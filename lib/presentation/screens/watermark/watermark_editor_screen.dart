import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/derivatives/derivative_registry.dart';
import '../../../core/services/native_share_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/watermark/watermark_logo_service.dart';
import '../../../core/watermark/watermark_render_service.dart';
import '../../../core/watermark/watermark_scene.dart';
import '../../../core/watermark/watermark_source_analysis.dart';
import '../../../core/watermark/watermark_tone.dart';
import '../../../data/models/watermark/watermark_settings.dart';
import '../../adaptive/adaptive_layout.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../providers/watermark_settings_provider.dart';
import '../../router/app_routes.dart';
import '../derivatives/derivative_copy_saver.dart';
import 'watermark_editor_controls.dart';
import 'watermark_editor_preview.dart';

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
    this.decodePreview = WatermarkRenderService.decodePreview,
    this.renderCopy = WatermarkRenderService.render,
  });

  final Uint8List sourceBytes;
  final String sourceFileName;
  final String? sourcePath;
  final bool defaultsOnly;
  final Future<WatermarkEditorSource?> Function()? onChooseSource;
  final WatermarkPreviewDecoder decodePreview;
  final WatermarkRenderOperation renderCopy;

  @override
  ConsumerState<WatermarkEditorScreen> createState() =>
      _WatermarkEditorScreenState();
}

