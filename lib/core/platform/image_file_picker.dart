import 'package:file_picker/file_picker.dart';

// file_picker 默认在 Android 上把所选图片重编码为质量 30 的 JPEG
Future<FilePickerResult?> pickImageFiles({
  bool allowMultiple = false,
  bool withData = false,
}) {
  return FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: allowMultiple,
    withData: withData,
    // 两项都关：插件改动任一参数语义都不会恢复压缩
    allowCompression: false,
    compressionQuality: 0,
  );
}
