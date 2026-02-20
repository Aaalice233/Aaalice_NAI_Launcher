import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/models/gallery/local_image_record.dart';
import '../../themes/theme_extension.dart';
import '../common/animated_favorite_button.dart';
import '../common/app_toast.dart';

/// Steam风格本地图片卡片
///
/// 实现高级视觉效果：
/// - 边缘发光效果
/// - 光泽扫过动画
/// - 悬停时轻微放大和阴影增强
/// - 复制、发送到主页、收藏按钮
class LocalImageCard3D extends StatefulWidget {
  final LocalImageRecord record;
  final double width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final bool isSelected;
  final bool showFavoriteIndicator;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSendToHome;

  const LocalImageCard3D({
    super.key,
    required this.record,
    required this.width,
    this.height,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.isSelected = false,
    this.showFavoriteIndicator = true,
    this.onFavoriteToggle,
    this.onSendToHome,
  });

  @override
  State<LocalImageCard3D> createState() => _LocalImageCard3DState();
}

class _LocalImageCard3DState extends State<LocalImageCard3D>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  /// 是否悬停
  bool _isHovered = false;

  /// 光泽动画控制器
  late AnimationController _glossController;

  /// 光泽动画
  late Animation<double> _glossAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _glossController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glossAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _glossController, curve: Curves.easeInOut),
    );
  }

  void _onHoverEnter(PointerEvent event) {
    setState(() => _isHovered = true);
    _glossController.forward(from: 0.0);
  }

  void _onHoverExit(PointerEvent event) {
    setState(() => _isHovered = false);
  }

  /// 复制图片到剪贴板
  Future<void> _copyImageToClipboard() async {
    File? tempFile;
    try {
      final sourceFile = File(widget.record.path);

      if (!await sourceFile.exists()) {
        if (mounted) {
          AppToast.error(context, '文件不存在');
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      tempFile = File(
        '${tempDir.path}/NAI_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(await sourceFile.readAsBytes());

      // 使用 PowerShell 复制图像到剪贴板
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        'Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; \$image = [System.Drawing.Image]::FromFile("${tempFile.path}"); [System.Windows.Forms.Clipboard]::SetImage(\$image); \$image.Dispose();',
      ]);

      if (result.exitCode != 0) {
        throw Exception('PowerShell 命令失败');
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        AppToast.success(context, '已复制到剪贴板');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '复制失败: $e');
      }
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// 获取主题适配的效果强度
  _EffectIntensity _getEffectIntensity(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();

    // 根据主题类型调整效果强度
    if (extension?.enableNeonGlow == true) {
      // 霓虹风格：更强的效果
      return const _EffectIntensity(
        holographic: 1.5,
        edgeGlow: 1.3,
        gloss: 1.0,
      );
    } else if (extension?.isLightTheme == true) {
      // 浅色主题：较弱的效果
      return const _EffectIntensity(
        holographic: 0.7,
        edgeGlow: 0.6,
        gloss: 1.0,
      );
    } else {
      // 暗色主题：标准效果
      return const _EffectIntensity(
        holographic: 1.0,
        edgeGlow: 1.0,
        gloss: 0.8,
      );
    }
  }

  /// 获取边缘发光颜色
  Color _getEdgeGlowColor(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();

    // 优先使用主题定义的发光颜色
    if (extension?.glowColor != null) {
      return extension!.glowColor!;
    }

    // 否则使用主题主色
    return theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = theme.colorScheme;
    final intensity = _getEffectIntensity(context);
    final glowColor = _getEdgeGlowColor(context);

    return MouseRegion(
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
          transformAlignment: Alignment.center,
          child: Container(
            width: widget.width,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: widget.isSelected
                  ? Border.all(
                      color: colorScheme.primary,
                      width: 3,
                    )
                  : _isHovered
                      ? Border.all(
                          color: colorScheme.primary.withOpacity(0.3),
                          width: 2,
                        )
                      : null,
              boxShadow: [
                // 主阴影
                BoxShadow(
                  color: _isHovered
                      ? Colors.black.withOpacity(0.35)
                      : Colors.black.withOpacity(0.12),
                  blurRadius: _isHovered ? 28 : 10,
                  offset: Offset(
                    0,
                    _isHovered ? 14 : 4,
                  ),
                  spreadRadius: _isHovered ? 2 : 0,
                ),
                // 次阴影（增加深度感）
                if (_isHovered)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                    spreadRadius: -4,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. 图片层 - 使用RepaintBoundary隔离
                  RepaintBoundary(
                    child: _buildImage(),
                  ),

                  // 2. 边缘发光效果（仅悬停时，带淡入动画）
                  if (_isHovered)
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return _EdgeGlowOverlay(
                            glowColor: glowColor,
                            intensity: value * intensity.edgeGlow,
                          );
                        },
                      ),
                    ),

                  // 3. 光泽扫过效果（仅悬停时）
                  if (_isHovered)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _glossAnimation,
                          builder: (context, child) {
                            return _GlossOverlay(
                              progress: _glossAnimation.value,
                              intensity: intensity.gloss,
                            );
                          },
                        ),
                      ),
                    ),

                  // 4. 右侧竖向按钮组（复制、发送、收藏）
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      // 阻止事件冒泡到父级的卡片点击
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: _buildActionButtons(),
                    ),
                  ),

                  // 5. 选中状态指示器
                  if (widget.isSelected)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildSelectionIndicator(colorScheme),
                    ),

                  // 6. 选中覆盖层（使用 IgnorePointer 让点击穿透）
                  if (widget.isSelected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  // 7. 悬停时显示元数据预览
                  if (_isHovered && widget.record.metadata != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildMetadataPreview(theme),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final file = File(widget.record.path);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.width * pixelRatio).toInt();

    return Container(
      color: Colors.black.withOpacity(0.05),
      child: Image.file(
        file,
        fit: BoxFit.contain,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
            ),
          );
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          // Show placeholder while loading
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }

  /// 构建右侧竖向按钮组
  Widget _buildActionButtons() {
    final hasSend = widget.onSendToHome != null;
    final hasFavorite = widget.onFavoriteToggle != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 收藏按钮（排在第一个）
        if (hasFavorite)
          _buildFavoriteButton(),
        if (hasFavorite)
          const SizedBox(height: 8),
        // 复制按钮（始终显示）
        _buildActionButton(
          icon: Icons.copy,
          onTap: _copyImageToClipboard,
          tooltip: '复制图片',
        ),
        if (hasSend)
          const SizedBox(height: 8),
        // 发送到主页按钮
        if (hasSend)
          Builder(
            builder: (context) => _buildActionButton(
              icon: Icons.send,
              onTap: () => _showSendToHomeMenu(context),
              tooltip: '发送到主页',
            ),
          ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _isHovered ? 1.0 : 0.0,
      child: _HoverActionButton(
        icon: icon,
        onTap: onTap,
        tooltip: tooltip,
      ),
    );
  }

  /// 显示发送到主页菜单
  void _showSendToHomeMenu(BuildContext context) {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;

    final offset = button.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // 计算菜单位置（在按钮左侧弹出）
    const menuWidth = 160.0;
    double left = offset.dx - menuWidth - 8;
    double top = offset.dy;

    // 边界检查
    if (left < 8) left = offset.dx + button.size.width + 8;
    if (top + 150 > screenSize.height) top = screenSize.height - 150;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      useRootNavigator: true,
      builder: (dialogContext) => _SendToHomeMenu(
        position: Offset(left, top),
        onSendToTxt2Img: widget.onSendToHome != null
            ? () {
                Navigator.of(dialogContext).pop();
                widget.onSendToHome!();
              }
            : null,
        onSendToImg2Img: () {
          Navigator.of(dialogContext).pop();
          _showToast(dialogContext, '图生图功能制作中');
        },
        onUpscale: () {
          Navigator.of(dialogContext).pop();
          _showToast(dialogContext, '放大功能制作中');
        },
      ),
    );
  }

  /// 显示提示
  void _showToast(BuildContext context, String message) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildFavoriteButton() {
    final isFavorite = widget.record.isFavorite;
    final showButton = _isHovered || isFavorite;

    if (!showButton) return const SizedBox.shrink();

    return GestureDetector(
      // 拦截点击事件，防止冒泡到父级 GestureDetector 打开详情
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: CardFavoriteButton(
        isFavorite: isFavorite,
        onToggle: widget.onFavoriteToggle,
      ),
    );
  }

  Widget _buildSelectionIndicator(ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.check,
          color: colorScheme.onPrimary,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildMetadataPreview(ThemeData theme) {
    final metadata = widget.record.metadata;
    if (metadata == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.85),
            Colors.black.withOpacity(0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (metadata.model != null)
            Text(
              metadata.model!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              if (metadata.seed != null)
                _buildMetadataChip('Seed: ${metadata.seed}'),
              if (metadata.steps != null)
                _buildMetadataChip('${metadata.steps} steps'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _glossController.dispose();
    super.dispose();
  }
}

/// 效果强度配置
class _EffectIntensity {
  final double holographic;
  final double edgeGlow;
  final double gloss;

  const _EffectIntensity({
    required this.holographic,
    required this.edgeGlow,
    required this.gloss,
  });
}

/// 边缘发光效果覆盖层
class _EdgeGlowOverlay extends StatelessWidget {
  final Color glowColor;
  final double intensity;

  const _EdgeGlowOverlay({
    required this.glowColor,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EdgeGlowPainter(
          glowColor: glowColor,
          intensity: intensity,
        ),
      ),
    );
  }
}

/// 边缘发光绘制器
class _EdgeGlowPainter extends CustomPainter {
  final Color glowColor;
  final double intensity;

  _EdgeGlowPainter({
    required this.glowColor,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // 多层内发光效果
    for (int i = 0; i < 3; i++) {
      final inset = (i + 1) * 1.5;
      final innerRect = rect.deflate(inset);
      final innerRRect = RRect.fromRectAndRadius(
        innerRect,
        Radius.circular(math.max(0, 12 - inset)),
      );

      final opacity = 0.12 * intensity * (3 - i) / 3;
      final blurAmount = (3 - i) * 2.0;

      final paint = Paint()
        ..color = glowColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurAmount);

      canvas.drawRRect(innerRRect, paint);
    }

    // 外部高光边框
    final borderPaint = Paint()
      ..color = glowColor.withOpacity(0.25 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    canvas.drawRRect(rrect, borderPaint);

    // 角落高光点
    _drawCornerHighlights(canvas, size, glowColor, intensity);
  }

  void _drawCornerHighlights(
    Canvas canvas,
    Size size,
    Color color,
    double intensity,
  ) {
    final highlightPaint = Paint()
      ..color = color.withOpacity(0.3 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    const radius = 3.0;
    const offset = 16.0;

    // 四个角落的高光点
    final corners = [
      const Offset(offset, offset),
      Offset(size.width - offset, offset),
      Offset(offset, size.height - offset),
      Offset(size.width - offset, size.height - offset),
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, radius, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(_EdgeGlowPainter oldDelegate) {
    return oldDelegate.glowColor != glowColor ||
        oldDelegate.intensity != intensity;
  }
}

/// 光泽扫过效果覆盖层
class _GlossOverlay extends StatelessWidget {
  final double progress;
  final double intensity;

  const _GlossOverlay({
    required this.progress,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GlossPainter(
          progress: progress,
          intensity: intensity,
        ),
      ),
    );
  }
}

/// 改进的光泽效果绘制器
///
/// 包含主光泽层和珠光层
class _GlossPainter extends CustomPainter {
  final double progress;
  final double intensity;

  _GlossPainter({
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 主光泽层 - 白色高光
    final mainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.06 * intensity),
          Colors.white.withOpacity(0.15 * intensity),
          Colors.white.withOpacity(0.06 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(
        Rect.fromLTWH(
          size.width * progress - size.width * 0.5,
          size.height * progress - size.height * 0.5,
          size.width,
          size.height,
        ),
      );

    canvas.drawRect(Offset.zero & size, mainPaint);

    // 珠光层 - 微妙的彩色光泽
    final pearlPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          const Color(0xFFB8E6F5).withOpacity(0.03 * intensity), // 浅青色
          const Color(0xFFFFF5E1).withOpacity(0.05 * intensity), // 浅金色
          const Color(0xFFE6B8F5).withOpacity(0.03 * intensity), // 浅紫色
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(
        Rect.fromLTWH(
          size.width * progress - size.width * 0.6,
          size.height * progress - size.height * 0.6,
          size.width * 1.2,
          size.height * 1.2,
        ),
      )
      ..blendMode = BlendMode.screen;

    canvas.drawRect(Offset.zero & size, pearlPaint);
  }

  @override
  bool shouldRepaint(_GlossPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}

/// 悬浮操作按钮
/// 
/// 带独立悬浮动效（放大、背景变亮），并阻止点击事件冒泡
class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  const _HoverActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        // 阻止事件冒泡到父级，同时执行实际点击回调
        onTap: () {
          widget.onTap?.call();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: _isHovering ? 1.15 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _isHovering
                  ? Colors.black.withOpacity(0.85)
                  : Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(
                widget.icon,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// 发送到主页菜单
/// 
/// 用于选择将图片发送到何处：
/// - 文生图（参数套用）
/// - 图生图（制作中）
/// - 放大（制作中）
class _SendToHomeMenu extends StatelessWidget {
  final Offset position;
  final VoidCallback? onSendToTxt2Img;
  final VoidCallback? onSendToImg2Img;
  final VoidCallback? onUpscale;

  const _SendToHomeMenu({
    required this.position,
    this.onSendToTxt2Img,
    this.onSendToImg2Img,
    this.onUpscale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 点击外部关闭
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          // 菜单
          Positioned(
            left: position.dx,
            top: position.dy,
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.text_fields,
                    label: '文生图',
                    subtitle: '套用参数',
                    onTap: onSendToTxt2Img,
                  ),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.image,
                    label: '图生图',
                    subtitle: '制作中',
                    enabled: false,
                    onTap: onSendToImg2Img,
                  ),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.zoom_in,
                    label: '放大',
                    subtitle: '制作中',
                    enabled: false,
                    onTap: onUpscale,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.38),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withOpacity(0.38),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface.withOpacity(0.38),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
