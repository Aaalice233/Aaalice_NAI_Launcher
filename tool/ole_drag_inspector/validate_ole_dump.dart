import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

const _matrixPaths = <String>{
  'history_prepared_file',
  'preview_memory_only',
  'preview_source_file',
  'gallery_drag_wrapper',
};
const _matrixModes = <String>{'protected', 'unprotected'};
const _matrixPayloads = <String>{'text', 'stealth'};
const _allowedControlFormats = <String>{
  'Preferred DropEffect',
  'Performed DropEffect',
  'Paste Succeeded',
  'InShellDragLoop',
  'UsingDefaultDragImage',
  'IsShowingLayered',
  'DragSourceHelperFlags',
  'DragWindow',
  'DragContext',
  'DragSource',
  'DropDescription',
  'Shell IDList Array',
  'FileGroupDescriptor',
  'FileGroupDescriptorW',
  'FileContents',
};

Future<void> main(List<String> arguments) async {
  final sessionValue = _requiredOption(arguments, '--session');
  final sentinelValue = _requiredOption(arguments, '--sentinels');
  final cleanup = arguments.contains('--cleanup');
  final session = Directory(p.normalize(p.absolute(sessionValue)));
  final sentinelManifest = File(p.normalize(p.absolute(sentinelValue)));
  var passed = false;

  try {
    final report = await validateOleDump(
      session: session,
      sentinelManifest: sentinelManifest,
    );
    final reportFile = File(p.join(session.path, 'validation_report.json'));
    await reportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
      encoding: utf8,
      flush: true,
    );
    passed = report['passed'] == true;
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  } catch (error, stackTrace) {
    stderr.writeln('OLE validation failed before completion: $error');
    stderr.writeln(stackTrace);
  } finally {
    if (cleanup) {
      await _cleanupTemporarySession(session);
    }
  }

  if (!passed) exitCode = 1;
}

Future<Map<String, Object?>> validateOleDump({
  required Directory session,
  required File sentinelManifest,
}) async {
  if (!await session.exists()) {
    throw FileSystemException(
      'OLE session directory does not exist',
      session.path,
    );
  }
  if (!await sentinelManifest.exists()) {
    throw FileSystemException(
      'Sentinel manifest does not exist',
      sentinelManifest.path,
    );
  }

  final sentinelRoot = _decodeMap(await sentinelManifest.readAsString());
  if (_int(sentinelRoot, 'schemaVersion') != 1) {
    throw const FormatException('Unsupported sentinel manifest schema');
  }
  final sentinelMaps = _list(sentinelRoot, 'sentinels').map(_asMap).toList();
  final sentinels = <String, _Sentinel>{
    for (final map in sentinelMaps)
      _string(map, 'payload'): _Sentinel.fromMap(map),
  };
  if (!sentinels.keys.toSet().containsAll(_matrixPayloads)) {
    throw const FormatException('Both text and stealth sentinels are required');
  }

  for (final sentinel in sentinels.values) {
    await sentinel.verifySource();
  }

  final manifestFiles = await session
      .list(recursive: true, followLinks: false)
      .where(
        (entity) =>
            entity is File && p.basename(entity.path) == 'manifest.json',
      )
      .cast<File>()
      .toList();
  final cells = <String, List<_CapturedCell>>{};
  for (final file in manifestFiles) {
    final cell = _CapturedCell(file, _decodeMap(await file.readAsString()));
    cells.putIfAbsent(cell.key, () => []).add(cell);
  }

  final errors = <String>[];
  final cellReports = <Map<String, Object?>>[];
  for (final path in _matrixPaths) {
    for (final mode in _matrixModes) {
      for (final payload in _matrixPayloads) {
        final key = '$path|$mode|$payload';
        final matches = cells[key] ?? const [];
        if (matches.length != 1) {
          errors.add(
            '$key expected exactly one capture, found ${matches.length}',
          );
          continue;
        }
        final result = await _validateCell(matches.single, sentinels[payload]!);
        errors.addAll(result.errors.map((error) => '$key: $error'));
        cellReports.add(result.report);
      }
    }
  }

  final expectedKeys = <String>{
    for (final path in _matrixPaths)
      for (final mode in _matrixModes)
        for (final payload in _matrixPayloads) '$path|$mode|$payload',
  };
  for (final extra in cells.keys.where((key) => !expectedKeys.contains(key))) {
    errors.add('Unexpected matrix capture: $extra');
  }

  return {
    'schemaVersion': 1,
    'validatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'passed': errors.isEmpty && cellReports.length == 16,
    'expectedCells': 16,
    'validatedCells': cellReports.length,
    'errors': errors,
    'cells': cellReports,
  };
}

