/// 文件选择类型枚举
enum ImagePickerType {
  /// 图像选择（仅图片格式）
  image,

  /// 文件选择（需配合 allowedExtensions）
  file,

  /// 目录选择
  directory,
}
