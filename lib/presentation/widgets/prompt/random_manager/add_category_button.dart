import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../data/models/prompt/random_category.dart';
import '../../../providers/random_preset_provider.dart';
import '../../common/themed_input_dialog.dart';

/// 添加类别按钮
class AddCategoryButton extends ConsumerStatefulWidget {
  const AddCategoryButton({super.key});

  @override
  ConsumerState<AddCategoryButton> createState() => _AddCategoryButtonState();
}

class _AddCategoryButtonState extends ConsumerState<AddCategoryButton> {
  Future<void> _handlePressed() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await ThemedInputDialog.show(
      context: context,
      title: l10n.category_dialogTitle,
      hintText: l10n.category_nameHint,
      validator: (v) => v.trim().isEmpty ? l10n.category_nameRequired : null,
    );
    if (!mounted || name == null || name.trim().isEmpty) return;

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
    return FilledButton.tonalIcon(
      onPressed: _handlePressed,
      icon: const Icon(Icons.add_rounded),
      label: Text(AppLocalizations.of(context)!.randomManager_addCategory),
    );
  }
}
