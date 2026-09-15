import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/mcp/mcp_image_http_endpoint.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../agent_chat/services/defined_agent_tool.dart';
import '../../agent_chat/services/image_resource_action_service.dart';
import '../../agent_chat/services/image_presentation_toolbox.dart';
import 'mcp_image_display_cache.dart';

/// 客户端呈现图片的方式，只决定返回哪种 Markdown，不改变返回的图片字节。
enum McpImageDisplayStyle { inlineUrl, inlineFile, inlineWithLink, link }

/// External clients receive image bytes, never original-file shortcuts.
/// Internal chat previews and the auto-saved originals are left untouched.
class McpImageResponseService {
  McpImageResponseService({
    required AgentImageResourceResolver resolve,
    required bool Function() shouldStripMetadata,
    AgentImageResourceValidator? validate,
    ShareImagePrepareFunction? prepareImage,
    ShareImageWriteTempFileFunction? writeDisplayFile,
    McpImageDisplayPublisher? publishDisplayImage,
  }) : _resolve = resolve,
       _validate = validate,
       _shouldStripMetadata = shouldStripMetadata,
       _prepareImage =
           prepareImage ?? ImageShareSanitizer.prepareForCopyOrDragInBackground,
       _writeDisplayFile = writeDisplayFile ?? McpImageDisplayCache().prepare,
       _publishDisplayImage = publishDisplayImage;

  /// Claude Desktop 渲染图片 Markdown 但用点击门拦住自动加载，于是图片之外再附
  /// 一条链接绕开那一下；终端里的 Claude Code 画不出图片，只能给链接。
  /// claude-code 必须先判，否则会被 claude 前缀吞掉。
  static McpImageDisplayStyle styleForClient(String clientLabel) {
    final label = clientLabel.toLowerCase();
    if (label.contains('claude-code')) return McpImageDisplayStyle.link;
    if (label.contains('claude')) return McpImageDisplayStyle.inlineWithLink;
    if (label.contains('codex')) return McpImageDisplayStyle.inlineFile;
    return McpImageDisplayStyle.inlineUrl;
  }

  static const imageTools = {
    'generate_image',
    'submit_generation',
    'inspect_images',
    'display_images',
  };

  final AgentImageResourceResolver _resolve;
  final AgentImageResourceValidator? _validate;
  final bool Function() _shouldStripMetadata;
  final ShareImagePrepareFunction _prepareImage;
  final ShareImageWriteTempFileFunction _writeDisplayFile;
  final McpImageDisplayPublisher? _publishDisplayImage;

  /// Save/copy are side effects: sanitizing their result afterwards is too late.
  Future<ResolvedImageResourceActionSource> prepareExportImage(
    ResolvedImageResourceActionSource source,
  ) async {
    final stripMetadata = _shouldStripMetadata();
    final mime = detectSupportedImageMimeType(source.bytes);
    if (mime == null) throw const ImageSanitizeException('Unsupported image');
    final prepared = await _prepareImage(
      source.bytes,
      fileName: 'image.${mime == 'image/jpeg' ? 'jpg' : mime.split('/').last}',
      stripMetadata: stripMetadata,
    );
    return ResolvedImageResourceActionSource(
      label: prepared.fileName,
      bytes: prepared.bytes,
      metadataStripped: stripMetadata,
    );
  }

