import 'package:flutter/material.dart';

import 'interaction_policy.dart';

/// Geometry for dense tree rows: touch keeps a 48 hit area, a precise pointer
/// uses 32 so the rows stay scannable.
@immutable
class CompactControlMetrics {
  const CompactControlMetrics.forTouchTargets(bool touchTargets)
    : extent = touchTargets ? 48 : 32,
      density = touchTargets ? VisualDensity.standard : VisualDensity.compact;

  /// Touch-equivalent entry points stay mounted after touch is observed, so the
  /// geometry follows the same capability instead of the current modality.
  CompactControlMetrics.forPolicy(InteractionPolicy policy)
    : this.forTouchTargets(policy.shouldExposeTouchAlternatives);

  final double extent;
  final VisualDensity density;

  BoxConstraints get constraints =>
      BoxConstraints.tightFor(width: extent, height: extent);

  @override
  bool operator ==(Object other) =>
      other is CompactControlMetrics &&
      other.extent == extent &&
      other.density == density;

  @override
  int get hashCode => Object.hash(extent, density);
}