Future<_CellValidation> _validateCell(
  _CapturedCell cell,
  _Sentinel sentinel,
) async {
  final errors = <String>[];
  final manifest = cell.manifest;
  final cellDirectory = cell.manifestFile.parent;
  if (_int(manifest, 'SchemaVersion', fallback: 'schemaVersion') != 1) {
    errors.add('unsupported inspector manifest schema');
  }
  if (_bool(manifest, 'InspectionPassed', fallback: 'inspectionPassed') !=
      true) {
    errors.add('inspector did not complete in passing state');
  }
  if (_int(manifest, 'ProcessBitness', fallback: 'processBitness') != 64) {
    errors.add('inspector did not run as a 64-bit process');
  }
  final fatal = _nullableString(manifest, 'FatalError', fallback: 'fatalError');
  if (fatal != null && fatal.isNotEmpty) {
    errors.add('inspector fatal error: $fatal');
  }

  final formats = _list(
    manifest,
    'Formats',
    fallback: 'formats',
  ).map(_asMap).toList();
  if (formats.isEmpty) errors.add('no OLE formats were enumerated');
  final artifacts = <_ValidatedArtifact>[];
  final coveredRelativePaths = <String>{};
  final formatReports = <Map<String, Object?>>[];
  final shellImages = <File>[];

  for (final format in formats) {
    final name = _string(format, 'FormatName', fallback: 'formatName');
    final status = _string(format, 'Status', fallback: 'status');
    final classification = _string(
      format,
      'Classification',
      fallback: 'classification',
    );
    if (status != 'complete') {
      errors.add('$name GetData/read status is $status');
    }
    if (_bool(
          format,
          'ReleaseStgMediumCalled',
          fallback: 'releaseStgMediumCalled',
        ) !=
        true) {
      errors.add('$name did not release STGMEDIUM');
    }
    if (classification == 'unknown') errors.add('$name is unclassified');
    if (classification == 'control' && !_allowedControlFormats.contains(name)) {
      errors.add('$name is not in the explicit control-format allowlist');
    }
    final loweredName = name.toLowerCase();
    if (loweredName.contains('localdata') ||
        loweredName.contains('history_internal')) {
      errors.add('$name exposes an in-process drag identifier');
    }

    for (final artifactMap in _list(
      format,
      'DumpFiles',
      fallback: 'dumpFiles',
    ).map(_asMap)) {
      final artifact = await _validateArtifact(
        cellDirectory,
        artifactMap,
        coveredRelativePaths,
        errors,
      );
      if (artifact != null) artifacts.add(artifact);
    }

    for (final referencedMap in _list(
      format,
      'ReferencedFiles',
      fallback: 'referencedFiles',
    ).map(_asMap)) {
      final copyMap = _map(referencedMap, 'Copy', fallback: 'copy');
      final artifact = await _validateArtifact(
        cellDirectory,
        copyMap,
        coveredRelativePaths,
        errors,
      );
      if (artifact != null) artifacts.add(artifact);
    }

    final decodedImages = _list(
      format,
      'DecodedImages',
      fallback: 'decodedImages',
    ).map(_asMap).toList();
    final isImageCandidate =
        _bool(format, 'IsImageCandidate', fallback: 'isImageCandidate') == true;
    if (isImageCandidate && decodedImages.isEmpty) {
      errors.add('$name is image-like but has no decoded image');
    }
    for (final imageMap in decodedImages) {
      final pngMap = _map(imageMap, 'Png', fallback: 'png');
      final rgbaMap = _map(imageMap, 'Rgba', fallback: 'rgba');
      final pngArtifact = await _validateArtifact(
        cellDirectory,
        pngMap,
        coveredRelativePaths,
        errors,
      );
      final rgbaArtifact = await _validateArtifact(
        cellDirectory,
        rgbaMap,
        coveredRelativePaths,
        errors,
      );
      if (pngArtifact != null) {
        artifacts.add(pngArtifact);
        if (loweredName.contains('dragimagebits')) {
          shellImages.add(pngArtifact.file);
        }
      }
      if (rgbaArtifact != null) artifacts.add(rgbaArtifact);
    }

    formatReports.add({
      'id': _int(format, 'FormatId', fallback: 'formatId'),
      'name': name,
      'advertisedTymed': _string(
        format,
        'AdvertisedTymed',
        fallback: 'advertisedTymed',
      ),
      'actualTymed': _string(format, 'ActualTymed', fallback: 'actualTymed'),
      'classification': classification,
    });
  }

  if (shellImages.isEmpty) {
    errors.add('DragImageBits was not enumerated and decoded');
  }
  await _checkArtifactCoverage(cellDirectory, coveredRelativePaths, errors);

  final scans = <_ArtifactScan>[];
  for (final artifact in artifacts) {
    scans.add(await _scanArtifact(artifact, sentinel));
  }
  final originalBytes = await sentinel.file.readAsBytes();
  final originalPath = p.normalize(p.absolute(sentinel.file.path));
  final originalPathLower = originalPath.toLowerCase();
  final allExtractedPaths = <String>[
    for (final format in formats)
      for (final value in _list(
        format,
        'ExtractedPaths',
        fallback: 'extractedPaths',
      ))
        if (value is String) p.normalize(p.absolute(value)),
  ];
  final fileDropExtractedPaths = <String>[
    for (final format in formats)
      if (_int(format, 'FormatId', fallback: 'formatId') == 15)
        for (final value in _list(
          format,
          'ExtractedPaths',
          fallback: 'extractedPaths',
        ))
          if (value is String) p.normalize(p.absolute(value)),
  ];
  final originalShaFound = artifacts.any(
    (item) => item.sha256 == sentinel.sha256,
  );
  final originalBytesFound = scans.any(
    (scan) => _containsBytes(scan.bytes, originalBytes),
  );
  final promptFound = scans.any((scan) => scan.containsPrompt);
  final pathBytesFound = scans.any((scan) => scan.containsOriginalPath);
  final originalPathExtracted = allExtractedPaths.any(
    (path) => path.toLowerCase() == originalPathLower,
  );
  final originalPathInFileDrop = fileDropExtractedPaths.any(
    (path) => path.toLowerCase() == originalPathLower,
  );
  final matchingMetadata = scans
      .where((scan) => scan.metadataContainsPrompt)
      .toList();
  final internalProtocolFound = scans.any(
    (scan) =>
        _containsText(scan.bytes, 'localData') ||
        _containsText(scan.bytes, 'history_internal') ||
        _containsText(scan.bytes, 'imageId'),
  );

  if (internalProtocolFound) {
    errors.add('an OLE payload exposes the in-process localData protocol');
  }

  if (cell.mode == 'protected') {
    if (originalShaFound) errors.add('original PNG SHA-256 is present');
    if (originalBytesFound) {
      errors.add('original PNG byte sequence is embedded');
    }
    if (promptFound) {
      errors.add('sentinel metadata token is present in a payload');
    }
    if (pathBytesFound || originalPathExtracted) {
      errors.add('original absolute path is externally observable');
    }
    if (matchingMetadata.isNotEmpty) {
      errors.add('UnifiedMetadataParser recovered sentinel metadata');
    }
  } else {
    if (!originalShaFound) {
      errors.add('positive control did not expose original PNG SHA');
    }
    if (matchingMetadata.isEmpty) {
      errors.add('positive control metadata was not recovered');
    } else if (cell.payload == 'stealth' &&
        !matchingMetadata.any(
          (scan) => scan.metadataSource == 'NovelAI stealth_pngcomp',
        )) {
      errors.add('positive control did not recover stealth_pngcomp metadata');
    }
    if ((cell.path == 'preview_source_file' ||
            cell.path == 'gallery_drag_wrapper') &&
        !originalPathInFileDrop) {
      errors.add('positive control CF_HDROP did not expose the source path');
    }
  }

  final shellMarkerMatches = <bool>[];
  final shellPatternMatches = <bool>[];
  for (final file in shellImages) {
    final bytes = await file.readAsBytes();
    shellMarkerMatches.add(_matchesProtectedMarker(bytes));
    shellPatternMatches.add(_matchesPalettePattern(bytes, sentinel.palette));
  }
  if (cell.mode == 'protected') {
    if (!shellMarkerMatches.contains(true)) {
      errors.add(
        'Shell feedback does not contain the protected marker geometry',
      );
    }
    if (shellPatternMatches.contains(true)) {
      errors.add('Shell feedback still contains the sentinel image pattern');
    }
  } else {
    if (!shellPatternMatches.contains(true)) {
      errors.add('positive-control Shell feedback lacks the sentinel pattern');
    }
    if (shellMarkerMatches.contains(true)) {
      errors.add(
        'positive-control Shell feedback unexpectedly uses the marker',
      );
    }
  }

  return _CellValidation(errors, {
    'path': cell.path,
    'mode': cell.mode,
    'payload': cell.payload,
    'passed': errors.isEmpty,
    'formatCount': formats.length,
    'formats': formatReports,
    'artifactHashes': [for (final artifact in artifacts) artifact.sha256],
  });
}

