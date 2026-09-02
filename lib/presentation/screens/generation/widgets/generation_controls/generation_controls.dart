import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_notifier.dart';
import 'package:nai_launcher/presentation/utils/asset_protection_guard.dart';
import 'package:nai_launcher/presentation/widgets/common/app_toast.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_number_input.dart';
import 'package:nai_launcher/presentation/widgets/generation/auto_save_toggle_chip.dart';
import 'package:nai_launcher/presentation/widgets/anlas/anlas_balance_chip.dart';
import 'package:nai_launcher/presentation/widgets/anlas/opus_usage_chip.dart';
import 'batch_settings_button.dart';
import 'generate_button.dart';
import 'random_mode_toggle.dart';

/// 生成控制按钮
class GenerationControls extends ConsumerStatefulWidget {
  /// 紧凑模式：用于官网式布局的钉底控制条——
  /// 追加批次大小按钮，并按可用宽度重排全部操作。
  final bool compact;

  const GenerationControls({super.key, this.compact = false});

  @override
  ConsumerState<GenerationControls> createState() => _GenerationControlsState();
}

class _GenerationControlsState extends ConsumerState<GenerationControls> {
  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final cooldownState = ref.watch(generationCooldownProvider);
    final isAuthenticated = ref.watch(
      authNotifierProvider.select((state) => state.isAuthenticated),
    );
    final isKritaGenerating =
        PlatformCapabilities.current.supportsKritaBridge &&
        ref.watch(kritaBridgeNotifierProvider).isBridgeGenerating;
    final nSamples = ref.watch(
      generationParamsNotifierProvider.select((params) => params.nSamples),
    );
    final isLauncherGenerating = generationState.isGenerating;
    final isGenerating = isLauncherGenerating || isKritaGenerating;

    // 生成中常驻显示取消入口（与移动端一致）
    final showCancel = isLauncherGenerating;

    final randomMode = ref.watch(randomPromptModeProvider);
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);
    final isUpscaleMode = ref.watch(
      imageWorkflowControllerProvider.select((workflow) => workflow.isUpscale),
    );

    // 快捷键已由父级 DesktopGenerationLayout 统一处理
    // 这里只负责布局
    final compact = widget.compact;
    final opusUsage = OpusUsageChip(compact: compact);
    final anlasBalance = AnlasBalanceChip(compact: compact);
    final leftActions = <Widget>[opusUsage, anlasBalance];
    final rightActions = <Widget>[
      // 生成中批量参数不可变更；隐藏后为跳过/停止操作保留空间。
      if (compact && !showCancel) const BatchSettingsButton(compact: true),
      if (!(compact && showCancel))
        DraggableNumberInput(
          value: nSamples,
          min: 1,
          prefix: '×',
          onChanged: (value) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .updateNSamples(value);
          },
        ),
      if (showRandomTools)
        RandomModeToggle(enabled: randomMode, compact: compact),
      if (compact) const AutoSaveToggleChip(compact: true),
    ];

    // 由子控件的实际布局尺寸决定是否换行，而不是把 compact 或文本
    // 缩放直接等同于窄布局。这样能放下时始终保持单行和主按钮几何居中。
    return _GenerationControlsLayout(
      leftActions: leftActions,
      primaryAction: SizedBox(
        key: const ValueKey('generation-footer-primary-action'),
        child: GenerateButtonWithCost(
          height: 48,
          isGenerating: isGenerating,
          showCancel: showCancel,
          generationState: generationState,
          cooldownRemainingSeconds: cooldownState.remainingSeconds,
          onGenerate: () => unawaited(_handleGenerate(context, ref)),
          onCancel: () =>
              ref.read(imageGenerationNotifierProvider.notifier).cancel(),
          onSkipCurrent: () => ref
              .read(imageGenerationNotifierProvider.notifier)
              .skipCurrentRequest(),
          showCost: !isUpscaleMode,
          requiresLogin: !isAuthenticated && !isGenerating,
          compact: compact,
        ),
      ),
      rightActions: rightActions,
    );
  }

  Future<void> _handleGenerate(BuildContext context, WidgetRef ref) async {
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      await context.pushNamed('login');
      return;
    }

    final params = ref.read(generationParamsNotifierProvider);
    if (params.prompt.isEmpty) {
      AppToast.warning(context, context.l10n.generation_pleaseInputPrompt);
      return;
    }

    final confirmed = await AssetProtectionGuard.confirmHighAnlasCost(
      context: context,
      ref: ref,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    // 生成（抽卡模式逻辑在 generate 方法内部处理）
    ref.read(imageGenerationNotifierProvider.notifier).generate(params);
  }
}

enum _GenerationControlGroup { left, primary, right }

