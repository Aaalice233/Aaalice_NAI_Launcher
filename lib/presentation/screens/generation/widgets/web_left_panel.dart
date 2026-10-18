import 'dart:async';

import 'package:flutter/material.dart';
import '../../../widgets/common/model_family_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../providers/generation/generation_panel_expansion_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../widgets/character/inline_character_section.dart';
import 'collapsed_panel.dart';
import 'generation_controls/generation_controls.dart';
import 'generation_param_sections.dart';
import 'generation_workspace_header.dart';
import 'img2img_panel.dart';
import 'precise_reference_panel.dart';
import 'prompt_input.dart';
import 'prompt_input_controller.dart';
import 'reverse_prompt_panel.dart';
import 'unified_reference_panel.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/generation/web_panel_modules_provider.dart';
import '../../../providers/reverse_prompt_provider.dart';

enum WebLeftPanelModule {
  img2img,
  character,
  preciseReference,
  vibeTransfer,
  reversePrompt,
}

/// 官网式布局左栏
///
/// 一体式滚动列，自上而下：尺寸 → 种子 → 提示词（随内容自由增高）→
/// 反推/图生图/风格迁移/精准参考。
/// 参数（模型/采样器/噪声调度/步数/CFG/CFG Rescale）是独立的二级菜单：
/// 触发条固定在钉底生成控制条上方，点击后面板向上弹出、
/// 悬浮于滚动内容之上（官网式，不与提示词等模块同层）。
class WebLeftPanel extends ConsumerStatefulWidget {
  final ValueNotifier<bool> negativeModeNotifier;
  final PromptInputController promptInputController;
  final GlobalKey promptInputKey;
  final bool isResizing;

  const WebLeftPanel({
    super.key,
    required this.negativeModeNotifier,
    required this.promptInputController,
    required this.promptInputKey,
    this.isResizing = false,
  });

  @override
  ConsumerState<WebLeftPanel> createState() => _WebLeftPanelState();
}

