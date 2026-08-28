import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/inpaint_outpaint_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/services/efficient_vit_sam_service.dart';
import 'core/editor_state.dart';
import 'image_editor_controller.dart';
import 'image_editor_types.dart';
import 'image_editor_workspace.dart';

export 'image_editor_types.dart';

class ImageEditorScreen extends StatefulWidget {
  const ImageEditorScreen({
    super.key,
    this.initialImage,
    this.initialSize,
    this.existingMask,
    this.existingFocusRect,
    this.initialMinimumContextMegaPixels = 88.0,
    this.initialFocusedInpaintEnabled = false,
    this.focusedInpaintCostConfig,
    this.showMaskExport = true,
    this.mode = ImageEditorMode.edit,
    this.title = '',
    this.initialOutpaintCommitPending = false,
    this.initialShowLayerPanel = true,
    this.debugFailOutpaintSourceReplacement = false,
    this.debugFailOutpaintAfterFocusedDisable = false,
    this.debugDisableDropRegion = false,
    this.debugEfficientVitSamSelector,
  });

  factory ImageEditorScreen.config({
    Key? key,
    required ImageEditorSessionConfig config,
  }) {
    final debug = config.debugOptions;
    return ImageEditorScreen(
      key: key,
      initialImage: config.initialImage,
      initialSize: config.initialSize,
      existingMask: config.existingMask,
      existingFocusRect: config.existingFocusRect,
      initialMinimumContextMegaPixels: config.initialMinimumContextMegaPixels,
      initialFocusedInpaintEnabled: config.initialFocusedInpaintEnabled,
      focusedInpaintCostConfig: config.focusedInpaintCostConfig,
      showMaskExport: config.showMaskExport,
      mode: config.mode,
      title: config.title,
      initialOutpaintCommitPending: debug.initialOutpaintCommitPending,
      initialShowLayerPanel: debug.initialShowLayerPanel,
      debugFailOutpaintSourceReplacement: debug.failOutpaintSourceReplacement,
      debugFailOutpaintAfterFocusedDisable:
          debug.failOutpaintAfterFocusedDisable,
      debugDisableDropRegion: debug.disableDropRegion,
      debugEfficientVitSamSelector: debug.efficientVitSamSelector,
    );
  }

  final Uint8List? initialImage;
  final Size? initialSize;
  final Uint8List? existingMask;
  final Rect? existingFocusRect;
  final double initialMinimumContextMegaPixels;
  final bool initialFocusedInpaintEnabled;
  final ImageEditorFocusedInpaintCostConfig? focusedInpaintCostConfig;
  final bool showMaskExport;
  final ImageEditorMode mode;
  final String title;

  @visibleForTesting
  final bool initialOutpaintCommitPending;
  @visibleForTesting
  final bool initialShowLayerPanel;
  @visibleForTesting
  final bool debugFailOutpaintSourceReplacement;
  @visibleForTesting
  final bool debugFailOutpaintAfterFocusedDisable;
  @visibleForTesting
  final bool debugDisableDropRegion;
  @visibleForTesting
  final EfficientVitSamSelector? debugEfficientVitSamSelector;

  ImageEditorSessionConfig get sessionConfig => ImageEditorSessionConfig(
    initialImage: initialImage,
    initialSize: initialSize,
    existingMask: existingMask,
    existingFocusRect: existingFocusRect,
    initialMinimumContextMegaPixels: initialMinimumContextMegaPixels,
    initialFocusedInpaintEnabled: initialFocusedInpaintEnabled,
    focusedInpaintCostConfig: focusedInpaintCostConfig,
    showMaskExport: showMaskExport,
    mode: mode,
    title: title,
    debugOptions: ImageEditorDebugOptions(
      initialOutpaintCommitPending: initialOutpaintCommitPending,
      initialShowLayerPanel: initialShowLayerPanel,
      failOutpaintSourceReplacement: debugFailOutpaintSourceReplacement,
      failOutpaintAfterFocusedDisable: debugFailOutpaintAfterFocusedDisable,
      disableDropRegion: debugDisableDropRegion,
      efficientVitSamSelector: debugEfficientVitSamSelector,
    ),
  );

  static Future<ImageEditorResult?> show(
    BuildContext context, {
    Uint8List? initialImage,
    Size? initialSize,
    Uint8List? existingMask,
    Rect? existingFocusRect,
    double initialMinimumContextMegaPixels = 88.0,
    bool initialFocusedInpaintEnabled = false,
    ImageEditorFocusedInpaintCostConfig? focusedInpaintCostConfig,
    bool showMaskExport = true,
    ImageEditorMode mode = ImageEditorMode.edit,
    String? title,
  }) {
    return Navigator.of(context, rootNavigator: true).push<ImageEditorResult>(
      MaterialPageRoute(
        builder: (context) => ImageEditorScreen(
          initialImage: initialImage,
          initialSize: initialSize,
          existingMask: existingMask,
          existingFocusRect: existingFocusRect,
          initialMinimumContextMegaPixels: initialMinimumContextMegaPixels,
          initialFocusedInpaintEnabled: initialFocusedInpaintEnabled,
          focusedInpaintCostConfig: focusedInpaintCostConfig,
          showMaskExport: showMaskExport,
          mode: mode,
          title: title ?? context.l10n.editor_defaultTitle,
        ),
      ),
    );
  }

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  late final ImageEditorController controller;
  final workspaceKey = GlobalKey<ImageEditorWorkspaceState>();

