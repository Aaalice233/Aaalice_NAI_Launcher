import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/mosaic/mosaic_derivative_registry.dart';
import '../../../core/mosaic/mosaic_render_service.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/services/android_media_store_service.dart';
import '../../../core/services/native_share_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_save_utils.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/mosaic/mosaic_settings.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/mosaic_settings_provider.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../widgets/image_editor/widgets/color_picker.dart';
import 'mosaic_editor_canvas.dart';

class MosaicEditorSource {
  const MosaicEditorSource({
    required this.bytes,
    required this.fileName,
    this.path,
  });

  final Uint8List bytes;
  final String fileName;
  final String? path;
}

class MosaicEditorScreen extends ConsumerStatefulWidget {
  const MosaicEditorScreen({
    super.key,
    required this.sourceBytes,
    required this.sourceFileName,
    required this.defaultsOnly,
    this.sourcePath,
    this.onChooseSource,
  });

  final Uint8List sourceBytes;
  final String sourceFileName;
  final String? sourcePath;
  final bool defaultsOnly;
  final Future<MosaicEditorSource?> Function()? onChooseSource;

  @override
  ConsumerState<MosaicEditorScreen> createState() =>
      _MosaicEditorScreenState();
}

class _MosaicEditorScreenState extends ConsumerState<MosaicEditorScreen> {
  final _previewFocusNode = FocusNode(debugLabel: 'mosaic preview');
  final _undo = <_MosaicSnapshot>[];
  final _redo = <_MosaicSnapshot>[];
  MosaicCancellationToken? _renderToken;

  late MosaicSettings _settings;
  late MosaicSettings _initialSettings;
  late List<MosaicRegion> _regions;
  late List<MosaicRegion> _initialRegions;
  late MosaicShape _drawShape;
  String? _selectedId;
  late Uint8List _sourceBytes;
  late String _sourceFileName;
  String? _sourcePath;
  ui.Image? _sourceImage;
  ui.Image? _processedImage;
  bool _loading = true;
  bool _processingPreview = false;
  bool _saving = false;
  Object? _loadError;
  int _processedEpoch = 0;
  int _regionSequence = 0;

  @override
  void initState() {
    super.initState();
    _sourceBytes = widget.sourceBytes;
    _sourceFileName = widget.sourceFileName;
    _sourcePath = widget.sourcePath;
    final state = ref.read(mosaicSettingsProvider);
    _settings = state.configuration;
    _initialSettings = _settings;
    _drawShape = _settings.defaultShape;
    _regions = <MosaicRegion>[_newCenteredRegion()];
    _initialRegions = List<MosaicRegion>.of(_regions);
    _selectedId = _regions.first.id;
    unawaited(_loadImage());
  }

  @override
  void dispose() {
    _renderToken?.cancel();
    _processedEpoch++;
    _previewFocusNode.dispose();
    _processedImage?.dispose();
    _sourceImage?.dispose();
    super.dispose();
  }

  String _nextRegionId() =>
      'redaction_${DateTime.now().microsecondsSinceEpoch}_${_regionSequence++}';

  MosaicRegion _newCenteredRegion({MosaicShape? shape}) {
    final resolvedShape = shape ??
        (_settings.defaultShape == MosaicShape.brush
            ? MosaicShape.roundedRectangle
            : _settings.defaultShape);
    return MosaicRegion(
      id: _nextRegionId(),
      left: 0.33,
      top: 0.39,
      width: 0.34,
      height: 0.18,
      shape: resolvedShape,
      brushSizeRatio: _settings.brushSizeRatio,
    );
  }