class _WebLeftPanelState extends ConsumerState<WebLeftPanel>
    with TickerProviderStateMixin {
  // 320px 的面板最小宽度包含右侧 1px 分隔线。
  static const double _expandedContentMinWidth = 319;

  static const _baseModuleOrder = [
    WebLeftPanelModule.img2img,
    WebLeftPanelModule.character,
    WebLeftPanelModule.preciseReference,
    WebLeftPanelModule.vibeTransfer,
    WebLeftPanelModule.reversePrompt,
  ];

  late List<WebLeftPanelModule> _displayOrder;
  final Map<WebLeftPanelModule, GlobalKey> _moduleKeys = {
    for (final m in WebLeftPanelModule.values) m: GlobalKey(),
  };
  Map<WebLeftPanelModule, double> _animatedOffsets = {};

  late final AnimationController _sortController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final CurvedAnimation _sortAnimation = CurvedAnimation(
    parent: _sortController,
    curve: Curves.easeInOutCubic,
  );

  /// 参数二级菜单是否挂载（动画收起完毕后卸载）。
  bool _paramsMenuMounted = false;

  late final AnimationController _menuController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final CurvedAnimation _menuAnimation = CurvedAnimation(
    parent: _menuController,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _menuSlide = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(_menuAnimation);

  @override
  void initState() {
    super.initState();
    _displayOrder = _computeDesiredOrder();
    _sortController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _animatedOffsets = {};
        });
      }
    });
    final restored = ref
        .read(generationPanelExpansionProvider)
        .isExpanded(GenerationWorkbenchPanel.generationParameters);
    _paramsMenuMounted = restored;
    _menuController.value = restored ? 1 : 0;
    // 收起动画播完再卸载浮层
    _menuController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _paramsMenuMounted = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncEmptyPanelsExpansion();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    _menuController.duration = duration;
    _menuController.reverseDuration = duration;
  }

  @override
  void dispose() {
    _sortAnimation.dispose();
    _sortController.dispose();
    _menuAnimation.dispose();
    _menuController.dispose();
    super.dispose();
  }

  bool _moduleHasData(WebLeftPanelModule module) {
    switch (module) {
      case WebLeftPanelModule.img2img:
        final params = ref.read(generationParamsNotifierProvider);
        return params.sourceImage != null;
      case WebLeftPanelModule.character:
        return ref.read(characterPromptNotifierProvider).characters.isNotEmpty;
      case WebLeftPanelModule.preciseReference:
        return ref
            .read(generationParamsNotifierProvider)
            .preciseReferences
            .isNotEmpty;
      case WebLeftPanelModule.vibeTransfer:
        final params = ref.read(generationParamsNotifierProvider);
        return params.vibeReferencesV4.isNotEmpty;
      case WebLeftPanelModule.reversePrompt:
        return ref.read(reversePromptProvider).images.isNotEmpty;
    }
  }

  List<WebLeftPanelModule> _computeDesiredOrder() {
    final withData = <WebLeftPanelModule>[];
    final empty = <WebLeftPanelModule>[];
    for (final m in _baseModuleOrder) {
      if (_moduleHasData(m)) {
        withData.add(m);
      } else {
        empty.add(m);
      }
    }
    return [...withData, ...empty];
  }

  bool _ordersMatch(List<WebLeftPanelModule> a, List<WebLeftPanelModule> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  GenerationWorkbenchPanel _panelForModule(WebLeftPanelModule module) {
    return switch (module) {
      WebLeftPanelModule.img2img => GenerationWorkbenchPanel.img2img,
      WebLeftPanelModule.character => GenerationWorkbenchPanel.characters,
      WebLeftPanelModule.preciseReference =>
        GenerationWorkbenchPanel.preciseReference,
      WebLeftPanelModule.vibeTransfer => GenerationWorkbenchPanel.vibeTransfer,
      WebLeftPanelModule.reversePrompt =>
        GenerationWorkbenchPanel.reversePrompt,
    };
  }

  void _syncEmptyPanelsExpansion() {
    final expansionNotifier =
        ref.read(generationPanelExpansionProvider.notifier);
    for (final m in _baseModuleOrder) {
      if (!_moduleHasData(m)) {
        final panel = _panelForModule(m);
        expansionNotifier.setExpanded(panel, false, resetManuallyClosed: true);
      }
    }
  }

  /// 外部失焦/点击空闲区时触发模块重排判断与平滑过渡动画
  void triggerAutoSortIfChanged() {
    if (!mounted) return;
    _syncEmptyPanelsExpansion();
    final targetOrder = _computeDesiredOrder();
    if (_ordersMatch(_displayOrder, targetOrder)) return;

    final oldPositions = <WebLeftPanelModule, double>{};
    for (final id in _displayOrder) {
      final key = _moduleKeys[id];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        oldPositions[id] = box.localToGlobal(Offset.zero).dy;
      }
    }

    setState(() {
      _displayOrder = targetOrder;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final offsets = <WebLeftPanelModule, double>{};
      for (final id in targetOrder) {
        final key = _moduleKeys[id];
        final box = key?.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && oldPositions.containsKey(id)) {
          final newDy = box.localToGlobal(Offset.zero).dy;
          final deltaY = oldPositions[id]! - newDy;
          if (deltaY.abs() > 0.5) {
            offsets[id] = deltaY;
          }
        }
      }
      if (offsets.isNotEmpty) {
        setState(() {
          _animatedOffsets = offsets;
        });
        _sortController.forward(from: 0.0);
      }
    });
  }

  bool _isModuleEnabled(
    WebLeftPanelModule module,
    WebPanelModulesState panelModules,
  ) {
    if (_moduleHasData(module)) return true;
    return switch (module) {
      WebLeftPanelModule.img2img => true,
      WebLeftPanelModule.character => panelModules.showCharacter,
      WebLeftPanelModule.preciseReference => panelModules.showPreciseReference,
      WebLeftPanelModule.vibeTransfer => panelModules.showVibeTransfer,
      WebLeftPanelModule.reversePrompt => panelModules.showTagExtraction,
    };
  }

  Widget _buildModule(
    WebLeftPanelModule module,
    WebPanelModulesState panelModules,
  ) {
    final Widget child = switch (module) {
      WebLeftPanelModule.img2img => const Img2ImgPanel(),
      WebLeftPanelModule.character => const InlineCharacterSection(),
      WebLeftPanelModule.preciseReference => const PreciseReferencePanel(),
      WebLeftPanelModule.vibeTransfer => const UnifiedReferencePanel(),
      WebLeftPanelModule.reversePrompt => const ReversePromptPanel(),
    };

    return AnimatedBuilder(
      animation: _sortAnimation,
      builder: (context, c) {
        final delta = _animatedOffsets[module] ?? 0.0;
        final currentOffset = delta * (1.0 - _sortAnimation.value);
        return Transform.translate(
          offset: Offset(0, currentOffset),
          child: c,
        );
      },
      child: KeyedSubtree(
        key: _moduleKeys[module]!,
        child: child,
      ),
    );
  }

  void _toggleParamsMenu() {
    final opening =
        _menuController.status == AnimationStatus.dismissed ||
        _menuController.status == AnimationStatus.reverse;
    _setParamsMenuExpanded(opening);
  }

  void _closeParamsMenu() => _setParamsMenuExpanded(false);

  void _setParamsMenuExpanded(bool expanded) {
    if (expanded && !_paramsMenuMounted) {
      setState(() => _paramsMenuMounted = true);
    }
    if (expanded) {
      _menuController.forward();
    } else {
      _menuController.reverse();
    }
    unawaited(
      ref
          .read(generationPanelExpansionProvider.notifier)
          .setExpanded(GenerationWorkbenchPanel.generationParameters, expanded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layoutState = ref.watch(layoutStateNotifierProvider);

    final width = layoutState.webLeftPanelExpanded
        ? layoutState.webLeftPanelWidth
        : 40.0;
    final decoration = BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
    );

    final child = LayoutBuilder(
      builder: (context, constraints) {
        // AnimatedContainer 会先切换业务状态，再逐帧过渡实际宽度。
        // 只有当前帧真正容得下完整内容时才构建展开态，避免其内部所有
        // Row 在 40px 附近仍按桌面侧栏排版。
        final showExpandedContent =
            layoutState.webLeftPanelExpanded &&
            constraints.maxWidth >= _expandedContentMinWidth;
        if (showExpandedContent) {
          return KeyedSubtree(
            key: const ValueKey('web-left-panel-expanded-content'),
            child: _buildExpanded(context, theme),
          );
        }
        return CollapsedPanel(
          key: const ValueKey('web-left-panel-compact-content'),
          icon: Icons.edit_note,
          label: context.l10n.generation_params,
          onTap: () => ref
              .read(layoutStateNotifierProvider.notifier)
              .setWebLeftPanelExpanded(true),
        );
      },
    );

    // Keep the same subtree while dragging: replacing the container reparents
    // the keyed prompt and its active OverlayPortal during layout.
    return AnimatedContainer(
      duration: widget.isResizing || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      width: width,
      decoration: decoration,
      child: child,
    );
  }

  Widget _buildExpanded(BuildContext context, ThemeData theme) {
    final modelName = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => ImageModels.modelDisplayNames[params.model] ?? params.model,
      ),
    );
    final panelModules = ref.watch(webPanelModulesProvider);

    return Column(
      children: [
        GenerationWorkspaceHeader(
          key: const ValueKey('web-generation-workspace-header'),
          onCollapse: () => ref
              .read(layoutStateNotifierProvider.notifier)
              .setWebLeftPanelExpanded(false),
        ),

        // 内容区 + 参数二级菜单浮层
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // 一体式滚动列（点击空闲区域触发失焦排序过渡）
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: triggerAutoSortIfChanged,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 尺寸设置置顶：不会被长提示词推走
                          const SizeSection(),
                          const SizedBox(height: 10),

                          // 种子：位于尺寸与提示词之间
                          const SeedSection(),
                          const SizedBox(height: 10),

                          // 提示词：随内容自由增高（官网式）
                          PromptInputWidget(
                            key: widget.promptInputKey,
                            controller: widget.promptInputController,
                            autoGrow: true,
                            showMaximizeButton: false,
                            negativeModeNotifier: widget.negativeModeNotifier,
                          ),
                          const SizedBox(height: 10),

                          // 功能面板（智能排序与有内容自动展开）
                          for (final module in _displayOrder) ...[
                            if (_isModuleEnabled(module, panelModules)) ...[
                              _buildModule(module, panelModules),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  // 参数二级菜单：遮罩淡入淡出 + 抽屉从触发条上方拉出
                  if (_paramsMenuMounted) ...[
                    Positioned.fill(
                      child: FadeTransition(
                        opacity: _menuAnimation,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _closeParamsMenu,
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRect(
                        child: SlideTransition(
                          position: _menuSlide,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight - 12,
                            ),
                            child: Material(
                              elevation: 8,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                              clipBehavior: Clip.antiAlias,
                              color: theme.colorScheme.surface,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(10),
                                  ),
                                  border: Border(
                                    top: BorderSide(color: theme.dividerColor),
                                    left: BorderSide(color: theme.dividerColor),
                                    right: BorderSide(
                                      color: theme.dividerColor,
                                    ),
                                  ),
                                ),
                                child: const SingleChildScrollView(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ModelSection(),
                                      SizedBox(height: 10),
                                      SamplerSection(),
                                      SizedBox(height: 10),
                                      NoiseScheduleSection(),
                                      SizedBox(height: 10),
                                      StepsSection(),
                                      CfgScaleSection(),
                                      AdvancedSamplingOptions(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),

        // 参数二级菜单触发条：固定在钉底控制条上方，永远一步可达
        Material(
          color: theme.colorScheme.surface,
          child: InkWell(
            onTap: _toggleParamsMenu,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.dividerColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    context.l10n.generation_params,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ModelNameLabel(
                        modelId: ref.watch(
                          generationParamsNotifierProvider.select(
                            (params) => params.model,
                          ),
                        ),
                        displayName: modelName,
                        iconSize: 16,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 箭头随抽屉开合旋转（收起朝上提示拉出方向）
                  RotationTransition(
                    turns: Tween<double>(
                      begin: 0,
                      end: 0.5,
                    ).animate(_menuAnimation),
                    child: const Icon(Icons.keyboard_arrow_up, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 钉底生成控制条（压扁）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.5),
            border: Border(
              top: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: const GenerationControls(compact: true),
        ),
      ],
    );
  }
}
