import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/krita/krita_outbound_image.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../utils/clipboard_image.dart';
import 'defined_agent_tool.dart';
import 'generation_image_resource.dart';

final class ResolvedImageResourceActionSource {
  const ResolvedImageResourceActionSource({
    required this.label,
    required this.bytes,
  });

  final String label;
  final Uint8List bytes;
}

/// Injectable boundary for image clipboard writes.
typedef ImageResourceActionResolver =
    Future<ResolvedImageResourceActionSource?> Function(
      AgentChatResourceReference reference,
    );
typedef ResourceImageClipboardWriter = Future<void> Function(Uint8List bytes);
typedef ResourceImageKritaSender =
    FutureOr<bool> Function(Uint8List bytes, {required String name});
typedef ResourceImageExclusiveWriter =
    Future<void> Function(String path, Uint8List bytes, String canonicalParent);

final class ImageResourceKritaBridgeState {
  const ImageResourceKritaBridgeState({
    required this.configured,
    required this.connected,
  });

  final bool configured;
  final bool connected;
}

/// Executes explicit external actions for generated-image resource references.
///
/// Stable references are resolved through the application owner. File targets
/// are checked by the same [ExecutionEnv] boundary used by workspace/full-access
/// tools, and the default writer creates files exclusively to avoid overwrites.
final class ImageResourceActionService {
  ImageResourceActionService({
    required ImageResourceActionResolver resolve,
    required ExecutionEnv env,
    ResourceImageClipboardWriter clipboardWriter =
        writeImageBytesToClipboardAsPng,
    bool Function()? supportsKritaBridge,
    ImageResourceKritaBridgeState Function()? readKritaBridgeState,
    ResourceImageKritaSender? sendToKrita,
    ResourceImageExclusiveWriter? exclusiveWriter,
  }) : _resolve = resolve,
       _env = env,
       _clipboardWriter = clipboardWriter,
       _supportsKritaBridge =
           supportsKritaBridge ??
           (() => PlatformCapabilities.current.supportsKritaBridge),
       _readKritaBridgeState = readKritaBridgeState,
       _sendToKrita = sendToKrita,
       _exclusiveWriter = exclusiveWriter ?? _writeExclusive;

  final ImageResourceActionResolver _resolve;
  final ExecutionEnv _env;
  final ResourceImageClipboardWriter _clipboardWriter;
  final bool Function() _supportsKritaBridge;
  final ImageResourceKritaBridgeState Function()? _readKritaBridgeState;
  final ResourceImageKritaSender? _sendToKrita;
  final ResourceImageExclusiveWriter _exclusiveWriter;

