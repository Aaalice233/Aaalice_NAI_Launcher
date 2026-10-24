import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common/decoded_memory_image.dart';
import '../../widgets/common/image_viewport_surface.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/director/director_emotion.dart';
import '../../../data/models/director/director_prompt_params.dart';
import '../../../data/models/director/director_tool_type.dart';
import '../../adaptive/adaptive_layout.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/director_tools_notifier.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_slider.dart';
import 'widgets/director_result_variant_selector.dart';
import 'widgets/pixel_snap_panel.dart';

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
    _promptController = TextEditingController(
      text: _activePromptText(ref.read(directorToolsNotifierProvider)),
    );
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

    ref.listen(
      directorToolsNotifierProvider.select(_activePromptText),
      (_, next) => _syncPromptController(next),
    );

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

  static String _activePromptText(DirectorToolsState state) =>
      state.activePromptParams?.prompt ?? '';

  /// 输入时状态与输入框本就一致，只有切换工具或重新打开才会改写，光标不会被打断。
  void _syncPromptController(String text) {
    if (_promptController.text == text) return;
    _promptController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
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
      color: ImageViewportSurface.background,
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
        child: _CappedPreview(bytes: source),
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
                    Flexible(child: _CappedPreview(bytes: state.sourceImage!)),
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
                      _resultTitle(state),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: state.selectedTool.producesPixelArt
                          // 像素画按原尺寸解码并最近邻放大，任何重采样都会把刚对齐的硬边缘糊回去。
                          ? Image.memory(
                              state.result!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.none,
                            )
                          : _CappedPreview(
                              key: const ValueKey('director-result-preview'),
                              bytes: state.result!,
                              evictOnDispose: true,
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

  String _resultTitle(DirectorToolsState state) {
    final l10n = context.l10n;
    final selected = state.selectedResult;
    if (state.results.length <= 1 || selected == null) {
      return l10n.img2img_directorResult;
    }
    return l10n.img2img_directorResultWithVariant(
      l10n.img2img_directorResult,
      selected.label(l10n, state.selectedResultIndex),
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
            pixelSnapErrorText(context.l10n, state.errorCause) ?? state.error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (state.pixelSnapResult != null && state.result != null) ...[
          const SizedBox(height: 12),
          PixelSnapSummary(output: state.pixelSnapResult!),
        ],
        if (state.results.length > 1) ...[
          const SizedBox(height: 16),
          DirectorResultVariantSelector(
            results: state.results,
            selectedIndex: state.selectedResultIndex,
            onSelected: ref
                .read(directorToolsNotifierProvider.notifier)
                .selectResult,
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
    } else if (tool == DirectorToolType.pixelSnap) {
      widgets.add(
        PixelSnapOptionsSection(
          options: state.pixelSnap,
          enabled: !state.isRunning,
        ),
      );
    }

    if (state.activePromptParams != null) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        TextField(
          // 各工具各用一个输入框，撤销栈不会把另一个工具的文字撤回来。
          key: ValueKey(tool),
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

  static String _defryText(double defry) => '${defry.round()}';

  List<Widget> _buildDefrySlider(
    ThemeData theme,
    DirectorPromptParams params, {
    required String label,
  }) {
    return [
      Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 8),
          Text(
            _defryText(params.defry.toDouble()),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      NamedSlider(
        label: label,
        valueText: _defryText,
        value: params.defry.toDouble(),
        min: DirectorPromptParams.minDefry.toDouble(),
        max: DirectorPromptParams.maxDefry.toDouble(),
        divisions:
            DirectorPromptParams.maxDefry - DirectorPromptParams.minDefry,
        onChanged: (v) => ref
            .read(directorToolsNotifierProvider.notifier)
            .updateDefry(v.round()),
      ),
    ];
  }

  List<Widget> _buildColorizeOptions(
    ThemeData theme,
    DirectorToolsState state,
  ) {
    return [
      ..._buildDefrySlider(
        theme,
        state.colorizeParams,
        label: context.l10n.img2img_directorDefry,
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
      Text(
        context.l10n.img2img_directorEmotionMood,
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final emotion in DirectorEmotion.values)
            _buildEmotionChip(
              theme,
              emotion,
              selected: state.selectedEmotion == emotion,
            ),
        ],
      ),
      const SizedBox(height: 12),
      ..._buildDefrySlider(
        theme,
        state.emotionParams,
        label: context.l10n.img2img_directorEmotionLevel,
      ),
      Text(
        context.l10n.img2img_directorEmotionLevelHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }

  Widget _buildEmotionChip(
    ThemeData theme,
    DirectorEmotion emotion, {
    required bool selected,
  }) {
    return ChoiceChip(
      // Chip 默认单行淡出，窄屏放大字号时长标签宁可折行也不能被截掉。
      label: Text(emotion.label(context.l10n), softWrap: true, maxLines: 3),
      selected: selected,
      // 对勾挤占宽度会让大字号标签被截断；描边不参与布局，选中态不只靠色面。
      showCheckmark: false,
      side: selected
          ? BorderSide(color: theme.colorScheme.primary)
          : BorderSide.none,
      onSelected: (_) => ref
          .read(directorToolsNotifierProvider.notifier)
          .selectEmotion(emotion),
    );
  }

  Widget _buildRunButton(ThemeData theme, DirectorToolsState state) {
    final label = state.selectedTool.labelKey(context.l10n);
    final isOpus = ref.watch(isOpusSubscriptionProvider);
    final cost = state.estimatedAnlasCost(isOpus: isOpus);
    final runsLocally = state.selectedTool.runsLocally;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
            if (!runsLocally &&
                state.imageWidth > 0 &&
                state.imageHeight > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5,
                  ),
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
        ),
        if (runsLocally && state.isRunning) ...[
          const SizedBox(height: 12),
          PixelSnapProgressPanel(progress: state.progress),
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
    // 本机工具不花 Anlas，弹消耗确认只会让用户以为要扣费。
    if (!requestState.selectedTool.runsLocally) {
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
    }

    final notifier = ref.read(directorToolsNotifierProvider.notifier);
    await notifier.runTool();

    if (!mounted) return;
    final state = ref.read(directorToolsNotifierProvider);
    if (state.result != null) {
      final registration = await notifier.registerResult();
      if (mounted) _showRegistrationOutcome(state.selectedTool, registration);
    }
  }

  void _showRegistrationOutcome(
    DirectorToolType tool,
    DirectorResultRegistration registration,
  ) {
    final l10n = context.l10n;
    final label = tool.labelKey(l10n);
    final failed = registration.failedCount;
    final total = registration.total;
    if (registration.succeeded) {
      AppToast.success(context, l10n.img2img_directorResultReady(label));
    } else if (registration.allFailed) {
      AppToast.error(context, l10n.img2img_directorResultSaveFailed(label));
    } else if (registration.selectedFailed) {
      AppToast.error(
        context,
        l10n.img2img_directorResultSelectedSaveFailed(label, failed, total),
      );
    } else {
      AppToast.warning(
        context,
        l10n.img2img_directorResultPartiallySaved(label, failed, total),
      );
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

/// 原图与结果都可能远大于屏幕；按显示器尺寸封顶解码，拖动窗口时缓存键不变、不反复整图解码。
class _CappedPreview extends StatelessWidget {
  const _CappedPreview({
    super.key,
    required this.bytes,
    this.evictOnDispose = false,
  });

  final Uint8List bytes;

  /// 结果每次运行都是新字节，离开页面后不该继续占着解码缓存。
  final bool evictOnDispose;

  @override
  Widget build(BuildContext context) {
    final display = View.of(context).display;
    final logicalDisplay = display.size / display.devicePixelRatio;
    return DecodedMemoryImage(
      bytes: bytes,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      maxLogicalWidth: logicalDisplay.width,
      maxLogicalHeight: logicalDisplay.height,
      evictOnDispose: evictOnDispose,
    );
  }
}
