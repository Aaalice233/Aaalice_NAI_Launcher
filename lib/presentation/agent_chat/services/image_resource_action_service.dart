import 'dart:async';
import 'dart:typed_data';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/krita/krita_outbound_image.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../utils/clipboard_image.dart';
import 'defined_agent_tool.dart';
import 'generated_image_export_writer.dart';
import 'generation_image_resource.dart';

export 'generated_image_export_writer.dart' show ResourceImageExclusiveWriter;

final class ResolvedImageResourceActionSource {
  const ResolvedImageResourceActionSource({
    required this.label,
    required this.bytes,
    this.metadataStripped,
  });

  final String label;
  final Uint8List bytes;
  final bool? metadataStripped;
}

/// Injectable boundary for image clipboard writes.
typedef ImageResourceActionResolver =
    Future<ResolvedImageResourceActionSource?> Function(
      AgentChatResourceReference reference,
    );
typedef ResourceImageClipboardWriter = Future<void> Function(Uint8List bytes);
typedef ResourceImageKritaSender =
    FutureOr<bool> Function(Uint8List bytes, {required String name});
typedef ImageResourceExportPreparer =
    Future<ResolvedImageResourceActionSource> Function(
      ResolvedImageResourceActionSource source,
    );

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
    ImageResourceExportPreparer? prepareExport,
  }) : _resolve = resolve,
       _clipboardWriter = clipboardWriter,
       _supportsKritaBridge =
           supportsKritaBridge ??
           (() => PlatformCapabilities.current.supportsKritaBridge),
       _readKritaBridgeState = readKritaBridgeState,
       _sendToKrita = sendToKrita,
       _exportWriter = GeneratedImageExportWriter(
         env: env,
         exclusiveWriter: exclusiveWriter,
       ),
       _prepareExport = prepareExport;

  final ImageResourceActionResolver _resolve;
  final ResourceImageClipboardWriter _clipboardWriter;
  final bool Function() _supportsKritaBridge;
  final ImageResourceKritaBridgeState Function()? _readKritaBridgeState;
  final ResourceImageKritaSender? _sendToKrita;
  final GeneratedImageExportWriter _exportWriter;
  final ImageResourceExportPreparer? _prepareExport;

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

    final prepared = await _exportWriter.prepareTarget(
      requestedPath,
      mimeType: loaded.mimeType!,
    );
    if (prepared.errorOrNull case final failure?) {
      return _exportFailureResult(failure, loaded);
    }
    final target = prepared.valueOrNull!;

    final writeFailure = await _exportWriter.write(target, loaded.bytes!);
    if (writeFailure != null) return _exportFailureResult(writeFailure, loaded);

    final destination = _exportWriter.describeDestination(target.absolutePath);
    return agentToolJsonResult({
      'ok': true,
      'action': 'saved',
      'resource_ref': _exportReferenceJson(loaded),
      if (loaded.metadataStripped != null)
        'metadata_stripped': loaded.metadataStripped,
      if (loaded.metadataStripped != null) 'mime_type': loaded.mimeType,
      ...destination,
    });
  }

  AgentToolResult _exportFailureResult(
    GeneratedImageExportFailure failure,
    _LoadedImage loaded,
  ) => switch (failure.kind) {
    GeneratedImageExportFailureKind.invalidTarget => agentToolError(
      'invalid_destination',
      'destination_path must identify a file, not a directory.',
    ),
    GeneratedImageExportFailureKind.outsideScope => agentToolError(
      'unsafe_destination',
      'The requested destination is outside the permitted file scope.',
    ),
    GeneratedImageExportFailureKind.extensionMismatch => agentToolError(
      'invalid_destination_extension',
      'destination_path must use an extension matching the image format.',
    ),
    GeneratedImageExportFailureKind.parentUnavailable => agentToolError(
      'destination_unavailable',
      'The destination directory could not be created.',
    ),
    GeneratedImageExportFailureKind.parentUnresolvable => agentToolError(
      'destination_unavailable',
      'The destination directory could not be resolved safely.',
    ),
    GeneratedImageExportFailureKind.checkFailed => agentToolError(
      'destination_check_failed',
      'The destination could not be checked safely.',
    ),
    GeneratedImageExportFailureKind.exists => agentToolError(
      'destination_exists',
      'The destination already exists; image resources are never overwritten.',
    ),
    GeneratedImageExportFailureKind.unsafeChange => agentToolError(
      'unsafe_destination',
      'The requested destination changed outside the permitted file scope.',
    ),
    GeneratedImageExportFailureKind.writeFailed => _saveFailedResult(
      loaded,
      failure.error,
    ),
  };

  static AgentToolResult _saveFailedResult(_LoadedImage loaded, Object? error) {
    final detail = error == null ? '' : ' (${error.runtimeType})';
    return agentToolError(
      'save_failed',
      'save_generated_image: generated image '
          '${loaded.reference!.resourceId} failed during exclusive file '
          'write$detail.',
    );
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
      'resource_ref': _exportReferenceJson(loaded),
      if (loaded.metadataStripped != null)
        'metadata_stripped': loaded.metadataStripped,
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
    final loaded = _LoadedImage(
      reference: reference,
      bytes: bytes,
      mimeType: mimeType,
      label: resolved.label,
    );
    return _prepareExport != null &&
            (action == 'save_generated_image' ||
                action == 'copy_generated_image_to_clipboard')
        ? _prepareLoadedExport(loaded)
        : loaded;
  }

  Future<_LoadedImage> _prepareLoadedExport(_LoadedImage loaded) async {
    try {
      final prepared = await _prepareExport!(
        ResolvedImageResourceActionSource(
          label: loaded.label!,
          bytes: loaded.bytes!,
        ),
      );
      final mimeType = detectSupportedImageMimeType(prepared.bytes);
      if (mimeType == null) throw StateError('Unsupported export format');
      return _LoadedImage(
        reference: loaded.reference,
        bytes: prepared.bytes,
        mimeType: mimeType,
        label: prepared.label,
        metadataStripped: prepared.metadataStripped,
      );
    } on Object {
      return _LoadedImage.error(
        agentToolError(
          'image_export_preparation_failed',
          'The image could not be prepared under the current sharing policy. '
              'No image was exported; original bytes were not used as a fallback.',
        ),
      );
    }
  }

  static Map<String, dynamic> _exportReferenceJson(_LoadedImage loaded) {
    final reference = loaded.reference!;
    return AgentChatResourceReferenceCodec.encodeJsonMap(
      loaded.metadataStripped == true
          ? AgentChatResourceReference(
              version: reference.version,
              kind: reference.kind,
              source: reference.source,
              resourceId: reference.resourceId,
              mediaId: reference.mediaId,
            )
          : reference,
    );
  }

}

final class _LoadedImage {
  const _LoadedImage({
    this.reference,
    this.bytes,
    this.mimeType,
    this.label,
    this.metadataStripped,
  }) : error = null;

  const _LoadedImage.error(AgentToolResult this.error)
    : reference = null,
      bytes = null,
      mimeType = null,
      metadataStripped = null,
      label = null;

  final AgentChatResourceReference? reference;
  final Uint8List? bytes;
  final String? mimeType;
  final String? label;
  final bool? metadataStripped;
  final AgentToolResult? error;
}
