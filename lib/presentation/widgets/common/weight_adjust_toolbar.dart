import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../prompt/prompt_weight_editing.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../core/utils/prompt_edit_document.dart';
import '../prompt/prompt_action_overlay.dart';
import '../prompt/prompt_weight_controls.dart';
import '../prompt/prompt_translation_caption.dart';
import '../prompt/tag_editor_scope.dart';

/// 权重调整工具条包装器
///
/// 为任意文本输入框提供权重调整功能
/// 使用 OverlayPortal 的布局信息跟随选区并避让屏幕边界
///
/// 使用示例：
/// ```dart
/// WeightAdjustToolbarWrapper(
///   controller: _controller,
///   focusNode: _focusNode,
///   child: TextField(
///     controller: _controller,
///     focusNode: _focusNode,
///   ),
/// )
/// ```
class WeightAdjustToolbarWrapper extends StatefulWidget {
  /// 被包装的输入组件
  final Widget child;

  /// 文本控制器
  final TextEditingController controller;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 是否启用权重调整
  final bool enabled;

  /// 是否允许通过鼠标滚轮调整权重
  final bool enableWheelAdjustment;

  const WeightAdjustToolbarWrapper({
    super.key,
    required this.child,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.enableWheelAdjustment = true,
  });

  @override
  State<WeightAdjustToolbarWrapper> createState() =>
      _WeightAdjustToolbarWrapperState();
}

class _WeightAdjustToolbarWrapperState
    extends State<WeightAdjustToolbarWrapper> {
  final OverlayPortalController _overlayController = OverlayPortalController(
    debugLabel: 'prompt-weight-toolbar',
  );
  final GlobalKey _textFieldKey = GlobalKey();
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _isInteractingWithToolbar = false;
  bool _toolbarVisible = false;
  Timer? _blurTimer;

  @override
  void initState() {
    super.initState();
    _initFocusNode();
    widget.controller.addListener(_onSelectionChanged);
  }

  void _initFocusNode() {
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(WeightAdjustToolbarWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.enabled) _hideToolbar();
      });
    }
    if (!oldWidget.enabled && widget.enabled) {
      _scheduleControllerSelectionSync(widget.controller);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSelectionChanged);
      widget.controller.addListener(_onSelectionChanged);
      _scheduleControllerSelectionSync(widget.controller);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _blurTimer?.cancel();
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _initFocusNode();
    }
  }

  @override
  void dispose() {
    _blurTimer?.cancel();
    _isInteractingWithToolbar = false;
    _toolbarVisible = false;
    widget.controller.removeListener(_onSelectionChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    _blurTimer?.cancel();
    if (!_focusNode.hasFocus && !_isInteractingWithToolbar) {
      _blurTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus && !_isInteractingWithToolbar) {
          _hideToolbar();
        }
      });
    }
  }

  void _onSelectionChanged() {
    if (!widget.enabled || _isInteractingWithToolbar) return;

    _syncToolbarWithControllerSelection();
  }

  void _syncToolbarWithControllerSelection() {
    if (!widget.enabled) return;

    final selection = widget.controller.selection;
    final hasSelection =
        selection.isValid &&
        selection.start != selection.end &&
        selection.start >= 0 &&
        selection.end <= widget.controller.text.length;

    if (hasSelection && !_toolbarVisible) {
      _showToolbar();
    } else if (!hasSelection && _toolbarVisible) {
      _hideToolbar();
    } else if (hasSelection && _toolbarVisible && mounted) {
      setState(() {});
    }
  }

  void _scheduleControllerSelectionSync(
    TextEditingController updatedController,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(widget.controller, updatedController)) {
        _syncToolbarWithControllerSelection();
      }
    });
  }

  void _showToolbar() {
    if (_toolbarVisible) return;
    _toolbarVisible = true;
    _overlayController.show();
  }

  void _hideToolbar() {
    _isInteractingWithToolbar = false;
    if (!_toolbarVisible) return;
    _toolbarVisible = false;
    _overlayController.hide();
  }

  void _adjustWeightByStep(double step) {
    if (!PromptWeightEditing.protectNegativeBlockSyntax(widget.controller)) {
      return;
    }
    final result = PromptWeightEditing.parseSelection(widget.controller);
    PromptWeightEditing.applyWeight(
      widget.controller,
      (result.weight + step).clamp(0.1, 3.0),
    );
    if (mounted && _toolbarVisible) {
      setState(() {});
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        !widget.enabled ||
        !widget.enableWheelAdjustment ||
        !PromptWeightEditing.hasSelection(widget.controller) ||
        !PromptWeightEditing.protectNegativeBlockSyntax(widget.controller)) {
      return;
    }

    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      final scrollEvent = resolvedEvent as PointerScrollEvent;
      _adjustWeightByStep(scrollEvent.scrollDelta.dy < 0 ? 0.05 : -0.05);
      scrollEvent.respond(allowPlatformDefault: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _overlayController,
        overlayChildBuilder: _buildToolbarOverlay,
        child: KeyedSubtree(key: _textFieldKey, child: widget.child),
      ),
    );
  }

  Widget _buildToolbarOverlay(
    BuildContext context,
    OverlayChildLayoutInfo layoutInfo,
  ) {
    final childRect = MatrixUtils.transformRect(
      layoutInfo.childPaintTransform,
      Offset.zero & layoutInfo.childSize,
    );
    var caretRect = Rect.fromLTWH(
      childRect.left,
      childRect.top,
      0,
      childRect.height,
    );
    final textFieldContext = _textFieldKey.currentContext;
    final textFieldRenderBox =
        textFieldContext?.findRenderObject() as RenderBox?;
    if (textFieldContext is Element && textFieldRenderBox != null) {
      RenderEditable? renderEditable;
      void findEditable(Element element) {
        if (renderEditable != null) return;
        if (element.renderObject case final RenderEditable editable) {
          renderEditable = editable;
          return;
        }
        element.visitChildren(findEditable);
      }

      findEditable(textFieldContext);
      final editable = renderEditable;
      final selection = editable?.selection ?? widget.controller.selection;
      if (editable != null && selection.isValid && selection.start >= 0) {
        final localCaretRect = editable.getLocalRectForCaret(
          TextPosition(offset: selection.start),
        );
        final editableToField = editable.getTransformTo(textFieldRenderBox);
        final caretInField = MatrixUtils.transformRect(
          editableToField,
          localCaretRect,
        );
        caretRect = MatrixUtils.transformRect(
          layoutInfo.childPaintTransform,
          caretInField,
        );
      }
    }

    return _WeightAdjustToolbar(
      controller: widget.controller,
      caretRect: caretRect,
      overlaySize: layoutInfo.overlaySize,
      onClose: _hideToolbar,
      enableWheelAdjustment: widget.enableWheelAdjustment,
      onInteractingChanged: (interacting) {
        _isInteractingWithToolbar = interacting;
      },
    );
  }
}

