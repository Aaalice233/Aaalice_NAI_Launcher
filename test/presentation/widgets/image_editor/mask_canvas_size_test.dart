import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';

/// Tests for verifying mask loading functionality with various canvas sizes and orientations.
///
/// This test suite verifies that masks of different sizes and aspect ratios
/// can be loaded correctly as layers in the image editor, regardless of
/// whether they are larger, smaller, or different proportions than the canvas.
void main() {
  group('Mask Canvas Size and Orientation Tests', () {
    late LayerManager layerManager;

    setUp(() {
      layerManager = LayerManager();
    });

    tearDown(() {
      layerManager.dispose();
    });

    /// Helper: Creates a test PNG mask image with specified dimensions
    Uint8List createTestMask({
      required int width,
      required int height,
      int color = 0xFFFF0000,
    }) {
      final image = img.Image(width: width, height: height);
      image.clear(img.ColorRgb8(
        (color >> 16) & 0xFF,
        (color >> 8) & 0xFF,
        color & 0xFF,
      ));
      return Uint8List.fromList(img.encodePng(image));
    }

    group('Small Mask Loading', () {
      test('should load mask smaller than canvas (32x32)', () async {
        // Create a very small mask
        final maskBytes = createTestMask(width: 32, height: 32);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '小蒙版 32x32',
        );

        expect(layer, isNotNull);
        expect(layer?.name, '小蒙版 32x32');
        expect(layerManager.layerCount, 1);
        expect(layer?.baseImage, isNotNull);
      });

      test('should load very small mask (16x16)', () async {
        final maskBytes = createTestMask(width: 16, height: 16);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '极小蒙版 16x16',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load small wide mask (50x20)', () async {
        final maskBytes = createTestMask(width: 50, height: 20);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '小宽蒙版 50x20',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load small tall mask (20x50)', () async {
        final maskBytes = createTestMask(width: 20, height: 50);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '小高蒙版 20x50',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });
    });

    group('Large Mask Loading', () {
      test('should load mask larger than canvas (2048x2048)', () async {
        // Create a large HD mask
        final maskBytes = createTestMask(width: 2048, height: 2048);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '大蒙版 2048x2048',
        );

        expect(layer, isNotNull);
        expect(layer?.name, '大蒙版 2048x2048');
        expect(layerManager.layerCount, 1);
        expect(layer?.baseImage, isNotNull);
      });

      test('should load very large mask (4096x4096)', () async {
        // Create a 4K mask
        final maskBytes = createTestMask(width: 4096, height: 4096);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '超大蒙版 4096x4096',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load large wide mask (3840x2160 - Full HD)', () async {
        final maskBytes = createTestMask(width: 3840, height: 2160);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '全高清宽蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load large tall mask (2160x3840 - Portrait Full HD)', () async {
        final maskBytes = createTestMask(width: 2160, height: 3840);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '全高清高蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });
    });

    group('Different Aspect Ratios', () {
      test('should load square mask (1:1 ratio)', () async {
        final maskBytes = createTestMask(width: 512, height: 512);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '方形蒙版 1:1',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load landscape mask (16:9 ratio)', () async {
        final maskBytes = createTestMask(width: 1920, height: 1080);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '宽屏蒙版 16:9',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load portrait mask (9:16 ratio)', () async {
        final maskBytes = createTestMask(width: 1080, height: 1920);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '竖屏蒙版 9:16',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load ultra-wide mask (21:9 ratio)', () async {
        final maskBytes = createTestMask(width: 2560, height: 1080);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '超宽蒙版 21:9',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load panoramic mask (32:9 ratio)', () async {
        final maskBytes = createTestMask(width: 3840, height: 1080);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '全景蒙版 32:9',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load Instagram portrait (4:5 ratio)', () async {
        final maskBytes = createTestMask(width: 1080, height: 1350);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: 'Instagram竖屏蒙版 4:5',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load ultra-tall mask (9:21 ratio)', () async {
        final maskBytes = createTestMask(width: 1080, height: 2520);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '超高蒙版 9:21',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });
    });

    group('Mixed Size Loading', () {
      test('should load multiple masks of different sizes simultaneously', () async {
        // Small mask
        final smallMask = createTestMask(width: 64, height: 64);
        final smallLayer = await layerManager.addLayerFromImage(
          smallMask,
          name: '小蒙版',
        );
        expect(smallLayer, isNotNull);
        expect(layerManager.layerCount, 1);

        // Medium mask
        final mediumMask = createTestMask(width: 512, height: 512);
        final mediumLayer = await layerManager.addLayerFromImage(
          mediumMask,
          name: '中蒙版',
        );
        expect(mediumLayer, isNotNull);
        expect(layerManager.layerCount, 2);

        // Large mask
        final largeMask = createTestMask(width: 2048, height: 2048);
        final largeLayer = await layerManager.addLayerFromImage(
          largeMask,
          name: '大蒙版',
        );
        expect(largeLayer, isNotNull);
        expect(layerManager.layerCount, 3);

        // Verify all layers exist
        expect(layerManager.layers.length, 3);
        expect(layerManager.layers.any((l) => l.name == '小蒙版'), true);
        expect(layerManager.layers.any((l) => l.name == '中蒙版'), true);
        expect(layerManager.layers.any((l) => l.name == '大蒙版'), true);
      });

      test('should load masks with varying aspect ratios', () async {
        // Square
        final squareMask = createTestMask(width: 500, height: 500);
        await layerManager.addLayerFromImage(squareMask, name: '方形');
        expect(layerManager.layerCount, 1);

        // Wide
        final wideMask = createTestMask(width: 1000, height: 500);
        await layerManager.addLayerFromImage(wideMask, name: '宽屏');
        expect(layerManager.layerCount, 2);

        // Tall
        final tallMask = createTestMask(width: 500, height: 1000);
        await layerManager.addLayerFromImage(tallMask, name: '竖屏');
        expect(layerManager.layerCount, 3);

        // Verify all layers exist
        expect(layerManager.layers.length, 3);
        expect(layerManager.layers.every((l) => l.baseImage != null), true);
      });

      test('should handle masks smaller than canvas followed by larger masks', () async {
        // Start with small
        final smallMask = createTestMask(width: 32, height: 32);
        final smallLayer = await layerManager.addLayerFromImage(
          smallMask,
          name: '小蒙版',
        );
        expect(smallLayer, isNotNull);

        // Then add large
        final largeMask = createTestMask(width: 4096, height: 4096);
        final largeLayer = await layerManager.addLayerFromImage(
          largeMask,
          name: '大蒙版',
        );
        expect(largeLayer, isNotNull);

        // Verify both loaded successfully
        expect(layerManager.layerCount, 2);
        expect(layerManager.layers.firstWhere((l) => l.name == '小蒙版').baseImage, isNotNull);
        expect(layerManager.layers.firstWhere((l) => l.name == '大蒙版').baseImage, isNotNull);
      });
    });

    group('Extreme Sizes', () {
      test('should load very thin horizontal mask (1 pixel height)', () async {
        final maskBytes = createTestMask(width: 100, height: 1);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '细线横蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load very thin vertical mask (1 pixel width)', () async {
        final maskBytes = createTestMask(width: 1, height: 100);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '细线竖蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load tiny 1x1 pixel mask', () async {
        final maskBytes = createTestMask(width: 1, height: 1);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '单像素蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });

      test('should load asymmetric dimensions (137x249)', () async {
        // Use prime number dimensions for uniqueness
        final maskBytes = createTestMask(width: 137, height: 249);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '不规则蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
        expect(layerManager.layerCount, 1);
      });
    });

    group('Real-world Canvas Sizes', () {
      test('should load SD (Standard Definition) mask (640x480)', () async {
        final maskBytes = createTestMask(width: 640, height: 480);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: 'SD蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
      });

      test('should load HD (High Definition) mask (1920x1080)', () async {
        final maskBytes = createTestMask(width: 1920, height: 1080);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: 'HD蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
      });

      test('should load 2K mask (2560x1440)', () async {
        final maskBytes = createTestMask(width: 2560, height: 1440);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '2K蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
      });

      test('should load 4K mask (3840x2160)', () async {
        final maskBytes = createTestMask(width: 3840, height: 2160);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '4K蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
      });

      test('should load A4 paper ratio mask at 96 DPI (794x1123)', () async {
        // A4 at 96 DPI: 210mm x 297mm ≈ 794x1123 pixels
        final maskBytes = createTestMask(width: 794, height: 1123);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: 'A4蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
      });

      test('should load common mobile resolution (1080x2400)', () async {
        final maskBytes = createTestMask(width: 1080, height: 2400);

        final layer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '手机竖屏蒙版',
        );

        expect(layer, isNotNull);
        expect(layer?.baseImage, isNotNull);
      });
    });
  });
}
