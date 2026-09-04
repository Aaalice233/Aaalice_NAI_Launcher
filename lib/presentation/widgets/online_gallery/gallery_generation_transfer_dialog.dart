import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../services/generation_prompt_transfer_service.dart';
import '../common/adaptive_dialog_frame.dart';

/// Lets users choose which recognized NovelAI settings accompany a prompt
/// sent from AI TAG to the native text-to-image form.
class GalleryGenerationTransferDialog extends StatefulWidget {
  const GalleryGenerationTransferDialog._({
    required this.configuration,
    required this.scrollController,
  });

  final GenerationTransferConfiguration? configuration;
  final ScrollController scrollController;

  static Future<Set<GenerationTransferSetting>?> show(
    BuildContext context, {
    required GenerationTransferConfiguration? configuration,
  }) => AdaptivePresenter.showForm<Set<GenerationTransferSetting>>(
    context: context,
    dialogWidth: 520,
    maxCenteredHeight: 720,
    titleBuilder: (panelContext) => Row(
      children: [
        Icon(
          Icons.send_outlined,
          size: 22,
          color: Theme.of(panelContext).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            panelContext.l10n.onlineGallery_sendToTextToImage,
            style: Theme.of(panelContext).textTheme.titleLarge,
          ),
        ),
      ],
    ),
    builder: (_, scrollController) => GalleryGenerationTransferDialog._(
      configuration: configuration,
      scrollController: scrollController,
    ),
  );

  @override
  State<GalleryGenerationTransferDialog> createState() =>
      _GalleryGenerationTransferDialogState();
}

class _GalleryGenerationTransferDialogState
    extends State<GalleryGenerationTransferDialog> {
  final Set<GenerationTransferSetting> _selected = {};

  Set<GenerationTransferSetting> get _available =>
      widget.configuration?.availableSettings ?? const {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const options = GenerationTransferSetting.values;
    return AdaptiveDialogFrame(
      key: const ValueKey('gallery-generation-transfer-dialog'),
      maxWidth: 520,
      maxHeight: 640,
      reservedVerticalSpace: 0,
      horizontalMargin: 0,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              children: [
                Text(
                  context.l10n.onlineGallery_replaceConfig,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.configuration == null
                      ? context.l10n.onlineGallery_replaceConfigNaiOnly
                      : context.l10n.onlineGallery_replaceConfigDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: _available.isEmpty
                          ? null
                          : () => setState(() {
                              _selected
                                ..clear()
                                ..addAll(_available);
                            }),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: Text(context.l10n.common_selectAll),
                    ),
                    TextButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => setState(_selected.clear),
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: Text(context.l10n.common_clear),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Material(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < options.length; index++) ...[
                        _settingTile(options[index]),
                        if (index + 1 < options.length)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.common_cancel),
                ),
                FilledButton.icon(
                  key: const ValueKey('gallery-generation-transfer-submit'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(Set<GenerationTransferSetting>.from(_selected)),
                  icon: const Icon(Icons.send, size: 18),
                  label: Text(
                    context.l10n.onlineGallery_sendToTextToImage,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingTile(GenerationTransferSetting setting) {
    final theme = Theme.of(context);
    final enabled = _available.contains(setting);
    return CheckboxListTile(
      key: ValueKey('gallery-generation-setting-${setting.name}'),
      value: enabled && _selected.contains(setting),
      onChanged: enabled
          ? (checked) => setState(() {
              if (checked ?? false) {
                _selected.add(setting);
              } else {
                _selected.remove(setting);
              }
            })
          : null,
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: Icon(
        _icon(setting),
        size: 20,
        color: enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      title: Text(
        _label(setting),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        enabled ? _value(setting) : context.l10n.metadataImport_noData,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    );
  }

  String _label(GenerationTransferSetting setting) => switch (setting) {
    GenerationTransferSetting.model => context.l10n.generation_model,
    GenerationTransferSetting.size => context.l10n.generation_imageSize,
    GenerationTransferSetting.sampler => context.l10n.generation_sampler,
    GenerationTransferSetting.seed => context.l10n.generation_seed,
    GenerationTransferSetting.steps => context.l10n.queue_steps,
    GenerationTransferSetting.scale => context.l10n.queue_cfg,
    GenerationTransferSetting.cfgRescale => _labelBeforeColon(
      context.l10n.generation_cfgRescale(''),
    ),
    GenerationTransferSetting.noiseSchedule =>
      context.l10n.generation_noiseSchedule,
    GenerationTransferSetting.smea => context.l10n.generation_smea,
    GenerationTransferSetting.smeaDyn => context.l10n.generation_smeaDyn,
  };

  String _value(GenerationTransferSetting setting) {
    final configuration = widget.configuration!;
    return switch (setting) {
      GenerationTransferSetting.model =>
        ImageModels.modelDisplayNames[configuration.model] ??
            configuration.model!,
      GenerationTransferSetting.size =>
        '${configuration.width} x ${configuration.height}',
      GenerationTransferSetting.sampler =>
        Samplers.samplerDisplayNames[configuration.sampler] ??
            configuration.sampler!,
      GenerationTransferSetting.seed => '${configuration.seed}',
      GenerationTransferSetting.steps => '${configuration.steps}',
      GenerationTransferSetting.scale => _formatNumber(configuration.scale!),
      GenerationTransferSetting.cfgRescale => _formatNumber(
        configuration.cfgRescale!,
      ),
      GenerationTransferSetting.noiseSchedule =>
        NoiseSchedules.displayNames[configuration.noiseSchedule] ??
            configuration.noiseSchedule!,
      GenerationTransferSetting.smea =>
        configuration.smea!
            ? context.l10n.common_enabled
            : context.l10n.common_disabled,
      GenerationTransferSetting.smeaDyn =>
        configuration.smeaDyn!
            ? context.l10n.common_enabled
            : context.l10n.common_disabled,
    };
  }

  IconData _icon(GenerationTransferSetting setting) => switch (setting) {
    GenerationTransferSetting.model => Icons.memory_outlined,
    GenerationTransferSetting.size => Icons.aspect_ratio_outlined,
    GenerationTransferSetting.sampler => Icons.timeline_outlined,
    GenerationTransferSetting.seed => Icons.casino_outlined,
    GenerationTransferSetting.steps => Icons.stairs_outlined,
    GenerationTransferSetting.scale => Icons.tune_outlined,
    GenerationTransferSetting.cfgRescale => Icons.balance_outlined,
    GenerationTransferSetting.noiseSchedule => Icons.multiline_chart_outlined,
    GenerationTransferSetting.smea => Icons.hd_outlined,
    GenerationTransferSetting.smeaDyn => Icons.auto_fix_high_outlined,
  };

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

  String _labelBeforeColon(String value) =>
      value.replaceFirst(RegExp(r'[:：]\s*$'), '').trim();
}
