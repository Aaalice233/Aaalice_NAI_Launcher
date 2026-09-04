import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/director/director_tool_type.dart';
import '../../adaptive/adaptive_layout.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/director_tools_notifier.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/themed_confirm_dialog.dart';

class DirectorToolsScreen extends ConsumerStatefulWidget {
  const DirectorToolsScreen({super.key, required this.sourceImage});

  final Uint8List sourceImage;

  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List sourceImage,
  }) {
    return Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(
        builder: (context) => DirectorToolsScreen(sourceImage: sourceImage),
      ),
    );
  }

  @override
  ConsumerState<DirectorToolsScreen> createState() =>
      _DirectorToolsScreenState();
}

class _DirectorToolsScreenState extends ConsumerState<DirectorToolsScreen> {
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(directorToolsNotifierProvider.notifier).init(widget.sourceImage);
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(directorToolsNotifierProvider);

    ref.listen(directorToolsNotifierProvider, (prev, next) {
      if (prev?.prompt != next.prompt &&
          _promptController.text != next.prompt) {
        _promptController.text = next.prompt;
      }
    });

    return LayoutBuilder(
      builder: (context, screenConstraints) {
        final compactActions = AdaptiveBreakpoints.classifyWidth(
          screenConstraints.maxWidth,
        ).isCompact;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.l10n.img2img_directorTools,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (state.result != null)
                if (compactActions)
                  IconButton(
                    constraints: BoxConstraints.tightFor(
                      width: context.interactionPolicy.minimumControlExtent,
                      height: context.interactionPolicy.minimumControlExtent,
                    ),
                    onPressed: _applyAndReturn,
                    tooltip: context.l10n.img2img_directorApplyAsSource,
                    icon: const Icon(Icons.check),
                  )
                else
                  TextButton.icon(
                    onPressed: _applyAndReturn,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(context.l10n.img2img_directorApplyAsSource),
                  ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final panelWidth = _sidePanelWidth(
                  constraints.maxWidth,
                  textScale,
                );
                final minimumImageWidth =
                    360 + (textScale - 1).clamp(0, 2) * 48;
                final useSidePanel =
                    constraints.maxHeight >= 480 &&
                    constraints.maxWidth - panelWidth - 1 >= minimumImageWidth;
                return useSidePanel
                    ? _buildSideBySideLayout(
                        theme,
                        state,
                        panelWidth: panelWidth,
                      )
                    : _buildStackedLayout(theme, state);
              },
            ),
          ),
        );
      },
    );
  }

  double _sidePanelWidth(double availableWidth, double textScale) {
    final scaleAllowance = (textScale - 1).clamp(0, 2) * 24;
    return (availableWidth * 0.36 + scaleAllowance).clamp(320, 400);
  }

  Widget _buildSideBySideLayout(
    ThemeData theme,
    DirectorToolsState state, {
    required double panelWidth,
  }) {
    return Row(
      key: const ValueKey('director-tools-side-by-side-layout'),
      children: [
        Expanded(flex: 3, child: _buildImageArea(theme, state)),
        VerticalDivider(width: 1, color: theme.dividerColor),
        SizedBox(width: panelWidth, child: _buildControlPanel(theme, state)),
      ],
    );
  }

  Widget _buildStackedLayout(ThemeData theme, DirectorToolsState state) {
    return Column(
      key: const ValueKey('director-tools-stacked-layout'),
      children: [
        Expanded(flex: 2, child: _buildImageArea(theme, state)),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(flex: 3, child: _buildControlPanel(theme, state)),
      ],
    );
  }

  Widget _buildImageArea(ThemeData theme, DirectorToolsState state) {
    return Container(
      color: Colors.black,
      child: state.result != null
          ? _buildCompareView(state)
          : _buildSingleImageView(state),
    );
  }

  Widget _buildSingleImageView(DirectorToolsState state) {
    final source = state.sourceImage;
    if (source == null) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Image.memory(source, fit: BoxFit.contain, gaplessPlayback: true),
      ),
    );
  }

  Widget _buildCompareView(DirectorToolsState state) {
    if (state.sourceImage == null || state.result == null) {
      return _buildSingleImageView(state);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.img2img_directorSourceImage,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Image.memory(
                        state.sourceImage!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.img2img_directorResult,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Image.memory(
                        state.result!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlPanel(ThemeData theme, DirectorToolsState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.l10n.img2img_directorToolsHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        _buildToolSelector(theme, state),
        const SizedBox(height: 16),
        ..._buildToolOptions(theme, state),
        const SizedBox(height: 20),
        _buildRunButton(theme, state),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Text(
            state.error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (state.result != null) ...[
          const SizedBox(height: 16),
          _buildResultActions(theme, state),
        ],
      ],
    );
  }

  Widget _buildToolSelector(ThemeData theme, DirectorToolsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tool in DirectorToolType.values)
          _ToolListTile(
            tool: tool,
            isSelected: state.selectedTool == tool,
            onTap: () {
              ref.read(directorToolsNotifierProvider.notifier).selectTool(tool);
            },
          ),
      ],
    );
  }

  List<Widget> _buildToolOptions(ThemeData theme, DirectorToolsState state) {
    final tool = state.selectedTool;
    final widgets = <Widget>[];

    if (tool == DirectorToolType.colorize) {
      widgets.addAll(_buildColorizeOptions(theme, state));
    } else if (tool == DirectorToolType.fixEmotion) {
      widgets.addAll(_buildEmotionOptions(theme, state));
    }

    if (tool.needsPrompt) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        TextField(
          controller: _promptController,
          minLines: 1,
          maxLines: 4,
          onChanged: (v) =>
              ref.read(directorToolsNotifierProvider.notifier).updatePrompt(v),
          decoration: InputDecoration(
            labelText: context.l10n.img2img_directorPrompt,
            hintText: context.l10n.img2img_directorPromptHint,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildColorizeOptions(
    ThemeData theme,
    DirectorToolsState state,
  ) {
    return [
      Row(
        children: [
          Text(
            context.l10n.img2img_directorDefry,
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            '${state.defry}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Slider(
        value: state.defry.toDouble(),
        min: 0,
        max: 5,
        divisions: 5,
        label: '${state.defry}',
        onChanged: (v) => ref
            .read(directorToolsNotifierProvider.notifier)
            .updateDefry(v.round()),
      ),
      Text(
        context.l10n.img2img_directorDefryHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }

  List<Widget> _buildEmotionOptions(ThemeData theme, DirectorToolsState state) {
    return [
      Row(
        children: [
          Text(
            context.l10n.img2img_directorEmotionLevel,
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            '${state.defry}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Slider(
        value: state.defry.toDouble(),
        min: 0,
        max: 5,
        divisions: 5,
        label: '${state.defry}',
        onChanged: (v) => ref
            .read(directorToolsNotifierProvider.notifier)
            .updateDefry(v.round()),
      ),
      Text(
        context.l10n.img2img_directorEmotionLevelHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        context.l10n.img2img_directorEmotionPresets,
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: emotionPresets.map((preset) {
          final notifier = ref.read(directorToolsNotifierProvider.notifier);
          final isActive = notifier.activePreset?.mood == preset.mood;
          return ChoiceChip(
            label: Text(preset.label),
            selected: isActive,
            onSelected: (_) {
              notifier.applyEmotionPreset(preset);
              _promptController.text = preset.extraTags;
            },
          );
        }).toList(),
      ),
    ];
  }

  Widget _buildRunButton(ThemeData theme, DirectorToolsState state) {
    final label = state.selectedTool.labelKey(context.l10n);
    final isOpus = ref.watch(isOpusSubscriptionProvider);
    final cost = state.estimatedAnlasCost(isOpus: isOpus);

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed:
                state.isRunning ||
                    state.imageWidth <= 0 ||
                    state.imageHeight <= 0
                ? null
                : () => _runTool(),
            icon: state.isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              state.isRunning
                  ? context.l10n.img2img_directorRunning
                  : context.l10n.img2img_directorRun(label),
            ),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ),
        if (state.imageWidth > 0 && state.imageHeight > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.diamond_outlined,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  cost == 0 ? 'Free' : '$cost',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultActions(ThemeData theme, DirectorToolsState state) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _applyAndReturn,
            icon: const Icon(Icons.check, size: 18),
            label: Text(context.l10n.img2img_directorApplyAsSource),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              final notifier = ref.read(directorToolsNotifierProvider.notifier);
              notifier.applyResultAsSource();
              AppToast.success(context, context.l10n.img2img_directorApplied);
            },
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: Text(
              context.l10n.img2img_directorRun(
                context.l10n.img2img_directorTools,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _runTool() async {
    final requestState = ref.read(directorToolsNotifierProvider);
    final label = requestState.selectedTool.labelKey(context.l10n);
    final cost = requestState.estimatedAnlasCost(
      isOpus: ref.read(isOpusSubscriptionProvider),
    );
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.img2img_directorConfirmTitle,
      content: context.l10n.img2img_directorConfirmContent(label, cost),
      confirmText: context.l10n.common_confirm,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.warning,
      icon: Icons.toll_outlined,
    );
    if (!confirmed || !mounted) return;

    final notifier = ref.read(directorToolsNotifierProvider.notifier);
    await notifier.runTool();

    if (!mounted) return;
    final state = ref.read(directorToolsNotifierProvider);
    if (state.result != null) {
      await notifier.registerResult();
      if (mounted) {
        final label = state.selectedTool.labelKey(context.l10n);
        AppToast.success(
          context,
          context.l10n.img2img_directorResultReady(label),
        );
      }
    }
  }

  void _applyAndReturn() {
    final state = ref.read(directorToolsNotifierProvider);
    if (state.result != null) {
      Navigator.pop(context, state.result);
    }
  }
}

class _ToolListTile extends StatelessWidget {
  const _ToolListTile({
    required this.tool,
    required this.isSelected,
    required this.onTap,
  });

  final DirectorToolType tool;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = tool.labelKey(context.l10n);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                tool.icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  softWrap: true,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
