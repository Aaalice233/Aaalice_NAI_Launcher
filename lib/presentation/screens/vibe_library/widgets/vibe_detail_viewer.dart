import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference_v4.dart';

/// Vibe 详情页回调函数
class VibeDetailCallbacks {
  /// 发送到生成页面回调
  final void Function(
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
  )? onSendToGeneration;

  /// 导出回调
  final void Function(VibeLibraryEntry entry)? onExport;

  /// 删除回调
  final void Function(VibeLibraryEntry entry)? onDelete;

  /// 重命名回调，返回错误信息（null 表示成功）
  final Future<String?> Function(VibeLibraryEntry entry, String newName)?
      onRename;

  /// 参数更新回调（可选，用于保存调整后的参数）
  final void Function(
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
  )? onParamsChanged;

  const VibeDetailCallbacks({
    this.onSendToGeneration,
    this.onExport,
    this.onDelete,
    this.onRename,
    this.onParamsChanged,
  });
}

/// Vibe 详情查看器
///
/// 功能特性:
/// - 大图预览（使用 InteractiveViewer 支持缩放）
/// - Strength 滑块调整（0.0 - 1.0）
/// - Info Extracted 滑块调整（0.0 - 1.0）
/// - 发送到生成、导出、删除操作按钮
/// - 桌面端左右分栏布局
class VibeDetailViewer extends StatefulWidget {
  /// Vibe 条目数据
  final VibeLibraryEntry entry;

  /// 回调函数
  final VibeDetailCallbacks? callbacks;

  /// Hero 标签
  final String? heroTag;

  const VibeDetailViewer({
    super.key,
    required this.entry,
    this.callbacks,
    this.heroTag,
  });

  /// 显示 Vibe 详情查看器
  static Future<void> show(
    BuildContext context, {
    required VibeLibraryEntry entry,
    VibeDetailCallbacks? callbacks,
    String? heroTag,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => VibeDetailViewer(
        entry: entry,
        callbacks: callbacks,
        heroTag: heroTag,
      ),
    );
  }

  @override
  State<VibeDetailViewer> createState() => _VibeDetailViewerState();
}

class _VibeDetailViewerState extends State<VibeDetailViewer> {
  late VibeLibraryEntry _entry;
  late double _strength;
  late double _infoExtracted;
  bool _isRenaming = false;
  final TransformationController _transformationController =
      TransformationController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _strength = _entry.strength;
    _infoExtracted = _entry.infoExtracted;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _updateStrength(double value) {
    setState(() => _strength = value);
  }

