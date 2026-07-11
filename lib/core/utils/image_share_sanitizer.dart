import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef ShareImagePrepareFunction = Future<SanitizedShareImage> Function(
  Uint8List bytes, {
  required String fileName,
  required bool stripMetadata,
});
typedef ShareImageWriteTempFileFunction = Future<File> Function(
  SanitizedShareImage image,
);
typedef ShareImageWritePreparedFileFunction = Future<File> Function(
  String cacheKey,
  SanitizedShareImage image,
);

class SanitizedShareImage {
  const SanitizedShareImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class ShareImageTransferCache {
  ShareImageTransferCache({
    required this.imageBytes,
    required this.fileName,
    this.sourceFilePath,
    ShareImagePrepareFunction? prepareImage,
    ShareImageWriteTempFileFunction? writeTempFile,
  })  : _prepareImage = prepareImage ??
            ImageShareSanitizer.prepareForCopyOrDragInBackground,
        _writeTempFile =
            writeTempFile ?? ImageShareSanitizer.writeTempShareFile;

  final Uint8List imageBytes;
  final String fileName;
  final String? sourceFilePath;
  final ShareImagePrepareFunction _prepareImage;
  final ShareImageWriteTempFileFunction _writeTempFile;

  final Map<bool, Future<SanitizedShareImage>> _preparedImages = {};
  final Map<bool, Future<File>> _preparedFiles = {};
  final Map<bool, File> _temporaryFiles = {};

  Future<SanitizedShareImage> prepareImage({
    required bool stripMetadata,
  }) {
    return _preparedImages.putIfAbsent(
      stripMetadata,
      () => _prepareImage(
        imageBytes,
        fileName: fileName,
        stripMetadata: stripMetadata,
      ),
    );
  }

  Future<File> prepareFile({
    required bool stripMetadata,
  }) {
    final sourceFile = _resolveSourceFile(stripMetadata: stripMetadata);
    if (sourceFile != null) {
      return Future.value(sourceFile);
    }

    return _preparedFiles.putIfAbsent(stripMetadata, () async {
      final prepared = await prepareImage(stripMetadata: stripMetadata);
      final file = await _writeTempFile(prepared);
      _temporaryFiles[stripMetadata] = file;
      return file;
    });
  }

  void warmUp({required bool stripMetadata}) {
    unawaited(prepareFile(stripMetadata: stripMetadata));
  }

  Future<void> dispose() async {
    for (final file in _temporaryFiles.values) {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // ignore cleanup failures in temp directory
        }
      }
    }
    _temporaryFiles.clear();
  }

  File? _resolveSourceFile({required bool stripMetadata}) {
    if (stripMetadata) return null;
    final normalizedSourceFilePath = sourceFilePath?.trim();
    if (normalizedSourceFilePath == null || normalizedSourceFilePath.isEmpty) {
      return null;
    }
    final sourceFile = File(normalizedSourceFilePath);
    if (!sourceFile.existsSync()) {
      return null;
    }
    return sourceFile;
  }
}

enum ShareImagePreparationStatus {
  notQueued,
  preparing,
  ready,
  failed,
}

class ShareImagePreparationSnapshot {
  const ShareImagePreparationSnapshot({
    required this.imageId,
    required this.stripMetadata,
    required this.status,
    this.file,
    this.error,
  });

  final String imageId;
  final bool stripMetadata;
  final ShareImagePreparationStatus status;
  final File? file;
  final Object? error;

  bool get isReady => status == ShareImagePreparationStatus.ready;
}

class ShareImagePreparationService extends ChangeNotifier {
  ShareImagePreparationService({
    ShareImagePrepareFunction? prepareImage,
    ShareImageWritePreparedFileFunction? writePreparedFile,
    this.maxConcurrentPreparations = 1,
  })  : _prepareImage = prepareImage ?? _defaultPrepareImage,
        _writePreparedFile =
            writePreparedFile ?? ImageShareSanitizer.writeCachedShareFile;

  static final ShareImagePreparationService instance =
      ShareImagePreparationService();

  final ShareImagePrepareFunction _prepareImage;
  final ShareImageWritePreparedFileFunction _writePreparedFile;
  final int maxConcurrentPreparations;

  final Map<String, _SharePreparedImageEntry> _entries = {};
  final Queue<_SharePreparationRequest> _queue =
      Queue<_SharePreparationRequest>();
  final Map<String, List<Completer<File?>>> _readyWaiters = {};
  int _activePreparations = 0;

