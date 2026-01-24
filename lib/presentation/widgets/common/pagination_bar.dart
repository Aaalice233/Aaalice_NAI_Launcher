import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 分页导航栏
///
/// 支持可输入页码功能：
/// - 点击页码文本进入编辑模式
/// - Enter 确认跳转
/// - 失去焦点自动取消编辑
/// - 非法值自动修正到有效范围
class PaginationBar extends StatefulWidget {
  final int currentPage; // 0-based
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  State<PaginationBar> createState() => _PaginationBarState();
}

class _PaginationBarState extends State<PaginationBar> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      // 失去焦点时取消编辑（不跳转）
      setState(() {
        _isEditing = false;
      });
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      // 显示 1-based 页码
      _controller.text = (widget.currentPage + 1).toString();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    // 在下一帧请求焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _submitPage() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      _cancelEditing();
      return;
    }

    final parsed = int.tryParse(input);
    if (parsed == null) {
      _cancelEditing();
      return;
    }

    // 转换为 0-based 并限制范围
    int targetPage = parsed - 1;
    if (targetPage < 0) targetPage = 0;
    if (targetPage >= widget.totalPages) targetPage = widget.totalPages - 1;

    setState(() {
      _isEditing = false;
    });

    // 只有页码变化时才触发回调
    if (targetPage != widget.currentPage) {
      widget.onPageChanged(targetPage);
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一页按钮
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: widget.currentPage > 0
                ? () => widget.onPageChanged(widget.currentPage - 1)
                : null,
          ),

          // 页码显示/输入
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _isEditing
                ? _buildEditablePageInput(colorScheme, textTheme)
                : _buildClickablePageDisplay(colorScheme, textTheme),
          ),

          // 下一页按钮
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: widget.currentPage < widget.totalPages - 1
                ? () => widget.onPageChanged(widget.currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  /// 可点击的页码显示
  Widget _buildClickablePageDisplay(
      ColorScheme colorScheme, TextTheme textTheme,) {
    return InkWell(
      onTap: widget.totalPages > 1 ? _startEditing : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.currentPage + 1}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' / ${widget.totalPages}',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 页码输入框
  Widget _buildEditablePageInput(ColorScheme colorScheme, TextTheme textTheme) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          suffixText: '/ ${widget.totalPages}',
          suffixStyle: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5), // 最多 5 位数
        ],
        onSubmitted: (_) => _submitPage(),
      ),
    );
  }
}
