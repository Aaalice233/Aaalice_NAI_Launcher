import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../services/image_send_action_dispatcher.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/image_card_hover_motion.dart';
import '../../widgets/common/image_detail/file_image_detail_data.dart';
import '../../widgets/gallery/draggable_image_card.dart';
import '../../widgets/gallery/local_image_context_menu.dart';
import '../providers/agent_chat_notifier.dart';
import '../services/agent_resource_resolver.dart';

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
    'get_generation_status' => l10n.agentChat_toolGenerationStatus,
    'get_generation_settings' => l10n.agentChat_toolGetGenerationSettings,
    'update_generation_settings' => l10n.agentChat_toolUpdateGenerationSettings,
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

_AgentToolVisual _agentToolVisual(ThemeData theme, String toolName) {
  final neutral = theme.colorScheme.onSurfaceVariant;
  return switch (toolName) {
    'generate_image' => _AgentToolVisual(
      icon: Icons.auto_awesome,
      color: neutral,
    ),
    'queue_image_task' => _AgentToolVisual(
      icon: Icons.schedule_send_outlined,
      color: neutral,
    ),
    'interrogate_image' || 'get_recent_images' || 'get_generation_status' =>
      _AgentToolVisual(icon: Icons.image_search_outlined, color: neutral),
    'get_generation_settings' || 'update_generation_settings' =>
      _AgentToolVisual(icon: Icons.tune, color: neutral),
    'get_prompt_state' || 'set_positive_prompt' || 'set_negative_prompt' =>
      _AgentToolVisual(icon: Icons.edit_note, color: neutral),
    'add_character' || 'update_character' || 'remove_character' =>
      _AgentToolVisual(icon: Icons.manage_accounts_outlined, color: neutral),
    'read_skill' ||
    'read_skill_resource' ||
    'get_skill_diagnostics' ||
    'reload_skills' => _AgentToolVisual(
      icon: Icons.extension_outlined,
      color: neutral,
    ),
    'search_tags' => _AgentToolVisual(
      icon: Icons.sell_outlined,
      color: neutral,
    ),
    'read' => _AgentToolVisual(
      icon: Icons.description_outlined,
      color: neutral,
    ),
    'web_search' => _AgentToolVisual(
      icon: Icons.travel_explore_outlined,
      color: neutral,
    ),
    'web_read' => _AgentToolVisual(
      icon: Icons.language_outlined,
      color: neutral,
    ),
    _ => _AgentToolVisual(icon: Icons.build_outlined, color: neutral),
  };
}

class AgentChatToolActivityTile extends StatefulWidget {
  const AgentChatToolActivityTile({super.key, required this.activity});

  final AgentToolActivity activity;

  @override
  State<AgentChatToolActivityTile> createState() =>
      _AgentChatToolActivityTileState();
}

