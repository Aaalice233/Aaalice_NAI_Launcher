import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path/path.dart' as p;
// ignore: implementation_imports
import 'package:onnxruntime_v2/src/bindings/onnxruntime_bindings_generated.dart'
    as bg;

import '../../core/platform/platform_capabilities.dart';
import '../../core/utils/exif_orientation.dart';
import '../../core/utils/isolate_pool.dart';
import '../../core/utils/prompt_tag_utils.dart';
import 'local_onnx_model_service.dart';
import 'local_onnx_tagger_labels.dart';
import 'local_onnx_tagger_preprocessor.dart';
import 'onnx_session_input_spec.dart';

final localOnnxTaggerServiceProvider = Provider<LocalOnnxTaggerService>((ref) {
  return const LocalOnnxTaggerService();
});

class OnnxTaggerTag {
  const OnnxTaggerTag({
    required this.name,
    required this.score,
    required this.labelCategory,
    this.category,
  });

  final String name;
  final double score;
  final String? category;
  final OnnxTaggerLabelCategory labelCategory;

  String get promptText => labelCategory == OnnxTaggerLabelCategory.artist
      ? PromptTagUtils.artistPromptTag(name)
      : name;
}

class OnnxTaggerResult {
  const OnnxTaggerResult({required this.model, required this.tags});

  final LocalOnnxModelDescriptor model;
  final List<OnnxTaggerTag> tags;

  String get prompt => tags.map((tag) => tag.promptText).join(', ');
}

// 通用、角色跟随滑块；其余分类用模型推荐值，模型未给出时版权、画师沿用角色滑块
class OnnxTaggerThresholds {
  const OnnxTaggerThresholds({
    required this.general,
    required this.character,
    this.recommended = const {},
  });

  final double general;
  final double character;
  final Map<OnnxTaggerLabelCategory, double> recommended;

  double forCategory(OnnxTaggerLabelCategory category) => switch (category) {
    OnnxTaggerLabelCategory.general => general,
    OnnxTaggerLabelCategory.character => character,
    OnnxTaggerLabelCategory.copyright ||
    OnnxTaggerLabelCategory.artist => recommended[category] ?? character,
    OnnxTaggerLabelCategory.meta ||
    OnnxTaggerLabelCategory.rating ||
    OnnxTaggerLabelCategory.other => recommended[category] ?? general,
  };
}

enum OnnxSessionLoadMode { originalFile, patchedSingleFile }

class LocalOnnxTaggerService {
  const LocalOnnxTaggerService();

  static const int _opsetPatchTailBytes = 4096;

