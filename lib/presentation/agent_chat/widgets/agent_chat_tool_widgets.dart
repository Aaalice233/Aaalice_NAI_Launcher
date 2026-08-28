import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/agent/agent_types.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_resolution_adapter.dart';
import '../../../../data/models/gallery/local_image_record.dart';
import '../../utils/image_detail_opener.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../services/image_send_action_dispatcher.dart';
import '../../widgets/common/image_card_hover_motion.dart';
import '../../widgets/common/image_detail/file_image_detail_data.dart';
import '../../widgets/gallery/draggable_image_card.dart';
import '../../widgets/gallery/local_image_context_menu.dart';
import '../providers/agent_chat_notifier.dart';

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
    _ => toolName,
  };
}

_AgentToolVisual _agentToolVisual(ThemeData theme, String toolName) {
  final colors = theme.colorScheme;
  Color muted(Color accent) =>
      Color.lerp(colors.onSurfaceVariant, accent, 0.36)!;
  final primary = muted(colors.primary);
  final secondary = muted(colors.secondary);
  final tertiary = muted(colors.tertiary);
  final imageColor = muted(Color.lerp(colors.primary, colors.tertiary, 0.55)!);
  final settingsColor = muted(
    Color.lerp(colors.primary, colors.secondary, 0.5)!,
  );
  final skillColor = muted(Color.lerp(colors.secondary, colors.tertiary, 0.5)!);
  final tagColor = muted(Color.lerp(colors.secondary, colors.error, 0.22)!);
  final readColor = muted(Color.lerp(colors.tertiary, colors.onSurface, 0.3)!);
  final webColor = muted(Color.lerp(colors.secondary, colors.primary, 0.4)!);
  return switch (toolName) {
    'generate_image' => _AgentToolVisual(
      icon: Icons.auto_awesome,
      color: primary,
    ),
    'queue_image_task' => _AgentToolVisual(
      icon: Icons.schedule_send_outlined,
      color: primary,
    ),
    'interrogate_image' || 'get_recent_images' || 'get_generation_status' =>
      _AgentToolVisual(icon: Icons.image_search_outlined, color: imageColor),
    'get_generation_settings' || 'update_generation_settings' =>
      _AgentToolVisual(icon: Icons.tune, color: settingsColor),
    'get_prompt_state' || 'set_positive_prompt' || 'set_negative_prompt' =>
      _AgentToolVisual(icon: Icons.edit_note, color: secondary),
    'add_character' || 'update_character' || 'remove_character' =>
      _AgentToolVisual(icon: Icons.manage_accounts_outlined, color: tertiary),
    'read_skill' ||
    'read_skill_resource' ||
    'get_skill_diagnostics' ||
    'reload_skills' => _AgentToolVisual(
      icon: Icons.extension_outlined,
      color: skillColor,
    ),
    'search_tags' => _AgentToolVisual(
      icon: Icons.sell_outlined,
      color: tagColor,
    ),
    'read' => _AgentToolVisual(
      icon: Icons.description_outlined,
      color: readColor,
    ),
    'web_search' => _AgentToolVisual(
      icon: Icons.travel_explore_outlined,
      color: webColor,
    ),
    'web_read' => _AgentToolVisual(
      icon: Icons.language_outlined,
      color: webColor,
    ),
    _ => _AgentToolVisual(
      icon: Icons.build_outlined,
      color: colors.onSurfaceVariant,
    ),
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final progress = Curves.easeInOut.transform(animation.value);
          final changingColor = Color.lerp(
            visual.color,
            Color.lerp(
              theme.colorScheme.onSurfaceVariant,
              theme.colorScheme.primary,
              0.32,
            )!,
            0.16 + progress * 0.24,
          )!;
          return Container(
            key: ValueKey('agent-tool-activity-${activity.toolCallId}'),
            constraints: const BoxConstraints(minHeight: 28),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              gradient: activity.status == AgentToolActivityStatus.running
                  ? LinearGradient(
                      begin: Alignment(-1.15 + progress * 0.45, -0.35),
                      end: Alignment(0.45 + progress * 0.45, 0.35),
                      colors: [
                        theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.42,
                        ),
                        changingColor.withValues(alpha: 0.13),
                        theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.38,
                        ),
                      ],
                      stops: const [0, 0.52, 1],
                    )
                  : null,
              color: activity.status == AgentToolActivityStatus.running
                  ? null
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.42,
                    ),
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
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _summarize(AgentToolActivity activity, String toolLabel) {
    if (activity.status == AgentToolActivityStatus.running) {
      return toolLabel;
    }
    final text = activity.content.trim();
    if (text.isEmpty) return toolLabel;
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    return normalized.length <= 60
        ? normalized
        : '${normalized.substring(0, 60)}…';
  }
}

class AgentChatToolResultTile extends StatelessWidget {
  const AgentChatToolResultTile({super.key, required this.result});

  final ToolResultMessage result;

  @override
  Widget build(BuildContext context) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox.square(
                key: ValueKey('agent-tool-result-icon-${result.toolCallId}'),
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
              Flexible(
                child: Text(
                  toolLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.78),
                    height: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final path in files)
                    _ToolResultImage(key: ValueKey(path), path: path),
                ],
              ),
            ),
        ],
      ),
    );
  }
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
