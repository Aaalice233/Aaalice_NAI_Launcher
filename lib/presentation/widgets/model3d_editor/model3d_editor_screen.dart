import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../l10n/app_localizations.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';
import '../image_editor/layers/model3d_layer_data.dart';
import 'local_asset_server.dart';
import 'model3d_bridge.dart';
import 'model3d_library_service.dart';
import 'model3d_web_viewport.dart';

/// 编辑结果:透明 PNG + 场景状态 + 模型引用
class Model3dEditResult {
  final Uint8List pngBytes;
  final Map<String, dynamic> sceneState;
  final String modelRef;

  const Model3dEditResult({
    required this.pngBytes,
    required this.sceneState,
    required this.modelRef,
  });
}

/// 3D 模型图层全屏编辑器
class Model3dEditorScreen extends StatefulWidget {
  final Model3dLayerData? existing;
  final int renderWidth;
  final int renderHeight;
  final Model3dLibraryService? libraryService;

  /// 测试注入口
  final Model3dBridge? bridgeOverride;
  final WidgetBuilder? viewportBuilder;
  final LocalAssetServer? serverOverride;
  final Future<File?> Function()? pickModelFile;
  final bool markReadyForTest;

  const Model3dEditorScreen({
    super.key,
    this.existing,
    required this.renderWidth,
    required this.renderHeight,
    this.libraryService,
    this.bridgeOverride,
    this.viewportBuilder,
    this.serverOverride,
    this.pickModelFile,
    this.markReadyForTest = false,
  });

  static Future<Model3dEditResult?> show(
    BuildContext context, {
    Model3dLayerData? existing,
    required int renderWidth,
    required int renderHeight,
    Model3dLibraryService? libraryService,
  }) {
    return Navigator.push<Model3dEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => Model3dEditorScreen(
          existing: existing,
          renderWidth: renderWidth,
          renderHeight: renderHeight,
          libraryService: libraryService,
        ),
      ),
    );
  }

  @override
  State<Model3dEditorScreen> createState() => _Model3dEditorScreenState();
}

class _Model3dEditorScreenState extends State<Model3dEditorScreen> {
  LocalAssetServer? _server;
  Model3dBridge? _bridge;
  Model3dLibraryService? _library;
  Uri? _editorUrl;

  bool _ready = false;
  bool _dirty = false;
  bool _busy = false;
  String? _modelRef;
  String _mode = 'transform';
  String _gizmo = 'translate';

  /// 光照参数(与 editor.js 的默认 lightParams 一致)
  double _lightIntensity = 1.6;
  double _lightAzimuth = 37;
  double _lightElevation = 50;

