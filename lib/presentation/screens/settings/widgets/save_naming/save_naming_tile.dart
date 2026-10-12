import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../providers/image_save_settings_provider.dart';
import 'save_naming_form.dart';
import 'save_naming_preview_sample.dart';

/// 存储设置里的“文件夹与文件名”入口，副标题显示按当前规则得到的示例路径。
class SaveNamingTile extends ConsumerWidget {
  const SaveNamingTile({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(imageSaveSettingsNotifierProvider.notifier);
    final result = await showSaveNamingForm(
      context,
      initial: ref.read(imageSaveSettingsNotifierProvider).naming,
    );
    if (result == null) return;
    await notifier.setNaming(result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final naming = ref.watch(
      imageSaveSettingsNotifierProvider.select((settings) => settings.naming),
    );
    final example = naming
        .resolve(SaveNamingPreviewSample.builtIn(DateTime.now()).context)
        .relativeFileName;
    return ListTile(
      key: const ValueKey('save-naming-tile'),
      leading: const Icon(Icons.drive_file_rename_outline),
      title: Text(context.l10n.settings_saveNaming),
      subtitle: Text(
        context.l10n.settings_saveNamingSubtitle(example),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _edit(context, ref),
    );
  }
}
