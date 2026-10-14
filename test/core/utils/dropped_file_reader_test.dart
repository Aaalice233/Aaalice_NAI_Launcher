import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/share_temp_directories.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../helpers/shared_compute_gate.dart';
import '../../helpers/webp_metadata_fixture.dart';

void main() {
  group('DroppedFileReader', () {
    test('issues every native read before returning control', () async {
      final pngBytes = Uint8List.fromList([1, 2, 3]);
      final reader = _SessionBoundDataReader(pngBytes: pngBytes);

      final pending = DroppedFileReader.read(reader);
      reader.endSession();

      expect(reader.requests, {
        'fileUri',
        'suggestedName',
        'png',
        'jpeg',
        'uri',
        'html',
        'plainText',
      });
      final result = await pending;
      expect(result!.bytes, pngBytes);
      expect(reader.lateRequests, isEmpty);
    });

    test('closes representations that were requested but never read', () async {
      final reader = _SessionBoundDataReader(pngBytes: Uint8List(4));

      await DroppedFileReader.read(reader, allowRemoteImages: false);
      await Future<void>.delayed(Duration.zero);

      expect(reader.jpegCallbackFinished, isTrue);
      expect(reader.jpegReads, 0);
    });

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

    test('prefers remote original over a synthesized Windows bitmap', () async {
      final remoteBytes = Uint8List.fromList([1, 2, 3, 4]);
      final directBytes = Uint8List.fromList([9, 8, 7]);
      final server = await _startImageServer(remoteBytes);
      addTearDown(() => server.close(force: true));
      final uri = Uri.parse(
        'http://${server.address.address}:${server.port}/original.png',
      );
      final reader = _ImageAndUriDataReader(
        uri: uri,
        imageBytes: directBytes,
        synthesizedImage: true,
      );

      final result = await DroppedFileReader.read(reader);

      expect(result, isNotNull);
      expect(result!.bytes, remoteBytes);
      expect(result.sourceUri, uri);
    });

    test('keeps a real image representation ahead of its remote URL', () async {
      final remoteBytes = Uint8List.fromList([1, 2, 3, 4]);
      final directBytes = Uint8List.fromList([9, 8, 7]);
      final server = await _startImageServer(remoteBytes);
      addTearDown(() => server.close(force: true));
      final uri = Uri.parse(
        'http://${server.address.address}:${server.port}/original.png',
      );
      final reader = _ImageAndUriDataReader(
        uri: uri,
        imageBytes: directBytes,
        synthesizedImage: false,
      );

      final result = await DroppedFileReader.read(reader);

      expect(result, isNotNull);
      expect(result!.bytes, directBytes);
      expect(result.sourceUri, isNull);
    });

    test(
      'does not await Discord CDN when real image bytes are available',
      () async {
        final directBytes = Uint8List.fromList([9, 8, 7]);
        final proxyUri = Uri.parse(
          'https://media.discordapp.net/attachments/1/2/image.png'
          '?ex=abc&is=def&hm=123&format=webp&quality=lossless',
        );
        final reader = _ImageAndUriDataReader(
          uri: proxyUri,
          imageBytes: directBytes,
          synthesizedImage: false,
        );

        final stopwatch = Stopwatch()..start();
        final result = await DroppedFileReader.read(reader);
        stopwatch.stop();

        expect(result, isNotNull);
        expect(result!.bytes, directBytes);
        expect(result.metadataBytes, isNull);
        expect(result.sourceUri?.host, 'cdn.discordapp.com');
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      },
    );

    test(
      'restores Discord media proxy attachment URLs to the CDN original',
      () {
        final proxyUri = Uri.parse(
          'https://media.discordapp.net/attachments/1/2/image.png'
          '?ex=abc&is=def&hm=123&=&format=webp&quality=lossless'
          '&width=1024&height=768',
        );

        final normalized = DroppedFileReader.normalizeRemoteImageUri(proxyUri);

        expect(normalized.host, 'cdn.discordapp.com');
        expect(normalized.path, '/attachments/1/2/image.png');
        expect(normalized.queryParameters, {
          'ex': 'abc',
          'is': 'def',
          'hm': '123',
        });
      },
    );

    test('builds a bounded lossless Discord preview URL', () {
      final originalUri = Uri.parse(
        'https://cdn.discordapp.com/attachments/1/2/image.png'
        '?ex=abc&is=def&hm=123',
      );

      final previewUri = DroppedFileReader.buildDiscordPreviewUri(originalUri);

      expect(previewUri.host, 'media.discordapp.net');
      expect(previewUri.path, '/attachments/1/2/image.png');
      expect(previewUri.queryParameters, {
        'ex': 'abc',
        'is': 'def',
        'hm': '123',
        'format': 'webp',
        'quality': 'lossless',
        'width': '512',
        'height': '512',
      });
    });

    test('remote metadata probe requests and caps the byte prefix', () async {
      final sourceBytes = Uint8List.fromList(
        List<int>.generate(96 * 1024, (index) => index % 251),
      );
      String? requestedRange;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        requestedRange = request.headers.value(HttpHeaders.rangeHeader);
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes 0-${sourceBytes.length - 1}/${sourceBytes.length}',
        );
        request.response.add(sourceBytes);
        await request.response.close();
      });
      final uri = Uri.parse(
        'http://${server.address.address}:${server.port}/original.png',
      );

      final result = await DroppedFileReader.downloadRemoteMetadataPrefix(uri);

      expect(
        requestedRange,
        'bytes=0-${DroppedFileReader.discordMetadataProbeBytes - 1}',
      );
      expect(result, hasLength(DroppedFileReader.discordMetadataProbeBytes));
      expect(
        result,
        orderedEquals(
          sourceBytes.sublist(0, DroppedFileReader.discordMetadataProbeBytes),
        ),
      );
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

    test('keeps reading when the suggested name lookup fails', () async {
      final bytes = buildNovelAiWebpFixture(
        comment: const {'prompt': 'clipboard fixture'},
      );
      final reader = _FailingSuggestedNameWebpDataReader(
        bytes,
        fileName: 'clipboard.WEBP',
      );

      final result = await DroppedFileReader.read(
        reader,
        allowRemoteImages: false,
      );

      expect(result?.fileName, 'clipboard.WEBP');
      expect(result?.bytes, bytes);
    });

    test('reads a dropped local file behind the shared compute gate', () async {
      final directory = await Directory.systemTemp.createTemp('drop-local-');
      addTearDown(() => directory.delete(recursive: true));
      final bytes = buildNovelAiWebpFixture(
        comment: const {'prompt': 'local fixture'},
      );
      final file = File('${directory.path}${Platform.pathSeparator}drop.webp');
      await file.writeAsBytes(bytes);

      final result = await expectQueuedBehindSharedComputeGate(
        () => DroppedFileReader.read(
          _FileUriDataReader(file.uri),
          allowRemoteImages: false,
        ),
      );

      expect(result?.fileName, 'drop.webp');
      expect(result?.bytes, bytes);
      expect(result?.sourcePath, file.path);
    });

    test('a file the launcher exported is read without a source', () async {
      final directory = await Directory.systemTemp.createTemp('drop-export-');
      addTearDown(() => directory.delete(recursive: true));
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TemporaryPathProvider(directory.path);
      addTearDown(() => PathProviderPlatform.instance = original);
      final exports = await ShareTempDirectories.resolve(
        ShareTempDirectories.dragExport,
      );
      final bytes = buildNovelAiWebpFixture(
        comment: const {'prompt': 'exported fixture'},
      );
      final file = File(p.join(exports.path, 'run_a', 'item_a', 'drop.webp'));
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);

      final result = await DroppedFileReader.read(
        _FileUriDataReader(file.uri),
        allowRemoteImages: false,
      );

      expect(result?.bytes, bytes);
      expect(result?.sourcePath, isNull);
      expect(result?.sourceUri, isNull);
    });
  });
}

