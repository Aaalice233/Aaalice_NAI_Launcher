import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/cache/online_gallery_preload_policy.dart';

/// Converts viewport movement into one coalesced pagination demand.
///
/// It owns no gallery data and never advances a cursor. The provider remains
/// responsible for pagination truth; this class only decides how much runway
/// the current viewport needs and serializes UI demand around that provider.
class OnlineGalleryPaginationDemand {
  OnlineGalleryPaginationDemand({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const double _minimumRunwayViewports = 4;
  static const double _maximumRunwayViewports = 12;
  static const double _latencySafetyFactor = 1.5;
  static const Duration _initialLatency = Duration(milliseconds: 1200);

  final DateTime Function() _now;
  DateTime? _lastScrollAt;
  DateTime? _requestStartedAt;
  double? _lastScrollOffset;
  double _pixelsPerSecond = 0;
  double _estimatedLatencyMs = _initialLatency.inMilliseconds.toDouble();
  bool _requestInFlight = false;
  bool _queuedDemand = false;
  String? _scopeKey;
  String? _requestCursor;
  double _requestRunwayPixels = 0;
  int _generation = 0;
  int? _activeRequestToken;

  bool get requestInFlight => _requestInFlight;
  String? get requestCursor => _requestCursor;

  void recordScroll(double offset) {
    final now = _now();
    final previousAt = _lastScrollAt;
    final previousOffset = _lastScrollOffset;
    _lastScrollAt = now;
    _lastScrollOffset = offset;
    if (previousAt == null || previousOffset == null) return;
    final elapsedMs = now.difference(previousAt).inMicroseconds / 1000;
    if (elapsedMs <= 0 || elapsedMs > 500) {
      _pixelsPerSecond = 0;
      return;
    }
    final instantaneous = (offset - previousOffset).abs() * 1000 / elapsedMs;
    _pixelsPerSecond = _pixelsPerSecond == 0
        ? instantaneous
        : _pixelsPerSecond * 0.7 + instantaneous * 0.3;
  }

  double loadAheadDistance(double viewportDimension) {
    final staticDistance = OnlineGalleryPreloadPolicy.loadAheadDistance(
      viewportDimension,
    );
    final minimumDistance = viewportDimension * _minimumRunwayViewports;
    final velocityDistance =
        _pixelsPerSecond * (_estimatedLatencyMs / 1000) * _latencySafetyFactor;
    return math
        .max(staticDistance, math.max(minimumDistance, velocityDistance))
        .clamp(minimumDistance, viewportDimension * _maximumRunwayViewports);
  }

  bool isWithinDemandWindow(
    ScrollMetrics metrics, {
    double reservedPlaceholderExtent = 0,
  }) {
    final loadedExtentAfter = math.max(
      0.0,
      metrics.extentAfter - reservedPlaceholderExtent,
    );
    return loadedExtentAfter <= loadAheadDistance(metrics.viewportDimension);
  }

  void settleScroll() => _pixelsPerSecond = 0;

  int? beginRequest({
    required String scopeKey,
    required String? cursor,
    required double viewportDimension,
  }) {
    if (_scopeKey != scopeKey) resetScope(scopeKey);
    if (_requestInFlight) {
      _queuedDemand = true;
      return null;
    }
    _requestInFlight = true;
    _queuedDemand = false;
    _requestCursor = cursor;
    _requestStartedAt = _now();
    _requestRunwayPixels = loadAheadDistance(viewportDimension);
    _activeRequestToken = ++_generation;
    return _activeRequestToken;
  }

  ({bool accepted, bool hadQueuedDemand}) completeRequest(int token) {
    if (_activeRequestToken != token) {
      return (accepted: false, hadQueuedDemand: false);
    }
    final startedAt = _requestStartedAt;
    if (startedAt != null) {
      final elapsedMs = _now().difference(startedAt).inMicroseconds / 1000;
      if (elapsedMs > 0) {
        _estimatedLatencyMs = _estimatedLatencyMs * 0.7 + elapsedMs * 0.3;
      }
    }
    _requestInFlight = false;
    _requestStartedAt = null;
    _requestCursor = null;
    _activeRequestToken = null;
    final hadQueuedDemand = _queuedDemand;
    _queuedDemand = false;
    return (accepted: true, hadQueuedDemand: hadQueuedDemand);
  }

  void queueDemand() => _queuedDemand = true;

  double placeholderExtent({
    required double viewportDimension,
    required double itemWidth,
    required int columnCount,
    required double spacing,
    required int pageSize,
  }) {
    final count = placeholderCount(
      viewportDimension: viewportDimension,
      itemWidth: itemWidth,
      columnCount: columnCount,
      spacing: spacing,
      pageSize: pageSize,
    );
    final rows = (count / columnCount).ceil();
    return rows * itemWidth + math.max(0, rows - 1) * spacing;
  }

  int placeholderCount({
    required double viewportDimension,
    required double itemWidth,
    required int columnCount,
    required double spacing,
    required int pageSize,
  }) {
    final minimum = viewportDimension * _minimumRunwayViewports;
    final maximum = viewportDimension * _maximumRunwayViewports;
    final runway = (_requestRunwayPixels > 0 ? _requestRunwayPixels : minimum)
        .clamp(minimum, maximum);
    final rowExtent = math.max(1.0, itemWidth + spacing);
    final rows = math.max(1, (runway / rowExtent).ceil());
    final maximumSlots =
        math.max(1, (maximum / rowExtent).ceil()) * columnCount;
    return math.min(maximumSlots, math.max(pageSize, rows * columnCount));
  }

  void resetScope(String scopeKey) {
    _scopeKey = scopeKey;
    _generation++;
    _activeRequestToken = null;
    _requestInFlight = false;
    _queuedDemand = false;
    _requestStartedAt = null;
    _requestCursor = null;
    _requestRunwayPixels = 0;
    _lastScrollAt = null;
    _lastScrollOffset = null;
    _pixelsPerSecond = 0;
  }
}
