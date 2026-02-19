import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shortcuts/default_shortcuts.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../providers/vibe_library_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/shortcuts/shortcut_aware_widget.dart';
import 'vibe_detail/bundle_gallery_strip.dart';
import 'vibe_detail/vibe_detail_background.dart';
import 'vibe_detail/vibe_detail_param_panel.dart';
import 'vibe_detail/vibe_preview_drop_zone.dart';

/// Vibe 详情页回调函数
class VibeDetailCallbacks {
  /// 发送到生成页面回调
  final void Function(
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
    bool isShiftPressed,
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

/// 沉浸式毛玻璃 Vibe 详情查看器
///
/// 重构特性：
/// - 沉浸式模糊背景（VibeDetailBackground）
/// - 毛玻璃参数面板（VibeDetailParamPanel）
/// - Bundle 画廊条（BundleGalleryStrip）
/// - 预览图拖拽设置（VibePreviewDropZone）
/// - 统一快捷键管理（ShortcutAwareWidget）
/// - 收藏/标签/缩略图直接通过 Provider 操作
class VibeDetailViewer extends ConsumerStatefulWidget {
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
      barrierColor: Colors.transparent,
      builder: (context) => VibeDetailViewer(
        entry: entry,
        callbacks: callbacks,
        heroTag: heroTag,
      ),
    );
  }

  @override
  ConsumerState<VibeDetailViewer> createState() => _VibeDetailViewerState();
}

class _VibeDetailViewerState extends ConsumerState<VibeDetailViewer> {
  late VibeLibraryEntry _entry;
  late double _strength;
  late double _infoExtracted;
  bool _isRenaming = false;

