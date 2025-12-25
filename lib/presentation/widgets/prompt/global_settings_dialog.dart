import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/algorithm_config.dart';
import '../../providers/random_preset_provider.dart';

/// 总览设置对话框
///
/// 显示全局算法参数配置：
/// - 角色数量权重分布
/// - 权重随机偏移设置
/// - 所有类别概率总览
class GlobalSettingsDialog extends ConsumerStatefulWidget {
  const GlobalSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const GlobalSettingsDialog(),
    );
  }

  @override
  ConsumerState<GlobalSettingsDialog> createState() =>
      _GlobalSettingsDialogState();
}

class _GlobalSettingsDialogState extends ConsumerState<GlobalSettingsDialog> {
  late AlgorithmConfig _config;
  late CategoryProbabilityConfig _probConfig;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(randomPresetNotifierProvider);
    // 检查加载状态
    if (state.isLoading) {
      _config = const AlgorithmConfig();
      _probConfig = const CategoryProbabilityConfig();
    } else {
      final preset = state.selectedPreset;
      _config = preset?.algorithmConfig ?? const AlgorithmConfig();
      _probConfig =
          preset?.categoryProbabilities ?? const CategoryProbabilityConfig();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.settings, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(context.l10n.globalSettings_title, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetToDefault,
                    child: Text(context.l10n.globalSettings_resetToDefault),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 角色数量分布
                    _buildSectionTitle(context.l10n.globalSettings_characterCountDistribution, theme),
                    const SizedBox(height: 8),
                    _CharacterCountWeightEditor(
                      config: _config,
                      onChanged: (newConfig) {
                        setState(() {
                          _config = newConfig;
                          _hasChanges = true;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // 权重随机偏移
                    _buildSectionTitle(context.l10n.globalSettings_weightRandomOffset, theme),
                    const SizedBox(height: 8),
                    _BracketRandomizationEditor(
                      config: _config,
                      onChanged: (newConfig) {
                        setState(() {
                          _config = newConfig;
                          _hasChanges = true;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // 类别概率总览
                    _buildSectionTitle(context.l10n.globalSettings_categoryProbabilityOverview, theme),
                    const SizedBox(height: 8),
                    _CategoryProbabilityOverview(
                      config: _probConfig,
                      onChanged: (newConfig) {
                        setState(() {
                          _probConfig = newConfig;
                          _hasChanges = true;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.globalSettings_cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _hasChanges && !_isSaving ? _saveChanges : null,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.globalSettings_save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _resetToDefault() {
    setState(() {
      _config = const AlgorithmConfig();
      _probConfig = const CategoryProbabilityConfig();
      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(randomPresetNotifierProvider.notifier);
      await notifier.updateAlgorithmConfig(_config);
      await notifier.updateCategoryProbabilities(_probConfig);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.globalSettings_saveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

/// 角色数量权重编辑器
class _CharacterCountWeightEditor extends StatelessWidget {
  final AlgorithmConfig config;
  final ValueChanged<AlgorithmConfig> onChanged;

  const _CharacterCountWeightEditor({
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final weight in config.characterCountWeights)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildWeightRow(
                  context,
                  weight[0],
                  weight[1],
                  theme,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightRow(
    BuildContext context,
    int count,
    int weight,
    ThemeData theme,
  ) {
    final l10n = context.l10n;
    final label = count == 0
        ? l10n.globalSettings_noCharacter
        : l10n.globalSettings_characterCount(count);

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: weight.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '$weight%',
            onChanged: (value) {
              final newConfig =
                  config.updateWeightForCount(count, value.round());
              onChanged(newConfig);
            },
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '$weight%',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// 权重随机偏移编辑器
class _BracketRandomizationEditor extends StatelessWidget {
  final AlgorithmConfig config;
  final ValueChanged<AlgorithmConfig> onChanged;

  const _BracketRandomizationEditor({
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 启用开关
            SwitchListTile(
              title: Text(l10n.globalSettings_enableWeightRandomOffset),
              subtitle: Text(l10n.globalSettings_enableWeightRandomOffsetDesc),
              value: config.bracketRandomizationEnabled,
              onChanged: (value) {
                onChanged(config.copyWith(bracketRandomizationEnabled: value));
              },
            ),

            if (config.bracketRandomizationEnabled) ...[
              const Divider(),

              // 括号类型
              ListTile(
                title: Text(l10n.globalSettings_bracketType),
                trailing: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(l10n.globalSettings_bracketEnhance)),
                    ButtonSegment(value: false, label: Text(l10n.globalSettings_bracketWeaken)),
                  ],
                  selected: {config.bracketEnhance},
                  onSelectionChanged: (values) {
                    onChanged(config.copyWith(bracketEnhance: values.first));
                  },
                ),
              ),

              // 层数范围
              ListTile(
                title: Text(l10n.globalSettings_layerRange),
                subtitle: Text(
                  l10n.globalSettings_layerRangeValue(
                    config.bracketRandomizationMin,
                    config.bracketRandomizationMax,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RangeSlider(
                  values: RangeValues(
                    config.bracketRandomizationMin.toDouble(),
                    config.bracketRandomizationMax.toDouble(),
                  ),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  labels: RangeLabels(
                    '${config.bracketRandomizationMin}',
                    '${config.bracketRandomizationMax}',
                  ),
                  onChanged: (values) {
                    onChanged(
                      config.copyWith(
                        bracketRandomizationMin: values.start.round(),
                        bracketRandomizationMax: values.end.round(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 类别概率总览
class _CategoryProbabilityOverview extends StatelessWidget {
  final CategoryProbabilityConfig config;
  final ValueChanged<CategoryProbabilityConfig> onChanged;

  const _CategoryProbabilityOverview({
    required this.config,
    required this.onChanged,
  });

  static const _categoryKeys = [
    'hairColor',
    'eyeColor',
    'hairStyle',
    'expression',
    'pose',
    'clothing',
    'accessory',
    'bodyFeature',
    'background',
    'scene',
    'style',
  ];

  String _getCategoryLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'hairColor' => l10n.globalSettings_category_hairColor,
      'eyeColor' => l10n.globalSettings_category_eyeColor,
      'hairStyle' => l10n.globalSettings_category_hairStyle,
      'expression' => l10n.globalSettings_category_expression,
      'pose' => l10n.globalSettings_category_pose,
      'clothing' => l10n.globalSettings_category_clothing,
      'accessory' => l10n.globalSettings_category_accessory,
      'bodyFeature' => l10n.globalSettings_category_bodyFeature,
      'background' => l10n.globalSettings_category_background,
      'scene' => l10n.globalSettings_category_scene,
      'style' => l10n.globalSettings_category_style,
      _ => key,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final key in _categoryKeys)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        _getCategoryLabel(context, key),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: config.getProbability(key),
                        min: 0,
                        max: 1,
                        divisions: 20,
                        label: '${(config.getProbability(key) * 100).round()}%',
                        onChanged: (value) {
                          onChanged(config.updateProbability(key, value));
                        },
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${(config.getProbability(key) * 100).round()}%',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
