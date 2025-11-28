import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 框选覆盖层
/// 支持 Shift+拖动进行矩形框选
class BoxSelectionOverlay extends StatefulWidget {
  /// 子组件
  final Widget child;

  /// 是否启用框选
  final bool enabled;

  /// 获取所有标签的位置回调
  final List<Rect> Function() getTagRects;

  /// 选择变化回调
  final ValueChanged<Set<int>> onSelectionChanged;

  /// 框选开始回调
  final VoidCallback? onSelectionStart;

  /// 框选结束回调
  final VoidCallback? onSelectionEnd;

  const BoxSelectionOverlay({
    super.key,
    required this.child,
    required this.enabled,
    required this.getTagRects,
    required this.onSelectionChanged,
    this.onSelectionStart,
    this.onSelectionEnd,
  });

  @override
  State<BoxSelectionOverlay> createState() => _BoxSelectionOverlayState();
}

class _BoxSelectionOverlayState extends State<BoxSelectionOverlay> {
  bool _isSelecting = false;
  Offset? _startPoint;
  Offset? _currentPoint;
  Set<int> _selectedIndices = {};

  bool get _isShiftPressed => HardwareKeyboard.instance.isShiftPressed;

  void _onPanStart(DragStartDetails details) {
    if (!widget.enabled || !_isShiftPressed) return;

    setState(() {
      _isSelecting = true;
      _startPoint = details.localPosition;
      _currentPoint = details.localPosition;
      _selectedIndices = {};
    });

    widget.onSelectionStart?.call();
    HapticFeedback.lightImpact();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isSelecting) return;

    setState(() {
      _currentPoint = details.localPosition;
    });

    _updateSelection();
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isSelecting) return;

    widget.onSelectionChanged(_selectedIndices);
    widget.onSelectionEnd?.call();

    setState(() {
      _isSelecting = false;
      _startPoint = null;
      _currentPoint = null;
    });

    if (_selectedIndices.isNotEmpty) {
      HapticFeedback.mediumImpact();
    }
  }

  void _updateSelection() {
    if (_startPoint == null || _currentPoint == null) return;

    final selectionRect = Rect.fromPoints(_startPoint!, _currentPoint!);
    final tagRects = widget.getTagRects();
    final newSelection = <int>{};

    for (var i = 0; i < tagRects.length; i++) {
      if (_rectsIntersect(selectionRect, tagRects[i])) {
        newSelection.add(i);
      }
    }

    if (!_setEquals(_selectedIndices, newSelection)) {
      setState(() {
        _selectedIndices = newSelection;
      });
    }
  }

  bool _rectsIntersect(Rect a, Rect b) {
    return !(a.right < b.left ||
        a.bottom < b.top ||
        a.left > b.right ||
        a.top > b.bottom);
  }

  bool _setEquals(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    return a.every((e) => b.contains(e));
  }

  Rect? get _selectionRect {
    if (_startPoint == null || _currentPoint == null) return null;
    return Rect.fromPoints(_startPoint!, _currentPoint!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          widget.child,
          if (_isSelecting && _selectionRect != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SelectionBoxPainter(
                    rect: _selectionRect!,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 选择框绘制器
class _SelectionBoxPainter extends CustomPainter {
  final Rect rect;
  final Color color;

  _SelectionBoxPainter({
    required this.rect,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 填充
    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // 边框
    final strokePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 绘制圆角矩形
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, strokePaint);
  }

  @override
  bool shouldRepaint(_SelectionBoxPainter oldDelegate) {
    return rect != oldDelegate.rect || color != oldDelegate.color;
  }
}

/// 框选控制器
/// 管理框选状态和选中的标签索引
class BoxSelectionController extends ChangeNotifier {
  Set<int> _selectedIndices = {};
  bool _isSelecting = false;

  /// 当前选中的索引集合
  Set<int> get selectedIndices => Set.unmodifiable(_selectedIndices);

  /// 是否正在框选
  bool get isSelecting => _isSelecting;

  /// 是否有选中项
  bool get hasSelection => _selectedIndices.isNotEmpty;

  /// 选中项数量
  int get selectionCount => _selectedIndices.length;

  /// 开始框选
  void startSelection() {
    _isSelecting = true;
    notifyListeners();
  }

  /// 结束框选
  void endSelection() {
    _isSelecting = false;
    notifyListeners();
  }

  /// 更新选中项
  void updateSelection(Set<int> indices) {
    _selectedIndices = Set.from(indices);
    notifyListeners();
  }

  /// 切换单个索引的选中状态
  void toggleIndex(int index) {
    if (_selectedIndices.contains(index)) {
      _selectedIndices.remove(index);
    } else {
      _selectedIndices.add(index);
    }
    notifyListeners();
  }

  /// 添加索引到选中
  void addIndex(int index) {
    _selectedIndices.add(index);
    notifyListeners();
  }

  /// 从选中移除索引
  void removeIndex(int index) {
    _selectedIndices.remove(index);
    notifyListeners();
  }

  /// 全选
  void selectAll(int count) {
    _selectedIndices = Set.from(List.generate(count, (i) => i));
    notifyListeners();
  }

  /// 清除选择
  void clearSelection() {
    _selectedIndices.clear();
    notifyListeners();
  }

  /// 检查索引是否被选中
  bool isSelected(int index) => _selectedIndices.contains(index);
}
