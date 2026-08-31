import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_media_display_policy.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/agent/agent_tool_presentation.dart';
import '../../../core/windowing/agent_chat_shared_widgets.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../utils/image_detail_opener.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/watermark_settings_provider.dart';
import '../../screens/online_gallery/online_gallery_detail_launcher.dart';
import '../../services/image_send_action_dispatcher.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/image_card_hover_motion.dart';
import '../../widgets/common/image_detail/file_image_detail_data.dart';
import '../../widgets/common/image_detail/image_detail_data.dart';
import '../../widgets/gallery/draggable_image_card.dart';
import '../../widgets/gallery/local_image_context_menu.dart';
import '../providers/agent_chat_notifier.dart';
import '../services/agent_resource_resolver.dart';
import 'agent_chat_resource_widgets.dart';

class _AgentToolVisual {
  const _AgentToolVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

String agentToolLabel(BuildContext context, String toolName) {
  final l10n = context.l10n;
  return switch (toolName) {
    'generate_image' => l10n.agentChat_toolGenerateImage,
    'queue_image_task' => l10n.agentChat_toolQueueImageTask,
    'interrogate_image' => l10n.agentChat_toolInterrogateImage,
    'get_recent_images' => l10n.agentChat_toolRecentImages,
    'display_images' => l10n.agentChat_toolDisplayImages,
    'get_generation_status' => l10n.agentChat_toolGenerationStatus,
    'get_generation_settings' => l10n.agentChat_toolGetGenerationSettings,
    'update_generation_settings' => l10n.agentChat_toolUpdateGenerationSettings,
    'get_generation_source_image' => l10n.agentChat_toolGetGenerationSourceImage,
    'set_generation_source_image' => l10n.agentChat_toolSetGenerationSourceImage,
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
    'create_manual_inpaint_draft' => l10n.agentChat_toolCreateInpaint,
    'list_manual_inpaint_drafts' => l10n.agentChat_toolListInpaint,
    'get_manual_inpaint_draft' => l10n.agentChat_toolInspectInpaint,
    'cancel_manual_inpaint_draft' => l10n.agentChat_toolCancelInpaint,
    'reedit_manual_inpaint_draft' => l10n.agentChat_toolReeditInpaint,
    'submit_manual_inpaint_draft' => l10n.agentChat_toolSubmitInpaint,
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
  'interrogate_image' ||
  'get_recent_images' ||
  'preview_generated_image' ||
  'get_generation_status' => Icons.image_search_outlined,
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

_AgentToolVisual _agentToolVisual(ThemeData theme, String toolName) =>
    _AgentToolVisual(
      icon: agentToolIcon(toolName),
      color: theme.colorScheme.onSurfaceVariant,
    );

Color agentToolSuccessColor(ThemeData theme) =>
    theme.brightness == Brightness.dark
    ? Colors.green.shade400
    : Colors.green.shade700;

class AgentChatToolActivityTile extends StatefulWidget {
  const AgentChatToolActivityTile({super.key, required this.activity});

  final AgentToolActivity activity;

  @override
  State<AgentChatToolActivityTile> createState() =>
      _AgentChatToolActivityTileState();
}

class _AgentChatToolActivityTileState extends State<AgentChatToolActivityTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = widget.activity;
    final toolLabel = agentToolLabel(context, activity.toolName);
    final visual = _agentToolVisual(theme, activity.toolName);
    final statusColor = switch (activity.status) {
      AgentToolActivityStatus.running => visual.color,
      AgentToolActivityStatus.succeeded => agentToolSuccessColor(theme),
      AgentToolActivityStatus.failed => theme.colorScheme.error,
    };
    final statusLabel = activity.status == AgentToolActivityStatus.running
        ? context.l10n.agentChat_toolRunning
        : '';
    final statusIcon = switch (activity.status) {
      AgentToolActivityStatus.running => null,
      AgentToolActivityStatus.succeeded => Icons.check_rounded,
      AgentToolActivityStatus.failed => Icons.close_rounded,
    };
    final details = _activityDetails(activity);
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ToolStepRow(
            key: ValueKey('agent-tool-activity-${activity.toolCallId}'),
            iconKey: ValueKey(
              'agent-tool-activity-icon-${activity.toolCallId}',
            ),
            icon: visual.icon,
            iconColor: visual.color,
            title: toolLabel,
            summary: _summarize(activity),
            status: statusLabel,
            statusIcon: statusIcon,
            statusIconKey: ValueKey(
              'agent-tool-activity-status-${activity.toolCallId}',
            ),
            statusColor: statusColor,
            statusSemanticsLabel:
                activity.status == AgentToolActivityStatus.failed
                ? context.l10n.common_error
                : context.l10n.common_success,
            expanded: _expanded,
            expandable: details.isNotEmpty,
            failure: activity.status == AgentToolActivityStatus.failed,
            onTap: details.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            _ToolDetailPanel(
              key: ValueKey(
                'agent-tool-activity-details-${activity.toolCallId}',
              ),
              text: details,
            ),
        ],
      ),
    );
  }

  String _summarize(AgentToolActivity activity) {
    if (activity.content.trim().isEmpty) return '';
    return _safeToolTextSummary(
      activity.content,
      fallback: '',
      failed: activity.status == AgentToolActivityStatus.failed,
    );
  }

  String _activityDetails(AgentToolActivity activity) {
    final sections = <String>[];
    if (activity.args.isNotEmpty) {
      sections.add(_formatDetailValue(activity.args));
    }
    if (activity.content.trim().isNotEmpty) {
      sections.add(_formatDetailText(activity.content));
    }
    return sections.join('\n\n');
  }
}

