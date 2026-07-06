import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shortcuts/default_shortcuts.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
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
    bool isShiftPressed, {
    required bool applyParamOverrides,
    int? bundleChildParamOverrideIndex,
  })?
  onSendToGeneration;

  /// 导出回调
  final void Function(VibeLibraryEntry entry)? onExport;

  /// 删除回调
  final void Function(VibeLibraryEntry entry)? onDelete;

  /// 重命名回调，返回错误信息（null 表示成功）
  final Future<String?> Function(VibeLibraryEntry entry, String newName)?
  onRename;

  /// 显式保存参数回调（仅在用户点击保存时触发）
  final Future<VibeLibraryEntry?> Function(
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
    int? bundleChildIndex,
  )?
  onSaveParams;

  const VibeDetailCallbacks({
    this.onSendToGeneration,
    this.onExport,
    this.onDelete,
    this.onRename,
    this.onSaveParams,
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
  List<double>? _bundleStrengths;
  List<double>? _bundleInfoExtracted;
  final Map<int, Uint8List> _bundleChildRawImageBytes = {};
  final Set<int> _bundleChildImageLoads = {};
  bool _isRenaming = false;
  bool _isSavingParams = false;

  /// Bundle: 当前选中的子 vibe 索引（-1 表示"使用全部"）
  int _selectedSubVibeIndex = -1;

  bool get _hasParamChanges {
    if (_entry.isBundle) {
      final index = _selectedSubVibeIndex;
      final strengths = _bundleStrengths;
      final infoExtracted = _bundleInfoExtracted;
      if (index < 0 ||
          strengths == null ||
          infoExtracted == null ||
          index >= strengths.length ||
          index >= infoExtracted.length) {
        return false;
      }

      final savedStrengths = _entry.bundledVibeStrengths;
      final savedInfoExtracted = _entry.bundledVibeInfoExtracted;
      final savedStrength =
          savedStrengths != null && index < savedStrengths.length
          ? savedStrengths[index]
          : _entry.strength;
      final savedInfo =
          savedInfoExtracted != null && index < savedInfoExtracted.length
          ? savedInfoExtracted[index]
          : _entry.infoExtracted;
      return strengths[index] != savedStrength ||
          infoExtracted[index] != savedInfo;
    }
    return _strength != _entry.strength ||
        _infoExtracted != _entry.infoExtracted;
  }

  bool get _canPersistParamChanges {
    if (_entry.isBundle) return _selectedSubVibeIndex >= 0;
    final infoChanged = _infoExtracted != _entry.infoExtracted;
    if (!infoChanged) return true;
    return _entry.canReencodeFromRawSource;
  }

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _hydrateBundleParamCache(_entry);
    _selectFirstBundleChildIfNeeded();
    _syncDisplayedParamsWithSelection();
    unawaited(_loadSelectedBundleImage());
    unawaited(_loadActualEntry());
  }

  void _hydrateBundleParamCache(VibeLibraryEntry entry) {
    if (!entry.isBundle) {
      _bundleStrengths = null;
      _bundleInfoExtracted = null;
      return;
    }

    final names = entry.bundledVibeNames ?? const <String>[];
    if (names.isEmpty) {
      _bundleStrengths = null;
      _bundleInfoExtracted = null;
      return;
    }

    final strengths = entry.bundledVibeStrengths;
    final infoExtracted = entry.bundledVibeInfoExtracted;

    _bundleStrengths = List<double>.generate(names.length, (index) {
      final value = strengths != null && index < strengths.length
          ? strengths[index]
          : entry.strength;
      return VibeReference.sanitizeStrength(value);
    }, growable: false);

    _bundleInfoExtracted = List<double>.generate(names.length, (index) {
      final value = infoExtracted != null && index < infoExtracted.length
          ? infoExtracted[index]
          : entry.infoExtracted;
      return VibeReference.sanitizeInfoExtracted(value);
    }, growable: false);
  }

  void _selectFirstBundleChildIfNeeded() {
    if (!_entry.isBundle || _selectedSubVibeIndex >= 0) return;
    final names = _entry.bundledVibeNames;
    if (names != null && names.isNotEmpty) {
      _selectedSubVibeIndex = 0;
    }
  }

  void _syncDisplayedParamsWithSelection() {
    final selectedIndex = _selectedSubVibeIndex;
    final strengths = _bundleStrengths;
    final infoExtracted = _bundleInfoExtracted;
    final hasSelectedBundleItem =
        _entry.isBundle &&
        selectedIndex >= 0 &&
        strengths != null &&
        infoExtracted != null &&
        selectedIndex < strengths.length &&
        selectedIndex < infoExtracted.length;

    if (hasSelectedBundleItem) {
      _strength = strengths[selectedIndex];
      _infoExtracted = infoExtracted[selectedIndex];
      return;
    }

    _strength = _entry.strength;
    _infoExtracted = _entry.infoExtracted;
  }

  void _selectSubVibeIndex(int index) {
    if (!_entry.isBundle) return;
    final maxIndex = (_entry.bundledVibeNames?.length ?? 1) - 1;
    final clampedIndex = index.clamp(-1, maxIndex);
    setState(() {
      _selectedSubVibeIndex = clampedIndex;
      _syncDisplayedParamsWithSelection();
    });
    unawaited(_loadSelectedBundleImage());
  }

  void _onStrengthChanged(double value) {
    setState(() {
      if (_entry.isBundle &&
          _selectedSubVibeIndex >= 0 &&
          _bundleStrengths != null &&
          _selectedSubVibeIndex < _bundleStrengths!.length) {
        final updatedStrengths = List<double>.from(_bundleStrengths!);
        updatedStrengths[_selectedSubVibeIndex] =
            VibeReference.sanitizeStrength(value);
        _bundleStrengths = updatedStrengths;
      }
      _strength = VibeReference.sanitizeStrength(value);
    });
  }

  void _onInfoExtractedChanged(double value) {
    setState(() {
      if (_entry.isBundle &&
          _selectedSubVibeIndex >= 0 &&
          _bundleInfoExtracted != null &&
          _selectedSubVibeIndex < _bundleInfoExtracted!.length) {
        final updatedInfoExtracted = List<double>.from(_bundleInfoExtracted!);
        updatedInfoExtracted[_selectedSubVibeIndex] =
            VibeReference.sanitizeInfoExtracted(value);
        _bundleInfoExtracted = updatedInfoExtracted;
      }
      _infoExtracted = VibeReference.sanitizeInfoExtracted(value);
    });
  }

  // ============================================================
  // 图片数据
  // ============================================================

  Uint8List? get _imageBytes {
    // Bundle 模式：主预览优先使用子 Vibe 原图，底部画廊条才使用缩略图。
    if (_entry.isBundle && _selectedSubVibeIndex >= 0) {
      final loadedRaw = _bundleChildRawImageBytes[_selectedSubVibeIndex];
      if (loadedRaw != null && loadedRaw.isNotEmpty) {
        return loadedRaw;
      }

      if (_selectedSubVibeIndex == 0) {
        final firstRaw = _entry.rawImageData;
        if (firstRaw != null && firstRaw.isNotEmpty) {
          return firstRaw;
        }
      }

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
    final isShiftPressed =
        physicalKeys.contains(PhysicalKeyboardKey.shiftLeft) ||
        physicalKeys.contains(PhysicalKeyboardKey.shiftRight);

    widget.callbacks?.onSendToGeneration?.call(
      _entry,
      _strength,
      _infoExtracted,
      isShiftPressed,
      applyParamOverrides: _hasParamChanges,
      bundleChildParamOverrideIndex: _entry.isBundle
          ? _selectedSubVibeIndex
          : null,
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
                errorText = value.trim().isEmpty
                    ? context.l10n.vibe_nameRequired
                    : null;
              });
            }

            return AlertDialog(
              title: Text(context.l10n.shortcut_action_vibe_detail_rename),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.vibe_saveToLibrary_nameHint,
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
                  child: Text(context.l10n.common_cancel),
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
                  child: Text(context.l10n.common_confirm),
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
      AppToast.success(context, context.l10n.toast_renameSuccess);
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

  void _close() => Navigator.of(context).pop();

  Future<void> _saveParams() async {
    final callback = widget.callbacks?.onSaveParams;
    if (callback == null || !_hasParamChanges || !_canPersistParamChanges) {
      return;
    }

    setState(() => _isSavingParams = true);
    try {
      final updatedEntry = await callback(
        _entry,
        _strength,
        _infoExtracted,
        _entry.isBundle ? _selectedSubVibeIndex : null,
      );
      if (!mounted) return;

      if (updatedEntry != null) {
        setState(() {
          _entry = updatedEntry;
          _hydrateBundleParamCache(updatedEntry);
          _syncDisplayedParamsWithSelection();
        });
        AppToast.success(context, context.l10n.toast_paramsSaved);
      } else {
        AppToast.error(context, context.l10n.toast_paramsSaveFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingParams = false);
      }
    }
  }

  Future<void> _loadActualEntry() async {
    final actualEntry = await ref
        .read(vibeLibraryStorageServiceProvider)
        .getEntry(_entry.id);
    if (!mounted || actualEntry == null) return;
    setState(() {
      _entry = actualEntry;
      final maxIndex = (_entry.bundledVibeNames?.length ?? 1) - 1;
      if (_selectedSubVibeIndex > maxIndex) {
        _selectedSubVibeIndex = maxIndex >= 0 ? 0 : -1;
      }
      _hydrateBundleParamCache(actualEntry);
      _selectFirstBundleChildIfNeeded();
      _syncDisplayedParamsWithSelection();
    });
    unawaited(_loadSelectedBundleImage());
  }

  Future<void> _loadSelectedBundleImage() async {
    if (!_entry.isBundle || _selectedSubVibeIndex < 0) return;

    final index = _selectedSubVibeIndex;
    if (_bundleChildRawImageBytes.containsKey(index) ||
        _bundleChildImageLoads.contains(index)) {
      return;
    }

    _bundleChildImageLoads.add(index);
    final entryId = _entry.id;
    final childVibe = await ref
        .read(vibeLibraryStorageServiceProvider)
        .loadBundleChildVibe(entryId, index);

    _bundleChildImageLoads.remove(index);
    if (!mounted || _entry.id != entryId) return;

    final rawImageData = childVibe?.rawImageData;
    if (rawImageData == null || rawImageData.isEmpty) return;

    setState(() {
      _bundleChildRawImageBytes[index] = rawImageData;
    });
  }

  void _prevSubVibe() {
    if (!_entry.isBundle) return;
    if (_selectedSubVibeIndex <= -1) return;
    _selectSubVibeIndex(_selectedSubVibeIndex - 1);
  }

  void _nextSubVibe() {
    if (!_entry.isBundle) return;
    final maxIndex = (_entry.bundledVibeNames?.length ?? 1) - 1;
    if (_selectedSubVibeIndex >= maxIndex) return;
    _selectSubVibeIndex(_selectedSubVibeIndex + 1);
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
                child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
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
                    onSelected: _selectSubVibeIndex,
                    onLongPressSetCover: _setSubVibeAsCover,
                    onUseAll: () => _selectSubVibeIndex(-1),
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
        Expanded(flex: 4, child: _buildParamPanel()),
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
        Expanded(flex: 4, child: _buildParamPanel()),
      ],
    );
  }

  Widget _buildParamPanel() {
    final bundleParamHint = _entry.isBundle
        ? _selectedSubVibeIndex >= 0
              ? 'Showing import parameters for child Vibe ${_selectedSubVibeIndex + 1}.'
              : 'Showing Bundle default parameters. Click a child item below to view its parameters.'
        : null;

    return VibeDetailParamPanel(
      entry: _entry,
      strength: _strength,
      infoExtracted: _infoExtracted,
      onStrengthChanged: _onStrengthChanged,
      onInfoExtractedChanged: _onInfoExtractedChanged,
      onSendToGeneration: _sendToGeneration,
      onExport: _export,
      onDelete: _delete,
      onRename: _rename,
      onToggleFavorite: _toggleFavorite,
      onTagsChanged: _updateTags,
      isRenaming: _isRenaming,
      onSaveParams: _saveParams,
      canSaveParams: _hasParamChanges && _canPersistParamChanges,
      showInfoExtractedControl:
          _entry.isBundle || _entry.canReencodeFromRawSource,
      parametersEditable: !_entry.isBundle || _selectedSubVibeIndex >= 0,
      parameterHint: bundleParamHint,
      isSavingParams: _isSavingParams,
    );
  }
}
