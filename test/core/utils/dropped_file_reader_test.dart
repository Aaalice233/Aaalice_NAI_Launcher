import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../helpers/webp_metadata_fixture.dart';

void main() {
  group('DroppedFileReader', () {
    test('skips remote URL lookup when remote images are disabled', () async {
      final reader = _PlainTextDataReader(
        'https://cdn.example.test/images/copied.png',
      );

      final result = await DroppedFileReader.read(
        reader,
        allowRemoteImages: false,
      );

      expect(result, isNull);
    });

    test('reads direct clipboard WebP bytes without a file URI', () async {
      final bytes = buildNovelAiWebpFixture(
        comment: const {'prompt': 'clipboard fixture'},
      );
      final reader = _WebpDataReader(bytes, fileName: 'clipboard.WEBP');

      final result = await DroppedFileReader.read(
        reader,
        allowRemoteImages: false,
      );

      expect(result?.fileName, 'clipboard.WEBP');
      expect(result?.bytes, bytes);
      expect(result?.sourcePath, isNull);
      expect(result?.sourceUri, isNull);
    });
  });
}

class _PlainTextDataReader extends DataReader {
  _PlainTextDataReader(this.text);

  final String text;

  @override
  bool canProvide(DataFormat format) => format == Formats.plainText;

  @override
  List<DataFormat> getFormats(List<DataFormat> allFormats) {
    return allFormats
        .where((format) => format == Formats.plainText)
        .toList(growable: false);
  }

  @override
  ReadProgress? getValue<T extends Object>(
    ValueFormat<T> format,
    AsyncValueChanged<T?> onValue, {
    ValueChanged<Object>? onError,
  }) {
    if (!identical(format, Formats.plainText)) {
      return null;
    }
    Future<void>.microtask(() async {
      await onValue(text as T);
    });
    return _CompletedReadProgress();
  }

  @override
  ReadProgress? getFile(
    FileFormat? format,
    AsyncValueChanged<DataReaderFile> onFile, {
    ValueChanged<Object>? onError,
    bool allowVirtualFiles = true,
    bool synthesizeFilesFromURIs = true,
  }) {
    return null;
  }

  @override
  bool isSynthesized(DataFormat format) => false;

  @override
  bool isVirtual(DataFormat format) => false;

  @override
  Future<String?> getSuggestedName() async => null;

  @override
  Future<VirtualFileReceiver?> getVirtualFileReceiver({
    FileFormat? format,
  }) async {
    return null;
  }

  @override
  List<PlatformFormat> get platformFormats => const [];
}

class _WebpDataReader extends DataReader {
  _WebpDataReader(this.bytes, {required this.fileName});

  final Uint8List bytes;
  final String fileName;

  @override
  bool canProvide(DataFormat format) => identical(format, Formats.webp);

  @override
  List<DataFormat> getFormats(List<DataFormat> allFormats) => allFormats
      .where((format) => identical(format, Formats.webp))
      .toList(growable: false);

  @override
  ReadProgress? getFile(
    FileFormat? format,
    AsyncValueChanged<DataReaderFile> onFile, {
    ValueChanged<Object>? onError,
    bool allowVirtualFiles = true,
    bool synthesizeFilesFromURIs = true,
  }) {
    if (!identical(format, Formats.webp)) return null;
    Future<void>.microtask(
      () async => onFile(_MemoryDataReaderFile(bytes, fileName: fileName)),
    );
    return _CompletedReadProgress();
  }

  @override
  ReadProgress? getValue<T extends Object>(
    ValueFormat<T> format,
    AsyncValueChanged<T?> onValue, {
    ValueChanged<Object>? onError,
  }) => null;

  @override
  bool isSynthesized(DataFormat format) => false;

  @override
  bool isVirtual(DataFormat format) => false;

  @override
  Future<String?> getSuggestedName() async => fileName;

  @override
  Future<VirtualFileReceiver?> getVirtualFileReceiver({
    FileFormat? format,
  }) async => null;

  @override
  List<PlatformFormat> get platformFormats => const [];
}

class _MemoryDataReaderFile extends DataReaderFile {
  _MemoryDataReaderFile(this.bytes, {required this.fileName});

  final Uint8List bytes;

  @override
  final String fileName;

  @override
  int get fileSize => bytes.length;

  @override
  void close() {}

  @override
  Stream<Uint8List> getStream() => Stream.value(bytes);

  @override
  Future<Uint8List> readAll() async => bytes;
}

class _CompletedReadProgress extends ReadProgress {
  final ValueNotifier<double?> _fraction = ValueNotifier<double?>(1);
  final ValueNotifier<bool> _cancellable = ValueNotifier<bool>(false);

  @override
  ValueListenable<double?> get fraction => _fraction;

  @override
  ValueListenable<bool> get cancellable => _cancellable;

  @override
  void cancel() {}
}
