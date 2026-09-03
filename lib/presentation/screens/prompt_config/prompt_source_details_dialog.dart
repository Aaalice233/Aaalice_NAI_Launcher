import 'package:flutter/material.dart';

import '../../../core/constants/model_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/official_wordlist.dart';
import '../../../data/models/prompt/random_prompt_result.dart';
import '../../../data/models/prompt/tag_library.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../themes/core/layered_surface_style.dart';

class PromptSourceDetailsDialog extends StatelessWidget {
  const PromptSourceDetailsDialog({
    super.key,
    required this.library,
    required this.mode,
    required this.profile,
    required this.officialData,
    this.scrollController,
  });

  final TagLibrary library;
  final RandomGenerationMode mode;
  final RandomPromptProfile profile;
  final OfficialWordlistData? officialData;
  final ScrollController? scrollController;

  static Future<void> show(
    BuildContext context, {
    required TagLibrary library,
    required RandomGenerationMode mode,
    required RandomPromptProfile profile,
    required OfficialWordlistData? officialData,
  }) => AdaptivePresenter.showForm<void>(
    context: context,
    title: context.l10n.randomManager_sourceDetails,
    sideSheetWidth: 680,
    builder: (context, scrollController) => PromptSourceDetailsDialog(
      library: library,
      mode: mode,
      profile: profile,
      officialData: officialData,
      scrollController: scrollController,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final includesOfficial = mode != RandomGenerationMode.custom;
    final includesCatalog = mode != RandomGenerationMode.naiOfficial;
    return ListView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      children: [
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SourceDetailsCard(
                children: [
                  _SourceDetailRow(
                    label: context.l10n.randomManager_currentMode,
                    value: mode.getName(context.l10n),
                  ),
                ],
              ),
              if (includesOfficial) ...[
                const SizedBox(height: 12),
                _SourceDetailsCard(
                  children: [
                    _SourceDetailRow(
                      label: context.l10n.randomManager_officialWordlist,
                      value: context.l10n.randomManager_officialWordlistCount(
                        randomPromptProfileName(context, profile),
                        randomPromptProfileCount(profile),
                      ),
                    ),
                    _SourceDetailRow(
                      label: context.l10n.randomManager_officialAsset,
                      value: context.l10n.randomManager_officialAssetCount(
                        officialWordlistTotalEntryCount,
                        officialWordlistTotalGroupCount,
                      ),
                    ),
                    _SourceDetailRow(
                      label: context.l10n.randomManager_sourceFile,
                      value: officialData?.sourceFileName ?? '—',
                    ),
                    _SourceDetailRow(
                      label: context.l10n.randomManager_sourceSha256,
                      value: officialData?.sourceSha256 ?? '—',
                    ),
                  ],
                ),
              ],
              if (includesCatalog) ...[
                const SizedBox(height: 12),
                _SourceDetailsCard(
                  children: [
                    _SourceDetailRow(
                      label: context.l10n.randomManager_sourceUrl,
                      value: library.sourceUrl ?? '—',
                    ),
                    _SourceDetailRow(
                      label: context.l10n.randomManager_sourceCommit,
                      value: library.sourceCommit ?? '—',
                    ),
                    _SourceDetailRow(
                      label: context.l10n.randomManager_sourceDate,
                      value:
                          library.sourceVersionDate
                              ?.toUtc()
                              .toIso8601String() ??
                          '—',
                    ),
                    _SourceDetailRow(
                      label: context.l10n.randomManager_sourceLicense,
                      value: library.sourceLicense ?? '—',
                    ),
                    _SourceDetailRow(
                      label: context.l10n.randomManager_catalogExtension,
                      value: context.l10n.randomManager_catalogCounts(
                        library.sourceCatalogTagCount ?? 0,
                        library.sourceCatalogAliasCount ?? 0,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_close),
          ),
        ),
      ],
    );
  }
}

String randomPromptProfileName(
  BuildContext context,
  RandomPromptProfile profile,
) => switch (profile) {
  RandomPromptProfile.legacyAnime =>
    context.l10n.randomManager_wordlistLegacyAnime,
  RandomPromptProfile.furryV3 => context.l10n.randomManager_wordlistFurryV3,
  RandomPromptProfile.characterPrompts =>
    context.l10n.randomManager_wordlistCharacterPrompts,
};

int randomPromptProfileCount(RandomPromptProfile profile) =>
    officialWordlistGeneratorEntryCounts[profile.name]!;

class _SourceDetailsCard extends StatelessWidget {
  const _SourceDetailsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sectionSurfaceColor(Theme.of(context).colorScheme),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }
}

class _SourceDetailRow extends StatelessWidget {
  const _SourceDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