typedef _AutoDecisionKey = (
  WatermarkSettings,
  WatermarkSourceAnalysis,
  ui.Image?,
  WatermarkLogoLuminance?,
  Size,
);

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
  WatermarkSourceAnalysis? _analysis;
  bool _analysisFailed = false;
  WatermarkLogoLuminance? _logoLuminance;
  ({_AutoDecisionKey key, WatermarkAutoDecision value})? _autoDecisionCache;
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
      final source = await widget.decodePreview(
        _sourceBytes,
        requireStatic: true,
      );
      ui.Image? logo;
      Uint8List? logoBytes;
      final path = _logoPath;
      if (path != null) {
        try {
          logoBytes = await _logoService.readValidated(path);
          logo = await widget.decodePreview(logoBytes);
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
        _logoLuminance = null;
        _initialLogoBytes = logoBytes;
        _loading = false;
      });
      // 分析只影响预览的自动调整，不阻塞编辑器打开
      unawaited(_analyzeSource(_sourceBytes));
      unawaited(_measureLogo(logoBytes));
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

  Future<void> _analyzeSource(Uint8List bytes) async {
    try {
      final analysis = await WatermarkSourceAnalysis.fromEncoded(bytes);
      if (!mounted || !identical(bytes, _sourceBytes)) return;
      setState(() => _analysis = analysis);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to analyze watermark source image',
        error,
        stackTrace,
        'WatermarkEditor',
      );
      if (!mounted || !identical(bytes, _sourceBytes)) return;
      setState(() => _analysisFailed = true);
    }
  }

  Future<void> _measureLogo(Uint8List? bytes) async {
    if (bytes == null) return;
    try {
      final luminance = await WatermarkLogoLuminance.fromEncoded(bytes);
      if (!mounted || !identical(bytes, _logoBytes)) return;
      setState(() => _logoLuminance = luminance);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to measure watermark logo luminance',
        error,
        stackTrace,
        'WatermarkEditor',
      );
    }
  }

  /// 在保存时的原尺寸上判定，预览只缩放绘制，选位与灰阶与保存结果一致
  WatermarkAutoDecision get _autoDecision {
    final analysis = _analysis;
    if (analysis == null || _sourceImage == null) {
      return WatermarkAutoDecision.none;
    }
    final canvasSize = _decisionCanvasSize(analysis.sourceSize);
    final key = (_settings, analysis, _logoImage, _logoLuminance, canvasSize);
    final cached = _autoDecisionCache;
    if (cached != null && cached.key == key) return cached.value;
    final value = WatermarkScene.decide(
      canvasSize: canvasSize,
      settings: _settings,
      analysis: analysis,
      logo: _logoImage,
      logoLuminance: _logoLuminance,
    );
    _autoDecisionCache = (key: key, value: value);
    return value;
  }

  // 默认方案的竖图/方图/横图预览把示例图拉伸到该比例，判定画布保持原图短边、换成预览比例
  Size _decisionCanvasSize(Size sourceSize) {
    if (!widget.defaultsOnly || _previewKind == WatermarkLayoutKind.universal) {
      return sourceSize;
    }
    final aspect = _previewAspect;
    final shortEdge = math.min(sourceSize.width, sourceSize.height);
    return aspect >= 1
        ? Size(shortEdge * aspect, shortEdge)
        : Size(shortEdge, shortEdge / aspect);
  }

  double get _previewAspect {
    final source = _sourceImage!;
    final originalAspect = source.width / source.height;
    if (!widget.defaultsOnly) return originalAspect;
    return switch (_previewKind) {
      WatermarkLayoutKind.portrait => 9 / 16,
      WatermarkLayoutKind.square => 1.0,
      WatermarkLayoutKind.landscape => 16 / 9,
      WatermarkLayoutKind.universal => originalAspect,
    };
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
        : await widget.decodePreview(initialBytes);
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
      _logoLuminance = null;
      _draftImportedLogoPath = null;
    });
    unawaited(_measureLogo(initialBytes));
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
      final image = await widget.decodePreview(bytes);
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
        _logoLuminance = null;
      });
      unawaited(_measureLogo(bytes));
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
    final saver = ref.read(
      derivativeCopySaverProvider(DerivativeKind.watermark),
    );
    final notices = DerivativeCopyFollowUpNotices.capture(
      context,
      systemGalleryFailed: context.l10n.watermark_systemGalleryExportFailed,
      galleryIndexFailed: context.l10n.watermark_galleryRefreshFailed,
    );
    final sourceBytes = _sourceBytes;
    final sourcePath = _sourcePath;
    final token = WatermarkCancellationToken();
    _renderToken = token;
    setState(() => _saving = true);
    try {
      final result = await widget.renderCopy(
        WatermarkRenderRequest(
          sourceBytes: sourceBytes,
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
      final galleryRoot = await saver.resolveGalleryRoot();
      if (!mounted || token.isCancelled) return;
      if (galleryRoot == null) {
        throw StateError(context.l10n.localGallery_saveDirectoryNotSet);
      }
      final output = await saver.write(
        rootPath: galleryRoot,
        bytes: result.bytes,
        fileName: result.fileName,
      );
      // 文件已落盘，之后的登记与收录不能再把编辑器卡在保存态
      notices.watch(
        saver.followUp(
          outputPath: output,
          outputBytes: result.bytes,
          fileName: result.fileName,
          sourceBytes: sourceBytes,
          sourcePath: sourcePath,
        ),
      );
      if (!mounted) return;
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
      _analysis = null;
      _analysisFailed = false;
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

  void _moveSelected(Offset displayedDelta) {
    // 画面上看到的是镜像后的位置，位移换回用户设定的布局坐标再写入
    final ratioDelta = _autoDecision.mirror.delta(displayedDelta);
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

  Widget _buildPreview() => WatermarkEditorPreview(
    source: _sourceImage!,
    aspectRatio: _previewAspect,
    settings: _settings,
    decision: _autoDecision,
    analysis: _analysisFailed
        ? WatermarkPreviewAnalysis.failed
        : _analysis == null
        ? WatermarkPreviewAnalysis.pending
        : WatermarkPreviewAnalysis.ready,
    logo: _logoImage,
    selectedLayer: _selectedLayer,
    layoutKind: _previewKind,
    focusNode: _previewFocusNode,
    onMove: _moveSelected,
    onLayoutKindChanged: widget.defaultsOnly
        ? (value) => setState(() => _previewKind = value)
        : null,
  );

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