class _AgentChatToolActivityTileState extends State<AgentChatToolActivityTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gradientController;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _gradientController
        ..stop()
        ..value = 0.5;
    } else if (!_gradientController.isAnimating) {
      _gradientController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = widget.activity;
    final toolLabel = agentToolLabel(context, activity.toolName);
    final visual = _agentToolVisual(theme, activity.toolName);
    final statusColor = activity.status == AgentToolActivityStatus.failed
        ? Color.lerp(
            theme.colorScheme.onSurfaceVariant,
            theme.colorScheme.error,
            0.48,
          )!
        : visual.color;
    final statusLabel = activity.status == AgentToolActivityStatus.running
        ? context.l10n.agentChat_toolRunning
        : toolLabel;
    final icon = activity.status == AgentToolActivityStatus.failed
        ? Icons.error_outline
        : visual.icon;
    final animation = MediaQuery.disableAnimationsOf(context)
        ? const AlwaysStoppedAnimation<double>(0.5)
        : _gradientController;
    final details = _activityDetails(activity);
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final progress = Curves.easeInOut.transform(animation.value);
              final changingColor = Color.lerp(
                visual.color,
                Color.lerp(
                  theme.colorScheme.onSurfaceVariant,
                  theme.colorScheme.onSurface,
                  0.18,
                )!,
                0.16 + progress * 0.24,
              )!;
              return Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: ValueKey('agent-tool-activity-${activity.toolCallId}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: details.isEmpty
                      ? null
                      : () => setState(() => _expanded = !_expanded),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 28),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient:
                            activity.status == AgentToolActivityStatus.running
                            ? LinearGradient(
                                begin: Alignment(
                                  -1.15 + progress * 0.45,
                                  -0.35,
                                ),
                                end: Alignment(0.45 + progress * 0.45, 0.35),
                                colors: [
                                  theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.42),
                                  changingColor.withValues(alpha: 0.13),
                                  theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.38),
                                ],
                                stops: const [0, 0.52, 1],
                              )
                            : null,
                        color:
                            activity.status == AgentToolActivityStatus.running
                            ? null
                            : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox.square(
                            key: ValueKey(
                              'agent-tool-activity-icon-${activity.toolCallId}',
                            ),
                            dimension: 18,
                            child: Center(
                              child: Icon(icon, size: 15, color: statusColor),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(statusLabel, style: theme.textTheme.labelSmall),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _summarize(activity, toolLabel),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor.withValues(alpha: 0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (details.isNotEmpty)
                            Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_expanded)
            _ToolDetailPanel(
              key: ValueKey(
                'agent-tool-activity-details-${activity.toolCallId}',
              ),
              text: details,
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  String _summarize(AgentToolActivity activity, String toolLabel) {
    if (activity.status == AgentToolActivityStatus.running) {
      return toolLabel;
    }
    return _humanReadableTextSummary(activity.content, fallback: toolLabel);
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
  const AgentChatToolResultTile({super.key, required this.result});

  final ToolResultMessage result;

  @override
  State<AgentChatToolResultTile> createState() =>
      _AgentChatToolResultTileState();
}

class _AgentChatToolResultTileState extends State<AgentChatToolResultTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final theme = Theme.of(context);
    final toolLabel = agentToolLabel(context, result.toolName);
    final visual = _agentToolVisual(theme, result.toolName);
    final color = result.isError
        ? Color.lerp(
            theme.colorScheme.onSurfaceVariant,
            theme.colorScheme.error,
            0.48,
          )!
        : visual.color;
    final files = _extractImageFiles(result);
    final preferFileImages =
        files.isNotEmpty &&
        result.details is Map &&
        (result.details as Map)['preferFileImages'] == true;
    final inlineImages = preferFileImages
        ? const <Uint8List>[]
        : _extractInlineImages(result);
    final remoteImages = preferFileImages
        ? const <String>[]
        : _extractRemoteImages(
            result,
          ).where((url) => !files.contains(url)).toList(growable: false);
    final resourceReferences =
        files.isEmpty && inlineImages.isEmpty && remoteImages.isEmpty
        ? _extractResourceReferences(result)
        : const <AgentChatResourceReference>[];
    final detailText = _resultDetailText(result);
    final summary = _resultSummary(context, result);
    final hasExpandedContent =
        detailText.isNotEmpty ||
        files.isNotEmpty ||
        inlineImages.isNotEmpty ||
        remoteImages.isNotEmpty ||
        resourceReferences.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('agent-tool-result-${result.toolCallId}'),
              borderRadius: BorderRadius.circular(8),
              onTap: !hasExpandedContent
                  ? null
                  : () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      key: ValueKey(
                        'agent-tool-result-icon-${result.toolCallId}',
                      ),
                      dimension: 18,
                      child: Center(
                        child: Icon(
                          result.isError ? Icons.error_outline : visual.icon,
                          size: 15,
                          color: color.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$toolLabel · ${result.isError ? context.l10n.common_error : context.l10n.common_success} · $summary',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color.withValues(alpha: 0.9),
                          height: 1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasExpandedContent)
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 17,
                        color: color.withValues(alpha: 0.78),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded && detailText.isNotEmpty)
            _ToolDetailPanel(
              key: ValueKey('agent-tool-result-details-${result.toolCallId}'),
              text: detailText,
            ),
          if (_expanded &&
              (files.isNotEmpty ||
                  inlineImages.isNotEmpty ||
                  remoteImages.isNotEmpty ||
                  resourceReferences.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final path in files)
                    _ToolResultImage(key: ValueKey(path), path: path),
                  for (var index = 0; index < inlineImages.length; index++)
                    _ToolResultInlineImage(
                      key: ValueKey('${result.toolCallId}-inline-$index'),
                      bytes: inlineImages[index],
                    ),
                  for (final url in remoteImages)
                    _ToolResultNetworkImage(key: ValueKey(url), url: url),
                  for (final reference in resourceReferences)
                    _ToolResultResourcePreview(reference: reference),
                ],
              ),
            ),
        ],
      ),
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

