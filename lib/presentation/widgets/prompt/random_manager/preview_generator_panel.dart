import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/character/character_prompt.dart';
import '../../../../data/models/prompt/random_prompt_result.dart';
import '../../../../data/services/random_prompt_generator.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../common/app_toast.dart';

class PreviewGeneratorController {
  VoidCallback? _generateAction;
  bool _disposed = false;

  void generate() {
    if (!_disposed) _generateAction?.call();
  }

  void _attach(VoidCallback action) {
    if (!_disposed) _generateAction = action;
  }

  void _detach(VoidCallback action) {
    if (identical(_generateAction, action)) _generateAction = null;
  }

  void dispose() {
    _disposed = true;
    _generateAction = null;
  }
}

class PreviewGeneratorPanel extends ConsumerStatefulWidget {
  const PreviewGeneratorPanel({
    super.key,
    this.controller,
    this.inline = false,
  });

  final PreviewGeneratorController? controller;

  /// Compact workspaces share the page scroll view instead of nesting another
  /// vertical viewport inside it.
  final bool inline;

  @override
  ConsumerState<PreviewGeneratorPanel> createState() =>
      _PreviewGeneratorPanelState();
}

class _PreviewGeneratorPanelState extends ConsumerState<PreviewGeneratorPanel> {
  RandomPromptResult? _result;
  bool _isGenerating = false;
  String? _error;
  int _generationRevision = 0;
  late final VoidCallback _generateCallback;

  @override
  void initState() {
    super.initState();
    _generateCallback = _generate;
    widget.controller?._attach(_generateCallback);
  }

  @override
  void didUpdateWidget(covariant PreviewGeneratorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller?._detach(_generateCallback);
    widget.controller?._attach(_generateCallback);
  }

