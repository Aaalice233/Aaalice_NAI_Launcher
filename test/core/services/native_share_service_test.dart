import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/native_share_service.dart';

void main() {
  group('NativeShareService.resolveSharePositionOriginFor', () {
    const viewSize = Size(1024, 768);

    test('iOS falls back to a screen-centered anchor when none is given', () {
      // iPad 上分享面板是 popover，没有非空锚点会呈现失败；
      // mosaic / watermark 两个调用点都没有传 sharePositionOrigin。
      final resolved = NativeShareService.resolveSharePositionOriginFor(
        origin: null,
        isIOS: true,
        viewSize: viewSize,
      );

      expect(resolved, isNotNull);
      expect(resolved!.center, const Offset(512, 384));
      expect(resolved.width, greaterThan(0));
      expect(resolved.height, greaterThan(0));
    });

    test('iOS keeps a caller-provided anchor and rejects an empty one', () {
      const anchor = Rect.fromLTWH(10, 20, 30, 40);

      expect(
        NativeShareService.resolveSharePositionOriginFor(
          origin: anchor,
          isIOS: true,
          viewSize: viewSize,
        ),
        anchor,
      );
      expect(
        NativeShareService.resolveSharePositionOriginFor(
          origin: Rect.zero,
          isIOS: true,
          viewSize: viewSize,
        ),
        isNot(Rect.zero),
      );
    });

    test('non-iOS platforms keep the upstream pass-through behaviour', () {
      expect(
        NativeShareService.resolveSharePositionOriginFor(
          origin: null,
          isIOS: false,
          viewSize: viewSize,
        ),
        isNull,
      );
    });
  });
}
