import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/dependency_config.dart';
import '../../../../../data/models/prompt/diy_category_references.dart';
import '../../../../../data/models/prompt/random_tag_group.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../utils/single_line_text_width.dart';
import '../../../../widgets/common/horizontal_segmented_control.dart';
import '../../../../widgets/common/surface_ink_well.dart';
import '../diy_category_field.dart';
import '../diy_panel_header.dart';
import '../diy_section_card.dart';
import '../diy_switch_card.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 依赖配置面板：按源类别的结果或角色人数决定本词组的抽取
class DependencyConfigPanel extends StatefulWidget {
  final DependencyConfig? config;
  final ValueChanged<DependencyConfig?> onConfigChanged;
  final List<DiyCategoryOption> categoryOptions;

  /// 所属词组的选择模式，用于说明数量依赖如何覆盖该模式的数量
  final SelectionMode? selectionMode;

  final bool readOnly;

  const DependencyConfigPanel({
    super.key,
    this.config,
    required this.onConfigChanged,
    this.categoryOptions = const [],
    this.selectionMode,
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
        DiySwitchCard(
          title: context.l10n.diy_enableDependency,
          subtitle: context.l10n.diy_enableDependencyHint,
          value: _config.enabled,
          onChanged: widget.readOnly
              ? null
              : (value) => _updateConfig(_config.copyWith(enabled: value)),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;

    return DiyPanelHeader(
      icon: Icons.link_rounded,
      accent: colorScheme.tertiary,
      title: context.l10n.diy_dependencyTitle,
      subtitle: context.l10n.diy_dependencySubtitle,
      trailing: widget.config != null && !widget.readOnly
          ? TextButton.icon(
              onPressed: () => widget.onConfigChanged(null),
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(context.l10n.common_clear),
            )
          : null,
    );
  }

  Widget _buildTypeSelector() {
    final colorScheme = Theme.of(context).colorScheme;
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

    return DiySectionCard(
      icon: Icons.category_rounded,
      accent: colorScheme.primary,
      accentContainer: colorScheme.primaryContainer,
      title: context.l10n.diy_dependencyType,
      hoverable: !widget.readOnly,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeOptions(typeIcons, typeColors),
          const SizedBox(height: 12),
          _buildNote(
            Icons.info_outline_rounded,
            _getDependencyTypeDescription(_config.type),
          ),
          if (_selectionCountOverrideNote case final note?) ...[
            const SizedBox(height: 8),
            _buildNote(Icons.tune_rounded, note),
          ],
        ],
      ),
    );
  }

  Widget _buildNote(IconData icon, String text) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 数量与值依赖在“多选数量”以外的模式下覆盖模式自身的数量
  String? get _selectionCountOverrideNote {
    final mode = widget.selectionMode;
    if (!_config.controlsSelectionCount ||
        mode == null ||
        mode == SelectionMode.multipleNum) {
      return null;
    }
    return mode == SelectionMode.sequential
        ? context.l10n.diy_dependencyOverridesSequentialCount
        : context.l10n.diy_dependencyOverridesSelectionCount;
  }

  // 四种类型是互斥模式：放得下时等宽排满一行，否则整行横向滚动，不竖排也不截断标签
  Widget _buildTypeOptions(
    Map<DependencyType, IconData> typeIcons,
    Map<DependencyType, Color> typeColors,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    const contentPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 12);
    const gap = 6.0;
    final tileWidth =
        DependencyType.values.fold(
          0.0,
          (widest, type) => math.max(
            widest,
            singleLineTextWidth(
              context,
              _getDependencyTypeLabel(type),
              labelStyle,
            ),
          ),
        ) +
        contentPadding.horizontal;

