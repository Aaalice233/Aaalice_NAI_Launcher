import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_selectors.dart';

void main() {
  group('generation_params_selectors', () {
    test('Img2ImgPanel 视图数据只在图生图字段变化时更新', () {
      final image = Uint8List.fromList([1, 2, 3]);
      final base = ImageParams(
        prompt: 'girl',
        sourceImage: image,
        strength: 0.55,
      );

      expect(
        selectImg2ImgPanelViewData(base.copyWith(prompt: 'girl, smile')),
        equals(selectImg2ImgPanelViewData(base)),
      );
      expect(
        selectImg2ImgPanelViewData(
          base.copyWith(sourceImage: Uint8List.fromList([1, 2, 3])),
        ),
        isNot(equals(selectImg2ImgPanelViewData(base))),
      );
    });

    test('VibePanel 视图数据忽略普通参数变化但响应引用变化', () {
      const vibe = VibeReference(
        displayName: 'style',
        vibeEncoding: 'encoded',
      );
      const base = ImageParams(vibeReferencesV4: [vibe]);

      expect(
        selectVibePanelViewData(base.copyWith(prompt: 'new prompt')),
        equals(selectVibePanelViewData(base)),
      );
      expect(
        selectVibePanelViewData(base.copyWith(normalizeVibeStrength: false)),
        isNot(equals(selectVibePanelViewData(base))),
      );
    });

    test('预览尺寸视图数据只关心宽高', () {
      const base = ImageParams(width: 832, height: 1216);
      final heavy = base.copyWith(
        sourceImage: Uint8List.fromList([1, 2, 3]),
        preciseReferences: [
          PreciseReference(
            image: Uint8List.fromList([7, 8, 9]),
            type: PreciseRefType.style,
          ),
        ],
      );

      expect(
        selectPreviewDimensionsViewData(heavy),
        equals(selectPreviewDimensionsViewData(base)),
      );
    });
  });
}
