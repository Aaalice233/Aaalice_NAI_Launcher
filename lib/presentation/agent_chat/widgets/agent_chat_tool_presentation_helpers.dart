import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/agent/agent_tool_presentation.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/utils/localization_extension.dart';
import 'agent_tool_result_summary.dart';

class AgentToolVisual {
  const AgentToolVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

String agentToolLabel(BuildContext context, String toolName) {
  final l10n = context.l10n;
  return switch (toolName) {
    'ask_user_question' => l10n.userQuestion_title,
    'generate_image' => l10n.agentChat_toolGenerateImage,
    'queue_image_task' => l10n.agentChat_toolQueueImageTask,
    'interrogate_image' => l10n.agentChat_toolInterrogateImage,
    'get_recent_images' => l10n.agentChat_toolRecentImages,
    'inspect_images' => l10n.agentChat_toolInspectImages,
    'display_images' => l10n.agentChat_toolDisplayImages,
    'get_generation_status' => l10n.agentChat_toolGenerationStatus,
    'get_generation_settings' => l10n.agentChat_toolGetGenerationSettings,
    'update_generation_settings' => l10n.agentChat_toolUpdateGenerationSettings,
    'get_generation_source_image' =>
      l10n.agentChat_toolGetGenerationSourceImage,
    'set_generation_source_image' =>
      l10n.agentChat_toolSetGenerationSourceImage,
    'clear_generation_source_image' =>
      l10n.agentChat_toolClearGenerationSourceImage,
    'update_generation_source_settings' =>
      l10n.agentChat_toolUpdateGenerationSourceSettings,
    'get_prompt_state' => l10n.agentChat_toolPromptState,
    'set_positive_prompt' => l10n.agentChat_toolSetPositivePrompt,
    'set_negative_prompt' => l10n.agentChat_toolSetNegativePrompt,
    'add_character' => l10n.agentChat_toolAddCharacter,
    'update_character' => l10n.agentChat_toolUpdateCharacter,
    'remove_character' => l10n.agentChat_toolRemoveCharacter,
    'read_skill' => l10n.agentChat_toolReadSkill,
    'read_skill_resource' => l10n.agentChat_toolReadSkillResource,
    'get_skill_diagnostics' => l10n.agentChat_toolSkillDiagnostics,
    'reload_skills' => l10n.agentChat_toolReloadSkills,
    'search_tags' => l10n.agentChat_toolSearchTags,
    'read' => l10n.agentChat_toolReadFile,
    'web_search' => l10n.agentChat_toolWebSearch,
    'web_read' => l10n.agentChat_toolWebRead,
    'prepare_generation' => l10n.agentChat_toolPrepareGeneration,
    'inspect_generation_preparation' => l10n.agentChat_toolInspectGeneration,
    'update_generation_preparation' => l10n.agentChat_toolUpdateGeneration,
    'cancel_generation_preparation' => l10n.agentChat_toolCancelGeneration,
    'submit_generation' => l10n.agentChat_toolSubmitGeneration,
    'upscale_image' => l10n.agentChat_toolUpscaleImage,
    'create_manual_inpaint_draft' => l10n.agentChat_toolCreateInpaint,
    'list_manual_inpaint_drafts' => l10n.agentChat_toolListInpaint,
    'get_manual_inpaint_draft' => l10n.agentChat_toolInspectInpaint,
    'cancel_manual_inpaint_draft' => l10n.agentChat_toolCancelInpaint,
    'reedit_manual_inpaint_draft' => l10n.agentChat_toolReeditInpaint,
    'submit_manual_inpaint_draft' => l10n.agentChat_toolSubmitInpaint,
    'create_inpaint_mask' => l10n.agentChat_toolCreateInpaintMask,
    'expand_inpaint_canvas' => l10n.agentChat_toolExpandInpaintCanvas,
    'load_inpaint_draft_into_panel' => l10n.agentChat_toolLoadInpaintPanel,
    String() when toolName.contains('generated_image') =>
      l10n.agentChat_toolRecentImages,
    String() when toolName.contains('queue') =>
      l10n.agentChat_toolQueueImageTask,
    String() when toolName.contains('gallery') => l10n.agentChat_toolGallery,
    String()
        when toolName.contains('vibe') || toolName.contains('precise_ref') =>
      l10n.agentChat_toolReferenceLibrary,
    String()
        when toolName.contains('fixed_tag') ||
            toolName.contains('tag_library') ||
            toolName == 'navigate_application' ||
            toolName == 'get_application_context' =>
      l10n.agentChat_toolApplication,
    _ => toolName,
  };
}

IconData agentToolIcon(String toolName) => switch (toolName) {
  'generate_image' || 'submit_generation' => Icons.auto_awesome_outlined,
  'queue_image_task' => Icons.schedule_send_outlined,
  'upscale_image' => Icons.zoom_out_map_rounded,
  'interrogate_image' ||
  'get_recent_images' ||
  'preview_generated_image' ||
  'get_generation_status' => Icons.image_search_outlined,
  'inspect_images' => Icons.visibility_outlined,
  'display_images' => Icons.photo_library_outlined,
  'get_generation_settings' || 'update_generation_settings' => Icons.tune,
  String() when toolName.contains('generation_source') =>
    Icons.photo_filter_outlined,
  'get_prompt_state' ||
  'set_positive_prompt' ||
  'set_negative_prompt' => Icons.edit_note_outlined,
  'add_character' ||
  'update_character' ||
  'remove_character' => Icons.manage_accounts_outlined,
  'read_skill' ||
  'read_skill_resource' ||
  'get_skill_diagnostics' ||
  'reload_skills' => Icons.extension_outlined,
  'search_tags' => Icons.sell_outlined,
  'read' => Icons.description_outlined,
  'web_search' => Icons.travel_explore_outlined,
  'web_read' => Icons.language_outlined,
  String() when toolName.contains('gallery') => Icons.collections_outlined,
  String() when toolName.contains('queue') => Icons.list_alt_outlined,
  _ => Icons.build_outlined,
};

AgentToolVisual agentToolVisual(ThemeData theme, String toolName) =>
    AgentToolVisual(
      icon: agentToolIcon(toolName),
      color: theme.colorScheme.onSurfaceVariant,
    );

Color agentToolSuccessColor(ThemeData theme) =>
    theme.brightness == Brightness.dark
    ? Colors.green.shade400
    : Colors.green.shade700;

String agentToolResultDefaultSummary(
  BuildContext context,
  ToolResultMessage result,
) => agentToolResultSummary(
  context,
  result,
  fallback: result.isError
      ? context.l10n.common_error
      : context.l10n.common_success,
);

String agentToolResultSummary(
  BuildContext context,
  ToolResultMessage result, {
  required String fallback,
}) {
  final structured = structuredAgentToolResultSummary(context.l10n, result);
  if (structured != null) return structured;
  final text = result.text.trim();
  if (text.isEmpty) return fallback;
  return safeAgentToolTextSummary(
    text,
    fallback: fallback,
    failed: result.isError,
  );
}

String safeAgentToolTextSummary(
  String text, {
  required String fallback,
  required bool failed,
}) {
  final summary = AgentToolPresentation.summary(text, fallback: fallback);
  if (!failed) return summary;
  final diagnostic = RegExp(
    r'(RequestOptions|DioException|validateStatus|response\.data|stack\s*trace|package:[^\s]+\.dart|API_ERROR|authorization\s*:|bearer\s+)',
    caseSensitive: false,
  );
  if (diagnostic.hasMatch(text) || diagnostic.hasMatch(summary)) {
    final status = RegExp(
      r'(?:HTTP(?: status)?[: ]+|status code of\s*)(\d{3})',
      caseSensitive: false,
    ).firstMatch(text);
    return status == null ? fallback : '$fallback (HTTP ${status.group(1)})';
  }
  return summary;
}

String agentToolResultDetailText(ToolResultMessage result) {
  final sections = <String>[];
  for (final content in result.content.whereType<ToolResultTextContent>()) {
    if (content.text.trim().isNotEmpty) {
      sections.add(formatAgentToolDetailText(content.text));
    }
  }
  if (result.details != null) {
    final formatted = formatAgentToolDetailValue(result.details);
    if (formatted.isNotEmpty && !sections.contains(formatted)) {
      sections.add(formatted);
    }
  }
  return sections.join('\n\n');
}

String formatAgentToolDetailText(String text) {
  return AgentToolPresentation.formattedDetails(text);
}

String formatAgentToolDetailValue(Object? value) {
  if (value == null) return '';
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } on JsonUnsupportedObjectError {
    return value.toString();
  }
}
