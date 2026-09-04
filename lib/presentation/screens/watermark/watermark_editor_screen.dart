import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/services/android_media_store_service.dart';
import '../../../core/services/native_share_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_save_utils.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/watermark/watermark_derivative_registry.dart';
import '../../../core/watermark/watermark_logo_service.dart';
import '../../../core/watermark/watermark_render_service.dart';
import '../../../core/watermark/watermark_scene.dart';
import '../../../data/models/watermark/watermark_settings.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../adaptive/adaptive_layout.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../providers/watermark_settings_provider.dart';
import '../../router/app_routes.dart';
import 'watermark_editor_controls.dart';

class WatermarkEditorSource {
  const WatermarkEditorSource({
    required this.bytes,
    required this.fileName,
    this.path,
  });

  final Uint8List bytes;
  final String fileName;
  final String? path;
}

class WatermarkEditorScreen extends ConsumerStatefulWidget {
  const WatermarkEditorScreen({
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
  final Future<WatermarkEditorSource?> Function()? onChooseSource;

  @override
  ConsumerState<WatermarkEditorScreen> createState() =>
      _WatermarkEditorScreenState();
}

class _WatermarkEditorScreenState extends ConsumerState<WatermarkEditorScreen> {
  final _logoService = const WatermarkLogoService();
  final _previewFocusNode = FocusNode(debugLabel: 'watermark preview');
  final _undo = <WatermarkSettings>[];
  final _redo = <WatermarkSettings>[];
  WatermarkCancellationToken? _renderToken;
  late WatermarkSettings _settings;
  late WatermarkSettings _initialSettings;
  WatermarkEditableLayer _selectedLayer = WatermarkEditableLayer.text;
  WatermarkLayoutKind _previewKind = WatermarkLayoutKind.universal;
  late Uint8List _sourceBytes;
  late String _sourceFileName;
  String? _sourcePath;
  ui.Image? _sourceImage;
  ui.Image? _logoImage;
  Uint8List? _logoBytes;
  Uint8List? _initialLogoBytes;
  String? _logoPath;
  String? _initialLogoPath;
  String? _draftImportedLogoPath;
  bool _loading = true;
  bool _saving = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _sourceBytes = widget.sourceBytes;
    _sourceFileName = widget.sourceFileName;
    _sourcePath = widget.sourcePath;
    final state = ref.read(watermarkSettingsProvider);
    _settings = state.configuration;
    _initialSettings = state.configuration;
    _logoPath = state.localLogoPath;
    _initialLogoPath = state.localLogoPath;
    unawaited(_loadImages());
  }

  Future<void> _loadImages() async {
    try {
      final source = await _decodeSingleFrame(
        _sourceBytes,
        requireStatic: true,
      );
      ui.Image? logo;
      Uint8List? logoBytes;
      final path = _logoPath;
      if (path != null) {
        try {
          logoBytes = await _logoService.readValidated(path);
          logo = await _decodeSingleFrame(logoBytes);
        } on Object {
          logoBytes = null;
          logo = null;
        }
      }
      if (!mounted) {
        source.dispose();
        logo?.dispose();
        return;
      }
      setState(() {
        if (!widget.defaultsOnly && _settings.rememberLayoutsByOrientation) {
          _previewKind = WatermarkScene.classify(
            Size(source.width.toDouble(), source.height.toDouble()),
          );
        }
        _sourceImage = source;
        _logoImage = logo;
        _logoBytes = logoBytes;
        _initialLogoBytes = logoBytes;
        _loading = false;
      });
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to load watermark source image',
        error,
        stackTrace,
        'WatermarkEditor',
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
        throw const WatermarkRenderException(
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

  @override
  void dispose() {
    _renderToken?.cancel();
    _previewFocusNode.dispose();
    _sourceImage?.dispose();
    _logoImage?.dispose();
    final draftPath = _draftImportedLogoPath;
    if (draftPath != null) {
      unawaited(_deleteDraftLogo(draftPath));
    }
    super.dispose();
  }

  Future<void> _deleteDraftLogo(String path) async {
    try {
      await _logoService.deleteManaged(path);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to delete draft watermark logo',
        error,
        stackTrace,
        'WatermarkEditor',
      );
    }
  }

  WatermarkLayout get _activeLayout {
    if (!_settings.rememberLayoutsByOrientation ||
        _previewKind == WatermarkLayoutKind.universal) {
      return _settings.universalLayout;
    }
    return switch (_previewKind) {
      WatermarkLayoutKind.portrait => _settings.portraitLayout,
      WatermarkLayoutKind.square => _settings.squareLayout,
      WatermarkLayoutKind.landscape => _settings.landscapeLayout,
      WatermarkLayoutKind.universal => _settings.universalLayout,
    };
  }

  void _changeSettings(WatermarkSettings value, {bool recordUndo = true}) {
    if (recordUndo) {
      _undo.add(_settings);
      if (_undo.length > 50) _undo.removeAt(0);
      _redo.clear();
    }
    setState(() {
      _settings = value;
      if (!widget.defaultsOnly) {
        final source = _sourceImage;
        _previewKind = value.rememberLayoutsByOrientation && source != null
            ? WatermarkScene.classify(
                Size(source.width.toDouble(), source.height.toDouble()),
              )
            : WatermarkLayoutKind.universal;
      }
    });
  }

  void _changeLayout(WatermarkLayout value) {
    _changeSettings(
      WatermarkScene.updateLayout(_settings, _previewKind, value),
    );
  }

  void _undoChange() {
    if (_undo.isEmpty) return;
    _redo.add(_settings);
    setState(() => _settings = _undo.removeLast());
  }

  Future<void> _reset() async {
    _changeSettings(_initialSettings);
    final initialBytes = _initialLogoBytes;
    final restoredImage = initialBytes == null
        ? null
        : await _decodeSingleFrame(initialBytes);
    if (!mounted) {
      restoredImage?.dispose();
      return;
    }
    final draftPath = _draftImportedLogoPath;
    _logoImage?.dispose();
    setState(() {
      _logoPath = _initialLogoPath;
      _logoBytes = initialBytes;
      _logoImage = restoredImage;
      _draftImportedLogoPath = null;
    });
    if (draftPath != null) await _logoService.deleteManaged(draftPath);
  }

  Future<void> _chooseLogo() async {
    String? importedPath;
    var adopted = false;
    try {
      importedPath = await _logoService.pickAndImport(
        dialogTitle: context.l10n.watermark_chooseLogo,
      );
      if (importedPath == null) return;
      if (!mounted) {
        await _deleteDraftLogo(importedPath);
        return;
      }
      final bytes = await _logoService.readValidated(importedPath);
      final image = await _decodeSingleFrame(bytes);
      if (!mounted) {
        image.dispose();
        await _deleteDraftLogo(importedPath);
        return;
      }
      final previousDraft = _draftImportedLogoPath;
      _logoImage?.dispose();
      setState(() {
        _logoPath = importedPath;
        _draftImportedLogoPath = importedPath;
        _logoBytes = bytes;
        _logoImage = image;
      });
      adopted = true;
      if (previousDraft != null && previousDraft != importedPath) {
        await _deleteDraftLogo(previousDraft);
      }
      if (!_settings.logoStyle.enabled) {
        _changeSettings(
          _settings.copyWith(
            logoStyle: _settings.logoStyle.copyWith(enabled: true),
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      if (!adopted && importedPath != null) {
        await _deleteDraftLogo(importedPath);
      }
      AppLogger.e(
        'Failed to import watermark logo',
        error,
        stackTrace,
        'WatermarkEditor',
      );
      if (!mounted) return;
      _showError(context.l10n.watermark_logoImportFailed);
    }
  }

  Future<void> _setDefault() async {
    await ref.read(watermarkSettingsProvider.notifier).saveDefaults(_settings);
    final logoPath = _logoPath;
    if (logoPath != null) {
      final previousLogoPath = ref
          .read(watermarkSettingsProvider)
          .localLogoPath;
      await ref
          .read(watermarkSettingsProvider.notifier)
          .updateLocalLogoPath(logoPath);
      if (logoPath == _draftImportedLogoPath) {
        _draftImportedLogoPath = null;
      }
      if (previousLogoPath != null && previousLogoPath != logoPath) {
        await _logoService.deleteManaged(previousLogoPath);
      }
    }
    _initialSettings = _settings;
    _initialLogoPath = _logoPath;
    _initialLogoBytes = _logoBytes;
    _undo.clear();
    _redo.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.watermark_defaultSaved)),
    );
  }

  Future<void> _saveCopy() async {
    if (_saving) return;
    if ((!_settings.textStyle.enabled ||
            _settings.textStyle.text.trim().isEmpty) &&
        !_settings.logoStyle.enabled) {
      _showError(context.l10n.watermark_noLayer);
      return;
    }
    if (_settings.logoStyle.enabled && _logoBytes == null) {
      _showError(context.l10n.watermark_logoMissing);
      return;
    }
    final token = WatermarkCancellationToken();
    _renderToken = token;
    setState(() => _saving = true);
    try {
      final result = await WatermarkRenderService.render(
        WatermarkRenderRequest(
          sourceBytes: _sourceBytes,
          logoBytes: _logoBytes,
          settings: _settings,
          preserveMetadata: ref
              .read(watermarkSettingsProvider)
              .configuration
              .preserveMetadata,
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
            'Watermarked copy saved but system gallery export failed',
            error,
            stackTrace,
            'WatermarkEditor',
          );
        }
      }
      if (!mounted) return;
      final sourcePath = _sourcePath;
      if (sourcePath != null) {
        await WatermarkDerivativeRegistry(
          ref.read(localStorageServiceProvider),
        ).register(outputPath: output, sourcePath: sourcePath);
      }
      Object? galleryRefreshError;
      try {
        final previousError = ref.read(localGalleryNotifierProvider).error;
        await ref.read(localGalleryNotifierProvider.notifier).refresh();
        final refreshError = ref.read(localGalleryNotifierProvider).error;
        if (refreshError != null && !identical(refreshError, previousError)) {
          galleryRefreshError = refreshError;
          AppLogger.e(
            'Watermarked copy saved but gallery refresh failed',
            refreshError.details ?? refreshError.code.name,
            null,
            'WatermarkEditor',
          );
        }
      } on Object catch (error, stackTrace) {
        galleryRefreshError = error;
        AppLogger.e(
          'Watermarked copy saved but gallery refresh failed',
          error,
          stackTrace,
          'WatermarkEditor',
        );
      }
      if (!mounted) return;
      if (systemGalleryError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.watermark_systemGalleryExportFailed),
          ),
        );
      }
      if (galleryRefreshError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.watermark_galleryRefreshFailed)),
        );
      }
      await _showSaved(result, output);
      if (mounted) Navigator.of(context).pop(output);
    } on WatermarkCancelledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.watermark_cancelled)),
        );
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to create watermarked copy',
        error,
        stackTrace,
        'WatermarkEditor',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.watermark_failedGeneric),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _renderToken = null;
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSaved(WatermarkRenderResult result, String output) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.watermark_saved),
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
            label: Text(context.l10n.watermark_open),
          ),
          TextButton.icon(
            onPressed: () => _share(result),
            icon: const Icon(Icons.share_outlined),
            label: Text(context.l10n.watermark_share),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.common_close),
          ),
        ],
      ),
    );
  }

  Future<void> _share(WatermarkRenderResult result) async {
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

  void _openMetadataSettings() {
    context.go('${AppRoutes.settings}?section=privacy');
  }

  Future<void> _retryLoad() async {
    _sourceImage?.dispose();
    _logoImage?.dispose();
    _sourceImage = null;
    _logoImage = null;
    setState(() {
      _loadError = null;
      _loading = true;
    });
    await _loadImages();
  }

  Future<void> _chooseSource() async {
    final choose = widget.onChooseSource;
    if (choose == null) return;
    final selected = await choose();
    if (selected == null || !mounted) return;
    _sourceBytes = selected.bytes;
    _sourceFileName = selected.fileName;
    _sourcePath = selected.path;
    await _retryLoad();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.watermark_failed(error.toString())),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  KeyEventResult _handlePreviewKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    var delta = Offset.zero;
    final step = HardwareKeyboard.instance.isShiftPressed ? 0.01 : 0.002;
    if (key == LogicalKeyboardKey.arrowLeft) delta = Offset(-step, 0);
    if (key == LogicalKeyboardKey.arrowRight) delta = Offset(step, 0);
    if (key == LogicalKeyboardKey.arrowUp) delta = Offset(0, -step);
    if (key == LogicalKeyboardKey.arrowDown) delta = Offset(0, step);
    if (delta == Offset.zero) return KeyEventResult.ignored;
    _moveSelected(delta);
    return KeyEventResult.handled;
  }

  void _moveSelected(Offset ratioDelta) {
    final layout = _activeLayout;
    final grouped =
        _settings.composition.arrangement !=
        WatermarkLayerArrangement.independent;
    final useText = grouped || _selectedLayer == WatermarkEditableLayer.text;
    final placement = useText ? layout.textPlacement : layout.logoPlacement;
    double snapped(double value) =>
        value.abs() < 0.012 ? 0 : value.clamp(-0.5, 0.5);
    final moved = placement.copyWith(
      offsetXRatio: snapped(placement.offsetXRatio + ratioDelta.dx),
      offsetYRatio: snapped(placement.offsetYRatio + ratioDelta.dy),
    );
    _changeLayout(
      useText
          ? layout.copyWith(textPlacement: moved)
          : layout.copyWith(logoPlacement: moved),
    );
  }

  String _layoutStatus() {
    if (!_settings.rememberLayoutsByOrientation) {
      return context.l10n.watermark_layoutUniversal;
    }
    return switch (_previewKind) {
      WatermarkLayoutKind.portrait => context.l10n.watermark_layoutPortrait,
      WatermarkLayoutKind.square => context.l10n.watermark_layoutSquare,
      WatermarkLayoutKind.landscape => context.l10n.watermark_layoutLandscape,
      WatermarkLayoutKind.universal => context.l10n.watermark_layoutUniversal,
    };
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
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.watermark_editorTitle,
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
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
        ),
      );
    }
    if (_loadError != null || _sourceImage == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.watermark_sourceLoadFailed,
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
                        label: Text(context.l10n.watermark_chooseOriginal),
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
        final controls = WatermarkEditorControls(
          settings: _settings,
          layout: _activeLayout,
          selectedLayer: _selectedLayer,
          logoAvailable: _logoImage != null,
          preserveMetadata: ref
              .watch(watermarkSettingsProvider)
              .configuration
              .preserveMetadata,
          onOpenMetadataSettings: _openMetadataSettings,
          onSettingsChanged: _changeSettings,
          onLayoutChanged: _changeLayout,
          onSelectedLayerChanged: (value) =>
              setState(() => _selectedLayer = value),
          onChooseLogo: _chooseLogo,
        );
        if (AdaptiveBreakpoints.classifyWidth(
          constraints.maxWidth,
        ).isExpandedOrWider) {
          return Row(
            children: [
              Expanded(child: preview),
              const VerticalDivider(width: 1),
              SizedBox(width: 390, child: controls),
            ],
          );
        }
        final controlsHeight = math.min(330.0, constraints.maxHeight * 0.44);
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
    final originalAspect = source.width / source.height;
    final aspect = widget.defaultsOnly
        ? switch (_previewKind) {
            WatermarkLayoutKind.portrait => 9 / 16,
            WatermarkLayoutKind.square => 1.0,
            WatermarkLayoutKind.landscape => 16 / 9,
            WatermarkLayoutKind.universal => originalAspect,
          }
        : originalAspect;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          if (widget.defaultsOnly)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SegmentedButton<WatermarkLayoutKind>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: WatermarkLayoutKind.universal,
                    label: Text(context.l10n.watermark_ratioOriginal),
                  ),
                  ButtonSegment(
                    value: WatermarkLayoutKind.portrait,
                    label: Text(context.l10n.watermark_ratioPortrait),
                  ),
                  ButtonSegment(
                    value: WatermarkLayoutKind.square,
                    label: Text(context.l10n.watermark_ratioSquare),
                  ),
                  ButtonSegment(
                    value: WatermarkLayoutKind.landscape,
                    label: Text(context.l10n.watermark_ratioLandscape),
                  ),
                ],
                selected: {_previewKind},
                onSelectionChanged: (value) =>
                    setState(() => _previewKind = value.first),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: Focus(
                    focusNode: _previewFocusNode,
                    autofocus: true,
                    onKeyEvent: _handlePreviewKey,
                    child: LayoutBuilder(
                      builder: (context, previewConstraints) {
                        final size = previewConstraints.biggest;
                        return Semantics(
                          label:
                              '${_selectedLayer == WatermarkEditableLayer.text ? context.l10n.watermark_textLayer : context.l10n.watermark_logoLayer}. ${context.l10n.watermark_dragHint}',
                          customSemanticsActions: {
                            CustomSemanticsAction(
                              label: context.l10n.watermark_moveLeft,
                            ): () =>
                                _moveSelected(const Offset(-0.01, 0)),
                            CustomSemanticsAction(
                              label: context.l10n.watermark_moveRight,
                            ): () =>
                                _moveSelected(const Offset(0.01, 0)),
                            CustomSemanticsAction(
                              label: context.l10n.watermark_moveUp,
                            ): () =>
                                _moveSelected(const Offset(0, -0.01)),
                            CustomSemanticsAction(
                              label: context.l10n.watermark_moveDown,
                            ): () =>
                                _moveSelected(const Offset(0, 0.01)),
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (_) => _previewFocusNode.requestFocus(),
                            onPanStart: (_) => _previewFocusNode.requestFocus(),
                            onPanUpdate: (details) {
                              final shortEdge = math.min(
                                size.width,
                                size.height,
                              );
                              if (shortEdge > 0) {
                                _moveSelected(details.delta / shortEdge);
                              }
                            },
                            child: ClipRect(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  RawImage(
                                    image: source,
                                    fit: BoxFit.fill,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                  CustomPaint(
                                    painter: _WatermarkPreviewPainter(
                                      settings: _settings,
                                      logo: _logoImage,
                                      selectedLayer: _selectedLayer,
                                      selectionColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              children: [
                Text(
                  _layoutStatus(),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  context.l10n.watermark_dragHint,
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

  Widget _buildActions() {
    final ready = _sourceImage != null && !_loading && _loadError == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 600 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.watermark_undo,
                  onPressed: _undo.isEmpty || _saving || !ready
                      ? null
                      : _undoChange,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: context.l10n.watermark_reset,
                  onPressed: _saving || !ready ? null : _reset,
                  icon: const Icon(Icons.restart_alt),
                ),
                const SizedBox(width: 4),
                const Spacer(),
                if (widget.defaultsOnly)
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: _saving || !ready ? null : _setDefault,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(
                        context.l10n.watermark_setDefault,
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                    ),
                  )
                else if (compact)
                  IconButton(
                    tooltip: context.l10n.watermark_setDefault,
                    onPressed: _saving || !ready ? null : _setDefault,
                    icon: const Icon(Icons.bookmark_add_outlined),
                  )
                else
                  TextButton.icon(
                    onPressed: _saving || !ready ? null : _setDefault,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(context.l10n.watermark_setDefault),
                  ),
                if (!widget.defaultsOnly) ...[
                  const SizedBox(width: 8),
                  if (compact)
                    FilledButton.icon(
                      onPressed: _saving || !ready ? null : _saveCopy,
                      icon: _saving
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: MediaQuery.disableAnimationsOf(context)
                                    ? 0.72
                                    : null,
                              ),
                            )
                          : const Icon(Icons.save_alt),
                      label: Text(context.l10n.common_save),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _saving || !ready ? null : _saveCopy,
                      icon: _saving
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: MediaQuery.disableAnimationsOf(context)
                                    ? 0.72
                                    : null,
                              ),
                            )
                          : const Icon(Icons.save_alt),
                      label: Text(
                        _saving
                            ? context.l10n.watermark_saving
                            : context.l10n.watermark_saveCopy,
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

class _WatermarkPreviewPainter extends CustomPainter {
  const _WatermarkPreviewPainter({
    required this.settings,
    required this.logo,
    required this.selectedLayer,
    required this.selectionColor,
  });

  final WatermarkSettings settings;
  final ui.Image? logo;
  final WatermarkEditableLayer selectedLayer;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    final result = WatermarkScene.paint(
      canvas: canvas,
      canvasSize: size,
      settings: settings,
      logo: logo,
    );
    final kind = selectedLayer == WatermarkEditableLayer.text
        ? WatermarkLayerKind.text
        : WatermarkLayerKind.logo;
    final bounds = result.boundsFor(kind);
    if (bounds != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds.inflate(4), const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = selectionColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WatermarkPreviewPainter oldDelegate) =>
      oldDelegate.settings != settings ||
      oldDelegate.logo != logo ||
      oldDelegate.selectedLayer != selectedLayer ||
      oldDelegate.selectionColor != selectionColor;
}
