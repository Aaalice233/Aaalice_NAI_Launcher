import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../providers/image_save_settings_provider.dart';
import '../../themes/theme_extension.dart';
import 'pro_context_menu.dart';
import 'app_toast.dart';

/// 可选择的图像卡片组件
///
/// 支持：
/// - 悬浮时显示操作按钮（保存、复制、放大）
/// - 边缘发光效果
/// - 光泽扫过动画（闪卡效果）
/// - 悬浮时轻微放大和阴影增强
/// - 生成中状态（流式预览、进度显示）
class SelectableImageCard extends ConsumerStatefulWidget {
  /// 图像数据（生成完成时必须提供，生成中时可为空）
  final Uint8List? imageBytes;
  final int? index;
  final bool isSelected;
  final bool showIndex;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onFullscreen;

  /// 是否启用右键菜单
  final bool enableContextMenu;

  /// 是否启用悬浮放大效果
  final bool enableHoverScale;

  /// 是否启用闪卡效果（边缘发光+光泽扫过）
  final bool enableGlossEffect;

  /// 是否启用选择框
  final bool enableSelection;

  /// 放大回调（用于单图显示放大按钮）
  final VoidCallback? onUpscale;

  /// 在文件夹中打开的回调（需要先保存图片）
  final VoidCallback? onOpenInExplorer;

  /// 保存到词库的回调（传入图像字节和合并后的提示词）
  final void Function(Uint8List imageBytes, String prompt)? onSaveToLibrary;

  // ========== 生成中状态相关参数 ==========

  /// 是否处于生成中状态
  final bool isGenerating;

  /// 生成进度 (0.0-1.0)
  final double? progress;

  /// 当前第几张图像 (1-based)
  final int? currentImage;

  /// 总共几张图像
  final int? totalImages;

  /// 流式预览图像（渐进式生成中显示）
  final Uint8List? streamPreview;

  /// 图像宽度（用于计算比例，生成中状态需要）
  final int? imageWidth;

  /// 图像高度（用于计算比例，生成中状态需要）
  final int? imageHeight;

  const SelectableImageCard({
    super.key,
    this.imageBytes,
    this.index,
    this.isSelected = false,
    this.showIndex = true,
    this.onTap,
    this.onSelectionChanged,
    this.onFullscreen,
    this.enableContextMenu = true,
    this.enableHoverScale = true,
    this.enableGlossEffect = true,
    this.enableSelection = true,
    this.onUpscale,
    this.onOpenInExplorer,
    this.onSaveToLibrary,
    // 生成中状态参数
    this.isGenerating = false,
    this.progress,
    this.currentImage,
    this.totalImages,
    this.streamPreview,
    this.imageWidth,
    this.imageHeight,
  }) : assert(
          !isGenerating || (imageWidth != null && imageHeight != null),
          'imageWidth and imageHeight are required when isGenerating is true',
        );

  @override
  ConsumerState<SelectableImageCard> createState() =>
      _SelectableImageCardState();
}

