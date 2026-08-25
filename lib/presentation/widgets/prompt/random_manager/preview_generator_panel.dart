import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_prompt_result.dart';
import '../../../../data/services/random_prompt_generator.dart';
import '../../../providers/random_preset_provider.dart';
import '../../common/app_toast.dart';

class PreviewGeneratorPanel extends ConsumerStatefulWidget {
  const PreviewGeneratorPanel({super.key});

  @override
  ConsumerState<PreviewGeneratorPanel> createState() =>
      _PreviewGeneratorPanelState();
}

class _PreviewGeneratorPanelState extends ConsumerState<PreviewGeneratorPanel> {
  RandomPromptResult? _result;
  bool _isGenerating = false;
  String? _error;
  int _generationRevision = 0;

  @override
  void dispose() {
    _generationRevision++;
    super.dispose();
  }

  Future<void> _generate() async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    final revision = ++_generationRevision;

    try {
      final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
      if (preset == null) {
        throw StateError(context.l10n.randomManager_selectPresetRequired);
      }
      final result = await ref
          .read(randomPromptGeneratorProvider)
          .generateFromPreset(preset: preset);
      final selectedId = ref
          .read(randomPresetNotifierProvider)
          .selectedPresetId;
      if (!mounted || revision != _generationRevision) return;
      setState(() {
        if (selectedId == preset.id) _result = result;
        _isGenerating = false;
      });
    } catch (error) {
      if (!mounted || revision != _generationRevision) return;
      setState(() {
        _error = error.toString();
        _isGenerating = false;
      });
    }
  }

  Future<void> _copyToClipboard() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.mergedPrompt));
    if (mounted) {
      AppToast.success(context, context.l10n.randomManager_copiedToClipboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shuffle_rounded, size: 19, color: colors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.l10n.randomManager_previewGeneration,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isGenerating ? null : _generate,
                  icon: _isGenerating
                      ? const SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    _isGenerating
                        ? context.l10n.randomManager_generating
                        : context.l10n.randomManager_generate,
                  ),
                ),
                const SizedBox(width: 32),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResult(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (_error != null) {
      return _PreviewMessage(
        icon: Icons.error_outline_rounded,
        title: context.l10n.randomManager_generationFailed,
        message: _error!,
        foreground: colors.error,
        action: TextButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(context.l10n.common_retry),
        ),
      );
    }
    final result = _result;
    if (result == null) {
      return _PreviewMessage(
        icon: Icons.notes_rounded,
        title: context.l10n.randomManager_previewHint,
        message: context.l10n.randomManager_previewEmptyDescription,
        foreground: colors.onSurfaceVariant,
        action: TextButton.icon(
          onPressed: _generate,
          icon: const Icon(Icons.shuffle_rounded),
          label: Text(context.l10n.randomManager_generateNow),
        ),
      );
    }

    final tagCount = result.mergedPrompt
        .split(',')
        .where((tag) => tag.trim().isNotEmpty)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                result.mergedPrompt,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.55,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _InlineStat(
              icon: Icons.person_outline_rounded,
              label: context.l10n.randomManager_characterCountLabel(
                result.characterCount,
              ),
            ),
            const SizedBox(width: 10),
            _InlineStat(
              icon: Icons.sell_outlined,
              label: context.l10n.randomManager_tagCountLabel(tagCount),
            ),
            const Spacer(),
            IconButton(
              onPressed: _copyToClipboard,
              tooltip: context.l10n.randomManager_copy,
              icon: const Icon(Icons.copy_outlined, size: 18),
            ),
            IconButton(
              onPressed: _isGenerating ? null : _generate,
              tooltip: context.l10n.randomManager_regenerate,
              icon: const Icon(Icons.refresh_rounded, size: 19),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.foreground,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color foreground;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: foreground),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            action,
          ],
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