Future<_ValidatedArtifact?> _validateArtifact(
  Directory cellDirectory,
  Map<String, dynamic> artifact,
  Set<String> coveredRelativePaths,
  List<String> errors,
) async {
  final relative = _string(artifact, 'RelativePath', fallback: 'relativePath');
  final expectedLength = _int(artifact, 'Length', fallback: 'length');
  final expectedSha = _string(
    artifact,
    'Sha256',
    fallback: 'sha256',
  ).toLowerCase();
  final normalizedRelative = p.normalize(relative);
  final resolved = p.normalize(
    p.absolute(p.join(cellDirectory.path, normalizedRelative)),
  );
  if (!p.isWithin(cellDirectory.path, resolved)) {
    errors.add('artifact escapes cell directory: $relative');
    return null;
  }
  final file = File(resolved);
  if (!await file.exists()) {
    errors.add('artifact is missing: $relative');
    return null;
  }
  final bytes = await file.readAsBytes();
  final actualSha = crypto.sha256.convert(bytes).toString();
  if (bytes.length != expectedLength) {
    errors.add('$relative length ${bytes.length} != manifest $expectedLength');
  }
  if (actualSha != expectedSha) {
    errors.add('$relative SHA-256 does not match its manifest');
  }
  coveredRelativePaths.add(p.normalize(relative).replaceAll('\\', '/'));
  return _ValidatedArtifact(file, actualSha);
}