    Widget option(DependencyType type) {
      final isSelected = _config.type == type;
      final color = typeColors[type]!;
      return SurfaceInkWell(
        borderRadius: BorderRadius.circular(10),
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.8)],
              )
            : null,
        color: isSelected ? null : colorScheme.surfaceContainerHighest,
        shadows: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        duration: const Duration(milliseconds: 200),
        onTap: widget.readOnly
            ? null
            : () => _updateConfig(_config.copyWith(type: type)),
        child: Padding(
          padding: contentPadding,
          child: Column(
            children: [
              Icon(
                typeIcons[type],
                size: 20,
                color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                _getDependencyTypeLabel(type),
                style: labelStyle?.copyWith(
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const types = DependencyType.values;
        final fits =
            tileWidth * types.length + gap * (types.length - 1) <=
            constraints.maxWidth;
        if (fits) {
          return Row(
            spacing: gap,
            children: [for (final type in types) Expanded(child: option(type))],
          );
        }
        return HorizontalSegmentedControl(
          child: Row(
            spacing: gap,
            children: [
              for (final type in types)
                SizedBox(width: tileWidth, child: option(type)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceCategorySelector() {
    final colorScheme = Theme.of(context).colorScheme;

    return DiySectionCard(
      icon: Icons.source_rounded,
      accent: colorScheme.secondary,
      accentContainer: colorScheme.secondaryContainer,
      title: context.l10n.diy_sourceCategory,
      hoverable: !widget.readOnly,
      child: DiyCategoryDropdown(
        value: _config.sourceCategoryId,
        options: _sourceOptions,
        readOnly: widget.readOnly,
        decoration: InputDecoration(
          hintText: context.l10n.diy_selectSourceCategory,
          prefixIcon: Icon(
            Icons.folder_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
          border: InputBorder.none,
        ),
        onChanged: (value) {
          _updateConfig(_config.copyWith(sourceCategoryId: value));
        },
      ),
    );
  }

  List<DiyCategoryOption> get _sourceOptions => [
    DiyCategoryOption(
      id: characterCountReference,
      label: context.l10n.diy_sourceCharacterCount,
    ),
    ...widget.categoryOptions,
  ];

  Widget _buildMappingRulesEditor() {
    final colorScheme = Theme.of(context).colorScheme;

    return DiySectionCard(
      icon: Icons.swap_horiz_rounded,
      accent: colorScheme.tertiary,
      accentContainer: colorScheme.tertiaryContainer,
      title: context.l10n.diy_mappingRules,
      trailing: widget.readOnly
          ? null
          : TextButton.icon(
              onPressed: _addMappingRule,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.l10n.common_add),
            ),
      child: _config.mappingRules.isEmpty
          ? const _NoMappingRules()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                for (final MapEntry(:key, :value)
                    in _config.mappingRules.entries)
                  _MappingRuleRow(
                    source: key,
                    result: value,
                    onDeleted: widget.readOnly
                        ? null
                        : () => _removeMappingRule(key),
                  ),
              ],
            ),
    );
  }

  Widget _buildDefaultValueField() {
    final colorScheme = Theme.of(context).colorScheme;

    return DiySectionCard(
      icon: Icons.text_snippet_outlined,
      accent: colorScheme.primary,
      accentContainer: colorScheme.primaryContainer,
      title: context.l10n.diy_defaultValue,
      hoverable: !widget.readOnly,
      child: ThemedFormInput(
        initialValue: _config.defaultValue ?? '',
        decoration: InputDecoration(
          hintText: context.l10n.diy_defaultValueHint,
          prefixIcon: Icon(
            Icons.edit_note_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        readOnly: widget.readOnly,
        onChanged: (value) {
          _updateConfig(
            _config.copyWith(defaultValue: value.isEmpty ? null : value),
          );
        },
      ),
    );
  }

  Future<void> _addMappingRule() async {
    final result = await AdaptivePresenter.showForm<_MappingRule>(
      context: context,
      titleBuilder: (context) => Row(
        children: [
          const Icon(Icons.add_link_rounded),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.diy_addMappingRule,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      dialogWidth: 480,
      builder: (context, scrollController) =>
          _MappingRuleForm(scrollController: scrollController),
    );
    if (!mounted || result == null) return;

    final newRules = Map<String, String>.from(_config.mappingRules);
    newRules[result.source] = result.value;
    _updateConfig(_config.copyWith(mappingRules: newRules));
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

  // 角色数量源读取的是本次生成的人数而非类别结果，说明要按源区分
  String _getDependencyTypeDescription(DependencyType type) {
    final l10n = context.l10n;
    final fromCharacterCount =
        _config.sourceCategoryId == characterCountReference;
    switch (type) {
      case DependencyType.count:
        return fromCharacterCount
            ? l10n.diy_dependencyCountCharacterCountDescription
            : l10n.diy_dependencyCountDescription;
      case DependencyType.exists:
        return fromCharacterCount
            ? l10n.diy_dependencyExistsCharacterCountDescription
            : l10n.diy_dependencyExistsDescription;
      case DependencyType.value:
        return fromCharacterCount
            ? l10n.diy_dependencyValueCharacterCountDescription
            : l10n.diy_dependencyValueDescription;
      case DependencyType.excludes:
        return fromCharacterCount
            ? l10n.diy_dependencyExcludesCharacterCountDescription
            : l10n.diy_dependencyExcludesDescription;
    }
  }
}

class _NoMappingRules extends StatelessWidget {
  const _NoMappingRules();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.rule_rounded, size: 32, color: colorScheme.outline),
            const SizedBox(height: 8),
            Text(
              context.l10n.diy_noMappingRules,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一条映射：源值 → 结果值，[onDeleted] 为空时不可删除
class _MappingRuleRow extends StatelessWidget {
  const _MappingRuleRow({
    required this.source,
    required this.result,
    required this.onDeleted,
  });

  final String source;
  final String result;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Widget chip(String text, Color container, Color foreground) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: container.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                chip(source, colorScheme.primaryContainer, colorScheme.primary),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                chip(
                  result,
                  colorScheme.secondaryContainer,
                  colorScheme.secondary,
                ),
              ],
            ),
          ),
          if (onDeleted != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: colorScheme.error.withValues(alpha: 0.7),
              ),
              onPressed: onDeleted,
              tooltip: context.l10n.diy_deleteRule,
            ),
        ],
      ),
    );
  }
}

class _MappingRule {
  const _MappingRule({required this.source, required this.value});

  final String source;
  final String value;
}

class _MappingRuleForm extends StatefulWidget {
  const _MappingRuleForm({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_MappingRuleForm> createState() => _MappingRuleFormState();
}

class _MappingRuleFormState extends State<_MappingRuleForm> {
  final _sourceController = TextEditingController();
  final _valueController = TextEditingController();
  final _sourceFocusNode = FocusNode();
  final _valueFocusNode = FocusNode();

  bool get _isValid =>
      _sourceController.text.isNotEmpty && _valueController.text.isNotEmpty;

  @override
  void dispose() {
    _sourceController.dispose();
    _valueController.dispose();
    _sourceFocusNode.dispose();
    _valueFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 2;
    return Column(
      key: const ValueKey('mapping-rule-form'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('mapping-rule-form-scroll'),
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ThemedInput(
                  key: const ValueKey('mapping-rule-source'),
                  controller: _sourceController,
                  focusNode: _sourceFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n.diy_sourceValue,
                    hintText: context.l10n.diy_sourceValueHint,
                    prefixIcon: largeText
                        ? null
                        : Icon(
                            Icons.input_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _valueFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                ThemedInput(
                  key: const ValueKey('mapping-rule-value'),
                  controller: _valueController,
                  focusNode: _valueFocusNode,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: context.l10n.diy_resultValue,
                    hintText: context.l10n.diy_resultValueHint,
                    prefixIcon: largeText
                        ? null
                        : Icon(
                            Icons.output_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (_isValid) _submit();
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cancel = TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.common_cancel),
                );
                final add = FilledButton(
                  key: const ValueKey('mapping-rule-submit'),
                  onPressed: _isValid ? _submit : null,
                  child: Text(context.l10n.common_add),
                );
                final stackActions =
                    MediaQuery.textScalerOf(context).scale(1) >= 2 ||
                    constraints.maxWidth < 240;
                if (stackActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [add, const SizedBox(height: 8), cancel],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [cancel, const SizedBox(width: 8), add],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _submit() {
    if (!_isValid) return;
    Navigator.pop(
      context,
      _MappingRule(
        source: _sourceController.text,
        value: _valueController.text,
      ),
    );
  }
}
