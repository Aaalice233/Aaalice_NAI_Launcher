import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/window_size_class.dart';
import '../../providers/online_gallery_output_filter_provider.dart';
import '../autocomplete/autocomplete_config.dart';
import '../tag_chip.dart';
import '../autocomplete/autocomplete_wrapper.dart';

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
        Row(
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.onlineGallery_outputFilterTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.onlineGallery_outputFilterSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${tags.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AutocompleteWrapper(
                controller: _tagController,
                focusNode: _tagFocusNode,
                config: const AutocompleteConfig(
                  minQueryLength: 1,
                  autoInsertComma: false,
                ),
                onSuggestionSelected: (_) => _addTags(),
                child: TextField(
                  controller: _tagController,
                  focusNode: _tagFocusNode,
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: context.l10n.onlineGallery_outputFilterAddHint,
                    helperText:
                        context.l10n.onlineGallery_outputFilterInputHint,
                  ),
                  onSubmitted: (_) => _addTags(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: Center(
                child: IconButton.filledTonal(
                  tooltip: context.l10n.common_add,
                  onPressed: _addTags,
                  icon: const Icon(Icons.add),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 280),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: tags.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      context.l10n.onlineGallery_outputFilterEmpty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in tags)
                        SimpleTagChip(
                          tag: tag,
                          color: theme.colorScheme.primary,
                          onDeleted: () => ref
                              .read(onlineGalleryOutputFilterProvider.notifier)
                              .removeTag(tag),
                          deleteTooltip: context.l10n.common_delete,
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 4,
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _resetDefaults,
              icon: const Icon(Icons.restore, size: 18),
              label: Text(
                context.l10n.onlineGallery_outputFilterRestoreDefaults,
              ),
            ),
            TextButton.icon(
              onPressed: tags.isEmpty ? null : _clearAll,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(context.l10n.common_clear),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ],
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
    sideSheetWidth: 768,
    builder: (panelContext, scrollController) => SingleChildScrollView(
      key: const ValueKey('online-gallery-output-filter-form-scroll'),
      controller: scrollController,
      padding: const EdgeInsets.all(20),
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
