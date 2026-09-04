import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

import '../../../data/models/auth/saved_account.dart';
import '../../adaptive/adaptive_presenter.dart';

/// 昵称编辑弹窗
///
/// 用于修改账号的昵称
/// 支持中文、Emoji 等任意字符
class NicknameEditDialog extends StatefulWidget {
  /// 当前账号
  final SavedAccount account;
  final ScrollController? scrollController;

  const NicknameEditDialog({
    super.key,
    required this.account,
    this.scrollController,
  });

  /// 显示昵称编辑表单。
  ///
  /// [onSave] 回调在用户点击保存时触发，传入新的昵称。
  static Future<void> show({
    required BuildContext context,
    required SavedAccount account,
    required void Function(String newNickname) onSave,
  }) async {
    final result = await AdaptivePresenter.showForm<String>(
      context: context,
      titleBuilder: (panelContext) {
        final theme = Theme.of(panelContext);
        return Row(
          children: [
            Icon(Icons.badge_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                panelContext.l10n.settings_editNickname,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
      width: 400,
      builder: (panelContext, scrollController) => NicknameEditDialog(
        account: account,
        scrollController: scrollController,
      ),
    );
    if (result != null) onSave(result);
  }

  @override
  State<NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<NicknameEditDialog> {
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

    Navigator.of(context).pop(_controller.text.trim());
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final error = _hasInteracted ? _errorText : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return SingleChildScrollView(
          key: const ValueKey('nickname-edit-form-scroll'),
          controller: widget.scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ThemedFormInput(
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: compact ? 16 : 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _onCancel,
                    child: Text(context.l10n.common_cancel),
                  ),
                  FilledButton(
                    onPressed:
                        _validateNickname(_controller.text) == null &&
                            _controller.text.trim().isNotEmpty
                        ? _onSave
                        : null,
                    child: Text(context.l10n.common_save),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