Future<void> _checkArtifactCoverage(
  Directory cellDirectory,
  Set<String> covered,
  List<String> errors,
) async {
  await for (final entity in cellDirectory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File || p.basename(entity.path) == 'manifest.json') continue;
    final relative = p
        .relative(entity.path, from: cellDirectory.path)
        .replaceAll('\\', '/');
    if (!covered.contains(relative)) {
      errors.add('uncovered dump artifact: $relative');
    }
  }
}

Future<_ArtifactScan> _scanArtifact(
  _ValidatedArtifact artifact,
  _Sentinel sentinel,
) async {
  final bytes = await artifact.file.readAsBytes();
  final containsPrompt = _containsText(bytes, sentinel.promptToken);
  final containsOriginalPath = _containsText(
    bytes,
    sentinel.file.absolute.path,
  );
  String? metadataSource;
  var metadataContainsPrompt = false;
  if (UnifiedMetadataParser.isPngHeader(bytes)) {
    final result = UnifiedMetadataParser.parseFromPng(bytes, useCache: false);
    metadataSource = result.sourceFormat;
    metadataContainsPrompt =
        result.rawData?.contains(sentinel.promptToken) == true;
  }
  return _ArtifactScan(
    bytes,
    containsPrompt,
    containsOriginalPath,
    metadataContainsPrompt,
    metadataSource,
  );
}

