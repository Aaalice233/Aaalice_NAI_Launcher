import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/tag_scope.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../providers/random_preset_provider.dart';
import '../../common/themed_input_dialog.dart';

/// 作用域三选项开关
///
/// 精美的三选项切换组件，每个选项有不同的高亮色
class ScopeTripleSwitch extends StatefulWidget {
  const ScopeTripleSwitch({
    super.key,
    required this.scope,
    required this.onChanged,
    this.enabled = true,
  });

  final TagScope scope;
  final ValueChanged<TagScope> onChanged;

  /// 是否可交互
  final bool enabled;

  @override
  State<ScopeTripleSwitch> createState() => _ScopeTripleSwitchState();
}

class _ScopeTripleSwitchState extends State<ScopeTripleSwitch> {
  int _currentIndex = 0;

  static const _scopeIcons = {
    TagScope.global: Icons.text_fields,
    TagScope.character: Icons.person,
    TagScope.all: Icons.all_inclusive,
  };

  static const _scopeColors = {
    TagScope.global: Colors.blue,
    TagScope.character: Color(0xFF4CAF50),
    TagScope.all: Colors.purple,
  };

  static const _scopeOrder = [
    TagScope.global,
    TagScope.character,
    TagScope.all,
  ];

  String _getLabel(AppLocalizations l10n, TagScope scope) {
    return switch (scope) {
      TagScope.global => l10n.scope_global,
      TagScope.character => l10n.scope_character,
      TagScope.all => l10n.scope_all,
    };
  }

  String _getTooltip(AppLocalizations l10n, TagScope scope) {
    return switch (scope) {
      TagScope.global => l10n.scope_globalTooltip,
      TagScope.character => l10n.scope_characterTooltip,
      TagScope.all => l10n.scope_allTooltip,
    };
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = _scopeOrder.indexOf(widget.scope);
    if (_currentIndex < 0) _currentIndex = 0;
  }

