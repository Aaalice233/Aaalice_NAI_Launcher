import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';

/// 精致的前缀/后缀切换开关
/// 左侧=前缀，右侧=后缀，带滑动动画
class PrefixSuffixSwitch extends StatefulWidget {
  final FixedTagPosition value;
  final ValueChanged<FixedTagPosition> onChanged;
  final String? prefixLabel;
  final String? suffixLabel;

  const PrefixSuffixSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.prefixLabel,
    this.suffixLabel,
  });

  @override
  State<PrefixSuffixSwitch> createState() => _PrefixSuffixSwitchState();
}

class _PrefixSuffixSwitchState extends State<PrefixSuffixSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.value == FixedTagPosition.suffix) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(PrefixSuffixSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value == FixedTagPosition.suffix) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final newValue = widget.value == FixedTagPosition.prefix
        ? FixedTagPosition.suffix
        : FixedTagPosition.prefix;
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrefix = widget.value == FixedTagPosition.prefix;
    final prefixLabel = widget.prefixLabel ?? context.l10n.common_prefix;
    final suffixLabel = widget.suffixLabel ?? context.l10n.common_suffix;

    return GestureDetector(
      onTap: _toggle,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 40,
          width: 240,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // 滑动背景
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Positioned(
                    left: _slideAnimation.value * 120,
                    top: 1,
                    bottom: 1,
                    child: Container(
                      width: 118,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPrefix
                              ? [
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.85,
                                  ),
                                  theme.colorScheme.primary,
                                ]
                              : [
                                  theme.colorScheme.tertiary.withValues(
                                    alpha: 0.85,
                                  ),
                                  theme.colorScheme.tertiary,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(19),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isPrefix
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.tertiary)
                                    .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // 选项文本和图标
              Row(
                children: [
                  Expanded(
                    child: _buildOption(
                      theme,
                      Icons.arrow_forward,
                      prefixLabel,
                      isPrefix,
                      theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _buildOption(
                      theme,
                      Icons.arrow_back,
                      suffixLabel,
                      !isPrefix,
                      theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    ThemeData theme,
    IconData icon,
    String label,
    bool isSelected,
    Color color,
  ) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
