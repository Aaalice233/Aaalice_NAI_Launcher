import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../tool/ole_drag_inspector/validate_ole_dump.dart';

void main() {
  test('synthetic 16-cell matrix passes and tampering fails closed', () async {
    final root = await Directory.systemTemp.createTemp('ole_validator_matrix_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final sentinelManifest = await _createSentinels(root);
    final session = Directory(p.join(root.path, 'session'))..createSync();
    await _createMatrix(session, sentinelManifest);

    final passing = await validateOleDump(
      session: session,
      sentinelManifest: sentinelManifest,
    );
    expect(passing['passed'], isTrue, reason: '${passing['errors']}');
    expect(passing['validatedCells'], 16);

    final tampered = File(
      p.join(
        session.path,
        'history_prepared_file_protected_text',
        'formats',
        'filedrop.bin',
      ),
    );
    await tampered.writeAsBytes(const [1, 2, 3], flush: true);
    final failing = await validateOleDump(
      session: session,
      sentinelManifest: sentinelManifest,
    );
    expect(failing['passed'], isFalse);
    expect(
      (failing['errors']! as List).join('\n'),
      contains('SHA-256 does not match'),
    );
  });
}

Future<File> _createSentinels(Directory root) async {
  final directory = Directory(p.join(root.path, 'sentinels'))..createSync();
  const token = 'SYNTHETIC_OLE_VALIDATOR';
  final records = <Map<String, Object?>>[];
  for (final entry in const {
    'text': ['#F44336', '#4CAF50', '#2196F3', '#FFC107'],
    'stealth': ['#9C27B0', '#00BCD4', '#FF5722', '#3F51B5'],
  }.entries) {
    final promptToken = 'NAI_OLE_${entry.key.toUpperCase()}_$token';
    final metadata = jsonEncode({
      'prompt': promptToken,
      'uc': 'negative',
      'seed': entry.key == 'text' ? 101 : 202,
      'width': 96,
      'height': 96,
      'steps': 28,
      'scale': 5.0,
      'sampler': 'k_euler',
    });
    final palette = entry.value.map(_parseColor).toList();
    final base = Uint8List.fromList(img.encodePng(_patternImage(palette)));
    final Uint8List bytes;
    final String sourceFormat;
    if (entry.key == 'text') {
      bytes = UnifiedMetadataParser.embedTextChunkOnly(
        base,
        'Comment',
        metadata,
      );
      sourceFormat = 'NovelAI';
    } else {
      bytes = _removeTextChunks(
        await UnifiedMetadataParser.embedMetadata(
          base,
          metadata,
          useStealth: true,
        ),
      );
      sourceFormat = 'NovelAI stealth_pngcomp';
    }
    final file = File(p.join(directory.path, '${entry.key}.png'));
    await file.writeAsBytes(bytes, flush: true);
    records.add({
      'payload': entry.key,
      'filePath': file.path,
      'sha256': crypto.sha256.convert(bytes).toString(),
      'promptToken': promptToken,
      'sourceFormat': sourceFormat,
      'palette': entry.value,
    });
  }
  final manifest = File(p.join(directory.path, 'sentinels.json'));
  await manifest.writeAsString(
    jsonEncode({'schemaVersion': 1, 'sentinels': records}),
    flush: true,
  );
  return manifest;
}

Future<void> _createMatrix(Directory session, File sentinelManifest) async {
  final decoded = jsonDecode(await sentinelManifest.readAsString()) as Map;
  final sentinels = <String, Map<String, dynamic>>{
    for (final value in decoded['sentinels'] as List)
      (value as Map)['payload'] as String: value.cast<String, dynamic>(),
  };
  final external = Directory(p.join(session.parent.path, 'external'))
    ..createSync();
  final cleanBytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 8, height: 8, numChannels: 4)),
  );
  final markerBytes = Uint8List.fromList(img.encodePng(_markerImage()));

  for (final path in const [
    'history_prepared_file',
    'preview_memory_only',
    'preview_source_file',
    'gallery_drag_wrapper',
  ]) {
    for (final mode in const ['protected', 'unprotected']) {
      for (final payload in const ['text', 'stealth']) {
        final sentinel = sentinels[payload]!;
        final original = File(sentinel['filePath'] as String);
        final originalBytes = await original.readAsBytes();
        final cell = Directory(p.join(session.path, '${path}_${mode}_$payload'))
          ..createSync();
        final externalFile = File(
          p.join(external.path, '${path}_${mode}_$payload.png'),
        );
        await externalFile.writeAsBytes(
          mode == 'protected' ? cleanBytes : originalBytes,
          flush: true,
        );
        final extractedPath =
            mode == 'unprotected' &&
                (path == 'preview_source_file' ||
                    path == 'gallery_drag_wrapper')
            ? original.path
            : externalFile.path;
        final referencedSource = File(extractedPath);
        final referencedBytes = await referencedSource.readAsBytes();

        final fileDropRaw = await _writeArtifact(
          cell,
          'formats/filedrop.bin',
          _utf16le(extractedPath),
          'raw',
        );
        final referenced = await _writeArtifact(
          cell,
          'referenced_files/copied.png',
          referencedBytes,
          'referenced-file',
        );
        final shellBytes = mode == 'protected'
            ? markerBytes
            : _attenuateForShellFeedback(originalBytes);
        final shellRaw = await _writeArtifact(
          cell,
          'formats/drag_image_bits.bin',
          Uint8List.fromList(const [11, 22, 33, 44]),
          'raw',
        );
        final shellPng = await _writeArtifact(
          cell,
          'decoded_images/drag_image_bits.png',
          shellBytes,
          'decoded-png',
        );
        final shellRgba = await _writeArtifact(
          cell,
          'decoded_images/drag_image_bits.rgba',
          _rgbaBytes(shellBytes),
          'decoded-rgba',
        );

        final manifest = {
          'SchemaVersion': 1,
          'Mode': mode,
          'Path': path,
          'Payload': payload,
          'ProcessBitness': 64,
          'InspectionPassed': true,
          'FatalError': null,
          'Formats': [
            {
              'Index': 0,
              'FormatId': 15,
              'FormatName': 'FileDrop',
              'AdvertisedTymed': 'TYMED_HGLOBAL',
              'ActualTymed': 'TYMED_HGLOBAL',
              'Aspect': 'DVASPECT_CONTENT',
              'Lindex': -1,
              'Classification': 'file-list',
              'IsImageCandidate': false,
              'Status': 'complete',
              'Error': null,
              'ReleaseStgMediumCalled': true,
              'Text': null,
              'ExtractedPaths': [extractedPath],
              'DumpFiles': [fileDropRaw],
              'ReferencedFiles': [
                {'OriginalPath': extractedPath, 'Copy': referenced},
              ],
              'DecodedImages': <Object>[],
            },
            {
              'Index': 1,
              'FormatId': 50001,
              'FormatName': 'DragImageBits',
              'AdvertisedTymed': 'TYMED_HGLOBAL',
              'ActualTymed': 'TYMED_HGLOBAL',
              'Aspect': 'DVASPECT_CONTENT',
              'Lindex': -1,
              'Classification': 'image',
              'IsImageCandidate': true,
              'Status': 'complete',
              'Error': null,
              'ReleaseStgMediumCalled': true,
              'Text': null,
              'ExtractedPaths': <Object>[],
              'DumpFiles': [shellRaw],
              'ReferencedFiles': <Object>[],
              'DecodedImages': [
                {
                  'Width': 96,
                  'Height': 96,
                  'Source': 'synthetic',
                  'Png': shellPng,
                  'Rgba': shellRgba,
                },
              ],
            },
          ],
        };
        await File(
          p.join(cell.path, 'manifest.json'),
        ).writeAsString(jsonEncode(manifest), flush: true);
      }
    }
  }
}

