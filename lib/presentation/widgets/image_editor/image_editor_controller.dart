import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/utils/editor_compression_utils.dart';
import '../../../core/utils/inpaint_outpaint_utils.dart';
import 'core/editor_state.dart';
import 'core/focused_selection_state.dart';
import 'document_transaction.dart';
import 'image_editor_processing_service.dart';
import 'image_editor_types.dart';

@immutable
class ImageEditorSessionSnapshot {
  ImageEditorSessionSnapshot({
    required this.minimumContextMegaPixels,
    required this.focusedInpaintEnabled,
    required this.compressionPlan,
    required this.compressionTarget,
    required this.isInitialized,
    required this.didStartInitialization,
    required this.isOutpaintCommitPending,
    required this.sourceLayerId,
    required Uint8List? outpaintSourceImage,
    required this.outpaintSourceWidth,
    required this.outpaintSourceHeight,
    required Uint8List? inpaintWorkingSourceImage,
    required this.inpaintWorkingSourceWidth,
    required this.inpaintWorkingSourceHeight,
    required this.initialSourceWidth,
    required this.initialSourceHeight,
    required this.sourceWasNormalized,
    required this.virtualOutpaintFrame,
    required this.hasOutpaintChanges,
    required this.isImportingDroppedImage,
    required this.hasTransparentCutout,
  }) : outpaintSourceImage = outpaintSourceImage == null
           ? null
           : Uint8List.fromList(outpaintSourceImage),
       inpaintWorkingSourceImage = inpaintWorkingSourceImage == null
           ? null
           : Uint8List.fromList(inpaintWorkingSourceImage);

  final double minimumContextMegaPixels;
  final bool focusedInpaintEnabled;
  final EditorCompressionPlan? compressionPlan;
  final EditorCompressionTarget? compressionTarget;
  final bool isInitialized;
  final bool didStartInitialization;
  final bool isOutpaintCommitPending;
  final String? sourceLayerId;
  final Uint8List? outpaintSourceImage;
  final int? outpaintSourceWidth;
  final int? outpaintSourceHeight;
  final Uint8List? inpaintWorkingSourceImage;
  final int? inpaintWorkingSourceWidth;
  final int? inpaintWorkingSourceHeight;
  final int? initialSourceWidth;
  final int? initialSourceHeight;
  final bool sourceWasNormalized;
  final OutpaintVirtualFrame? virtualOutpaintFrame;
  final bool hasOutpaintChanges;
  final bool isImportingDroppedImage;
  final bool hasTransparentCutout;
}

/// Owns exactly one editor session and rejects superseded asynchronous results.
class ImageEditorController extends ChangeNotifier {
  ImageEditorController({
    this.config = const ImageEditorSessionConfig.empty(),
    ImageEditorProcessingService? processingService,
  }) : processingService = processingService ?? ImageEditorProcessingService(),
       editorState = EditorState();

  final ImageEditorSessionConfig config;
  final EditorState editorState;
  final ImageEditorProcessingService processingService;

  late FocusedSelectionState focusedSelectionState;
  double minimumContextMegaPixels = 88;
  bool focusedInpaintEnabled = false;
  EditorCompressionPlan? compressionPlan;
  EditorCompressionTarget? compressionTarget;
  bool isInitialized = false;
  bool didStartInitialization = false;
  bool isOutpaintCommitPending = false;
  String? sourceLayerId;
  Uint8List? outpaintSourceImage;
  int? outpaintSourceWidth;
  int? outpaintSourceHeight;
  Uint8List? inpaintWorkingSourceImage;
  int? inpaintWorkingSourceWidth;
  int? inpaintWorkingSourceHeight;
  int? initialSourceWidth;
  int? initialSourceHeight;
  bool sourceWasNormalized = false;
  OutpaintVirtualFrame? virtualOutpaintFrame;
  bool hasOutpaintChanges = false;
  bool isImportingDroppedImage = false;
  bool hasTransparentCutout = false;

  ImageEditorSessionSnapshot get snapshot => ImageEditorSessionSnapshot(
    minimumContextMegaPixels: minimumContextMegaPixels,
    focusedInpaintEnabled: focusedInpaintEnabled,
    compressionPlan: compressionPlan,
    compressionTarget: compressionTarget,
    isInitialized: isInitialized,
    didStartInitialization: didStartInitialization,
    isOutpaintCommitPending: isOutpaintCommitPending,
    sourceLayerId: sourceLayerId,
    outpaintSourceImage: outpaintSourceImage,
    outpaintSourceWidth: outpaintSourceWidth,
    outpaintSourceHeight: outpaintSourceHeight,
    inpaintWorkingSourceImage: inpaintWorkingSourceImage,
    inpaintWorkingSourceWidth: inpaintWorkingSourceWidth,
    inpaintWorkingSourceHeight: inpaintWorkingSourceHeight,
    initialSourceWidth: initialSourceWidth,
    initialSourceHeight: initialSourceHeight,
    sourceWasNormalized: sourceWasNormalized,
    virtualOutpaintFrame: virtualOutpaintFrame,
    hasOutpaintChanges: hasOutpaintChanges,
    isImportingDroppedImage: isImportingDroppedImage,
    hasTransparentCutout: hasTransparentCutout,
  );

  int _operationEpoch = 0;
  bool _disposed = false;
  Object? _lastError;

  void initializeSession({
    required Size canvasSize,
    required Rect? initialFocusRect,
    required double minimumContextMegaPixels,
    required bool focusedInpaintEnabled,
    required bool outpaintCommitPending,
  }) {
    focusedSelectionState = FocusedSelectionState(
      canvasSize: canvasSize,
      initialRect: initialFocusRect,
    );
    this.minimumContextMegaPixels = minimumContextMegaPixels;
    this.focusedInpaintEnabled = focusedInpaintEnabled;
    isOutpaintCommitPending = outpaintCommitPending;
  }

  int beginOperation() => ++_operationEpoch;

  Future<T> runDocumentTransaction<T>({
    required DocumentSnapshot snapshot,
    required Future<void> Function(DocumentSnapshot snapshot) restore,
    required Future<T> Function() mutation,
  }) {
    return DocumentTransaction(
      snapshot: snapshot,
      restore: restore,
    ).run(mutation);
  }

  bool accepts(int epoch) => !_disposed && epoch == _operationEpoch;

  void cancelPendingOperations() {
    _operationEpoch++;
  }

  Object? get lastError => _lastError;

  void reportError(Object error) {
    if (_disposed) return;
    _lastError = error;
    notifyListeners();
  }

  void clearError() {
    if (_disposed || _lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operationEpoch++;
    editorState.dispose();
    processingService.dispose();
    super.dispose();
  }
}
