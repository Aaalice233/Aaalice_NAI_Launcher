import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../common/themed_checkbox.dart';
import '../../../data/models/prompt/algorithm_config.dart';
import '../../../data/models/prompt/character_count_config.dart';
import '../../providers/random_preset_provider.dart';
import '../../widgets/common/themed_divider.dart';
import '../../widgets/common/app_toast.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 人数类别配置对话框
///
/// 用于配置单人、双人、三人、多人、无人等类别的权重和标签选项
class GlobalSettingsDialog extends ConsumerStatefulWidget {
  const GlobalSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const GlobalSettingsDialog(),
    );
  }

  @override
  ConsumerState<GlobalSettingsDialog> createState() =>
      _GlobalSettingsDialogState();
}

class _GlobalSettingsDialogState extends ConsumerState<GlobalSettingsDialog> {
  late CharacterCountConfig _config;
  final Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    final algorithmConfig = preset?.algorithmConfig ?? const AlgorithmConfig();
    _config =
        algorithmConfig.characterCountConfig ?? CharacterCountConfig.naiDefault;

    // 默认折叠所有类别
    for (final category in _config.categories) {
      _expandedCategories[category.id] = false;
    }
  }

  void _resetToDefault() {
    setState(() {
      _config = CharacterCountConfig.naiDefault;
      for (final category in _config.categories) {
        _expandedCategories[category.id] = false;
      }
    });
  }

  Future<void> _saveChanges() async {
    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    if (preset == null) return;

    final updatedAlgorithmConfig =
        preset.algorithmConfig.copyWith(characterCountConfig: _config);
    await ref
        .read(randomPresetNotifierProvider.notifier)
        .updateAlgorithmConfig(updatedAlgorithmConfig);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _updateCategoryWeight(String categoryId, int weight) {
    setState(() {
      final categories = _config.categories.map((c) {
        if (c.id == categoryId) {
          return c.copyWith(weight: weight.clamp(0, 100));
        }
        return c;
      }).toList();
      _config = _config.copyWith(categories: categories);
    });
  }

  void _toggleTagOptionEnabled(String categoryId, String optionId) {
    setState(() {
      final categories = _config.categories.map((c) {
        if (c.id == categoryId) {
          final tagOptions = c.tagOptions.map((t) {
            if (t.id == optionId) {
              return t.copyWith(enabled: !t.enabled);
            }
            return t;
          }).toList();
          return c.copyWith(tagOptions: tagOptions);
        }
        return c;
      }).toList();
      _config = _config.copyWith(categories: categories);
    });
  }

  void _updateTagOptionWeight(
    String categoryId,
    String optionId,
    int weight,
  ) {
    setState(() {
      final categories = _config.categories.map((c) {
        if (c.id == categoryId) {
          final tagOptions = c.tagOptions.map((t) {
            if (t.id == optionId) {
              return t.copyWith(weight: weight.clamp(1, 100));
            }
            return t;
          }).toList();
          return c.copyWith(tagOptions: tagOptions);
        }
        return c;
      }).toList();
      _config = _config.copyWith(categories: categories);
    });
  }

  void _addTagOption(String categoryId, CharacterTagOption option) {
    setState(() {
      final categories = _config.categories.map((c) {
        if (c.id == categoryId) {
          return c.copyWith(tagOptions: [...c.tagOptions, option]);
        }
        return c;
      }).toList();
      _config = _config.copyWith(categories: categories);
    });
  }

  void _removeTagOption(String categoryId, String optionId) {
    setState(() {
      final categories = _config.categories.map((c) {
        if (c.id == categoryId) {
          final tagOptions =
              c.tagOptions.where((t) => t.id != optionId).toList();
          return c.copyWith(tagOptions: tagOptions);
        }
        return c;
      }).toList();
      _config = _config.copyWith(categories: categories);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(theme, l10n),
            const ThemedDivider(height: 1),
            // 类别列表
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _config.categories.map((category) {
                    return _buildCategoryCard(category, theme, l10n);
                  }).toList(),
                ),
              ),
            ),
            const ThemedDivider(height: 1),
            // 底部按钮
            _buildFooter(theme, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.tune, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            l10n.characterCountConfig_title,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(width: 12),
          // 自定义槽位按钮
          OutlinedButton.icon(
            onPressed: () => _showCustomSlotsDialog(theme, l10n),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: Text(l10n.characterCountConfig_customSlots),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _resetToDefault,
            icon: Icon(
              Icons.restart_alt,
              size: 18,
              color: theme.colorScheme.error,
            ),
            label: Text(
              l10n.preset_resetToDefault,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.common_cancel),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _saveChanges,
            child: Text(l10n.common_save),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    CharacterCountCategory category,
    ThemeData theme,
    dynamic l10n,
  ) {
    final isExpanded = _expandedCategories[category.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // 类别标题栏
          InkWell(
            onTap: () {
              setState(() {
                _expandedCategories[category.id] = !isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getCategoryDisplayName(category, l10n),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (category.isMultiPersonContainer)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.characterCountConfig_customizable,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  const Spacer(),
                  // 权重输入
                  Text(
                    l10n.characterCountConfig_weight,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: ThemedFormInput(
                      initialValue: '${category.weight}',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        suffixText: '%',
                      ),
                      onChanged: (value) {
                        final weight = int.tryParse(value) ?? category.weight;
                        _updateCategoryWeight(category.id, weight);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 展开内容
          if (isExpanded) ...[
            const ThemedDivider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标签选项列表
                  ...category.tagOptions.map((option) {
                    return _buildTagOptionTile(
                      category.id,
                      option,
                      theme,
                      l10n,
                    );
                  }),
                  // 添加按钮
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showAddTagOptionDialog(category, theme, l10n),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      category.isMultiPersonContainer
                          ? l10n.characterCountConfig_addMultiPersonCombo
                          : l10n.characterCountConfig_addTagOption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagOptionTile(
    String categoryId,
    CharacterTagOption option,
    ThemeData theme,
    dynamic l10n,
  ) {
    // 构建角色提示词文本（如 "girl" 或 "girl + girl"）
    String? characterPromptText;
    if (option.slotTags.isNotEmpty) {
      characterPromptText =
          option.slotTags.map((slot) => slot.characterTag).join(' + ');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: option.enabled
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: option.enabled
              ? theme.colorScheme.outline.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // 启用复选框
          ThemedCheckbox(
            value: option.enabled,
            onChanged: (_) => _toggleTagOptionEnabled(categoryId, option.id),
            size: 18,
          ),
          // 标签名称和提示词信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: option.enabled
                        ? null
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                // 合并显示主提示词和角色提示词
                Text(
                  characterPromptText != null
                      ? '${l10n.characterCountConfig_mainPrompt}: ${option.mainPromptTags} | ${l10n.characterCountConfig_characterPrompt}: $characterPromptText'
                      : '${l10n.characterCountConfig_mainPrompt}: ${option.mainPromptTags}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 权重输入
          SizedBox(
            width: 70,
            child: ThemedFormInput(
              initialValue: '${option.weight}',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                suffixText: '%',
              ),
              onChanged: (value) {
                final weight = int.tryParse(value) ?? option.weight;
                _updateTagOptionWeight(categoryId, option.id, weight);
              },
            ),
          ),
          // 删除按钮（仅自定义选项）
          if (option.isCustom)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
                size: 20,
              ),
              onPressed: () => _removeTagOption(categoryId, option.id),
            ),
        ],
      ),
    );
  }

  String _getCategoryDisplayName(
    CharacterCountCategory category,
    dynamic l10n,
  ) {
    return switch (category.id) {
      'solo' => l10n.characterCountConfig_solo,
      'duo' => l10n.characterCountConfig_duo,
      'trio' => l10n.characterCountConfig_trio,
      'no_humans' => l10n.characterCountConfig_noHumans,
      'multi_person' => l10n.characterCountConfig_multiPerson,
      _ => category.label,
    };
  }

  Future<void> _showAddTagOptionDialog(
    CharacterCountCategory category,
    ThemeData theme,
    dynamic l10n,
  ) async {
    final labelController = TextEditingController();
    final mainPromptController = TextEditingController();
    final weightController = TextEditingController(text: '50');
    int slotCount = category.isMultiPersonContainer ? 4 : category.count;
    final defaultSlotTag = _config.customSlotOptions.isNotEmpty
        ? _config.customSlotOptions.first
        : 'girl';
    List<String> slotTags = List.filled(slotCount, defaultSlotTag);

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                category.isMultiPersonContainer
                    ? l10n.characterCountConfig_addMultiPersonCombo
                    : l10n.characterCountConfig_addTagOption,
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ThemedInput(
                        controller: labelController,
                        decoration: InputDecoration(
                          labelText: l10n.characterCountConfig_displayName,
                          hintText: l10n.characterCountConfig_displayNameHint,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ThemedInput(
                        controller: mainPromptController,
                        decoration: InputDecoration(
                          labelText: l10n.characterCountConfig_mainPromptLabel,
                          hintText: l10n.characterCountConfig_mainPromptHint,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 多人时显示人数选择
                      if (category.isMultiPersonContainer) ...[
                        Row(
                          children: [
                            Text(l10n.characterCountConfig_personCount),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: slotCount,
                              items: List.generate(7, (i) => i + 4)
                                  .map(
                                    (n) => DropdownMenuItem(
                                      value: n,
                                      child: Text('$n'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    slotCount = value;
                                    slotTags =
                                        List.filled(slotCount, defaultSlotTag);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      // 槽位配置
                      Text(
                        l10n.characterCountConfig_slotConfig,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(slotCount, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(
                                '${l10n.characterCountConfig_slot} ${i + 1}:',
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: slotTags[i],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: _config.customSlotOptions
                                      .map(
                                        (slot) => DropdownMenuItem(
                                          value: slot,
                                          child: Text(slot),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() {
                                        slotTags[i] = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      ThemedInput(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.characterCountConfig_weight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (labelController.text.isEmpty) return;

                    final option = CharacterTagOption(
                      id: const Uuid().v4(),
                      label: labelController.text,
                      mainPromptTags: mainPromptController.text.isNotEmpty
                          ? mainPromptController.text
                          : (category.count == 1 ? 'solo' : ''),
                      slotTags: List.generate(
                        slotCount,
                        (i) => CharacterSlotTag(
                          slotIndex: i,
                          characterTag: slotTags[i],
                        ),
                      ),
                      weight: int.tryParse(weightController.text) ?? 50,
                      isCustom: true,
                    );

                    _addTagOption(category.id, option);
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.common_add),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      labelController.dispose();
      mainPromptController.dispose();
      weightController.dispose();
    }
  }

  /// 显示自定义槽位管理对话框
  Future<void> _showCustomSlotsDialog(ThemeData theme, dynamic l10n) async {
    final controller = TextEditingController();
    const builtinSlots = defaultSlotOptions;

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.characterCountConfig_customSlotsTitle),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.characterCountConfig_customSlotsDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 添加新槽位
                    Row(
                      children: [
                        Expanded(
                          child: ThemedInput(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: l10n.characterCountConfig_addSlotHint,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final value = controller.text.trim();
                            if (value.isEmpty) return;
                            if (_config.customSlotOptions.contains(value)) {
                              AppToast.warning(
                                context,
                                l10n.characterCountConfig_slotExists,
                              );
                              return;
                            }
                            setState(() {
                              _config = _config.copyWith(
                                customSlotOptions: [
                                  ..._config.customSlotOptions,
                                  value,
                                ],
                              );
                            });
                            setDialogState(() {});
                            controller.clear();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 槽位列表
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Column(
                          children: _config.customSlotOptions.map((slot) {
                            final isBuiltin = builtinSlots.contains(slot);
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                isBuiltin ? Icons.lock_outline : Icons.person,
                                size: 20,
                                color: isBuiltin
                                    ? theme.colorScheme.outline
                                    : theme.colorScheme.primary,
                              ),
                              title: Text(slot),
                              trailing: isBuiltin
                                  ? null
                                  : IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: theme.colorScheme.error,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _config = _config.copyWith(
                                            customSlotOptions: _config
                                                .customSlotOptions
                                                .where((s) => s != slot)
                                                .toList(),
                                          );
                                        });
                                        setDialogState(() {});
                                      },
                                    ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_confirm),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}