class AgentChatToolResultTile extends StatefulWidget {
  const AgentChatToolResultTile({
    super.key,
    required this.result,
    this.initiallyExpanded = false,
    this.showMedia = true,
    this.showRailConnector = false,
    this.nested = false,
  });

  final ToolResultMessage result;
  final bool initiallyExpanded;
  final bool showMedia;
  final bool showRailConnector;
  final bool nested;

  @override
  State<AgentChatToolResultTile> createState() =>
      _AgentChatToolResultTileState();
}

class _AgentChatToolResultTileState extends State<AgentChatToolResultTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final theme = Theme.of(context);
    final toolLabel = widget.nested
        ? context.l10n.agentChat_toolResult
        : agentToolLabel(context, result.toolName);
    final visual = _agentToolVisual(theme, result.toolName);
    final statusColor = result.isError
        ? theme.colorScheme.error
        : agentToolSuccessColor(theme);
    final showMedia =
        widget.showMedia && agentToolDisplaysMedia(result.toolName);
    final files = showMedia ? _extractImageFiles(result) : const <String>[];
    final preferFileImages = files.isNotEmpty;
    final inlineImages = preferFileImages
        ? const <Uint8List>[]
        : _extractInlineImages(result);
    final remoteImages = preferFileImages
        ? const <String>[]
        : _extractRemoteImages(
            result,
          ).where((url) => !files.contains(url)).toList(growable: false);
    final resourceReferences = files.isEmpty
        ? _extractResourceReferences(result)
        : const <AgentChatResourceReference>[];
    final unpairedInlineImages = resourceReferences.isEmpty
        ? inlineImages
        : inlineImages.skip(resourceReferences.length).toList(growable: false);
    final detailText = _resultDetailText(result);
    final statusLabel = result.isError
        ? context.l10n.common_error
        : context.l10n.common_success;
    final rawSummary = _resultSummary(context, result);
    final summary = rawSummary == statusLabel ? '' : rawSummary;
    final hasMedia =
        files.isNotEmpty ||
        unpairedInlineImages.isNotEmpty ||
        remoteImages.isNotEmpty ||
        resourceReferences.isNotEmpty;
    final hasExpandedContent = detailText.isNotEmpty || (showMedia && hasMedia);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ToolStepRow(
          key: ValueKey('agent-tool-result-${result.toolCallId}'),
          iconKey: ValueKey('agent-tool-result-icon-${result.toolCallId}'),
          icon: visual.icon,
          iconColor: visual.color,
          title: toolLabel,
          summary: summary,
          status: '',
          statusIcon: widget.nested
              ? null
              : result.isError
              ? Icons.close_rounded
              : Icons.check_rounded,
          statusIconKey: ValueKey(
            'agent-tool-result-status-${result.toolCallId}',
          ),
          statusColor: statusColor,
          statusSemanticsLabel: statusLabel,
          expanded: _expanded,
          expandable: hasExpandedContent,
          failure: result.isError,
          showIcon: !widget.nested,
          showRailConnector: widget.showRailConnector,
          onTap: !hasExpandedContent
              ? null
              : () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded && detailText.isNotEmpty)
          _ToolDetailPanel(
            key: ValueKey('agent-tool-result-details-${result.toolCallId}'),
            text: detailText,
          ),
        if (_expanded && showMedia && hasMedia)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 8, 8),
            child: AgentChatResourceGallery(
              children: [
                for (final path in files)
                  _ToolResultImage(key: ValueKey(path), path: path),
                ..._buildResourcePreviewWidgets(
                  references: resourceReferences,
                  inlineImages: inlineImages,
                  keyPrefix: '${result.toolCallId}-ref',
                ),
                for (
                  var index = 0;
                  index < unpairedInlineImages.length;
                  index++
                )
                  _ToolResultInlineImage(
                    key: ValueKey('${result.toolCallId}-inline-$index'),
                    bytes: unpairedInlineImages[index],
                  ),
                for (final url in remoteImages)
                  _ToolResultNetworkImage(key: ValueKey(url), url: url),
              ],
            ),
          ),
      ],
    );
  }
}