class _TemporaryPathProvider extends PathProviderPlatform {
  _TemporaryPathProvider(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

Future<HttpServer> _startImageServer(Uint8List bytes) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.headers.contentType = ContentType('image', 'png');
    request.response.add(bytes);
    await request.response.close();
  });
  return server;
}

/// 只声明 [formats] 的拖入项；读值、读文件默认都不提供。
class _StubDataReader extends Fake implements DataReader {
  _StubDataReader(this.formats);

  final List<DataFormat> formats;

  @override
  bool canProvide(DataFormat format) =>
      formats.any((provided) => identical(provided, format));

  @override
  List<DataFormat> getFormats(List<DataFormat> allFormats) =>
      allFormats.where(canProvide).toList(growable: false);

  @override
  ReadProgress? getValue<T extends Object>(
    ValueFormat<T> format,
    AsyncValueChanged<T?> onValue, {
    ValueChanged<Object>? onError,
  }) => null;

  @override
  ReadProgress? getFile(
    FileFormat? format,
    AsyncValueChanged<DataReaderFile> onFile, {
    ValueChanged<Object>? onError,
    bool allowVirtualFiles = true,
    bool synthesizeFilesFromURIs = true,
  }) => null;

  @override
  bool isSynthesized(DataFormat format) => false;

