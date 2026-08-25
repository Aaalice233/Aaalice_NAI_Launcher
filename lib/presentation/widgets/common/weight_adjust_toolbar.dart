import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

/// 权重调整工具条包装器
///
/// 为任意文本输入框提供权重调整功能
/// 使用 CompositedTransform 实现精确定位
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
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _isInteractingWithToolbar = false;

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
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSelectionChanged);
      widget.controller.addListener(_onSelectionChanged);
      _scheduleControllerSelectionSync(widget.controller);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _initFocusNode();
    }
    if (oldWidget.enableWheelAdjustment != widget.enableWheelAdjustment) {
      final overlayEntry = _overlayEntry;
      if (overlayEntry != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              identical(_overlayEntry, overlayEntry) &&
              overlayEntry.mounted) {
            overlayEntry.markNeedsBuild();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _hideToolbar();
    widget.controller.removeListener(_onSelectionChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && !_isInteractingWithToolbar) {
      Future.delayed(const Duration(milliseconds: 200), () {
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

    if (hasSelection && _overlayEntry == null) {
      _showToolbar();
    } else if (!hasSelection && _overlayEntry != null) {
      _hideToolbar();
    } else if (hasSelection && _overlayEntry != null) {
      _overlayEntry?.markNeedsBuild();
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
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _WeightAdjustToolbar(
        controller: widget.controller,
        layerLink: _layerLink,
        textFieldKey: _textFieldKey,
        onClose: _hideToolbar,
        enableWheelAdjustment: widget.enableWheelAdjustment,
        onInteractingChanged: (interacting) {
          _isInteractingWithToolbar = interacting;
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideToolbar() {
    _isInteractingWithToolbar = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _adjustWeightByStep(double step) {
    final result = _WeightSelectionEditor.parseSelection(widget.controller);
    _WeightSelectionEditor.applyWeight(
      widget.controller,
      (result.weight + step).clamp(0.1, 3.0),
    );
    _overlayEntry?.markNeedsBuild();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        !widget.enabled ||
        !widget.enableWheelAdjustment ||
        !_WeightSelectionEditor.hasSelection(widget.controller)) {
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
      child: CompositedTransformTarget(
        link: _layerLink,
        child: KeyedSubtree(key: _textFieldKey, child: widget.child),
      ),
    );
  }
}

/// 权重解析结果
class _WeightParseResult {
  final String baseText;
  final double weight;

  const _WeightParseResult({required this.baseText, required this.weight});
}

class _WeightSelectionEditor {
  static bool hasSelection(TextEditingController controller) {
    final selection = controller.selection;
    return selection.isValid &&
        selection.start != selection.end &&
        selection.start >= 0 &&
        selection.end <= controller.text.length;
  }

  static _WeightParseResult parseSelection(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || end > text.length || start >= end) {
      return const _WeightParseResult(baseText: '', weight: 1.0);
    }

    final selectedText = text.substring(start, end);
    return parseWeightSyntax(selectedText);
  }

  static _WeightParseResult parseWeightSyntax(String text) {
    var baseText = text;
    var weight = 1.0;

    final trimmed = text.trim();

    // NAI 数值权重语法: weight::text:: 或 weight::text
    final naiWeightMatch = RegExp(
      r'^(-?\d+\.?\d*)::(.+?)(?:::$|$)',
    ).firstMatch(trimmed);

    if (naiWeightMatch != null) {
      final weightValue = double.tryParse(naiWeightMatch.group(1)!);
      if (weightValue != null) {
        weight = weightValue;
        baseText = naiWeightMatch.group(2)!.trim();
        return _WeightParseResult(baseText: baseText, weight: weight);
      }
    }

    // 括号权重语法 {text} 或 [text]
    var braceCount = 0;
    var bracketCount = 0;

    var i = 0;
    while (i < trimmed.length) {
      if (trimmed[i] == '{') {
        braceCount++;
        i++;
      } else if (trimmed[i] == '[') {
        bracketCount++;
        i++;
      } else {
        break;
      }
    }

    var j = trimmed.length - 1;
    var closeBraceCount = 0;
    var closeBracketCount = 0;
    while (j >= i) {
      if (trimmed[j] == '}') {
        closeBraceCount++;
        j--;
      } else if (trimmed[j] == ']') {
        closeBracketCount++;
        j--;
      } else {
        break;
      }
    }

    final effectiveBraces = braceCount < closeBraceCount
        ? braceCount
        : closeBraceCount;
    final effectiveBrackets = bracketCount < closeBracketCount
        ? bracketCount
        : closeBracketCount;

    if (effectiveBraces > 0) {
      weight = 1.0 + (effectiveBraces * 0.05);
      baseText = trimmed
          .substring(effectiveBraces, trimmed.length - effectiveBraces)
          .trim();
    } else if (effectiveBrackets > 0) {
      weight = 1.0 - (effectiveBrackets * 0.05);
      baseText = trimmed
          .substring(effectiveBrackets, trimmed.length - effectiveBrackets)
          .trim();
    }

    return _WeightParseResult(
      baseText: baseText.trim(),
      weight: weight.clamp(0.1, 3.0),
    );
  }

  static bool applyWeight(TextEditingController controller, double newWeight) {
    final result = parseSelection(controller);
    final baseText = result.baseText;

    if (baseText.isEmpty) return false;

    String newText;
    if (newWeight == 1.0) {
      newText = baseText;
    } else {
      newText = '${newWeight.toStringAsFixed(2)}::$baseText::';
    }

    final text = controller.text;
    final selection = controller.selection;
    final newTextValue =
        text.substring(0, selection.start) +
        newText +
        text.substring(selection.end);

    controller.text = newTextValue;

    final newSelectionEnd = selection.start + newText.length;
    controller.selection = TextSelection(
      baseOffset: selection.start,
      extentOffset: newSelectionEnd,
    );

    return true;
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
    if (_WeightSelectionEditor.hasSelection(controllerProvider())) {
      return false;
    }
    return super.shouldAcceptUserOffset(position);
  }
}

bool supportsPromptWeightScrollPhysics(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
  };
}

/// 权重调整工具条
class _WeightAdjustToolbar extends StatefulWidget {
  final TextEditingController controller;
  final LayerLink layerLink;
  final GlobalKey textFieldKey;
  final VoidCallback onClose;
  final bool enableWheelAdjustment;
  final ValueChanged<bool> onInteractingChanged;

  const _WeightAdjustToolbar({
    required this.controller,
    required this.layerLink,
    required this.textFieldKey,
    required this.onClose,
    required this.enableWheelAdjustment,
    required this.onInteractingChanged,
  });

  @override
  State<_WeightAdjustToolbar> createState() => _WeightAdjustToolbarState();
}

class _WeightAdjustToolbarState extends State<_WeightAdjustToolbar> {
  final TextEditingController _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateWeightDisplay();
  }

  @override
  void didUpdateWidget(_WeightAdjustToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateWeightDisplay();
  }

  void _updateWeightDisplay() {
    final result = _WeightSelectionEditor.parseSelection(widget.controller);
    _weightController.text = result.weight.toStringAsFixed(2);
  }

  void _applyWeight(double newWeight) {
    if (!_WeightSelectionEditor.applyWeight(widget.controller, newWeight)) {
      return;
    }

    setState(() {
      _weightController.text = newWeight.toStringAsFixed(2);
    });
  }

  void _adjustWeightByStep(double step) {
    final currentWeight = double.tryParse(_weightController.text) ?? 1.0;
    _applyWeight((currentWeight + step).clamp(0.1, 3.0));
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        !widget.enableWheelAdjustment) {
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

  Offset _calculateOffset() {
    final textFieldContext = widget.textFieldKey.currentContext;
    if (textFieldContext == null) {
      return const Offset(0, -52);
    }

    final textFieldRenderBox =
        textFieldContext.findRenderObject() as RenderBox?;
    if (textFieldRenderBox == null) {
      return const Offset(0, -52);
    }

    RenderEditable? findRenderEditable(Element element) {
      RenderEditable? result;
      void search(Element e) {
        if (result != null) return;
        if (e.renderObject is RenderEditable) {
          result = e.renderObject as RenderEditable;
          return;
        }
        e.visitChildren(search);
      }

      search(element);
      return result;
    }

    final renderEditable = findRenderEditable(textFieldContext as Element);
    if (renderEditable == null) {
      return const Offset(0, -52);
    }

    final selection = widget.controller.selection;
    if (!selection.isValid || selection.start < 0) {
      return const Offset(0, -52);
    }

    final caretPosition = TextPosition(offset: selection.start);
    final caretRect = renderEditable.getLocalRectForCaret(caretPosition);

    const toolbarHeight = 48.0;
    const verticalPadding = 4.0;

    return Offset(
      caretRect.left,
      caretRect.top - toolbarHeight - verticalPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Listener(
      onPointerDown: (_) => widget.onInteractingChanged(true),
      onPointerUp: (_) => widget.onInteractingChanged(false),
      onPointerSignal: _handlePointerSignal,
      child: CompositedTransformFollower(
        link: widget.layerLink,
        showWhenUnlinked: false,
        offset: _calculateOffset(),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 220,
            height: 48,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.surfaceContainerHigh,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WeightButton(
                      icon: Icons.remove,
                      onPressed: () => _adjustWeightByStep(-0.05),
                      tooltip: l10n.tooltip_decreaseWeight,
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _weightController,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: colorScheme.outline.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onSubmitted: (value) {
                            final newWeight = double.tryParse(value) ?? 1.0;
                            _applyWeight(newWeight.clamp(0.1, 3.0));
                          },
                        ),
                      ),
                    ),
                    _WeightButton(
                      icon: Icons.add,
                      onPressed: () => _adjustWeightByStep(0.05),
                      tooltip: l10n.tooltip_increaseWeight,
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    _WeightButton(
                      icon: Icons.refresh,
                      onPressed: () => _applyWeight(1.0),
                      tooltip: l10n.tooltip_resetWeight,
                    ),
                    _WeightButton(
                      icon: Icons.close,
                      onPressed: widget.onClose,
                      tooltip: l10n.common_close,
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

/// 权重调整按钮
class _WeightButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const _WeightButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip ?? '',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
