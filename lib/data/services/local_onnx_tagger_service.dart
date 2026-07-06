import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart' as p;
// ignore: implementation_imports
import 'package:onnxruntime/src/bindings/onnxruntime_bindings_generated.dart'
    as bg;

import '../../core/utils/isolate_pool.dart';
import 'local_onnx_model_service.dart';

final localOnnxTaggerServiceProvider = Provider<LocalOnnxTaggerService>((ref) {
  return const LocalOnnxTaggerService();
});

enum OnnxTaggerLabelCategory { rating, general, character, other }

class OnnxTaggerLabel {
  const OnnxTaggerLabel({required this.name, this.category});

  final String name;
  final String? category;

  OnnxTaggerLabelCategory get labelCategory {
    final normalizedCategory = category?.trim().toLowerCase();
    if (normalizedCategory == '9' ||
        normalizedCategory == 'rating' ||
        name.startsWith('rating:')) {
      return OnnxTaggerLabelCategory.rating;
    }
    if (normalizedCategory == '0' ||
        normalizedCategory == 'general' ||
        normalizedCategory == 'tag' ||
        normalizedCategory == 'tags') {
      return OnnxTaggerLabelCategory.general;
    }
    if (normalizedCategory == '4' ||
        normalizedCategory == 'character' ||
        normalizedCategory == 'characters') {
      return OnnxTaggerLabelCategory.character;
    }
    return OnnxTaggerLabelCategory.other;
  }

  bool get isRating {
    return labelCategory == OnnxTaggerLabelCategory.rating;
  }

  bool get isGeneral => labelCategory == OnnxTaggerLabelCategory.general;

  bool get isCharacter => labelCategory == OnnxTaggerLabelCategory.character;
}

class OnnxTaggerTag {
  const OnnxTaggerTag({required this.name, required this.score, this.category});

  final String name;
  final double score;
  final String? category;
}

class OnnxTaggerResult {
  const OnnxTaggerResult({required this.model, required this.tags});

  final LocalOnnxModelDescriptor model;
  final List<OnnxTaggerTag> tags;

  String get prompt => tags.map((tag) => tag.name).join(', ');
}

class _OnnxImageInput {
  const _OnnxImageInput({required this.data, required this.shape});

  final Float32List data;
  final List<int> shape;
}

enum OnnxSessionLoadMode { externalDataFile, patchedSingleFile }

class OnnxLetterboxLayout {
  const OnnxLetterboxLayout({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.resizedWidth,
    required this.resizedHeight,
    required this.offsetX,
    required this.offsetY,
  });

  final int canvasWidth;
  final int canvasHeight;
  final int resizedWidth;
  final int resizedHeight;
  final int offsetX;
  final int offsetY;

  int get canvasPixels => canvasWidth * canvasHeight;
}

class LocalOnnxTaggerService {
  const LocalOnnxTaggerService();

  static const int defaultInputSize = 448;
  static const int _opsetPatchTailBytes = 4096;

  static OnnxLetterboxLayout debugLetterboxLayoutForTesting({
    required int sourceWidth,
    required int sourceHeight,
    required int inputSize,
  }) {
    return _computeLetterboxLayout(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      inputSize: inputSize,
    );
  }

  static OnnxSessionLoadMode debugSessionLoadModeForTesting(
    LocalOnnxModelDescriptor model,
  ) {
    return _resolveSessionLoadMode(model);
  }

  Future<OnnxTaggerResult> tagImage({
    required Uint8List imageBytes,
    required LocalOnnxModelDescriptor model,
    double? threshold,
    double generalThreshold = 0.35,
    double characterThreshold = 0.35,
    bool includeRatings = false,
  }) {
    final imageData = TransferableTypedData.fromList([imageBytes]);
    return ComputeGate.singleTask().runIsolate(
      () => const LocalOnnxTaggerService()._tagImageInCurrentIsolate(
        imageData: imageData,
        model: model,
        generalThreshold: threshold ?? generalThreshold,
        characterThreshold: threshold ?? characterThreshold,
        includeRatings: includeRatings,
      ),
    );
  }

