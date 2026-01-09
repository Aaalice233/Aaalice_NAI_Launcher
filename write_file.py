import sys

content = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/algorithm_config.dart';
import '../../../data/models/prompt/character_count_config.dart';
import '../../providers/random_preset_provider.dart';

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
    final algorithmConfig =
        preset?.algorithmConfig ?? const AlgorithmConfig();
    _config = algorithmConfig.characterCountConfig ??
        CharacterCountConfig.naiDefault;

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
            const Divider(height: 1),
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
            const Divider(height: 1),
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
            