class _SelectableImageCardState extends ConsumerState<SelectableImageCard>
    with TickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _glossController;
  late Animation<double> _glossAnimation;

  // 生成中状态的发光动画
  AnimationController? _glowController;
  Animation<double>? _glowAnimation;

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

    // 如果是生成中状态，初始化发光动画
    if (widget.isGenerating) {
      _initGlowAnimation();
    }
  }

  void _initGlowAnimation() {
    _glowController?.dispose();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.1, end: 0.35).animate(
      CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(SelectableImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 状态变化时管理发光动画
    if (widget.isGenerating && !oldWidget.isGenerating) {
      _initGlowAnimation();
    } else if (!widget.isGenerating && oldWidget.isGenerating) {
      _glowController?.dispose();
      _glowController = null;
      _glowAnimation = null;
    }
  }

  @override
  void dispose() {
    _glossController.dispose();
    _glowController?.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    setState(() => _isHovering = true);
    if (widget.enableGlossEffect) {
      _glossController.forward(from: 0.0);
    }
  }

  void _onHoverExit() {
    setState(() => _isHovering = false);
  }

  /// 获取边缘发光颜色
  Color _getGlowColor(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();
    return extension?.glowColor ?? theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 生成中状态使用专用的构建方法
    if (widget.isGenerating) {
      return _buildGeneratingCard(context, theme);
    }

    // 正常的已完成图像卡片
    return _buildCompletedCard(context, theme);
  }

  /// 构建生成中状态的卡片
  Widget _buildGeneratingCard(BuildContext context, ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final hasPreview =
        widget.streamPreview != null && widget.streamPreview!.isNotEmpty;

    // 如果有流式预览，显示预览图像
    if (hasPreview) {
      return _buildPreviewCard(primaryColor, surfaceColor, theme);
    }

    // 否则显示加载动画
    return _buildLoadingCard(primaryColor, surfaceColor, theme);
  }

  /// 构建带预览图像的生成中卡片
  Widget _buildPreviewCard(
    Color primaryColor,
    Color surfaceColor,
    ThemeData theme,
  ) {
    final progress = widget.progress ?? 0.0;
    final currentImage = widget.currentImage ?? 0;
    final totalImages = widget.totalImages ?? 0;

    return AnimatedBuilder(
      animation: _glowAnimation ?? const AlwaysStoppedAnimation(0.2),
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(_glowAnimation?.value ?? 0.2),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 流式预览图像
            Image.memory(
              widget.streamPreview!,
              fit: BoxFit.cover,
              gaplessPlayback: true, // 平滑过渡，避免闪烁
            ),
            // 半透明遮罩 + 进度指示
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
            // 底部进度信息
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  // 进度环
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 2,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 进度文字
                  Text(
                    '$currentImage/$totalImages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 百分比
                  if (progress > 0)
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建加载动画卡片（无预览时）
  Widget _buildLoadingCard(
    Color primaryColor,
    Color surfaceColor,
    ThemeData theme,
  ) {
    final progress = widget.progress ?? 0.0;
    final currentImage = widget.currentImage ?? 0;
    final totalImages = widget.totalImages ?? 0;

    return AnimatedBuilder(
      animation: _glowAnimation ?? const AlwaysStoppedAnimation(0.2),
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(_glowAnimation?.value ?? 0.2),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 进度环 + 图标
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    value: progress > 0 ? progress : null,
                    strokeWidth: 2.5,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    color: primaryColor,
                  ),
                ),
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 22,
                  color: primaryColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 当前 / 总数
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  '$currentImage',
                  key: ValueKey(currentImage),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    height: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.25),
                    height: 1,
                  ),
                ),
              ),
              Text(
                '$totalImages',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建已完成状态的卡片
  Widget _buildCompletedCard(BuildContext context, ThemeData theme) {
    final glowColor = _getGlowColor(context);

    // 确保有图像数据
    if (widget.imageBytes == null) {
      return const SizedBox.shrink();
    }

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap ?? widget.onFullscreen,
        onSecondaryTapDown: widget.enableContextMenu
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..scale(widget.enableHoverScale && _isHovering ? 1.03 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 3)
                : (_isHovering
                    ? Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 2,
                      )
                    : null),
            boxShadow: [
              // 主阴影
              BoxShadow(
                color: widget.isSelected
                    ? theme.colorScheme.primary.withOpacity(0.3)
                    : (_isHovering
                        ? Colors.black.withOpacity(0.35)
                        : Colors.black.withOpacity(0.12)),
                blurRadius: widget.isSelected ? 16 : (_isHovering ? 28 : 10),
                offset: Offset(0, _isHovering ? 14 : 4),
                spreadRadius: _isHovering ? 2 : 0,
              ),
              // 次阴影（悬浮时增加深度感）
              if (_isHovering)
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
                // 1. 图片层
                RepaintBoundary(
                  child: Image.memory(
                    widget.imageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),

                // 2. 边缘发光效果（悬浮时）
                if (_isHovering && widget.enableGlossEffect)
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return _EdgeGlowOverlay(
                          glowColor: glowColor,
                          intensity: value,
                        );
                      },
                    ),
                  ),

                // 3. 光泽扫过效果（悬浮时）
                if (_isHovering && widget.enableGlossEffect)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _glossAnimation,
                        builder: (context, child) {
                          return _GlossOverlay(
                            progress: _glossAnimation.value,
                          );
                        },
                      ),
                    ),
                  ),

                // 4. 悬浮/选中时的渐变遮罩（使用 IgnorePointer 让点击穿透）
                if (_isHovering || widget.isSelected)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                // 5. 左上角：选择框（悬浮或选中时显示）
                if (widget.enableSelection &&
                    (_isHovering || widget.isSelected))
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildCheckbox(theme),
                  ),

                // 6. 操作按钮（悬浮时显示）
                if (_isHovering)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: _buildHoverActionBar(context),
                  ),

                // 7. 左下角：序号
                if (widget.showIndex && widget.index != null && !_isHovering)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${widget.index! + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                // 8. 选中覆盖层（使用 IgnorePointer 让点击穿透）
                if (widget.isSelected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 悬浮时底部操作栏
  Widget _buildHoverActionBar(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 保存按钮
            _HoverActionButton(
              icon: Icons.save_alt_rounded,
              tooltip: context.l10n.image_save,
              onTap: () => _saveImage(context),
              isPrimary: true,
            ),
            const SizedBox(width: 6),
            // 复制按钮
            _HoverActionButton(
              icon: Icons.copy_rounded,
              tooltip: context.l10n.image_copy,
              onTap: () => _copyImage(context),
            ),
            // 放大按钮（可选）
            if (widget.onUpscale != null) ...[
              const SizedBox(width: 6),
              _HoverActionButton(
                icon: Icons.zoom_out_map_rounded,
                tooltip: context.l10n.image_upscale,
                onTap: widget.onUpscale,
              ),
            ],
            // 保存到词库按钮（可选）
            if (widget.onSaveToLibrary != null) ...[
              const SizedBox(width: 6),
              _HoverActionButton(
                icon: Icons.bookmark_add_rounded,
                tooltip: context.l10n.image_saveToLibrary,
                onTap: () => _saveToLibrary(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(ThemeData theme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onSelectionChanged?.call(!widget.isSelected);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: widget.isSelected ? theme.colorScheme.primary : Colors.black45,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                widget.isSelected ? theme.colorScheme.primary : Colors.white70,
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
        child: widget.isSelected
            ? Icon(
                Icons.check,
                color: theme.colorScheme.onPrimary,
                size: 18,
              )
            : null,
      ),
    );
  }

  Future<void> _saveImage(BuildContext context) async {
    try {
      // 优先使用设置中的自定义路径
      final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
      Directory saveDir;

      if (saveSettings.hasCustomPath) {
        saveDir = Directory(saveSettings.customPath!);
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        saveDir = Directory('${docDir.path}/NAI_Launcher');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      }

      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(widget.imageBytes!);

      if (context.mounted) {
        AppToast.success(context, '已保存到 ${saveDir.path}');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '保存失败: $e');
      }
    }
  }

  Future<void> _copyImage(BuildContext context) async {
    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
        '${tempDir.path}/NAI_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(widget.imageBytes!);

      // 使用 PowerShell 复制图像到剪贴板
      // 使用 [System.Windows.Forms.Clipboard]::SetImage() 正确复制图像数据
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        'Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; \$image = [System.Drawing.Image]::FromFile("${tempFile.path}"); [System.Windows.Forms.Clipboard]::SetImage(\$image); \$image.Dispose();',
      ]);

      // 检查 PowerShell 命令执行结果
      if (result.exitCode != 0) {
        final errorOutput = result.stderr.toString();
        throw Exception(
            'PowerShell 命令失败 (exitCode: ${result.exitCode}): $errorOutput');
      }

      // 延迟删除临时文件，确保 PowerShell 完成读取
      await Future.delayed(const Duration(milliseconds: 500));

      if (context.mounted) {
        AppToast.success(context, '已复制到剪贴板');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '复制失败: $e');
      }
    } finally {
      // 清理临时文件
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          // 忽略删除错误
        }
      }
    }
  }

  Future<void> _saveToLibrary(BuildContext context) async {
    if (widget.onSaveToLibrary == null || widget.imageBytes == null) return;

    // 调用保存到词库的回调
    widget.onSaveToLibrary!(widget.imageBytes!, '');
  }

  /// 显示右键菜单
  void _showContextMenu(BuildContext context, Offset position) {
    final items = <ProMenuItem>[
      ProMenuItem(
        id: 'save',
        label: '保存图片',
        icon: Icons.save_alt,
        onTap: () => _saveImage(context),
      ),
      ProMenuItem(
        id: 'copy',
        label: '复制图片',
        icon: Icons.copy,
        onTap: () => _copyImage(context),
      ),
      if (widget.onOpenInExplorer != null) ...[
        const ProMenuItem.divider(),
        ProMenuItem(
          id: 'open_folder',
          label: '在文件夹中打开',
          icon: Icons.folder_open,
          onTap: widget.onOpenInExplorer!,
        ),
      ],
    ];

    Navigator.of(context).push(
      _ContextMenuRoute(
        position: position,
        items: items,
        onSelect: (item) {},
      ),
    );
  }
}