  Future<OnnxTaggerResult> _tagImageInCurrentIsolate({
    required TransferableTypedData imageData,
    required LocalOnnxModelDescriptor model,
    double generalThreshold = 0.35,
    double characterThreshold = 0.35,
    bool includeRatings = false,
  }) async {
    if (model.labelsPath == null || model.labelsPath!.isEmpty) {
      throw StateError(
        '模型缺少标签文件，请放置 selected_tags.csv / tags.csv / labels.txt / model_vocabulary.json',
      );
    }

    final labels = await loadLabels(model.labelsPath!);
    if (labels.isEmpty) {
      throw StateError('标签文件为空: ${model.labelsPath}');
    }

    final imageBytes = imageData.materialize().asUint8List();
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw StateError('无法解码图片');
    }

    final inputSize = _resolveInputSize(model);
    final input = _preprocessImage(decoded, inputSize, model);
    final options = OrtSessionOptions()
      ..setInterOpNumThreads(1)
      ..setIntraOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    final runOptions = OrtRunOptions();
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      input.data,
      input.shape,
    );

    OrtSession? session;
    List<OrtValue?>? outputs;
    try {
      session = await _createSession(model, options);
      final inputName = _resolveInputName(session, model);
      final outputNames = _resolveOutputNames(session, model);
      final inputs = {inputName: inputOrt};
      outputs = session.run(runOptions, inputs, outputNames);
      final scores = outputs.isNotEmpty
          ? _normalizeScores(_flattenScores(outputs.first?.value))
          : <double>[];
      return OnnxTaggerResult(
        model: model,
        tags: _buildTags(
          labels: labels,
          scores: scores,
          generalThreshold: generalThreshold,
          characterThreshold: characterThreshold,
          includeRatings: includeRatings,
        ),
      );
    } finally {
      for (final output in outputs ?? const <OrtValue?>[]) {
        output?.release();
      }
      inputOrt.release();
      runOptions.release();
      session?.release();
      options.release();
    }
  }

  Future<List<OnnxTaggerLabel>> loadLabels(String labelsPath) async {
    final file = File(labelsPath);
    if (!await file.exists()) {
      return const [];
    }

    final extension = labelsPath.split('.').last.toLowerCase();
    final raw = await file.readAsString();
    if (extension == 'json') {
      return _parseJsonLabels(raw);
    }
    if (extension == 'csv') {
      return _parseCsvLabels(raw);
    }
    return _parseTextLabels(raw);
  }

  Future<OrtSession> _createSession(
    LocalOnnxModelDescriptor model,
    OrtSessionOptions options,
  ) async {
    final loadMode = _resolveSessionLoadMode(model);
    if (loadMode == OnnxSessionLoadMode.externalDataFile) {
      return _createFileSession(model.path, options);
    }

    final patchedPath = await _ensurePatchedSingleFileModelPath(model.path);
    return _createFileSession(patchedPath, options);
  }

  OrtSession _createFileSession(String modelPath, OrtSessionOptions options) {
    if (Platform.isWindows) {
      return _createWindowsFileSession(modelPath);
    }
    return OrtSession.fromFile(File(modelPath), options);
  }

  OrtSession _createWindowsFileSession(String modelPath) {
    final options = _createNativeSessionOptions();
    try {
      _configureNativeSessionOptions(options);
      return _createWindowsSessionFromPath(modelPath, options);
    } finally {
      _releaseNativeSessionOptions(options);
    }
  }

  ffi.Pointer<bg.OrtSessionOptions> _createNativeSessionOptions() {
    final optionsPtrPtr = calloc<ffi.Pointer<bg.OrtSessionOptions>>();
    try {
      final statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateSessionOptions
          .asFunction<
            bg.OrtStatusPtr Function(
              ffi.Pointer<ffi.Pointer<bg.OrtSessionOptions>>,
            )
          >()(optionsPtrPtr);
      OrtStatus.checkOrtStatus(statusPtr);
      return optionsPtrPtr.value;
    } finally {
      calloc.free(optionsPtrPtr);
    }
  }

  void _configureNativeSessionOptions(
    ffi.Pointer<bg.OrtSessionOptions> options,
  ) {
    var statusPtr = OrtEnv.instance.ortApiPtr.ref.SetInterOpNumThreads
        .asFunction<
          bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtSessionOptions>, int)
        >()(options, 1);
    OrtStatus.checkOrtStatus(statusPtr);

    statusPtr = OrtEnv.instance.ortApiPtr.ref.SetIntraOpNumThreads
        .asFunction<
          bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtSessionOptions>, int)
        >()(options, 1);
    OrtStatus.checkOrtStatus(statusPtr);

    statusPtr = OrtEnv.instance.ortApiPtr.ref.SetSessionGraphOptimizationLevel
        .asFunction<
          bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtSessionOptions>, int)
        >()(options, GraphOptimizationLevel.ortEnableAll.value);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  OrtSession _createWindowsSessionFromPath(
    String modelPath,
    ffi.Pointer<bg.OrtSessionOptions> options,
  ) {
    final sessionPtrPtr = calloc<ffi.Pointer<bg.OrtSession>>();
    final pathPtr = File(modelPath).absolute.path.toNativeUtf16();
    try {
      final statusPtr =
          OrtEnv.instance.ortApiPtr.ref.CreateSession
              .asFunction<
                bg.OrtStatusPtr Function(
                  ffi.Pointer<bg.OrtEnv>,
                  ffi.Pointer<ffi.Char>,
                  ffi.Pointer<bg.OrtSessionOptions>,
                  ffi.Pointer<ffi.Pointer<bg.OrtSession>>,
                )
              >()(
            OrtEnv.instance.ptr,
            pathPtr.cast<ffi.Char>(),
            options,
            sessionPtrPtr,
          );
      OrtStatus.checkOrtStatus(statusPtr);
      return OrtSession.fromAddress(sessionPtrPtr.value.address);
    } finally {
      calloc.free(pathPtr);
      calloc.free(sessionPtrPtr);
    }
  }

  void _releaseNativeSessionOptions(ffi.Pointer<bg.OrtSessionOptions> options) {
    OrtEnv.instance.ortApiPtr.ref.ReleaseSessionOptions
        .asFunction<void Function(ffi.Pointer<bg.OrtSessionOptions>)>()(
      options,
    );
  }

  Future<String> _ensurePatchedSingleFileModelPath(String modelPath) async {
    final source = File(modelPath);
    final stat = await source.stat();
    final cacheDirectory = Directory(
      p.join(Directory.systemTemp.path, 'nai_launcher_onnx_cache'),
    );
    await cacheDirectory.create(recursive: true);

    final baseName = p
        .basenameWithoutExtension(modelPath)
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    final cacheKey = _singleFileModelCacheKey(source.absolute.path, stat);
    final target = File(
      p.join(cacheDirectory.path, '${baseName}_$cacheKey.onnx'),
    );
    if (await target.exists() && await target.length() == stat.size) {
      return target.path;
    }

    final partial = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.partial',
    );
    try {
      await _copyPatchedSingleFileModel(source, partial);
      if (await target.exists()) {
        await target.delete();
      }
      return (await partial.rename(target.path)).path;
    } catch (_) {
      if (await partial.exists()) {
        await partial.delete();
      }
      rethrow;
    }
  }

  String _singleFileModelCacheKey(String modelPath, FileStat stat) {
    final digest = sha1.convert(
      utf8.encode(
        [
          'opset_patch_v1',
          modelPath,
          stat.size.toString(),
          stat.modified.millisecondsSinceEpoch.toString(),
        ].join('|'),
      ),
    );
    return digest.toString().substring(0, 16);
  }

  Future<void> _copyPatchedSingleFileModel(File source, File target) async {
    final length = await source.length();
    final tailStart = math.max(0, length - _opsetPatchTailBytes);
    final tail = BytesBuilder(copy: false);
    await for (final chunk in source.openRead(tailStart)) {
      tail.add(chunk);
    }
    final patchedTail = _patchUnsupportedOpsetImports(tail.takeBytes());
    final sink = target.openWrite();
    try {
      await for (final chunk in source.openRead(0, tailStart)) {
        sink.add(chunk);
      }
      sink.add(patchedTail);
    } finally {
      await sink.close();
    }
  }

  static OnnxSessionLoadMode _resolveSessionLoadMode(
    LocalOnnxModelDescriptor model,
  ) {
    final hasExternalData = File('${model.path}.data').existsSync();
    return hasExternalData
        ? OnnxSessionLoadMode.externalDataFile
        : OnnxSessionLoadMode.patchedSingleFile;
  }

  String _resolveInputName(OrtSession session, LocalOnnxModelDescriptor model) {
    if (_isClTaggerV2(model) && session.inputNames.contains('pixel_values')) {
      return 'pixel_values';
    }
    return session.inputNames.isNotEmpty ? session.inputNames.first : 'input';
  }

  List<String>? _resolveOutputNames(
    OrtSession session,
    LocalOnnxModelDescriptor model,
  ) {
    if (_isClTaggerV2(model) && session.outputNames.contains('logits')) {
      return const ['logits'];
    }
    return null;
  }

  int _resolveInputSize(LocalOnnxModelDescriptor model) {
    final lower = model.name.toLowerCase();
    if (_isClTaggerV2(model)) {
      return 384;
    }
    if (_isClTagger(model)) {
      return 448;
    }
    final match = RegExp(
      r'(?:^|[^0-9])(224|256|384|448|512)(?:[^0-9]|$)',
    ).firstMatch(lower);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return defaultInputSize;
  }

  bool _isClTaggerV2(LocalOnnxModelDescriptor model) {
    final lowerName = model.name.toLowerCase();
    final lowerPath = model.path.toLowerCase();
    final lowerLabels = model.labelsPath?.toLowerCase() ?? '';
    return lowerName.contains('cl_tagger_v2') ||
        lowerName.contains('cl-tagger-v2') ||
        lowerPath.contains('cl_tagger_v2') ||
        lowerPath.contains('cl-tagger-v2') ||
        lowerLabels.endsWith('model_vocabulary.json');
  }

  bool _isClTagger(LocalOnnxModelDescriptor model) {
    final lowerName = model.name.toLowerCase();
    return model.kind == LocalOnnxModelKind.clTagger ||
        lowerName.contains('cl_tagger');
  }

  _OnnxImageInput _preprocessImage(
    img.Image source,
    int inputSize,
    LocalOnnxModelDescriptor model,
  ) {
    final layout = _computeLetterboxLayout(
      sourceWidth: source.width,
      sourceHeight: source.height,
      inputSize: inputSize,
    );
    final resizedSource = img.copyResize(
      source,
      width: layout.resizedWidth,
      height: layout.resizedHeight,
      interpolation: img.Interpolation.cubic,
    );
    final resized = img.Image(
      width: layout.canvasWidth,
      height: layout.canvasHeight,
    );
    img.fill(resized, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      resized,
      resizedSource,
      dstX: layout.offsetX,
      dstY: layout.offsetY,
    );

    final data = Float32List(inputSize * inputSize * 3);
    if (_isClTaggerV2(model)) {
      final planeSize = inputSize * inputSize;
      var rOffset = 0;
      var gOffset = planeSize;
      var bOffset = planeSize * 2;
      for (var y = 0; y < inputSize; y++) {
        for (var x = 0; x < inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          data[rOffset++] = pixel.r.toDouble() / 127.5 - 1.0;
          data[gOffset++] = pixel.g.toDouble() / 127.5 - 1.0;
          data[bOffset++] = pixel.b.toDouble() / 127.5 - 1.0;
        }
      }
      return _OnnxImageInput(data: data, shape: [1, 3, inputSize, inputSize]);
    }

    if (_isClTagger(model)) {
      final planeSize = inputSize * inputSize;
      var bOffset = 0;
      var gOffset = planeSize;
      var rOffset = planeSize * 2;
      for (var y = 0; y < inputSize; y++) {
        for (var x = 0; x < inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          data[bOffset++] = pixel.b.toDouble() / 255.0;
          data[gOffset++] = pixel.g.toDouble() / 255.0;
          data[rOffset++] = pixel.r.toDouble() / 255.0;
        }
      }
      return _OnnxImageInput(data: data, shape: [1, 3, inputSize, inputSize]);
    }

    var offset = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        data[offset++] = pixel.b.toDouble();
        data[offset++] = pixel.g.toDouble();
        data[offset++] = pixel.r.toDouble();
      }
    }
    return _OnnxImageInput(data: data, shape: [1, inputSize, inputSize, 3]);
  }

  static OnnxLetterboxLayout _computeLetterboxLayout({
    required int sourceWidth,
    required int sourceHeight,
    required int inputSize,
  }) {
    final longestSide = math.max(1, math.max(sourceWidth, sourceHeight));
    final scale = inputSize / longestSide;
    final resizedWidth = math.max(1, (sourceWidth * scale).round());
    final resizedHeight = math.max(1, (sourceHeight * scale).round());
    return OnnxLetterboxLayout(
      canvasWidth: inputSize,
      canvasHeight: inputSize,
      resizedWidth: math.min(inputSize, resizedWidth),
      resizedHeight: math.min(inputSize, resizedHeight),
      offsetX: (inputSize - resizedWidth) ~/ 2,
      offsetY: (inputSize - resizedHeight) ~/ 2,
    );
  }

  List<double> _flattenScores(Object? value) {
    final scores = <double>[];

    void walk(Object? current) {
      if (current is num) {
        scores.add(current.toDouble());
        return;
      }
      if (current is Iterable) {
        for (final item in current) {
          walk(item);
        }
      }
    }

    walk(value);
    return scores;
  }

  List<double> _normalizeScores(List<double> scores) {
    if (scores.any((score) => score < 0 || score > 1)) {
      return scores.map((score) => 1 / (1 + math.exp(-score))).toList();
    }
    return scores;
  }

  Uint8List _patchUnsupportedOpsetImports(Uint8List bytes) {
    _patchDefaultDomainOpsetImport(bytes);
    _patchNamedDomainOpsetImport(bytes, domain: 'ai.onnx.ml', maxVersion: 3);
    return bytes;
  }

  void _patchDefaultDomainOpsetImport(Uint8List bytes) {
    final start = math.max(0, bytes.length - _opsetPatchTailBytes);
    for (var i = start; i < bytes.length - 3; i++) {
      // ModelProto.opset_import field = 8 (0x42), OperatorSetIdProto with
      // only version field: [0x42, 0x02, 0x10, version]. CL tagger uses
      // ai.onnx opset 20, while the bundled Windows ORT can fail to bind
      // Shape(19) in the release runtime. CL tagger needs at least opset 18
      // because ReduceMean uses axes as an input.
      if (bytes[i] == 0x42 &&
          bytes[i + 1] == 0x02 &&
          bytes[i + 2] == 0x10 &&
          bytes[i + 3] > 18) {
        bytes[i + 3] = 18;
      }

      // Some exporters encode the default domain as an explicit empty string:
      // [0x42, 0x04, 0x0a, 0x00, 0x10, version].
      if (i < bytes.length - 5 &&
          bytes[i] == 0x42 &&
          bytes[i + 1] == 0x04 &&
          bytes[i + 2] == 0x0a &&
          bytes[i + 3] == 0x00 &&
          bytes[i + 4] == 0x10 &&
          bytes[i + 5] > 18) {
        bytes[i + 5] = 18;
      }
    }
  }

  void _patchNamedDomainOpsetImport(
    Uint8List bytes, {
    required String domain,
    required int maxVersion,
  }) {
    final needle = utf8.encode(domain);
    final start = math.max(0, bytes.length - _opsetPatchTailBytes);
    for (var i = start; i <= bytes.length - needle.length; i++) {
      var matched = true;
      for (var j = 0; j < needle.length; j++) {
        if (bytes[i + j] != needle[j]) {
          matched = false;
          break;
        }
      }
      if (!matched) continue;

      final end = math.min(bytes.length - 1, i + needle.length + 8);
      for (var j = i + needle.length; j < end; j++) {
        if (bytes[j] == 0x10 && bytes[j + 1] > maxVersion) {
          bytes[j + 1] = maxVersion;
          return;
        }
      }
    }
  }

  List<OnnxTaggerTag> _buildTags({
    required List<OnnxTaggerLabel> labels,
    required List<double> scores,
    required double generalThreshold,
    required double characterThreshold,
    required bool includeRatings,
  }) {
    final count = math.min(labels.length, scores.length);
    final tags = <OnnxTaggerTag>[];
    for (var i = 0; i < count; i++) {
      final label = labels[i];
      final category = label.labelCategory;
      if (category == OnnxTaggerLabelCategory.rating && !includeRatings) {
        continue;
      }
      if (category != OnnxTaggerLabelCategory.general &&
          category != OnnxTaggerLabelCategory.character &&
          !(includeRatings && category == OnnxTaggerLabelCategory.rating)) {
        continue;
      }

      final score = scores[i];
      final effectiveThreshold = switch (category) {
        OnnxTaggerLabelCategory.character => characterThreshold,
        OnnxTaggerLabelCategory.rating => generalThreshold,
        OnnxTaggerLabelCategory.general => generalThreshold,
        OnnxTaggerLabelCategory.other => generalThreshold,
      };
      if (score < effectiveThreshold) continue;
      tags.add(
        OnnxTaggerTag(name: label.name, score: score, category: label.category),
      );
    }
    tags.sort((a, b) => b.score.compareTo(a.score));
    return tags;
  }

  List<OnnxTaggerLabel> _parseCsvLabels(String raw) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(raw).where((row) => row.isNotEmpty).toList();
    final parsed = _labelsFromCsvRows(rows);
    if (parsed.isNotEmpty) {
      return parsed;
    }

    return _labelsFromCsvRows(
      raw
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) => line.split(',').map((cell) => cell.trim()).toList())
          .toList(),
    );
  }

  List<OnnxTaggerLabel> _labelsFromCsvRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return const [];
    }

    final header = rows.first.map((e) => e.toString().toLowerCase()).toList();
    final hasHeader =
        header.contains('name') ||
        header.contains('tag') ||
        header.contains('category');
    final headerNameIndex = hasHeader
        ? math.max(header.indexOf('name'), header.indexOf('tag'))
        : -1;
    final nameIndex = headerNameIndex >= 0
        ? headerNameIndex
        : rows.first.length > 1
        ? 1
        : 0;
    final categoryIndex = hasHeader ? header.indexOf('category') : 2;
    final dataRows = hasHeader ? rows.skip(1) : rows;

    return dataRows
        .map((row) {
          if (row.length <= nameIndex) {
            return null;
          }
          final name = row[nameIndex].toString().trim();
          if (name.isEmpty) {
            return null;
          }
          final category = categoryIndex >= 0 && row.length > categoryIndex
              ? row[categoryIndex].toString().trim()
              : null;
          return OnnxTaggerLabel(name: name, category: category);
        })
        .whereType<OnnxTaggerLabel>()
        .toList();
  }

  List<OnnxTaggerLabel> _parseTextLabels(String raw) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((line) {
          final parts = line.split(RegExp(r'[\t,]'));
          return OnnxTaggerLabel(name: parts.first.trim());
        })
        .toList();
  }

  List<OnnxTaggerLabel> _parseJsonLabels(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .map((item) {
            if (item is String) {
              return OnnxTaggerLabel(name: item.trim());
            }
            if (item is Map<String, dynamic>) {
              final name = (item['name'] ?? item['tag'] ?? item['label'])
                  ?.toString()
                  .trim();
              if (name == null || name.isEmpty) {
                return null;
              }
              return OnnxTaggerLabel(
                name: name,
                category: item['category']?.toString(),
              );
            }
            return null;
          })
          .whereType<OnnxTaggerLabel>()
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final vocabularyLabels = _parseVocabularyLabels(decoded);
      if (vocabularyLabels.isNotEmpty) {
        return vocabularyLabels;
      }

      final numericKeys =
          decoded.keys.map(int.tryParse).whereType<int>().toList()..sort();
      if (numericKeys.isNotEmpty) {
        return numericKeys
            .map((index) {
              final item = decoded[index.toString()];
              if (item is String) {
                final name = item.trim();
                return name.isEmpty ? null : OnnxTaggerLabel(name: name);
              }
              if (item is Map<String, dynamic>) {
                final name = (item['tag'] ?? item['name'] ?? item['label'])
                    ?.toString()
                    .trim();
                if (name == null || name.isEmpty) {
                  return null;
                }
                return OnnxTaggerLabel(
                  name: name,
                  category: item['category']?.toString(),
                );
              }
              return null;
            })
            .whereType<OnnxTaggerLabel>()
            .toList();
      }

      final labels = decoded['labels'] ?? decoded['tags'];
      if (labels is List) {
        return labels
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .map((item) => OnnxTaggerLabel(name: item))
            .toList();
      }
    }
    return const [];
  }

  List<OnnxTaggerLabel> _parseVocabularyLabels(Map<String, dynamic> decoded) {
    final labelsByIndex = <int, String>{};
    final idxToTag = decoded['idx_to_tag'];
    if (idxToTag is Map) {
      for (final entry in idxToTag.entries) {
        final index = int.tryParse(entry.key.toString());
        final tag = entry.value?.toString().trim();
        if (index != null && tag != null && tag.isNotEmpty) {
          labelsByIndex[index] = tag;
        }
      }
    } else if (idxToTag is List) {
      for (var i = 0; i < idxToTag.length; i++) {
        final tag = idxToTag[i]?.toString().trim();
        if (tag != null && tag.isNotEmpty) {
          labelsByIndex[i] = tag;
        }
      }
    }

    if (labelsByIndex.isEmpty) {
      final tagToIdx = decoded['tag_to_idx'];
      if (tagToIdx is Map) {
        for (final entry in tagToIdx.entries) {
          final index = int.tryParse(entry.value.toString());
          final tag = entry.key.toString().trim();
          if (index != null && tag.isNotEmpty) {
            labelsByIndex[index] = tag;
          }
        }
      }
    }

    if (labelsByIndex.isEmpty) {
      return const [];
    }

    final tagToCategory = _scalarStringMap(decoded['tag_to_category']);
    final categories = _scalarStringMap(decoded['categories']);
    final sortedIndexes = labelsByIndex.keys.toList()..sort();
    return sortedIndexes.map((index) {
      final name = labelsByIndex[index]!;
      final rawCategory = tagToCategory[name];
      final category = rawCategory == null
          ? null
          : categories[rawCategory] ?? rawCategory;
      return OnnxTaggerLabel(name: name, category: category);
    }).toList();
  }

  Map<String, String> _scalarStringMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is String || value is num || value is bool) {
        final normalized = value.toString().trim();
        if (normalized.isNotEmpty) {
          result[entry.key.toString()] = normalized;
        }
      }
    }
    return result;
  }
}