bool _matchesProtectedMarker(Uint8List bytes) {
  return _matchesColors(bytes, const [
    _ColorTarget(0x12, 0x3b, 0x3a, 0.12),
    _ColorTarget(0xff, 0xb0, 0x00, 0.012),
    _ColorTarget(0x00, 0xd6, 0xc9, 0.006),
  ], tolerance: 28);
}

bool _matchesPalettePattern(Uint8List bytes, List<List<int>> palette) {
  return _matchesColors(bytes, [
    for (final color in palette)
      _ColorTarget(color[0], color[1], color[2], 0.035),
  ], tolerance: 34);
}

bool _matchesColors(
  Uint8List bytes,
  List<_ColorTarget> targets, {
  required int tolerance,
}) {
  final image = img.decodeImage(bytes);
  if (image == null || image.width == 0 || image.height == 0) return false;
  final counts = List<int>.filled(targets.length, 0);
  for (final pixel in image) {
    for (var index = 0; index < targets.length; index++) {
      final target = targets[index];
      if ((pixel.r.toInt() - target.r).abs() <= tolerance &&
          (pixel.g.toInt() - target.g).abs() <= tolerance &&
          (pixel.b.toInt() - target.b).abs() <= tolerance) {
        counts[index]++;
      }
    }
  }
  final total = image.width * image.height;
  for (var index = 0; index < targets.length; index++) {
    if (counts[index] / total < targets[index].minimumFraction) return false;
  }
  return true;
}

bool _containsText(Uint8List bytes, String value) {
  return _containsBytes(bytes, Uint8List.fromList(utf8.encode(value))) ||
      _containsBytes(bytes, Uint8List.fromList(utf16le.encode(value)));
}

bool _containsBytes(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty) return true;
  if (needle.length > haystack.length) return false;
  final prefix = List<int>.filled(needle.length, 0);
  for (var index = 1, matched = 0; index < needle.length; index++) {
    while (matched > 0 && needle[index] != needle[matched]) {
      matched = prefix[matched - 1];
    }
    if (needle[index] == needle[matched]) matched++;
    prefix[index] = matched;
  }
  for (var index = 0, matched = 0; index < haystack.length; index++) {
    while (matched > 0 && haystack[index] != needle[matched]) {
      matched = prefix[matched - 1];
    }
    if (haystack[index] == needle[matched]) matched++;
    if (matched == needle.length) return true;
  }
  return false;
}

Future<void> _cleanupTemporarySession(Directory session) async {
  final tempRoot = p.normalize(p.absolute(Directory.systemTemp.path));
  final sessionPath = p.normalize(p.absolute(session.path));
  final allowedSegment =
      '${p.separator}nai_launcher_ole_drag_inspector${p.separator}';
  if (!p.isWithin(tempRoot, sessionPath) ||
      !sessionPath.toLowerCase().contains(allowedSegment.toLowerCase())) {
    throw FileSystemException(
      'Refusing cleanup outside the inspector temporary root',
      sessionPath,
    );
  }
  if (await session.exists()) await session.delete(recursive: true);
}

String _requiredOption(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) {
    throw FormatException('$name is required');
  }
  return arguments[index + 1];
}

Map<String, dynamic> _decodeMap(String source) => _asMap(jsonDecode(source));

Map<String, dynamic> _asMap(Object? value) {
  if (value is! Map) throw const FormatException('Expected a JSON object');
  return value.map((key, value) => MapEntry('$key', value));
}

Object? _read(Map<String, dynamic> map, String key, {String? fallback}) {
  if (map.containsKey(key)) return map[key];
  if (fallback != null && map.containsKey(fallback)) return map[fallback];
  throw FormatException('Missing JSON field $key');
}

String _string(Map<String, dynamic> map, String key, {String? fallback}) {
  final value = _read(map, key, fallback: fallback);
  if (value is! String) throw FormatException('$key must be a string');
  return value;
}

String? _nullableString(
  Map<String, dynamic> map,
  String key, {
  String? fallback,
}) {
  final value = _read(map, key, fallback: fallback);
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string or null');
  return value;
}

int _int(Map<String, dynamic> map, String key, {String? fallback}) {
  final value = _read(map, key, fallback: fallback);
  if (value is! num) throw FormatException('$key must be numeric');
  return value.toInt();
}