/// 右键菜单路由
class _ContextMenuRoute extends PopupRoute {
  final Offset position;
  final List<ProMenuItem> items;
  final void Function(ProMenuItem) onSelect;

  _ContextMenuRoute({
    required this.position,
    required this.items,
    required this.onSelect,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeLeft: true,
      removeRight: true,
      removeBottom: true,
      child: Builder(
        builder: (context) {
          final screenSize = MediaQuery.of(context).size;
          const menuWidth = 180.0;
          final menuHeight = items.where((i) => !i.isDivider).length * 36.0 +
              items.where((i) => i.isDivider).length * 1.0;

          double left = position.dx;
          double top = position.dy;

          if (left + menuWidth > screenSize.width) {
            left = screenSize.width - menuWidth - 16;
          }

          if (top + menuHeight > screenSize.height) {
            top = screenSize.height - menuHeight - 16;
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                ProContextMenu(
                  position: Offset(left, top),
                  items: items,
                  onSelect: (item) {
                    onSelect(item);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
        child: child,
      ),
    );
  }
}

/// 悬浮操作按钮
class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _HoverActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isPrimary
                  ? (_isHovered ? primaryColor : primaryColor.withOpacity(0.9))
                  : (_isHovered
                      ? Colors.white.withOpacity(0.2)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: widget.isPrimary
                  ? Colors.white
                  : (_isHovered ? Colors.white : Colors.white.withOpacity(0.8)),
            ),
          ),
        ),
      ),
    );
  }
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

  const _GlossOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GlossPainter(progress: progress),
      ),
    );
  }
}

/// 光泽绘制器
class _GlossPainter extends CustomPainter {
  final double progress;

  _GlossPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // 主光泽层 - 白色高光
    final mainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.06),
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
          const Color(0xFFB8E6F5).withOpacity(0.03), // 浅青色
          const Color(0xFFFFF5E1).withOpacity(0.05), // 浅金色
          const Color(0xFFE6B8F5).withOpacity(0.03), // 浅紫色
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
    return oldDelegate.progress != progress;
  }
}