  ShareImagePreparationSnapshot snapshotFor(
    String imageId, {
    required bool stripMetadata,
  }) {
    final variant = _entries[imageId]?.variants[stripMetadata];
    if (variant == null) {
      return ShareImagePreparationSnapshot(
        imageId: imageId,
        stripMetadata: stripMetadata,
        status: ShareImagePreparationStatus.notQueued,
      );
    }

    return ShareImagePreparationSnapshot(
      imageId: imageId,
      stripMetadata: stripMetadata,
      status: variant.status,
      file: variant.file,
      error: variant.error,
    );
  }

  File? readyFileFor(
    String imageId, {
    required bool stripMetadata,
  }) {
    final snapshot = snapshotFor(imageId, stripMetadata: stripMetadata);
    if (!snapshot.isReady) {
      return null;
    }
    return snapshot.file;
  }

  void enqueue({
    required String imageId,
    required Uint8List imageBytes,
    required String fileName,
    required bool stripMetadata,
    String? sourceFilePath,
  }) {
    final entry = _entries.putIfAbsent(
      imageId,
      () => _SharePreparedImageEntry(imageId),
    );
    final variant = entry.variants.putIfAbsent(
      stripMetadata,
      _SharePreparedVariant.new,
    );

    if (variant.status == ShareImagePreparationStatus.ready ||
        variant.status == ShareImagePreparationStatus.preparing) {
      return;
    }

    variant
      ..status = ShareImagePreparationStatus.preparing
      ..error = null
      ..file = null
      ..ownsFile = false;

    _queue.add(
      _SharePreparationRequest(
        imageId: imageId,
        imageBytes: imageBytes,
        fileName: fileName,
        sourceFilePath: sourceFilePath,
        stripMetadata: stripMetadata,
      ),
    );
    notifyListeners();
    _pumpQueue();
  }

  Future<File?> waitUntilReady(
    String imageId, {
    required bool stripMetadata,
  }) {
    final readyFile = readyFileFor(imageId, stripMetadata: stripMetadata);
    if (readyFile != null) {
      return Future<File?>.value(readyFile);
    }

    final snapshot = snapshotFor(imageId, stripMetadata: stripMetadata);
    if (snapshot.status == ShareImagePreparationStatus.failed ||
        snapshot.status == ShareImagePreparationStatus.notQueued) {
      return Future<File?>.value(null);
    }

    final completer = Completer<File?>();
    _readyWaiters
        .putIfAbsent(_variantKey(imageId, stripMetadata), () => [])
        .add(completer);
    return completer.future;
  }

  Future<void> retainHistoryImageIds(Set<String> retainedImageIds) async {
    final removedIds =
        _entries.keys.where((id) => !retainedImageIds.contains(id)).toList();
    if (removedIds.isEmpty) {
      return;
    }

    for (final imageId in removedIds) {
      await _removeImage(imageId);
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    final imageIds = _entries.keys.toList();
    for (final imageId in imageIds) {
      await _removeImage(imageId);
    }
    _queue.clear();
    notifyListeners();
  }

  void _pumpQueue() {
    while (
        _activePreparations < maxConcurrentPreparations && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      final variant =
          _entries[request.imageId]?.variants[request.stripMetadata];
      if (variant == null ||
          variant.status != ShareImagePreparationStatus.preparing) {
        continue;
      }

      _activePreparations++;
      unawaited(_runRequest(request));
    }
  }

  Future<void> _runRequest(_SharePreparationRequest request) async {
    _PreparedShareFile? prepared;
    try {
      prepared = await _prepareRequest(request);
      final variant =
          _entries[request.imageId]?.variants[request.stripMetadata];
      if (variant == null) {
        if (prepared.ownsFile) {
          await _deleteFileIfExists(prepared.file);
        }
        _completeWaiters(request.imageId, request.stripMetadata, null);
        return;
      }

      variant
        ..status = ShareImagePreparationStatus.ready
        ..file = prepared.file
        ..ownsFile = prepared.ownsFile
        ..error = null;
      _completeWaiters(
        request.imageId,
        request.stripMetadata,
        prepared.file,
      );
    } catch (error) {
      final variant =
          _entries[request.imageId]?.variants[request.stripMetadata];
      if (variant != null) {
        variant
          ..status = ShareImagePreparationStatus.failed
          ..file = null
          ..ownsFile = false
          ..error = error;
      }
      _completeWaiters(request.imageId, request.stripMetadata, null);
    } finally {
      _activePreparations--;
      notifyListeners();
      _pumpQueue();
    }
  }

  Future<_PreparedShareFile> _prepareRequest(
    _SharePreparationRequest request,
  ) async {
    final sourceFilePath = request.sourceFilePath?.trim();
    if (!request.stripMetadata &&
        sourceFilePath != null &&
        sourceFilePath.isNotEmpty) {
      final sourceFile = File(sourceFilePath);
      if (await sourceFile.exists()) {
        return _PreparedShareFile(file: sourceFile, ownsFile: false);
      }
    }

    final prepared = await _prepareImage(
      request.imageBytes,
      fileName: request.fileName,
      stripMetadata: request.stripMetadata,
    );
    final file = await _writePreparedFile(_cacheKeyFor(request), prepared);
    return _PreparedShareFile(file: file, ownsFile: true);
  }

  Future<void> _removeImage(String imageId) async {
    final entry = _entries.remove(imageId);
    if (entry == null) {
      return;
    }

    for (final mapEntry in entry.variants.entries) {
      final stripMetadata = mapEntry.key;
      final variant = mapEntry.value;
      if (variant.ownsFile && variant.file != null) {
        await _deleteFileIfExists(variant.file!);
      }
      _completeWaiters(imageId, stripMetadata, null);
    }
  }

  void _completeWaiters(
    String imageId,
    bool stripMetadata,
    File? file,
  ) {
    final waiters = _readyWaiters.remove(_variantKey(imageId, stripMetadata));
    if (waiters == null) {
      return;
    }

    for (final waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.complete(file);
      }
    }
  }

