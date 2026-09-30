import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('assets/model3d_editor/editor.js').readAsStringSync();
  });

  String topLevelBlock(String opening) {
    final start = source.indexOf(opening);
    expect(start, greaterThanOrEqualTo(0), reason: opening);
    final end = source.indexOf(RegExp(r'^\}', multiLine: true), start);
    expect(end, greaterThan(start), reason: opening);
    return source.substring(start, end);
  }

  test('disposing bone markers releases materials and the shared geometry', () {
    final body = topLevelBlock('function disposeBoneMarkers() {');

    expect(body, contains('marker.material.dispose();'));
    expect(body, contains('new Set()'));
    expect(body, contains('geometry.dispose();'));
    expect(body, contains('selectedMarker = null;'));
    expect(
      body.indexOf('boneMarkers.clear();'),
      greaterThan(body.indexOf('geometry.dispose();')),
      reason: 'children must be disposed before the group is emptied',
    );
  });

  test('rebuilding bone markers disposes the previous set first', () {
    final body = topLevelBlock('function rebuildBoneMarkers() {');

    expect(body, isNot(contains('boneMarkers.clear();')));
    expect(
      body.indexOf('disposeBoneMarkers();'),
      allOf(
        greaterThanOrEqualTo(0),
        lessThan(body.indexOf('new THREE.SphereGeometry')),
      ),
    );
  });

  test('clearing the model drops markers and the gizmo target with it', () {
    final body = topLevelBlock('function clearCurrentModel() {');

    expect(body, contains('disposeBoneMarkers();'));
    expect(body, contains('transformControls.detach();'));
  });

  test('a successful load re-applies the mode after rebuilding markers', () {
    final body = topLevelBlock("registerCommand('loadModel'");

    expect(body.indexOf('clearCurrentModel();'), greaterThanOrEqualTo(0));
    expect(
      body.indexOf('applyMode();'),
      greaterThan(body.indexOf('rebuildBoneMarkers();')),
    );
  });
}