class _GenerationControlsLayout extends MultiChildRenderObjectWidget {
  _GenerationControlsLayout({
    required List<Widget> leftActions,
    required Widget primaryAction,
    required List<Widget> rightActions,
  }) : super(
         key: const ValueKey('generation-footer-adaptive-layout'),
         children: [
           for (final action in leftActions)
             _GenerationControlSlot(
               group: _GenerationControlGroup.left,
               child: action,
             ),
           _GenerationControlSlot(
             group: _GenerationControlGroup.primary,
             child: primaryAction,
           ),
           for (final action in rightActions)
             _GenerationControlSlot(
               group: _GenerationControlGroup.right,
               child: action,
             ),
         ],
       );

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGenerationControlsLayout();
}

class _GenerationControlSlot
    extends ParentDataWidget<_GenerationControlsParentData> {
  const _GenerationControlSlot({required this.group, required super.child});

  final _GenerationControlGroup group;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData =
        renderObject.parentData! as _GenerationControlsParentData;
    if (parentData.group == group) return;
    parentData.group = group;
    final parent = renderObject.parent;
    if (parent is RenderObject) parent.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _GenerationControlsLayout;
}

class _GenerationControlsParentData extends ContainerBoxParentData<RenderBox> {
  _GenerationControlGroup group = _GenerationControlGroup.left;
}

