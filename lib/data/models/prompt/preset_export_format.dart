import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'preset_export_format.freezed.dart';
part 'preset_export_format.g.dart';

/// 预设文件扩展名常量
const String kNaiv4presetExtension = 'naiv4preset';

/// 预设 Bundle 文件扩展名常量
const String kNaiv4presetbundleExtension = 'naiv4presetbundle';

/// 预设导出格式枚举
///
/// 定义预设数据导出的不同格式
@HiveType(typeId: 40)
enum PresetExportFormat {
  /// Bundle 格式 - 导出为 .naiv4presetbundle 打包文件
  /// 支持多个预设同时导出
  @HiveField(0)
  bundle,

  /// JSON 格式 - 导出为 JSON 文件
  /// 包含完整的预设配置数据
  @HiveField(1)
  json,

  /// 纯编码格式 - 仅导出预设编码数据 (Base64)
  /// 用于与其他系统交换预设数据
  @HiveField(2)
  encoding,
}

/// PresetExportFormat 扩展方法
extension PresetExportFormatExtension on PresetExportFormat {
  /// 获取导出格式的文件扩展名
  String get fileExtension {
    switch (this) {
      case PresetExportFormat.bundle:
        return kNaiv4presetbundleExtension;
      case PresetExportFormat.json:
        return 'json';
      case PresetExportFormat.encoding:
        return 'txt';
    }
  }

  /// 获取导出格式的 MIME 类型
  String get mimeType {
    switch (this) {
      case PresetExportFormat.bundle:
        return 'application/json';
      case PresetExportFormat.json:
        return 'application/json';
      case PresetExportFormat.encoding:
        return 'text/plain';
    }
  }

  /// 获取导出格式的显示名称
  String get displayName {
    switch (this) {
      case PresetExportFormat.bundle:
        return 'Preset Bundle';
      case PresetExportFormat.json:
        return 'JSON';
      case PresetExportFormat.encoding:
        return 'Raw Encoding';
    }
  }

  /// 是否支持多预设导出
  bool get supportsMultiple => this == PresetExportFormat.bundle;
}

/// 预设导出选项数据模型
///
/// 用于配置预设导出操作的各项参数
/// 使用 Freezed 生成不可变数据类，支持 Hive 持久化
@HiveType(typeId: 41)
@freezed
class PresetExportOptions with _$PresetExportOptions {
  const PresetExportOptions._();

  const factory PresetExportOptions({
    /// 导出格式
    @HiveField(0) @Default(PresetExportFormat.bundle) PresetExportFormat format,

    /// 是否包含预设完整数据
    /// - true: 包含完整的预设配置数据
    /// - false: 仅包含元数据
    @HiveField(1) @Default(true) bool includeFullData,

    /// 导出文件名（不含扩展名）
    /// 如果为空，将自动生成文件名
    @HiveField(2) String? fileName,

    /// 是否包含缩略图或预览数据
    /// 控制是否在导出数据中包含预览相关信息
    @HiveField(3) @Default(true) bool includePreview,

    /// 是否压缩导出数据
    /// 仅适用于 bundle 格式
    @HiveField(4) @Default(false) bool compress,

    /// 数据格式版本号
    /// 用于未来兼容性和迁移
    @HiveField(5) @Default(1) int version,

    /// 是否包含创建时间
    @HiveField(6) @Default(true) bool includeCreatedAt,

    /// 是否包含更新时间
    @HiveField(7) @Default(true) bool includeUpdatedAt,

    /// 导出描述/备注
    @HiveField(8) String? description,
  }) = _PresetExportOptions;

  factory PresetExportOptions.fromJson(Map<String, dynamic> json) =>
      _$PresetExportOptionsFromJson(json);

  /// 创建用于 Bundle 导出的选项
  factory PresetExportOptions.bundle({
    String? fileName,
    bool includePreview = true,
    bool compress = false,
    String? description,
  }) {
    return PresetExportOptions(
      format: PresetExportFormat.bundle,
      includeFullData: true,
      fileName: fileName,
      includePreview: includePreview,
      compress: compress,
      description: description,
    );
  }

  /// 创建用于 JSON 导出的选项
  factory PresetExportOptions.json({
    String? fileName,
    bool includePreview = true,
    String? description,
  }) {
    return PresetExportOptions(
      format: PresetExportFormat.json,
      includeFullData: true,
      fileName: fileName,
      includePreview: includePreview,
      description: description,
    );
  }

  /// 创建用于纯编码导出的选项
  factory PresetExportOptions.encoding({
    String? fileName,
    String? description,
  }) {
    return PresetExportOptions(
      format: PresetExportFormat.encoding,
      includeFullData: true,
      fileName: fileName,
      includePreview: false,
      description: description,
    );
  }

  /// 获取完整文件名（含扩展名）
  String getFullFileName(String defaultName) {
    final baseName = fileName?.trim() ?? defaultName;
    return '$baseName.${format.fileExtension}';
  }

  /// 验证导出选项是否有效
  bool get isValid {
    return true;
  }

  /// 获取验证错误信息
  String? get validationError {
    return null;
  }

  /// 更新导出格式
  PresetExportOptions withFormat(PresetExportFormat newFormat) {
    return copyWith(format: newFormat);
  }

  /// 切换完整数据包含状态
  PresetExportOptions toggleIncludeFullData() {
    return copyWith(includeFullData: !includeFullData);
  }

  /// 切换预览包含状态
  PresetExportOptions toggleIncludePreview() {
    return copyWith(includePreview: !includePreview);
  }

  /// 切换压缩状态
  PresetExportOptions toggleCompress() {
    return copyWith(compress: !compress);
  }

  /// 更新文件名
  PresetExportOptions withFileName(String? name) {
    return copyWith(fileName: name);
  }

  /// 更新描述
  PresetExportOptions withDescription(String? desc) {
    return copyWith(description: desc);
  }
}
