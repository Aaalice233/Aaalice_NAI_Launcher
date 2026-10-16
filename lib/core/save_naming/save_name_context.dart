import '../../data/models/gallery/nai_image_metadata.dart';
import '../constants/api_constants.dart';
import 'save_name_template.dart';

/// 一张待保存图片在模板里能取到的字段。
final class SaveNameContext implements SaveNameValues {
  const SaveNameContext({
    required this.createdAt,
    this.metadata,
    this.imageId,
    this.index,
    this.width,
    this.height,
  });

  /// 生成时间；日期类字段都取自它。
  final DateTime createdAt;
  final NaiImageMetadata? metadata;
  final String? imageId;

  /// 本次保存中的位置，从 0 开始；模板里显示为从 1 开始。
  final int? index;

  /// 图片实际像素尺寸，优先于元数据里记录的尺寸。
  final int? width;
  final int? height;

  SaveNameContext copyWith({
    NaiImageMetadata? metadata,
    int? width,
    int? height,
  }) => SaveNameContext(
    createdAt: createdAt,
    metadata: metadata ?? this.metadata,
    imageId: imageId,
    index: index,
    width: width ?? this.width,
    height: height ?? this.height,
  );

  @override
  String valueOf(SaveNameToken token) {
    final local = createdAt.toLocal();
    return switch (token) {
      SaveNameToken.prompt => metadata?.prompt ?? '',
      SaveNameToken.seed => _seed,
      SaveNameToken.date =>
        '${_digits(local.year, 4)}-${_digits(local.month)}-${_digits(local.day)}',
      SaveNameToken.time =>
        '${_digits(local.hour)}-${_digits(local.minute)}-${_digits(local.second)}',
      SaveNameToken.year => _digits(local.year, 4),
      SaveNameToken.month => _digits(local.month),
      SaveNameToken.day => _digits(local.day),
      SaveNameToken.model => metadata?.model ?? '',
      SaveNameToken.modelName => _modelName,
      SaveNameToken.resolution =>
        _width != null && _height != null ? '${_width}x$_height' : '',
      SaveNameToken.width => _width?.toString() ?? '',
      SaveNameToken.height => _height?.toString() ?? '',
      SaveNameToken.imageIndex => index == null ? '' : '${index! + 1}',
      SaveNameToken.imageId => imageId ?? '',
      SaveNameToken.type => _generationType,
      SaveNameToken.characters => '',
    };
  }

  @override
  List<SaveNameCharacter> get characters => [
    for (final prompt in metadata?.characterPrompts ?? const <String>[])
      if (prompt.trim().isNotEmpty) SaveNameCharacter(prompt: prompt),
  ];

  String get _seed {
    final seed = metadata?.seed;
    return seed == null || seed < 0 ? '' : '$seed';
  }

  String get _modelName {
    final model = metadata?.model;
    if (model == null || model.isEmpty) return '';
    return ImageModels.modelDisplayNames[ImageModels.migrateLegacyModel(
          model,
        )] ??
        model;
  }

  int? get _width => _positive(width) ?? _positive(metadata?.width);

  int? get _height => _positive(height) ?? _positive(metadata?.height);

  // 只取元数据能确定的生成方式，取值与 NovelAI 官网的图片标签一致；文生图为空。
  String get _generationType {
    final metadata = this.metadata;
    if (metadata == null) return '';
    final model = metadata.model;
    if (model != null && ImageModels.isInpaintingModel(model)) {
      return 'inpaint';
    }
    if (metadata.isImg2Img) return 'image2image';
    if (metadata.vibeReferences.isNotEmpty) return 'vibe-transfer';
    return '';
  }

  static int? _positive(int? value) =>
      value != null && value > 0 ? value : null;

  static String _digits(int value, [int width = 2]) =>
      value.toString().padLeft(width, '0');
}