class AgentChatToolResultMedia extends StatelessWidget {
  const AgentChatToolResultMedia({
    super.key,
    required this.result,
    this.resolveResource,
  });

  final ToolResultMessage result;
  final Future<ResolvedAgentResource?> Function(
    AgentChatResourceReference reference,
  )?
  resolveResource;

  @override
  Widget build(BuildContext context) {
    if (!agentToolDisplaysMedia(result.toolName)) {
      return const SizedBox.shrink();
    }
    final files = _extractImageFiles(result);
    final preferFileImages = files.isNotEmpty;
    final inlineImages = preferFileImages
        ? const <Uint8List>[]
        : _extractInlineImages(result);
    final remoteImages = preferFileImages
        ? const <String>[]
        : _extractRemoteImages(
            result,
          ).where((url) => !files.contains(url)).toList(growable: false);
    final resourceReferences = files.isEmpty
        ? _extractResourceReferences(result)
        : const <AgentChatResourceReference>[];
    final unpairedInlineImages = resourceReferences.isEmpty
        ? inlineImages
        : inlineImages.skip(resourceReferences.length).toList(growable: false);
    if (files.isEmpty &&
        unpairedInlineImages.isEmpty &&
        remoteImages.isEmpty &&
        resourceReferences.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: ValueKey('agent-tool-media-${result.toolCallId}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: AgentChatResourceGallery(
        children: [
          for (final path in files)
            _ToolResultImage(key: ValueKey(path), path: path),
          ..._buildResourcePreviewWidgets(
            references: resourceReferences,
            inlineImages: inlineImages,
            keyPrefix: '${result.toolCallId}-media-ref',
            resolveResource: resolveResource,
          ),
          for (var index = 0; index < unpairedInlineImages.length; index++)
            _ToolResultInlineImage(
              key: ValueKey('${result.toolCallId}-media-inline-$index'),
              bytes: unpairedInlineImages[index],
            ),
          for (final url in remoteImages)
            _ToolResultNetworkImage(key: ValueKey(url), url: url),
        ],
      ),
    );
  }
}

