import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';

/// 必保 #2 的高风险面：v4.2.1 新增的「复制/拖拽时加水印」
/// （`copyDragWatermarkProvider`）与「去除元数据」是两个正交开关。
/// 上游 `_copyImageToClipboard` 无条件把水印 transform 交给 sanitizer；
/// 我们的「复制（去除元数据）」只承诺产出没有元数据的副本，绝不能顺带烙水印。
void main() {
  final watermark = ShareImageTransform(
    cacheKey: 'test-watermark',
    apply: (image, {required stripMetadata}) async => image,
  );

  test('the clean copy path never carries the watermark transform', () {
    expect(
      ImageDetailViewer.copyTransformFor(
        stripMetadataOverride: true,
        watermark: watermark,
      ),
      isNull,
    );
  });

  test('the upstream copy path keeps following the watermark setting', () {
    expect(
      ImageDetailViewer.copyTransformFor(
        stripMetadataOverride: null,
        watermark: watermark,
      ),
      same(watermark),
    );
    expect(
      ImageDetailViewer.copyTransformFor(
        stripMetadataOverride: false,
        watermark: watermark,
      ),
      same(watermark),
    );
  });
}