  /// Bundle: 当前选中的子 vibe 索引（-1 表示"使用全部"）
  int _selectedSubVibeIndex = -1;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _strength = _entry.strength;
    _infoExtracted = _entry.infoExtracted;
  }

  // ============================================================
  // 图片数据
  // ============================================================

  Uint8List? get _imageBytes {
    // Bundle 模式：选中子 vibe 时显示对应缩略图
    if (_entry.isBundle && _selectedSubVibeIndex >= 0) {
      final previews = _entry.bundledVibePreviews;
      if (previews != null && _selectedSubVibeIndex < previews.length) {
        return previews[_selectedSubVibeIndex];
      }
    }
    return _entry.rawImageData ?? _entry.thumbnail ?? _entry.vibeThumbnail;
  }

  // ============================================================
  // 操作方法
  // ============================================================

  void _sendToGeneration() {
    // 检测是否按住 Shift 键
    final physicalKeys = HardwareKeyboard.instance.physicalKeysPressed;
    final isShiftPressed = physicalKeys.contains(PhysicalKeyboardKey.shiftLeft) ||
        physicalKeys.contains(PhysicalKeyboardKey.shiftRight);

    widget.callbacks?.onSendToGeneration?.call(
      _entry,
      _strength,
      _infoExtracted,
      isShiftPressed,
    );
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
    if (callback == null || _isRenaming) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _entry.displayName);
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            void validate(String value) {
              setState(() {
                errorText = value.trim().isEmpty ? '名称不能为空' : null;
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

    if (!mounted || newName == null) return;
    if (newName == _entry.displayName) return;

    setState(() => _isRenaming = true);

    final errorMessage = await callback(_entry, newName);

    if (!mounted) return;

    setState(() {
      _isRenaming = false;
      if (errorMessage == null) {
        _entry = _entry.copyWith(name: newName);
      }
    });

    if (errorMessage == null) {
      AppToast.success(context, '重命名成功');
    } else {
      AppToast.error(context, errorMessage);
    }
  }

  Future<void> _toggleFavorite() async {
    final updated = await ref
        .read(vibeLibraryNotifierProvider.notifier)
        .toggleFavorite(_entry.id);
    if (updated != null && mounted) {
      setState(() => _entry = updated);
    }
  }

  Future<void> _updateTags(List<String> tags) async {
    final updated = await ref
        .read(vibeLibraryNotifierProvider.notifier)
        .updateEntryTags(_entry.id, tags);
    if (updated != null && mounted) {
      setState(() => _entry = updated);
    }
  }

  Future<void> _handleThumbnailChanged(Uint8List thumbnail) async {
    final updated = await ref
        .read(vibeLibraryNotifierProvider.notifier)
        .updateEntryThumbnail(_entry.id, thumbnail);
    if (updated != null && mounted) {
      setState(() => _entry = updated);
    }
  }

  void _setSubVibeAsCover(int index) {
    final previews = _entry.bundledVibePreviews;
    if (previews == null || index >= previews.length) return;
    _handleThumbnailChanged(previews[index]);
  }

  void _close() {
    if (_strength != _entry.strength ||
        _infoExtracted != _entry.infoExtracted) {
      widget.callbacks?.onParamsChanged
          ?.call(_entry, _strength, _infoExtracted);
    }
    Navigator.of(context).pop();
  }

  void _prevSubVibe() {
    if (!_entry.isBundle) return;
    setState(() {
      if (_selectedSubVibeIndex > -1) {
        _selectedSubVibeIndex--;
      }
    });
  }

  void _nextSubVibe() {
    if (!_entry.isBundle) return;
    final maxIndex = (_entry.bundledVibeNames?.length ?? 1) - 1;
    setState(() {
      if (_selectedSubVibeIndex < maxIndex) {
        _selectedSubVibeIndex++;
      }
    });
  }

  // ============================================================
  // 构建
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 800;
    final isBundle = _entry.isBundle;

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: ShortcutAwareWidget(
        contextType: ShortcutContext.vibeDetail,
        autofocus: true,
        shortcuts: {
          ShortcutIds.vibeDetailSendToGeneration: _sendToGeneration,
          ShortcutIds.vibeDetailExport: _export,
          ShortcutIds.vibeDetailRename: _rename,
          ShortcutIds.vibeDetailDelete: _delete,
          ShortcutIds.vibeDetailToggleFavorite: _toggleFavorite,
          ShortcutIds.vibeDetailPrevSubVibe: _prevSubVibe,
          ShortcutIds.vibeDetailNextSubVibe: _nextSubVibe,
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: 纯黑色背景
            const VibeDetailBackground(),

            // Layer 2: 主内容区（Bundle 时为画廊条预留底部空间）
            SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: isBundle ? 100.0 : 0.0),
                child: isDesktop
                    ? _buildDesktopLayout()
                    : _buildMobileLayout(),
              ),
            ),

            // Layer 3: Bundle 画廊条（仅 Bundle）
            if (isBundle)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: BundleGalleryStrip(
                    vibeNames: _entry.bundledVibeNames ?? [],
                    vibePreviews: _entry.bundledVibePreviews,
                    selectedIndex: _selectedSubVibeIndex,
                    onSelected: (index) =>
                        setState(() => _selectedSubVibeIndex = index),
                    onLongPressSetCover: _setSubVibeAsCover,
                    onUseAll: () =>
                        setState(() => _selectedSubVibeIndex = -1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 桌面端布局：左 60% 预览 + 右 40% 参数面板
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: VibePreviewDropZone(
            imageBytes: _imageBytes,
            onThumbnailChanged: _handleThumbnailChanged,
            onClose: _close,
          ),
        ),
        Expanded(
          flex: 4,
          child: _buildParamPanel(),
        ),
      ],
    );
  }

  /// 移动端布局：上下分栏
  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: VibePreviewDropZone(
            imageBytes: _imageBytes,
            onThumbnailChanged: _handleThumbnailChanged,
            onClose: _close,
          ),
        ),
        Expanded(
          flex: 4,
          child: _buildParamPanel(),
        ),
      ],
    );
  }

  Widget _buildParamPanel() {
    return VibeDetailParamPanel(
      entry: _entry,
      strength: _strength,
      infoExtracted: _infoExtracted,
      onStrengthChanged: (v) => setState(() => _strength = v),
      onInfoExtractedChanged: (v) => setState(() => _infoExtracted = v),
      onSendToGeneration: _sendToGeneration,
      onExport: _export,
      onDelete: _delete,
      onRename: _rename,
      onToggleFavorite: _toggleFavorite,
      onTagsChanged: _updateTags,
      isRenaming: _isRenaming,
    );
  }
}
