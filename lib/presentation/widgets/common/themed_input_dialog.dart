import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

import '../../adaptive/adaptive_presenter.dart';
import 'adaptive_dialog_frame.dart';

/// 通用输入对话框
///
/// 用于需要用户输入单行文本的场景，如重命名、输入名称等。
///
/// 使用示例:
/// ```dart
/// final name = await ThemedInputDialog.show(
///   context: context,
///   title: '输入名称',
///   hintText: '请输入预设名称',
///   validator: (v) => v.isEmpty ? '名称不能为空' : null,
/// );
/// if (name != null) { ... }
/// ```
class ThemedInputDialog extends StatefulWidget {
  /// 对话框标题
  final String title;

  /// 输入框标签
  final String? labelText;

  /// 输入框提示文字
  final String? hintText;

  /// 初始值
  final String? initialValue;

  /// 输入验证器，返回错误信息或 null
  final String? Function(String)? validator;

  /// 确认按钮文字
  final String? confirmText;

  /// 取消按钮文字
  final String? cancelText;

  /// 是否多行输入
  final bool multiline;

  /// 多行输入时的最大行数
  final int maxLines;

  final bool presentationManaged;
  final ScrollController? scrollController;

  const ThemedInputDialog({
    super.key,
    required this.title,
    this.labelText,
    this.hintText,
    this.initialValue,
    this.validator,
    this.confirmText,
    this.cancelText,
    this.multiline = false,
    this.maxLines = 5,
    this.presentationManaged = false,
    this.scrollController,
  });

  /// 显示输入对话框
  ///
  /// 返回用户输入的文本，取消时返回 null
  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? labelText,
    String? hintText,
    String? initialValue,
    String? Function(String)? validator,
    String? confirmText,
    String? cancelText,
    bool multiline = false,
    int maxLines = 5,
  }) {
    return AdaptivePresenter.showForm<String>(
      context: context,
      title: title,
      sideSheetWidth: multiline ? 440 : 380,
      builder: (context, scrollController) => ThemedInputDialog(
        title: title,
        labelText: labelText,
        hintText: hintText,
        initialValue: initialValue,
        validator: validator,
        confirmText: confirmText,
        cancelText: cancelText,
        multiline: multiline,
        maxLines: maxLines,
        presentationManaged: true,
        scrollController: scrollController,
      ),
    );
  }

  @override
  State<ThemedInputDialog> createState() => _ThemedInputDialogState();
}

class _ThemedInputDialogState extends State<ThemedInputDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    // 初始验证
    if (widget.initialValue != null && widget.validator != null) {
      _errorText = widget.validator!(widget.initialValue!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String value) {
    setState(() {
      if (widget.validator != null) {
        _errorText = widget.validator!(value);
      }
      // 即使没有 validator，也需要触发 setState 以更新 _canSubmit 状态
    });
  }

  bool get _canSubmit {
    final text = _controller.text.trim();
    if (text.isEmpty) return false;
    if (widget.validator != null && widget.validator!(text) != null) {
      return false;
    }
    return true;
  }

  void _submit() {
    if (_canSubmit) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final confirmText = widget.confirmText ?? l10n.common_confirm;
    final cancelText = widget.cancelText ?? l10n.common_cancel;

    final contentWidth = widget.multiline ? 400.0 : 320.0;

    final content = AdaptiveDialogFrame(
      maxWidth: contentWidth,
      maxHeight: widget.multiline ? 280 : 120,
      reservedVerticalSpace: widget.presentationManaged ? 80 : 120,
      scaleReservedVerticalSpace: true,
      horizontalMargin: widget.presentationManaged ? 0 : 24,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: ThemedInput(
          controller: _controller,
          autofocus: true,
          maxLines: widget.multiline ? widget.maxLines : 1,
          minLines: widget.multiline ? 3 : 1,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            errorText: _errorText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onChanged: _validate,
          onSubmitted: widget.multiline ? null : (_) => _submit(),
        ),
      ),
    );
    final actions = <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(
          cancelText,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
      FilledButton(
        onPressed: _canSubmit ? _submit : null,
        child: Text(confirmText),
      ),
    ];

    if (!widget.presentationManaged) {
      return AlertDialog(
        scrollable: true,
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          widget.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: content,
        actions: actions,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Expanded(
            child: Align(alignment: Alignment.topCenter, child: content),
          ),
          const SizedBox(height: 8),
          SafeArea(
            top: false,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(spacing: 8, runSpacing: 8, children: actions),
            ),
          ),
        ],
      ),
    );
  }
}