  Future<AgentToolResult> prepare(
    String toolName,
    AgentToolResult result, {
    AbortSignal? signal,
    bool includeDisplayFile = false,
    bool includeDisplayUrl = true,
    McpImageDisplayStyle style = McpImageDisplayStyle.inlineUrl,
  }) async {
    if (result.isError ||
        (!imageTools.contains(toolName) && toolName != 'get_recent_images')) {
      return result;
    }
    final payload = _payload(result);
    final entries = payload?['images'];
    // Paid preparations do not contain images and must retain their approval
    // contract. A media result without identities must never leak raw bytes.
    if (entries == null &&
        result.content.whereType<ToolResultImageContent>().isEmpty) {
      return result;
    }
    if (entries is! List || entries.isEmpty) return _unavailable();

    try {
      throwIfAborted(signal);
      final stripMetadata = _shouldStripMetadata();
      final includeImages = imageTools.contains(toolName);
      // 链接样式的客户端无法内联图片，两种展示引用都要备好：HTTP 一小时过期，
      // 显示缓存文件留得更久。
      final wantsLink = style == McpImageDisplayStyle.link;
      final needsDisplayFile =
          toolName == 'display_images' && (includeDisplayFile || wantsLink);
      final needsDisplayUrl =
          toolName == 'display_images' && (includeDisplayUrl || wantsLink);
      final images = <Map<String, dynamic>>[];
      final content = <ToolResultImageContent>[];
      for (final entry in entries) {
        throwIfAborted(signal);
        if (entry is! Map || entry['resource_ref'] is! Map) {
          return _unavailable();
        }
        final reference = AgentChatResourceReferenceCodec.decodeJsonMap(
          Map<String, dynamic>.from(entry['resource_ref'] as Map),
        );
        final descriptor = <String, dynamic>{
          if (entry['size'] is String) 'size': entry['size'],
          if (entry['saved'] is bool) 'saved': entry['saved'],
          if (!stripMetadata && entry['seed'] is num) 'seed': entry['seed'],
          'resource_ref': _referenceJson(reference, stripMetadata),
        };
        if (includeImages) {
          final image = await _imageContent(
            reference,
            stripMetadata,
            needsDisplayFile,
            needsDisplayUrl,
            style,
            signal,
          );
          if (image == null) return _unavailable();
          descriptor.addAll(image.descriptor);
          content.add(image.content);
        }
        images.add(descriptor);
      }
      // Build both text and structured content from the same safe projection;
      // details.files otherwise exposes the original via the MCP adapter.
      final output = <String, dynamic>{
        'ok': true,
        'images': images,
        if (includeImages) 'image_resolution': 'original',
        if (includeImages) 'metadata_stripped': stripMetadata,
        if (toolName == 'inspect_images') 'inspected_count': images.length,
        if (includeImages) ...{
          'image_content_count': content.length,
          'display_status': 'requires_client_rendering',
          'display_instructions': _instructionsFor(style, images),
        },
      };
      return AgentToolResult(
        content: [ToolResultTextContent(jsonEncode(output)), ...content],
        details: output,
      );
    } on Object {
      // Never fall back to the internal preview or unstripped bytes on failure.
      throwIfAborted(signal);
      return _unavailable();
    }
  }

  Future<({Map<String, dynamic> descriptor, ToolResultImageContent content})?>
  _imageContent(
    AgentChatResourceReference reference,
    bool stripMetadata,
    bool includeDisplayFile,
    bool includeDisplayUrl,
    McpImageDisplayStyle style,
    AbortSignal? signal,
  ) async {
    await _validate?.call(reference);
    final resolved = await _resolve(reference);
    final source = resolved?.bytes;
    if (resolved == null || source == null) return null;
    final mime = detectSupportedImageMimeType(source);
    if (mime == null) return null;
    final image = await _prepareImage(
      source,
      fileName: 'image.${mime == 'image/jpeg' ? 'jpg' : mime.split('/').last}',
      stripMetadata: stripMetadata,
    );
    throwIfAborted(signal);
    final size = NaiResolutionAdapter.readImageSize(image.bytes);
    if (size == null) return null;
    final displayFile = includeDisplayFile
        ? await _writeDisplayFile(image)
        : null;
    throwIfAborted(signal);
    final displayPath = displayFile == null
        ? null
        : p.absolute(displayFile.path).replaceAll('\\', '/');
    final displayLink = includeDisplayUrl
        ? _publishDisplayImage?.call(
            image.bytes,
            mimeType: image.mimeType,
            metadataStripped: stripMetadata,
          )
        : null;
    final fileMarkdown = displayPath == null
        ? null
        : '![Generated image](<$displayPath>)';
    final urlMarkdown = displayLink == null
        ? null
        : '![Generated image](${displayLink.url})';
    // 链接优先给 HTTP：聊天界面普遍把 http 变成可点链接，file:// 常被剥掉。
    final linkTarget = displayLink?.url.toString() ?? displayPath;
    final linkMarkdown = linkTarget == null
        ? null
        : '[Generated image ${size.$1}x${size.$2}](<$linkTarget>)';
    final markdown = switch (style) {
      McpImageDisplayStyle.link => linkMarkdown,
      McpImageDisplayStyle.inlineFile => fileMarkdown ?? urlMarkdown,
      McpImageDisplayStyle.inlineUrl ||
      McpImageDisplayStyle.inlineWithLink => urlMarkdown ?? fileMarkdown,
    };
    return (
      descriptor: {
        'resource_ref': _referenceJson(resolved.reference, stripMetadata),
        'size': '${size.$1}x${size.$2}',
        'mime_type': image.mimeType,
        'metadata_stripped': stripMetadata,
        if (displayPath != null) ...{
          'display_path': displayPath,
          'display_file_markdown': fileMarkdown,
        },
        if (displayLink != null) ...{
          'display_url': displayLink.url.toString(),
          'display_url_expires_at': displayLink.expiresAt.toIso8601String(),
          'display_url_markdown': urlMarkdown,
        },
        if (linkMarkdown != null) 'display_link_markdown': linkMarkdown,
        if (markdown != null) 'display_markdown': markdown,
      },
      content: ToolResultImageContent(
        ImageContent(
          source: ImageSource.base64(
            mimeType: image.mimeType,
            base64Data: base64Encode(image.bytes),
          ),
        ),
      ),
    );
  }

