import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/dependency_config.dart';
import '../../../../widgets/common/elevated_card.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 依赖配置面板
///
/// 用于配置标签选择的依赖关系
/// 采用 Dimensional Layering 设计风格
class DependencyConfigPanel extends StatefulWidget {
  /// 当前配置
  final DependencyConfig? config;

  /// 配置变更回调
  final ValueChanged<DependencyConfig?> onConfigChanged;

  /// 可选的源类别列表
  final List<String> availableCategories;

  /// 是否只读
  final bool readOnly;

  const DependencyConfigPanel({
    super.key,
    this.config,
    required this.onConfigChanged,
    this.availableCategories = const [],
    this.readOnly = false,
  });

  @override
  State<DependencyConfigPanel> createState() => _DependencyConfigPanelState();
}

class _DependencyConfigPanelState extends State<DependencyConfigPanel> {
  late DependencyConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config ?? const DependencyConfig(sourceCategoryId: '');
  }

  @override
  void didUpdateWidget(DependencyConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _config = widget.config ?? const DependencyConfig(sourceCategoryId: '');
    }
  }

  void _updateConfig(DependencyConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
    widget.onConfigChanged(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildTypeSelector(),
        const SizedBox(height: 12),
        _buildSourceCategorySelector(),
        const SizedBox(height: 12),
        _buildMappingRulesEditor(),
        const SizedBox(height: 12),
        _buildDefaultValueField(),
        const SizedBox(height: 12),
        _buildEnabledSwitch(),
      ],
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // 图标容器 - 渐变背景
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.tertiary.withValues(alpha: 0.2),
                colorScheme.tertiary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: colorScheme.tertiary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.link_rounded,
            size: 20,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.diy_dependencyTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                context.l10n.diy_dependencySubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (widget.config != null && !widget.readOnly)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onConfigChanged(null),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.common_clear,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 类型图标和颜色
    final typeIcons = {
      DependencyType.count: Icons.numbers_rounded,
      DependencyType.exists: Icons.check_circle_outline_rounded,
      DependencyType.value: Icons.text_fields_rounded,
      DependencyType.excludes: Icons.block_rounded,
    };

    final typeColors = {
      DependencyType.count: colorScheme.primary,
      DependencyType.exists: colorScheme.secondary,
      DependencyType.value: colorScheme.tertiary,
      DependencyType.excludes: colorScheme.error,
    };

    return ElevatedCard(
      elevation: CardElevation.level1,
      hoverElevation: CardElevation.level2,
      enableHoverEffect: !widget.readOnly,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.category_rounded,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.diy_dependencyType,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 自定义类型选择器
          Row(
            children: DependencyType.values.map((type) {
              final isSelected = _config.type == type;
              final color = typeColors[type]!;
              final icon = typeIcons[type]!;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.readOnly
                          ? null
                          : () => _updateConfig(_config.copyWith(type: type)),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [color, color.withValues(alpha: 0.8)],
                                )
                              : null,
                          color: isSelected
                              ? null
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: isSelected
                                  ? Colors.white
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getDependencyTypeLabel(type),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // 描述
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getDependencyTypeDescription(_config.type),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCategorySelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level1,
      hoverElevation: CardElevation.level2,
      enableHoverEffect: !widget.readOnly,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.source_rounded,
                  size: 14,
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.diy_sourceCategory,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.availableCategories.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _config.sourceCategoryId.isNotEmpty
                  ? _config.sourceCategoryId
                  : null,
              decoration: InputDecoration(
                hintText: context.l10n.diy_selectSourceCategory,
                prefixIcon: Icon(
                  Icons.folder_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
              items: widget.availableCategories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: widget.readOnly
                  ? null
                  : (value) {
                      if (value != null) {
                        _updateConfig(
                          _config.copyWith(sourceCategoryId: value),
                        );
                      }
                    },
            )
          else
            ThemedFormInput(
              initialValue: _config.sourceCategoryId,
              decoration: InputDecoration(
                labelText: context.l10n.diy_sourceCategoryId,
                hintText: context.l10n.diy_enterCategoryId,
                prefixIcon: Icon(
                  Icons.folder_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              readOnly: widget.readOnly,
              onChanged: (value) {
                _updateConfig(_config.copyWith(sourceCategoryId: value));
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMappingRulesEditor() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 14,
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.diy_mappingRules,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!widget.readOnly)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _addMappingRule,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.common_add,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_config.mappingRules.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.rule_rounded,
                      size: 32,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.diy_noMappingRules,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _config.mappingRules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = _config.mappingRules.entries.elementAt(index);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // 源值
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.key,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      // 目标值
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.value,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!widget.readOnly)
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: colorScheme.error.withValues(alpha: 0.7),
                          ),
                          onPressed: () => _removeMappingRule(entry.key),
                          tooltip: context.l10n.diy_deleteRule,
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultValueField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level1,
      hoverElevation: CardElevation.level2,
      enableHoverEffect: !widget.readOnly,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.text_snippet_outlined,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.diy_defaultValue,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ThemedFormInput(
            initialValue: _config.defaultValue ?? '',
            decoration: InputDecoration(
              hintText: context.l10n.diy_defaultValueHint,
              prefixIcon: Icon(
                Icons.edit_note_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ),
            readOnly: widget.readOnly,
            onChanged: (value) {
              _updateConfig(
                _config.copyWith(defaultValue: value.isEmpty ? null : value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnabledSwitch() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            _config.enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 20,
            color: _config.enabled ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.diy_enableDependency,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  context.l10n.diy_enableDependencyHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _config.enabled,
            onChanged: widget.readOnly
                ? null
                : (value) {
                    _updateConfig(_config.copyWith(enabled: value));
                  },
          ),
        ],
      ),
    );
  }

  void _addMappingRule() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        String key = '';
        String value = '';

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_link_rounded, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(context.l10n.diy_addMappingRule),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThemedInput(
                decoration: InputDecoration(
                  labelText: context.l10n.diy_sourceValue,
                  hintText: context.l10n.diy_sourceValueHint,
                  prefixIcon: Icon(
                    Icons.input_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (v) => key = v,
              ),
              const SizedBox(height: 16),
              ThemedInput(
                decoration: InputDecoration(
                  labelText: context.l10n.diy_resultValue,
                  hintText: context.l10n.diy_resultValueHint,
                  prefixIcon: Icon(
                    Icons.output_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (v) => value = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                if (key.isNotEmpty && value.isNotEmpty) {
                  final newRules = Map<String, String>.from(
                    _config.mappingRules,
                  );
                  newRules[key] = value;
                  _updateConfig(_config.copyWith(mappingRules: newRules));
                }
                Navigator.pop(context);
              },
              child: Text(context.l10n.common_add),
            ),
          ],
        );
      },
    );
  }

  void _removeMappingRule(String key) {
    final newRules = Map<String, String>.from(_config.mappingRules);
    newRules.remove(key);
    _updateConfig(_config.copyWith(mappingRules: newRules));
  }

  String _getDependencyTypeLabel(DependencyType type) {
    switch (type) {
      case DependencyType.count:
        return context.l10n.diy_dependencyCount;
      case DependencyType.exists:
        return context.l10n.diy_dependencyExists;
      case DependencyType.value:
        return context.l10n.diy_dependencyValue;
      case DependencyType.excludes:
        return context.l10n.diy_dependencyExcludes;
    }
  }

  String _getDependencyTypeDescription(DependencyType type) {
    switch (type) {
      case DependencyType.count:
        return context.l10n.diy_dependencyCountDescription;
      case DependencyType.exists:
        return context.l10n.diy_dependencyExistsDescription;
      case DependencyType.value:
        return context.l10n.diy_dependencyValueDescription;
      case DependencyType.excludes:
        return context.l10n.diy_dependencyExcludesDescription;
    }
  }
}