String _resultSummary(BuildContext context, ToolResultMessage result) {
  final text = result.text.trim();
  if (text.isEmpty) {
    return result.isError
        ? context.l10n.common_error
        : context.l10n.common_success;
  }
  return _humanReadableTextSummary(
    text,
    fallback: result.isError
        ? context.l10n.common_error
        : context.l10n.common_success,
  );
}

String _humanReadableTextSummary(String text, {required String fallback}) {
  return AgentToolPresentation.summary(text, fallback: fallback);
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
/// Groups stay compact by default while their title keeps failures visible.
class AgentChatToolResultGroup extends StatelessWidget {
  const AgentChatToolResultGroup({super.key, required this.results});

  final List<ToolResultMessage> results;

  @override
  Widget build(BuildContext context) {
    if (results.length == 1) {
      return AgentChatToolResultTile(result: results.single);
    }
    final theme = Theme.of(context);
    final failed = results.where((result) => result.isError).length;
    String? failureSummary;
    for (final result in results) {
      if (result.isError) {
        failureSummary = _resultSummary(context, result);
        break;
      }
    }
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          key: PageStorageKey(
            'agent-tool-group-${results.first.toolCallId}-${results.length}',
          ),
          initiallyExpanded: false,
          expansionAnimationStyle: disableAnimations
              ? const AnimationStyle(
                  duration: Duration.zero,
                  reverseDuration: Duration.zero,
                )
              : null,
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.only(left: 12),
          minTileHeight: 34,
          leading: Icon(
            failed > 0 ? Icons.error_outline : Icons.task_alt_outlined,
            size: 17,
            color: failed > 0
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(
            context.l10n.agentChat_toolGroupCount(results.length),
            style: theme.textTheme.labelMedium,
          ),
          subtitle: Text(
            [
              if (failed > 0) context.l10n.common_error,
              if (failureSummary != null) failureSummary,
              ...results
                  .map((result) => agentToolLabel(context, result.toolName))
                  .toSet(),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            for (final result in results)
              AgentChatToolResultTile(result: result),
          ],
        ),
      ),
    );
  }
}

class AgentChatReasoningTile extends StatelessWidget {
  const AgentChatReasoningTile({
    super.key,
    required this.thinking,
    this.live = false,
  });

  final String thinking;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          key: ValueKey('agent-reasoning-${thinking.hashCode}-$live'),
          initiallyExpanded: live,
          minTileHeight: 32,
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.fromLTRB(28, 0, 8, 8),
          leading: live
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                )
              : Icon(
                  Icons.psychology_alt_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          title: Text(
            context.l10n.agentChat_reasoning,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                thinking,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
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

class _ToolResultResourcePreview extends ConsumerStatefulWidget {
  const _ToolResultResourcePreview({required this.reference});

  final AgentChatResourceReference reference;

  @override
  ConsumerState<_ToolResultResourcePreview> createState() =>
      _ToolResultResourcePreviewState();
}

class _ToolResultResourcePreviewState
    extends ConsumerState<_ToolResultResourcePreview> {
  late Future<ResolvedAgentResource?> _resolution;

  @override
  void initState() {
    super.initState();
    _resolution = ref
        .read(agentChatNotifierProvider.notifier)
        .resolveResourcePreview(widget.reference);
  }

  @override
  void didUpdateWidget(covariant _ToolResultResourcePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference) {
      _resolution = ref
          .read(agentChatNotifierProvider.notifier)
          .resolveResourcePreview(widget.reference);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ResolvedAgentResource?>(
    future: _resolution,
    builder: (context, snapshot) {
      final bytes = snapshot.data?.bytes;
      return bytes == null
          ? const SizedBox.shrink()
          : _ToolResultInlineImage(bytes: bytes);
    },
  );
}

class _ToolResultInlineImage extends StatelessWidget {
  const _ToolResultInlineImage({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _ToolResultNetworkImage extends StatelessWidget {
  const _ToolResultNetworkImage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
  final action = await LocalImageContextMenu.showSendActions(
    context,
    position: position,
    isKritaConnected: isKritaConnected,
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

  void _showSendMenu(TapDownDetails details) {
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
                  onSecondaryTapDown: _showSendMenu,
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
