import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/keyboard_modifier_utils.dart';
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
    _lastStreamPreviewBytes = data.streamPreview?.isNotEmpty == true
        ? data.streamPreview
        : null;
    showPreparedIndexBadge = data.dragPreparationReady;
    completedImageHasFrame = effectiveCompletionPlaceholderBytes == null;
    _scheduleCompletionPlaceholderFallback();
    if (data.isGenerating) _initGlowAnimation(vsync);
    _shareTransferCache = _createShareTransferCache();
  }

  static const dragPreparationProgressValue = 0.96;
  static const dragPreparationOverlayFadeDuration = Duration(milliseconds: 140);
  static const completionPlaceholderFallbackDuration = Duration(
    milliseconds: 900,
  );

  ImageCardViewData _data;
  ImageCardCapabilities _capabilities;
  bool isPointerInside = false;
  bool isHovering = false;
  bool showPreparedIndexBadge = false;
  bool completedImageHasFrame = false;
  bool _completionPlaceholderSettledNotified = false;
  int _completionImageEpoch = 0;
  Uint8List? _precachingCompletedImageBytes;
  Uint8List? _lastStreamPreviewBytes;
  Timer? _completionPlaceholderFallbackTimer;
  bool _isTapping = false;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  PointerDeviceKind? _lastTapKind;
  Timer? _legacyTapResetTimer;
  Timer? _doubleTapResetTimer;
  ShareImageTransferCache? _shareTransferCache;
  bool _disposed = false;

  final AnimationController glossController;
  late final Animation<double> glossAnimation;
  AnimationController? glowController;
  Animation<double>? glowAnimation;

  ImageCardViewData get data => _data;
  ImageCardCapabilities get capabilities => _capabilities;
  ShareImageTransferCache? get shareTransferCache => _shareTransferCache;

  Uint8List? get effectiveCompletionPlaceholderBytes {
    if (_data.isGenerating || _data.imageBytes == null) return null;
    return _data.completionPlaceholderBytes ?? _lastStreamPreviewBytes;
  }

  Uint8List? get displayedImageBytes {
    final placeholder = effectiveCompletionPlaceholderBytes;
    return placeholder != null && !completedImageHasFrame
        ? placeholder
        : _data.imageBytes;
  }

  bool get showCompletionPlaceholder =>
      effectiveCompletionPlaceholderBytes != null && !completedImageHasFrame;

  void update({
    required TickerProvider vsync,
    required ImageCardViewData data,
    required ImageCardCapabilities capabilities,
    required BuildContext context,
  }) {
    final oldData = _data;
    final oldCapabilities = _capabilities;
    _data = data;
    _capabilities = capabilities;

    if (data.isGenerating && !oldData.isGenerating) {
      _initGlowAnimation(vsync);
    } else if (!data.isGenerating && oldData.isGenerating) {
      glowController?.dispose();
      glowController = null;
      glowAnimation = null;
    }

    if (data.streamPreview?.isNotEmpty == true) {
      _lastStreamPreviewBytes = data.streamPreview;
    } else if (oldData.imageBytes != null &&
        (oldData.imageIdentity != data.imageIdentity ||
            oldData.imageBytes != data.imageBytes)) {
      _lastStreamPreviewBytes = null;
    }

    if (oldData.imageBytes != data.imageBytes ||
        oldData.sourceFilePath != data.sourceFilePath) {
      final previousCache = _shareTransferCache;
      _shareTransferCache = _createShareTransferCache();
      if (previousCache != null) unawaited(previousCache.dispose());
    }

    if (oldData.imageBytes != data.imageBytes ||
        oldData.imageIdentity != data.imageIdentity ||
        oldData.completionPlaceholderBytes != data.completionPlaceholderBytes ||
        (oldData.isGenerating && !data.isGenerating)) {
      _completionImageEpoch++;
      completedImageHasFrame = effectiveCompletionPlaceholderBytes == null;
      _completionPlaceholderSettledNotified = false;
      _precachingCompletedImageBytes = null;
      _scheduleCompletionPlaceholderFallback();
      scheduleCompletedImagePrecache(context);
    }

    final hoverEffectsBecameAvailable =
        capabilities.hoverEffectsEnabled &&
        data.dragPreparationReady &&
        (!oldCapabilities.hoverEffectsEnabled || !oldData.dragPreparationReady);
    if (!capabilities.hoverEffectsEnabled || !data.dragPreparationReady) {
      isHovering = false;
    } else if (isPointerInside && hoverEffectsBecameAvailable) {
      isHovering = true;
      if (capabilities.enableGlossEffect) {
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

  void _initGlowAnimation(TickerProvider vsync) {
    glowController?.dispose();
    glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: vsync,
    )..repeat(reverse: true);
    glowAnimation = Tween<double>(begin: 0.04, end: 0.1).animate(
      CurvedAnimation(parent: glowController!, curve: Curves.easeInOut),
    );
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
    if (_capabilities.enableGlossEffect) glossController.forward(from: 0);
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

  void scheduleCompletedImagePrecache(BuildContext context) {
    final imageBytes = _data.imageBytes;
    if (imageBytes == null ||
        effectiveCompletionPlaceholderBytes == null ||
        completedImageHasFrame ||
        identical(_precachingCompletedImageBytes, imageBytes)) {
      return;
    }
    final epoch = _completionImageEpoch;
    _precachingCompletedImageBytes = imageBytes;
    unawaited(
      precacheImage(MemoryImage(imageBytes), context).then((_) {
        if (_disposed ||
            epoch != _completionImageEpoch ||
            !identical(_precachingCompletedImageBytes, imageBytes)) {
          return;
        }
        markCompletedImageReady(epoch);
      }),
    );
  }

  void _scheduleCompletionPlaceholderFallback() {
    _completionPlaceholderFallbackTimer?.cancel();
    if (effectiveCompletionPlaceholderBytes == null || completedImageHasFrame) {
      return;
    }
    final epoch = _completionImageEpoch;
    _completionPlaceholderFallbackTimer = Timer(
      completionPlaceholderFallbackDuration,
      () {
        if (_disposed || epoch != _completionImageEpoch) return;
        markCompletedImageReady(epoch);
      },
    );
  }

  void markCompletedImageReady([int? expectedEpoch]) {
    if (_disposed ||
        (expectedEpoch != null && expectedEpoch != _completionImageEpoch) ||
        completedImageHasFrame) {
      return;
    }
    _completionPlaceholderFallbackTimer?.cancel();
    _completionPlaceholderFallbackTimer = null;
    completedImageHasFrame = true;
    _lastStreamPreviewBytes = null;
    notifyListeners();
    if (!_completionPlaceholderSettledNotified) {
      _completionPlaceholderSettledNotified = true;
      _capabilities.onCompletionPlaceholderSettled?.call();
    }
  }

  Widget completedImageFrameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if ((frame != null || wasSynchronouslyLoaded) && !completedImageHasFrame) {
      final epoch = _completionImageEpoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed ||
            epoch != _completionImageEpoch ||
            completedImageHasFrame) {
          return;
        }
        markCompletedImageReady(epoch);
      });
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
    glowController?.dispose();
    _completionPlaceholderFallbackTimer?.cancel();
    _legacyTapResetTimer?.cancel();
    _doubleTapResetTimer?.cancel();
    final cache = _shareTransferCache;
    if (cache != null) unawaited(cache.dispose());
    super.dispose();
  }
}
