import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/project/project_data.dart';

void main() {
  test('projectVersion is 2', () {
    expect(projectVersion, 2);
  });

  test('layer with model3d round-trips', () {
    final layer = LayerProjectData(
      id: 'l1',
      name: '3D Layer',
      imageData: 'aGVsbG8=',
      model3d: const {
        'modelRef': 'builtin:mannequin',
        'sceneState': {'version': 1},
      },
    );
    final restored = LayerProjectData.fromJson(layer.toJson());
    expect(restored.model3d?['modelRef'], 'builtin:mannequin');
    expect(restored.imageData, 'aGVsbG8=');
  });

  test('v1 project json (no model3d) loads with null', () {
    final restored = LayerProjectData.fromJson({
      'id': 'l1',
      'name': 'Layer',
      'visible': true,
      'locked': false,
      'opacity': 1.0,
      'blendMode': 'normal',
      'strokes': <dynamic>[],
    });
    expect(restored.model3d, isNull);
  });

  test('v1 ProjectData json still parses', () {
    final project = ProjectData.fromJson({
      'version': 1,
      'width': 64,
      'height': 64,
      'layers': <dynamic>[],
      'foregroundColor': 0xFF000000,
      'backgroundColor': 0xFFFFFFFF,
      'createdAt': DateTime(2026).toIso8601String(),
      'modifiedAt': DateTime(2026).toIso8601String(),
    });
    expect(project.version, 1);
    expect(project.layers, isEmpty);
  });
}