class WeightAdjustScrollPhysics extends ScrollPhysics {
  const WeightAdjustScrollPhysics({
    required this.controllerProvider,
    super.parent,
  });

  /// Resolves lazily because Flutter can retain same-type physics on rebuild.
  final ValueGetter<TextEditingController> controllerProvider;

  @override
  WeightAdjustScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return WeightAdjustScrollPhysics(
      controllerProvider: controllerProvider,
      parent: buildParent(ancestor),
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (PromptWeightEditing.hasSelection(controllerProvider())) {
      return false;
    }
    return super.shouldAcceptUserOffset(position);
  }
}

bool supportsPromptWeightScrollPhysics(InteractionPolicy interactionPolicy) {
  return interactionPolicy.precisePointerAvailable;
}

class _WeightAdjustToolbar extends StatelessWidget {
  const _WeightAdjustToolbar({
    required this.controller,
    required this.caretRect,
    required this.overlaySize,
    required this.onClose,
    required this.enableWheelAdjustment,
    required this.onInteractingChanged,
  });
  final TextEditingController controller;
  final Rect caretRect;
  final Size overlaySize;
  final VoidCallback onClose;
  final bool enableWheelAdjustment;
  final ValueChanged<bool> onInteractingChanged;

  void _weight(double value) {
    if (PromptWeightEditing.protectNegativeBlockSyntax(controller)) {
      PromptWeightEditing.applyWeight(controller, value);
    }
  }

  void _step(double step) => _weight(
    (PromptWeightEditing.parseSelection(controller).weight + step).clamp(
      0.1,
      3.0,
    ),
  );
  void _wheel(PointerSignalEvent event) {
    if (!enableWheelAdjustment ||
        event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      _step(scroll.scrollDelta.dy < 0 ? 0.05 : -0.05);
      scroll.respond(allowPlatformDefault: false);
    });
  }

  void _toggle(PromptEditSpan span) {
    final replacement = span.disabled
        ? span.text
        : PromptEditDocument.disable(span.raw);
    controller.value = TextEditingValue(
      text: controller.text.replaceRange(span.start, span.end, replacement),
      selection: TextSelection(
        baseOffset: span.start,
        extentOffset: span.start + replacement.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = controller.selection;
    final session = TagEditorScope.maybeOf(context);
    final tags = session?.textSelectionTags ?? [];
    final enable = tags.isNotEmpty && tags.every((tag) => tag.span.disabled);
    final selected = PromptEditDocument.singleSelected(
      controller.text,
      selection.start,
      selection.end,
    );
    final caption = selected == null
        ? null
        : PromptWeightEditing.parseWeightSyntax(selected.text).baseText;
    return PromptActionOverlay(
      anchor: caretRect,
      overlaySize: overlaySize,
      child: TextFieldTapRegion(
        child: Listener(
          onPointerDown: (_) => onInteractingChanged(true),
          onPointerUp: (_) => onInteractingChanged(false),
          onPointerCancel: (_) => onInteractingChanged(false),
          onPointerSignal: _wheel,
          child: PromptActionSurface(
            key: const ValueKey('weight_adjust_toolbar_surface'),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: PromptWeightControls(
                onClose: onClose,
                caption:
                    caption != null &&
                        Localizations.localeOf(context).languageCode == 'zh'
                    ? PromptTranslationCaption(text: caption)
                    : null,
                weight: PromptWeightEditing.parseSelection(controller).weight,
                onWeight: _weight,
                onStep: _step,
                trailing: [
                  if (tags.isNotEmpty)
                    IconButton(
                      key: const ValueKey('text-selection-enabled-button'),
                      tooltip: enable
                          ? context.l10n.tagMode_enable
                          : context.l10n.tagMode_disable,
                      onPressed: () => session!.setTextSelectionEnabled(enable),
                      icon: Icon(
                        enable
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                    )
                  else if (session == null && selected != null)
                    IconButton(
                      tooltip: selected.disabled
                          ? context.l10n.tagMode_enable
                          : context.l10n.tagMode_disable,
                      onPressed: () => _toggle(selected),
                      icon: Icon(
                        selected.disabled
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
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
