import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

/// 预设创建模式
enum PresetCreationMode {
  /// 完全空白
  blank,

  /// 基于默认预设
  template,
}

/// 新建预设结果
class NewPresetResult {
  final String name;
  final PresetCreationMode mode;

  NewPresetResult({required this.name, required this.mode});
}

/// 新建预设对话框
///
/// 用于输入预设名称并选择创建模式：
/// - 完全空白：从头开始创建
/// - 基于默认预设：复制默认预设作为起点
class NewPresetDialog extends StatefulWidget {
  const NewPresetDialog({super.key});

  /// 显示对话框并返回结果
  static Future<NewPresetResult?> show(BuildContext context) {
    return showDialog<NewPresetResult>(
      context: context,
      builder: (context) => const NewPresetDialog(),
    );
  }

  @override
  State<NewPresetDialog> createState() => _NewPresetDialogState();
}

class _NewPresetDialogState extends State<NewPresetDialog> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  PresetCreationMode _selectedMode = PresetCreationMode.template;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    // 自动聚焦到名称输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = context.l10n.newPresetDialog_nameRequired);
      return;
    }
    Navigator.of(context).pop(NewPresetResult(name: name, mode: _selectedMode));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    final mediaQuery = MediaQuery.of(context);
    final isCompact =
        mediaQuery.size.width < 600 || mediaQuery.size.height < 600;
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.vertical -
        mediaQuery.viewInsets.bottom -
        (isCompact ? 24 : 48);
    final isShort = availableHeight < 320;

    return SafeArea(
      minimum: EdgeInsets.all(isCompact ? 12 : 24),
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: availableHeight.clamp(160, 560),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isShort ? 12 : 16,
                  vertical: isShort ? 4 : 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.newPresetDialog_title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // 内容区域在键盘、小高度和大字体下滚动，标题与动作始终固定可达。
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名称输入
                      TextField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        decoration: InputDecoration(
                          labelText: l10n.newPresetDialog_nameLabel,
                          hintText: l10n.newPresetDialog_nameHint,
                          errorText: _nameError,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.edit_outlined),
                        ),
                        onChanged: (_) {
                          if (_nameError != null) {
                            setState(() => _nameError = null);
                          }
                        },
                        onSubmitted: (_) => _validateAndSubmit(),
                      ),
                      const SizedBox(height: 20),

                      // 创建模式选择
                      Text(
                        l10n.newPresetDialog_creationMode,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 基于默认预设选项
                      _ModeOptionCard(
                        icon: Icons.content_copy_outlined,
                        title: l10n.newPresetDialog_template,
                        subtitle: l10n.newPresetDialog_templateDesc,
                        isSelected:
                            _selectedMode == PresetCreationMode.template,
                        onTap: () => setState(
                          () => _selectedMode = PresetCreationMode.template,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 完全空白选项
                      _ModeOptionCard(
                        icon: Icons.note_add_outlined,
                        title: l10n.newPresetDialog_blank,
                        subtitle: l10n.newPresetDialog_blankDesc,
                        isSelected: _selectedMode == PresetCreationMode.blank,
                        onTap: () => setState(
                          () => _selectedMode = PresetCreationMode.blank,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 底部按钮
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isShort ? 4 : 16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.common_cancel),
                    ),
                    FilledButton.icon(
                      onPressed: _validateAndSubmit,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(l10n.common_create),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 模式选项卡片
class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: colorScheme.primary, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? colorScheme.primary : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