  ImageEditorWorkspaceState get _workspace => workspaceKey.currentState!;

  @visibleForTesting
  Size get debugCanvasSize => _workspace.debugCanvasSize;
  @visibleForTesting
  Size get debugCompressionTargetSize => _workspace.debugCompressionTargetSize;
  @visibleForTesting
  int get debugCompressionTargetCount => _workspace.debugCompressionTargetCount;
  @visibleForTesting
  bool get debugCompressionApplied => _workspace.debugCompressionApplied;
  @visibleForTesting
  void debugSetCompressionTargetIndex(int index) =>
      _workspace.debugSetCompressionTargetIndex(index);
  @visibleForTesting
  bool get debugFocusedInpaintEnabled => _workspace.debugFocusedInpaintEnabled;
  @visibleForTesting
  bool get debugHasOutpaintChanges => _workspace.debugHasOutpaintChanges;
  @visibleForTesting
  bool get debugOutpaintCommitPending => _workspace.debugOutpaintCommitPending;
  @visibleForTesting
  List<Rect> get debugVirtualOutpaintMaskRects =>
      _workspace.debugVirtualOutpaintMaskRects;
  @visibleForTesting
  int? get debugOutpaintSourceWidth => _workspace.debugOutpaintSourceWidth;
  @visibleForTesting
  int? get debugOutpaintSourceHeight => _workspace.debugOutpaintSourceHeight;
  @visibleForTesting
  String? get debugCurrentToolId => _workspace.debugCurrentToolId;
  @visibleForTesting
  String? get debugActiveLayerId => _workspace.debugActiveLayerId;
  @visibleForTesting
  String? get debugActiveLayerName => _workspace.debugActiveLayerName;
  @visibleForTesting
  int get debugActiveLayerStrokeCount => _workspace.debugActiveLayerStrokeCount;
  @visibleForTesting
  bool get debugIsDrawing => _workspace.debugIsDrawing;
  @visibleForTesting
  bool get debugActiveLayerHasBaseImage =>
      _workspace.debugActiveLayerHasBaseImage;
  @visibleForTesting
  int get debugCurrentStrokePointCount =>
      _workspace.debugCurrentStrokePointCount;
  @visibleForTesting
  bool get debugHasMaskContent => _workspace.debugHasMaskContent;
  @visibleForTesting
  bool get debugMagicWandProcessing => _workspace.debugMagicWandProcessing;
  @visibleForTesting
  Future<void> debugApplyMagicWand(
    Offset point, {
    MagicWandSelectionMode mode = MagicWandSelectionMode.colorArea,
    int tolerance = 32,
    bool invert = false,
  }) => _workspace.debugApplyMagicWand(
    point,
    mode: mode,
    tolerance: tolerance,
    invert: invert,
  );
  @visibleForTesting
  bool debugUndo() => _workspace.debugUndo();
  @visibleForTesting
  Offset debugCanvasToScreen(Offset point) =>
      _workspace.debugCanvasToScreen(point);
  @visibleForTesting
  Rect? get debugFocusedRect => _workspace.debugFocusedRect;
  @visibleForTesting
  Rect? get debugSelectionBounds => _workspace.debugSelectionBounds;
  @visibleForTesting
  Rect? get debugPreviewBounds => _workspace.debugPreviewBounds;
  @visibleForTesting
  List<String> get debugLayerNames => _workspace.debugLayerNames;
  @visibleForTesting
  Future<void> debugApplyOutpaintEdges(
    OutpaintEdges edges, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) => _workspace.debugApplyOutpaintEdges(
    edges,
    horizontalSnapTarget: horizontalSnapTarget,
    verticalSnapTarget: verticalSnapTarget,
  );
  @visibleForTesting
  Future<void> debugApplyOutpaintFrameDelta(
    OutpaintFrameDelta delta, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) => _workspace.debugApplyOutpaintFrameDelta(
    delta,
    horizontalSnapTarget: horizontalSnapTarget,
    verticalSnapTarget: verticalSnapTarget,
  );
  @visibleForTesting
  Future<void> debugApplyOutpaintFrameDeltaMaterialized(
    OutpaintFrameDelta delta, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) => _workspace.debugApplyOutpaintFrameDeltaMaterialized(
    delta,
    horizontalSnapTarget: horizontalSnapTarget,
    verticalSnapTarget: verticalSnapTarget,
  );
  @visibleForTesting
  Future<void> debugExportAndClose() => _workspace.debugExportAndClose();
  @visibleForTesting
  Future<void> debugImportDroppedImageLayer(String name, Uint8List bytes) =>
      _workspace.debugImportDroppedImageLayer(name, bytes);
  @visibleForTesting
  void debugSetToolById(String id) => _workspace.debugSetToolById(id);
  @visibleForTesting
  void debugSetSelectionRect(Rect rect) =>
      _workspace.debugSetSelectionRect(rect);
  @visibleForTesting
  void debugSetPreviewRect(Rect rect) => _workspace.debugSetPreviewRect(rect);

  @override
  void initState() {
    super.initState();
    controller = ImageEditorController(config: widget.sessionConfig);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ImageEditorWorkspace(
      key: workspaceKey,
      controller: controller,
      config: controller.config,
    );
  }
}
