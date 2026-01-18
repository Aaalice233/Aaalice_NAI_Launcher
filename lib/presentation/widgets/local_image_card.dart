import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:timeago/timeago.dart' as timeago;

import '../../data/models/gallery/local_image_record.dart';

/// 本地图片卡片组件（支持右键菜单和长按）
class LocalImageCard extends StatefulWidget {
  final LocalImageRecord record;
  final double itemWidth;

  const LocalImageCard({
    super.key,
    required this.record,
    required this.itemWidth,
  });

  @override
  State<LocalImageCard> createState() => _LocalImageCardState();
}

class _LocalImageCardState extends State<LocalImageCard> {
  Timer? _longPressTimer;
  bool _isHovering = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  /// 显示上下文菜单
  void _showContextMenu([Offset? position]) {
    final metadata = widget.record.metadata;

    if (metadata == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此图片无元数据')),
      );
      return;
    }

    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    showMenu(
      context: context,
      position: position != null
          ? RelativeRect.fromRect(
              position & const Size(40, 40),
              Offset.zero & overlay!.size,
            )
          : const RelativeRect.fromLTRB(100, 100, 100, 100),
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.content_copy, size: 18),
              SizedBox(width: 8),
              Text('复制 Prompt'),
            ],
          ),
          onTap: () {
            final prompt = metadata.displayName;
            Clipboard.setData(ClipboardData(text: prompt));
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prompt 已复制')),
                );
              }
            });
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.tag, size: 18),
              SizedBox(width: 8),
              Text('复制 Seed'),
            ],
          ),
          onTap: () {
            final seed = metadata.strength.toString();
            Clipboard.setData(ClipboardData(text: seed));
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seed 已复制')),
                );
              }
            });
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18),
              SizedBox(width: 8),
              Text('查看详情'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _showDetailsDialog();
              }
            });
          },
        ),
      ],
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
              constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 1000),
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
                  
                  // 顶部操作栏（仅移动端显示，桌面端在右侧面板）
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '图片详情',
                                        style: Theme.of(context).textTheme.titleLarge,
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
                                    child: _buildMetadataContent(context, metadata),
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
                                            Clipboard.setData(ClipboardData(text: metadata.displayName));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Prompt 已复制')),
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
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '图片详情',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: metadata.displayName));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Prompt 已复制')),
                                            );
                                          },
                                          icon: const Icon(Icons.copy, size: 16),
                                          label: const Text('复制 Prompt'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: _buildMetadataContent(context, metadata),
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
                              icon: const Icon(Icons.close, color: Colors.white),
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

  Widget _buildMetadataContent(BuildContext context, dynamic metadata) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          context,
          title: '基本信息',
          children: [
            _buildInfoRow(context, Icons.insert_drive_file_outlined, '文件名', path.basename(widget.record.path)),
            const SizedBox(height: 8),
            _buildInfoRow(context, Icons.folder_open_outlined, '路径', widget.record.path),
            const SizedBox(height: 8),
            _buildInfoRow(context, Icons.data_usage, '大小', '${(widget.record.size / 1024).toStringAsFixed(2)} KB'),
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
            _buildInfoRow(context, Icons.tune, 'Strength', metadata.strength.toString()),
            const SizedBox(height: 8),
            // 尝试获取图片尺寸 (异步)
            FutureBuilder<ui.ImageDescriptor>(
              future: _getImageSize(widget.record.path),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
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
              metadata.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<ui.ImageDescriptor> _getImageSize(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    return descriptor;
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
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

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        // 点击查看详情
        onTap: () {
          _showDetailsDialog();
        },

        // 桌面端：右键菜单
        onSecondaryTapDown: (details) {
          _showContextMenu(details.globalPosition);
        },

        // 移动端：长按菜单（500ms 阈值）
        onLongPressStart: (details) {
          _longPressTimer = Timer(const Duration(milliseconds: 500), () {
            _showContextMenu(details.globalPosition);
          });
        },
        onLongPressEnd: (details) {
          _longPressTimer?.cancel();
        },
        onLongPressCancel: () {
          _longPressTimer?.cancel();
        },

        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片 + 悬停叠加层
              Stack(
                children: [
                  Image.file(
                    File(widget.record.path),
                    cacheWidth: cacheWidth, // 优化内存占用
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48),
                        ),
                      );
                    },
                  ),
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
                            Text(
                              timeago.format(
                                widget.record.modifiedAt,
                                locale: Localizations.localeOf(context).languageCode == 'zh' ? 'zh' : 'en',
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                            if (widget.record.metadata?.displayName != null)
                              Text(
                                widget.record.metadata!.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
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
}