bool? _bool(Map<String, dynamic> map, String key, {String? fallback}) {
  final value = _read(map, key, fallback: fallback);
  if (value == null) return null;
  if (value is! bool) throw FormatException('$key must be boolean');
  return value;
}

List<dynamic> _list(Map<String, dynamic> map, String key, {String? fallback}) {
  final value = _read(map, key, fallback: fallback);
  if (value is! List) throw FormatException('$key must be a list');
  return value;
}

Map<String, dynamic> _map(
  Map<String, dynamic> map,
  String key, {
  String? fallback,
}) => _asMap(_read(map, key, fallback: fallback));

final class _Sentinel {
  const _Sentinel({
    required this.payload,
    required this.file,
    required this.sha256,
    required this.promptToken,
    required this.sourceFormat,
    required this.palette,
  });

  factory _Sentinel.fromMap(Map<String, dynamic> map) {
    return _Sentinel(
      payload: _string(map, 'payload'),
      file: File(_string(map, 'filePath')),
      sha256: _string(map, 'sha256').toLowerCase(),
      promptToken: _string(map, 'promptToken'),
      sourceFormat: _string(map, 'sourceFormat'),
      palette: [
        for (final value in _list(map, 'palette')) _parseHexColor('$value'),
      ],
    );
  }

  final String payload;
  final File file;
  final String sha256;
  final String promptToken;
  final String sourceFormat;
  final List<List<int>> palette;

  Future<void> verifySource() async {
    if (!await file.exists()) {
      throw FileSystemException('Sentinel image is missing', file.path);
    }
    final bytes = await file.readAsBytes();
    if (crypto.sha256.convert(bytes).toString() != sha256) {
      throw StateError('Sentinel $payload SHA-256 does not match its manifest');
    }
    final result = UnifiedMetadataParser.parseFromPng(bytes, useCache: false);
    if (!result.success || result.rawData?.contains(promptToken) != true) {
      throw StateError('Sentinel $payload failed metadata self-check');
    }
    if (result.sourceFormat != sourceFormat) {
      throw StateError(
        'Sentinel $payload parser source ${result.sourceFormat} != $sourceFormat',
      );
    }
  }
}

final class _CapturedCell {
  const _CapturedCell(this.manifestFile, this.manifest);

  final File manifestFile;
  final Map<String, dynamic> manifest;

  String get path => _string(manifest, 'Path', fallback: 'path');
  String get mode => _string(manifest, 'Mode', fallback: 'mode');
  String get payload => _string(manifest, 'Payload', fallback: 'payload');
  String get key => '$path|$mode|$payload';
}

final class _ValidatedArtifact {
  const _ValidatedArtifact(this.file, this.sha256);

  final File file;
  final String sha256;
}

final class _ArtifactScan {
  const _ArtifactScan(
    this.bytes,
    this.containsPrompt,
    this.containsOriginalPath,
    this.metadataContainsPrompt,
    this.metadataSource,
  );

  final Uint8List bytes;
  final bool containsPrompt;
  final bool containsOriginalPath;
  final bool metadataContainsPrompt;
  final String? metadataSource;
}

final class _CellValidation {
  const _CellValidation(this.errors, this.report);

  final List<String> errors;
  final Map<String, Object?> report;
}

final class _ColorTarget {
  const _ColorTarget(this.r, this.g, this.b, this.minimumFraction);

  final int r;
  final int g;
  final int b;
  final double minimumFraction;
}

List<int> _parseHexColor(String value) {
  final normalized = value.startsWith('#') ? value.substring(1) : value;
  if (normalized.length != 6) throw FormatException('Invalid color $value');
  return [
    int.parse(normalized.substring(0, 2), radix: 16),
    int.parse(normalized.substring(2, 4), radix: 16),
    int.parse(normalized.substring(4, 6), radix: 16),
  ];
}

const utf16le = _Utf16LeCodec();

final class _Utf16LeCodec {
  const _Utf16LeCodec();

  List<int> encode(String value) {
    final units = value.codeUnits;
    final bytes = Uint8List(units.length * 2);
    final data = ByteData.sublistView(bytes);
    for (var index = 0; index < units.length; index++) {
      data.setUint16(index * 2, units[index], Endian.little);
    }
    return bytes;
  }
}