Future<Map<String, Object>> _writeArtifact(
  Directory cell,
  String relative,
  Uint8List bytes,
  String role,
) async {
  final file = File(p.join(cell.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return {
    'Role': role,
    'RelativePath': relative.replaceAll('\\', '/'),
    'Length': bytes.length,
    'Sha256': crypto.sha256.convert(bytes).toString(),
  };
}

img.Image _patternImage(List<List<int>> palette) {
  final image = img.Image(width: 96, height: 96, numChannels: 4);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final index = (y < 48 ? 0 : 2) + (x < 48 ? 0 : 1);
      final color = palette[index];
      image.setPixelRgba(x, y, color[0], color[1], color[2], 255);
    }
  }
  return image;
}

Uint8List _attenuateForShellFeedback(Uint8List bytes) {
  final source = img.decodeImage(bytes)!;
  final output = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  for (var y = 0; y < source.height; y++) {
    final scale = y < source.height / 2 ? 1.0 : 0.62;
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      output.setPixelRgba(
        x,
        y,
        (pixel.r * scale).round(),
        (pixel.g * scale).round(),
        (pixel.b * scale).round(),
        128,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(output));
}

img.Image _markerImage() {
  final image = img.Image(width: 100, height: 100, numChannels: 4);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final color = y >= 20
          ? const [0x12, 0x3b, 0x3a]
          : x < 65
          ? const [0xff, 0xb0, 0x00]
          : const [0x00, 0xd6, 0xc9];
      image.setPixelRgba(x, y, color[0], color[1], color[2], 255);
    }
  }
  return image;
}

Uint8List _rgbaBytes(Uint8List png) {
  final image = img.decodePng(png)!;
  final bytes = Uint8List(image.width * image.height * 4);
  var offset = 0;
  for (final pixel in image) {
    bytes[offset++] = pixel.r.toInt();
    bytes[offset++] = pixel.g.toInt();
    bytes[offset++] = pixel.b.toInt();
    bytes[offset++] = pixel.a.toInt();
  }
  return bytes;
}

Uint8List _utf16le(String value) {
  final bytes = Uint8List(value.codeUnits.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < value.codeUnits.length; index++) {
    data.setUint16(index * 2, value.codeUnits[index], Endian.little);
  }
  return bytes;
}

Uint8List _removeTextChunks(Uint8List png) {
  final output = BytesBuilder(copy: false)..add(png.sublist(0, 8));
  var offset = 8;
  while (offset + 12 <= png.length) {
    final length = ByteData.sublistView(png, offset, offset + 4).getUint32(0);
    final end = offset + length + 12;
    final type = ascii.decode(png.sublist(offset + 4, offset + 8));
    if (type != 'tEXt' && type != 'zTXt' && type != 'iTXt') {
      output.add(png.sublist(offset, end));
    }
    offset = end;
    if (type == 'IEND') break;
  }
  return output.takeBytes();
}

List<int> _parseColor(String value) {
  final hex = value.substring(1);
  return [
    int.parse(hex.substring(0, 2), radix: 16),
    int.parse(hex.substring(2, 4), radix: 16),
    int.parse(hex.substring(4, 6), radix: 16),
  ];
}
