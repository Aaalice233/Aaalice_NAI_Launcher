import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/localization_extension.dart';

/// 质量词提示组件
/// 显示当前开启的质量词会添加什么内容
class QualityTagsHint extends StatefulWidget {
  /// 是否开启质量词
  final bool enabled;

  /// 当前选择的模型
  final String model;

  /// 点击回调（切换开关）
  final VoidCallback? onTap;

  const QualityTagsHint({
    super.key,
    required this.enabled,
    required this.model,
    this.onTap,
  });

  @override
  State<QualityTagsHint> createState() => _QualityTagsHintState();
}

class _QualityTagsHintState extends State<QualityTagsHint> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qualityTags = QualityTags.getQualityTags(widget.model) ??
        'very aesthetic, masterpiece, no text';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        richMessage: WidgetSpan(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: _buildTooltipWidget(theme, qualityTags),
          ),
        ),
        preferBelow: true,
        verticalOffset: 20,
        waitDuration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.enabled
                  ? (_isHovering
                      ? Colors.orange.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.1))
                  : (_isHovering
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.enabled
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.enabled
                      ? Icons.auto_awesome
                      : Icons.auto_awesome_outlined,
                  size: 14,
                  color: widget.enabled
                      ? Colors.orange.shade700
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.qualityTags_label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        widget.enabled ? FontWeight.w600 : FontWeight.w500,
                    color: widget.enabled
                        ? Colors.orange.shade700
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                if (widget.enabled) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.orange.shade700,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTooltipWidget(ThemeData theme, String qualityTags) {
    if (!widget.enabled) {
      return Text(
        context.l10n.qualityTags_disabled,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 12,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.qualityTags_addToEnd,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ', $qualityTags',
          style: TextStyle(
            color: Colors.orange.shade700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
