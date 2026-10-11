import 'dart:convert';

import 'package:dart_mcp/server.dart' as mcp;

import '../agent/agent_types.dart';
import '../agent/permissions/agent_permission.dart';
import '../agent/permissions/tool_permission_catalog.dart';

/// Translates launcher agent tools and their results into the wire types of
/// `package:dart_mcp`.
abstract final class McpToolAdapter {
  static mcp.Tool toMcpTool(AgentTool tool) => mcp.Tool(
    name: tool.name,
    title: tool.label,
    description: tool.description,
    inputSchema: mcp.ObjectSchema.fromMap(tool.parameters),
    annotations: _annotationsFor(tool),
  );

  static mcp.CallToolResult toCallToolResult(AgentToolResult result) {
    final content = <mcp.Content>[];
    for (final item in result.content) {
      switch (item) {
        case ToolResultTextContent(:final text):
          content.add(mcp.TextContent(text: text));
        case ToolResultImageContent(:final image):
          content.add(_imageContent(image));
      }
    }
    return mcp.CallToolResult(
      content: content,
      structuredContent: _structuredContent(result.content),
      isError: result.isError,
    );
  }

  static mcp.CallToolResult errorResult(String message) => mcp.CallToolResult(
    content: [mcp.TextContent(text: message)],
    isError: true,
  );

  static mcp.Content _imageContent(ImageContent image) {
    final data = image.source.base64Data;
    if (data == null) {
      // URL-only sources carry no bytes; the link is still useful to the model.
      return mcp.TextContent(text: image.source.url ?? '');
    }
    return mcp.ImageContent(
      data: data,
      mimeType: image.source.mimeType ?? 'image/png',
    );
  }

  // MCP text blocks serialize structuredContent; details is UI-only, so derive
  // from text.
  static Map<String, Object?>? _structuredContent(
    List<ToolResultContent> content,
  ) {
    for (final item in content.whereType<ToolResultTextContent>()) {
      final decoded = _decodeJsonObject(item.text);
      if (decoded != null) {
        return decoded;
      }
    }
    return null;
  }

  static Map<String, Object?>? _decodeJsonObject(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static const Set<AgentPermissionOperation> _destructiveOperations = {
    AgentPermissionOperation.delete,
    AgentPermissionOperation.overwrite,
    AgentPermissionOperation.move,
  };

  static mcp.ToolAnnotations _annotationsFor(AgentTool tool) {
    final operation = _operationOf(tool.name);
    if (operation == null) {
      // Every launcher tool acts on this machine's launcher state only.
      return mcp.ToolAnnotations(title: tool.label, openWorldHint: false);
    }
    final readOnly = operation == AgentPermissionOperation.read;
    return mcp.ToolAnnotations(
      title: tool.label,
      readOnlyHint: readOnly,
      destructiveHint: _destructiveOperations.contains(operation),
      idempotentHint: readOnly,
      openWorldHint: false,
    );
  }

  static AgentPermissionOperation? _operationOf(String toolName) {
    try {
      return describeAgentToolPermission(toolName).operation;
    } on StateError {
      // A tool outside the permission catalog still has to appear in
      // `tools/list`; it just carries no behavioural hints.
      return null;
    }
  }
}
