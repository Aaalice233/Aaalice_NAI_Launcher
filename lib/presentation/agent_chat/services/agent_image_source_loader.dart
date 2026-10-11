import 'dart:io';
import 'dart:typed_data';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/private_data_guard.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'generation_workspace_path_resolver.dart';

final class AgentImageSource {
  const AgentImageSource._({this.bytes, this.encodedReference, this.error});

  factory AgentImageSource.failed(String code, String message) =>
      AgentImageSource._(error: agentToolError(code, message));

  final Uint8List? bytes;

  /// 只有经 resource_ref 载入时才有，回显给模型继续引用同一资源。
  final Map<String, dynamic>? encodedReference;
  final AgentToolResult? error;
}

/// 按 resource_ref 或 image_path 二选一载入一张可解码的图片。
final class AgentImageSourceLoader {
  AgentImageSourceLoader({
    required AgentResourceResolver resolver,
    required GenerationWorkspacePathResolver pathResolver,
  }) : _resolver = resolver,
       _pathResolver = pathResolver;

  final AgentResourceResolver _resolver;
  final GenerationWorkspacePathResolver _pathResolver;

  /// 只检查参数形状，不读取任何资源。
  AgentToolResult? rejectSelection(Map<String, dynamic> params) {
    final hasPath =
        ((params['image_path'] as String?)?.trim() ?? '').isNotEmpty;
    final hasReference = params['resource_ref'] != null;
    return hasReference == hasPath
        ? agentToolError(
            'invalid_source',
            'Provide exactly one of resource_ref or image_path.',
          )
        : null;
  }

  Future<AgentImageSource> load(Map<String, dynamic> params) async {
    if (rejectSelection(params) case final rejection?) {
      return AgentImageSource._(error: rejection);
    }
    final source = params['resource_ref'] != null
        ? await _loadReference(params['resource_ref'])
        : await _loadFile((params['image_path'] as String).trim());
    final bytes = source.bytes;
    if (bytes != null && NaiResolutionAdapter.readImageSize(bytes) == null) {
      return AgentImageSource.failed(
        'invalid_image',
        'The provided data could not be decoded as an image.',
      );
    }
    return source;
  }

  Future<AgentImageSource> _loadReference(Object? rawReference) async {
    try {
      final reference = _resolver.decode(rawReference);
      final resolved = await _resolver.resolve(reference);
      if (resolved == null) {
        return AgentImageSource.failed(
          'resource_unavailable',
          'The referenced resource is unavailable.',
        );
      }
      final bytes = resolved.bytes;
      if (bytes == null || bytes.isEmpty) {
        return AgentImageSource.failed(
          'not_an_image',
          'The referenced resource has no image data.',
        );
      }
      return AgentImageSource._(
        bytes: bytes,
        encodedReference: AgentChatResourceReferenceCodec.encodeJsonMap(
          resolved.reference,
        ),
      );
    } on FormatException catch (error) {
      return AgentImageSource.failed('invalid_resource_ref', '$error');
    }
  }

  Future<AgentImageSource> _loadFile(String rawPath) async {
    final String resolved;
    try {
      resolved = await _pathResolver.resolveLocalImagePath(rawPath);
    } on Object {
      return AgentImageSource.failed(
        'image_path_not_permitted',
        'Image path is not permitted.',
      );
    }
    final file = File(resolved);
    if (!file.existsSync()) {
      return AgentImageSource.failed(
        'source_not_found',
        'Source image not found.',
      );
    }
    try {
      return AgentImageSource._(bytes: await file.readAsBytes());
    } on Object catch (error) {
      return AgentImageSource.failed(
        'source_unreadable',
        PrivateDataGuard.redactAbsolutePaths('$error'),
      );
    }
  }
}