  Future<void> _loadImage() async {
    try {
      final source = await _decodeSingleFrame(
        _sourceBytes,
        requireStatic: true,
      );
      if (!mounted) {
        source.dispose();
        return;
      }
      final previousSource = _sourceImage;
      final previousProcessed = _processedImage;
      setState(() {
        _sourceImage = source;
        _processedImage = null;
        _loading = false;
        _loadError = null;
      });
      previousSource?.dispose();
      previousProcessed?.dispose();
      await _refreshProcessedImage();
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to load redaction source image',
        error,
        stackTrace,
        'MosaicEditor',
      );
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<ui.Image> _decodeSingleFrame(
    Uint8List bytes, {
    bool requireStatic = false,
  }) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longestEdge = math.max(descriptor.width, descriptor.height);
      const previewEdgeLimit = 2048;
      final scale = longestEdge > previewEdgeLimit
          ? previewEdgeLimit / longestEdge
          : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      if (requireStatic && codec.frameCount != 1) {
        throw const MosaicRenderException(
          'Choose a static source image. Animated images are not supported.',
        );
      }
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  Future<void> _refreshProcessedImage() async {
    final source = _sourceImage;
    if (source == null) return;
    final epoch = ++_processedEpoch;
    if (mounted) setState(() => _processingPreview = true);
    ui.Image? next;
    try {
      next = await MosaicRenderService.buildProcessedImage(source, _settings);
      if (!mounted || epoch != _processedEpoch) {
        next?.dispose();
        return;
      }
      final previous = _processedImage;
      setState(() {
        _processedImage = next;
        _processingPreview = false;
      });
      previous?.dispose();
    } on Object catch (error, stackTrace) {
      next?.dispose();
      AppLogger.e(
        'Failed to build redaction preview',
        error,
        stackTrace,
        'MosaicEditor',
      );
      if (!mounted || epoch != _processedEpoch) return;
      setState(() => _processingPreview = false);
    }
  }

  bool _processedStyleChanged(MosaicSettings a, MosaicSettings b) =>
      a.effect != b.effect ||
      a.pixelSizeRatio != b.pixelSizeRatio ||
      a.blurSigmaRatio != b.blurSigmaRatio;

  void _pushUndo() {
    _undo.add(_snapshot());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  _MosaicSnapshot _snapshot() => _MosaicSnapshot(
        settings: _settings,
        regions: List<MosaicRegion>.of(_regions),
        selectedId: _selectedId,
        drawShape: _drawShape,
      );

  void _restoreSnapshot(_MosaicSnapshot snapshot) {
    final refresh = _processedStyleChanged(_settings, snapshot.settings);
    setState(() {
      _settings = snapshot.settings;
      _regions = List<MosaicRegion>.of(snapshot.regions);
      _selectedId = snapshot.selectedId;
      _drawShape = snapshot.drawShape;
    });
    if (refresh) unawaited(_refreshProcessedImage());
  }

  void _undoChange() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot());
    _restoreSnapshot(_undo.removeLast());
  }

