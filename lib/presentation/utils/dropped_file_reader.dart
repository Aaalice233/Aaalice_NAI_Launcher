import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/file_name_sanitizer.dart';
import '../../core/utils/vibe_file_parser.dart';

class DroppedFileData {
  const DroppedFileData({
    required this.fileName,
    required this.bytes,
    this.sourceUri,
    this.sourcePath,
    this.metadataBytes,
    this.imageBytesArePreview = false,
  });

  final String fileName;
  final Uint8List bytes;
  final Uri? sourceUri;
  final String? sourcePath;
  final Uint8List? metadataBytes;
  final bool imageBytesArePreview;
}

class DroppedFileReader {
  DroppedFileReader._();

  static const int maxRemoteRawImageBytes = 256 * 1024 * 1024;
  static const int discordMetadataProbeBytes = 64 * 1024;
  static const Duration readTimeout = Duration(seconds: 10);
  static const Duration remoteTimeout = Duration(seconds: 30);
  static const Duration discordMetadataTimeout = Duration(seconds: 5);
  static const Duration discordPreviewTimeout = Duration(seconds: 10);
  static const Set<String> _imageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
  };

  static final List<({FileFormat format, String extension})> _imageFormats = [
    (format: Formats.png, extension: 'png'),
    (format: Formats.jpeg, extension: 'jpg'),
    (format: Formats.webp, extension: 'webp'),
    (format: Formats.gif, extension: 'gif'),
    (format: Formats.bmp, extension: 'bmp'),
  ];

  static Future<DroppedFileData?> read(
    DataReader reader, {
    bool allowVibeFiles = false,
    bool allowRemoteImages = true,
    String logTag = 'DroppedFileReader',
  }) async {
    _logAvailableFormats(reader, logTag);

    final localFile = await _readLocalFile(
      reader,
      allowVibeFiles: allowVibeFiles,
      logTag: logTag,
    );
    if (localFile != null) {
      return localFile;
    }

    final hasRealDirectImage = _hasNonSynthesizedDirectImage(reader);
    final directImageFuture = hasRealDirectImage
        ? _readDirectImageFile(reader, logTag: logTag)
        : null;
    final remoteUri = allowRemoteImages
        ? await _readRemoteImageUri(reader, logTag: logTag)
        : null;
    final normalizedRemoteUri = remoteUri == null
        ? null
        : normalizeRemoteImageUri(remoteUri);

    if (normalizedRemoteUri != null &&
        isDiscordAttachmentUri(normalizedRemoteUri)) {
      final discordImage = await _readDiscordAttachment(
        normalizedRemoteUri,
        directImageFuture: directImageFuture,
        logTag: logTag,
      );
      if (discordImage != null) {
        return discordImage;
      }
    }

    if (directImageFuture != null) {
      final directImage = await directImageFuture;
      if (directImage != null) {
        return directImage;
      }
    }

    var remoteLookupAttempted = false;
    if (allowRemoteImages && _hasOnlySynthesizedDirectImages(reader)) {
      remoteLookupAttempted = true;
      AppLogger.d(
        'Preferring the remote source over synthesized dropped image data',
        logTag,
      );
      final remoteImage = await _readRemoteImage(
        normalizedRemoteUri,
        logTag: logTag,
      );
      if (remoteImage != null) {
        return remoteImage;
      }
    }

    if (!hasRealDirectImage) {
      final directImage = await _readDirectImageFile(reader, logTag: logTag);
      if (directImage != null) {
        return directImage;
      }
    }

    if (allowRemoteImages && !remoteLookupAttempted) {
      return _readRemoteImage(normalizedRemoteUri, logTag: logTag);
    }

    return null;
  }

  static bool _hasOnlySynthesizedDirectImages(DataReader reader) {
    var foundDirectImage = false;
    try {
      for (final imageFormat in _imageFormats) {
        if (!reader.canProvide(imageFormat.format)) {
          continue;
        }
        foundDirectImage = true;
        if (!reader.isSynthesized(imageFormat.format)) {
          return false;
        }
      }
    } catch (_) {
      return false;
    }
    return foundDirectImage;
  }

  static bool _hasNonSynthesizedDirectImage(DataReader reader) {
    try {
      return _imageFormats.any(
        (imageFormat) =>
            reader.canProvide(imageFormat.format) &&
            !reader.isSynthesized(imageFormat.format),
      );
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static Uri? extractImageUriFromText(String text) {
    final normalized = _decodeBasicHtmlEntities(text);
    final attributePattern = RegExp(
      r'''(?:src|href)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );

    for (final match in attributePattern.allMatches(normalized)) {
      final uri = _parseHttpUri(match.group(1));
      if (uri != null) {
        return uri;
      }
    }

    final urlPattern = RegExp(r'''https?://[^\s"'<>]+''', caseSensitive: false);
    for (final match in urlPattern.allMatches(normalized)) {
      final uri = _parseHttpUri(match.group(0));
      if (uri != null) {
        return uri;
      }
    }
    return null;
  }

  @visibleForTesting
  static String inferFileNameFromUri(
    Uri uri, {
    String? contentType,
    String? contentDisposition,
  }) {
    final dispositionFileName = _extractContentDispositionFileName(
      contentDisposition,
    );
    final uriFileName = uri.pathSegments.isNotEmpty
        ? Uri.decodeComponent(uri.pathSegments.last)
        : null;
    var fileName = _sanitizeFileName(
      dispositionFileName?.trim().isNotEmpty == true
          ? dispositionFileName!
          : (uriFileName?.trim().isNotEmpty == true
                ? uriFileName!
                : 'dropped_image'),
    );

    final extension = _extensionOf(fileName);
    if (!_imageExtensions.contains(extension)) {
      final inferredExtension =
          _extensionFromContentType(contentType) ??
          _extensionFromUriQuery(uri) ??
          'png';
      fileName = '$fileName.$inferredExtension';
    }
    return fileName;
  }

  static void _logAvailableFormats(DataReader reader, String logTag) {
    try {
      final formats = reader.getFormats(Formats.standardFormats);
      final details = formats
          .map(
            (format) => [
              format.toString(),
              if (reader.isVirtual(format)) 'virtual',
              if (reader.isSynthesized(format)) 'synthesized',
            ].join(':'),
          )
          .join(', ');
      AppLogger.d('Dropped data formats: $details', logTag);
    } catch (e) {
      AppLogger.d('Failed to inspect dropped data formats: $e', logTag);
    }
  }

  static Future<DroppedFileData?> _readLocalFile(
    DataReader reader, {
    required bool allowVibeFiles,
    required String logTag,
  }) async {
    if (!reader.canProvide(Formats.fileUri)) {
      return null;
    }

    final uri = await _readValue<Uri>(
      reader,
      Formats.fileUri,
      label: 'file URI',
      logTag: logTag,
    );
    if (uri == null) {
      return null;
    }

    try {
      final filePath = uri.toFilePath();
      final fileName = _sanitizeFileName(
        filePath.split(Platform.pathSeparator).last,
      );
      if (!_isAllowedLocalFile(fileName, allowVibeFiles: allowVibeFiles)) {
        AppLogger.w('Unsupported dropped local file: $fileName', logTag);
        return null;
      }

      final result = await compute(
        _readLocalFileInIsolate,
        _LocalFileReadRequest(filePath: filePath, fileName: fileName),
      );
      if (result == null) {
        AppLogger.w('Failed to read dropped local file: $filePath', logTag);
        return null;
      }

      return DroppedFileData(
        fileName: result.fileName,
        bytes: result.bytes,
        sourceUri: uri,
        sourcePath: filePath,
      );
    } catch (e) {
      AppLogger.w('Failed to resolve dropped local file URI: $e', logTag);
      return null;
    }
  }

  static bool _isAllowedLocalFile(
    String fileName, {
    required bool allowVibeFiles,
  }) {
    final extension = _extensionOf(fileName);
    if (_imageExtensions.contains(extension)) {
      return true;
    }
    return allowVibeFiles && VibeFileParser.isSupportedFile(fileName);
  }

  static Future<DroppedFileData?> _readDirectImageFile(
    DataReader reader, {
    required String logTag,
  }) async {
    final suggestedName = await _safeSuggestedName(reader);
    for (final imageFormat in _imageFormats) {
      if (!reader.canProvide(imageFormat.format)) {
        continue;
      }

      final file = await _readImageFile(
        reader,
        imageFormat.format,
        label: imageFormat.extension,
        logTag: logTag,
      );
      if (file == null) {
        continue;
      }

      final fileName = _ensureImageFileName(
        file.fileName ?? suggestedName ?? 'dropped_image',
        fallbackExtension: imageFormat.extension,
      );
      final bytes = file.bytes;
      if (bytes.isEmpty) {
        AppLogger.w('Dropped image file is empty: $fileName', logTag);
        continue;
      }

      return DroppedFileData(fileName: fileName, bytes: bytes);
    }
    return null;
  }

  static Future<Uri?> _readRemoteImageUri(
    DataReader reader, {
    required String logTag,
  }) async {
    if (reader.canProvide(Formats.uri)) {
      final namedUri = await _readValue<NamedUri>(
        reader,
        Formats.uri,
        label: 'URI',
        logTag: logTag,
      );
      final uri = _parseHttpUri(namedUri?.uri.toString());
      if (uri != null) {
        return uri;
      }
    }

    if (reader.canProvide(Formats.htmlText)) {
      final html = await _readValue<String>(
        reader,
        Formats.htmlText,
        label: 'HTML',
        logTag: logTag,
      );
      final uri = html == null ? null : extractImageUriFromText(html);
      if (uri != null) {
        return uri;
      }
    }

    if (reader.canProvide(Formats.plainText)) {
      final text = await _readValue<String>(
        reader,
        Formats.plainText,
        label: 'plain text',
        logTag: logTag,
      );
      final uri = text == null ? null : extractImageUriFromText(text);
      if (uri != null) {
        return uri;
      }
    }

    return null;
  }

  static Future<DroppedFileData?> _readRemoteImage(
    Uri? remoteUri, {
    required String logTag,
  }) async {
    if (remoteUri == null) {
      return null;
    }
    return downloadRemoteImage(remoteUri, logTag: logTag);
  }

  static Future<DroppedFileData?> _readDiscordAttachment(
    Uri originalUri, {
    Future<DroppedFileData?>? directImageFuture,
    required String logTag,
  }) async {
    if (directImageFuture != null) {
      final directImage = await directImageFuture;
      if (directImage != null) {
        return DroppedFileData(
          fileName: directImage.fileName,
          bytes: directImage.bytes,
          sourceUri: originalUri,
          sourcePath: directImage.sourcePath,
        );
      }
    }

    final metadataFuture = downloadRemoteMetadataPrefix(
      originalUri,
      logTag: logTag,
    );
    final previewFuture = _downloadRemoteImage(
      buildDiscordPreviewUri(originalUri),
      logTag: logTag,
      timeout: discordPreviewTimeout,
    );
    final previewImage = await previewFuture;
    final metadataBytes = await metadataFuture;
    if (previewImage != null) {
      return DroppedFileData(
        fileName: inferFileNameFromUri(originalUri),
        bytes: previewImage.bytes,
        sourceUri: originalUri,
        metadataBytes: metadataBytes,
        imageBytesArePreview: true,
      );
    }

    final originalImage = await downloadRemoteImage(
      originalUri,
      logTag: logTag,
    );
    if (originalImage == null) {
      return null;
    }
    return DroppedFileData(
      fileName: originalImage.fileName,
      bytes: originalImage.bytes,
      sourceUri: originalUri,
      metadataBytes: metadataBytes,
    );
  }

  static Future<DroppedFileData?> downloadRemoteImage(
    Uri uri, {
    String logTag = 'DroppedFileReader',
  }) {
    return _downloadRemoteImage(normalizeRemoteImageUri(uri), logTag: logTag);
  }

  @visibleForTesting
  static Uri normalizeRemoteImageUri(Uri uri) {
    if (uri.host.toLowerCase() != 'media.discordapp.net' ||
        uri.pathSegments.isEmpty ||
        !_discordAttachmentPathPrefixes.contains(uri.pathSegments.first)) {
      return uri;
    }

    final queryParameters = Map<String, String>.from(uri.queryParameters)
      ..removeWhere(
        (key, _) =>
            key.isEmpty ||
            _discordProxyTransformParameters.contains(key.toLowerCase()),
      );
    return uri.replace(
      host: 'cdn.discordapp.com',
      queryParameters: queryParameters,
    );
  }

  @visibleForTesting
  static Uri buildDiscordPreviewUri(Uri uri) {
    final originalUri = normalizeRemoteImageUri(uri);
    if (!isDiscordAttachmentUri(originalUri)) {
      return uri;
    }

    final queryParameters =
        Map<String, String>.from(originalUri.queryParameters)..removeWhere(
          (key, _) =>
              key.isEmpty ||
              _discordProxyTransformParameters.contains(key.toLowerCase()),
        );
    queryParameters.addAll(const {
      'format': 'webp',
      'quality': 'lossless',
      'width': '512',
      'height': '512',
    });
    return originalUri.replace(
      host: 'media.discordapp.net',
      queryParameters: queryParameters,
    );
  }

  static bool isDiscordAttachmentUri(Uri uri) {
    final host = uri.host.toLowerCase();
    return (host == 'cdn.discordapp.com' || host == 'media.discordapp.net') &&
        uri.pathSegments.isNotEmpty &&
        _discordAttachmentPathPrefixes.contains(uri.pathSegments.first);
  }

  static const Set<String> _discordAttachmentPathPrefixes = {
    'attachments',
    'ephemeral-attachments',
  };

  static const Set<String> _discordProxyTransformParameters = {
    'animated',
    'format',
    'height',
    'quality',
    'width',
  };

  static Future<Uint8List?> downloadRemoteMetadataPrefix(
    Uri uri, {
    int maxBytes = discordMetadataProbeBytes,
    String logTag = 'DroppedFileReader',
  }) async {
    if (maxBytes <= 0) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'Must be positive');
    }

    final normalizedUri = normalizeRemoteImageUri(uri);
    final client = HttpClient();
    client.connectionTimeout = discordMetadataTimeout;
    try {
      final request = await client
          .getUrl(normalizedUri)
          .timeout(discordMetadataTimeout);
      request.followRedirects = true;
      request.headers.set(HttpHeaders.userAgentHeader, 'NAI-Launcher/1.0');
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${maxBytes - 1}');
      final response = await request.close().timeout(discordMetadataTimeout);
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        AppLogger.w(
          'Dropped image metadata probe failed: '
          '${_uriWithoutQuery(normalizedUri)} status=${response.statusCode}',
          logTag,
        );
        await response.drain<void>();
        return null;
      }

      final contentType = response.headers.contentType?.mimeType;
      if (!_isImageResponse(normalizedUri, contentType, null)) {
        AppLogger.w(
          'Dropped image metadata probe returned non-image content: '
          '${_uriWithoutQuery(normalizedUri)} contentType=$contentType',
          logTag,
        );
        await response.drain<void>();
        return null;
      }

      final builder = BytesBuilder(copy: false);
      var totalBytes = 0;
      await for (final chunk in response.timeout(discordMetadataTimeout)) {
        final remaining = maxBytes - totalBytes;
        if (remaining <= 0) {
          break;
        }
        if (chunk.length <= remaining) {
          builder.add(chunk);
          totalBytes += chunk.length;
        } else {
          builder.add(chunk.sublist(0, remaining));
          totalBytes += remaining;
        }
        if (totalBytes >= maxBytes) {
          break;
        }
      }

      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        return null;
      }
      AppLogger.d(
        'Read dropped image metadata prefix: bytes=${bytes.length}, '
        'uri=${_uriWithoutQuery(normalizedUri)}',
        logTag,
      );
      return bytes;
    } catch (e) {
      AppLogger.w(
        'Failed to read dropped image metadata prefix: '
        '${_uriWithoutQuery(normalizedUri)}, error=$e',
        logTag,
      );
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<DroppedFileData?> _downloadRemoteImage(
    Uri uri, {
    required String logTag,
    Duration timeout = remoteTimeout,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.followRedirects = true;
      request.headers.set(HttpHeaders.userAgentHeader, 'NAI-Launcher/1.0');
      final response = await request.close().timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.w(
          'Dropped remote image request failed: ${_uriWithoutQuery(uri)} '
          'status=${response.statusCode}',
          logTag,
        );
        await response.drain<void>();
        return null;
      }

      final contentType = response.headers.contentType?.mimeType;
      final contentDisposition = response.headers.value('content-disposition');
      final effectiveUri = response.redirects.isNotEmpty
          ? response.redirects.last.location
          : uri;
      if (!_isImageResponse(effectiveUri, contentType, contentDisposition)) {
        AppLogger.w(
          'Dropped remote URL is not an image: ${_uriWithoutQuery(uri)} '
          'contentType=$contentType',
          logTag,
        );
        await response.drain<void>();
        return null;
      }

      final fileName = inferFileNameFromUri(
        effectiveUri,
        contentType: contentType,
        contentDisposition: contentDisposition,
      );

      final builder = BytesBuilder(copy: false);
      var totalBytes = 0;
      await for (final chunk in response.timeout(timeout)) {
        totalBytes += chunk.length;
        if (totalBytes > maxRemoteRawImageBytes) {
          throw StateError(
            '远程图片原始下载超过 ${maxRemoteRawImageBytes ~/ (1024 * 1024)}MB',
          );
        }
        builder.add(chunk);
      }

      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        AppLogger.w(
          'Dropped remote image is empty: ${_uriWithoutQuery(uri)}',
          logTag,
        );
        return null;
      }

      AppLogger.i(
        'Downloaded dropped remote image: $fileName, bytes=${bytes.length}, '
        'uri=${_uriWithoutQuery(uri)}',
        logTag,
      );
      return DroppedFileData(fileName: fileName, bytes: bytes, sourceUri: uri);
    } catch (e) {
      AppLogger.w(
        'Failed to download dropped remote image: '
        '${_uriWithoutQuery(uri)}, error=$e',
        logTag,
      );
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Uri _uriWithoutQuery(Uri uri) => uri.replace(query: null);

  static bool _isImageResponse(
    Uri uri,
    String? contentType,
    String? contentDisposition,
  ) {
    final mimeType = contentType?.toLowerCase();
    if (mimeType != null && mimeType.startsWith('image/')) {
      return true;
    }

    final fileNameFromUri = uri.pathSegments.isNotEmpty
        ? Uri.decodeComponent(uri.pathSegments.last)
        : '';
    final fileNameFromDisposition = _extractContentDispositionFileName(
      contentDisposition,
    );
    return _imageExtensions.contains(_extensionOf(fileNameFromUri)) ||
        (fileNameFromDisposition != null &&
            _imageExtensions.contains(_extensionOf(fileNameFromDisposition))) ||
        _extensionFromUriQuery(uri) != null;
  }

  static Future<T?> _readValue<T extends Object>(
    DataReader reader,
    ValueFormat<T> format, {
    required String label,
    required String logTag,
  }) async {
    final completer = Completer<T?>();
    final progress = reader.getValue<T>(
      format,
      (value) {
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      },
      onError: (e) {
        AppLogger.w('Failed to read dropped $label: $e', logTag);
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );
    if (progress == null) {
      return null;
    }
    return completer.future.timeout(
      readTimeout,
      onTimeout: () {
        AppLogger.w('Timed out reading dropped $label', logTag);
        return null;
      },
    );
  }

  static Future<({String? fileName, Uint8List bytes})?> _readImageFile(
    DataReader reader,
    FileFormat format, {
    required String label,
    required String logTag,
  }) async {
    final completer = Completer<({String? fileName, Uint8List bytes})?>();
    final progress = reader.getFile(
      format,
      (file) async {
        try {
          final bytes = await file.readAll();
          if (!completer.isCompleted) {
            completer.complete((fileName: file.fileName, bytes: bytes));
          }
        } catch (e) {
          AppLogger.w('Failed to read dropped $label bytes: $e', logTag);
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      },
      onError: (e) {
        AppLogger.w('Failed to read dropped $label image: $e', logTag);
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
      synthesizeFilesFromURIs: false,
    );
    if (progress == null) {
      return null;
    }
    return completer.future.timeout(
      readTimeout,
      onTimeout: () {
        AppLogger.w('Timed out reading dropped $label image', logTag);
        return null;
      },
    );
  }

  static Future<String?> _safeSuggestedName(DataReader reader) async {
    try {
      return reader.getSuggestedName().timeout(readTimeout);
    } catch (_) {
      return null;
    }
  }

  static String _ensureImageFileName(
    String fileName, {
    required String fallbackExtension,
  }) {
    final sanitized = _sanitizeFileName(fileName);
    final extension = _extensionOf(sanitized);
    if (_imageExtensions.contains(extension)) {
      return sanitized;
    }
    return '$sanitized.$fallbackExtension';
  }

  static Uri? _parseHttpUri(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = _stripUrlBoundaryPunctuation(
      _decodeBasicHtmlEntities(value.trim()),
    );
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    return uri;
  }

  static String _stripUrlBoundaryPunctuation(String value) {
    var result = value;
    while (result.isNotEmpty && '.,;'.contains(result[result.length - 1])) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  static String _decodeBasicHtmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#34;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  static String _sanitizeFileName(String fileName) {
    return FileNameSanitizer.sanitize(fileName, fallback: 'dropped_image');
  }

  static String _extensionOf(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index < 0 || index == fileName.length - 1) {
      return '';
    }
    return fileName.substring(index + 1).toLowerCase();
  }

  static String? _extensionFromContentType(String? contentType) {
    switch (contentType?.toLowerCase().split(';').first.trim()) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/bmp':
      case 'image/x-ms-bmp':
        return 'bmp';
    }
    return null;
  }

  static String? _extensionFromUriQuery(Uri uri) {
    final format =
        uri.queryParameters['format'] ??
        uri.queryParameters['fm'] ??
        uri.queryParameters['ext'];
    if (format == null) {
      return null;
    }
    final normalized = format.toLowerCase().replaceAll('.', '');
    return _imageExtensions.contains(normalized) ? normalized : null;
  }

  static String? _extractContentDispositionFileName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final utf8Match = RegExp(
      r'''filename\*=UTF-8''([^;]+)''',
      caseSensitive: false,
    ).firstMatch(value);
    if (utf8Match != null) {
      return Uri.decodeComponent(
        utf8Match.group(1)!.trim().replaceAll('"', ''),
      );
    }

    final quotedMatch = RegExp(
      r'''filename\s*=\s*"([^"]+)''',
      caseSensitive: false,
    ).firstMatch(value);
    if (quotedMatch != null) {
      return quotedMatch.group(1);
    }

    final plainMatch = RegExp(
      r'''filename\s*=\s*([^;]+)''',
      caseSensitive: false,
    ).firstMatch(value);
    return plainMatch?.group(1)?.trim();
  }
}

Future<_LocalFileReadResult?> _readLocalFileInIsolate(
  _LocalFileReadRequest request,
) async {
  try {
    final file = File(request.filePath);
    if (!await file.exists()) {
      return null;
    }
    return _LocalFileReadResult(
      fileName: request.fileName,
      bytes: await file.readAsBytes(),
    );
  } catch (_) {
    return null;
  }
}

class _LocalFileReadRequest {
  const _LocalFileReadRequest({required this.filePath, required this.fileName});

  final String filePath;
  final String fileName;
}

class _LocalFileReadResult {
  const _LocalFileReadResult({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}
