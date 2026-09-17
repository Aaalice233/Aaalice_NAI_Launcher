import 'dart:convert';
import 'dart:io';

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
enum McpImageDisplayStyle {
  inlineUrl,
  inlineFile,

  /// 只渲染工作目录内的本地文件，故仅调用方自己传的 saved_path 走文件 Markdown。
  inlineWorkspaceFile,
  inlineWithLink,
  link,
}

/// External clients receive image bytes. A gallery original is exposed only as
/// saved_path; internal chat previews and the auto-saved originals are left
/// untouched.
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
  /// 一条链接绕开那一下；终端里的 Claude Code（`claude-code`）画不出图片，只能
  /// 给链接。`local-agent-mode` 是 Claude Code 桌面版，只认工作目录内的文件；
  /// `pi-mcp` 是 Pi 终端，同样只能给链接。
  /// claude-code 与 local-agent-mode 必须先判，否则会被 claude 前缀吞掉。
  static McpImageDisplayStyle styleForClient(String clientLabel) {
    final label = clientLabel.toLowerCase();
    if (label.contains('claude-code')) return McpImageDisplayStyle.link;
    if (label.contains('local-agent-mode')) {
      return McpImageDisplayStyle.inlineWorkspaceFile;
    }
    if (label.contains('claude')) return McpImageDisplayStyle.inlineWithLink;
    if (label.contains('codex')) return McpImageDisplayStyle.inlineFile;
    if (label.contains('pi-mcp')) return McpImageDisplayStyle.link;
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
    bool? includeDisplayFile,
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
      final generated =
          toolName == 'generate_image' || toolName == 'submit_generation';
      // 链接样式的客户端无法内联图片，两种展示引用都要备好：HTTP 一小时过期，
      // 显示缓存文件留得更久。
      final wantsLink = style == McpImageDisplayStyle.link;
      final prepareDisplay = generated || toolName == 'display_images';
      final needsDisplayFile =
          prepareDisplay &&
          ((includeDisplayFile ?? style == McpImageDisplayStyle.inlineFile) ||
              wantsLink);
      final needsDisplayUrl =
          prepareDisplay && (includeDisplayUrl || wantsLink);
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
        final savedPath = entry['saved_path'] is String
            ? entry['saved_path'] as String
            : null;
        final savedPathSource = entry['saved_path_source'] is String
            ? entry['saved_path_source'] as String
            : null;
        final descriptor = <String, dynamic>{
          if (entry['size'] is String) 'size': entry['size'],
          if (entry['saved'] is bool) 'saved': entry['saved'],
          if (!stripMetadata && entry['seed'] is num) 'seed': entry['seed'],
          if (savedPath != null) 'saved_path': savedPath,
          if (savedPathSource != null) 'saved_path_source': savedPathSource,
          if (entry['save_error'] is Map)
            'save_error': Map<String, dynamic>.from(entry['save_error'] as Map),
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
            bestEffortDisplay: generated,
            savedPath: savedPath,
            savedPathSource: savedPathSource,
          );
          if (image == null) return _unavailable();
          descriptor.addAll(image.descriptor);
          content.add(image.content);
        }
        images.add(descriptor);
      }
      // Build both text and structured content from the same safe projection;
      // details.files otherwise exposes the original via the MCP adapter.
      final displayMarkdown = _displayMarkdown(style, images);
      final output = <String, dynamic>{
        'ok': true,
        'images': images,
        if (displayMarkdown.isNotEmpty) 'display_markdown': displayMarkdown,
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
        content: [
          ToolResultTextContent(jsonEncode(output)),
          // Some hosts forward text blocks but discard nested JSON fields.
          if (displayMarkdown.isNotEmpty)
            ToolResultTextContent(displayMarkdown),
          ...content,
        ],
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
    AbortSignal? signal, {
    bool bestEffortDisplay = false,
    String? savedPath,
    String? savedPathSource,
  }) async {
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
    File? displayFile;
    try {
      // 调用方给了持久文件，显示缓存副本没有意义。
      if (includeDisplayFile && savedPath == null) {
        displayFile = await _writeDisplayFile(image);
      }
    } on Object {
      // A display-cache failure must not turn a completed paid generation into
      // a generation failure. Privacy preparation above still fails closed.
      if (!bestEffortDisplay) rethrow;
    }
    throwIfAborted(signal);
    final displayPath =
        savedPath ??
        (displayFile == null
            ? null
            : p.absolute(displayFile.path).replaceAll('\\', '/'));
    McpImageDisplayLink? displayLink;
    try {
      if (includeDisplayUrl) {
        displayLink = _publishDisplayImage?.call(
          image.bytes,
          mimeType: image.mimeType,
          metadataStripped: stripMetadata,
        );
      }
    } on Object {
      if (!bestEffortDisplay) rethrow;
    }
    return (
      descriptor: {
        'resource_ref': _referenceJson(resolved.reference, stripMetadata),
        'size': '${size.$1}x${size.$2}',
        'mime_type': image.mimeType,
        'metadata_stripped': stripMetadata,
        if (displayPath != null) 'display_path': displayPath,
        if (displayLink != null) ...{
          'display_url': displayLink.url.toString(),
          'display_url_expires_at': displayLink.expiresAt.toIso8601String(),
        },
        ..._displayReferences(
          style,
          size: size,
          displayPath: displayPath,
          displayLink: displayLink,
          savedPath: savedPath,
          savedPathSource: savedPathSource,
        ),
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

  /// 两种 saved_path 来源里只有 caller 落在客户端工作目录内，图库原图给文件引用是死链。
  static bool _isCallerPath(String? savedPath, String? savedPathSource) =>
      savedPath != null &&
      (savedPathSource == null || savedPathSource == 'caller');

  static String _fileUri(String path) =>
      Uri.file(path, windows: Platform.isWindows).toString();

  static Map<String, dynamic> _displayReferences(
    McpImageDisplayStyle style, {
    required (int, int) size,
    required String? displayPath,
    required McpImageDisplayLink? displayLink,
    required String? savedPath,
    required String? savedPathSource,
  }) {
    final label = 'Generated image ${size.$1}x${size.$2}';
    final fileMarkdown = displayPath == null
        ? null
        : '![Generated image](<$displayPath>)';
    final urlMarkdown = displayLink == null
        ? null
        : '![Generated image](${displayLink.url})';
    final fileLinkMarkdown = displayPath == null
        ? null
        : '[$label](<${_fileUri(displayPath)}>)';
    // 链接优先给 HTTP：聊天界面普遍把 http 变成可点链接，file:// 常被剥掉。
    final linkTarget = displayLink?.url.toString() ?? displayPath;
    final linkMarkdown = linkTarget == null ? null : '[$label](<$linkTarget>)';
    // 持久文件不过期而 HTTP 预览会，终端两条都要，其余样式只能二选一。
    final durableLinks = savedPath == null
        ? null
        : [
            fileLinkMarkdown!,
            if (displayLink != null)
              '[Temporary preview link](<${displayLink.url}>)',
          ].join('\n');
    final markdown = switch (style) {
      McpImageDisplayStyle.link => durableLinks ?? linkMarkdown,
      McpImageDisplayStyle.inlineFile => fileMarkdown,
      McpImageDisplayStyle.inlineWorkspaceFile =>
        _isCallerPath(savedPath, savedPathSource) ? fileMarkdown : urlMarkdown,
      McpImageDisplayStyle.inlineUrl ||
      McpImageDisplayStyle.inlineWithLink => urlMarkdown,
    };
    return {
      if (fileMarkdown != null) 'display_file_markdown': fileMarkdown,
      if (fileLinkMarkdown != null)
        'display_file_link_markdown': fileLinkMarkdown,
      if (urlMarkdown != null) 'display_url_markdown': urlMarkdown,
      if (linkMarkdown != null) 'display_link_markdown': linkMarkdown,
      if (markdown != null) 'display_markdown': markdown,
    };
  }

  static String _displayMarkdown(
    McpImageDisplayStyle style,
    List<Map<String, dynamic>> images,
  ) => [
    for (final image in images)
      if (image['display_markdown'] case final String markdown) ...[
        markdown,
        if (style == McpImageDisplayStyle.inlineWithLink &&
            image['display_link_markdown'] is String)
          image['display_link_markdown'] as String,
      ],
  ].join('\n\n');

  static const String _dualLinkNote =
      ' Each image gives a durable local file link first and a temporary HTTP '
      'preview link that expires; put both in the final answer.';

  static String _displayInstructions(
    McpImageDisplayStyle style,
    List<Map<String, dynamic>> images,
  ) {
    final durableFiles = images.any((image) => image.containsKey('saved_path'));
    return switch (style) {
      McpImageDisplayStyle.link =>
        'Put the top-level display_markdown in the final answer as clickable '
            'links, not image embeds or a code block. This client uses links.'
            '${durableFiles ? _dualLinkNote : ''}',
      // 只有 Claude Desktop 会把相邻工具调用并成一块，并连带吞掉直显的图。
      McpImageDisplayStyle.inlineWithLink =>
        'Embed the top-level display_markdown in the final answer. It includes '
            'each image and a clickable link. Keep the one-click reveal; '
            'do not retry to bypass it. Write your reply text before any '
            'further tool call, or this result merges into a multi-tool block '
            'and its image is not shown inline.',
      McpImageDisplayStyle.inlineFile =>
        'Embed the top-level display_markdown in the final answer, not a code '
            'block or plain link. Codex desktop uses the absolute local '
            'display_file_markdown, not the HTTP URL.',
      McpImageDisplayStyle.inlineWorkspaceFile =>
        'Embed the top-level display_markdown in the final answer. This client '
            'renders local images only inside its working directory: only a '
            'save_path you passed yourself is inlined as a file, while the '
            'launcher gallery original sits outside it and falls back to the '
            'HTTP URL, which expires. Pass a save_path inside your working '
            'directory to inline the file.',
      McpImageDisplayStyle.inlineUrl =>
        'Embed the top-level display_markdown in the final answer, not a code '
            'block or plain link. Cherry Studio uses display_url_markdown '
            '(HTTP), never a local file path.',
    };
  }

  static String _instructionsFor(
    McpImageDisplayStyle style,
    List<Map<String, dynamic>> images,
  ) {
    final missingReference = images.any(
      (image) => !image.containsKey('display_markdown'),
    );
    final retrievalInstructions = missingReference
        ? 'For images missing a display reference, call display_images with '
              'their resource_refs (Codex: include_display_file=true).'
        : 'Do not call display_images again unless a reference is missing, '
              'expired or fails to load.';
    final savePathInstructions = [
      if (images.any((image) => image.containsKey('saved_path')))
        'saved_path is the durable file chosen by the caller or the launcher '
            'gallery original; state it in the final answer and prefer it over '
            'display cache paths.',
      if (images.any((image) => image.containsKey('saved_path_source')))
        'saved_path_source is caller for a path you passed and '
            'gallery_original for the launcher own gallery file, which must '
            'never be deleted, moved or rewritten.',
      if (images.any((image) => image.containsKey('save_error')))
        'save_error means the image was generated but not written to '
            'save_path; never regenerate for that, call save_generated_image '
            'with a new destination if a file is still needed.',
    ].join(' ');
    return '${_displayInstructions(style, images)} ImageContent in tool '
        'details is not proof of visible display. $retrievalInstructions '
        'Never regenerate merely to display an image.'
        '${savePathInstructions.isEmpty ? '' : ' $savePathInstructions'}';
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
