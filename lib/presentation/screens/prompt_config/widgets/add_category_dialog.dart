import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../widgets/common/emoji_picker_dialog.dart';
import '../../../widgets/common/inset_shadow_container.dart';
import '../../../widgets/common/themed_slider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

/// 新增类别对话框的返回结果
class AddCategoryResult {
  /// 类别名称
  final String name;

  /// 类别标识（key）
  final String key;

  /// emoji 图标
  final String emoji;

  /// 选中概率 (0.0 - 1.0)
  final double probability;

  const AddCategoryResult({
    required this.name,
    required this.key,
    required this.emoji,
    required this.probability,
  });
}

/// 新增类别对话框
///
/// 用于创建自定义类别，包含名称、emoji 和概率设置
class AddCategoryDialog extends StatefulWidget {
  /// 已存在的类别 key 列表（用于唯一性校验）
  final List<String> existingKeys;

  const AddCategoryDialog({
    super.key,
    required this.existingKeys,
  });

  /// 显示新增类别对话框
  ///
  /// 返回 [AddCategoryResult]，如果用户取消则返回 null
  static Future<AddCategoryResult?> show(
    BuildContext context, {
    required List<String> existingKeys,
  }) {
    return showDialog<AddCategoryResult>(
      context: context,
      builder: (context) => AddCategoryDialog(existingKeys: existingKeys),
    );
  }

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _selectedEmoji = '🏷️';
  double _probability = 1.0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 从名称自动生成唯一 key
  String _generateUniqueKey(String name) {
    // 基础 key 生成
    String baseKey;
    final cleanName = name.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]'), '');

    if (cleanName.isEmpty) {
      baseKey = 'custom';
    } else if (RegExp(r'^[a-zA-Z\s]+$').hasMatch(name)) {
      // 英文：使用驼峰命名
      final words = name.toLowerCase().split(RegExp(r'\s+'));
      if (words.length == 1) {
        baseKey = words[0];
      } else {
        baseKey = words[0] +
            words
                .skip(1)
                .map((w) => w[0].toUpperCase() + w.substring(1))
                .join();
      }
    } else {
      // 中文或混合：使用 custom 前缀
      baseKey = 'custom';
    }

    // 确保唯一性
    String finalKey = baseKey;
    int counter = 1;
    while (widget.existingKeys.contains(finalKey)) {
      finalKey = '${baseKey}_$counter';
      counter++;
    }

    return finalKey;
  }

  Future<void> _selectEmoji() async {
    final emoji = await EmojiPickerDialog.show(
      context,
      initialEmoji: _selectedEmoji,
    );
    if (emoji != null && mounted) {
      setState(() => _selectedEmoji = emoji);
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;

    final name = _nameController.text.trim();
    final result = AddCategoryResult(
      name: name,
      key: _generateUniqueKey(name),
      emoji: _selectedEmoji,
      probability: _probability,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(context.l10n.category_dialogTitle),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji 和名称输入（紧凑布局）
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Emoji 选择按钮
                  InkWell(
                    onTap: _selectEmoji,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _selectedEmoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 名称输入
                  Expanded(
                    child: InsetShadowContainer(
                      borderRadius: 8,
                      child: ThemedFormInput(
                        controller: _nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: context.l10n.category_name,
                          hintText: context.l10n.category_nameHint,
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.l10n.category_nameRequired;
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 概率滑块（紧凑设计）
              Row(
                children: [
                  Text(
                    context.l10n.category_probability,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(_probability * 100).round()}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ThemedSlider(
                value: _probability,
                onChanged: (value) {
                  setState(() => _probability = value);
                },
                min: 0,
                max: 1,
                divisions: 20,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.common_confirm),
        ),
      ],
    );
  }
}