  @override
  void didUpdateWidget(ScopeTripleSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      final newIndex = _scopeOrder.indexOf(widget.scope);
      if (newIndex >= 0 && newIndex != _currentIndex) {
        setState(() => _currentIndex = newIndex);
      }
    }
  }

  void _onTap(int index) {
    if (!widget.enabled) return;
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    widget.onChanged(_scopeOrder[index]);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final currentScope = _scopeOrder[_currentIndex];
    final currentColor = widget.enabled
        ? _scopeColors[currentScope]!
        : colorScheme.outline;
    final controlExtent = context.interactionPolicy.minimumControlExtent;

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.6,
      child: Container(
        constraints: BoxConstraints(minHeight: controlExtent),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / 3;
            return Stack(
              children: [
                // 滑动高亮背景
                AnimatedPositioned(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  left: _currentIndex * itemWidth + 2,
                  top: 2,
                  bottom: 2,
                  width: itemWidth - 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: currentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                // 选项按钮
                Row(
                  children: List.generate(3, (index) {
                    final isSelected = index == _currentIndex;
                    final scope = _scopeOrder[index];
                    final icon = _scopeIcons[scope]!;
                    final label = _getLabel(l10n, scope);
                    final tooltip = _getTooltip(l10n, scope);
                    return Expanded(
                      child: Tooltip(
                        message: tooltip,
                        preferBelow: false,
                        verticalOffset: 20,
                        child: TextButton(
                          onPressed: widget.enabled
                              ? () => _onTap(index)
                              : null,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            foregroundColor: isSelected
                                ? currentColor
                                : colorScheme.onSurfaceVariant,
                            backgroundColor: Colors.transparent,
                            minimumSize: Size(0, controlExtent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 14,
                                  color: isSelected
                                      ? currentColor
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? currentColor
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 彩色概率滑条
///
/// 保留 ProbabilityBar 的彩色渐变样式，但支持拖动交互
class ColorfulProbabilitySlider extends StatelessWidget {
  const ColorfulProbabilitySlider({
    super.key,
    required this.probability,
    required this.onChanged,
    this.enabled = true,
    this.interactive = true,
  });

  final double probability;
  final ValueChanged<double> onChanged;
  final bool enabled;

  /// 是否可交互（默认预设时为 false，完全禁用滑条）
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final secondaryColor = enabled
        ? colorScheme.secondary
        : colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              // 隐藏默认轨道，使用自定义背景
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              // 移除轨道两端的默认 padding
              trackShape: const RectangularSliderTrackShape(),
              thumbColor: primaryColor,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
                elevation: 2,
              ),
              overlayColor: primaryColor.withValues(alpha: 0.12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 背景轨道（添加水平 padding 补偿滑块半径）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // 彩色渐变进度
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: probability,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: enabled
                              ? [
                                  primaryColor.withValues(alpha: 0.9),
                                  secondaryColor.withValues(alpha: 0.7),
                                ]
                              : [
                                  primaryColor.withValues(alpha: 0.4),
                                  secondaryColor.withValues(alpha: 0.3),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: enabled
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
                // 透明滑条（用于交互）
                Slider(
                  value: probability,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: interactive ? onChanged : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 百分比标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${(probability * 100).toInt()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: primaryColor.withValues(alpha: enabled ? 1.0 : 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

/// 添加词组卡片
///
/// 放置在词组列表末尾，点击后打开添加词组对话框
class AddTagGroupCard extends StatefulWidget {
  const AddTagGroupCard({super.key, required this.onTap, this.enabled = true});

  final VoidCallback onTap;

  /// 是否可交互（默认预设时为 false）
  final bool enabled;

  @override
  State<AddTagGroupCard> createState() => _AddTagGroupCardState();
}

class _AddTagGroupCardState extends State<AddTagGroupCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = widget.enabled;
    final l10n = AppLocalizations.of(context)!;

    return MouseRegion(
      cursor: isEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: isEnabled ? widget.onTap : null,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: SizedBox(
            width: 135,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 图标
                  AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (_isHovered && isEnabled)
                          ? colorScheme.primary.withValues(alpha: 0.15)
                          : colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEnabled ? Icons.add_rounded : Icons.lock_outline,
                      size: 20,
                      color: (_isHovered && isEnabled)
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 文字
                  Text(
                    isEnabled
                        ? l10n.randomManager_addTagGroup
                        : l10n.randomManager_locked,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: (_isHovered && isEnabled)
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: (_isHovered && isEnabled)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 添加类别按钮
class AddCategoryButton extends ConsumerStatefulWidget {
  const AddCategoryButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  ConsumerState<AddCategoryButton> createState() => _AddCategoryButtonState();
}

class _AddCategoryButtonState extends ConsumerState<AddCategoryButton> {
  bool _isHovered = false;

  /// 未传入上层流程时，按钮仍能完成标准的类别创建。
  Future<void> _handlePressed() async {
    final customHandler = widget.onPressed;
    if (customHandler != null) {
      customHandler();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final name = await ThemedInputDialog.show(
      context: context,
      title: l10n.category_dialogTitle,
      hintText: l10n.category_nameHint,
      validator: (v) => v.trim().isEmpty ? l10n.category_nameRequired : null,
    );
    if (name == null || name.trim().isEmpty) return;

    final preset = ref.read(randomPresetNotifierProvider).selectedPreset;
    if (preset == null) return;
    // 键名只在预设内用于标识，用序号保证可读且不与现有类别冲突
    var index = preset.categories.length + 1;
    var key = 'custom$index';
    while (preset.findCategoryByKey(key) != null) {
      index++;
      key = 'custom$index';
    }

    await ref
        .read(randomPresetNotifierProvider.notifier)
        .addCategory(RandomCategory.create(name: name.trim(), key: key));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _handlePressed,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: _isHovered
                ? LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.15),
                      colorScheme.secondary.withValues(alpha: 0.1),
                    ],
                  )
                : null,
            color: _isHovered ? null : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size: 16,
                color: _isHovered
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.randomManager_addCategory,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _isHovered
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 空类别占位符
class EmptyCategoryPlaceholder extends StatelessWidget {
  const EmptyCategoryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.randomManager_noCategories,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.randomManager_noCategoriesHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 类别统计信息组件
class CategoryStats extends StatelessWidget {
  const CategoryStats({
    super.key,
    required this.categoryCount,
    required this.groupCount,
    required this.tagCount,
  });

  final int categoryCount;
  final int groupCount;
  final int tagCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatBadge(
          icon: Icons.category_outlined,
          label: l10n.randomManager_categories,
          value: '$categoryCount',
          color: colorScheme.primary,
        ),
        const SizedBox(width: 12),
        _StatBadge(
          icon: Icons.layers_outlined,
          label: l10n.randomManager_tagGroups,
          value: '$groupCount',
          color: colorScheme.secondary,
        ),
        const SizedBox(width: 12),
        _StatBadge(
          icon: Icons.label_outlined,
          label: l10n.randomManager_tags,
          value: '$tagCount',
          color: colorScheme.tertiary,
        ),
      ],
    );
  }
}

/// 统计徽章组件
class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label:',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