  void _redoChange() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot());
    _restoreSnapshot(_redo.removeLast());
  }

  void _changeSettings(MosaicSettings value, {bool recordUndo = true}) {
    if (recordUndo) _pushUndo();
    final refresh = _processedStyleChanged(_settings, value);
    setState(() {
      _settings = value;
      _drawShape = value.defaultShape;
    });
    if (refresh) unawaited(_refreshProcessedImage());
  }

  MosaicRegion? get _selectedRegion {
    final selectedId = _selectedId;
    if (selectedId == null) return null;
    for (final region in _regions) {
      if (region.id == selectedId) return region;
    }
    return null;
  }

  void _selectRegion(String? id) {
    if (_selectedId == id) return;
    setState(() => _selectedId = id);
  }

  void _updateRegion(MosaicRegion value, {bool recordUndo = true}) {
    final index = _regions.indexWhere((region) => region.id == value.id);
    if (index < 0) return;
    if (recordUndo) _pushUndo();
    final next = List<MosaicRegion>.of(_regions);
    next[index] = value.normalized();
    setState(() => _regions = next);
  }

  void _createRegion(
    MosaicShape shape,
    Rect normalizedRect,
    List<MosaicPoint> points,
  ) {
    _pushUndo();
    final region = MosaicRegion(
      id: _nextRegionId(),
      left: normalizedRect.left,
      top: normalizedRect.top,
      width: normalizedRect.width,
      height: normalizedRect.height,
      shape: shape,
      points: List<MosaicPoint>.of(points),
      brushSizeRatio: _settings.brushSizeRatio,
    ).normalized();
    setState(() {
      _regions = <MosaicRegion>[..._regions, region];
      _selectedId = region.id;
    });
  }

  void _addCentered(MosaicShape shape) {
    _pushUndo();
    late final MosaicRegion region;
    if (shape == MosaicShape.brush) {
      final points = <MosaicPoint>[
        const MosaicPoint(0.40, 0.50),
        const MosaicPoint(0.45, 0.48),
        const MosaicPoint(0.50, 0.52),
        const MosaicPoint(0.55, 0.48),
        const MosaicPoint(0.60, 0.50),
      ];
      final bounds = _boundsForBrush(points, _settings.brushSizeRatio);
      region = MosaicRegion(
        id: _nextRegionId(),
        left: bounds.left,
        top: bounds.top,
        width: bounds.width,
        height: bounds.height,
        shape: MosaicShape.brush,
        points: points,
        brushSizeRatio: _settings.brushSizeRatio,
      );
    } else {
      region = _newCenteredRegion(shape: shape);
    }
    setState(() {
      _regions = <MosaicRegion>[..._regions, region];
      _selectedId = region.id;
      _drawShape = shape;
      _settings = _settings.copyWith(defaultShape: shape);
    });
  }

  void _addFullImageRegion() {
    _pushUndo();
    final region = MosaicRegion(
      id: _nextRegionId(),
      left: 0,
      top: 0,
      width: 1,
      height: 1,
      shape: MosaicShape.roundedRectangle,
      brushSizeRatio: _settings.brushSizeRatio,
    );
    setState(() {
      _regions = <MosaicRegion>[..._regions, region];
      _selectedId = region.id;
      _settings = _settings.copyWith(invertMask: false);
    });
  }

  void _deleteSelected() {
    final selected = _selectedRegion;
    if (selected == null) return;
    _pushUndo();
    final index = _regions.indexOf(selected);
    final next = List<MosaicRegion>.of(_regions)..removeAt(index);
    setState(() {
      _regions = next;
      _selectedId = next.isEmpty
          ? null
          : next[math.min(index, next.length - 1)].id;
    });
  }

  void _duplicateSelected() {
    final selected = _selectedRegion;
    if (selected == null) return;
    _pushUndo();
    late final MosaicRegion duplicate;
    if (selected.shape == MosaicShape.brush) {
      final points = <MosaicPoint>[
        for (final point in selected.points) point.translated(0.025, 0.025),
      ];
      final bounds = _boundsForBrush(points, selected.brushSizeRatio);
      duplicate = selected.copyWith(
        id: _nextRegionId(),
        left: bounds.left,
        top: bounds.top,
        width: bounds.width,
        height: bounds.height,
        points: points,
        locked: false,
      );
    } else {
      duplicate = selected.copyWith(
        id: _nextRegionId(),
        left: (selected.left + 0.025)
            .clamp(0.0, 1.0 - selected.width)
            .toDouble(),
        top: (selected.top + 0.025)
            .clamp(0.0, 1.0 - selected.height)
            .toDouble(),
        locked: false,
      );
    }
    setState(() {
      _regions = <MosaicRegion>[..._regions, duplicate];
      _selectedId = duplicate.id;
    });
  }

  void _clearAll() {
    if (_regions.isEmpty) return;
    _pushUndo();
    setState(() {
      _regions = const <MosaicRegion>[];
      _selectedId = null;
    });
  }

  void _setSelectedShape(MosaicShape shape) {
    final selected = _selectedRegion;
    if (selected == null || selected.locked || selected.shape == shape) return;
    _pushUndo();
    var next = selected.copyWith(shape: shape);
    if (shape == MosaicShape.brush && selected.points.isEmpty) {
      final centerY = selected.top + selected.height / 2;
      final points = <MosaicPoint>[
        MosaicPoint(selected.left + selected.width * 0.15, centerY),
        MosaicPoint(selected.left + selected.width * 0.5, centerY),
        MosaicPoint(selected.left + selected.width * 0.85, centerY),
      ];
      final bounds = _boundsForBrush(points, _settings.brushSizeRatio);
      next = next.copyWith(
        left: bounds.left,
        top: bounds.top,
        width: bounds.width,
        height: bounds.height,
        points: points,
        brushSizeRatio: _settings.brushSizeRatio,
      );
    }
    _updateRegion(next, recordUndo: false);
  }

  void _setSelectedBrushSize(double value, {bool recordUndo = false}) {
    final selected = _selectedRegion;
    if (selected == null || selected.shape != MosaicShape.brush) return;
    if (recordUndo) _pushUndo();
    final bounds = _boundsForBrush(selected.points, value);
    _updateRegion(
      selected.copyWith(
        left: bounds.left,
        top: bounds.top,
        width: bounds.width,
        height: bounds.height,
        brushSizeRatio: value,
      ),
      recordUndo: false,
    );
  }

  static Rect _boundsForBrush(List<MosaicPoint> points, double sizeRatio) {
    if (points.isEmpty) return Rect.zero;
    var left = points.first.x;
    var top = points.first.y;
    var right = points.first.x;
    var bottom = points.first.y;
    for (final point in points.skip(1)) {
      left = math.min(left, point.x);
      top = math.min(top, point.y);
      right = math.max(right, point.x);
      bottom = math.max(bottom, point.y);
    }
    final radius = sizeRatio / 2;
    return Rect.fromLTRB(
      (left - radius).clamp(0.0, 1.0).toDouble(),
      (top - radius).clamp(0.0, 1.0).toDouble(),
      (right + radius).clamp(0.0, 1.0).toDouble(),
      (bottom + radius).clamp(0.0, 1.0).toDouble(),
    );
  }

  void _moveSelected(Offset delta) {
    final selected = _selectedRegion;
    if (selected == null || selected.locked) return;
    _pushUndo();
    if (selected.shape == MosaicShape.brush) {
      if (selected.points.isEmpty) return;
      var minX = selected.points.first.x;
      var maxX = selected.points.first.x;
      var minY = selected.points.first.y;
      var maxY = selected.points.first.y;
      for (final point in selected.points.skip(1)) {
        minX = math.min(minX, point.x);
        maxX = math.max(maxX, point.x);
        minY = math.min(minY, point.y);
        maxY = math.max(maxY, point.y);
      }
      final radius = selected.brushSizeRatio / 2;
      final dx = delta.dx.clamp(-minX + radius, 1 - maxX - radius).toDouble();
      final dy = delta.dy.clamp(-minY + radius, 1 - maxY - radius).toDouble();
      final points = <MosaicPoint>[
        for (final point in selected.points)
          MosaicPoint(point.x + dx, point.y + dy),
      ];
      final bounds = _boundsForBrush(points, selected.brushSizeRatio);
      _updateRegion(
        selected.copyWith(
          left: bounds.left,
          top: bounds.top,
          width: bounds.width,
          height: bounds.height,
          points: points,
        ),
        recordUndo: false,
      );
      return;
    }
    _updateRegion(
      selected.copyWith(
        left: (selected.left + delta.dx)
            .clamp(0.0, 1.0 - selected.width)
            .toDouble(),
        top: (selected.top + delta.dy)
            .clamp(0.0, 1.0 - selected.height)
            .toDouble(),
      ),
      recordUndo: false,
    );
  }

  KeyEventResult _handlePreviewKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final command = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (command && key == LogicalKeyboardKey.keyZ) {
      if (keyboard.isShiftPressed) {
        _redoChange();
      } else {
        _undoChange();
      }
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyY) {
      _redoChange();
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyD) {
      _duplicateSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _deleteSelected();
      return KeyEventResult.handled;
    }
    var delta = Offset.zero;
    final step = keyboard.isShiftPressed ? 0.01 : 0.002;
    if (key == LogicalKeyboardKey.arrowLeft) delta = Offset(-step, 0);
    if (key == LogicalKeyboardKey.arrowRight) delta = Offset(step, 0);
    if (key == LogicalKeyboardKey.arrowUp) delta = Offset(0, -step);
    if (key == LogicalKeyboardKey.arrowDown) delta = Offset(0, step);
    if (delta == Offset.zero) return KeyEventResult.ignored;
    _moveSelected(delta);
    return KeyEventResult.handled;
  }

  Future<void> _reset() async {
    _pushUndo();
    final refresh = _processedStyleChanged(_settings, _initialSettings);
    setState(() {
      _settings = _initialSettings;
      _regions = List<MosaicRegion>.of(_initialRegions);
      _selectedId = _regions.isEmpty ? null : _regions.first.id;
      _drawShape = _initialSettings.defaultShape;
    });
    if (refresh) await _refreshProcessedImage();
  }

  Future<void> _saveDefaults() async {
    await ref.read(mosaicSettingsProvider.notifier).saveDefaults(_settings);
    _initialSettings = _settings;
    _undo.clear();
    _redo.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.mosaic_defaultSaved)),
    );
  }

  Future<void> _saveCopy() async {
    if (_saving) return;
    if (!_regions.any((region) => region.isUsable)) {
      _showError(context.l10n.mosaic_noRegionError);
      return;
    }
    final token = MosaicCancellationToken();
    _renderToken = token;
    setState(() => _saving = true);
    try {
      final result = await MosaicRenderService.render(
        MosaicRenderRequest(
          sourceBytes: _sourceBytes,
          settings: _settings,
          regions: _regions,
          preserveMetadata: _settings.preserveMetadata,
          sourceFileName: _sourceFileName,
        ),
        cancellationToken: token,
      );
      if (!mounted || token.isCancelled) return;
      final galleryRoot = await GalleryFolderRepository.instance.getRootPath();
      if (!mounted || token.isCancelled) return;
      if (galleryRoot == null || galleryRoot.isEmpty) {
        throw StateError(context.l10n.localGallery_saveDirectoryNotSet);
      }
      final output = await ImageSaveUtils.saveBytesToDatedPath(
        rootPath: galleryRoot,
        bytes: result.bytes,
        preferredFileName: result.fileName,
      );
      Object? systemGalleryError;
      if (PlatformCapabilities.current.supportsSystemGalleryExport) {
        try {
          await AndroidMediaStoreService.savePng(
            bytes: result.bytes,
            fileName: result.fileName,
          );
        } on Object catch (error, stackTrace) {
          systemGalleryError = error;
          AppLogger.e(
            'Redacted copy saved but system gallery export failed',
            error,
            stackTrace,
            'MosaicEditor',
          );
        }
      }
      if (!mounted) return;
      final sourcePath = _sourcePath;
      if (sourcePath != null) {
        await MosaicDerivativeRegistry(
          ref.read(localStorageServiceProvider),
        ).register(outputPath: output, sourcePath: sourcePath);
      }
      if (_settings.rememberLastStyle) {
        await ref.read(mosaicSettingsProvider.notifier).saveDefaults(_settings);
      }
      Object? galleryRefreshError;
      try {
        final previousError = ref.read(localGalleryNotifierProvider).error;
        await ref.read(localGalleryNotifierProvider.notifier).refresh();
        final refreshError = ref.read(localGalleryNotifierProvider).error;
        if (refreshError != null && !identical(refreshError, previousError)) {
          galleryRefreshError = refreshError;
          AppLogger.e(
            'Redacted copy saved but gallery refresh failed',
            refreshError.details ?? refreshError.code.name,
            null,
            'MosaicEditor',
          );
        }
      } on Object catch (error, stackTrace) {
        galleryRefreshError = error;
        AppLogger.e(
          'Redacted copy saved but gallery refresh failed',
          error,
          stackTrace,
          'MosaicEditor',
        );
      }
      if (!mounted) return;
      if (systemGalleryError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.mosaic_systemGalleryExportFailed),
          ),
        );
      }
      if (galleryRefreshError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.mosaic_galleryRefreshFailed)),
        );
      }
      await _showSaved(result, output);
      if (mounted) Navigator.of(context).pop(output);
    } on MosaicCancelledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.mosaic_cancelled)),
        );
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to create redacted copy',
        error,
        stackTrace,
        'MosaicEditor',
      );
      if (mounted) _showError('${context.l10n.mosaic_failedGeneric}\n$error');
    } finally {
      _renderToken = null;
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSaved(MosaicRenderResult result, String output) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.mosaic_saved),
        content: SelectableText(output),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final uri = output.contains('://')
                  ? Uri.parse(output)
                  : Uri.file(output);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.open_in_new),
            label: Text(context.l10n.mosaic_open),
          ),
          TextButton.icon(
            onPressed: () => _share(result),
            icon: const Icon(Icons.share_outlined),
            label: Text(context.l10n.mosaic_share),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.common_close),
          ),
        ],
      ),
    );
  }

  Future<void> _share(MosaicRenderResult result) async {
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    final prepared = await ImageShareSanitizer.prepareForCopyOrDragInBackground(
      result.bytes,
      fileName: result.fileName,
      stripMetadata: stripMetadata,
    );
    await NativeShareService.shareImage(
      bytes: prepared.bytes,
      fileName: prepared.fileName,
      mimeType: prepared.mimeType,
    );
  }

  Future<void> _retryLoad() async {
    _processedEpoch++;
    final previousSource = _sourceImage;
    final previousProcessed = _processedImage;
    _sourceImage = null;
    _processedImage = null;
    previousSource?.dispose();
    previousProcessed?.dispose();
    setState(() {
      _loadError = null;
      _loading = true;
    });
    await _loadImage();
  }

  Future<void> _chooseSource() async {
    final choose = widget.onChooseSource;
    if (choose == null) return;
    final selected = await choose();
    if (selected == null || !mounted) return;
    _sourceBytes = selected.bytes;
    _sourceFileName = selected.fileName;
    _sourcePath = selected.path;
    _undo.clear();
    _redo.clear();
    _regions = <MosaicRegion>[_newCenteredRegion()];
    _initialRegions = List<MosaicRegion>.of(_regions);
    _selectedId = _regions.first.id;
    await _retryLoad();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _saving) _renderToken?.cancel();
      },
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SafeArea(
            child: Column(
              children: [
                if (keyboardInset == 0) _buildHeader(),
                Expanded(child: _buildBody()),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.grid_on_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.defaultsOnly
                    ? context.l10n.mosaic_defaultsTitle
                    : context.l10n.mosaic_editorTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: context.l10n.common_close,
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null || _sourceImage == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 42,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.mosaic_sourceLoadFailed,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.common_close),
                    ),
                    if (widget.onChooseSource != null)
                      FilledButton.icon(
                        onPressed: _chooseSource,
                        icon: const Icon(Icons.image_search_outlined),
                        label: Text(context.l10n.mosaic_chooseOriginal),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _retryLoad,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.l10n.common_retry),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final preview = _buildPreview();
        final controls = _buildControls();
        if (constraints.maxWidth >= 880) {
          return Row(
            children: [
              Expanded(child: preview),
              const VerticalDivider(width: 1),
              SizedBox(width: 410, child: controls),
            ],
          );
        }
        final controlsHeight = math.min(390.0, constraints.maxHeight * 0.48);
        return Column(
          children: [
            Expanded(child: preview),
            const Divider(height: 1),
            SizedBox(height: controlsHeight, child: controls),
          ],
        );
      },
    );
  }

  Widget _buildPreview() {
    final source = _sourceImage!;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Focus(
                focusNode: _previewFocusNode,
                autofocus: true,
                onKeyEvent: _handlePreviewKey,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: MosaicEditorCanvas(
                        source: source,
                        processed: _processedImage,
                        settings: _settings,
                        regions: _regions,
                        selectedId: _selectedId,
                        drawShape: _drawShape,
                        selectionColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                        onSelected: _selectRegion,
                        onBeginRegionTransform: _pushUndo,
                        onRegionChanged: (value) =>
                            _updateRegion(value, recordUndo: false),
                        onRegionCreated: _createRegion,
                        onFocusRequested: _previewFocusNode.requestFocus,
                      ),
                    ),
                    if (_processingPreview)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              children: [
                Text(
                  '${_effectName(_settings.effect)} · '
                  '${context.l10n.mosaic_regions}: ${_regions.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  context.l10n.mosaic_canvasHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final selected = _selectedRegion;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(
            _settings.preserveMetadata
                ? Icons.data_object_outlined
                : Icons.remove_circle_outline,
          ),
          title: Text(context.l10n.settings_mosaicPreserveMetadata),
          subtitle: Text(context.l10n.settings_mosaicPreserveMetadataHint),
          value: _settings.preserveMetadata,
          onChanged: (value) => _changeSettings(
            _settings.copyWith(preserveMetadata: value),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.history_toggle_off_outlined),
          title: Text(context.l10n.settings_mosaicRememberStyle),
          subtitle: Text(context.l10n.settings_mosaicRememberStyleHint),
          value: _settings.rememberLastStyle,
          onChanged: (value) => _changeSettings(
            _settings.copyWith(rememberLastStyle: value),
          ),
        ),
        const Divider(),
        _sectionTitle(context.l10n.mosaic_drawTool),
        const SizedBox(height: 8),
        SegmentedButton<MosaicShape>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: MosaicShape.roundedRectangle,
              icon: const Icon(Icons.rectangle_outlined),
              label: Text(context.l10n.mosaic_shapeRectangle),
            ),
            ButtonSegment(
              value: MosaicShape.ellipse,
              icon: const Icon(Icons.circle_outlined),
              label: Text(context.l10n.mosaic_shapeEllipse),
            ),
            ButtonSegment(
              value: MosaicShape.brush,
              icon: const Icon(Icons.brush_outlined),
              label: Text(context.l10n.mosaic_shapeBrush),
            ),
          ],
          selected: {_drawShape},
          onSelectionChanged: (value) {
            final shape = value.first;
            _pushUndo();
            setState(() {
              _drawShape = shape;
              _settings = _settings.copyWith(defaultShape: shape);
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.mosaic_drawHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _addCentered(_drawShape),
              icon: const Icon(Icons.add_box_outlined),
              label: Text(context.l10n.mosaic_addRegion),
            ),
            OutlinedButton.icon(
              onPressed: _addFullImageRegion,
              icon: const Icon(Icons.fullscreen),
              label: Text(context.l10n.mosaic_fullImage),
            ),
            OutlinedButton.icon(
              onPressed: _regions.isEmpty ? null : _clearAll,
              icon: const Icon(Icons.layers_clear_outlined),
              label: Text(context.l10n.mosaic_clearAll),
            ),
          ],
        ),
        const Divider(height: 28),
        _sectionTitle(context.l10n.mosaic_effect),
        const SizedBox(height: 8),
        SegmentedButton<MosaicEffect>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: MosaicEffect.pixelate,
              icon: const Icon(Icons.grid_on_rounded),
              label: Text(context.l10n.mosaic_effectPixelate),
            ),
            ButtonSegment(
              value: MosaicEffect.blur,
              icon: const Icon(Icons.blur_on_outlined),
              label: Text(context.l10n.mosaic_effectBlur),
            ),
            ButtonSegment(
              value: MosaicEffect.solid,
              icon: const Icon(Icons.crop_square_rounded),
              label: Text(context.l10n.mosaic_effectSolid),
            ),
          ],
          selected: {_settings.effect},
          onSelectionChanged: (value) => _changeSettings(
            _settings.copyWith(effect: value.first),
          ),
        ),
        const SizedBox(height: 10),
        if (_settings.effect == MosaicEffect.pixelate)
          _MosaicSlider(
            label: context.l10n.mosaic_pixelSize,
            value: _settings.pixelSizeRatio,
            min: 0.004,
            max: 0.08,
            onChangeStart: _pushUndo,
            onChanged: (value) => _changeSettings(
              _settings.copyWith(pixelSizeRatio: value),
              recordUndo: false,
            ),
          ),
        if (_settings.effect == MosaicEffect.blur)
          _MosaicSlider(
            label: context.l10n.mosaic_blurStrength,
            value: _settings.blurSigmaRatio,
            min: 0.003,
            max: 0.06,
            onChangeStart: _pushUndo,
            onChanged: (value) => _changeSettings(
              _settings.copyWith(blurSigmaRatio: value),
              recordUndo: false,
            ),
          ),
        if (_settings.effect == MosaicEffect.solid)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Color(_settings.fillColorArgb),
              child: const Icon(Icons.palette_outlined),
            ),
            title: Text(context.l10n.mosaic_color),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickColor(
              Color(_settings.fillColorArgb),
              (color) => _changeSettings(
                _settings.copyWith(fillColorArgb: color.toARGB32()),
              ),
            ),
          ),
        _MosaicSlider(
          label: context.l10n.mosaic_opacity,
          value: _settings.opacity,
          min: 0.1,
          max: 1,
          onChangeStart: _pushUndo,
          onChanged: (value) => _changeSettings(
            _settings.copyWith(opacity: value),
            recordUndo: false,
          ),
        ),
        _MosaicSlider(
          label: context.l10n.mosaic_cornerRadius,
          value: _settings.cornerRadiusRatio,
          min: 0,
          max: 0.5,
          onChangeStart: _pushUndo,
          onChanged: (value) => _changeSettings(
            _settings.copyWith(cornerRadiusRatio: value),
            recordUndo: false,
          ),
        ),
        _MosaicSlider(
          label: context.l10n.mosaic_brushSize,
          value: _settings.brushSizeRatio,
          min: 0.01,
          max: 0.16,
          onChangeStart: _pushUndo,
          onChanged: (value) {
            _changeSettings(
              _settings.copyWith(brushSizeRatio: value),
              recordUndo: false,
            );
            if (_selectedRegion?.shape == MosaicShape.brush) {
              _setSelectedBrushSize(value);
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.flip),
          title: Text(context.l10n.mosaic_invertMask),
          subtitle: Text(context.l10n.mosaic_invertMaskHint),
          value: _settings.invertMask,
          onChanged: (value) => _changeSettings(
            _settings.copyWith(invertMask: value),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.numbers),
          title: Text(context.l10n.mosaic_showLabels),
          value: _settings.showRegionLabels,
          onChanged: (value) => _changeSettings(
            _settings.copyWith(showRegionLabels: value),
          ),
        ),
        const Divider(height: 28),
        Row(
          children: [
            Expanded(child: _sectionTitle(context.l10n.mosaic_regions)),
            Text('${_regions.length}'),
          ],
        ),
        const SizedBox(height: 8),
        if (_regions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              context.l10n.mosaic_noRegions,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var index = 0; index < _regions.length; index++)
                ChoiceChip(
                  selected: _regions[index].id == _selectedId,
                  avatar: Icon(_shapeIcon(_regions[index].shape), size: 16),
                  label: Text('#${index + 1}'),
                  onSelected: (_) => _selectRegion(_regions[index].id),
                ),
            ],
          ),
        if (selected != null) ...[
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.mosaic_regionEnabled),
            value: selected.enabled,
            onChanged: (value) =>
                _updateRegion(selected.copyWith(enabled: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.mosaic_regionLocked),
            value: selected.locked,
            onChanged: (value) =>
                _updateRegion(selected.copyWith(locked: value)),
          ),
          SegmentedButton<MosaicShape>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: MosaicShape.roundedRectangle,
                icon: const Icon(Icons.rectangle_outlined),
                label: Text(context.l10n.mosaic_shapeRectangle),
              ),
              ButtonSegment(
                value: MosaicShape.ellipse,
                icon: const Icon(Icons.circle_outlined),
                label: Text(context.l10n.mosaic_shapeEllipse),
              ),
              ButtonSegment(
                value: MosaicShape.brush,
                icon: const Icon(Icons.brush_outlined),
                label: Text(context.l10n.mosaic_shapeBrush),
              ),
            ],
            selected: {selected.shape},
            onSelectionChanged: selected.locked
                ? null
                : (value) => _setSelectedShape(value.first),
          ),
          if (selected.shape != MosaicShape.brush) ...[
            const SizedBox(height: 8),
            _MosaicSlider(
              label: context.l10n.mosaic_positionX,
              value: selected.left,
              min: 0,
              max: math.max(0.001, 1 - selected.width),
              onChangeStart: _pushUndo,
              onChanged: selected.locked
                  ? null
                  : (value) => _updateRegion(
                        selected.copyWith(left: value),
                        recordUndo: false,
                      ),
            ),
            _MosaicSlider(
              label: context.l10n.mosaic_positionY,
              value: selected.top,
              min: 0,
              max: math.max(0.001, 1 - selected.height),
              onChangeStart: _pushUndo,
              onChanged: selected.locked
                  ? null
                  : (value) => _updateRegion(
                        selected.copyWith(top: value),
                        recordUndo: false,
                      ),
            ),
            _MosaicSlider(
              label: context.l10n.mosaic_width,
              value: selected.width,
              min: 0.02,
              max: math.max(0.02, 1 - selected.left),
              onChangeStart: _pushUndo,
              onChanged: selected.locked
                  ? null
                  : (value) => _updateRegion(
                        selected.copyWith(width: value),
                        recordUndo: false,
                      ),
            ),
            _MosaicSlider(
              label: context.l10n.mosaic_height,
              value: selected.height,
              min: 0.02,
              max: math.max(0.02, 1 - selected.top),
              onChangeStart: _pushUndo,
              onChanged: selected.locked
                  ? null
                  : (value) => _updateRegion(
                        selected.copyWith(height: value),
                        recordUndo: false,
                      ),
            ),
          ] else
            _MosaicSlider(
              label: context.l10n.mosaic_brushSize,
              value: selected.brushSizeRatio,
              min: 0.01,
              max: 0.16,
              onChangeStart: _pushUndo,
              onChanged: selected.locked
                  ? null
                  : (value) => _setSelectedBrushSize(value),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _duplicateSelected,
                icon: const Icon(Icons.copy_all_outlined),
                label: Text(context.l10n.mosaic_duplicate),
              ),
              OutlinedButton.icon(
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.mosaic_delete),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(
          context.l10n.mosaic_keyboardHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      );

  String _effectName(MosaicEffect effect) => switch (effect) {
        MosaicEffect.pixelate => context.l10n.mosaic_effectPixelate,
        MosaicEffect.blur => context.l10n.mosaic_effectBlur,
        MosaicEffect.solid => context.l10n.mosaic_effectSolid,
      };

  static IconData _shapeIcon(MosaicShape shape) => switch (shape) {
        MosaicShape.roundedRectangle => Icons.rectangle_outlined,
        MosaicShape.ellipse => Icons.circle_outlined,
        MosaicShape.brush => Icons.brush_outlined,
      };

  Future<void> _pickColor(
    Color initial,
    ValueChanged<Color> onChanged,
  ) async {
    var selected = initial;
    final result = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        title: Text(context.l10n.editor_toolColorPicker),
        content: SizedBox(
          width: math.min(320, MediaQuery.sizeOf(dialogContext).width - 64),
          child: HSVColorPicker(
            color: initial,
            hexLabel: context.l10n.editor_colorHex,
            saturationBrightnessLabel:
                context.l10n.editor_colorSaturationBrightness,
            hueLabel: context.l10n.editor_colorHue,
            hueHeight: 48,
            onColorChanged: (value) => selected = value,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(selected),
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );
    if (result != null) onChanged(result);
  }

  Widget _buildActions() {
    final ready = _sourceImage != null && !_loading && _loadError == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.mosaic_undo,
                  onPressed: _undo.isEmpty || _saving || !ready
                      ? null
                      : _undoChange,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: context.l10n.mosaic_redo,
                  onPressed: _redo.isEmpty || _saving || !ready
                      ? null
                      : _redoChange,
                  icon: const Icon(Icons.redo),
                ),
                IconButton(
                  tooltip: context.l10n.mosaic_reset,
                  onPressed: _saving || !ready ? null : _reset,
                  icon: const Icon(Icons.restart_alt),
                ),
                const Spacer(),
                if (widget.defaultsOnly)
                  FilledButton.icon(
                    onPressed: _saving || !ready ? null : _saveDefaults,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(context.l10n.mosaic_saveDefaults),
                  )
                else if (compact)
                  IconButton(
                    tooltip: context.l10n.mosaic_saveDefaults,
                    onPressed: _saving || !ready ? null : _saveDefaults,
                    icon: const Icon(Icons.bookmark_add_outlined),
                  )
                else
                  TextButton.icon(
                    onPressed: _saving || !ready ? null : _saveDefaults,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(context.l10n.mosaic_saveDefaults),
                  ),
                if (!widget.defaultsOnly) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving || !ready ? null : _saveCopy,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt),
                    label: Text(
                      compact
                          ? context.l10n.common_save
                          : _saving
                              ? context.l10n.mosaic_saving
                              : context.l10n.mosaic_saveCopy,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MosaicSnapshot {
  const _MosaicSnapshot({
    required this.settings,
    required this.regions,
    required this.selectedId,
    required this.drawShape,
  });

  final MosaicSettings settings;
  final List<MosaicRegion> regions;
  final String? selectedId;
  final MosaicShape drawShape;
}

class _MosaicSlider extends StatelessWidget {
  const _MosaicSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChangeStart,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final VoidCallback onChangeStart;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final safeMax = math.max(min + 0.000001, max);
    final safeValue = value.clamp(min, safeMax).toDouble();
    return Semantics(
      label: label,
      value: '${(safeValue * 100).toStringAsFixed(1)}%',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final percentage = Text('${(safeValue * 100).toStringAsFixed(0)}%');
          final slider = Slider(
            value: safeValue,
            min: min,
            max: safeMax,
            onChangeStart: onChanged == null ? null : (_) => onChangeStart(),
            onChanged: onChanged,
          );
          if (constraints.maxWidth < 350 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Row(
                  children: [
                    Expanded(child: slider),
                    SizedBox(width: 48, child: percentage),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 116, child: Text(label)),
              Expanded(child: slider),
              SizedBox(width: 52, child: percentage),
            ],
          );
        },
      ),
    );
  }
}
