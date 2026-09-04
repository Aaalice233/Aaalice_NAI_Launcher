import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/online_gallery/ai_tag_generation_info.dart';
import '../common/app_toast.dart';
import 'gallery_detail_text_section.dart';

class AiTagGenerationInfoSection extends StatelessWidget {
  const AiTagGenerationInfoSection({
    super.key,
    required this.info,
    this.imageTypeLabel,
  });

  final AiTagGenerationInfo info;
  final String? imageTypeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rows = <Widget>[];
    void addRow(String label, String value) {
      if (value.trim().isEmpty) return;
      rows.add(_AiTagInfoRow(label: label, value: value));
    }

    final l10n = context.l10n;
    final hasModel = info.model != null && info.model!.trim().isNotEmpty;
    if (hasModel) addRow(l10n.gallery_metaModel, info.model!.trim());
    if (info.modelHash != null && info.modelHash!.trim().isNotEmpty) {
      addRow('Model Hash', info.modelHash!.trim());
    }
    if (info.vae != null && info.vae!.trim().isNotEmpty) {
      addRow('VAE', info.vae!.trim());
    }
    if (info.clip != null && info.clip!.trim().isNotEmpty) {
      addRow('Text Encoder', info.clip!.trim());
    }

    if (info.loras.isNotEmpty) {
      for (var i = 0; i < info.loras.length; i++) {
        final name = info.loras[i];
        final strength = i < info.loraStrengths.length
            ? info.loraStrengths[i]
            : null;
        final value = strength != null
            ? '$name (${strength.toStringAsFixed(2)})'
            : name;
        addRow(i == 0 ? 'LoRA' : 'LoRA ${i + 1}', value);
      }
    }

    if (info.sampler != null && info.sampler!.trim().isNotEmpty) {
      addRow(l10n.gallery_metaSampler, info.displaySampler);
    } else if (info.scheduler != null && info.scheduler!.trim().isNotEmpty) {
      addRow('Scheduler', info.scheduler!.trim());
    }
    if (info.scheduleType != null && info.scheduleType!.trim().isNotEmpty) {
      // Avoid duplicate if already in displaySampler
      if (info.sampler == null ||
          !info.displaySampler.contains(info.scheduleType!)) {
        addRow('Schedule Type', info.scheduleType!.trim());
      }
    }
    if (info.steps != null) {
      addRow(l10n.gallery_metaSteps, info.steps.toString());
    }
    if (info.cfgScale != null) {
      addRow(l10n.gallery_metaCfgScale, info.cfgScale.toString());
    }
    if (info.cfgRescale != null && info.cfgRescale != 0) {
      addRow('CFG Rescale', info.cfgRescale.toString());
    }
    if (info.shift != null) addRow('Shift', info.shift.toString());
    if (info.denoise != null) addRow('Denoising', info.denoise.toString());
    if (info.seed != null) addRow(l10n.gallery_metaSeed, info.seed.toString());
    if (info.sizeString.isNotEmpty) {
      addRow(l10n.gallery_metaResolution, info.sizeString);
    }
    if (info.smea == true || info.smeaDyn == true) {
      addRow(l10n.gallery_metaSmea, info.smeaDyn == true ? 'DYN' : 'ON');
    }
    if (info.software != null && info.software!.trim().isNotEmpty) {
      addRow('Software', info.software!.trim());
    }

    // Extra (Module 1/2, Version, RNG, etc.)
    for (final e in info.extra.entries) {
      if (e.value.trim().isEmpty) continue;
      final normalizedKey = e.key.trim().toLowerCase().replaceAll(
        RegExp(r'[\s_-]'),
        '',
      );
      if (normalizedKey == 'cfgrescale' && info.cfgRescale != null) continue;
      // Already shown as Model/VAE? UNET already in model, skip duplicate.
      if (e.key == 'UNET' && hasModel) continue;
      addRow(e.key, e.value);
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    final subtitle = imageTypeLabel?.trim().isNotEmpty == true
        ? imageTypeLabel!.trim()
        : info.software?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.memory_rounded, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.gallery_generationParams,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (subtitle.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AiTagInfoRow extends StatelessWidget {
  const _AiTagInfoRow({required this.label, required this.value});

  final String label;
  final String value;
  static const _minSideBySideWidth = 220.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelWidget = Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontSize: 11,
      ),
    );
    final valueWidget = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              AppToast.success(context, context.l10n.common_copied);
            }
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.content_copy_rounded,
              size: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < _minSideBySideWidth ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 2), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 86, child: labelWidget),
            const SizedBox(width: 4),
            Expanded(child: valueWidget),
          ],
        );
      },
    );
  }
}

class AiTagRawJsonSection extends StatefulWidget {
  const AiTagRawJsonSection({super.key, required this.info});

  final AiTagGenerationInfo info;

  @override
  State<AiTagRawJsonSection> createState() => _AiTagRawJsonSectionState();
}

class _AiTagRawJsonSectionState extends State<AiTagRawJsonSection> {
  static const _collapsedLines = 14;
  static const _longContentThreshold = 1200;

  bool _expanded = false;

  @override
  void didUpdateWidget(covariant AiTagRawJsonSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info.rawJson != widget.info.rawJson) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = widget.info.prettyJson.trim().isNotEmpty
        ? widget.info.prettyJson
        : widget.info.rawJson;
    if (display.trim().isEmpty) return const SizedBox.shrink();
    final lineCount = '\n'.allMatches(display).length + 1;
    final isLong =
        lineCount > _collapsedLines || display.length > _longContentThreshold;

    return GalleryDetailTextSection(
      title: 'Raw JSON',
      content: display,
      accentColor: theme.colorScheme.secondary,
      monospace: true,
      maxLines: isLong && !_expanded ? _collapsedLines : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLong) ...[
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                _expanded
                    ? context.l10n.prompt_collapseFull
                    : context.l10n.prompt_expandFull,
                style: theme.textTheme.labelSmall,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Tooltip(
            message: MaterialLocalizations.of(context).copyButtonLabel,
            child: InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: display));
                if (context.mounted) {
                  AppToast.success(context, context.l10n.common_copied);
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: SizedBox.square(
                dimension: 24,
                child: Icon(
                  Icons.content_copy_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
