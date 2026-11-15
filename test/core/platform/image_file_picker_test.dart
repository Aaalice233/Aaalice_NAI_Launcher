import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/image_file_picker.dart';

import '../../helpers/fake_save_file_picker.dart';

void main() {
  test('始终关闭 file_picker 的图片压缩', () async {
    final picker = _RecordingFilePicker();
    useFakeFilePicker(picker);

    await pickImageFiles();
    await pickImageFiles(allowMultiple: true, withData: true);

    expect(picker.calls, hasLength(2));
    for (final call in picker.calls) {
      expect(call.type, FileType.image);
      expect(call.allowCompression, isFalse);
      expect(call.compressionQuality, 0);
    }
  });

  test('透传多选与预读字节参数，并原样返回选择结果', () async {
    final selected = FilePickerResult([
      PlatformFile(name: 'source.png', size: 0, path: '/tmp/source.png'),
    ]);
    final picker = _RecordingFilePicker(result: selected);
    useFakeFilePicker(picker);

    expect(await pickImageFiles(), same(selected));
    expect(
      await pickImageFiles(allowMultiple: true, withData: true),
      same(selected),
    );

    expect(picker.calls[0].allowMultiple, isFalse);
    expect(picker.calls[0].withData, isFalse);
    expect(picker.calls[1].allowMultiple, isTrue);
    expect(picker.calls[1].withData, isTrue);
  });
}

typedef _PickCall = ({
  FileType type,
  bool allowCompression,
  int compressionQuality,
  bool allowMultiple,
  bool withData,
});

class _RecordingFilePicker extends FilePicker {
  _RecordingFilePicker({this.result});

  final FilePickerResult? result;
  final List<_PickCall> calls = [];

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    calls.add((
      type: type,
      allowCompression: allowCompression,
      compressionQuality: compressionQuality,
      allowMultiple: allowMultiple,
      withData: withData,
    ));
    return result;
  }
}
