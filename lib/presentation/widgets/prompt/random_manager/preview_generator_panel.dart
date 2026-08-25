import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/prompt/random_prompt_result.dart';
import '../../../../data/services/random_prompt_generator.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/random_preset_provider.dart';
import '../../common/elevated_card.dart';
import '../../common/app_toast.dart';

/// 预览生成面板组件
///
/// 用于快速预览随机标签生成结果
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
      final generator = ref.read(randomPromptGeneratorProvider);
      final presetState = ref.read(randomPresetNotifierProvider);
      final preset = presetState.selectedPreset;

      if (preset == null) {
        throw Exception(context.l10n.randomManager_selectPresetRequired);
      }

      final result = await generator.generateFromPreset(preset: preset);
      final selectedPresetId = ref
          .read(randomPresetNotifierProvider)
          .selectedPresetId;

      if (mounted && revision == _generationRevision) {
        setState(() {
          if (selectedPresetId == preset.id) _result = result;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted && revision == _generationRevision) {
        setState(() {
          _error = e.toString();
          _isGenerating = false;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_result == null) return;
    Clipboard.setData(ClipboardData(text: _result!.mergedPrompt));
    AppToast.success(context, context.l10n.randomManager_copiedToClipboard);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level2,
      borderRadius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shuffle_rounded,
                  size: 18,
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.randomManager_previewGeneration,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // 生成按钮
              _GenerateButton(
                onPressed: _generate,
                isGenerating: _isGenerating,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 结果区域
          Expanded(child: _buildResultArea(context)),
        ],
      ),
    );
  }

  Widget _buildResultArea(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_error != null) {
      return _ErrorDisplay(error: _error!);
    }

    if (_result == null) {
      return _EmptyState(onGenerate: _generate);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 生成的 Prompt
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: SelectableText(
              _result!.mergedPrompt,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 统计信息 + 操作按钮
        Row(
          children: [
            // 角色数量
            _StatChip(
              icon: Icons.person_outline,
              label: context.l10n.randomManager_characterCountLabel(
                _result!.characterCount,
              ),
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            // 标签数量 (估算：按逗号分隔)
            _StatChip(
              icon: Icons.tag,
              label: context.l10n.randomManager_tagCountLabel(
                _result!.mergedPrompt.split(',').length,
              ),
              color: colorScheme.secondary,
            ),
            const Spacer(),
            // 复制按钮
            IconButton(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy_outlined),
              iconSize: 18,
              tooltip: context.l10n.randomManager_copy,
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 重新生成按钮
            IconButton(
              onPressed: _isGenerating ? null : _generate,
              icon: const Icon(Icons.refresh),
              iconSize: 18,
              tooltip: context.l10n.randomManager_regenerate,
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.secondaryContainer.withValues(
                  alpha: 0.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 生成按钮组件
class _GenerateButton extends StatefulWidget {
  const _GenerateButton({required this.onPressed, required this.isGenerating});

  final VoidCallback onPressed;
  final bool isGenerating;

  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: widget.isGenerating ? null : widget.onPressed,
      icon: widget.isGenerating
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow_rounded, size: 18),
      label: Text(
        widget.isGenerating
            ? context.l10n.randomManager_generating
            : context.l10n.randomManager_generate,
      ),
    );
  }
}

/// 空状态提示
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGenerate});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_outlined,
              size: 32,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.randomManager_previewHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onGenerate,
            icon: const Icon(Icons.shuffle, size: 16),
            label: Text(context.l10n.randomManager_generateNow),
          ),
        ],
      ),
    );
  }
}

/// 错误显示
class _ErrorDisplay extends StatelessWidget {
  const _ErrorDisplay({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 32, color: colorScheme.error),
            const SizedBox(height: 8),
            Text(
              context.l10n.randomManager_generationFailed,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 统计信息标签
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
