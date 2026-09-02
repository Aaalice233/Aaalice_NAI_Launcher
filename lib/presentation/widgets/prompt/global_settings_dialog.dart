import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../common/themed_checkbox.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/window_size_class.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
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
  const GlobalSettingsDialog({super.key, this.scrollController});

  final ScrollController? scrollController;

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: (context) => Text(
        context.l10n.characterCountConfig_title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      sideSheetWidth: 720,
      builder: (context, scrollController) =>
          GlobalSettingsDialog(scrollController: scrollController),
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
    _config = algorithmConfig.effectiveCharacterCountConfig;

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

    final updatedAlgorithmConfig = preset.algorithmConfig.copyWith(
      characterCountConfig: _config,
    );
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

  void _updateTagOptionWeight(String categoryId, String optionId, int weight) {
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
          final tagOptions = c.tagOptions
              .where((t) => t.id != optionId)
              .toList();
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

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.all(
                context.adaptiveWindow.isCompact ? 12 : 16,
              ),
              children: [
                _buildHeader(theme, l10n),
                const SizedBox(height: 8),
                ..._config.categories.map(
                  (category) => _buildCategoryCard(category, theme, l10n),
                ),
              ],
            ),
          ),
          const ThemedDivider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight * 0.45,
            ),
            child: SingleChildScrollView(child: _buildFooter(theme, l10n)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _showCustomSlotsDialog(theme, l10n),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: Text(l10n.characterCountConfig_customSlots),
          ),
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
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(onPressed: _saveChanges, child: Text(l10n.common_save)),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    CharacterCountCategory category,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final isExpanded = _expandedCategories[category.id] ?? false;
    final stacked =
        context.adaptiveWindow.isCompact ||
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;

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
              child: Flex(
                direction: stacked ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: stacked
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                children: [
                  if (stacked)
                    _CategoryTitle(
                      category: category,
                      expanded: isExpanded,
                      label: _getCategoryDisplayName(category, l10n),
                      customizableLabel: l10n.characterCountConfig_customizable,
                    )
                  else
                    Expanded(
                      child: _CategoryTitle(
                        category: category,
                        expanded: isExpanded,
                        label: _getCategoryDisplayName(category, l10n),
                        customizableLabel:
                            l10n.characterCountConfig_customizable,
                      ),
                    ),
                  if (stacked) const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.characterCountConfig_weight,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: ThemedFormInput(
                          initialValue: '${category.weight}',
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            suffixText: '%',
                          ),
                          onChanged: (value) {
                            final weight =
                                int.tryParse(value) ?? category.weight;
                            _updateCategoryWeight(category.id, weight);
                          },
                        ),
                      ),
                    ],
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
    AppLocalizations l10n,
  ) {
    // 构建角色提示词文本（如 "girl" 或 "girl + girl"）
    String? characterPromptText;
    if (option.slotTags.isNotEmpty) {
      characterPromptText = option.slotTags
          .map((slot) => slot.characterTag)
          .join(' + ');
    }

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: option.enabled
                ? null
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        Text(
          characterPromptText != null
              ? '${l10n.characterCountConfig_mainPrompt}: ${option.mainPromptTags} | ${l10n.characterCountConfig_characterPrompt}: $characterPromptText'
              : '${l10n.characterCountConfig_mainPrompt}: ${option.mainPromptTags}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final weightField = SizedBox(
      width: 76,
      child: ThemedFormInput(
        initialValue: '${option.weight}',
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(isDense: true, suffixText: '%'),
        onChanged: (value) {
          final weight = int.tryParse(value) ?? option.weight;
          _updateTagOptionWeight(categoryId, option.id, weight);
        },
      ),
    );
    final deleteButton = option.isCustom
        ? IconButton(
            tooltip: l10n.common_delete,
            icon: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.error,
              size: 20,
            ),
            onPressed: () => _removeTagOption(categoryId, option.id),
          )
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: option.enabled
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 420 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          final checkbox = ThemedCheckbox(
            value: option.enabled,
            onChanged: (_) => _toggleTagOptionEnabled(categoryId, option.id),
            size: 18,
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    checkbox,
                    const SizedBox(width: 8),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    weightField,
                    if (deleteButton != null) deleteButton,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              checkbox,
              const SizedBox(width: 8),
              Expanded(child: details),
              weightField,
              if (deleteButton != null) deleteButton,
            ],
          );
        },
      ),
    );
  }

  String _getCategoryDisplayName(
    CharacterCountCategory category,
    AppLocalizations l10n,
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
    AppLocalizations l10n,
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
      await AdaptivePresenter.showForm<void>(
        context: context,
        title: category.isMultiPersonContainer
            ? l10n.characterCountConfig_addMultiPersonCombo
            : l10n.characterCountConfig_addTagOption,
        sideSheetWidth: 480,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
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
                                    slotTags = List.filled(
                                      slotCount,
                                      defaultSlotTag,
                                    );
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
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final stacked =
                                  constraints.maxWidth < 360 ||
                                  MediaQuery.textScalerOf(context).scale(1) >=
                                      2;
                              final dropdown = DropdownButtonFormField<String>(
                                initialValue: slotTags[i],
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
                              );
                              final label = Text(
                                '${l10n.characterCountConfig_slot} ${i + 1}:',
                              );
                              if (stacked) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    label,
                                    const SizedBox(height: 4),
                                    dropdown,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  label,
                                  const SizedBox(width: 12),
                                  Expanded(child: dropdown),
                                ],
                              );
                            },
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
                const ThemedDivider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
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
                  ),
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
  Future<void> _showCustomSlotsDialog(
    ThemeData theme,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController();
    const builtinSlots = defaultSlotOptions;

    try {
      await AdaptivePresenter.showForm<void>(
        context: context,
        title: l10n.characterCountConfig_customSlotsTitle,
        sideSheetWidth: 480,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
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
                      ..._config.customSlotOptions.map((slot) {
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
                      }),
                    ],
                  ),
                ),
                const ThemedDivider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.common_confirm),
                    ),
                  ),
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

class _CategoryTitle extends StatelessWidget {
  const _CategoryTitle({
    required this.category,
    required this.expanded,
    required this.label,
    required this.customizableLabel,
  });

  final CharacterCountCategory category;
  final bool expanded;
  final String label;
  final String customizableLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (category.isMultiPersonContainer)
          Flexible(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(
                customizableLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