  Future<AgentToolResult> save(Map<String, dynamic> args) async {
    final loaded = await _loadGeneratedImage(
      args,
      action: 'save_generated_image',
    );
    if (loaded.error case final error?) return error;

    final requestedPath = args['destination_path'];
    if (requestedPath is! String || requestedPath.trim().isEmpty) {
      return agentToolError(
        'invalid_destination',
        'destination_path must be a non-empty explicit file target.',
      );
    }
    final normalizedRequest = requestedPath.trim();
    if (p.basename(normalizedRequest).isEmpty ||
        p.basename(normalizedRequest) == '.' ||
        p.basename(normalizedRequest) == '..') {
      return agentToolError(
        'invalid_destination',
        'destination_path must identify a file, not a directory.',
      );
    }

    final absoluteResult = await _env.absolutePath(normalizedRequest);
    if (absoluteResult case HarnessErr<String, FileError>()) {
      return agentToolError(
        'unsafe_destination',
        'The requested destination is outside the permitted file scope.',
      );
    }
    final absolutePath = (absoluteResult as HarnessOk<String, FileError>).value;
    final extensionError = _validateTargetExtension(
      absolutePath,
      loaded.mimeType!,
    );
    if (extensionError != null) return extensionError;

    final parentResult = await _env.createDir(p.dirname(absolutePath));
    if (parentResult case HarnessErr<void, FileError>()) {
      return agentToolError(
        'destination_unavailable',
        'The destination directory could not be created.',
      );
    }

    final String writePath;
    final String canonicalParent;
    try {
      canonicalParent = await Directory(
        p.dirname(absolutePath),
      ).resolveSymbolicLinks();
      final canonicalTarget = p.join(canonicalParent, p.basename(absolutePath));
      final canonicalResult = await _env.absolutePath(
        p.relative(canonicalTarget, from: _env.cwd),
      );
      if (canonicalResult case HarnessErr<String, FileError>()) {
        return agentToolError(
          'unsafe_destination',
          'The requested destination changed outside the permitted file scope.',
        );
      }
      writePath = (canonicalResult as HarnessOk<String, FileError>).value;
    } on FileSystemException {
      return agentToolError(
        'destination_unavailable',
        'The destination directory could not be resolved safely.',
      );
    }

    final existsResult = await _env.exists(writePath);
    if (existsResult case HarnessErr<bool, FileError>()) {
      return agentToolError(
        'destination_check_failed',
        'The destination could not be checked safely.',
      );
    }
    if ((existsResult as HarnessOk<bool, FileError>).value) {
      return agentToolError(
        'destination_exists',
        'The destination already exists; image resources are never overwritten.',
      );
    }

    try {
      await _exclusiveWriter(writePath, loaded.bytes!, canonicalParent);
    } on _UnsafeDestinationChanged {
      return agentToolError(
        'unsafe_destination',
        'The requested destination changed outside the permitted file scope.',
      );
    } on FileSystemException {
      if (await File(writePath).exists()) {
        return agentToolError(
          'destination_exists',
          'The destination already exists; image resources are never overwritten.',
        );
      }
      return agentToolError(
        'save_failed',
        'save_generated_image: generated image '
            '${loaded.reference!.resourceId} failed during exclusive file '
            'write.',
      );
    } on Object catch (error) {
      return agentToolError(
        'save_failed',
        'save_generated_image: generated image '
            '${loaded.reference!.resourceId} failed during exclusive file '
            'write (${error.runtimeType}).',
      );
    }

    final destination = _safeDestinationDescription(absolutePath);
    return agentToolJsonResult({
      'ok': true,
      'action': 'saved',
      'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
        loaded.reference!,
      ),
      ...destination,
    });
  }

  Future<AgentToolResult> copy(Map<String, dynamic> args) async {
    final loaded = await _loadGeneratedImage(
      args,
      action: 'copy_generated_image_to_clipboard',
    );
    if (loaded.error case final error?) return error;
    try {
      await _clipboardWriter(loaded.bytes!);
    } on Object catch (error) {
      return agentToolError(
        'clipboard_write_failed',
        'copy_generated_image_to_clipboard: generated image '
            '${loaded.reference!.resourceId} failed during clipboard write '
            '(${error.runtimeType}).',
      );
    }
    return agentToolJsonResult({
      'ok': true,
      'action': 'copied_to_clipboard',
      'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
        loaded.reference!,
      ),
    });
  }

  Future<AgentToolResult> sendKrita(Map<String, dynamic> args) async {
    if (!_supportsKritaBridge()) {
      return agentToolError(
        'krita_unsupported',
        'send_generated_image_to_krita: Krita Bridge is not supported on '
            'this platform.',
      );
    }
    final stateReader = _readKritaBridgeState;
    final sender = _sendToKrita;
    if (stateReader == null || sender == null) {
      return agentToolError(
        'krita_not_configured',
        'send_generated_image_to_krita: Krita Bridge is not configured for '
            'Agent image actions.',
      );
    }
    final state = stateReader();
    if (!state.configured) {
      return agentToolError(
        'krita_not_configured',
        'send_generated_image_to_krita: Krita Bridge is disabled or not '
            'configured.',
      );
    }
    if (!state.connected) {
      return agentToolError(
        'krita_not_connected',
        'send_generated_image_to_krita: Krita Bridge has no authenticated '
            'client connection.',
      );
    }

    final loaded = await _loadGeneratedImage(
      args,
      action: 'send_generated_image_to_krita',
    );
    if (loaded.error case final error?) return error;
    final KritaOutboundImage outbound;
    try {
      outbound = KritaOutboundImage.prepare(loaded.bytes!, name: loaded.label!);
    } on Object {
      return agentToolError(
        'krita_unsupported_image',
        'send_generated_image_to_krita: generated image '
            '${loaded.reference!.resourceId} format could not be prepared for '
            'Krita.',
      );
    }
    try {
      final sent = await sender(outbound.bytes, name: outbound.name);
      if (!sent) {
        return agentToolError(
          'krita_send_failed',
          'send_generated_image_to_krita: generated image '
              '${loaded.reference!.resourceId} was rejected by Krita Bridge.',
        );
      }
    } on Object catch (error) {
      return agentToolError(
        'krita_send_failed',
        'send_generated_image_to_krita: generated image '
            '${loaded.reference!.resourceId} failed during Krita Bridge send '
            '(${error.runtimeType}).',
      );
    }
    return agentToolJsonResult({
      'ok': true,
      'action': 'sent_to_krita',
      'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
        loaded.reference!,
      ),
      'name': outbound.name,
    });
  }

  Future<_LoadedImage> _loadGeneratedImage(
    Map<String, dynamic> args, {
    required String action,
  }) async {
    final AgentChatResourceReference reference;
    try {
      reference = parseGenerationImageResource(args);
    } on GenerationImageResourceException catch (error) {
      return _LoadedImage.error(
        agentToolError(error.code, '$action: ${error.message}'),
      );
    }

    final ResolvedImageResourceActionSource? resolved;
    try {
      resolved = await _resolve(reference);
    } on GenerationImageResourceException catch (error) {
      return _LoadedImage.error(
        agentToolError(error.code, '$action: ${error.message}'),
      );
    } on Object catch (error) {
      return _LoadedImage.error(
        agentToolError(
          'resource_resolution_failed',
          '$action: generated image ${reference.resourceId} failed during '
              'resource resolution (${error.runtimeType}).',
        ),
      );
    }
    final bytes = resolved?.bytes;
    final mimeType = bytes == null ? null : detectSupportedImageMimeType(bytes);
    if (resolved == null || bytes == null || mimeType == null) {
      return _LoadedImage.error(
        agentToolError(
          'resource_unavailable',
          '$action: generated image ${reference.resourceId} is unavailable or unsupported.',
        ),
      );
    }
    return _LoadedImage(
      reference: reference,
      bytes: bytes,
      mimeType: mimeType,
      label: resolved.label,
    );
  }

  AgentToolResult? _validateTargetExtension(String path, String mimeType) {
    final extension = p.extension(path).toLowerCase();
    final expected = switch (mimeType) {
      'image/jpeg' => const {'.jpg', '.jpeg'},
      'image/png' => const {'.png'},
      'image/gif' => const {'.gif'},
      'image/webp' => const {'.webp'},
      'image/bmp' => const {'.bmp'},
      _ => const <String>{},
    };
    if (!expected.contains(extension)) {
      return agentToolError(
        'invalid_destination_extension',
        'destination_path must use an extension matching the image format.',
      );
    }
    return null;
  }

  Map<String, dynamic> _safeDestinationDescription(String absolutePath) {
    final root = p.normalize(_env.cwd);
    final target = p.normalize(absolutePath);
    final relative = p.relative(target, from: root);
    final inside =
        relative != '..' &&
        !p.isAbsolute(relative) &&
        !relative.startsWith('..${p.separator}');
    return inside
        ? {
            'destination_path': relative.replaceAll(p.separator, '/'),
            'destination_scope': 'workspace',
          }
        : {'file_name': p.basename(target), 'destination_scope': 'external'};
  }

  static Future<void> _writeExclusive(
    String path,
    Uint8List bytes,
    String canonicalParent,
  ) async {
    final file = File(path);
    RandomAccessFile? output;
    String? openedPath;
    try {
      await file.create(exclusive: true);
      output = await file.open(mode: FileMode.writeOnly);
      openedPath = await file.resolveSymbolicLinks();
      if (!p.equals(p.dirname(openedPath), canonicalParent)) {
        throw const _UnsafeDestinationChanged();
      }
      await output.writeFrom(bytes);
      await output.flush();
    } on Object {
      await output?.close();
      output = null;
      if (openedPath != null) {
        try {
          await File(openedPath).delete();
        } on Object {
          // Preserve the original write or boundary failure.
        }
      }
      rethrow;
    } finally {
      await output?.close();
    }
  }
}

final class _UnsafeDestinationChanged implements Exception {
  const _UnsafeDestinationChanged();
}

final class _LoadedImage {
  const _LoadedImage({this.reference, this.bytes, this.mimeType, this.label})
    : error = null;

  const _LoadedImage.error(AgentToolResult this.error)
    : reference = null,
      bytes = null,
      mimeType = null,
      label = null;

  final AgentChatResourceReference? reference;
  final Uint8List? bytes;
  final String? mimeType;
  final String? label;
  final AgentToolResult? error;
}
