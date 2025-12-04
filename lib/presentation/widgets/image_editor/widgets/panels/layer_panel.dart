import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/editor_state.dart';
import '../../layers/layer.dart';

/// 图层面板
class LayerPanel extends StatefulWidget {
  final EditorState state;

  const LayerPanel({
    super.key,
    required this.state,
  });

  @override
  State<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends State<LayerPanel> {
  /// 缩略图更新防抖计时器
  Timer? _thumbnailUpdateTimer;

  @override
  void initState() {
    super.initState();
    // 监听图层内容变化（用于触发缩略图更新）
    widget.state.layerManager.addListener(_onLayerContentChanged);
    // 初始化时立即更新缩略图
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateThumbnails();
    });
  }

  @override
  void dispose() {
    widget.state.layerManager.removeListener(_onLayerContentChanged);
    _thumbnailUpdateTimer?.cancel();
    super.dispose();
  }

  /// 图层内容变化回调（仅 layerManager.notifyListeners 触发）
  void _onLayerContentChanged() {
    _scheduleThumbnailUpdate();
  }

  /// 调度缩略图更新（带防抖）
  /// 仅在图层内容变化时调用（不在 UI 变化如锁定/重命名时调用）
  void _scheduleThumbnailUpdate() {
    _thumbnailUpdateTimer?.cancel();
    _thumbnailUpdateTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _updateThumbnails();
      }
    });
  }

  Future<void> _updateThumbnails() async {
    final canvasSize = widget.state.canvasSize;
    final layers = widget.state.layerManager.layers;

    // 只获取需要更新的图层
    final layersToUpdate = layers.where((layer) => layer.needsThumbnailUpdate).toList();

    // 如果没有需要更新的图层，直接返回
    if (layersToUpdate.isEmpty) return;

    try {
      // 分批处理，每帧最多处理 2 个缩略图，避免阻塞主线程
      const batchSize = 2;
      for (int i = 0; i < layersToUpdate.length; i += batchSize) {
        if (!mounted) return;

        final batch = layersToUpdate.skip(i).take(batchSize);
        await Future.wait(
          batch.map((layer) => layer.updateThumbnail(canvasSize)),
          eagerError: false,
        );

        // 让出主线程一帧，保持 UI 响应
        await Future.delayed(Duration.zero);

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('缩略图更新失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;

    // 监听 layerManager（图层列表变化）和 uiUpdateNotifier（锁定/重命名等UI变化）
    // 活动图层变化通过 ValueListenableBuilder 在每个 tile 中单独监听
    return ListenableBuilder(
      listenable: Listenable.merge([
        state.layerManager,
        state.layerManager.uiUpdateNotifier,
      ]),
      builder: (context, _) {
        final layers = state.layerManager.layers;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              left: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题栏
              _LayerPanelHeader(
                onAddLayer: () {
                  state.layerManager.addLayer();
                },
                onMergeDown: state.layerManager.layers.length > 1
                    ? () => state.layerManager.mergeDown()
                    : null,
              ),

              const Divider(height: 1),

              // 图层列表
              Expanded(
                child: layers.isEmpty
                    ? Center(
                        child: Text(
                          '无图层',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        // Krita 风格：顶部图层在列表顶部
                        itemCount: layers.length,
                        onReorder: (oldIndex, newIndex) {
                          // UI索引转换为实际图层索引
                          // UI index 0 = 顶部图层 = layers[length-1]
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final actualOldIndex = layers.length - 1 - oldIndex;
                          final actualNewIndex = layers.length - 1 - newIndex;
                          state.layerManager.reorderLayer(
                            actualOldIndex,
                            actualNewIndex,
                          );
                        },
                        itemBuilder: (context, index) {
                          // UI index 0 = 顶部图层 = layers[length-1]
                          final actualIndex = layers.length - 1 - index;
                          final layer = layers[actualIndex];
                          // 使用 layer.isActiveNotifier 单独监听活动状态
                          // 切换活动图层时仅重建新旧活动图层的 tile（O(1)），而非所有图层（O(n)）
                          return ValueListenableBuilder<bool>(
                            key: ValueKey(layer.id),
                            valueListenable: layer.isActiveNotifier,
                            builder: (context, isActive, _) {
                              return _LayerTile(
                                layer: layer,
                                isActive: isActive,
                                index: index,
                                showThumbnail: true,
                                onTap: () {
                                  state.layerManager.setActiveLayer(layer.id);
                                },
                                onVisibilityToggle: () {
                                  state.layerManager.toggleVisibility(layer.id);
                                },
                                onLockToggle: () {
                                  state.layerManager.toggleLock(layer.id);
                                },
                                onDelete: layers.length > 1
                                    ? () => state.layerManager.removeLayer(layer.id)
                                    : null,
                                onDuplicate: () {
                                  state.layerManager.duplicateLayer(layer.id);
                                },
                                onRename: (newName) {
                                  state.layerManager.renameLayer(layer.id, newName);
                                },
                                onOpacityChanged: (opacity) {
                                  state.layerManager.setLayerOpacity(layer.id, opacity);
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 图层面板头部
class _LayerPanelHeader extends StatelessWidget {
  final VoidCallback onAddLayer;
  final VoidCallback? onMergeDown;

  const _LayerPanelHeader({
    required this.onAddLayer,
    this.onMergeDown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text(
            '图层',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // 添加图层
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: '添加图层',
            onPressed: onAddLayer,
            visualDensity: VisualDensity.compact,
          ),
          // 向下合并
          IconButton(
            icon: const Icon(Icons.merge, size: 20),
            tooltip: '向下合并',
            onPressed: onMergeDown,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// 图层列表项
class _LayerTile extends StatefulWidget {
  final Layer layer;
  final bool isActive;
  final int index;
  final bool showThumbnail;
  final VoidCallback onTap;
  final VoidCallback onVisibilityToggle;
  final VoidCallback onLockToggle;
  final VoidCallback? onDelete;
  final VoidCallback onDuplicate;
  final ValueChanged<String> onRename;
  final ValueChanged<double> onOpacityChanged;

  const _LayerTile({
    super.key,
    required this.layer,
    required this.isActive,
    required this.index,
    this.showThumbnail = false,
    required this.onTap,
    required this.onVisibilityToggle,
    required this.onLockToggle,
    this.onDelete,
    required this.onDuplicate,
    required this.onRename,
    required this.onOpacityChanged,
  });

  @override
  State<_LayerTile> createState() => _LayerTileState();
}

class _LayerTileState extends State<_LayerTile>
    with AutomaticKeepAliveClientMixin {
  bool _isEditing = false;
  late TextEditingController _nameController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.layer.name);
  }

  @override
  void didUpdateWidget(_LayerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 图层名称变化时同步更新控制器（非编辑状态下）
    if (oldWidget.layer.name != widget.layer.name && !_isEditing) {
      _nameController.text = widget.layer.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 必须调用
    final theme = Theme.of(context);

    return ReorderableDragStartListener(
      index: widget.index,
      child: Material(
        color: widget.isActive
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: () => _showContextMenu(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            height: widget.showThumbnail ? 56 : null,
            child: Row(
              children: [
                // 缩略图
                if (widget.showThumbnail) ...[
                  _LayerThumbnail(
                    layer: widget.layer,
                    size: 40,
                  ),
                  const SizedBox(width: 8),
                ],

                // 可见性
                IconButton(
                  icon: Icon(
                    widget.layer.visible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    size: 18,
                  ),
                  onPressed: widget.onVisibilityToggle,
                  visualDensity: VisualDensity.compact,
                  tooltip: '可见性',
                ),

                // 锁定
                IconButton(
                  icon: Icon(
                    widget.layer.locked ? Icons.lock : Icons.lock_open,
                    size: 18,
                  ),
                  onPressed: widget.onLockToggle,
                  visualDensity: VisualDensity.compact,
                  tooltip: '锁定',
                ),

                // 图层名称
                Expanded(
                  child: _isEditing
                      ? TextField(
                          controller: _nameController,
                          autofocus: true,
                          style: theme.textTheme.bodySmall,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (value) {
                            widget.onRename(value);
                            setState(() => _isEditing = false);
                          },
                          onEditingComplete: () {
                            widget.onRename(_nameController.text);
                            setState(() => _isEditing = false);
                          },
                        )
                      : GestureDetector(
                          onDoubleTap: () {
                            setState(() => _isEditing = true);
                          },
                          child: Text(
                            widget.layer.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: widget.layer.visible
                                  ? null
                                  : theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),

                // 不透明度指示
                if (widget.layer.opacity < 1.0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '${(widget.layer.opacity * 100).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),

                // 拖动手柄
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Icon(Icons.drag_handle, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _LayerContextMenu(
        layer: widget.layer,
        onDelete: widget.onDelete,
        onDuplicate: widget.onDuplicate,
        onRename: () {
          Navigator.pop(context);
          setState(() => _isEditing = true);
        },
        onOpacityChanged: widget.onOpacityChanged,
      ),
    );
  }
}

/// 图层上下文菜单
class _LayerContextMenu extends StatefulWidget {
  final Layer layer;
  final VoidCallback? onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onRename;
  final ValueChanged<double> onOpacityChanged;

  const _LayerContextMenu({
    required this.layer,
    this.onDelete,
    required this.onDuplicate,
    required this.onRename,
    required this.onOpacityChanged,
  });

  @override
  State<_LayerContextMenu> createState() => _LayerContextMenuState();
}

class _LayerContextMenuState extends State<_LayerContextMenu> {
  late double _opacity;

  @override
  void initState() {
    super.initState();
    _opacity = widget.layer.opacity;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.layer.name,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 不透明度滑块
          Row(
            children: [
              const Text('不透明度'),
              Expanded(
                child: Slider(
                  value: _opacity,
                  onChanged: (value) {
                    setState(() => _opacity = value);
                    widget.onOpacityChanged(value);
                  },
                ),
              ),
              Text('${(_opacity * 100).round()}%'),
            ],
          ),

          const SizedBox(height: 16),

          // 操作按钮
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onRename();
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('重命名'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDuplicate();
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制'),
              ),
              if (widget.onDelete != null)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete!();
                  },
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('删除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 图层缩略图组件
class _LayerThumbnail extends StatelessWidget {
  final Layer layer;
  final double size;

  const _LayerThumbnail({
    required this.layer,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = layer.thumbnail;

    // 使用 RepaintBoundary 隔离缩略图渲染，避免父级重建时触发重绘
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: theme.dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: thumbnail != null
              ? RawImage(
                  image: thumbnail,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                )
              : _buildPlaceholder(theme),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    // 检查是否有内容
    if (layer.hasContent) {
      // 有内容但缩略图还没生成，显示加载指示
      return Center(
        child: SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
        ),
      );
    }

    // 空图层，显示透明网格图案
    return CustomPaint(
      painter: _TransparentGridPainter(
        gridSize: 5,
        color1: Colors.white,
        color2: Colors.grey.shade300,
      ),
    );
  }
}

/// 透明网格绘制器（棋盘格图案）
class _TransparentGridPainter extends CustomPainter {
  final double gridSize;
  final Color color1;
  final Color color2;

  _TransparentGridPainter({
    required this.gridSize,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    for (double y = 0; y < size.height; y += gridSize) {
      for (double x = 0; x < size.width; x += gridSize) {
        final isEven = ((x / gridSize).floor() + (y / gridSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, gridSize, gridSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
