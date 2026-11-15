import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mosaic/mosaic_render_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/mosaic/mosaic_settings.dart';
import '../../providers/mosaic_settings_provider.dart';
import '../derivatives/derivative_copy_save_run.dart';
import 'mosaic_editor_actions_bar.dart';
import 'mosaic_editor_controls.dart';
import 'mosaic_editor_dialogs.dart';
import 'mosaic_editor_geometry.dart';
import 'mosaic_editor_preview.dart';

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
    this.decodePreview = MosaicRenderService.decodePreview,
    this.renderCopy = MosaicRenderService.render,
  });

  final Uint8List sourceBytes;
  final String sourceFileName;
  final String? sourcePath;
  final bool defaultsOnly;
  final Future<MosaicEditorSource?> Function()? onChooseSource;
  final Future<ui.Image> Function(Uint8List bytes) decodePreview;
  final MosaicRenderOperation renderCopy;

  @override
  ConsumerState<MosaicEditorScreen> createState() => _MosaicEditorScreenState();
}

class _MosaicEditorScreenState extends ConsumerState<MosaicEditorScreen> {
  final _previewFocusNode = FocusNode(debugLabel: 'mosaic preview');
  final _undo = <MosaicSnapshot>[];
  final _redo = <MosaicSnapshot>[];
  DerivativeCopySaveRun? _saveRun;

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
  Object? _loadError;
  Object? _previewError;
  int _processedEpoch = 0;
  int _regionSequence = 0;