  @override
  bool isVirtual(DataFormat format) => false;

  @override
  Future<String?> getSuggestedName() async => null;

  @override
  Future<VirtualFileReceiver?> getVirtualFileReceiver({
    FileFormat? format,
  }) async => null;

  @override
  List<PlatformFormat> get platformFormats => const [];

  ReadProgress _deliver(Future<void> Function() delivery) {
    Future<void>.microtask(delivery);
    return _CompletedReadProgress();
  }
}

class _PlainTextDataReader extends _StubDataReader {
  _PlainTextDataReader(this.text) : super([Formats.plainText]);

  final String text;

  @override
  ReadProgress? getValue<T extends Object>(
    ValueFormat<T> format,
    AsyncValueChanged<T?> onValue, {
    ValueChanged<Object>? onError,
  }) => identical(format, Formats.plainText)
      ? _deliver(() async => onValue(text as T))
      : null;
}

class _ImageAndUriDataReader extends _StubDataReader {
  _ImageAndUriDataReader({
    required this.uri,
    required this.imageBytes,
    required this.synthesizedImage,
  }) : super([Formats.png, Formats.uri]);

  final Uri uri;
  final Uint8List imageBytes;
  final bool synthesizedImage;

  @override
  ReadProgress? getValue<T extends Object>(
    ValueFormat<T> format,
    AsyncValueChanged<T?> onValue, {
    ValueChanged<Object>? onError,
  }) => identical(format, Formats.uri)
      ? _deliver(() async => onValue(NamedUri(uri) as T))
      : null;

  @override
  ReadProgress? getFile(
    FileFormat? format,
    AsyncValueChanged<DataReaderFile> onFile, {
    ValueChanged<Object>? onError,
    bool allowVirtualFiles = true,
    bool synthesizeFilesFromURIs = true,
  }) => identical(format, Formats.png)
      ? _deliver(
          () async => onFile(
            _MemoryDataReaderFile(imageBytes, fileName: 'preview.png'),
          ),
        )
      : null;

  @override
  bool isSynthesized(DataFormat format) =>
      identical(format, Formats.png) && synthesizedImage;

  @override
  Future<String?> getSuggestedName() async => 'preview.png';
}

class _WebpDataReader extends _StubDataReader {
  _WebpDataReader(this.bytes, {required this.fileName}) : super([Formats.webp]);

  final Uint8List bytes;
  final String fileName;

