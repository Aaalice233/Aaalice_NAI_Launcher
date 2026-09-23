import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/compact_control_metrics.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';

void main() {
  test('触屏入口保留 48 命中区与标准密度', () {
    final metrics = CompactControlMetrics.forPolicy(
      InteractionPolicy.touchFirst,
    );

    expect(metrics.extent, 48);
    expect(metrics.density, VisualDensity.standard);
    expect(
      metrics.constraints,
      const BoxConstraints.tightFor(width: 48, height: 48),
    );
  });

  test('仅精确指针时收紧为 32 与紧凑密度', () {
    final metrics = CompactControlMetrics.forPolicy(
      const InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: false,
        precisePointerAvailable: true,
      ),
    );

    expect(metrics.extent, 32);
    expect(metrics.density, VisualDensity.compact);
  });

  test('观察过触屏后切回鼠标仍保留触屏命中区', () {
    final metrics = CompactControlMetrics.forPolicy(
      const InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: true,
        precisePointerAvailable: true,
      ),
    );

    expect(metrics.extent, 48);
    expect(metrics.density, VisualDensity.standard);
  });

  test('调用方自行给出判定结果时结果一致', () {
    expect(
      const CompactControlMetrics.forTouchTargets(true),
      CompactControlMetrics.forPolicy(InteractionPolicy.touchFirst),
    );
    expect(
      const CompactControlMetrics.forTouchTargets(false),
      CompactControlMetrics.forPolicy(InteractionPolicy.neutral),
    );
  });
}
