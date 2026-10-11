import 'package:flutter/material.dart';

import '../../../adaptive/interaction_policy.dart';
import '../../../themes/core/layered_surface_style.dart';

/// 互斥选项的紧凑胶囊分段，尺寸与配色和 [GenerationToggleButton] 一致。
class GenerationSegmentedToggle<T> extends StatelessWidget {
  const GenerationSegmentedToggle({
    super.key,
    required this.semanticLabel,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  static const double _trackPadding = 2;

  /// 分组名称只给读屏使用，界面上不显示。
  final String semanticLabel;
  final List<GenerationSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final policy = context.interactionPolicy;
    final minSegmentHeight = policy.prefersTouchPresentation
        ? policy.minimumControlExtent - _trackPadding * 2
        : 0.0;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: controlSurfaceColor(Theme.of(context).colorScheme),
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_trackPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final segment in segments)
                _Segment<T>(
                  segment: segment,
                  selected: segment.value == selected,
                  minHeight: minSegmentHeight,
                  onSelected: onChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GenerationSegment<T> {
  const GenerationSegment({required this.value, required this.label});

  final T value;
  final String label;
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.minHeight,
    required this.onSelected,
  });

  final GenerationSegment<T> segment;
  final bool selected;
  final double minHeight;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        type: MaterialType.transparency,
        child: TweenAnimationBuilder<Color?>(
          // 未选中用全透明主色，淡入淡出只变透明度，不经过灰色。
          tween: ColorTween(
            end: selected
                ? colorScheme.primary
                : colorScheme.primary.withValues(alpha: 0),
          ),
          duration: duration,
          curve: Curves.easeInOut,
          // Ink 把底色画在 Material 上，键盘焦点高亮才不会被选中色盖住。
          builder: (context, color, child) => Ink(
            decoration: ShapeDecoration(
              color: color,
              shape: const StadiumBorder(),
            ),
            child: child,
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            // 点已选中的分段不回调，但保留焦点遍历。
            onTap: () {
              if (!selected) onSelected(segment.value);
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeInOut,
                    style: (theme.textTheme.labelMedium ?? const TextStyle())
                        .copyWith(
                          color: selected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                    child: Text(segment.label, maxLines: 1, softWrap: false),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
