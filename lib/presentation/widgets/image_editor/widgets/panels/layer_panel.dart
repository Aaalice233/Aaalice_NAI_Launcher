import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show WebViewEnvironment;

import '../../../common/checkerboard_pattern.dart';
import '../../../common/image_viewport_surface.dart';
import '../../../../../core/platform/platform_capabilities.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../core/editor_state.dart';
import '../../layers/layer.dart';
import '../../layers/layer_role.dart';
import '../../layers/model3d_layer_data.dart';
import '../../../../widgets/common/themed_divider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import '../../../model3d_editor/model3d_editor_screen.dart';

/// 图层面板
class LayerPanel extends StatefulWidget {
  final EditorState state;

  const LayerPanel({super.key, required this.state});

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
    // 缩略图只展示取景框内的内容，框变化后同样需要重建
    widget.state.frameNotifier.addListener(_onLayerContentChanged);
    // 初始化时立即更新缩略图
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateThumbnails();
    });
  }

  @override
  void dispose() {
    widget.state.layerManager.removeListener(_onLayerContentChanged);
    widget.state.frameNotifier.removeListener(_onLayerContentChanged);
    _thumbnailUpdateTimer?.cancel();
    super.dispose();
  }

  /// 图层内容变化回调（仅 layerManager.notifyListeners 触发）
  void _onLayerContentChanged() {
    _scheduleThumbnailUpdate();
  }

  /// 调度缩略图更新（带防抖）
  /// 仅在图层内容变化时调用（不在 UI 变化如锁定/重命名时调用）
  /// 使用 500ms 防抖以在图层切换时提供额外安全裕度
  void _scheduleThumbnailUpdate() {
    _thumbnailUpdateTimer?.cancel();
    _thumbnailUpdateTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _updateThumbnails();
      }
    });
  }

  Future<void> _updateThumbnails() async {
    final region = widget.state.frame;
    final layers = widget.state.layerManager.layers;

    // 只获取需要更新的图层
    final layersToUpdate = layers
        .where((layer) => layer.needsThumbnailUpdateFor(region))
        .toList();

    // 如果没有需要更新的图层，直接返回
    if (layersToUpdate.isEmpty) return;

    try {
      // 分批处理，每帧最多处理 2 个缩略图，避免阻塞主线程
      const batchSize = 2;
      for (int i = 0; i < layersToUpdate.length; i += batchSize) {
        if (!mounted) return;

        final batch = layersToUpdate.skip(i).take(batchSize);
        await Future.wait(
          batch.map((layer) => layer.updateThumbnail(region)),
          eagerError: false,
        );

        // 让出主线程一帧，保持 UI 响应
        await Future.delayed(Duration.zero);

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      AppLogger.w('Thumbnail update failed: $e', 'ImageEditor');
    }
  }

  /// Windows 下 WebView2 Runtime 缺失时提前拦截(Win10/11 一般自带)
  Future<bool> _ensureWebView2Available() async {
    if (!PlatformCapabilities.current.isWindows) return true;
    String? version;
    try {
      version = await WebViewEnvironment.getAvailableVersion();
    } catch (_) {
      return true; // 查询本身失败时不拦截,交由编辑器内错误处理兜底
    }
    if (version != null) return true;
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(context.l10n.model3d_webview2Missing),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _onAdd3dLayer() async {
    if (!await _ensureWebView2Available()) return;
    if (!mounted) return;
    // 渲染尺寸等于取景框，结果铺在取景框位置
    final frame = widget.state.frame;
    final result = await Model3dEditorScreen.show(
      context,
      renderWidth: frame.width.round(),
      renderHeight: frame.height.round(),
    );
    if (result == null || !mounted) return;
    final layer = await widget.state.layerCommands.addImageLayer(
      result.pngBytes,
      name: context.l10n.model3d_editorTitle,
      offset: frame.topLeft,
    );
    layer?.model3d = Model3dLayerData(
      modelRef: result.modelRef,
      sceneState: result.sceneState,
    );
  }

  Future<void> _onEdit3dLayer(Layer layer) async {
    final data = layer.model3d;
    if (data == null) return;
    if (!await _ensureWebView2Available()) return;
    if (!mounted) return;
    final frame = widget.state.frame;
    final result = await Model3dEditorScreen.show(
      context,
      existing: data,
      renderWidth: frame.width.round(),
      renderHeight: frame.height.round(),
    );
    if (result == null || !mounted) return;
    await widget.state.layerManager.replaceLayerBaseImage(
      layer.id,
      result.pngBytes,
      offset: layer.baseImageOffset,
    );
    layer.model3d = Model3dLayerData(
      modelRef: result.modelRef,
      sceneState: result.sceneState,
    );
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
        state.layerManager.activeLayerNotifier,
      ]),
      builder: (context, _) {
        final layers = state.layerManager.layers;
        final commands = state.layerCommands;
        final active = state.layerManager.activeLayer;

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
                rolesEnabled: state.rolePolicy.rolesEnabled,
                onAddLayer: (role) {
                  commands.addLayer(
                    name: role == LayerRole.mask
                        ? context.l10n.editor_maskLayerName
                        : context.l10n.editor_layerName(
                            state.layerManager.layerCount + 1,
                          ),
                    role: role,
                  );
                },
                onAdd3dLayer: _onAdd3dLayer,
                onMergeDown: active != null && commands.canMergeDown(active)
                    ? () => commands.mergeDown(active)
                    : null,
              ),

              const ThemedDivider(height: 1),

              // 图层列表：与画布叠放顺序一致，最上层排在最前
              // 使用 RepaintBoundary 隔离整个图层列表，防止父组件更新触发重绘
              Expanded(
                child: RepaintBoundary(
                  child: layers.isEmpty
                      ? Center(
                          child: Text(
                            context.l10n.layer_empty,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: layers.length,
                          onReorderItem: commands.reorder,
                          itemBuilder: (context, index) {
                            final layer = layers[index];
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
                                  showMaskBadge:
                                      state.rolePolicy.rolesEnabled &&
                                      layer.isMask,
                                  onTap: () {
                                    state.layerManager.setActiveLayer(layer.id);
                                  },
                                  onVisibilityToggle: () {
                                    state.layerManager.toggleVisibility(
                                      layer.id,
                                    );
                                  },
                                  onLockToggle: () {
                                    state.layerManager.toggleLock(layer.id);
                                  },
                                  onDelete: commands.canDelete(layer)
                                      ? () => commands.delete(layer)
                                      : null,
                                  onDuplicate: () {
                                    commands.duplicate(
                                      layer,
                                      name: context.l10n.layer_duplicateName(
                                        layer.name,
                                      ),
                                    );
                                  },
                                  onRename: (newName) {
                                    state.layerManager.renameLayer(
                                      layer.id,
                                      newName,
                                    );
                                  },
                                  onOpacityChanged: (opacity) {
                                    state.layerManager.setLayerOpacity(
                                      layer.id,
                                      opacity,
                                    );
                                  },
                                  onDoubleTap: layer.hasModel3d
                                      ? () => _onEdit3dLayer(layer)
                                      : null,
                                  state: state,
                                );
                              },
                            );
                          },
                        ),
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
  final bool rolesEnabled;
  final ValueChanged<LayerRole> onAddLayer;
  final VoidCallback onAdd3dLayer;
  final VoidCallback? onMergeDown;

  const _LayerPanelHeader({
    required this.rolesEnabled,
    required this.onAddLayer,
    required this.onAdd3dLayer,
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
            context.l10n.editor_layers,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // 重绘会话里图片层与蒙版层分开添加
          if (rolesEnabled)
            PopupMenuButton<LayerRole>(
              icon: const Icon(Icons.add, size: 20),
              tooltip: context.l10n.layer_add,
              onSelected: onAddLayer,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: LayerRole.image,
                  child: ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: Text(context.l10n.layer_addImage),
                  ),
                ),
                PopupMenuItem(
                  value: LayerRole.mask,
                  child: ListTile(
                    leading: const Icon(Icons.gesture),
                    title: Text(context.l10n.layer_addMask),
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: context.l10n.layer_add,
              onPressed: () => onAddLayer(LayerRole.image),
              visualDensity: VisualDensity.compact,
            ),
          // 添加 3D 模型图层
          IconButton(
            icon: const Icon(Icons.view_in_ar, size: 20),
            tooltip: context.l10n.model3d_addLayerTooltip,
            onPressed: onAdd3dLayer,
            visualDensity: VisualDensity.compact,
          ),
          // 向下合并
          IconButton(
            icon: const Icon(Icons.merge, size: 20),
            tooltip: context.l10n.layer_mergeDown,
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
  final VoidCallback? onDoubleTap;
  final EditorState state;
  final bool showMaskBadge;

  const _LayerTile({
    required this.layer,
    required this.isActive,
    required this.index,
    this.showThumbnail = false,
    this.showMaskBadge = false,
    required this.onTap,
    required this.onVisibilityToggle,
    required this.onLockToggle,
    this.onDelete,
    required this.onDuplicate,
    required this.onRename,
    required this.onOpacityChanged,
    this.onDoubleTap,
    required this.state,
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
      enabled: context.interactionPolicy.precisePointerAvailable,
      child: Material(
        color: widget.isActive
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onLongPress: () => _showContextMenu(context),
          onSecondaryTap: () => _showContextMenu(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            height: widget.showThumbnail ? 56 : null,
            child: Row(
              children: [
                // 缩略图
                if (widget.showThumbnail) ...[
                  _LayerThumbnail(layer: widget.layer, size: 40),
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
                  tooltip: context.l10n.layer_visibility,
                ),

                // 锁定
                IconButton(
                  icon: Icon(
                    widget.layer.locked ? Icons.lock : Icons.lock_open,
                    size: 18,
                  ),
                  onPressed: widget.onLockToggle,
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.layer_lock,
                ),

                // 图层名称
                Expanded(
                  child: _isEditing
                      ? ThemedInput(
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
                          // 3D 图层(onDoubleTap 非空)双击名字进入 3D 编辑器;
                          // 普通图层保留双击重命名。3D 图层仍可经右键菜单重命名。
                          onDoubleTap:
                              widget.onDoubleTap ??
                              () => setState(() => _isEditing = true),
                          child: Text(
                            widget.layer.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: widget.layer.visible
                                  ? null
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),

                if (widget.showMaskBadge)
                  _LayerBadge(label: context.l10n.layer_roleMask),

                // 3D 模型图层角标
                if (widget.layer.hasModel3d)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('3D', style: theme.textTheme.labelSmall),
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
                  child: const SizedBox.square(
                    dimension: 48,
                    child: Icon(Icons.drag_handle, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) async {
    final theme = Theme.of(context);
    final commands = widget.state.layerCommands;

    final canMoveUp = commands.canMoveUp(widget.layer);
    final canMoveDown = commands.canMoveDown(widget.layer);
    final canMergeDown = commands.canMergeDown(widget.layer);
    final canDelete = widget.onDelete != null;

    // 获取按钮位置用于定位菜单
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // 使用 Rect 定义菜单弹出的锚点位置
    final menuAnchor = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      button.size.width,
      button.size.height,
    );

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(menuAnchor, Offset.zero & screenSize),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        // 复制图层
        PopupMenuItem<String>(
          value: 'duplicate',
          child: Row(
            children: [
              const Icon(Icons.copy_outlined, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.layer_duplicate),
            ],
          ),
        ),

        // 删除图层
        PopupMenuItem<String>(
          value: 'delete',
          enabled: canDelete,
          child: Row(
            children: [
              Icon(
                Icons.delete_outlined,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.layer_delete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),

        // 向下合并
        PopupMenuItem<String>(
          value: 'merge_down',
          enabled: canMergeDown,
          child: Row(
            children: [
              const Icon(Icons.merge_type, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.layer_merge),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // 切换可见性
        PopupMenuItem<String>(
          value: 'toggle_visibility',
          child: Row(
            children: [
              Icon(
                widget.layer.visible ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                widget.layer.visible
                    ? context.l10n.layer_visibility
                    : context.l10n.layer_visibility,
              ),
            ],
          ),
        ),

        // 切换锁定
        PopupMenuItem<String>(
          value: 'toggle_lock',
          child: Row(
            children: [
              Icon(
                widget.layer.locked ? Icons.lock_open : Icons.lock,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                widget.layer.locked
                    ? context.l10n.layer_lock
                    : context.l10n.layer_lock,
              ),
            ],
          ),
        ),

        // 重命名
        PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.layer_rename),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // 上移图层
        PopupMenuItem<String>(
          value: 'move_up',
          enabled: canMoveUp,
          child: Row(
            children: [
              const Icon(Icons.arrow_upward, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.layer_moveUp),
            ],
          ),
        ),

        // 下移图层
        PopupMenuItem<String>(
          value: 'move_down',
          enabled: canMoveDown,
          child: Row(
            children: [
              const Icon(Icons.arrow_downward, size: 18),
              const SizedBox(width: 12),
              Text(context.l10n.layer_moveDown),
            ],
          ),
        ),
      ],
    );

    if (value == null || !mounted) return;

    switch (value) {
      case 'duplicate':
        widget.onDuplicate();
        break;
      case 'delete':
        widget.onDelete?.call();
        break;
      case 'merge_down':
        commands.mergeDown(widget.layer);
        break;
      case 'toggle_visibility':
        widget.onVisibilityToggle();
        break;
      case 'toggle_lock':
        widget.onLockToggle();
        break;
      case 'rename':
        setState(() => _isEditing = true);
        break;
      case 'move_up':
        commands.moveUp(widget.layer);
        break;
      case 'move_down':
        commands.moveDown(widget.layer);
        break;
    }
  }
}

/// 图层名称后的角色角标
class _LayerBadge extends StatelessWidget {
  const _LayerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// 图层缩略图组件
class _LayerThumbnail extends StatelessWidget {
  final Layer layer;
  final double size;

  const _LayerThumbnail({required this.layer, this.size = 40});

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
          color: ImageViewportSurface.background,
          border: Border.all(color: theme.dividerColor, width: 1),
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
              : _buildPlaceholder(context, theme),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, ThemeData theme) {
    // 检查是否有内容
    if (layer.hasContent) {
      // 有内容但缩略图还没生成，显示加载指示
      return Center(
        child: SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    // 空图层，显示透明网格图案
    return CustomPaint(
      painter: _TransparentGridPainter(
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
    );
  }
}

/// 透明网格绘制器（棋盘格图案）
class _TransparentGridPainter extends CustomPainter {
  static final CheckerboardPattern _pattern = CheckerboardPattern(
    cellSize: 5,
    evenColor: Colors.white,
    oddColor: Colors.grey.shade300,
  );

  final double devicePixelRatio;

  const _TransparentGridPainter({required this.devicePixelRatio});

  @override
  void paint(Canvas canvas, Size size) {
    _pattern.paint(canvas, Offset.zero & size, pixelScale: devicePixelRatio);
  }

  @override
  bool shouldRepaint(_TransparentGridPainter oldDelegate) =>
      oldDelegate.devicePixelRatio != devicePixelRatio;
}