  @override
  ReadProgress? getFile(
    FileFormat? format,
    AsyncValueChanged<DataReaderFile> onFile, {
    ValueChanged<Object>? onError,
    bool allowVirtualFiles = true,
    bool synthesizeFilesFromURIs = true,
  }) => identical(format, Formats.webp)
      ? _deliver(
          () async => onFile(_MemoryDataReaderFile(bytes, fileName: fileName)),
        )
      : null;

  @override
  Future<String?> getSuggestedName() async => fileName;
}

class _FailingSuggestedNameWebpDataReader extends _WebpDataReader {
  _FailingSuggestedNameWebpDataReader(super.bytes, {required super.fileName});

  @override
  Future<String?> getSuggestedName() =>
      Future<String?>.error(const FileSystemException('name lookup failed'));
}

class _FileUriDataReader extends _StubDataReader {
  _FileUriDataReader(this.uri) : super([Formats.fileUri]);

  final Uri uri;

  @override
  ReadProgress? getValue<T extends Object>(
    ValueFormat<T> format,
    AsyncValueChanged<T?> onValue, {
    ValueChanged<Object>? onError,
  }) => identical(format, Formats.fileUri)
      ? _deliver(() async => onValue(uri as T))
      : null;
}

/// Mirrors a drop session: requests made after [endSession] fail like a
/// disposed native reader.
class _SessionBoundDataReader extends _StubDataReader {
  _SessionBoundDataReader({required this.pngBytes})
    : super([..._values.keys, Formats.png, Formats.jpeg]);

  static final Map<DataFormat, String> _values = {
    Formats.fileUri: 'fileUri',
    Formats.uri: 'uri',
    Formats.htmlText: 'html',
    Formats.plainText: 'plainText',
  };

  final Uint8List pngBytes;
  final requests = <String>{};
  final lateRequests = <String>[];
  var jpegCallbackFinished = false;
  var jpegReads = 0;
  var _sessionEnded = false;

  void endSession() => _sessionEnded = true;

  void _record(String name) {
    if (_sessionEnded) {
      lateRequests.add(name);
      throw StateError('Reader not found: $name');
    }
    requests.add(name);
  }

  @override
  ReadProgress? getValue<T extends Object>(
    ValueFormat<T> format,
    AsyncValueChanged<T?> onValue, {
    ValueChanged<Object>? onError,
  }) {
    final name = _values[format];
    if (name == null) return null;
    _record(name);
    final Object value = switch (name) {
      'fileUri' => Uri.file('/dropped/readme.txt'),
      'uri' => NamedUri(Uri.parse('https://cdn.example.test/original.png')),
      _ => '<img src="https://cdn.example.test/original.png">',
    };
    return _deliver(() async => onValue(value as T));
  }

  @override
  ReadProgress? getFile(
    FileFormat? format,
    AsyncValueChanged<DataReaderFile> onFile, {
    ValueChanged<Object>? onError,
    bool allowVirtualFiles = true,
    bool synthesizeFilesFromURIs = true,
  }) {
    if (identical(format, Formats.png)) {
      _record('png');
      return _deliver(
        () async => onFile(_MemoryDataReaderFile(pngBytes, fileName: 'a.png')),
      );
    }
    if (identical(format, Formats.jpeg)) {
      _record('jpeg');
      final file = _CountingDataReaderFile(onRead: () => jpegReads++);
      return _deliver(() async {
        await onFile(file);
        jpegCallbackFinished = true;
      });
    }
    return null;
  }

  @override
  Future<String?> getSuggestedName() {
    _record('suggestedName');
    return Future.value('dropped.png');
  }
}

class _CountingDataReaderFile extends _MemoryDataReaderFile {
  _CountingDataReaderFile({required this.onRead})
    : super(Uint8List(1), fileName: 'b.jpg');

  final VoidCallback onRead;

  @override
  Future<Uint8List> readAll() {
    onRead();
    return super.readAll();
  }
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