class _ToolTaskHeader extends StatelessWidget {
  const _ToolTaskHeader({
    required this.icon,
    required this.title,
    required this.statusIcon,
    required this.statusLabel,
    required this.statusColor,
    required this.expanded,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final IconData statusIcon;
  final String statusLabel;
  final Color statusColor;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: statusLabel,
                  child: ExcludeSemantics(
                    child: Icon(statusIcon, size: 16, color: statusColor),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolStepRow extends StatelessWidget {
  const _ToolStepRow({
    super.key,
    required this.iconKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.summary,
    required this.status,
    required this.expanded,
    required this.expandable,
    required this.onTap,
    this.statusIcon,
    this.statusIconKey,
    this.statusColor,
    this.statusSemanticsLabel,
    this.failure = false,
    this.showIcon = true,
    this.showRailConnector = false,
  });

  final Key iconKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String summary;
  final String status;
  final bool expanded;
  final bool expandable;
  final VoidCallback? onTap;
  final IconData? statusIcon;
  final Key? statusIconKey;
  final Color? statusColor;
  final String? statusSemanticsLabel;
  final bool failure;
  final bool showIcon;
  final bool showRailConnector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: failure
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.18)
              : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showIcon) ...[
                      SizedBox.square(
                        key: iconKey,
                        dimension: 18,
                        child: Icon(icon, size: 17, color: iconColor),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium,
                          ),
                          if (summary.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: failure
                                    ? theme.colorScheme.onErrorContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (status.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        status,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor ?? iconColor,
                        ),
                      ),
                    ],
                    if (statusIcon case final statusIcon?) ...[
                      const SizedBox(width: 8),
                      Semantics(
                        label: statusSemanticsLabel,
                        child: ExcludeSemantics(
                          child: Icon(
                            statusIcon,
                            key: statusIconKey,
                            size: 16,
                            color: statusColor ?? iconColor,
                          ),
                        ),
                      ),
                    ],
                    if (expandable) ...[
                      const SizedBox(width: 2),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showRailConnector)
          Positioned(
            left: -6,
            top: 23,
            child: IgnorePointer(
              child: Container(
                width: 16,
                height: 2,
                color: iconColor.withValues(alpha: 0.38),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToolDetailPanel extends StatelessWidget {
  const _ToolDetailPanel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AgentToolDetailSurface(
      text: text,
      copyTooltip: context.l10n.common_copy,
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          AppToast.info(context, context.l10n.common_copied);
        }
      },
    );
  }
}

String _resultSummary(BuildContext context, ToolResultMessage result) =>
    agentToolResultSummary(
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
  final text = result.text.trim();
  if (text.isEmpty) return fallback;
  return _safeToolTextSummary(text, fallback: fallback, failed: result.isError);
}

String _safeToolTextSummary(
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

String _resultDetailText(ToolResultMessage result) {
  final sections = <String>[];
  for (final content in result.content.whereType<ToolResultTextContent>()) {
    if (content.text.trim().isNotEmpty) {
      sections.add(_formatDetailText(content.text));
    }
  }
  if (result.details != null) {
    final formatted = _formatDetailValue(result.details);
    if (formatted.isNotEmpty && !sections.contains(formatted)) {
      sections.add(formatted);
    }
  }
  return sections.join('\n\n');
}

String _formatDetailText(String text) {
  return AgentToolPresentation.formattedDetails(text);
}

String _formatDetailValue(Object? value) {
  if (value == null) return '';
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } on JsonUnsupportedObjectError {
    return value.toString();
  }
}

/// Keeps consecutive tool results in one quiet, auditable turn activity unit.
/// The group keeps consecutive steps visible while each verbose payload stays
/// collapsed until requested.
class AgentChatToolResultGroup extends StatefulWidget {
  const AgentChatToolResultGroup({super.key, required this.results});

  final List<ToolResultMessage> results;

  @override
  State<AgentChatToolResultGroup> createState() =>
      _AgentChatToolResultGroupState();
}

class _AgentChatToolResultGroupState extends State<AgentChatToolResultGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    if (results.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final failed = results.where((result) => result.isError).length;
    final status = failed > 0
        ? context.l10n.common_error
        : context.l10n.common_success;
    final statusColor = failed > 0
        ? theme.colorScheme.error
        : agentToolSuccessColor(theme);
    return Container(
      key: PageStorageKey(
        'agent-tool-group-${results.first.toolCallId}-${results.length}',
      ),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: failed > 0
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.16)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ToolTaskHeader(
            icon: failed > 0
                ? Icons.error_outline_rounded
                : Icons.task_alt_outlined,
            title: context.l10n.agentChat_toolGroupCount(results.length),
            statusIcon: failed > 0 ? Icons.close_rounded : Icons.check_rounded,
            statusLabel: status,
            statusColor: statusColor,
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final result in results)
                          AgentChatToolResultTile(
                            result: result,
                            showRailConnector: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AgentChatReasoningTile extends StatefulWidget {
  const AgentChatReasoningTile({
    super.key,
    required this.thinking,
    this.live = false,
  });

  final String thinking;
  final bool live;

  @override
  State<AgentChatReasoningTile> createState() => _AgentChatReasoningTileState();
}

class _AgentChatReasoningTileState extends State<AgentChatReasoningTile> {
  late bool _expanded;
  bool _userOverrodeExpansion = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.live;
  }

  @override
  void didUpdateWidget(covariant AgentChatReasoningTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_userOverrodeExpansion && oldWidget.live != widget.live) {
      _expanded = widget.live;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: InkWell(
            key: const ValueKey('agent-reasoning-toggle'),
            onTap: () {
              setState(() {
                _userOverrodeExpansion = true;
                _expanded = !_expanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      widget.live
                          ? Icons.hourglass_top_rounded
                          : Icons.psychology_alt_outlined,
                      size: 16,
                      color: widget.live
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.agentChat_reasoning,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 8, 8),
            child: SelectableText(
              widget.thinking,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

List<Uint8List> _extractInlineImages(ToolResultMessage result) => [
  for (final content in result.content)
    if (content is ToolResultImageContent && content.image.source.bytes != null)
      content.image.source.bytes!,
];

List<String> _extractRemoteImages(ToolResultMessage result) => [
  for (final content in result.content)
    if (content is ToolResultImageContent && content.image.source.url != null)
      content.image.source.url!,
];

List<AgentChatResourceReference> _extractResourceReferences(
  ToolResultMessage result,
) {
  final references = <AgentChatResourceReference>[];
  final seen = <String>{};

  void collect(Object? value) {
    if (value is Map) {
      final resource = value['resource_ref'];
      if (resource is Map) {
        try {
          final encoded = Map<String, dynamic>.from(resource);
          final key = jsonEncode(encoded);
          if (seen.add(key)) {
            references.add(
              AgentChatResourceReferenceCodec.decodeJsonMap(encoded),
            );
          }
        } on FormatException {
          // Ignore malformed resource metadata from external tools.
        }
      }
      for (final child in value.values) {
        collect(child);
      }
    } else if (value is List) {
      for (final child in value) {
        collect(child);
      }
    }
  }

  collect(result.details);
  for (final content in result.content.whereType<ToolResultTextContent>()) {
    try {
      collect(jsonDecode(content.text));
    } on FormatException {
      // Tool output may be ordinary text.
    }
  }
  return references;
}

List<Widget> _buildResourcePreviewWidgets({
  required List<AgentChatResourceReference> references,
  required List<Uint8List> inlineImages,
  required String keyPrefix,
  Future<ResolvedAgentResource?> Function(AgentChatResourceReference reference)?
  resolveResource,
}) {
  final online = <Widget>[];
  final other = <Widget>[];
  for (var index = 0; index < references.length; index++) {
    final reference = references[index];
    final preview = _ToolResultResourcePreview(
      key: ValueKey('$keyPrefix-$index'),
      reference: reference,
      thumbnailBytes: index < inlineImages.length ? inlineImages[index] : null,
      resolveResource: resolveResource,
    );
    if (reference.kind == AgentChatResourceKind.onlineGalleryMedia) {
      online.add(SizedBox(width: 200, child: preview));
    } else {
      other.add(preview);
    }
  }
  return [
    if (online.isNotEmpty)
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: online,
      ),
    ...other,
  ];
}

class _ToolResultResourcePreview extends ConsumerStatefulWidget {
  const _ToolResultResourcePreview({
    super.key,
    required this.reference,
    this.thumbnailBytes,
    this.resolveResource,
  });

  final AgentChatResourceReference reference;
  final Uint8List? thumbnailBytes;
  final Future<ResolvedAgentResource?> Function(
    AgentChatResourceReference reference,
  )?
  resolveResource;

  @override
  ConsumerState<_ToolResultResourcePreview> createState() =>
      _ToolResultResourcePreviewState();
}

class _ToolResultResourcePreviewState
    extends ConsumerState<_ToolResultResourcePreview> {
  Future<ResolvedAgentResource?>? _resolution;
  bool _opening = false;

  Future<ResolvedAgentResource?> _resolve() => _resolution ??=
      widget.resolveResource?.call(widget.reference) ??
      ref
          .read(agentChatNotifierProvider.notifier)
          .resolveResourcePreview(widget.reference);

  @override
  void didUpdateWidget(covariant _ToolResultResourcePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference) {
      _resolution = null;
      _opening = false;
    }
  }

  Future<void> _openOriginal() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final resolved = await _resolve();
      if (!mounted) return;
      if (resolved == null ||
          (resolved.filePath == null && resolved.bytes == null)) {
        AppToast.error(context, context.l10n.agentChat_resourceUnavailable);
        return;
      }
      if (resolved.onlineGalleryItem case final item?) {
        final detail = resolved.onlineGalleryDetail;
        if (detail == null) {
          AppToast.error(context, context.l10n.agentChat_resourceUnavailable);
          return;
        }
        await OnlineGalleryDetailLauncher(
          context: context,
          ref: ref,
        ).show(context, item, preloadedDetail: detail);
      } else if (resolved.filePath case final path?) {
        ImageDetailOpener.showSingleImmediate(
          context,
          image: FileImageDetailData(filePath: path),
          showMetadataPanel: true,
        );
      } else {
        ImageDetailOpener.showSingleImmediate(
          context,
          image: GeneratedImageDetailData(imageBytes: resolved.bytes!),
          showMetadataPanel: true,
        );
      }
    } on Object {
      if (mounted) {
        AppToast.error(context, context.l10n.agentChat_resourceUnavailable);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _buildPreview(Uint8List bytes) {
    final isOnlineGallery =
        widget.reference.kind == AgentChatResourceKind.onlineGalleryMedia;
    final image = _AgentChatMemoryThumbnail(
      bytes: bytes,
      fit: isOnlineGallery ? BoxFit.cover : BoxFit.contain,
      errorBuilder: (_, _, _) => const _AgentResourceUnavailableImage(),
    );
    if (isOnlineGallery) {
      return _OnlineGalleryResourceCard(
        reference: widget.reference,
        onTap: () => unawaited(_openOriginal()),
        image: image,
      );
    }
    return _ToolResultInteractiveImageCard(
      onTap: () => unawaited(_openOriginal()),
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = widget.thumbnailBytes;
    if (thumbnail != null) return _buildPreview(thumbnail);
    return FutureBuilder<ResolvedAgentResource?>(
      future: _resolve(),
      builder: (context, snapshot) {
        final bytes = snapshot.data?.bytes;
        if (bytes == null) return const _AgentResourceUnavailableImage();
        return _buildPreview(bytes);
      },
    );
  }
}

class _OnlineGalleryResourceCard extends StatefulWidget {
  const _OnlineGalleryResourceCard({
    required this.reference,
    required this.onTap,
    required this.image,
  });

  final AgentChatResourceReference reference;
  final VoidCallback onTap;
  final Widget image;

  @override
  State<_OnlineGalleryResourceCard> createState() =>
      _OnlineGalleryResourceCardState();
}

class _OnlineGalleryResourceCardState
    extends State<_OnlineGalleryResourceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source =
        widget.reference.display['source_label'] ?? widget.reference.source;
    final title = widget.reference.display['title'];
    final author = widget.reference.display['author'];
    final hasDetails = title != null || author != null;
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      label: [source, title, author].whereType<String>().join(', '),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: ImageCardHoverMotion(
          hovered: _hovered,
          child: ClipRRect(
            borderRadius: radius,
            child: Material(
              key: const ValueKey('online-gallery-resource-card'),
              color: theme.colorScheme.surfaceContainerLow,
              child: InkWell(
                onTap: widget.onTap,
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: widget.image,
                          ),
                        ),
                        if (hasDetails)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (title != null)
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge,
                                  ),
                                if (author != null) ...[
                                  if (title != null) const SizedBox(height: 1),
                                  Text(
                                    author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          color: _hovered
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.08,
                                )
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentResourceUnavailableImage extends StatelessWidget {
  const _AgentResourceUnavailableImage();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    height: 120,
    child: Center(
      child: Text(
        context.l10n.agentChat_resourceUnavailable,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _ToolResultInlineImage extends StatelessWidget {
  const _ToolResultInlineImage({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => _ToolResultInteractiveImageCard(
    onTap: () => ImageDetailOpener.showSingleImmediate(
      context,
      image: GeneratedImageDetailData(imageBytes: bytes),
      showMetadataPanel: true,
    ),
    child: _AgentChatMemoryThumbnail(
      bytes: bytes,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}

class _AgentChatMemoryThumbnail extends StatelessWidget {
  const _AgentChatMemoryThumbnail({
    required this.bytes,
    required this.fit,
    required this.errorBuilder,
  });

  final Uint8List bytes;
  final BoxFit fit;
  final ImageErrorWidgetBuilder errorBuilder;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * pixelRatio).ceil()
            : null;
        final height = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * pixelRatio).ceil()
            : null;
        return Image.memory(
          bytes,
          fit: fit,
          alignment: Alignment.center,
          gaplessPlayback: true,
          cacheWidth: width,
          cacheHeight: height,
          errorBuilder: errorBuilder,
        );
      },
    );
  }
}

class _ToolResultNetworkImage extends StatelessWidget {
  const _ToolResultNetworkImage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => _ToolResultInteractiveImageCard(
    onTap: () => _showNetworkImagePreview(context, url),
    child: Image.network(
      url,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}

class _ToolResultInteractiveImageCard extends StatefulWidget {
  const _ToolResultInteractiveImageCard({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_ToolResultInteractiveImageCard> createState() =>
      _ToolResultInteractiveImageCardState();
}

class _ToolResultInteractiveImageCardState
    extends State<_ToolResultInteractiveImageCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: context.l10n.detail_imageDetails,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: ImageCardHoverMotion(
                  hovered: _hovered,
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    foregroundDecoration: BoxDecoration(
                      color: _hovered
                          ? theme.colorScheme.primary.withValues(alpha: 0.07)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showNetworkImagePreview(BuildContext context, String url) {
  final viewport = MediaQuery.sizeOf(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: (viewport.width * 0.86).clamp(280.0, 1080.0).toDouble(),
        height: (viewport.height * 0.82).clamp(240.0, 820.0).toDouble(),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 8,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

List<String> _extractImageFiles(ToolResultMessage result) {
  final details = result.details;
  if (details is Map && details['files'] is List) {
    final files = [
      for (final file in details['files'] as List)
        if (file is String) file,
    ];
    if (files.isNotEmpty) return files;
  }
  for (final content in result.content) {
    if (content is! ToolResultTextContent) continue;
    final text = content.text.trim();
    if (!text.startsWith('{')) continue;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['images'] is List) {
        return [
          for (final image in decoded['images'] as List)
            if (image is Map && image['file'] is String)
              image['file'] as String,
        ];
      }
    } catch (_) {
      // Tool output may be ordinary text rather than a persisted JSON report.
    }
  }
  return const [];
}

const Map<String, Object> _agentChatImageDragLocalData = {
  'source': 'agent_chat_internal',
};

Future<void> _showAgentChatImageSendMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Offset position,
  required String fileName,
  required Future<List<int>> Function() loadBytes,
}) async {
  var isKritaConnected = false;
  try {
    isKritaConnected =
        ref.read(kritaBridgeNotifierProvider).status ==
        KritaBridgeStatus.connected;
  } catch (_) {
    // The remaining image actions stay available during service restoration.
  }
  final watermarkEnabled = ref.read(
    watermarkSettingsProvider.select((state) => state.configuration.enabled),
  );
  final action = await LocalImageContextMenu.showSendActions(
    context,
    position: position,
    isKritaConnected: isKritaConnected,
    watermarkEnabled: watermarkEnabled,
  );
  if (action == null || !context.mounted) return;
  await ImageSendActionDispatcher.handle(
    context: context,
    ref: ref,
    action: action,
    fileName: fileName,
    loadBytes: () async => Uint8List.fromList(await loadBytes()),
  );
}

class _ToolResultImage extends ConsumerStatefulWidget {
  const _ToolResultImage({super.key, required this.path});

  final String path;

  @override
  ConsumerState<_ToolResultImage> createState() => _ToolResultImageState();
}

class _ToolResultImageState extends ConsumerState<_ToolResultImage> {
  static const int _maxHeaderBytes = 64 * 1024;
  static final Map<String, double> _aspectCache = {};
  bool _isHovering = false;

  double _readAspect(File file) {
    final cached = _aspectCache[widget.path];
    if (cached != null) return cached;
    var aspect = 4 / 3;
    RandomAccessFile? handle;
    try {
      final length = file.lengthSync();
      final headerLength = length < _maxHeaderBytes ? length : _maxHeaderBytes;
      handle = file.openSync();
      final dimensions = NaiResolutionAdapter.readImageSize(
        handle.readSync(headerLength),
      );
      if (dimensions != null && dimensions.$1 > 0 && dimensions.$2 > 0) {
        aspect = dimensions.$1 / dimensions.$2;
      }
    } catch (_) {
      // Keep a stable placeholder ratio for damaged or unsupported files.
    } finally {
      handle?.closeSync();
    }
    _aspectCache[widget.path] = aspect;
    return aspect;
  }

  void _openDetail() {
    ImageDetailOpener.showSingleImmediate(
      context,
      image: FileImageDetailData(filePath: widget.path),
      showMetadataPanel: true,
    );
  }

  void _showSendMenu(TapUpDetails details) {
    unawaited(
      _showAgentChatImageSendMenu(
        context: context,
        ref: ref,
        position: details.globalPosition,
        fileName: widget.path.split(RegExp(r'[/\\]')).last,
        loadBytes: () => File(widget.path).readAsBytes(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(widget.path);
    if (!file.existsSync()) return _missing(theme);
    late final LocalImageRecord record;
    try {
      record = LocalImageRecord(
        path: widget.path,
        size: file.lengthSync(),
        modifiedAt: file.lastModifiedSync(),
      );
    } catch (_) {
      return _missing(theme);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
          child: DraggableImageCard(
            record: record,
            localData: _agentChatImageDragLocalData,
            feedbackWidth: 240,
            child: AspectRatio(
              aspectRatio: _readAspect(file),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHovering = true),
                onExit: (_) => setState(() => _isHovering = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openDetail,
                  onSecondaryTapUp: _showSendMenu,
                  child: ImageCardHoverMotion(
                    hovered: _isHovering,
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      foregroundDecoration: BoxDecoration(
                        color: _isHovering
                            ? theme.colorScheme.primary.withValues(alpha: 0.07)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => _missing(theme),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _missing(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      '找不到图片：${widget.path}',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    ),
  );
}