  static OnnxLetterboxLayout debugLetterboxLayoutForTesting({
    required int sourceWidth,
    required int sourceHeight,
    required int inputSize,
  }) {
    return LocalOnnxTaggerPreprocessor.computeLetterboxLayout(
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

  /// 单次推理允许使用的 intra-op 线程数。
  ///
  /// 桌面端只占一半逻辑核心，给界面和其他后台任务留出余量；手机单核性能远低于
  /// 桌面，移动端放开到 `min(4, CPU 核数)`：既用上大核，又不至于在小核上抢占调度
  /// （推理本身已在独立 isolate 里串行执行，见 [tagImage] 的 ComputeGate）。
  static int resolveIntraOpThreadCount(
    PlatformCapabilities capabilities, {
    int? processorCount,
  }) {
    final cores = processorCount ?? Platform.numberOfProcessors;
    if (!capabilities.isMobile) {
      return math.max(1, cores ~/ 2);
    }
    return math.max(1, math.min(4, cores));
  }

  @visibleForTesting
  Future<String> ensurePatchedModelPathForTesting(String modelPath) {
    return _ensurePatchedSingleFileModelPath(modelPath);
  }

  Future<OnnxTaggerResult> tagImage({
    required Uint8List imageBytes,
    required LocalOnnxModelDescriptor model,
    double generalThreshold = 0.35,
    double characterThreshold = 0.35,
    Set<OnnxTaggerLabelCategory> categories =
        OnnxTaggerLabelCategory.defaultPromptCategories,
  }) {
    final imageData = TransferableTypedData.fromList([imageBytes]);
    final selectedCategories = Set<OnnxTaggerLabelCategory>.of(categories);
    return ComputeGate.singleTask().runIsolate(
      () => const LocalOnnxTaggerService()._tagImageInCurrentIsolate(
        imageData: imageData,
        model: model,
        generalThreshold: generalThreshold,
        characterThreshold: characterThreshold,
        categories: selectedCategories,
      ),
    );
  }

  // 十万级标签表的解析放到后台 isolate，避免卡住面板
  Future<Set<OnnxTaggerLabelCategory>> labelCategories(String labelsPath) {
    return Isolate.run(
      () async => (await OnnxTaggerLabelFiles.load(labelsPath)).categories,
      debugName: 'onnx-tagger-label-categories',
    );
  }

  Future<OnnxTaggerResult> _tagImageInCurrentIsolate({
    required TransferableTypedData imageData,
    required LocalOnnxModelDescriptor model,
    required double generalThreshold,
    required double characterThreshold,
    required Set<OnnxTaggerLabelCategory> categories,
  }) async {
    if (model.labelsPath == null || model.labelsPath!.isEmpty) {
      throw StateError(
        '模型缺少标签文件，请放置 selected_tags.csv / tags.csv / labels.txt / '
        'model_vocabulary.json / tags.json / config.json',
      );
    }

    final labelSet = await OnnxTaggerLabelFiles.load(model.labelsPath!);
    if (labelSet.labels.isEmpty) {
      throw StateError('标签文件为空: ${model.labelsPath}');
    }

    final imageBytes = imageData.materialize().asUint8List();
    final decoded = ExifOrientation.decodeUpright(imageBytes);
    if (decoded == null) {
      throw StateError('无法解码图片');
    }

    final profile = LocalOnnxTaggerPreprocessor.profileFor(model);
    // 这里跑在 `ComputeGate` 派生出来的独立 isolate 里，`debugDefaultTargetPlatform`
    // 那套 override 不会跨 isolate 传播，所以用纯 dart:io 的 `operatingSystem`。
    final options = OrtSessionOptions()
      ..setInterOpNumThreads(1)
      ..setIntraOpNumThreads(
        resolveIntraOpThreadCount(PlatformCapabilities.operatingSystem),
      )
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    final runOptions = OrtRunOptions();

    OrtSession? session;
    OrtValue? inputOrt;
    List<OrtValue?>? outputs;
    try {
      session = await _createSession(model, options);
      final inputName = _resolveInputName(session, model);
      final spec = OnnxSessionInputSpec.read(
        session,
        math.max(0, session.inputNames.indexOf(inputName)),
      );
      final input = _prepareInput(decoded, model, profile, spec);
      inputOrt = OrtValueTensor.createTensorWithDataList(
        input.data,
        input.shape,
      );
      outputs = session.run(
        runOptions,
        {inputName: inputOrt},
        _resolveOutputNames(session, model),
      );
      final scores = outputs.isNotEmpty
          ? profile.normalizeScores(_flattenScores(outputs.first?.value))
          : <double>[];
      return OnnxTaggerResult(
        model: model,
        tags: selectTags(
          labels: labelSet.labels,
          scores: scores,
          thresholds: OnnxTaggerThresholds(
            general: generalThreshold,
            character: characterThreshold,
            recommended: {
              ...profile.recommendedThresholds,
              ...labelSet.recommendedThresholds,
            },
          ),
          categories: categories,
        ),
      );
    } finally {
      for (final output in outputs ?? const <OrtValue?>[]) {
        output?.release();
      }
      inputOrt?.release();
      runOptions.release();
      if (session != null) await session.release();
      options.release();
    }
  }

  static OnnxImageInput _prepareInput(
    img.Image decoded,
    LocalOnnxModelDescriptor model,
    OnnxTaggerPreprocessProfile profile,
    OnnxSessionInputSpec spec,
  ) {
    final layout = spec.layout;
    if (layout != null && layout != profile.layout) {
      throw StateError(
        '模型输入为 ${layout.name.toUpperCase()} 布局，'
        '与识别出的 ${model.kind.name} 预处理不符，请检查模型与标签文件是否配套',
      );
    }
    return LocalOnnxTaggerPreprocessor.preprocess(
      decoded,
      model,
      inputSize: spec.squareSize,
    ).repeatedForBatch(spec.batchSize);
  }

  // 分类顺序同在线画廊的提示词类别，组内按置信度从高到低
  static List<OnnxTaggerTag> selectTags({
    required List<OnnxTaggerLabel> labels,
    required List<double> scores,
    required OnnxTaggerThresholds thresholds,
    required Set<OnnxTaggerLabelCategory> categories,
  }) {
    final count = math.min(labels.length, scores.length);
    final tags = <OnnxTaggerTag>[];
    for (var index = 0; index < count; index++) {
      final label = labels[index];
      final category = label.labelCategory;
      if (!categories.contains(category)) continue;
      final score = scores[index];
      if (score < thresholds.forCategory(category)) continue;
      tags.add(
        OnnxTaggerTag(
          name: label.name,
          score: score,
          labelCategory: category,
          category: label.category,
        ),
      );
    }

    const order = OnnxTaggerLabelCategory.promptOrder;
    int rank(OnnxTaggerLabelCategory category) {
      final position = order.indexOf(category);
      return position < 0 ? order.length : position;
    }

    tags.sort((a, b) {
      final byCategory = rank(a.labelCategory).compareTo(rank(b.labelCategory));
      return byCategory != 0 ? byCategory : b.score.compareTo(a.score);
    });
    return tags;
  }

  Future<OrtSession> _createSession(
    LocalOnnxModelDescriptor model,
    OrtSessionOptions options,
  ) async {
    final loadMode = _resolveSessionLoadMode(model);
    if (loadMode == OnnxSessionLoadMode.originalFile) {
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

    final intraOpThreads = resolveIntraOpThreadCount(
      PlatformCapabilities.operatingSystem,
    );
    statusPtr = OrtEnv.instance.ortApiPtr.ref.SetIntraOpNumThreads
        .asFunction<
          bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtSessionOptions>, int)
        >()(options, intraOpThreads);
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

    // 先只读尾部 4KB 试补：绝大多数模型的 opset 本来就在支持范围内，补丁不改
    // 任何字节，这时直接加载原文件，不再把几百 MB 到数 GB 的模型原样复制一份
    // 到临时目录（多占一倍磁盘；移动端临时目录被系统清理后还要重新复制）。
    final tailStart = math.max(0, stat.size - _opsetPatchTailBytes);
    final tailBuilder = BytesBuilder(copy: false);
    await for (final chunk in source.openRead(tailStart)) {
      tailBuilder.add(chunk);
    }
    final originalTail = tailBuilder.takeBytes();
    // `_patchUnsupportedOpsetImports` 是原地改写，必须先留一份原始副本再比对。
    final patchedTail = _patchUnsupportedOpsetImports(
      Uint8List.fromList(originalTail),
    );
    if (_bytesEqual(originalTail, patchedTail)) {
      return modelPath;
    }

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
      await _copyPatchedSingleFileModel(
        source,
        partial,
        tailStart: tailStart,
        patchedTail: patchedTail,
      );
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

  /// 尾部补丁由调用方先算出来（补丁不改字节时整段跳过复制），尾部偏移与
  /// 补丁后的字节作为参数传入。
  Future<void> _copyPatchedSingleFileModel(
    File source,
    File target, {
    required int tailStart,
    required Uint8List patchedTail,
  }) async {
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

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static OnnxSessionLoadMode _resolveSessionLoadMode(
    LocalOnnxModelDescriptor model,
  ) {
    final hasExternalData = File('${model.path}.data').existsSync();
    final lowersOpset = LocalOnnxTaggerPreprocessor.profileFor(
      model,
    ).lowersOpsetImports;
    return hasExternalData || !lowersOpset
        ? OnnxSessionLoadMode.originalFile
        : OnnxSessionLoadMode.patchedSingleFile;
  }

  String _resolveInputName(OrtSession session, LocalOnnxModelDescriptor model) {
    if (model.kind == LocalOnnxModelKind.clTaggerV2 &&
        session.inputNames.contains('pixel_values')) {
      return 'pixel_values';
    }
    return session.inputNames.isNotEmpty ? session.inputNames.first : 'input';
  }

  List<String>? _resolveOutputNames(
    OrtSession session,
    LocalOnnxModelDescriptor model,
  ) {
    if (model.kind == LocalOnnxModelKind.clTaggerV2 &&
        session.outputNames.contains('logits')) {
      return const ['logits'];
    }
    return null;
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
}
