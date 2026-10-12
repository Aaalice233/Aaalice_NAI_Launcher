import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';
import 'save_name_context.dart';
import 'save_name_template.dart';
import 'save_path_sanitizer.dart';

enum SaveFolderPreset {
  byDate('{date}'),
  byMonth('{year}-{month}'),
  byYearMonth('{year}/{month}'),
  none('');

  const SaveFolderPreset(this.template);

  final String template;

  static SaveFolderPreset? match(String template) {
    for (final preset in values) {
      if (preset.template == template) return preset;
    }
    return null;
  }
}

enum SaveFileNamePreset {
  timeSeed('{time}{seed|pre:-}'),
  dateTimeSeed('{date}_{time}{seed|pre:-}'),
  promptSeed('{prompt}{seed|pre: s-}');

  const SaveFileNamePreset(this.template);

  final String template;

  static SaveFileNamePreset? match(String template) {
    for (final preset in values) {
      if (preset.template == template) return preset;
    }
    return null;
  }
}

/// 图库根目录下的相对位置：逐级子文件夹与不含扩展名的文件名。
final class GalleryFileTarget {
  const GalleryFileTarget({required this.folders, required this.stem});

  final List<String> folders;
  final String stem;

  String get relativeFileName => [...folders, '$stem.png'].join('/');
}

/// 图库保存的子文件夹规则与文件名规则，二者共用同一套模板语法。
@immutable
final class ImageSaveNaming {
  const ImageSaveNaming({
    this.folderTemplate = defaultFolderTemplate,
    this.fileNameTemplate = defaultFileNameTemplate,
  });

  static const String defaultFolderTemplate = '{date}';
  static const String defaultFileNameTemplate = '{time}{seed|pre:-}';
  static const ImageSaveNaming standard = ImageSaveNaming();

  /// 空串表示直接保存在图库根目录。
  final String folderTemplate;

  /// 渲染结果为空时按 [defaultFileNameTemplate] 命名。
  final String fileNameTemplate;

  /// 沿用来源文件名的保存只渲染子文件夹，此时传 `includeFileName: false`。
  bool readsMetadata({bool includeFileName = true}) =>
      _compiled.folder.readsMetadata ||
      (includeFileName && _compiled.fileName.readsMetadata);

  bool readsDimensions({bool includeFileName = true}) =>
      _compiled.folder.readsDimensions ||
      (includeFileName && _compiled.fileName.readsDimensions);

  /// 文件名按时刻区分却没有任何日期字段时，不同日期的图片会混在同一处。
  bool get omitsDate =>
      !_compiled.folder.readsDate &&
      !_compiled.fileName.readsDate &&
      _compiled.fileName.tokens.contains(SaveNameToken.time);

  /// [preferredFileName] 用于派生副本等沿用来源文件名的保存，只套用子文件夹规则；
  /// 截短时 [protectedSuffix] 原样保留。
  GalleryFileTarget resolve(
    SaveNameContext context, {
    String? preferredFileName,
    String protectedSuffix = '',
  }) => GalleryFileTarget(
    folders: folderSegments(context),
    stem: preferredFileName == null
        ? fileStem(context)
        : _preferredStem(preferredFileName, context, protectedSuffix),
  );

  List<String> folderSegments(SaveNameContext context) => [
    for (final raw in _compiled.folder.renderSegments(context))
      if (SavePathSanitizer.segment(raw) case final segment
          when segment.isNotEmpty)
        segment,
  ];

  String fileStem(SaveNameContext context) {
    final stem = SavePathSanitizer.segment(_compiled.fileName.render(context));
    if (stem.isNotEmpty) return stem;
    return SavePathSanitizer.segment(_defaultFileName.render(context));
  }

  String _preferredStem(
    String fileName,
    SaveNameContext context,
    String protectedSuffix,
  ) {
    final leaf = fileName.split(RegExp(r'[/\\]')).last;
    final dot = leaf.lastIndexOf('.');
    final stem = SavePathSanitizer.segment(
      dot > 0 ? leaf.substring(0, dot) : leaf,
      protectedSuffix: protectedSuffix,
    );
    return stem.isNotEmpty ? stem : fileStem(context);
  }

  // 预览随输入逐字创建实例，弱引用缓存让解析结果跟着实例一起回收。
  static final Expando<_CompiledNaming> _cache = Expando('ImageSaveNaming');

  _CompiledNaming get _compiled => _cache[this] ??= _CompiledNaming(
    folder: _parseOrDefault(folderTemplate, defaultFolderTemplate),
    fileName: _parseOrDefault(fileNameTemplate, defaultFileNameTemplate),
  );

  static final SaveNameTemplate _defaultFileName = SaveNameTemplate.parse(
    defaultFileNameTemplate,
  );

  // 其他设备同步来的新版模板可能含本版本不认识的字段，按默认规则保存而不是失败。
  static SaveNameTemplate _parseOrDefault(String template, String fallback) {
    try {
      return SaveNameTemplate.parse(template);
    } on SaveNameTemplateException catch (error) {
      AppLogger.w(
        'Invalid save naming template "$template": $error',
        'ImageSaveNaming',
      );
      return SaveNameTemplate.parse(fallback);
    }
  }

  ImageSaveNaming copyWith({
    String? folderTemplate,
    String? fileNameTemplate,
  }) => ImageSaveNaming(
    folderTemplate: folderTemplate ?? this.folderTemplate,
    fileNameTemplate: fileNameTemplate ?? this.fileNameTemplate,
  );

  @override
  bool operator ==(Object other) =>
      other is ImageSaveNaming &&
      other.folderTemplate == folderTemplate &&
      other.fileNameTemplate == fileNameTemplate;

  @override
  int get hashCode => Object.hash(folderTemplate, fileNameTemplate);
}

final class _CompiledNaming {
  const _CompiledNaming({required this.folder, required this.fileName});

  final SaveNameTemplate folder;
  final SaveNameTemplate fileName;
}
