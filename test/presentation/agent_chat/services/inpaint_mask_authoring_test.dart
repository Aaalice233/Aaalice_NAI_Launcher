import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/core/utils/inpaint_mask/inpaint_mask_geometry.dart';
import 'package:nai_launcher/presentation/agent_chat/services/inpaint_mask_authoring.dart';

Matcher _throwsCode(String code) => throwsA(
  isA<InpaintMaskAuthoringException>().having((e) => e.code, 'code', code),
);

void main() {
  group('InpaintMaskAuthoring.parse', () {
    test('accepts edge-form and extent-form rectangles', () {
      final edges = InpaintMaskAuthoring.parse(const {
        'regions': [
          {
            'shape': 'rect',
            'left': 0.1,
            'top': 0.2,
            'right': 0.4,
            'bottom': 0.6,
          },
        ],
      });
      final extents = InpaintMaskAuthoring.parse(const {
        'regions': [
          {'shape': 'rect', 'x': 0.1, 'y': 0.2, 'width': 0.3, 'height': 0.4},
        ],
      });

      // 0.2 + 0.4 != 0.6，两种写法只能逐边比较而不能整体相等。
      final a = edges.regions.single.bounds!;
      final b = extents.regions.single.bounds!;
      expect(a.left, closeTo(b.left, 1e-9));
      expect(a.top, closeTo(b.top, 1e-9));
      expect(a.right, closeTo(b.right, 1e-9));
      expect(a.bottom, closeTo(b.bottom, 1e-9));
      expect(edges.regions.single.shape, InpaintMaskShape.rect);
      expect(edges.expandRatio, equals(0));
      expect(edges.focus, InpaintFocusPreference.auto);
      expect(edges.contextPadding, isNull);
    });

    test('rejects mixing the two coordinate forms', () {
      expect(
        () => InpaintMaskAuthoring.parse(const {
          'regions': [
            {
              'shape': 'rect',
              'left': 0.1,
              'top': 0.2,
              'right': 0.4,
              'width': 0.3,
            },
          ],
        }),
        _throwsCode('invalid_region'),
      );
    });

    test('parses polygons, subtract mode and ellipses', () {
      final request = InpaintMaskAuthoring.parse(const {
        'regions': [
          {'shape': 'ellipse', 'x': 0.0, 'y': 0.0, 'width': 1.0, 'height': 1.0},
          {
            'shape': 'polygon',
            'mode': 'subtract',
            'points': [
              {'x': 0.1, 'y': 0.1},
              {'x': 0.5, 'y': 0.1},
              {'x': 0.3, 'y': 0.4},
            ],
          },
        ],
      });

      expect(request.regions, hasLength(2));
      expect(request.regions.first.shape, InpaintMaskShape.ellipse);
      expect(request.regions.last.shape, InpaintMaskShape.polygon);
      expect(request.regions.last.mode, InpaintMaskRegionMode.subtract);
      expect(request.regions.last.points, hasLength(3));
    });

    test('rejects malformed regions', () {
      expect(
        () => InpaintMaskAuthoring.parse(const {'regions': []}),
        _throwsCode('invalid_regions'),
      );
      expect(
        () => InpaintMaskAuthoring.parse(const {
          'regions': [
            {'shape': 'triangle', 'x': 0, 'y': 0, 'width': 1, 'height': 1},
          ],
        }),
        _throwsCode('invalid_region'),
      );
      expect(
        () => InpaintMaskAuthoring.parse(const {
          'regions': [
            {
              'shape': 'polygon',
              'points': [
                {'x': 0.1, 'y': 0.1},
                {'x': 0.5, 'y': 0.1},
              ],
            },
          ],
        }),
        _throwsCode('invalid_region'),
      );
      expect(
        () => InpaintMaskAuthoring.parse(const {
          'regions': [
            {'shape': 'rect', 'x': 'a', 'y': 0, 'width': 1, 'height': 1},
          ],
        }),
        _throwsCode('invalid_region'),
      );
    });

    test('bounds expand_ratio and context_padding', () {
      final request = InpaintMaskAuthoring.parse(const {
        'regions': [
          {'shape': 'rect', 'x': 0, 'y': 0, 'width': 1, 'height': 1},
        ],
        'expand_ratio': 0.05,
        'context_padding': 120,
      });
      expect(request.expandRatio, closeTo(0.05, 1e-9));
      expect(request.contextPadding, equals(120));

      const base = {
        'regions': [
          {'shape': 'rect', 'x': 0, 'y': 0, 'width': 1, 'height': 1},
        ],
      };
      expect(
        () => InpaintMaskAuthoring.parse({...base, 'expand_ratio': 0.5}),
        _throwsCode('invalid_expand_ratio'),
      );
      expect(
        () => InpaintMaskAuthoring.parse({...base, 'expand_ratio': -0.1}),
        _throwsCode('invalid_expand_ratio'),
      );
      expect(
        () => InpaintMaskAuthoring.parse({...base, 'context_padding': 8}),
        _throwsCode('invalid_context_padding'),
      );
      expect(
        () => InpaintMaskAuthoring.parse({...base, 'context_padding': 400}),
        _throwsCode('invalid_context_padding'),
      );
    });

    test('maps the focused argument onto a preference', () {
      const base = {
        'regions': [
          {'shape': 'rect', 'x': 0, 'y': 0, 'width': 1, 'height': 1},
        ],
      };
      expect(
        InpaintMaskAuthoring.parse({...base, 'focused': true}).focus,
        InpaintFocusPreference.enabled,
      );
      expect(
        InpaintMaskAuthoring.parse({...base, 'focused': false}).focus,
        InpaintFocusPreference.disabled,
      );
      expect(
        InpaintMaskAuthoring.parse({...base, 'focused': 'auto'}).focus,
        InpaintFocusPreference.auto,
      );
      expect(
        () => InpaintMaskAuthoring.parse({...base, 'focused': 'maybe'}),
        _throwsCode('invalid_focused'),
      );
    });
  });

  group('InpaintMaskAuthoring.resolveFocusedEnabled', () {
    test('honours an explicit preference without consulting coverage', () {
      expect(
        InpaintMaskAuthoring.resolveFocusedEnabled(
          preference: InpaintFocusPreference.enabled,
          maskedPixels: 0,
          imagePixels: 0,
        ),
        isTrue,
      );
      expect(
        InpaintMaskAuthoring.resolveFocusedEnabled(
          preference: InpaintFocusPreference.disabled,
          maskedPixels: 1,
          imagePixels: 1000,
        ),
        isFalse,
      );
    });

    test('auto follows the free-generation size line', () {
      bool auto(int imagePixels) => InpaintMaskAuthoring.resolveFocusedEnabled(
        preference: InpaintFocusPreference.auto,
        maskedPixels: 4096,
        imagePixels: imagePixels,
      );

      // 免费线内的整张请求本来就免费且原生分辨率，不值得多一轮裁剪放大。
      expect(auto(512 * 512), isFalse);
      expect(auto(832 * 1216), isFalse);
      expect(auto(AnlasCalculator.opusFreeMaxPixels), isFalse);
      // 越线之后不裁剪就要么收费、要么把蒙版区缩没。
      expect(auto(AnlasCalculator.opusFreeMaxPixels + 1), isTrue);
      expect(auto(2048 * 2048), isTrue);
    });

    test('treats a degenerate mask as not focusable', () {
      expect(
        InpaintMaskAuthoring.resolveFocusedEnabled(
          preference: InpaintFocusPreference.auto,
          maskedPixels: 0,
          imagePixels: 1000,
        ),
        isFalse,
      );
    });
  });
}
