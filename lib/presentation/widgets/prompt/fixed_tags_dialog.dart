import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import 'fixed_tags_dialog_controller.dart';
import 'fixed_tags_dialog_coordinator.dart';
import 'fixed_tags_dialog_models.dart';
import 'fixed_tags_dialog_view.dart';

export 'fixed_tag_library_picker_dialog.dart' show FixedTagLibraryPickerDialog;

/// 固定词管理对话框。
///
/// 该 shell 只负责连接唯一业务 Provider 与对话框本地生命周期；展示、交互
/// 编排和几何状态分别由 view、coordinator 与 controller 承担。
class FixedTagsDialog extends ConsumerStatefulWidget {
  const FixedTagsDialog({super.key, this.presentationManaged = false});

  final bool presentationManaged;

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      title: context.l10n.fixedTags_manage,
      sideSheetWidth: 980,
      builder: (_, __) => const FixedTagsDialog(presentationManaged: true),
    );
  }

  @override
  ConsumerState<FixedTagsDialog> createState() => _FixedTagsDialogState();
}

class _FixedTagsDialogState extends ConsumerState<FixedTagsDialog> {
  late final FixedTagsDialogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedTagsDialogController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewData = FixedTagsDialogViewData(
      state: ref.watch(fixedTagsNotifierProvider),
      libraryEntries: ref.watch(
        tagLibraryPageNotifierProvider.select((state) => state.entries),
      ),
    );
    final commands = FixedTagsDialogCoordinator(ref).commands(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => FixedTagsDialogView(
        data: viewData,
        commands: commands,
        controller: _controller,
        presentationManaged: widget.presentationManaged,
      ),
    );
  }
}
