import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../data/models/gallery/local_image_record.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import 'common/app_toast.dart';
import 'prompt/random_manager/components/pro_context_menu.dart';

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
  });

  @override
  State<LocalImageCard> createState() => _LocalImageCardState();
}

class _LocalImageCardState extends State<LocalImageCard> {
  Timer? _longPressTimer;
  bool _isHovering = false;

  // Pinch gesture state
  double _scale = 1.0;
  Offset? _scaleStartPosition;
  bool _showThumbnailPreview = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
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
      ProMenuItem(
        id: 'delete',
        label: '删除图片',
        icon: Icons.delete_outline,
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
  void _showDetailsDialog() {
    final metadata = widget.record.metadata;
    if (metadata == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              constraints:
                  const BoxConstraints(maxWidth: 1400, maxHeight: 1000),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 800;

                  final closeButton = IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                  );

                  if (isDesktop) {
                    return Row(
                      children: [
                        // 左侧：大图预览
                        Expanded(
                          flex: 7,
                          child: Container(
                            color: Colors.black,
                            child: Stack(
                              children: [
                                InteractiveViewer(
                                  minScale: 0.5,
                                  maxScale: 4.0,
                                  child: Center(
                                    child: Image.file(
                                      File(widget.record.path),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 右侧：元数据面板
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                // 标题栏
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '图片详情',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      closeButton,
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                // 滚动内容
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: _buildMetadataContent(
                                      context,
                                      metadata,
                                    ),
                                  ),
                                ),
                                // 底部操作栏
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: metadata.fullPrompt,
                                              ),
                                            );
                                            AppToast.success(
                                              context,
                                              'Prompt 已复制',
                                            );
                                          },
                                          icon: const Icon(Icons.copy),
                                          label: const Text('复制 Prompt'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // 移动端布局
                    return Stack(
                      children: [
                        Column(
                          children: [
                            // 图片区域
                            Expanded(
                              flex: 5,
                              child: Container(
                                color: Colors.black,
                                child: InteractiveViewer(
                                  child: Center(
                                    child: Image.file(
                                      File(widget.record.path),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 元数据区域
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '图片详情',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: metadata.fullPrompt,
                                              ),
                                            );
                                            AppToast.success(
                                              context,
                                              'Prompt 已复制',
                                            );
                                          },
                                          icon:
                                              const Icon(Icons.copy, size: 16),
                                          label: const Text('复制 Prompt'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: _buildMetadataContent(
                                        context,
                                        metadata,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // 浮动关闭按钮
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
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
      },
    );
  }

  /// 复制图片到剪贴板
  Future<void> _copyImage(BuildContext context) async {
    try {
      final sourceFile = File(widget.record.path);

      // 检查源文件是否存在
      if (!await sourceFile.exists()) {
        if (context.mounted) {
          AppToast.error(context, '文件不存在');
        }
        return;
      }

      await Clipboard.setData(const ClipboardData(text: ''));
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/NAI_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(await sourceFile.readAsBytes());

      await Process.run('powershell', [
        '-command',
        'Set-Clipboard -Path "${file.path}"',
      ]);

      if (context.mounted) {
        AppToast.success(context, '已复制到剪贴板');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '复制失败: $e');
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
      await Process.run('explorer', ['/select,"$filePath"']);

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

  Widget _buildMetadataContent(
    BuildContext context,
    NaiImageMetadata metadata,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          context,
          title: '基本信息',
          children: [
            _buildInfoRow(
              context,
              Icons.insert_drive_file_outlined,
              '文件名',
              path.basename(widget.record.path),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              Icons.folder_open_outlined,
              '路径',
              widget.record.path,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              Icons.data_usage,
              '大小',
              '${(widget.record.size / 1024).toStringAsFixed(2)} KB',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              Icons.access_time,
              '修改时间',
              '${timeago.format(widget.record.modifiedAt, locale: Localizations.localeOf(context).languageCode == 'zh' ? 'zh' : 'en')} (${widget.record.modifiedAt.toString().substring(0, 19)})',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          context,
          title: '生成参数',
          children: [
            if (metadata.seed != null) ...[
              _buildInfoRow(
                context,
                Icons.tag,
                'Seed',
                metadata.seed.toString(),
              ),
              const SizedBox(height: 8),
            ],
            if (metadata.steps != null) ...[
              _buildInfoRow(
                context,
                Icons.repeat,
                'Steps',
                metadata.steps.toString(),
              ),
              const SizedBox(height: 8),
            ],
            if (metadata.scale != null) ...[
              _buildInfoRow(
                context,
                Icons.tune,
                'CFG Scale',
                metadata.scale.toString(),
              ),
              const SizedBox(height: 8),
            ],
            if (metadata.sampler != null) ...[
              _buildInfoRow(
                context,
                Icons.shuffle,
                'Sampler',
                metadata.displaySampler,
              ),
              const SizedBox(height: 8),
            ],
            if (metadata.sizeString.isNotEmpty) ...[
              _buildInfoRow(
                context,
                Icons.aspect_ratio,
                '尺寸',
                metadata.sizeString,
              ),
              const SizedBox(height: 8),
            ],
            if (metadata.model != null) ...[
              _buildInfoRow(context, Icons.smart_toy, '模型', metadata.model!),
              const SizedBox(height: 8),
            ],
            if (metadata.smea == true || metadata.smeaDyn == true) ...[
              _buildInfoRow(
                context,
                Icons.auto_awesome,
                'SMEA',
                metadata.smeaDyn == true
                    ? 'DYN'
                    : (metadata.smea == true ? 'ON' : 'OFF'),
              ),
              const SizedBox(height: 8),
            ],
            if (metadata.noiseSchedule != null) ...[
              _buildInfoRow(
                context,
                Icons.waves,
                'Noise Schedule',
                metadata.noiseSchedule!,
              ),
              const SizedBox(height: 8),
            ],
            if (metadata.cfgRescale != null && metadata.cfgRescale! > 0) ...[
              _buildInfoRow(
                context,
                Icons.balance,
                'CFG Rescale',
                metadata.cfgRescale.toString(),
              ),
              const SizedBox(height: 8),
            ],
            // 获取图片实际尺寸
            FutureBuilder<ui.ImageDescriptor>(
              future: _getImageSize(widget.record.path),
              builder: (context, snapshot) {
                if (snapshot.hasData && metadata.sizeString.isEmpty) {
                  return _buildInfoRow(
                    context,
                    Icons.aspect_ratio,
                    '尺寸',
                    '${snapshot.data!.width} x ${snapshot.data!.height}',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          context,
          title: 'Prompt',
          children: [
            SelectableText(
              metadata.fullPrompt.isNotEmpty ? metadata.fullPrompt : '(无)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
            ),
          ],
        ),
        if (metadata.negativePrompt.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            title: '负向提示词 (UC)',
            children: [
              SelectableText(
                metadata.negativePrompt,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.5,
                      color:
                          Theme.of(context).colorScheme.error.withOpacity(0.8),
                    ),
              ),
            ],
          ),
        ],
        if (metadata.rawJson != null) ...[
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            title: '原始 JSON',
            children: [
              SelectableText(
                metadata.rawJson!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<ui.ImageDescriptor> _getImageSize(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    return descriptor;
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side:
            BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.itemWidth * pixelRatio).toInt();
    final metadata = widget.record.metadata;
    // Calculate height dynamically based on aspect ratio, with max height constraint
    final maxHeight = widget.itemWidth * 3;
    final itemHeight = (widget.itemWidth / widget.aspectRatio).clamp(0.0, maxHeight);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
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
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      color: Colors.black.withOpacity(0.1),
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
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                        children: [
                        Image.file(
                          File(widget.record.path),
                          cacheWidth: cacheWidth, // 优化内存占用
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Selection Overlay
            if (widget.selectionMode && widget.isSelected)
              Positioned.fill(
                          child: Container(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                          ),
                        ),
                      // Checkbox
                      if (widget.selectionMode)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.black.withOpacity(0.4),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: widget.isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      if (!widget.selectionMode)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isHovering ? 1.0 : 0.0,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black87],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    path.basename(widget.record.path),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        timeago.format(
                                          widget.record.modifiedAt,
                                          locale:
                                              Localizations.localeOf(context)
                                                          .languageCode ==
                                                      'zh'
                                                  ? 'zh'
                                                  : 'en',
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (metadata?.seed != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          'Seed: ${metadata!.seed}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                      if (metadata?.width != null &&
                                          metadata?.height != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '${metadata?.width} x ${metadata?.height}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (metadata?.prompt.isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        metadata!.prompt,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  // Tags display
                                  if (widget.record.tags.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Wrap(
                                        spacing: 4.0,
                                        runSpacing: 2.0,
                                        children: widget.record.tags
                                            .take(3)
                                            .map((tag) {
                                          final displayTag = tag.length > 15
                                              ? '${tag.substring(0, 15)}...'
                                              : tag;
                                          return Chip(
                                            label: Text(
                                              displayTag,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor:
                                                Colors.white24,
                                            padding: EdgeInsets.zero,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                          );
                                        }).toList(),
                                      ),
                                    )
                                  else
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'No tags',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
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
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
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
          const menuWidth = 200.0;
          final menuHeight = items.length * 48.0;

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
