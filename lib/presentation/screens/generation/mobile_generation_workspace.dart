import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../themes/theme_extension.dart';
import 'mobile_generation_controller.dart';
import 'mobile_generation_gestures.dart';
import 'mobile_generation_view_data.dart';
import 'widgets/image_preview.dart';
import 'widgets/prompt_input.dart';
import 'widgets/prompt_input_controller.dart';

class MobileGenerationWorkspace extends StatefulWidget {
  const MobileGenerationWorkspace({
    super.key,
    required this.controller,
    required this.data,
    required this.promptInputController,
    required this.promptInputKey,
  });

  static const double _minimumHorizontalWorkspaceHeight = 320;

  final MobileGenerationController controller;
  final MobileGenerationViewData data;
  final PromptInputController promptInputController;
  final GlobalKey promptInputKey;

  @override
  State<MobileGenerationWorkspace> createState() =>
      _MobileGenerationWorkspaceState();
}

class _MobileGenerationWorkspaceState extends State<MobileGenerationWorkspace> {
  final GlobalKey _collapsedPromptLauncherKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final data = widget.data;
    return MobileWorkspaceMotion(
      active: !controller.agentFullScreen,
      hiddenOffset: const Offset(0, -0.08),
      child: TickerMode(
        enabled: !controller.agentFullScreen,
        child: data.isPromptMaximized
            ? Padding(
                key: const ValueKey('maximized-prompt'),
                padding: const EdgeInsets.all(12),
                child: PromptInputWidget(
                  key: widget.promptInputKey,
                  controller: widget.promptInputController,
                  isMaximized: true,
                  showMaximizeButton: false,
                  autofocus: true,
                ),
              )
            : MobileGenerationGestures(
                onPointerDown: (event) =>
                    controller.handleWorkspacePointerDown(context, event),
                onPointerMove: controller.handleWorkspacePointerMove,
                onPointerUp: controller.handleWorkspacePointerUp,
                onPointerCancel: controller.handleWorkspacePointerCancel,
                onScrollNotification:
                    controller.handleWorkspaceScrollNotification,
                pointerExclusionKeys: [_collapsedPromptLauncherKey],
                pointerActive: controller.workspacePointerActive,
                dragOffset: controller.workspaceDragFeedback,
                showHint: controller.showGestureHint,
                child: LayoutBuilder(
                  key: const ValueKey('generation-workspace'),
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final minimumHorizontalWidth = 640 * textScale;
                    final useHorizontalLayout =
                        constraints.maxWidth >= minimumHorizontalWidth &&
                        constraints.maxHeight >=
                            MobileGenerationWorkspace
                                ._minimumHorizontalWorkspaceHeight &&
                        constraints.maxWidth > constraints.maxHeight * 1.15;
                    if (useHorizontalLayout) {
                      return Row(
                        children: [
                          const Expanded(flex: 6, child: ImagePreviewWidget()),
                          VerticalDivider(width: 1, color: theme.dividerColor),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                Expanded(
                                  child: Padding(
                                    key: controller.embeddedPromptKey,
                                    padding: const EdgeInsets.all(12),
                                    child: PromptInputWidget(
                                      key: widget.promptInputKey,
                                      controller: widget.promptInputController,
                                      compact: true,
                                    ),
                                  ),
                                ),
                                if (data.generationState.isGenerating)
                                  MobileGenerationProgress(
                                    progress: data.generationState.progress,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Offstage(
                          offstage: true,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: 160 * textScale.clamp(1.0, 3.0).toDouble(),
                            child: PromptInputWidget(
                              key: widget.promptInputKey,
                              controller: widget.promptInputController,
                              compact: true,
                              active: false,
                            ),
                          ),
                        ),
                        const Expanded(child: ImagePreviewWidget()),
                        if (data.generationState.isGenerating)
                          MobileGenerationProgress(
                            progress: data.generationState.progress,
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: MobileCollapsedPromptLauncher(
                            key: _collapsedPromptLauncherKey,
                            prompt: data.promptSummary,
                            characterCount: data.enabledCharacterCount,
                            qualityEnabled: data.qualityEnabled,
                            negativePresetLabel: data.negativePresetLabel,
                            fixedTagCount: data.fixedTagCount,
                            onTap: controller.openPromptEditor,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class MobileWorkspaceMotion extends StatelessWidget {
  const MobileWorkspaceMotion({
    super.key,
    required this.active,
    required this.hiddenOffset,
    required this.child,
  });

  final bool active;
  final Offset hiddenOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final appTheme = Theme.of(context).appTheme;
    final duration = disableAnimations
        ? Duration.zero
        : appTheme.normalDuration;
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedSlide(
          offset: active || disableAnimations ? Offset.zero : hiddenOffset,
          duration: duration,
          curve: appTheme.standardCurve,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: duration,
            curve: appTheme.standardCurve,
            child: child,
          ),
        ),
      ),
    );
  }
}

class MobileCollapsedPromptLauncher extends StatelessWidget {
  const MobileCollapsedPromptLauncher({
    super.key,
    required this.prompt,
    required this.characterCount,
    required this.qualityEnabled,
    required this.negativePresetLabel,
    required this.fixedTagCount,
    required this.onTap,
  });

  final String prompt;
  final int characterCount;
  final bool qualityEnabled;
  final String? negativePresetLabel;
  final int fixedTagCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasPrompt = prompt.isNotEmpty;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    final statusItems = <Widget>[
      if (characterCount > 0)
        _PromptOverviewItem(
          icon: Icons.people_alt_rounded,
          label: '${context.l10n.character_buttonLabel} $characterCount',
          color: colors.primary,
        ),
      if (qualityEnabled)
        _PromptOverviewItem(
          icon: Icons.auto_awesome_rounded,
          label: context.l10n.qualityTags_label,
          color: const Color(0xFF67A87A),
        ),
      if (negativePresetLabel case final label?)
        _PromptOverviewItem(
          icon: Icons.shield_rounded,
          label: label,
          color: colors.error.withValues(alpha: 0.82),
        ),
      if (fixedTagCount > 0)
        _PromptOverviewItem(
          icon: Icons.push_pin_rounded,
          label: '${context.l10n.fixedTags_label} $fixedTagCount',
          color: colors.onSurfaceVariant,
        ),
    ];
    return Semantics(
      button: true,
      label: context.l10n.promptToken_prompt,
      child: Material(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('generation-collapsed-prompt-launcher'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 17,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (largeText) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.l10n.promptToken_prompt,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.open_in_full_rounded,
                                size: 15,
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: 0.68,
                                ),
                              ),
                            ],
                          ),
                        ] else
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  context.l10n.promptToken_prompt,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  hasPrompt
                                      ? prompt.replaceAll(RegExp(r'\s+'), ' ')
                                      : context.l10n.prompt_describeImage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant.withValues(
                                      alpha: hasPrompt ? 0.8 : 0.56,
                                    ),
                                  ),
                                ),
                              ),
                              if (hasPrompt) ...[
                                const SizedBox(width: 8),
                                Text(
                                  context.l10n
                                      .generation_promptOverviewCharacters(
                                        prompt.runes.length,
                                      ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              Icon(
                                Icons.open_in_full_rounded,
                                size: 15,
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: 0.68,
                                ),
                              ),
                            ],
                          ),
                        if (!largeText && statusItems.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          SizedBox(
                            height: largeText ? 48 : 17,
                            child: SingleChildScrollView(
                              key: const ValueKey(
                                'generation-prompt-overview-statuses',
                              ),
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (
                                    var index = 0;
                                    index < statusItems.length;
                                    index++
                                  ) ...[
                                    if (index > 0) const SizedBox(width: 11),
                                    statusItems[index],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptOverviewItem extends StatelessWidget {
  const _PromptOverviewItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class MobileGenerationProgress extends StatelessWidget {
  const MobileGenerationProgress({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress * 100).toInt();
    return Semantics(
      label: context.l10n.generation_progress(percent.toString()),
      value: '$percent%',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.generation_progress(percent.toString()),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
