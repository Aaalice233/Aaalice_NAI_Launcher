import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../data/models/prompt/random_category.dart';
import '../../../providers/random_preset_provider.dart';
import '../../common/themed_input_dialog.dart';

/// 添加类别按钮
class AddCategoryButton extends ConsumerStatefulWidget {
  const AddCategoryButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  ConsumerState<AddCategoryButton> createState() => _AddCategoryButtonState();
}

class _AddCategoryButtonState extends ConsumerState<AddCategoryButton> {
  bool _isHovered = false;

  /// 未传入上层流程时，按钮仍能完成标准的类别创建。
  Future<void> _handlePressed() async {
    final customHandler = widget.onPressed;
    if (customHandler != null) {
      customHandler();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final name = await ThemedInputDialog.show(
      context: context,
      title: l10n.category_dialogTitle,
      hintText: l10n.category_nameHint,
      validator: (v) => v.trim().isEmpty ? l10n.category_nameRequired : null,
    );
    if (name == null || name.trim().isEmpty) return;

    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    if (preset == null) return;
    // 键名只在预设内用于标识，用序号保证可读且不与现有类别冲突
    var index = preset.categories.length + 1;
    var key = 'custom$index';
    while (preset.findCategoryByKey(key) != null) {
      index++;
      key = 'custom$index';
    }

    await ref
        .read(randomPresetNotifierProvider.notifier)
        .addCategory(RandomCategory.create(name: name.trim(), key: key));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _handlePressed,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: _isHovered
                ? LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.15),
                      colorScheme.secondary.withValues(alpha: 0.1),
                    ],
                  )
                : null,
            color: _isHovered ? null : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size: 16,
                color: _isHovered
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.randomManager_addCategory,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _isHovered
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