class _RenderGenerationControlsLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GenerationControlsParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _GenerationControlsParentData
        > {
  static const double _itemSpacing = 2;
  static const double _primarySpacing = 8;
  static const double _runSpacing = 8;
  static const double _minimumPrimaryWidth = 160;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GenerationControlsParentData) {
      child.parentData = _GenerationControlsParentData();
    }
  }

  @override
  void performLayout() {
    final availableWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : 100000.0;
    final actionConstraints = BoxConstraints(maxWidth: availableWidth);
    final left = <RenderBox>[];
    final right = <RenderBox>[];
    RenderBox? primary;

    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _GenerationControlsParentData;
      switch (parentData.group) {
        case _GenerationControlGroup.left:
          child.layout(actionConstraints, parentUsesSize: true);
          if (!child.size.isEmpty) left.add(child);
        case _GenerationControlGroup.primary:
          primary = child;
        case _GenerationControlGroup.right:
          child.layout(actionConstraints, parentUsesSize: true);
          if (!child.size.isEmpty) right.add(child);
      }
      child = parentData.nextSibling;
    }

    final primaryChild = primary;
    if (primaryChild == null) {
      size = constraints.smallest;
      return;
    }

    final leftWidth = _groupWidth(left);
    final rightWidth = _groupWidth(right);
    final naturalWidth =
        leftWidth + rightWidth + _minimumPrimaryWidth + _primarySpacing * 2;
    final layoutWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : naturalWidth;
    final useSingleRow = naturalWidth <= layoutWidth;
    final primaryWidth = useSingleRow
        ? layoutWidth - leftWidth - rightWidth - _primarySpacing * 2
        : layoutWidth;
    primaryChild.layout(
      BoxConstraints.tightFor(width: primaryWidth),
      parentUsesSize: true,
    );
    final contentHeight = useSingleRow
        ? _layoutSingleRow(left, primaryChild, right, layoutWidth)
        : _layoutWrapped(left, primaryChild, right, layoutWidth);
    size = constraints.constrain(Size(layoutWidth, contentHeight));
  }

  double _groupWidth(List<RenderBox> children) {
    if (children.isEmpty) return 0;
    return children.fold<double>(0, (sum, child) => sum + child.size.width) +
        _itemSpacing * (children.length - 1);
  }

  double _layoutSingleRow(
    List<RenderBox> left,
    RenderBox primary,
    List<RenderBox> right,
    double width,
  ) {
    final allChildren = [...left, primary, ...right];
    final height = allChildren.fold<double>(
      0,
      (maximum, child) =>
          child.size.height > maximum ? child.size.height : maximum,
    );
    final leftWidth = _groupWidth(left);
    final rightWidth = _groupWidth(right);
    final primaryX = leftWidth + _primarySpacing;
    _positionGroup(left, 0, height);
    _position(primary, primaryX, (height - primary.size.height) / 2);
    _positionGroup(right, width - rightWidth, height);
    return height;
  }

  double _layoutWrapped(
    List<RenderBox> left,
    RenderBox primary,
    List<RenderBox> right,
    double width,
  ) {
    _position(primary, 0, 0);
    if (left.isEmpty && right.isEmpty) return primary.size.height;
    var y = primary.size.height + _runSpacing;
    final leftWidth = _groupWidth(left);
    final rightWidth = _groupWidth(right);
    if (leftWidth + rightWidth + _primarySpacing <= width) {
      final height = [...left, ...right].fold<double>(
        0,
        (maximum, action) =>
            action.size.height > maximum ? action.size.height : maximum,
      );
      _positionGroup(left, 0, height, y: y);
      _positionGroup(right, width - rightWidth, height, y: y);
      return y + height;
    }

    y = _layoutGroupRuns(left, width, y, alignRight: false);
    if (left.isNotEmpty && right.isNotEmpty) y += _runSpacing;
    return _layoutGroupRuns(right, width, y, alignRight: true);
  }

  double _layoutGroupRuns(
    List<RenderBox> children,
    double width,
    double startY, {
    required bool alignRight,
  }) {
    if (children.isEmpty) return startY;
    final runs = _buildRuns<RenderBox>(
      children,
      width,
      (child) => child.size.width,
    );
    var y = startY;
    for (final run in runs) {
      final runWidth = _groupWidth(run);
      final runHeight = run.fold<double>(
        0,
        (maximum, child) =>
            child.size.height > maximum ? child.size.height : maximum,
      );
      _positionGroup(run, alignRight ? width - runWidth : 0, runHeight, y: y);
      y += runHeight + _runSpacing;
    }
    return y - _runSpacing;
  }

  void _positionGroup(
    List<RenderBox> children,
    double x,
    double height, {
    double y = 0,
  }) {
    for (final child in children) {
      _position(child, x, y + (height - child.size.height) / 2);
      x += child.size.width + _itemSpacing;
    }
  }

  void _position(RenderBox child, double x, double y) {
    final parentData = child.parentData! as _GenerationControlsParentData;
    parentData.offset = Offset(x, y);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final availableWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : 100000.0;
    final actionConstraints = BoxConstraints(maxWidth: availableWidth);
    final left = <Size>[];
    final right = <Size>[];
    RenderBox? primaryChild;

    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _GenerationControlsParentData;
      switch (parentData.group) {
        case _GenerationControlGroup.left:
          final childSize = child.getDryLayout(actionConstraints);
          if (!childSize.isEmpty) left.add(childSize);
        case _GenerationControlGroup.primary:
          primaryChild = child;
        case _GenerationControlGroup.right:
          final childSize = child.getDryLayout(actionConstraints);
          if (!childSize.isEmpty) right.add(childSize);
      }
      child = parentData.nextSibling;
    }

    if (primaryChild == null) return constraints.smallest;
    final leftWidth = _dryGroupWidth(left);
    final rightWidth = _dryGroupWidth(right);
    final singleRowWidth =
        leftWidth + rightWidth + _minimumPrimaryWidth + _primarySpacing * 2;
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : singleRowWidth;
    final useSingleRow = singleRowWidth <= width;
    final primaryWidth = useSingleRow
        ? width - leftWidth - rightWidth - _primarySpacing * 2
        : width;
    final primarySize = primaryChild.getDryLayout(
      BoxConstraints.tightFor(width: primaryWidth),
    );
    if (useSingleRow) {
      final height = [...left, primarySize, ...right].fold<double>(
        0,
        (maximum, childSize) =>
            childSize.height > maximum ? childSize.height : maximum,
      );
      return constraints.constrain(Size(width, height));
    }

    final leftAndRightFit = leftWidth + rightWidth + _primarySpacing <= width;
    if (leftAndRightFit) {
      final actionsHeight = [...left, ...right].fold<double>(
        0,
        (maximum, action) => action.height > maximum ? action.height : maximum,
      );
      return constraints.constrain(
        Size(width, primarySize.height + _runSpacing + actionsHeight),
      );
    }
    var height = primarySize.height;
    if (left.isNotEmpty) {
      height += _runSpacing + _dryRunsHeight(left, width);
    }
    if (right.isNotEmpty) {
      height += _runSpacing + _dryRunsHeight(right, width);
    }
    return constraints.constrain(Size(width, height));
  }

  double _dryRunsHeight(List<Size> children, double width) {
    final runs = _buildRuns<Size>(children, width, (child) => child.width);
    return runs.fold<double>(0, (height, run) {
          final runHeight = run.fold<double>(
            0,
            (maximum, child) => child.height > maximum ? child.height : maximum,
          );
          return height + runHeight;
        }) +
        _runSpacing * (runs.length - 1);
  }

  List<List<T>> _buildRuns<T>(
    List<T> children,
    double width,
    double Function(T child) widthOf,
  ) {
    final runs = <List<T>>[];
    var run = <T>[];
    var runWidth = 0.0;
    for (final child in children) {
      final childWidth = widthOf(child);
      final nextWidth = run.isEmpty
          ? childWidth
          : runWidth + _itemSpacing + childWidth;
      if (run.isNotEmpty && nextWidth > width) {
        runs.add(run);
        run = <T>[];
        runWidth = 0;
      }
      run.add(child);
      runWidth = runWidth == 0
          ? childWidth
          : runWidth + _itemSpacing + childWidth;
    }
    if (run.isNotEmpty) runs.add(run);
    return runs;
  }

  double _dryGroupWidth(List<Size> children) {
    if (children.isEmpty) return 0;
    return children.fold<double>(0, (sum, child) => sum + child.width) +
        _itemSpacing * (children.length - 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
