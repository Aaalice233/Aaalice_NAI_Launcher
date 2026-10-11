import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

typedef SaveFileRequest = ({String? fileName, List<String>? allowedExtensions});

/// Answers save and folder dialogs with fixed paths and records the requests.
class FakeSaveFilePicker extends FilePicker {
  FakeSaveFilePicker({this.savePath, this.directoryPath});

  String? savePath;
  String? directoryPath;
  final List<SaveFileRequest> saveRequests = [];

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    saveRequests.add((
      fileName: fileName,
      allowedExtensions: allowedExtensions,
    ));
    return savePath;
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => directoryPath;
}

/// Installs [picker] as [FilePicker.platform] until the current test ends.
void useFakeFilePicker(FilePicker picker) {
  FilePicker? original;
  try {
    original = FilePicker.platform;
  } catch (_) {
    original = null;
  }
  FilePicker.platform = picker;
  addTearDown(() {
    if (original != null) FilePicker.platform = original;
  });
}
