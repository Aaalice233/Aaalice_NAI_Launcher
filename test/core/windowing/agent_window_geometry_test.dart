import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_window_geometry.dart';
import 'package:nai_launcher/core/windowing/agent_window_protocol.dart';

void main() {
  const display = AgentWindowVisibleArea(x: 0, y: 0, width: 1920, height: 1040);

  test('keeps a visible saved window in place', () {
    const bounds = AgentWindowBounds(x: 100, y: 80, width: 560, height: 760);

    final corrected = ensureAgentWindowIsVisible(
      bounds: bounds,
      visibleAreas: const [display],
    );

    expect(corrected.toJson(), bounds.toJson());
  });

  test('recenters an off-screen window and clamps it to the work area', () {
    final corrected = ensureAgentWindowIsVisible(
      bounds: const AgentWindowBounds(
        x: 6000,
        y: -4000,
        width: 3000,
        height: 2000,
      ),
      visibleAreas: const [display],
    );

    expect(corrected.width, 1920);
    expect(corrected.height, 1040);
    expect(corrected.x, 0);
    expect(corrected.y, 0);
  });

  test('supports negative-coordinate displays', () {
    final corrected = ensureAgentWindowIsVisible(
      bounds: const AgentWindowBounds(
        x: -1200,
        y: 100,
        width: 560,
        height: 760,
      ),
      visibleAreas: const [
        AgentWindowVisibleArea(x: -1600, y: 0, width: 1600, height: 900),
        display,
      ],
    );

    expect(corrected.x, -1200);
    expect(corrected.y, 100);
  });

  test('fits inside a work area smaller than the preferred minimum', () {
    final corrected = ensureAgentWindowIsVisible(
      bounds: const AgentWindowBounds(
        x: 5000,
        y: 5000,
        width: 560,
        height: 760,
      ),
      visibleAreas: const [
        AgentWindowVisibleArea(x: 0, y: 0, width: 360, height: 480),
      ],
    );

    expect(corrected.width, 360);
    expect(corrected.height, 480);
    expect(corrected.x, 0);
    expect(corrected.y, 0);
  });
}