  static Future<void> _deleteFileIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Temporary file cleanup must not break history state updates.
    }
  }

  static Future<SanitizedShareImage> _defaultPrepareImage(
    Uint8List bytes, {
    required String fileName,
    required bool stripMetadata,
  }) {
    if (stripMetadata) {
      return ImageShareSanitizer.prepareForCopyOrDragInBackground(
        bytes,
        fileName: fileName,
        stripMetadata: true,
      );
    }

    return ImageShareSanitizer.prepareForCopyOrDrag(
      bytes,
      fileName: fileName,
      stripMetadata: false,
    );
  }

  static String _variantKey(String imageId, bool stripMetadata) {
    return '$imageId|${stripMetadata ? 'strip' : 'raw'}';
  }

  static String _cacheKeyFor(_SharePreparationRequest request) {
    final safeImageId = request.imageId.replaceAll(
      RegExp(r'[^A-Za-z0-9_.-]+'),
      '_',
    );
    return '${safeImageId}_${request.stripMetadata ? 'strip' : 'raw'}';
  }
}

class _SharePreparedImageEntry {
  _SharePreparedImageEntry(this.imageId);

  final String imageId;
  final Map<bool, _SharePreparedVariant> variants = {};
}

class _SharePreparedVariant {
  ShareImagePreparationStatus status = ShareImagePreparationStatus.notQueued;
  File? file;
  bool ownsFile = false;
  Object? error;
}

class _SharePreparationRequest {
  const _SharePreparationRequest({
    required this.imageId,
    required this.imageBytes,
    required this.fileName,
    required this.stripMetadata,
    this.sourceFilePath,
  });

  final String imageId;
  final Uint8List imageBytes;
  final String fileName;
  final String? sourceFilePath;
  final bool stripMetadata;
}

class _PreparedShareFile {
  const _PreparedShareFile({
    required this.file,
    required this.ownsFile,
  });

  final File file;
  final bool ownsFile;
}

class ImageShareSanitizer {
  ImageShareSanitizer._();

