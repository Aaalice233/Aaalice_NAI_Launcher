import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../../core/utils/image_share_sanitizer.dart';
import '../../../../providers/image_generation_provider.dart';

class HistorySharePreheatController {
  HistorySharePreheatController({
    required this.sharePreparationService,
    required this.isMounted,
    required this.onScrollingChanged,
    required this.readTransform,
    required this.readCurrentMaintenanceState,
    required this.isImageVisible,
  });

  final ShareImagePreparationService sharePreparationService;
  final bool Function() isMounted;
  final VoidCallback onScrollingChanged;
  final ShareImageTransform? Function() readTransform;
  final ({List<GeneratedImage> images, bool stripMetadata}) Function()
  readCurrentMaintenanceState;
  final bool Function(String imageId) isImageVisible;

  Timer? _historyScrollIdleTimer;
  Timer? _historyPreheatTimer;
  Timer? _hoverPreheatTimer;
  bool isHistoryScrolling = false;
  String? _lastSharePreparationMaintenanceKey;

  void dispose() {
    _historyScrollIdleTimer?.cancel();
    _historyPreheatTimer?.cancel();
    _hoverPreheatTimer?.cancel();
  }

  void scheduleMaintenance(List<GeneratedImage> images, bool stripMetadata) {
    final imageIds = images.map((image) => image.id).toSet();
    final maintenanceKey =
        '${stripMetadata ? 'strip' : 'raw'}:'
        '${readTransform()?.cacheKey ?? 'original'}:'
        '${imageIds.join('|')}';

    if (_lastSharePreparationMaintenanceKey == maintenanceKey) {
      return;
    }
    _lastSharePreparationMaintenanceKey = maintenanceKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      unawaited(sharePreparationService.retainHistoryImageIds(imageIds));
      if (!isHistoryScrolling) {
        _scheduleHistoryPreheat(images, stripMetadata);
      }
    });
  }

  void _setHistoryScrolling(bool value) {
    if (isHistoryScrolling == value) {
      return;
    }
    isHistoryScrolling = value;
    onScrollingChanged();
  }

  bool handleScrollNotification(
    ScrollNotification notification,
    bool stripMetadata,
  ) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _historyScrollIdleTimer?.cancel();
      _historyPreheatTimer?.cancel();
      _hoverPreheatTimer?.cancel();
      _setHistoryScrolling(true);
      return false;
    }

    if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      _historyScrollIdleTimer?.cancel();
      _historyScrollIdleTimer = Timer(const Duration(milliseconds: 250), () {
        if (!isMounted()) return;
        _setHistoryScrolling(false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isMounted() || isHistoryScrolling) return;
          RendererBinding.instance.mouseTracker.updateAllDevices();
        });
        final current = readCurrentMaintenanceState();
        _scheduleHistoryPreheat(
          current.images,
          current.stripMetadata,
          delay: const Duration(milliseconds: 150),
        );
      });
    }

    return false;
  }

  void _scheduleHistoryPreheat(
    List<GeneratedImage> images,
    bool stripMetadata, {
    Duration delay = const Duration(milliseconds: 600),
  }) {
    _historyPreheatTimer?.cancel();
    final draggableImages = images.where((image) => image.canDrag).toList();
    if (draggableImages.isEmpty) {
      return;
    }

    _historyPreheatTimer = Timer(delay, () {
      if (!isMounted() || isHistoryScrolling) {
        return;
      }

      final transform = readTransform();
      for (final image in draggableImages) {
        if (transform != null && !isImageVisible(image.id)) continue;
        sharePreparationService.enqueue(
          imageId: image.id,
          imageBytes: image.bytes,
          fileName: 'history_${image.id}.png',
          sourceFilePath: image.filePath,
          stripMetadata: stripMetadata,
          transform: readTransform(),
        );
      }
    });
  }

  void scheduleHoverPreheat(GeneratedImage image, bool stripMetadata) {
    if (!image.canDrag || isHistoryScrolling) {
      return;
    }

    _hoverPreheatTimer?.cancel();
    _hoverPreheatTimer = Timer(const Duration(milliseconds: 350), () {
      if (!isMounted() || isHistoryScrolling) {
        return;
      }
      sharePreparationService.enqueue(
        imageId: image.id,
        imageBytes: image.bytes,
        fileName: 'history_${image.id}.png',
        sourceFilePath: image.filePath,
        stripMetadata: stripMetadata,
        transform: readTransform(),
      );
    });
  }

  void cancelHoverPreheat() {
    _hoverPreheatTimer?.cancel();
  }
}
