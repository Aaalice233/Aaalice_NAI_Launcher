import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/model3d_layer_data.dart';

void main() {
  test('round-trips through json', () {
    const data = Model3dLayerData(
      modelRef: 'lib:abc123',
      sceneState: {
        'version': 1,
        'bones': {
          'Head': {
            'quaternion': [0.0, 0.0, 0.0, 1.0],
          },
        },
      },
    );
    final restored = Model3dLayerData.fromJson(data.toJson());
    expect(restored.modelRef, 'lib:abc123');
    expect(restored.sceneState, data.sceneState);
  });
}