  @override
  void dispose() {
    widget.controller?._detach(_generateCallback);
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
    final sections = <String>[
      context.l10n.characterCountConfig_mainPrompt,
      result.mainPrompt,
    ];
    for (var index = 0; index < result.characters.length; index++) {
      final character = result.characters[index];
      sections.addAll([
        context.l10n.character_number(index + 1),
        context.l10n.prompt_positive,
        character.prompt,
      ]);
      if (character.negativePrompt.trim().isNotEmpty) {
        sections.addAll([
          context.l10n.prompt_negative,
          character.negativePrompt,
        ]);
      }
    }
    await Clipboard.setData(ClipboardData(text: sections.join('\n')));
    if (mounted) {
      AppToast.success(context, context.l10n.randomManager_copiedToClipboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      randomPresetNotifierProvider.select((state) => state.selectedPresetId),
      (previous, next) {
        if (previous == null || previous == next || !mounted) return;
        _generationRevision++;
        setState(() {
          _result = null;
          _error = null;
          _isGenerating = false;
        });
      },
    );

    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('random-manager-preview-panel'),
      decoration: BoxDecoration(
        color: sectionSurfaceColor(colors),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(widget.inline ? 12 : 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final compact =
                widget.inline || constraints.maxWidth < 360 || textScale > 1.5;
            if (!widget.inline && compact) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(context, compact: true),
                  const SizedBox(height: 12),
                  _buildBody(context, compact: true, scrollable: false),
                ],
              );
            }
            return Column(
              mainAxisSize: widget.inline ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, compact: compact),
                const SizedBox(height: 12),
                if (widget.inline)
                  _buildBody(context, compact: true, scrollable: false)
                else
                  Expanded(
                    child: _buildBody(
                      context,
                      compact: compact,
                      scrollable: true,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.shuffle_rounded, size: 18, color: colors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.randomManager_previewGeneration,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.randomManager_previewEmptyDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final generateButton = FilledButton.icon(
      key: const ValueKey('random-manager-generate-sample'),
      onPressed: _isGenerating ? null : _generate,
      icon: _isGenerating
          ? SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
              ),
            )
          : Icon(
              _result == null
                  ? Icons.play_arrow_rounded
                  : Icons.refresh_rounded,
              size: 18,
            ),
      label: Text(
        _isGenerating
            ? context.l10n.randomManager_generating
            : _result == null
            ? context.l10n.randomManager_generate
            : context.l10n.randomManager_regenerate,
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [heading, const SizedBox(height: 10), generateButton],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: heading),
        const SizedBox(width: 12),
        generateButton,
      ],
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool compact,
    required bool scrollable,
  }) {
    final colors = Theme.of(context).colorScheme;
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
        foreground: colors.onSurfaceVariant,
      );
    }

    final blocks = <Widget>[
      _PromptOutputBlock(
        key: const ValueKey('random-preview-main-prompt'),
        icon: Icons.public_rounded,
        title: context.l10n.characterCountConfig_mainPrompt,
        accent: colors.primary,
        positivePrompt: result.mainPrompt,
      ),
      for (var index = 0; index < result.characters.length; index++) ...[
        const SizedBox(height: 8),
        _PromptOutputBlock(
          key: ValueKey('random-preview-character-$index'),
          icon: Icons.person_outline_rounded,
          title: context.l10n.character_number(index + 1),
          badge: _genderLabel(context, result.characters[index].gender),
          accent: colors.tertiary,
          positivePrompt: result.characters[index].prompt,
          negativePrompt: result.characters[index].negativePrompt,
        ),
      ],
    ];
    final output = scrollable
        ? ListView(padding: EdgeInsets.zero, children: blocks)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: blocks,
          );

    return Column(
      mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummary(context, result: result, compact: compact),
        const SizedBox(height: 10),
        if (scrollable) Expanded(child: output) else output,
      ],
    );
  }

  Widget _buildSummary(
    BuildContext context, {
    required RandomPromptResult result,
    required bool compact,
  }) {
    final stats = Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        _InlineStat(
          icon: Icons.person_outline_rounded,
          label: context.l10n.randomManager_characterCountLabel(
            result.characterCount,
          ),
        ),
        _InlineStat(
          icon: Icons.sell_outlined,
          label: context.l10n.randomManager_tagCountLabel(
            _countResultTags(result),
          ),
        ),
        _InlineStat(
          icon: result.mode.icon,
          label: result.mode.getName(context.l10n),
        ),
        if (result.seed != null)
          _InlineStat(
            icon: Icons.tag_rounded,
            label: '${context.l10n.generation_seed} ${result.seed}',
          ),
      ],
    );
    final copy = TextButton.icon(
      onPressed: _copyToClipboard,
      icon: const Icon(Icons.copy_outlined, size: 17),
      label: Text(context.l10n.randomManager_copy),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          stats,
          Align(alignment: Alignment.centerRight, child: copy),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: stats),
        const SizedBox(width: 8),
        copy,
      ],
    );
  }
}

class _PromptOutputBlock extends StatelessWidget {
  const _PromptOutputBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    required this.positivePrompt,
    this.badge,
    this.negativePrompt,
  });

  final IconData icon;
  final String title;
  final String? badge;
  final Color accent;
  final String positivePrompt;
  final String? negativePrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final negative = negativePrompt?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: controlSurfaceColor(colors),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    badge!,
                    style: theme.textTheme.labelSmall?.copyWith(color: accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          _PromptText(
            label: badge == null ? null : context.l10n.prompt_positive,
            text: positivePrompt,
            color: accent,
          ),
          if (negative.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PromptText(
              label: context.l10n.prompt_negative,
              text: negative,
              color: colors.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _PromptText extends StatelessWidget {
  const _PromptText({
    required this.label,
    required this.text,
    required this.color,
  });

  final String? label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                label!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        SelectableText(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.icon,
    required this.title,
    required this.foreground,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color foreground;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: foreground),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 5),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 10), action!],
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

String _genderLabel(BuildContext context, CharacterGender gender) =>
    switch (gender) {
      CharacterGender.female => context.l10n.characterEditor_genderFemale,
      CharacterGender.male => context.l10n.characterEditor_genderMale,
      CharacterGender.other => context.l10n.characterEditor_genderOther,
    };

int _countResultTags(RandomPromptResult result) {
  var count = _countTags(result.mainPrompt);
  for (final character in result.characters) {
    count += _countTags(character.prompt);
    count += _countTags(character.negativePrompt);
  }
  return count;
}

int _countTags(String prompt) =>
    prompt.split(',').where((tag) => tag.trim().isNotEmpty).length;
