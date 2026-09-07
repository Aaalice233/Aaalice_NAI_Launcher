import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/keyboard_modifier_utils.dart';
import '../../../data/models/image/image_stream_chunk.dart';
import 'image_card_models.dart';

class ImageCardController extends ChangeNotifier {
  ImageCardController({
    required TickerProvider vsync,
    required ImageCardViewData data,
    required ImageCardCapabilities capabilities,
  }) : _data = data,
       _capabilities = capabilities,
       glossController = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: 800),
       ) {
    glossAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: glossController, curve: Curves.easeInOut),
    );
    _lastStreamPreview = _capturedStreamPreview(data);
    showPreparedIndexBadge = data.dragPreparationReady;
    _shareTransferCache = _createShareTransferCache();
  }

  static const dragPreparationProgressValue = 0.96;
  static const dragPreparationOverlayFadeDuration = Duration(milliseconds: 140);

  ImageCardViewData _data;
  ImageCardCapabilities _capabilities;
  bool isPointerInside = false;
  bool isHovering = false;
  bool showPreparedIndexBadge = false;
  bool hasPaintedCompletedImage = false;
  StreamPreviewFrame? _lastStreamPreview;
  bool _isTapping = false;
  bool _reducedMotion = false;
  bool _motionPreferenceInitialized = false;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  PointerDeviceKind? _lastTapKind;
  Timer? _legacyTapResetTimer;
  Timer? _doubleTapResetTimer;
  ShareImageTransferCache? _shareTransferCache;
  bool _disposed = false;

  final AnimationController glossController;
  late final Animation<double> glossAnimation;

  ImageCardViewData get data => _data;
  ImageCardCapabilities get capabilities => _capabilities;
  ShareImageTransferCache? get shareTransferCache => _shareTransferCache;

  /// 完成卡片在自己首帧到达前继续画的那一帧。
  StreamPreviewFrame? get effectiveCompletionPreview {
    if (_data.isGenerating || _data.imageBytes == null) return null;
    return _data.completionPreview ?? _lastStreamPreview;
  }

  void update({
    required TickerProvider vsync,
    required ImageCardViewData data,
    required ImageCardCapabilities capabilities,
  }) {
    final oldData = _data;
    final oldCapabilities = _capabilities;
    _data = data;
    _capabilities = capabilities;

    if (data.streamPreview?.isNotEmpty == true) {
      _lastStreamPreview = _capturedStreamPreview(data);
    } else if (oldData.imageBytes != null &&
        (oldData.imageIdentity != data.imageIdentity ||
            oldData.imageBytes != data.imageBytes)) {
      _lastStreamPreview = null;
    }

    if (oldData.imageBytes != data.imageBytes ||
        oldData.sourceFilePath != data.sourceFilePath) {
      final previousCache = _shareTransferCache;
      _shareTransferCache = _createShareTransferCache();
      if (previousCache != null) unawaited(previousCache.dispose());
    }

    // 只有这两种切换会重建表面层的 Image element；同一 element 换字节时旧帧仍在 gapless 画。
    if (oldData.isGenerating != data.isGenerating ||
        (oldData.imageBytes == null) != (data.imageBytes == null)) {
      hasPaintedCompletedImage = false;
    }

    final hoverEffectsBecameAvailable =
        capabilities.hoverEffectsEnabled &&
        data.dragPreparationReady &&
        (!oldCapabilities.hoverEffectsEnabled || !oldData.dragPreparationReady);
    if (!capabilities.hoverEffectsEnabled || !data.dragPreparationReady) {
      isHovering = false;
    } else if (isPointerInside && hoverEffectsBecameAvailable) {
      isHovering = true;
      if (capabilities.enableGlossEffect && !_reducedMotion) {
        glossController.forward(from: 0);
      }
    }
    if (!data.dragPreparationReady ||
        (!oldData.dragPreparationReady && data.dragPreparationReady)) {
      showPreparedIndexBadge = false;
    }
    if (oldData.imageIdentity != data.imageIdentity ||
        (oldCapabilities.onDoubleTap != null &&
            capabilities.onDoubleTap == null)) {
      clearPendingDoubleTap();
    }
  }

  void setReducedMotion(bool reducedMotion) {
    if (_motionPreferenceInitialized && _reducedMotion == reducedMotion) return;
    _motionPreferenceInitialized = true;
    _reducedMotion = reducedMotion;
    if (reducedMotion) {
      glossController.stop();
      glossController.value = 0;
    }
  }

  void hoverEnter({required VoidCallback warmShareCache}) {
    isPointerInside = true;
    if (_capabilities.shareWarmupEnabled) {
      warmShareCache();
    }
    if (!_capabilities.hoverEffectsEnabled || !_data.dragPreparationReady) {
      return;
    }
    if (!isHovering) {
      isHovering = true;
      notifyListeners();
    }
    if (_capabilities.enableGlossEffect && !_reducedMotion) {
      glossController.forward(from: 0);
    }
  }

  void hoverExit() {
    isPointerInside = false;
    if (!_capabilities.hoverEffectsEnabled && !isHovering) return;
    if (isHovering) {
      isHovering = false;
      notifyListeners();
    }
  }

  void markPreparedIndexBadgeVisible() {
    if (_disposed || !_data.dragPreparationReady || showPreparedIndexBadge) {
      return;
    }
    showPreparedIndexBadge = true;
    notifyListeners();
  }

  Widget completedImageFrameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (frame != null || wasSynchronouslyLoaded) {
      // 本帧自己已经算出 ready，标记只影响后续 build，通知反而多刷一帧。
      hasPaintedCompletedImage = true;
      _lastStreamPreview = null;
    }
    return child;
  }

  void handleLegacyTap() {
    final bypass =
        _capabilities.allowRepeatedModifierTaps &&
        isPrimarySelectionModifierPressed();
    if (_isTapping && !bypass) return;
    if (!bypass) _isTapping = true;
    (_capabilities.onTap ?? _capabilities.onFullscreen)?.call();
    if (!bypass) {
      _legacyTapResetTimer?.cancel();
      _legacyTapResetTimer = Timer(const Duration(milliseconds: 500), () {
        _isTapping = false;
      });
    }
  }

  void handleLinkedTapUp(TapUpDetails details) {
    if (isPrimarySelectionModifierPressed()) {
      clearPendingDoubleTap();
      _capabilities.onTap?.call();
      return;
    }
    final now = DateTime.now();
    final isDoubleTap =
        _lastTapTime != null &&
        now.difference(_lastTapTime!) <= kDoubleTapTimeout &&
        _lastTapPosition != null &&
        (details.globalPosition - _lastTapPosition!).distance <=
            kDoubleTapSlop &&
        _lastTapKind == details.kind;
    if (isDoubleTap) {
      clearPendingDoubleTap();
      _capabilities.onDoubleTap?.call();
      return;
    }
    _capabilities.onTap?.call();
    _lastTapTime = now;
    _lastTapPosition = details.globalPosition;
    _lastTapKind = details.kind;
    _doubleTapResetTimer?.cancel();
    _doubleTapResetTimer = Timer(kDoubleTapTimeout, clearPendingDoubleTap);
  }

  void clearPendingDoubleTap() {
    _doubleTapResetTimer?.cancel();
    _doubleTapResetTimer = null;
    _lastTapTime = null;
    _lastTapPosition = null;
    _lastTapKind = null;
  }

  static StreamPreviewFrame? _capturedStreamPreview(ImageCardViewData data) {
    final bytes = data.streamPreview;
    if (bytes == null || bytes.isEmpty) return null;
    return StreamPreviewFrame(
      bytes: bytes,
      placement: data.focusedPreviewPlacement,
    );
  }

  ShareImageTransferCache? _createShareTransferCache() {
    final bytes = _data.imageBytes;
    if (bytes == null) return null;
    return ShareImageTransferCache(
      imageBytes: bytes,
      fileName: 'generated.png',
      sourceFilePath: _data.sourceFilePath,
    );
  }

  void warmShareTransferCache({required bool stripMetadata}) {
    _shareTransferCache?.warmUp(stripMetadata: stripMetadata);
  }

  @override
  void dispose() {
    _disposed = true;
    glossController.dispose();
    _legacyTapResetTimer?.cancel();
    _doubleTapResetTimer?.cancel();
    final cache = _shareTransferCache;
    if (cache != null) unawaited(cache.dispose());
    super.dispose();
  }
}
