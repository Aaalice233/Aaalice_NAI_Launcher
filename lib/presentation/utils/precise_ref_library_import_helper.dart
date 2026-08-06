import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../providers/precise_ref_library_provider.dart';
import '../widgets/common/app_toast.dart';

/// 把图片字节快速存入精准参考库（各触点共用）
///
/// 不弹对话框：自动命名 + 默认参数直接入库，toast 提示可在库中编辑。
/// [suggestedName] 为空时使用时间戳命名（Ref_yyyyMMdd_HHmmss）。
Future<void> saveBytesToPreciseRefLibrary(
  WidgetRef ref,
  BuildContext context,
  Uint8List bytes, {
  String? suggestedName,
}) async {
  final name = (suggestedName == null || suggestedName.trim().isEmpty)
      ? defaultPreciseRefName()
      : suggestedName.trim();

  try {
    final entry = await ref
        .read(preciseRefLibraryNotifierProvider.notifier)
        .importFromBytes(bytes, name: name);

    if (!context.mounted) return;
    final l10n = context.l10n;
    AppToast.success(
      context,
      '${l10n.preciseRefLib_saved(entry.name)} · ${l10n.preciseRefLib_savedHint}',
    );
  } catch (e) {
    if (!context.mounted) return;
    AppToast.error(context, context.l10n.preciseRefLib_importFailed('$e'));
  }
}

/// 默认时间戳命名（Ref_yyyyMMdd_HHmmss）
String defaultPreciseRefName() {
  final now = DateTime.now();
  String pad(int value) => value.toString().padLeft(2, '0');
  return 'Ref_${now.year}${pad(now.month)}${pad(now.day)}'
      '_${pad(now.hour)}${pad(now.minute)}${pad(now.second)}';
}
