import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../data/models/gallery/local_image_record.dart';
import '../providers/local_gallery_provider.dart';
import '../utils/image_detail_opener.dart';
import 'common/app_toast.dart';
import 'common/animated_favorite_button.dart';
import 'common/image_detail/image_detail_data.dart';
import 'common/image_detail/image_detail_viewer.dart';
import 'common/pro_context_menu.dart';

/// 本地图片卡片组件（支持右键菜单和长按）
class LocalImageCard extends StatefulWidget {
  final LocalImageRecord record;
  final double itemWidth;
  final double aspectRatio;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleted;
  final void Function(LocalImageRecord)? onReuseMetadata;
  final void Function(LocalImageRecord)? onSendToImg2Img;
  final void Function(LocalImageRecord)? onFavoriteToggle;

  const LocalImageCard({
    super.key,
    required this.record,
    required this.itemWidth,
    required this.aspectRatio,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
    this.onLongPress,
    this.onDeleted,
    this.onReuseMetadata,
    this.onSendToImg2Img,
    this.onFavoriteToggle,
  });

  @override
  State<LocalImageCard> createState() => _LocalImageCardState();
}

class _LocalImageCardState extends State<LocalImageCard>
    with AutomaticKeepAliveClientMixin {
  Timer? _longPressTimer;

  // Pinch gesture state
  double _scale = 1.0;
  Offset? _scaleStartPosition;
  bool _showThumbnailPreview = false;

  /// 是否已预缓存详情图片
  bool _isPrecached = false;

  @override
  bool get wantKeepAlive => true; // 保持状态，避免翻页回来后重新加载

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  /// 预缓存详情图片
  ///
  /// 在鼠标悬停时预加载图片，提升点击后的响应速度
  void _precacheDetailImage() {
    if (_isPrecached) return;
    _isPrecached = true;

    // 异步预加载，不阻塞 UI
    precacheImage(
      FileImage(File(widget.record.path)),
      context,
    ).catchError((_) {
      // 忽略预加载错误
    });
  }

  /// 显示上下文菜单
  void _showContextMenu([Offset? position]) {
    final metadata = widget.record.metadata;

    if (metadata == null || !metadata.hasData) {
      AppToast.warning(context, '此图片无元数据');
      return;
    }

    final menuPosition = position ?? const Offset(100, 100);

    final items = <ProMenuItem>[
      ProMenuItem(
        id: 'copy_prompt',
        label: '复制 Prompt',
        icon: Icons.content_copy,
        onTap: () {
          Clipboard.setData(ClipboardData(text: metadata.fullPrompt));
          if (mounted) {
            AppToast.success(context, 'Prompt 已复制');
          }
        },
      ),
      if (metadata.negativePrompt.isNotEmpty)
        ProMenuItem(
          id: 'copy_negative',
          label: '复制负向提示词',
          icon: Icons.content_copy_outlined,
          onTap: () {
            Clipboard.setData(ClipboardData(text: metadata.negativePrompt));
            if (mounted) {
              AppToast.success(context, '负向提示词已复制');
            }
          },
        ),
      if (metadata.seed != null)
        ProMenuItem(
          id: 'copy_seed',
          label: '复制 Seed',
          icon: Icons.tag,
          onTap: () {
            Clipboard.setData(ClipboardData(text: metadata.seed.toString()));
            if (mounted) {
              AppToast.success(context, 'Seed 已复制');
            }
          },
        ),
      ProMenuItem(
        id: 'copy_image',
        label: '复制图片',
        icon: Icons.copy,
        onTap: () {
          if (mounted) {
            _copyImage(context);
          }
        },
      ),
      const ProMenuItem.divider(),
      // 复用数据
      if (widget.onReuseMetadata != null)
        ProMenuItem(
          id: 'reuse_metadata',
          label: '复用数据',
          icon: Icons.replay,
          onTap: () {
            widget.onReuseMetadata?.call(widget.record);
          },
        ),
      // 发送到图生图
      if (widget.onSendToImg2Img != null)
        ProMenuItem(
          id: 'send_to_img2img',
          label: '发送到图生图',
          icon: Icons.image_outlined,
          onTap: () {
            widget.onSendToImg2Img?.call(widget.record);
          },
        ),
      if (widget.onReuseMetadata != null || widget.onSendToImg2Img != null)
        const ProMenuItem.divider(),
      ProMenuItem(
        id: 'open_file',
        label: '在文件管理器中打开',
        icon: Icons.folder_open,
        onTap: () {
          if (mounted) {
            _openInFileManager(context);
          }
        },
      ),
      ProMenuItem(
        id: 'share',
        label: '分享图片',
        icon: Icons.share,
        onTap: () {
          if (mounted) {
            _shareImage(context);
          }
        },
      ),
      ProMenuItem(
        id: 'details',
        label: '查看详情',
        icon: Icons.info_outline,
        onTap: () {
          if (mounted) {
            _showDetailsDialog();
          }
        },
      ),
      const ProMenuItem.divider(),
      ProMenuItem(
        id: 'delete',
        label: '删除图片',
        icon: Icons.delete_outline,
        isDanger: true,
        onTap: () {
          if (mounted) {
            _showDeleteConfirmationDialog();
          }
        },
      ),
    ];

    Navigator.of(context).push(
      _ContextMenuRoute(
        position: menuPosition,
        items: items,
        onSelect: (item) {
          // Item onTap is already called
        },
      ),
    );
  }

  /// 显示详情对话框
  ///
  /// 使用统一的 ImageDetailViewer 组件显示图片详情
  void _showDetailsDialog() {
    // 使用 ImageDetailOpener 打开详情页（带防重复点击）
    ImageDetailOpener.showSingleImmediate(
      context,
      image: LocalImageDetailData(
        widget.record,
        getFavoriteStatus: (_) => widget.record.isFavorite,
      ),
      showMetadataPanel: true,
      callbacks: ImageDetailCallbacks(
        onFavoriteToggle: widget.onFavoriteToggle != null
            ? (image) => widget.onFavoriteToggle!(widget.record)
            : null,
        onReuseMetadata: widget.onReuseMetadata != null
            ? (image, options) {
                widget.onReuseMetadata!(widget.record);
              }
            : null,
      ),
      heroTag: 'local_image_${widget.record.path.hashCode}',
    );
  }

  /// 复制图片到剪贴板
  Future<void> _copyImage(BuildContext context) async {
    File? tempFile;
    try {
      final sourceFile = File(widget.record.path);

      // 检查源文件是否存在
      if (!await sourceFile.exists()) {
        if (context.mounted) {
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
        throw Exception('PowerShell 命令失败 (exitCode: ${result.exitCode}): $errorOutput');
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

  /// 在文件管理器中打开
  Future<void> _openInFileManager(BuildContext context) async {
    try {
      final filePath = widget.record.path;
      final file = File(filePath);

      // 检查文件是否存在
      if (!await file.exists()) {
        if (context.mounted) {
          AppToast.error(context, '文件不存在');
        }
        return;
      }

      // 使用 explorer /select 打开文件管理器并选中文件
      // 使用 Process.start 避免等待进程完成导致的延迟
      await Process.start('explorer', ['/select,"$filePath"']);

      if (context.mounted) {
        AppToast.success(context, '已在文件管理器中打开');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '打开失败: $e');
      }
    }
  }

  /// 分享图片
  Future<void> _shareImage(BuildContext context) async {
    try {
      final filePath = widget.record.path;
      final file = File(filePath);

      // 检查文件是否存在
      if (!await file.exists()) {
        if (context.mounted) {
          AppToast.error(context, '文件不存在');
        }
        return;
      }

      // 使用 Share.shareXFiles 分享文件
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '分享图片',
      );

      if (context.mounted) {
        AppToast.success(context, '分享成功');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '分享失败: $e');
      }
    }
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除图片「${path.basename(widget.record.path)}」吗？\n\n此操作将从文件系统中永久删除该图片，无法恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteImage();
    }
  }

  /// 删除图片
  Future<void> _deleteImage() async {
    try {
      final file = File(widget.record.path);

      // 检查文件是否存在
      if (!await file.exists()) {
        if (mounted) {
          AppToast.error(context, '文件不存在');
        }
        return;
      }

      // 删除文件
      await file.delete();

      if (mounted) {
        AppToast.success(context, '图片已删除');
        // 通知父组件刷新
        widget.onDeleted?.call();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '删除失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 需要调用
    
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.itemWidth * pixelRatio).toInt();
    // Calculate height dynamically based on aspect ratio, with max height constraint
    final maxHeight = widget.itemWidth * 3;
    final itemHeight =
        (widget.itemWidth / widget.aspectRatio).clamp(0.0, maxHeight);

    return RepaintBoundary(
      child: MouseRegion(
        cursor: widget.selectionMode
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        // 鼠标悬停时预缓存详情图片
        onEnter: (_) => _precacheDetailImage(),
        child: GestureDetector(
          // 点击
          onTap: () {
            if (widget.selectionMode) {
              widget.onSelectionToggle?.call();
            } else {
              _showDetailsDialog();
            }
          },

          // 桌面端：右键菜单
          onSecondaryTapDown: (details) {
            if (!widget.selectionMode) {
              _showContextMenu(details.globalPosition);
            }
          },

          // 移动端：长按
          onLongPressStart: (details) {
            if (!widget.selectionMode) {
              _longPressTimer = Timer(const Duration(milliseconds: 500), () {
                // 如果提供了 onLongPress 回调（进入多选），则执行它
                // 否则显示上下文菜单
                if (widget.onLongPress != null) {
                  widget.onLongPress!();
                } else {
                  _showContextMenu(details.globalPosition);
                }
              });
            }
          },
          onLongPressEnd: (details) {
            _longPressTimer?.cancel();
          },
          onLongPressCancel: () {
            _longPressTimer?.cancel();
          },

          // 双击缩放
          onDoubleTap: () {
            if (!widget.selectionMode) {
              _showDetailsDialog();
            }
          },

          // Pinch 缩放手势 - 显示缩略图预览
          onScaleStart: (details) {
            if (!widget.selectionMode && details.pointerCount > 1) {
              setState(() {
                _scale = 1.0;
                _scaleStartPosition = details.localFocalPoint;
                _showThumbnailPreview = true;
              });
            }
          },
          onScaleUpdate: (details) {
            if (_showThumbnailPreview) {
              setState(() {
                _scale = details.scale;
              });
            }
          },
          onScaleEnd: (details) {
            if (_showThumbnailPreview) {
              // 如果缩放足够大，打开详情页
              if (_scale > 1.5) {
                _showDetailsDialog();
              }
              setState(() {
                _showThumbnailPreview = false;
                _scale = 1.0;
                _scaleStartPosition = null;
              });
            }
          },

          child: Stack(
            children: [
              SizedBox(
                width: widget.itemWidth,
                height: itemHeight,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                        color: Colors.black.withOpacity(0.12),
                      ),
                    ],
                    border: widget.isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          )
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.file(
                          File(widget.record.path),
                          cacheWidth: cacheWidth, // 优化内存占用
                          fit: BoxFit.cover,
                          width: double.infinity,
                          gaplessPlayback: true, // 防止图片切换时闪白
                          frameBuilder:
                              (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded) return child;
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: frame != null
                                  ? child
                                  : _ImagePlaceholder(
                                      width: widget.itemWidth,
                                      aspectRatio: widget.aspectRatio,
                                    ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _ImageError(
                              width: widget.itemWidth,
                              aspectRatio: widget.aspectRatio,
                            );
                          },
                        ),
                        // Vibe badge - 显示在右上角
                        if (widget.record.hasVibeMetadata)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.8),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Selection Overlay and Checkbox
              if (widget.selectionMode)
                _SelectionIndicator(
                  isSelected: widget.isSelected,
                ),
              // Hover overlay (only shown when not in selection mode)
              if (!widget.selectionMode)
                _HoverOverlay(
                  record: widget.record,
                  onFavoriteToggle: widget.onFavoriteToggle != null
                      ? () => widget.onFavoriteToggle!(widget.record)
                      : null,
                ),
              // Pinch 缩略图预览 overlay
              if (_showThumbnailPreview && _scaleStartPosition != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Transform.scale(
                        scale: _scale.clamp(0.8, 2.0),
                        child: Container(
                          width: widget.itemWidth * 0.8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(widget.record.path),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 图片加载占位符（带 shimmer 效果）
class _ImagePlaceholder extends StatelessWidget {
  final double width;
  final double aspectRatio;

  const _ImagePlaceholder({
    required this.width,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width / aspectRatio,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}

/// 图片加载错误显示
class _ImageError extends StatelessWidget {
  final double width;
  final double aspectRatio;

  const _ImageError({
    required this.width,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width / aspectRatio,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Selection indicator widget
/// This widget handles the selection visual feedback independently
class _SelectionIndicator extends StatefulWidget {
  final bool isSelected;

  const _SelectionIndicator({
    required this.isSelected,
  });

  @override
  State<_SelectionIndicator> createState() => _SelectionIndicatorState();
}

class _SelectionIndicatorState extends State<_SelectionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _SelectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Selection Overlay
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primary.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Checkbox
        Positioned(
          top: 8,
          right: 8,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isSelected
                    ? colorScheme.primary
                    : Colors.black.withOpacity(0.5),
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
                size: 18,
                color: widget.isSelected
                    ? colorScheme.onPrimary
                    : Colors.transparent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hover overlay widget with separate state management
/// This prevents hover state changes from causing the entire card to rebuild
class _HoverOverlay extends ConsumerStatefulWidget {
  final LocalImageRecord record;
  final VoidCallback? onFavoriteToggle;

  const _HoverOverlay({
    required this.record,
    this.onFavoriteToggle,
  });

  @override
  ConsumerState<_HoverOverlay> createState() => _HoverOverlayState();
}

class _HoverOverlayState extends ConsumerState<_HoverOverlay> {
  bool _isHovering = false;

  /// 构建收藏按钮
  Widget _buildFavoriteButton() {
    // 从 provider 获取最新的收藏状态
    final galleryState = ref.watch(localGalleryNotifierProvider);
    final currentRecord = galleryState.currentImages
        .cast<LocalImageRecord?>()
        .firstWhere(
          (img) => img?.path == widget.record.path,
          orElse: () => null,
        );
    final isFavorite = currentRecord?.isFavorite ?? widget.record.isFavorite;
    
    // 只有在悬浮或已收藏时才显示
    if (!_isHovering && !isFavorite) {
      return const SizedBox.shrink();
    }
    
    return CardFavoriteButton(
      isFavorite: isFavorite,
      onToggle: widget.onFavoriteToggle,
      size: 18,
    );
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.record.metadata;
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        children: [
          // 主体内容
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.identity()..scale(_isHovering ? 1.02 : 1.0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: _isHovering
                  ? Border.all(
                      color: colorScheme.primary.withOpacity(0.25),
                      width: 2,
                    )
                  : null,
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _isHovering ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1.0],
                  ),
                ),
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.basename(widget.record.path),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            timeago.format(
                              widget.record.modifiedAt,
                              locale: Localizations.localeOf(context)
                                          .languageCode ==
                                      'zh'
                                  ? 'zh'
                                  : 'en',
                            ),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (metadata?.seed != null && metadata!.seed! > 0) ...[
                          Text(
                            ' | ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '${metadata.seed}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                        if (metadata?.width != null &&
                            metadata?.height != null) ...[
                          Text(
                            ' | ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${metadata?.width}x${metadata?.height}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (metadata?.prompt.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          metadata!.prompt,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // Tags display
                    if (widget.record.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Wrap(
                          spacing: 4.0,
                          runSpacing: 4.0,
                          children: widget.record.tags.take(3).map((tag) {
                            final displayTag = tag.length > 12
                                ? '${tag.substring(0, 12)}...'
                                : tag;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                displayTag,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // 右上角收藏按钮（悬浮时或已收藏时显示）
          if (widget.onFavoriteToggle != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                // 拦截点击事件，防止冒泡到父级 GestureDetector 打开详情
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: _buildFavoriteButton(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom route for displaying ProContextMenu
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
          // Calculate adjusted position to keep menu within screen bounds
          final screenSize = MediaQuery.of(context).size;
          const menuWidth = 180.0;
          final menuHeight = items.where((i) => !i.isDivider).length * 36.0 +
              items.where((i) => i.isDivider).length * 1.0;

          double left = position.dx;
          double top = position.dy;

          // Adjust horizontal position if menu goes off screen
          if (left + menuWidth > screenSize.width) {
            left = screenSize.width - menuWidth - 16;
          }

          // Adjust vertical position if menu goes off screen
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