  static String _instructionsFor(
    McpImageDisplayStyle style,
    List<Map<String, dynamic>> images,
  ) {
    final hasDisplayReference = images.any(
      (image) => image.containsKey('display_markdown'),
    );
    if (!hasDisplayReference) {
      return style == McpImageDisplayStyle.link
          ? 'ImageContent may be hidden in collapsed tool details, and this '
                'client does not render images in the answer. Call '
                'display_images with these resource_refs to obtain a clickable '
                'display_link_markdown. Tool success does not confirm '
                'user-visible display.'
          : 'ImageContent may be hidden in collapsed tool details. For '
                'inline output, call display_images with these resource_refs '
                'to obtain a temporary HTTP display_url_markdown. For Codex '
                'desktop set include_display_file=true and embed '
                'display_file_markdown instead. If no display reference is '
                'available, use the client media renderer '
                'or ask the user to expand the tool result. Tool success '
                'does not confirm user-visible display.';
    }
    return switch (style) {
      McpImageDisplayStyle.link =>
        'This client keeps tool images collapsed and does not render image '
            'Markdown in the answer. Put every images[].display_link_markdown '
            'in the final answer as a clickable link, one per image, never as '
            'an image embed and never in a code block, and say the image is '
            'also inside the collapsed tool result. Links open the same '
            'prepared bytes on this machine; the HTTP link expires within one '
            'hour while display_path stays available longer. Retrieve again '
            'instead of regenerating.',
      McpImageDisplayStyle.inlineWithLink =>
        'Put every images[].display_markdown in the final answer, and directly '
            'below each one add its images[].display_link_markdown on its own '
            'line as a clickable link. This client hides the image behind a '
            'one-click reveal such as a Show Image placeholder, so the link is '
            'how the user opens it without that click; the gate is the client '
            'protecting the user, so never retry or apologise for it. The '
            'image and the link carry the same prepared bytes from this '
            'machine and expire within one hour; retrieve again instead of '
            'regenerating. Do not claim visibility merely because this tool '
            'succeeded.',
      _ =>
        'Render every images[].display_markdown directly in the final '
            'answer, not in a code block or as a plain link. Cherry '
            'Studio must use display_url_markdown, not a local path. '
            'Codex desktop can use display_file_markdown when available. '
            'All variants contain the same prepared image bytes. HTTP '
            'URLs are temporary, same-machine capabilities; retrieve '
            'again if expired, never regenerate. Some clients, including '
            'Claude Desktop, hide the image behind a one-click reveal such '
            'as a Show Image placeholder; that is the client protecting the '
            'user, so keep the Markdown, mention the single click when it '
            'helps, and never retry or apologise for it. '
            'Do not claim visibility merely because this tool succeeded.',
    };
  }

  static Map<String, dynamic>? _payload(AgentToolResult result) {
    for (final text in result.content.whereType<ToolResultTextContent>()) {
      try {
        final decoded = jsonDecode(text.text);
        if (decoded is Map<String, dynamic> && decoded.containsKey('images')) {
          return decoded;
        }
      } on FormatException {
        continue;
      }
    }
    return result.details is Map<String, dynamic> ? result.details : null;
  }

  static Map<String, dynamic> _referenceJson(
    AgentChatResourceReference reference,
    bool stripMetadata,
  ) => AgentChatResourceReferenceCodec.encodeJsonMap(
    stripMetadata
        ? AgentChatResourceReference(
            version: reference.version,
            kind: reference.kind,
            source: reference.source,
            resourceId: reference.resourceId,
            mediaId: reference.mediaId,
          )
        : reference,
  );

  static AgentToolResult _unavailable() => agentToolError(
    'mcp_image_unavailable',
    'The full-resolution image could not be prepared safely. No image bytes '
        'were returned. Local originals are unchanged. For a completed '
        'generation, use get_recent_images then display_images to retry '
        'retrieval; do not generate or charge again automatically.',
  );
}