  @override
  void initState() {
    super.initState();
    _bridge = widget.bridgeOverride; // 真桥在 WebView controller 就绪后创建
    if (widget.markReadyForTest) {
      _ready = true;
      // 与真实 onReady 事件走同一条恢复路径,让测试覆盖 existing 恢复逻辑
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreExisting();
      });
    }
    _startServices();
  }

  Future<void> _startServices() async {
    final library = widget.libraryService ?? await _defaultLibrary();
    if (widget.viewportBuilder == null) {
      final server =
          widget.serverOverride ??
          LocalAssetServer(modelLibraryDir: library.libraryDir);
      final base = await server.start();
      if (!mounted) {
        await server.stop();
        return;
      }
      setState(() {
        _server = server;
        _editorUrl = base.resolve('editor/editor.html');
      });
    }
    _library = library;
  }

  Future<Model3dLibraryService> _defaultLibrary() async {
    final support = await getApplicationSupportDirectory();
    return Model3dLibraryService(
      libraryDir: Directory('${support.path}/model3d_library'),
    );
  }

  @override
  void dispose() {
    _bridge?.dispose();
    _server?.stop();
    super.dispose();
  }

  void _onBridgeEvent(String type, Map<String, dynamic> data) {
    if (!mounted) return;
    switch (type) {
      case 'onReady':
        setState(() => _ready = true);
        _restoreExisting();
      case 'onDirty':
        setState(() => _dirty = true);
      case 'onLoadError':
        _showSnack('${context.l10n.model3d_loadError}: ${data['error'] ?? ''}');
    }
  }

  Future<void> _restoreExisting() async {
    final existing = widget.existing;
    if (existing == null) return;
    if (existing.modelRef == Model3dLibraryService.builtinMannequinRef) {
      // 恢复已保存的图层不算脏:未做任何新修改就返回时不应弹放弃确认
      await _loadBuiltin(
        sceneState: existing.sceneState,
        confirm: false,
        markDirty: false,
      );
      return;
    }
    final library = _library;
    final file = library?.resolveFile(existing.modelRef);
    if (library == null || file == null || !file.existsSync()) {
      _showSnack(context.l10n.model3d_missingModel);
      return;
    }
    final path = library.urlPathFor(existing.modelRef)!;
    await _runBusy(() async {
      await _bridge!.loadModel(
        url: _editorUrl!.resolve(path).toString(),
        sceneState: existing.sceneState,
      );
      if (!mounted) return;
      setState(() {
        _modelRef = existing.modelRef;
        _dirty = false;
      });
    });
  }

  Future<bool> _confirmReplace() async {
    if (_modelRef == null) return true;
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(context.l10n.model3d_replaceConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    return answer == true;
  }

  Future<void> _loadBuiltin({
    Map<String, dynamic>? sceneState,
    bool confirm = true,
    bool markDirty = true,
  }) async {
    if (confirm && !await _confirmReplace()) return;
    await _runBusy(() async {
      await _bridge!.loadModel(builtin: 'mannequin', sceneState: sceneState);
      if (!mounted) return;
      setState(() {
        _modelRef = Model3dLibraryService.builtinMannequinRef;
        _dirty = markDirty;
      });
    });
  }

  Future<void> _importModel() async {
    if (!await _confirmReplace()) return;
    final pick = widget.pickModelFile ?? _pickWithFilePicker;
    final file = await pick();
    if (file == null || _library == null) return;
    await _runBusy(() async {
      try {
        final ref = await _library!.importModel(file);
        final path = _library!.urlPathFor(ref)!;
        await _bridge!.loadModel(url: _editorUrl!.resolve(path).toString());
        if (!mounted) return;
        setState(() {
          _modelRef = ref;
          _dirty = true;
        });
      } on Model3dImportException catch (e) {
        if (!mounted) return;
        _showSnack('${context.l10n.model3d_loadError}: ${e.message}');
      }
    });
  }

  Future<File?> _pickWithFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'gltf'],
    );
    final path = result?.files.single.path;
    return path == null ? null : File(path);
  }

  Future<void> _apply() async {
    await _runBusy(() async {
      final sceneState = await _bridge!.serialize();
      final png = await _bridge!.render(
        width: widget.renderWidth,
        height: widget.renderHeight,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        Model3dEditResult(
          pngBytes: png,
          sceneState: sceneState,
          modelRef: _modelRef!,
        ),
      );
    });
  }

  Future<void> _setMode(String mode, String gizmo) async {
    setState(() {
      _mode = mode;
      _gizmo = gizmo;
    });
    await _bridge!.setMode(mode: mode, gizmo: gizmo);
  }

  Future<void> _showLightDialog() async {
    await AdaptivePresenter.showForm<void>(
      context: context,
      title: context.l10n.model3d_light,
      sideSheetWidth: 520,
      builder: (panelContext, scrollController) => StatefulBuilder(
        builder: (context, setFormState) {
          void updateLight(ValueChanged<double> update, double value) {
            setFormState(() => update(value));
            _bridge?.setLight(
              intensity: _lightIntensity,
              azimuth: _lightAzimuth,
              elevation: _lightElevation,
            );
          }

          final l10n = panelContext.l10n;
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              _LightSliderField(
                key: const ValueKey('model3d-light-intensity'),
                label: l10n.model3d_lightIntensity,
                value: _lightIntensity,
                min: 0,
                max: 3,
                onChanged: (value) =>
                    updateLight((next) => _lightIntensity = next, value),
              ),
              const SizedBox(height: 20),
              _LightSliderField(
                key: const ValueKey('model3d-light-azimuth'),
                label: l10n.model3d_lightAzimuth,
                value: _lightAzimuth,
                min: -180,
                max: 180,
                onChanged: (value) =>
                    updateLight((next) => _lightAzimuth = next, value),
              ),
              const SizedBox(height: 20),
              _LightSliderField(
                key: const ValueKey('model3d-light-elevation'),
                label: l10n.model3d_lightElevation,
                value: _lightElevation,
                min: 0,
                max: 90,
                onChanged: (value) =>
                    updateLight((next) => _lightElevation = next, value),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Model3dBridgeException catch (e) {
      _showSnack(e.message);
    } on TimeoutException catch (e) {
      _showSnack(e.message ?? 'timeout');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(context.l10n.model3d_discardConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    return answer == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasModel = _modelRef != null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmExit();
        if (!context.mounted) return;
        if (shouldPop) {
          Navigator.pop(context);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactActions = constraints.maxWidth < 520;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                l10n.model3d_editorTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  tooltip: l10n.model3d_undo,
                  icon: const Icon(Icons.undo),
                  onPressed: hasModel && !_busy
                      ? () => _bridge!.undoPose()
                      : null,
                ),
                IconButton(
                  tooltip: l10n.model3d_resetPose,
                  icon: const Icon(Icons.restart_alt),
                  onPressed: hasModel && !_busy
                      ? () => _bridge!.resetPose()
                      : null,
                ),
                const SizedBox(width: 4),
                if (compactActions)
                  IconButton.filled(
                    constraints: BoxConstraints.tightFor(
                      width: context.interactionPolicy.minimumControlExtent,
                      height: context.interactionPolicy.minimumControlExtent,
                    ),
                    tooltip: l10n.model3d_apply,
                    onPressed: hasModel && !_busy ? _apply : null,
                    icon: const Icon(Icons.check),
                  )
                else
                  FilledButton(
                    onPressed: hasModel && !_busy ? _apply : null,
                    child: Text(l10n.model3d_apply),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildToolbar(l10n, hasModel),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.viewportBuilder != null)
                          widget.viewportBuilder!(context)
                        else if (_editorUrl != null)
                          Model3dWebViewport(
                            editorUrl: _editorUrl!,
                            onBridgeMessage: (args) =>
                                _bridge?.handleJsMessage(args),
                            onControllerReady: (controller) {
                              _bridge ??= Model3dBridge(
                                evalJs: (source) => controller
                                    .evaluateJavascript(source: source),
                                onEvent: _onBridgeEvent,
                              );
                            },
                          )
                        else
                          Center(
                            child: CircularProgressIndicator(
                              value: MediaQuery.disableAnimationsOf(context)
                                  ? 0.72
                                  : null,
                            ),
                          ),
                        if (_ready && !hasModel) _buildEmptyState(l10n),
                        if (_busy)
                          ColoredBox(
                            color: const Color(0x66000000),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: MediaQuery.disableAnimationsOf(context)
                                    ? 0.72
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar(AppLocalizations l10n, bool hasModel) {
    // 用横向滚动包裹:分段按钮的多语言文案长度不一,窄窗口下避免 RenderFlex 溢出。
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: context.interactionPolicy.minimumControlExtent + 12,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'transform',
                    label: Text(l10n.model3d_modeTransform),
                  ),
                  ButtonSegment(
                    value: 'pose',
                    label: Text(l10n.model3d_modePose),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: hasModel
                    ? (selection) => _setMode(
                        selection.first,
                        selection.first == 'pose' ? 'rotate' : _gizmo,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'translate',
                    label: Text(l10n.model3d_gizmoTranslate),
                  ),
                  ButtonSegment(
                    value: 'rotate',
                    label: Text(l10n.model3d_gizmoRotate),
                  ),
                  ButtonSegment(
                    value: 'scale',
                    label: Text(l10n.model3d_gizmoScale),
                  ),
                ],
                selected: {_gizmo},
                onSelectionChanged: hasModel
                    ? (selection) => _setMode(_mode, selection.first)
                    : null,
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: l10n.model3d_light,
                icon: const Icon(Icons.light_mode, size: 20),
                onPressed: hasModel && !_busy ? _showLightDialog : null,
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: l10n.model3d_addMannequin,
                icon: const Icon(Icons.accessibility_new, size: 20),
                onPressed: _ready && !_busy ? () => _loadBuiltin() : null,
              ),
              IconButton(
                tooltip: l10n.model3d_importModel,
                icon: const Icon(Icons.file_open, size: 20),
                onPressed: _ready && !_busy ? _importModel : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.model3d_emptyHint),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _loadBuiltin(confirm: false),
                    icon: const Icon(Icons.accessibility_new),
                    label: Text(l10n.model3d_addMannequin),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _importModel,
                    icon: const Icon(Icons.file_open),
                    label: Text(l10n.model3d_importModel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LightSliderField extends StatelessWidget {
  const _LightSliderField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
            const SizedBox(width: 12),
            Text(
              value.toStringAsFixed(1),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
