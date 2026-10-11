import 'dart:async';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart';

import '../../core/utils/app_logger.dart';

/// Every native read a dropped item may need, issued in one synchronous pass.
///
/// The drop session disposes its reader once the perform callback returns, and
/// requests made after that fail. Results can be awaited any time later.
final class DroppedDataRequest {
  DroppedDataRequest._({
    required this.fileUri,
    required this.suggestedName,
    required this.imageFiles,
    required this.hasNonSynthesizedImage,
    required this.hasOnlySynthesizedImages,
    required this.namedUri,
    required this.htmlText,
    required this.plainText,
  });

  factory DroppedDataRequest.issue(
    DataReader reader, {
    required Iterable<({FileFormat format, String extension})> imageFormats,
    required bool includeRemoteSources,
    required Duration timeout,
    required String logTag,
  }) {
    Future<T?>? valueIf<T extends Object>(
      ValueFormat<T> format,
      String label,
    ) => reader.canProvide(format)
        ? _requestValue(reader, format, label, timeout, logTag)
        : null;

    final imageFiles = <DeferredDroppedFile>[];
    var foundImage = false;
    var hasNonSynthesizedImage = false;
    var synthesisKnown = true;
    for (final image in imageFormats) {
      if (!reader.canProvide(image.format)) continue;
      final isSynthesized = _isSynthesized(reader, image.format);
      foundImage = true;
      synthesisKnown &= isSynthesized != null;
      hasNonSynthesizedImage |= isSynthesized == false;
      final file = DeferredDroppedFile._request(
        reader,
        image.format,
        extension: image.extension,
        isSynthesized: isSynthesized ?? false,
        timeout: timeout,
        logTag: logTag,
      );
      if (file != null) imageFiles.add(file);
    }

    return DroppedDataRequest._(
      fileUri: valueIf(Formats.fileUri, 'file URI'),
      suggestedName: _requestSuggestedName(reader, timeout),
      imageFiles: List.unmodifiable(imageFiles),
      hasNonSynthesizedImage: synthesisKnown && hasNonSynthesizedImage,
      hasOnlySynthesizedImages:
          synthesisKnown && foundImage && !hasNonSynthesizedImage,
      namedUri: includeRemoteSources ? valueIf(Formats.uri, 'URI') : null,
      htmlText: includeRemoteSources ? valueIf(Formats.htmlText, 'HTML') : null,
      plainText: includeRemoteSources
          ? valueIf(Formats.plainText, 'plain text')
          : null,
    );
  }

  final Future<Uri?>? fileUri;
  final Future<String?> suggestedName;

  /// Direct image representations in caller preference order.
  final List<DeferredDroppedFile> imageFiles;

  /// The source itself offers image data, not just a converted bitmap.
  final bool hasNonSynthesizedImage;

  /// Every offered image representation was converted from another format.
  final bool hasOnlySynthesizedImages;
  final Future<NamedUri?>? namedUri;
  final Future<String?>? htmlText;
  final Future<String?>? plainText;

  /// Lets the source close every representation that was never read.
  void discardUnread() {
    for (final file in imageFiles) {
      file.discard();
    }
  }

  static Future<T?> _requestValue<T extends Object>(
    DataReader reader,
    ValueFormat<T> format,
    String label,
    Duration timeout,
    String logTag,
  ) {
    final completer = Completer<T?>();
    final ReadProgress? progress;
    try {
      progress = reader.getValue<T>(
        format,
        (value) {
          if (!completer.isCompleted) completer.complete(value);
        },
        onError: (error) {
          AppLogger.w('Failed to read dropped $label: $error', logTag);
          if (!completer.isCompleted) completer.complete(null);
        },
      );
    } catch (error) {
      AppLogger.w('Failed to request dropped $label: $error', logTag);
      return Future.value();
    }
    if (progress == null) return Future.value();
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        AppLogger.w('Timed out reading dropped $label', logTag);
        return null;
      },
    );
  }

  static Future<String?> _requestSuggestedName(
    DataReader reader,
    Duration timeout,
  ) {
    try {
      return reader
          .getSuggestedName()
          .timeout(timeout)
          .then<String?>((name) => name, onError: (Object _) => null);
    } catch (_) {
      return Future.value();
    }
  }

  static bool? _isSynthesized(DataReader reader, FileFormat format) {
    try {
      return reader.isSynthesized(format);
    } catch (_) {
      return null;
    }
  }
}

/// A file representation requested inside the drop session but read on demand.
///
/// super_clipboard closes the file when its `onFile` callback finishes, so the
/// callback stays pending until the caller either reads or discards it.
final class DeferredDroppedFile {
  DeferredDroppedFile._({
    required this.format,
    required this.extension,
    required this.isSynthesized,
    required Duration timeout,
    required String logTag,
  }) : _timeout = timeout,
       _logTag = logTag;

  static DeferredDroppedFile? _request(
    DataReader reader,
    FileFormat format, {
    required String extension,
    required bool isSynthesized,
    required Duration timeout,
    required String logTag,
  }) {
    final file = DeferredDroppedFile._(
      format: format,
      extension: extension,
      isSynthesized: isSynthesized,
      timeout: timeout,
      logTag: logTag,
    );
    try {
      final progress = reader.getFile(
        format,
        file._receive,
        onError: file._fail,
        synthesizeFilesFromURIs: false,
      );
      return progress == null ? null : file;
    } catch (error) {
      AppLogger.w('Failed to request dropped $extension image: $error', logTag);
      return null;
    }
  }

  final FileFormat format;
  final String extension;
  final bool isSynthesized;
  final Duration _timeout;
  final String _logTag;
  final _decision = Completer<bool>();
  final _result = Completer<({String? fileName, Uint8List bytes})?>();

  /// Reads the whole representation; null when it failed or timed out.
  Future<({String? fileName, Uint8List bytes})?> read() {
    if (!_decision.isCompleted) _decision.complete(true);
    return _result.future.timeout(
      _timeout,
      onTimeout: () {
        AppLogger.w('Timed out reading dropped $extension image', _logTag);
        return null;
      },
    );
  }

  void discard() {
    if (!_decision.isCompleted) _decision.complete(false);
  }

  Future<void> _receive(DataReaderFile file) async {
    if (!await _decision.future) return;
    try {
      final bytes = await file.readAll();
      _complete((fileName: file.fileName, bytes: bytes));
    } catch (error) {
      AppLogger.w('Failed to read dropped $extension bytes: $error', _logTag);
      _complete(null);
    }
  }

  void _fail(Object error) {
    AppLogger.w('Failed to read dropped $extension image: $error', _logTag);
    _complete(null);
  }

  void _complete(({String? fileName, Uint8List bytes})? value) {
    if (!_result.isCompleted) _result.complete(value);
  }
}
