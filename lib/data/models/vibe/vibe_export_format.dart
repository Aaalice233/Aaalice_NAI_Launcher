import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'vibe_export_format.freezed.dart';
part 'vibe_export_format.g.dart';

/// Vibe 文件扩展名常量
const String kNaiv4vibeExtension = 'naiv4vibe';

/// Vibe Bundle 文件扩展名常量
const String kNaiv4vibebundleExtension = 'naiv4vibebundle';

/// Vibe 导出格式枚举
///
/// 定义 Vibe 数据导出的不同格式
@HiveType(typeId: 30)
enum VibeExportFormat {
  /// Bundle 格式 - 导出为 .naiv4vibebundle 打包文件
  /// 支持多个 Vibe 参考同时导出
  @HiveField(0)
  bundle,

  /// 嵌入图片格式 - 将 Vibe 数据嵌入到图片元数据中
  /// 支持导出为带 iTXt 元数据的 PNG 文件
  @HiveField(1)
  embeddedImage,

  /// 纯编码格式 - 仅导出 Vibe 编码数据 (Base64)
  /// 用于与其他系统交换 Vibe 数据
  @HiveField(2)
  encoding,
}

/// VibeExportFormat 扩展方法
extension VibeExportFormatExtension on VibeExportFormat {
  /// 获取导出格式的文件扩展名
  String get fileExtension {
    switch (this) {
      case VibeExportFormat.bundle:
        return kNaiv4vibebundleExtension;
      case VibeExportFormat.embeddedImage:
        return 'png';
      case VibeExportFormat.encoding:
        return 'txt';
    }
  }

  /// 获取导出格式的 MIME 类型
  String get mimeType {
    switch (this) {
      case VibeExportFormat.bundle:
        return 'application/json';
      case VibeExportFormat.embeddedImage:
        return 'image/png';
      case VibeExportFormat.encoding:
        return 'text/plain';
    }
  }

  /// 获取导出格式的显示名称
  String get displayName {
    switch (this) {
      case VibeExportFormat.bundle:
        return 'Vibe Bundle';
      case VibeExportFormat.embeddedImage:
        return 'PNG with Metadata';
      case VibeExportFormat.encoding:
        return 'Raw Encoding';
    }
  }

  /// 是否支持多 Vibe 导出
  bool get supportsMultiple => this == VibeExportFormat.bundle;

  /// 是否需要原始图片数据
  bool get requiresRawImage => this == VibeExportFormat.embeddedImage;
}

/// Vibe 导出选项数据模型
///
/// 用于配置 Vibe 导出操作的各项参数
/// 使用 Freezed 生成不可变数据类，支持 Hive 持久化
@HiveType(typeId: 31)
@freezed
class VibeExportOptions with _$VibeExportOptions {
  const VibeExportOptions._();

  const factory VibeExportOptions({
    /// 导出格式
    @HiveField(0) @Default(VibeExportFormat.bundle) VibeExportFormat format,

    /// 是否包含 Vibe 编码数据
    /// - true: 包含 Base64 编码的 Vibe 数据
    /// - false: 仅包含元数据
    @HiveField(1) @Default(true) bool includeEncoding,

    /// 目标图片路径（用于 embeddedImage 格式）
    /// 指定要将 Vibe 数据嵌入到的原始图片路径
    @HiveField(2) String? targetImagePath,

    /// 导出文件名（不含扩展名）
    /// 如果为空，将自动生成文件名
    @HiveField(3) String? fileName,

    /// 是否包含缩略图
    /// 控制是否在导出数据中包含缩略图数据
    @HiveField(4) @Default(true) bool includeThumbnail,

    /// 是否压缩导出数据
    /// 仅适用于 bundle 格式
    @HiveField(5) @Default(false) bool compress,

    /// 数据格式版本号
    /// 用于未来兼容性和迁移
    @HiveField(6) @Default(1) int version,
  }) = _VibeExportOptions;

  factory VibeExportOptions.fromJson(Map<String, dynamic> json) =>
      _$VibeExportOptionsFromJson(json);

  /// 创建用于 Bundle 导出的选项
  factory VibeExportOptions.bundle({
    String? fileName,
    bool includeThumbnail = true,
    bool compress = false,
  }) {
    return VibeExportOptions(
      format: VibeExportFormat.bundle,
      includeEncoding: true,
      fileName: fileName,
      includeThumbnail: includeThumbnail,
      compress: compress,
    );
  }

  /// 创建用于嵌入图片导出的选项
  factory VibeExportOptions.embeddedImage({
    required String targetImagePath,
    String? fileName,
    bool includeEncoding = true,
  }) {
    return VibeExportOptions(
      format: VibeExportFormat.embeddedImage,
      targetImagePath: targetImagePath,
      fileName: fileName,
      includeEncoding: includeEncoding,
    );
  }

  /// 创建用于纯编码导出的选项
  factory VibeExportOptions.encoding({
    String? fileName,
  }) {
    return VibeExportOptions(
      format: VibeExportFormat.encoding,
      includeEncoding: true,
      fileName: fileName,
      includeThumbnail: false,
    );
  }

  /// 获取完整文件名（含扩展名）
  String getFullFileName(String defaultName) {
    final baseName = fileName?.trim() ?? defaultName;
    return '$baseName.${format.fileExtension}';
  }

  /// 验证导出选项是否有效
  bool get isValid {
    // embeddedImage 格式需要目标图片路径
    if (format == VibeExportFormat.embeddedImage) {
      return targetImagePath != null && targetImagePath!.isNotEmpty;
    }
    return true;
  }

  /// 获取验证错误信息
  String? get validationError {
    if (format == VibeExportFormat.embeddedImage &&
        (targetImagePath == null || targetImagePath!.isEmpty)) {
      return 'Embedded image format requires a target image path';
    }
    return null;
  }

  /// 更新导出格式
  VibeExportOptions withFormat(VibeExportFormat newFormat) {
    return copyWith(format: newFormat);
  }

  /// 更新目标图片路径
  VibeExportOptions withTargetImagePath(String? path) {
    return copyWith(targetImagePath: path);
  }

  /// 切换编码包含状态
  VibeExportOptions toggleIncludeEncoding() {
    return copyWith(includeEncoding: !includeEncoding);
  }

  /// 切换缩略图包含状态
  VibeExportOptions toggleIncludeThumbnail() {
    return copyWith(includeThumbnail: !includeThumbnail);
  }
}
