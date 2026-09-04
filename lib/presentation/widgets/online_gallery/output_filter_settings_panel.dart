import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/window_size_class.dart';
import '../../providers/online_gallery_output_filter_provider.dart';
import 'gallery_tag_rules_editor.dart';

class OnlineGalleryOutputFilterSettingsPanel extends ConsumerStatefulWidget {
  const OnlineGalleryOutputFilterSettingsPanel({super.key});

  @override
  ConsumerState<OnlineGalleryOutputFilterSettingsPanel> createState() =>
      _OnlineGalleryOutputFilterSettingsPanelState();
}

class _OnlineGalleryOutputFilterSettingsPanelState
    extends ConsumerState<OnlineGalleryOutputFilterSettingsPanel> {
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();

  @override
  void dispose() {
    _tagController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(onlineGalleryOutputFilterProvider);
    final tags = settings.tags.toList()..sort();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GalleryTagRulesHeader(
          icon: Icons.filter_alt_off_outlined,
          title: context.l10n.onlineGallery_outputFilterTitle,
          subtitle: context.l10n.onlineGallery_outputFilterSubtitle,
          count: tags.length,
          accent: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        GalleryTagRulesInput(
          controller: _tagController,
          focusNode: _tagFocusNode,
          hintText: context.l10n.onlineGallery_outputFilterAddHint,
          helperText: context.l10n.onlineGallery_outputFilterInputHint,
          onAdd: _addTags,
        ),
        const SizedBox(height: 14),
        GalleryTagRulesList(
          tags: tags,
          emptyLabel: context.l10n.onlineGallery_outputFilterEmpty,
          keyPrefix: 'online-gallery-output-filter',
          onDelete: (tag) => ref
              .read(onlineGalleryOutputFilterProvider.notifier)
              .removeTag(tag),
        ),
        const SizedBox(height: 12),
        GalleryTagRulesActions(
          clearEnabled: tags.isNotEmpty,
          onClear: _clearAll,
          leading: TextButton.icon(
            onPressed: _resetDefaults,
            icon: const Icon(Icons.restore, size: 18),
            label: Text(context.l10n.onlineGallery_outputFilterRestoreDefaults),
          ),
        ),
      ],
    );
  }

  Future<void> _addTags() async {
    final values = _tagController.text
        .split(RegExp(r'[,\n，、]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    if (values.isEmpty) return;
    await ref.read(onlineGalleryOutputFilterProvider.notifier).addTags(values);
    if (!mounted) return;
    _tagController.clear();
    _tagFocusNode.requestFocus();
  }

  Future<void> _resetDefaults() async {
    await ref
        .read(onlineGalleryOutputFilterProvider.notifier)
        .resetToDefaults();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        constraints: _responsiveDialogConstraints(context, 560),
        insetPadding: _responsiveDialogInsetPadding,
        scrollable: true,
        title: Text(context.l10n.onlineGallery_outputFilterClearTitle),
        content: Text(context.l10n.onlineGallery_outputFilterClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.common_clear),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(onlineGalleryOutputFilterProvider.notifier).clear();
    }
  }
}

Future<void> showOnlineGalleryOutputFilterDialog(BuildContext context) {
  return AdaptivePresenter.showForm<void>(
    context: context,
    title: context.l10n.onlineGallery_outputFilter,
    dialogWidth: 728,
    builder: (panelContext, scrollController) => SingleChildScrollView(
      key: const ValueKey('online-gallery-output-filter-form-scroll'),
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: const OnlineGalleryOutputFilterSettingsPanel(),
    ),
  );
}

const _responsiveDialogInsetPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 12,
);

BoxConstraints _responsiveDialogConstraints(
  BuildContext context,
  double maxWidth,
) {
  final unobscuredSize = context.adaptiveWindow.unobscuredSize;
  final safeWidth = unobscuredSize.width - 24;
  final safeHeight = unobscuredSize.height - 24;
  return BoxConstraints(
    minWidth: safeWidth.clamp(0, 280).toDouble(),
    maxWidth: safeWidth.clamp(0, maxWidth).toDouble(),
    maxHeight: safeHeight.clamp(0, double.infinity).toDouble(),
  );
}