  void _updateInfoExtracted(double value) {
    setState(() => _infoExtracted = value);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.2).clamp(0.5, 4.0);
    _applyScale(newScale);
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.2).clamp(0.5, 4.0);
    _applyScale(newScale);
  }

  void _applyScale(double scale) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width * 0.3; // 左侧 60% 的中心
    final centerY = screenSize.height / 2;

    final matrix = Matrix4.identity()
      ..translate(centerX - centerX * scale, centerY - centerY * scale)
      ..scale(scale);

    _transformationController.value = matrix;
  }

  void _sendToGeneration() {
    widget.callbacks?.onSendToGeneration
        ?.call(_entry, _strength, _infoExtracted);
    Navigator.of(context).pop();
  }

  void _export() {
    widget.callbacks?.onExport?.call(_entry);
  }

  void _delete() {
    widget.callbacks?.onDelete?.call(_entry);
    Navigator.of(context).pop();
  }

  Future<void> _rename() async {
    final callback = widget.callbacks?.onRename;
    if (callback == null || _isRenaming) {
      return;
    }

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _entry.displayName);
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            void validate(String value) {
              final trimmed = value.trim();
              setState(() {
                if (trimmed.isEmpty) {
                  errorText = '名称不能为空';
                } else {
                  errorText = null;
                }
              });
            }

            return AlertDialog(
              title: const Text('重命名 Vibe'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '输入新名称',
                  errorText: errorText,
                ),
                onChanged: validate,
                onSubmitted: (value) {
                  final trimmed = value.trim();
                  if (trimmed.isNotEmpty) {
                    Navigator.of(context).pop(trimmed);
                  } else {
                    validate(value);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final trimmed = controller.text.trim();
                    if (trimmed.isEmpty) {
                      validate(controller.text);
                      return;
                    }
                    Navigator.of(context).pop(trimmed);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || newName == null) {
      return;
    }

    final trimmedName = newName.trim();
    if (trimmedName == _entry.displayName) {
      return;
    }

    setState(() {
      _isRenaming = true;
    });

    final errorMessage = await callback(_entry, trimmedName);

    if (!mounted) {
      return;
    }

    setState(() {
      _isRenaming = false;
      if (errorMessage == null) {
        _entry = _entry.copyWith(name: trimmedName);
      }
    });

    final messenger = ScaffoldMessenger.of(context);
    if (errorMessage == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('重命名成功')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }

  void _close() {
    // 如果参数有变化，通知回调
    if (_strength != _entry.strength ||
        _infoExtracted != _entry.infoExtracted) {
      widget.callbacks?.onParamsChanged
          ?.call(_entry, _strength, _infoExtracted);
    }
    Navigator.of(context).pop();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        _close();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.equal: // + key
      case LogicalKeyboardKey.add:
        _zoomIn();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.minus: // - key
      case LogicalKeyboardKey.underscore:
        _zoomOut();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.digit0:
        _resetZoom();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  Uint8List? get _imageBytes {
    // 优先使用原始图片数据，其次使用缩略图
    return _entry.rawImageData ?? _entry.thumbnail ?? _entry.vibeThumbnail;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: isDesktop
              ? Row(
                  children: [
                    // 左侧：大图预览（60%）
                    Expanded(
                      flex: 6,
                      child: _buildImageViewer(),
                    ),
                    // 右侧：参数面板（40%）
                    SizedBox(
                      width: screenWidth * 0.4,
                      child: _buildParamPanel(context),
                    ),
                  ],
                )
              : Column(
                  children: [
                    // 上方：大图预览
                    Expanded(
                      flex: 6,
                      child: _buildImageViewer(),
                    ),
                    // 下方：参数面板
                    Expanded(
                      flex: 4,
                      child: _buildParamPanel(context),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// 构建图片查看器
  Widget _buildImageViewer() {
    final imageBytes = _imageBytes;

    return Stack(
      children: [
        // 图片预览区域
        GestureDetector(
          onDoubleTap: _resetZoom,
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: imageBytes != null
                  ? Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        AppLogger.e('Failed to load image', error, stackTrace);
                        return _buildPlaceholder();
                      },
                    )
                  : _buildPlaceholder(),
            ),
          ),
        ),

        // 顶部关闭按钮
        Positioned(
          top: 16,
          right: 16,
          child: _buildIconButton(
            icon: Icons.close,
            onPressed: _close,
            tooltip: '关闭 (Esc)',
          ),
        ),

        // 缩放控制按钮
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconButton(
                icon: Icons.add,
                onPressed: _zoomIn,
                tooltip: '放大 (+)',
              ),
              const SizedBox(height: 8),
              _buildIconButton(
                icon: Icons.remove,
                onPressed: _zoomOut,
                tooltip: '缩小 (-)',
              ),
              const SizedBox(height: 8),
              _buildIconButton(
                icon: Icons.fit_screen,
                onPressed: _resetZoom,
                tooltip: '重置缩放 (0)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建占位符
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              '无预览图像',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建参数面板
  Widget _buildParamPanel(BuildContext context) {
    final theme = Theme.of(context);
    final isRawImage = _entry.sourceType == VibeSourceType.rawImage;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _entry.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _buildSourceTypeChip(theme),
                    ],
                  ),
                ),
                // 收藏状态
                IconButton(
                  icon: Icon(
                    _entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _entry.isFavorite ? Colors.red : null,
                  ),
                  onPressed: null, // 详情页只显示状态，不切换
                  tooltip: _entry.isFavorite ? '已收藏' : '未收藏',
                ),
              ],
            ),
          ),

          // 参数滑块区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reference Strength 滑块
                  _buildSliderSection(
                    context,
                    label: 'Reference Strength',
                    value: _strength,
                    onChanged: _updateStrength,
                    description: '控制 Vibe 对生成结果的影响强度',
                  ),

                  const SizedBox(height: 24),

                  // Information Extracted 滑块（仅原始图片）
                  if (isRawImage)
                    _buildSliderSection(
                      context,
                      label: 'Information Extracted',
                      value: _infoExtracted,
                      onChanged: _updateInfoExtracted,
                      description: '控制从原始图片提取的信息量（消耗 2 Anlas）',
                    ),

                  const SizedBox(height: 24),

                  // 统计信息
                  _buildStatsSection(theme),
                ],
              ),
            ),
          ),

          // 操作按钮区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 发送到生成按钮
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sendToGeneration,
                    icon: const Icon(Icons.send),
                    label: const Text('发送到生成'),
                  ),
                ),
                const SizedBox(height: 12),
                // 导出和删除按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isRenaming ? null : _rename,
                        icon: _isRenaming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.drive_file_rename_outline),
                        label: const Text('重命名'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _export,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('导出'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建源类型标签
  Widget _buildSourceTypeChip(ThemeData theme) {
    final isPreEncoded = _entry.isPreEncoded;
    final color = isPreEncoded ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPreEncoded ? Icons.check_circle_outline : Icons.warning_amber,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            _entry.sourceType.displayLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isPreEncoded) ...[
            const SizedBox(width: 4),
            Text(
              '(2 Anlas)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建滑块区域
  Widget _buildSliderSection(
    BuildContext context, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required String description,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value.toStringAsFixed(2),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
            thumbColor: theme.colorScheme.primary,
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['0.0', '0.5', '1.0']
              .map(
                (v) => Text(
                  v,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// 构建统计信息区域
  Widget _buildStatsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '统计信息',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatRow(theme, '使用次数', '${_entry.usedCount} 次'),
          _buildStatRow(
            theme,
            '最后使用',
            _entry.lastUsedAt != null
                ? _formatDateTime(_entry.lastUsedAt!)
                : '从未使用',
          ),
          _buildStatRow(theme, '创建时间', _formatDateTime(_entry.createdAt)),
          if (_entry.tags.isNotEmpty)
            _buildStatRow(theme, '标签', _entry.tags.join(', ')),
        ],
      ),
    );
  }

  /// 构建统计行
  Widget _buildStatRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inDays > 6) {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
    if (diff.inDays > 1) return '${diff.inDays} 天前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inHours > 0) return '${diff.inHours} 小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes} 分钟前';
    return '刚刚';
  }

  /// 构建图标按钮
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
