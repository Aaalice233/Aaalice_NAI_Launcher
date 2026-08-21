import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/preview_transparency_provider.dart';
import '../../../widgets/common/transparency_background.dart';
import '../../../widgets/image_editor/widgets/color_picker.dart';

/// 预览图下方的信息条（对齐官网结果区底部的 display/save 工具条）
///
/// 自左向右：分辨率胶囊 → 分隔线 → 显示设置齿轮 → 种子胶囊。
/// 齿轮向上弹出显示设置浮层，目前只有透明部分的底色选择。
class PreviewInfoBar extends ConsumerWidget {
  final GeneratedImage image;

  const PreviewInfoBar({super.key, required this.image});

  static const double barHeight = 30;

  /// 低于该宽度就收起分辨率胶囊（官网在窄容器下同样隐藏它）
  static const double _resolutionMinWidth = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = image.metadata?.seed;

    return SizedBox(
      height: barHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showResolution =
              !constraints.maxWidth.isFinite ||
              constraints.maxWidth >= _resolutionMinWidth;

          return ClipRect(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showResolution) ...[
                  _InfoPill(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${image.width}'),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.close_rounded, size: 11),
                        ),
                        Text('${image.height}'),
                      ],
                    ),
                  ),
                  const _PillDivider(),
                ],
                const _DisplaySettingsButton(),
                if (seed != null) ...[
                  const SizedBox(width: 6),
                  Flexible(child: _SeedPill(seed: seed)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 只读信息胶囊
class _InfoPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  const _InfoPill({required this.child, this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget pill = Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Center(
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      pill = Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: pill,
      );
    }
    return pill;
  }
}

class _PillDivider extends StatelessWidget {
  const _PillDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.dividerColor,
    );
  }
}

/// 种子胶囊：点击把这张图的种子写回生成参数
class _SeedPill extends ConsumerWidget {
  final int seed;

  const _SeedPill({required this.seed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _InfoPill(
      tooltip: context.l10n.generation_previewApplySeed,
      onTap: () => ref
          .read(generationParamsNotifierProvider.notifier)
          .updateSeed(seed),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.eco_outlined, size: 13),
          const SizedBox(width: 6),
          Flexible(
            child: Text('$seed', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// 显示设置齿轮：向上弹出浮层
class _DisplaySettingsButton extends StatefulWidget {
  const _DisplaySettingsButton();

  @override
  State<_DisplaySettingsButton> createState() => _DisplaySettingsButtonState();
}

class _DisplaySettingsButtonState extends State<_DisplaySettingsButton> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();

  void _close() {
    if (_controller.isShowing) _controller.hide();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _controller.isShowing;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (context) {
          return Stack(
            children: [
              // 点击浮层外部关闭
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                ),
              ),
              CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.topRight,
                followerAnchor: Alignment.bottomRight,
                offset: const Offset(0, -5),
                child: _DisplaySettingsPanel(onClose: _close),
              ),
            ],
          );
        },
        child: Tooltip(
          message: context.l10n.generation_previewDisplaySettings,
          waitDuration: const Duration(milliseconds: 400),
          child: Material(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                setState(() => _controller.toggle());
              },
              child: SizedBox(
                width: PreviewInfoBar.barHeight,
                height: PreviewInfoBar.barHeight,
                child: Icon(
                  Icons.settings_rounded,
                  size: 15,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 显示设置浮层内容
class _DisplaySettingsPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const _DisplaySettingsPanel({required this.onClose});

  @override
  ConsumerState<_DisplaySettingsPanel> createState() =>
      _DisplaySettingsPanelState();
}

class _DisplaySettingsPanelState extends ConsumerState<_DisplaySettingsPanel> {
  bool _customExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final style = ref.watch(previewTransparencyNotifierProvider);
    final notifier = ref.read(previewTransparencyNotifierProvider.notifier);
    final isCustom = TransparencyBackgrounds.isCustomColor(style);

    final checkerSwatches = <_SwatchSpec>[
      _SwatchSpec(
        value: TransparencyBackgrounds.checker,
        label: l10n.generation_transparencyChecker,
      ),
      _SwatchSpec(
        value: TransparencyBackgrounds.checkerLight,
        label: l10n.generation_transparencyCheckerLight,
      ),
      _SwatchSpec(
        value: TransparencyBackgrounds.checkerDark,
        label: l10n.generation_transparencyCheckerDark,
      ),
      _SwatchSpec(
        value: TransparencyBackgrounds.none,
        label: l10n.generation_transparencyNone,
      ),
    ];

    final solidLabels = <String, String>{
      'black': l10n.generation_transparencyBlack,
      'white': l10n.generation_transparencyWhite,
      'gray': l10n.generation_transparencyGray,
      'red': l10n.generation_transparencyRed,
      'green': l10n.generation_transparencyGreen,
      'blue': l10n.generation_transparencyBlue,
    };

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      child: Container(
        width: 232,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.generation_transparencyBackgroundTitle,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final swatch in checkerSwatches)
                  _Swatch(
                    tooltip: swatch.label,
                    selected: style == swatch.value,
                    onTap: () => notifier.setStyle(swatch.value),
                    child: _SwatchPreview(style: swatch.value),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in TransparencyBackgrounds.solidColors.entries)
                  _Swatch(
                    tooltip: solidLabels[entry.key] ?? entry.key,
                    selected: style == entry.key,
                    onTap: () => notifier.setStyle(entry.key),
                    child: ColoredBox(color: entry.value),
                  ),
                _Swatch(
                  tooltip: l10n.generation_transparencyCustom,
                  selected: isCustom,
                  onTap: () => setState(() => _customExpanded = !_customExpanded),
                  child: isCustom
                      ? ColoredBox(
                          color:
                              TransparencyBackgrounds.parseCustomColor(style)!,
                        )
                      : Icon(
                          Icons.colorize_rounded,
                          size: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                ),
              ],
            ),
            if (_customExpanded) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: HSVColorPicker(
                  color:
                      TransparencyBackgrounds.parseCustomColor(style) ??
                      const Color(0xFF808080),
                  onColorChanged: (color) => notifier.setStyle(
                    TransparencyBackgrounds.encodeCustomColor(color),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwatchSpec {
  final String value;
  final String label;

  const _SwatchSpec({required this.value, required this.label});
}

/// 色板格子：24×24，选中时描主题色边框
class _Swatch extends StatelessWidget {
  final Widget child;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _Swatch({
    required this.child,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(child: SizedBox.expand(child: child)),
        ),
      ),
    );
  }
}

/// 棋盘格/无 档位的格子预览
class _SwatchPreview extends StatelessWidget {
  final String style;

  const _SwatchPreview({required this.style});

  @override
  Widget build(BuildContext context) {
    if (style == TransparencyBackgrounds.none) {
      final theme = Theme.of(context);
      // 官网用一条对角线表示"不铺底色"
      return CustomPaint(
        painter: _DiagonalSlashPainter(color: theme.colorScheme.onSurface),
      );
    }
    return TransparencyBackgroundLayer(style: style);
  }
}

class _DiagonalSlashPainter extends CustomPainter {
  final Color color;

  const _DiagonalSlashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_DiagonalSlashPainter oldDelegate) =>
      oldDelegate.color != color;
}
