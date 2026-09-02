import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/adaptive/window_size_class.dart';

/// NAI 随机规则说明弹窗
///
/// 展示 Prompt 生成器的内置规则逻辑
class NaiRulesDialog extends StatelessWidget {
  const NaiRulesDialog({super.key, this.scrollController});

  final ScrollController? scrollController;

  /// 显示弹窗
  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      sideSheetWidth: 600,
      titleBuilder: (context) => Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.naiRules_title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      builder: (context, scrollController) =>
          NaiRulesDialog(scrollController: scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compact = context.adaptiveWindow.isCompact;

    return Column(
      key: const ValueKey('nai-rules-content'),
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('nai-rules-scroll'),
            controller: scrollController,
            padding: EdgeInsets.all(compact ? 12 : 24),
            children: [
              _buildSection(
                context,
                title: l10n.naiRules_characterCountProbability,
                icon: Icons.people_outline,
                children: [
                  _buildProbabilityItem(context, l10n.naiRules_solo, '50%'),
                  _buildProbabilityItem(context, l10n.naiRules_duo, '30%'),
                  _buildProbabilityItem(context, l10n.naiRules_trio, '15%'),
                  _buildProbabilityItem(context, l10n.naiRules_group, '5%'),
                ],
              ),
              _buildSection(
                context,
                title: l10n.naiRules_genderRules,
                icon: Icons.wc,
                children: [
                  _buildProbabilityItem(context, l10n.naiRules_female, '30%'),
                  _buildProbabilityItem(context, l10n.naiRules_male, '10%'),
                  _buildProbabilityItem(context, l10n.naiRules_mixed, '60%'),
                ],
              ),
              _buildSection(
                context,
                title: l10n.naiRules_categoryProbability,
                icon: Icons.category_outlined,
                children: [
                  ListTile(
                    dense: true,
                    title: Text(l10n.naiRules_dynamicTagWeightTitle),
                    subtitle: Text(l10n.naiRules_dynamicTagWeightSubtitle),
                  ),
                ],
              ),
              _buildSection(
                context,
                title: l10n.naiRules_specialMechanisms,
                icon: Icons.auto_awesome,
                children: [
                  _buildProbabilityItem(
                    context,
                    l10n.naiRules_tagStrengthening,
                    '2%',
                  ),
                  ListTile(
                    dense: true,
                    title: Text(l10n.naiRules_seasonalLibraryTitle),
                    subtitle: Text(l10n.naiRules_seasonalLibrarySubtitle),
                  ),
                ],
              ),
              _buildSection(
                context,
                title: l10n.naiRules_v4CharacterPositioning,
                icon: Icons.grid_view,
                children: [
                  ListTile(
                    dense: true,
                    title: Text(l10n.naiRules_smartPositionTitle),
                    subtitle: Text(l10n.naiRules_smartPositionSubtitle),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 24,
              vertical: compact ? 8 : 12,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.common_gotIt),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: children,
      ),
    );
  }

  Widget _buildProbabilityItem(
    BuildContext context,
    String label,
    String probability,
  ) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(label),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          probability,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