  static const Set<String> _clipboardFriendlyExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.bmp',
    '.gif',
    '.webp',
  };

  static const Set<String> _stripChunkTypes = {
    'tEXt',
    'zTXt',
    'iTXt',
    'eXIf',
    'tIME',
  };

  static Future<SanitizedShareImage> sanitizeForShare(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final extension = p.extension(fileName).toLowerCase();
    if (extension == '.png') {
      return SanitizedShareImage(
        bytes: _sanitizePng(bytes),
        fileName: p.basenameWithoutExtension(fileName).isEmpty
            ? 'shared.png'
            : p.basename(fileName),
        mimeType: 'image/png',
      );
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return SanitizedShareImage(
        bytes: bytes,
        fileName: p.setExtension(p.basename(fileName), '.png'),
        mimeType: 'image/png',
      );
    }

    return SanitizedShareImage(
      bytes: Uint8List.fromList(img.encodePng(decoded)),
      fileName: p.setExtension(p.basename(fileName), '.png'),
      mimeType: 'image/png',
    );
  }

  static Future<SanitizedShareImage> prepareForCopyOrDrag(
    Uint8List bytes, {
    required String fileName,
    required bool stripMetadata,
  }) async {
    final normalizedFileName = _normalizeShareFileName(fileName);
    final extension = p.extension(normalizedFileName).toLowerCase();
    final shouldNormalize =
        stripMetadata || !_clipboardFriendlyExtensions.contains(extension);

    if (shouldNormalize) {
      return sanitizeForShare(bytes, fileName: normalizedFileName);
    }

    return SanitizedShareImage(
      bytes: bytes,
      fileName: normalizedFileName,
      mimeType: _mimeTypeForExtension(extension),
    );
  }

  static Future<SanitizedShareImage> prepareForCopyOrDragInBackground(
    Uint8List bytes, {
    required String fileName,
    required bool stripMetadata,
  }) async {
    if (!stripMetadata) {
      return prepareForCopyOrDrag(
        bytes,
        fileName: fileName,
        stripMetadata: false,
      );
    }

    final transferableBytes = TransferableTypedData.fromList([bytes]);
    return Isolate.run(() {
      final materializedBytes = transferableBytes.materialize().asUint8List();
      return prepareForCopyOrDrag(
        materializedBytes,
        fileName: fileName,
        stripMetadata: true,
      );
    });
  }

  static Future<File> writeTempShareFile(SanitizedShareImage image) async {
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory(p.join(tempDir.path, 'nai_launcher_share'));
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${image.fileName}';
    final file = File(p.join(shareDir.path, fileName));
    await file.writeAsBytes(image.bytes, flush: true);
    return file;
  }

  static Future<File> writeCachedShareFile(
    String cacheKey,
    SanitizedShareImage image,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final shareDir =
        Directory(p.join(tempDir.path, 'nai_launcher_share_cache'));
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    }

    final safeKey = cacheKey.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
    final extension = p.extension(image.fileName).isEmpty
        ? '.png'
        : p.extension(image.fileName).toLowerCase();
    final target = File(p.join(shareDir.path, '$safeKey$extension'));
    final temporary = File('${target.path}.tmp');

    await temporary.writeAsBytes(image.bytes);
    if (await target.exists()) {
      await target.delete();
    }
    return temporary.rename(target.path);
  }

  static Uint8List _sanitizePng(Uint8List bytes) {
    if (!_looksLikePng(bytes)) {
      return bytes;
    }

    final decoded = img.decodePng(bytes);
    if (decoded != null) {
      return Uint8List.fromList(
        img.encodePng(_clearStealthAlphaLsb(decoded)),
      );
    }

    final output = BytesBuilder();
    output.add(bytes.sublist(0, 8));

    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final length =
          ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
      final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));
      final dataStart = offset + 8;
      final dataEnd = dataStart + length;
      final chunkEnd = dataEnd + 4;
      if (chunkEnd > bytes.length) {
        break;
      }

      final shouldKeep = !_stripChunkTypes.contains(type);
      if (shouldKeep) {
        output.add(bytes.sublist(offset, chunkEnd));
      }

      offset = chunkEnd;
    }

    return output.toBytes();
  }

  static String _normalizeShareFileName(String fileName) {
    final normalized = p.basename(fileName);
    if (normalized.isEmpty) {
      return 'shared.png';
    }
    return normalized;
  }

  static String _mimeTypeForExtension(String extension) {
    return switch (extension) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.bmp' => 'image/bmp',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      _ => 'image/png',
    };
  }

  static bool _looksLikePng(Uint8List bytes) {
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < signature.length) {
      return false;
    }
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) {
        return false;
      }
    }
    return true;
  }

  static img.Image _clearStealthAlphaLsb(img.Image image) {
    _clearFrameStealthAlphaLsb(image);
    for (final frame in image.frames) {
      _clearFrameStealthAlphaLsb(frame);
    }
    return image;
  }

  static void _clearFrameStealthAlphaLsb(img.Image frame) {
    frame.textData = null;
    for (var x = 0; x < frame.width; x++) {
      for (var y = 0; y < frame.height; y++) {
        final pixel = frame.getPixel(x, y);
        frame.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          pixel.a.toInt() & 0xFE,
        );
      }
    }
  }
}
