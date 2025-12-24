import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  Text('总览设置', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetToDefault,
                    child: const Text('重置为默认'),
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
                    _buildSectionTitle('角色数量分布', theme),
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
                    _buildSectionTitle('权重随机偏移', theme),
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
                    _buildSectionTitle('类别概率总览', theme),
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
                    child: const Text('取消'),
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
                        : const Text('保存'),
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
          SnackBar(content: Text('保存失败: $e')),
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
    final label = count == 0 ? '无人' : '$count人';

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 启用开关
            SwitchListTile(
              title: const Text('启用权重随机偏移'),
              subtitle: const Text('生成时随机添加括号模拟人类微调'),
              value: config.bracketRandomizationEnabled,
              onChanged: (value) {
                onChanged(config.copyWith(bracketRandomizationEnabled: value));
              },
            ),

            if (config.bracketRandomizationEnabled) ...[
              const Divider(),

              // 括号类型
              ListTile(
                title: const Text('括号类型'),
                trailing: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('{} 增强')),
                    ButtonSegment(value: false, label: Text('[] 减弱')),
                  ],
                  selected: {config.bracketEnhance},
                  onSelectionChanged: (values) {
                    onChanged(config.copyWith(bracketEnhance: values.first));
                  },
                ),
              ),

              // 层数范围
              ListTile(
                title: const Text('层数范围'),
                subtitle: Text(
                  '${config.bracketRandomizationMin} - ${config.bracketRandomizationMax} 层',
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

  static const _categories = [
    ('hairColor', '发色'),
    ('eyeColor', '瞳色'),
    ('hairStyle', '发型'),
    ('expression', '表情'),
    ('pose', '姿势'),
    ('clothing', '服装'),
    ('accessory', '配饰'),
    ('bodyFeature', '身体特征'),
    ('background', '背景'),
    ('scene', '场景'),
    ('style', '风格'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final (key, label) in _categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(label, style: theme.textTheme.bodyMedium),
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