  bool get _saving => _saveRun != null;

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
    _saveRun?.close();
    _processedEpoch++;
    _previewFocusNode.dispose();
    _processedImage?.dispose();
    _sourceImage?.dispose();
    super.dispose();
  }

  String _nextRegionId() =>
      'redaction_${DateTime.now().microsecondsSinceEpoch}_${_regionSequence++}';

  MosaicRegion _newCenteredRegion({MosaicShape? shape}) =>
      createCenteredMosaicRegion(
        id: _nextRegionId(),
        settings: _settings,
        shape: shape,
      );

  Future<void> _loadImage() async {
    try {
      final source = await widget.decodePreview(_sourceBytes);
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

  Future<void> _refreshProcessedImage() async {
    final source = _sourceImage;
    if (source == null) return;
    final epoch = ++_processedEpoch;
    if (mounted) {
      setState(() {
        _processingPreview = true;
        _previewError = null;
      });
    }
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
      setState(() {
        _processingPreview = false;
        _previewError = error;
      });
    }
  }

  void _pushUndo() {
    _undo.add(_snapshot());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  MosaicSnapshot _snapshot() => MosaicSnapshot(
    settings: _settings,
    regions: List<MosaicRegion>.of(_regions),
    selectedId: _selectedId,
    drawShape: _drawShape,
  );

  void _restoreSnapshot(MosaicSnapshot snapshot) {
    final refresh = mosaicProcessedStyleChanged(_settings, snapshot.settings);
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
    final refresh = mosaicProcessedStyleChanged(_settings, value);
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
    final region = shape == MosaicShape.brush
        ? createCenteredBrushMosaicRegion(
            id: _nextRegionId(),
            brushSizeRatio: _settings.brushSizeRatio,
          )
        : _newCenteredRegion(shape: shape);
    setState(() {
      _regions = <MosaicRegion>[..._regions, region];
      _selectedId = region.id;
      _drawShape = shape;
      _settings = _settings.copyWith(defaultShape: shape);
    });
  }

  void _addFullImageRegion() {
    _pushUndo();
    final region = createFullImageMosaicRegion(
      id: _nextRegionId(),
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
    final duplicate = duplicateMosaicRegion(
      selected: selected,
      id: _nextRegionId(),
    );
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
    final next = changeMosaicRegionShape(
      selected: selected,
      shape: shape,
      defaultBrushSizeRatio: _settings.brushSizeRatio,
    );
    _updateRegion(next, recordUndo: false);
  }

  void _setSelectedBrushSize(double value, {bool recordUndo = false}) {
    final selected = _selectedRegion;
    if (selected == null || selected.shape != MosaicShape.brush) return;
    if (recordUndo) _pushUndo();
    _updateRegion(
      resizeMosaicBrushRegion(selected: selected, brushSizeRatio: value),
      recordUndo: false,
    );
  }

  void _moveSelected(Offset delta) {
    final selected = _selectedRegion;
    if (selected == null || selected.locked) return;
    _pushUndo();
    final moved = moveMosaicRegion(selected: selected, delta: delta);
    if (moved == null) return;
    _updateRegion(moved, recordUndo: false);
  }

  KeyEventResult _handlePreviewKey(FocusNode node, KeyEvent event) {
    return handleMosaicPreviewKeyEvent(
      event: event,
      saving: _saving,
      onUndo: _undoChange,
      onRedo: _redoChange,
      onDuplicate: _duplicateSelected,
      onDelete: _deleteSelected,
      onMove: _moveSelected,
    );
  }

  Future<void> _reset() async {
    _pushUndo();
    final refresh = mosaicProcessedStyleChanged(_settings, _initialSettings);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.mosaic_defaultSaved)));
  }

  Future<void> _saveCopy() async {
    if (_saving) return;
    if (!_regions.any((region) => region.isUsable)) {
      _showError(context.l10n.mosaic_noRegionError);
      return;
    }
    final settings = _settings;
    final request = MosaicRenderRequest(
      sourceBytes: _sourceBytes,
      settings: settings,
      regions: _regions,
      preserveMetadata: settings.preserveMetadata,
      sourceFileName: _sourceFileName,
    );
    await executeMosaicSaveCopy(
      context: context,
      ref: ref,
      isMounted: () => mounted,
      request: request,
      sourcePath: _sourcePath,
      renderCopy: widget.renderCopy,
      onSaveRunChanged: (run) => setState(() => _saveRun = run),
      onError: _showError,
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
    final ready =
        _sourceImage != null &&
        !_loading &&
        _loadError == null &&
        !_processingPreview &&
        _previewError == null;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveRun?.close();
      },
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              if (keyboardInset == 0)
                MosaicEditorHeader(
                  defaultsOnly: widget.defaultsOnly,
                  onClose: () => Navigator.of(context).pop(),
                ),
              Expanded(
                child: ExcludeFocus(
                  excluding: _saving,
                  child: AbsorbPointer(absorbing: _saving, child: _buildBody()),
                ),
              ),
              MosaicEditorActionsBar(
                ready: ready,
                saving: _saving,
                defaultsOnly: widget.defaultsOnly,
                canUndo: _undo.isNotEmpty,
                canRedo: _redo.isNotEmpty,
                onUndo: _undoChange,
                onRedo: _redoChange,
                onReset: _reset,
                onSaveDefaults: _saveDefaults,
                onSaveCopy: _saveCopy,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null || _sourceImage == null) {
      return MosaicEditorErrorView(
        hasChooseSource: widget.onChooseSource != null,
        onClose: () => Navigator.of(context).pop(),
        onChooseSource: _chooseSource,
        onRetry: _retryLoad,
      );
    }
    final preview = MosaicEditorPreviewPane(
      previewFocusNode: _previewFocusNode,
      sourceImage: _sourceImage!,
      processedImage: _processedImage,
      settings: _settings,
      regions: _regions,
      selectedId: _selectedId,
      drawShape: _drawShape,
      processingPreview: _processingPreview,
      previewError: _previewError,
      onKeyEvent: _handlePreviewKey,
      onSelected: _selectRegion,
      onBeginRegionTransform: _pushUndo,
      onRegionChanged: (value) => _updateRegion(value, recordUndo: false),
      onRegionCreated: _createRegion,
      onRetryPreview: _refreshProcessedImage,
    );
    final controls = MosaicEditorControlsPanel(
      settings: _settings,
      regions: _regions,
      selectedRegion: _selectedRegion,
      selectedId: _selectedId,
      drawShape: _drawShape,
      onPushUndo: _pushUndo,
      onChangeSettings: _changeSettings,
      onDrawShapeChanged: (shape) {
        _pushUndo();
        setState(() {
          _drawShape = shape;
          _settings = _settings.copyWith(defaultShape: shape);
        });
      },
      onAddCentered: _addCentered,
      onAddFullImageRegion: _addFullImageRegion,
      onClearAll: _clearAll,
      onPickFillColor: (initial, onChanged) => showMosaicColorPickerDialog(
        context: context,
        initial: initial,
        onChanged: onChanged,
      ),
      onSelectRegion: _selectRegion,
      onUpdateRegion: _updateRegion,
      onSetSelectedShape: _setSelectedShape,
      onSetSelectedBrushSize: _setSelectedBrushSize,
      onDuplicateSelected: _duplicateSelected,
      onDeleteSelected: _deleteSelected,
    );
    return MosaicEditorWorkspace(preview: preview, controls: controls);
  }
}
