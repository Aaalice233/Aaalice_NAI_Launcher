import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';

import '../../../data/models/auth/saved_account.dart';
import '../common/inset_shadow_container.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

/// 昵称编辑弹窗
///
/// 用于修改账号的昵称
/// 支持中文、Emoji 等任意字符
class NicknameEditDialog extends StatefulWidget {
  /// 当前账号
  final SavedAccount account;

  const NicknameEditDialog({
    super.key,
    required this.account,
  });

  /// 显示昵称编辑弹窗
  ///
  /// [onSave] 回调在用户点击保存时触发，传入新的昵称
  static Future<void> show({
    required BuildContext context,
    required SavedAccount account,
    required void Function(String newNickname) onSave,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return NicknameEditDialog(
          account: account,
        );
      },
    ).then((result) {
      // result 是用户点击的按钮类型
      if (result == true) {
        // 用户点击了"保存"
        final nickname = _NicknameEditDialogState._currentNickname;
        if (nickname != null && nickname.trim().isNotEmpty) {
          // 保存时清理首尾空格
          onSave(nickname.trim());
        }
      }
    });
  }

  @override
  State<NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<NicknameEditDialog> {
  /// 当前昵称（静态变量用于在弹窗关闭时传递值）
  static String? _currentNickname;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String _errorText = '';
  bool _hasInteracted = false;

  /// 昵称最大长度
  static const int _maxLength = 64;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.account.nickname);
    _currentNickname = widget.account.nickname;
    _focusNode = FocusNode();
    _validateNickname(widget.account.nickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 验证昵称
  String? _validateNickname(String value) {
    // 检查是否为空（允许空格，但不允许纯空格字符串）
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return context.l10n.settings_nicknameEmpty;
    }

    // 检查长度（使用 characters 以正确支持 emoji 和中文）
    if (trimmed.characters.length > _maxLength) {
      return context.l10n.settings_nicknameTooLong(_maxLength);
    }

    return null;
  }

  void _onNicknameChanged(String value) {
    setState(() {
      _currentNickname = value;
      _hasInteracted = true;
      _errorText = _validateNickname(value) ?? '';
    });
  }

  void _onSave() {
    final error = _validateNickname(_controller.text);
    if (error != null) {
      setState(() {
        _hasInteracted = true;
        _errorText = error;
      });
      return;
    }

    // 关闭弹窗并返回保存信号
    Navigator.of(context).pop(true);
  }

  void _onCancel() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _hasInteracted ? _errorText : null;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.badge_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.settings_editNickname,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 昵称输入框
            InsetShadowContainer(
              borderRadius: 8,
              child: ThemedFormInput(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onNicknameChanged,
                onFieldSubmitted: (_) => _onSave(),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                maxLength: _maxLength,
                decoration: InputDecoration(
                  labelText: context.l10n.settings_nickname,
                  hintText: context.l10n.settings_nicknameHint,
                  errorText: error,
                  counterText:
                      '${_controller.text.characters.length}/$_maxLength',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(height: 24),

            // 按钮行
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _onCancel,
                  child: Text(context.l10n.common_cancel),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _validateNickname(_controller.text) == null &&
                          _controller.text.trim().isNotEmpty
                      ? _onSave
                      : null,
                  child: Text(context.l10n.common_save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
