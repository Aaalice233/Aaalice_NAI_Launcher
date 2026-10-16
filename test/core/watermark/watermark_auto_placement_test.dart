import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/watermark/watermark_auto_placement.dart';
import 'package:nai_launcher/core/watermark/watermark_render_service.dart';
import 'package:nai_launcher/core/watermark/watermark_scene.dart';
import 'package:nai_launcher/core/watermark/watermark_tone.dart';
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';

import '../../helpers/watermark_analysis_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mirror', () {
    test('moves corners and edges but keeps centers', () {
      expect(
        WatermarkMirror.horizontal.anchor(WatermarkAnchor.bottomRight),
        WatermarkAnchor.bottomLeft,
      );
      expect(
        WatermarkMirror.vertical.anchor(WatermarkAnchor.bottomRight),
        WatermarkAnchor.topRight,
      );
      expect(
        WatermarkMirror.both.anchor(WatermarkAnchor.bottomRight),
        WatermarkAnchor.topLeft,
      );
      expect(
        WatermarkMirror.horizontal.anchor(WatermarkAnchor.topCenter),
        WatermarkAnchor.topCenter,
      );
      expect(
        WatermarkMirror.vertical.anchor(WatermarkAnchor.centerLeft),
        WatermarkAnchor.centerLeft,
      );
      for (final anchor in WatermarkAnchor.values) {
        expect(WatermarkMirror.none.anchor(anchor), anchor);
        for (final mirror in WatermarkMirror.values) {
          expect(mirror.anchor(mirror.anchor(anchor)), anchor);
        }
      }
    });

    test('mirrors offsets, alignment and drag deltas on flipped axes', () {
      const placement = WatermarkPlacement(
        anchor: WatermarkAnchor.bottomRight,
        sizeRatio: 0.1,
        marginRatio: 0.03,
        offsetXRatio: 0.04,
        offsetYRatio: -0.02,
        zIndex: 3,
      );

      final mirrored = WatermarkMirror.both.placement(placement);

      expect(mirrored.anchor, WatermarkAnchor.topLeft);
      expect(mirrored.offsetXRatio, -0.04);
      expect(mirrored.offsetYRatio, 0.02);
      expect(mirrored.sizeRatio, placement.sizeRatio);
      expect(mirrored.zIndex, placement.zIndex);
      expect(
        WatermarkMirror.horizontal.alignment(WatermarkTextAlignment.right),
        WatermarkTextAlignment.left,
      );
      expect(
        WatermarkMirror.vertical.alignment(WatermarkTextAlignment.right),
        WatermarkTextAlignment.right,
      );
      expect(
        WatermarkMirror.horizontal.delta(const Offset(0.01, 0.02)),
        const Offset(-0.01, 0.02),
      );
    });
  });

  group('choose', () {
    test('keeps the preferred position unless another is clearly cleaner', () {
      expect(
        WatermarkAutoPlacement.choose({
          WatermarkMirror.none: 10,
          WatermarkMirror.horizontal: 9,
          WatermarkMirror.vertical: 8.6,
          WatermarkMirror.both: 9.5,
        }),
        WatermarkMirror.none,
      );
      expect(
        WatermarkAutoPlacement.choose({
          WatermarkMirror.none: 10,
          WatermarkMirror.horizontal: 9,
          WatermarkMirror.vertical: 4,
          WatermarkMirror.both: 2,
        }),
        WatermarkMirror.both,
      );
    });

    test('never leaves a perfectly clean preferred position', () {
      expect(
        WatermarkAutoPlacement.choose({
          WatermarkMirror.none: 0,
          WatermarkMirror.horizontal: 0,
          WatermarkMirror.vertical: 0,
          WatermarkMirror.both: 0,
        }),
        WatermarkMirror.none,
      );
    });
  });

  group('placement cost', () {
    test('a flat region costs less than a detailed one', () {
      final analysis = watermarkAnalysisOf(
        80,
        40,
        (x, y) => x < 40
            ? (128, 128, 128, 255)
            : ((x ~/ 2 + y ~/ 2).isEven
                  ? (0, 0, 0, 255)
                  : (255, 255, 255, 255)),
      );

      final flat = WatermarkAutoPlacement.placementCost(
        analysis.regionStats(const Rect.fromLTRB(0.05, 0.1, 0.4, 0.9)),
      );
      final busy = WatermarkAutoPlacement.placementCost(
        analysis.regionStats(const Rect.fromLTRB(0.6, 0.1, 0.95, 0.9)),
      );

      expect(flat, greaterThanOrEqualTo(0));
      expect(busy, greaterThan(flat));
    });

    test('stronger detail never costs less', () {
      final soft = watermarkAnalysisOf(
        40,
        40,
        (x, y) => (x ~/ 2).isEven ? (110, 110, 110, 255) : (140, 140, 140, 255),
      );
      final hard = watermarkAnalysisOf(
        40,
        40,
        (x, y) => (x ~/ 2).isEven ? (0, 0, 0, 255) : (255, 255, 255, 255),
      );
      const region = Rect.fromLTRB(0.1, 0.1, 0.9, 0.9);

      expect(
        WatermarkAutoPlacement.placementCost(hard.regionStats(region)),
        greaterThanOrEqualTo(
          WatermarkAutoPlacement.placementCost(soft.regionStats(region)),
        ),
      );
    });
  });

  group('scene decision', () {
    const canvasSize = Size(400, 300);
    final busyBottom = watermarkAnalysisOf(
      200,
      150,
      (x, y) => y < 75
          ? (40, 40, 40, 255)
          : ((x ~/ 2 + y ~/ 2).isEven ? (0, 0, 0, 255) : (255, 255, 255, 255)),
    );

    test('moves the watermark away from detailed content', () {
      final decision = WatermarkScene.decide(
        canvasSize: canvasSize,
        settings: const WatermarkSettings(autoPlacement: true),
        analysis: busyBottom,
      );

      expect(decision.mirror, WatermarkMirror.vertical);
      final result = _paint(canvasSize, decision: decision);
      final bounds = result.boundsFor(WatermarkLayerKind.text)!;
      expect(bounds.bottom, lessThanOrEqualTo(canvasSize.height / 2));
      expect(bounds.center.dx, greaterThan(canvasSize.width / 2));
    });

    test('does nothing when auto placement is off', () {
      final decision = WatermarkScene.decide(
        canvasSize: canvasSize,
        settings: const WatermarkSettings(),
        analysis: busyBottom,
      );

      expect(decision, WatermarkAutoDecision.none);
    });

    test('grouped layers keep the same layer next to the edge', () async {
      final logo = await _logoImage();
      addTearDown(logo.dispose);
      const settings = WatermarkSettings(
        logoStyle: WatermarkLogoStyle(enabled: true),
        composition: WatermarkComposition(
          arrangement: WatermarkLayerArrangement.horizontal,
        ),
      );

      final original = _paint(canvasSize, settings: settings, logo: logo);
      final mirrored = _paint(
        canvasSize,
        settings: settings,
        logo: logo,
        decision: const WatermarkAutoDecision(
          mirror: WatermarkMirror.horizontal,
        ),
      );

      final text = original.boundsFor(WatermarkLayerKind.text)!;
      final logoBounds = original.boundsFor(WatermarkLayerKind.logo)!;
      final mirroredText = mirrored.boundsFor(WatermarkLayerKind.text)!;
      final mirroredLogo = mirrored.boundsFor(WatermarkLayerKind.logo)!;
      expect(logoBounds.left, greaterThan(text.left));
      expect(mirroredLogo.left, lessThan(mirroredText.left));
      expect(
        mirroredLogo.left,
        closeTo(canvasSize.width - logoBounds.right, 1),
      );
    });

    test('oversized groups draw the text inside its shrunk bounds', () async {
      final logo = await _logoImage();
      addTearDown(logo.dispose);
      const settings = WatermarkSettings(
        textStyle: WatermarkTextStyle(
          text: 'AaaliceWatermarkSignature',
          strokeWidthRatio: 0,
          shadowBlurRatio: 0,
          shadowOffsetXRatio: 0,
          shadowOffsetYRatio: 0,
        ),
        logoStyle: WatermarkLogoStyle(enabled: true, opacity: 0),
        composition: WatermarkComposition(
          arrangement: WatermarkLayerArrangement.horizontal,
        ),
      );

      for (final mirror in [WatermarkMirror.none, WatermarkMirror.horizontal]) {
        final recorder = ui.PictureRecorder();
        final result = WatermarkScene.paint(
          canvas: Canvas(recorder),
          canvasSize: canvasSize,
          settings: settings,
          logo: logo,
          decision: WatermarkAutoDecision(mirror: mirror),
        );
        final picture = recorder.endRecording();
        // 光栅比画布宽，伸出画布的笔画才看得见
        final image = await picture.toImage(
          canvasSize.width.toInt() * 2,
          canvasSize.height.toInt(),
        );
        picture.dispose();
        final (left, right) = await _paintedColumns(image);
        image.dispose();

        final text = result.boundsFor(WatermarkLayerKind.text)!;
        expect(left, greaterThanOrEqualTo(text.left - 1), reason: '$mirror');
        expect(right, lessThanOrEqualTo(text.right + 1), reason: '$mirror');
        expect(right, lessThanOrEqualTo(canvasSize.width), reason: '$mirror');
      }
    });

    test('text tone follows the background under the text', () {
      final dark = watermarkAnalysisOf(20, 15, (x, y) => (20, 24, 30, 255));
      final light = watermarkAnalysisOf(20, 15, (x, y) => (235, 232, 228, 255));
      const settings = WatermarkSettings(
        textStyle: WatermarkTextStyle(autoTone: true),
      );

      final onDark = WatermarkScene.decide(
        canvasSize: canvasSize,
        settings: settings,
        analysis: dark,
      ).textTone!;
      final onLight = WatermarkScene.decide(
        canvasSize: canvasSize,
        settings: settings,
        analysis: light,
      ).textTone!;

      expect(onDark.fillRgb & 0xFF, greaterThan(onDark.haloRgb & 0xFF));
      expect(onLight.fillRgb & 0xFF, lessThan(onLight.haloRgb & 0xFF));
    });

    test('transparent backgrounds keep the configured colors', () {
      final transparent = watermarkAnalysisOf(20, 15, (x, y) => (0, 0, 0, 0));

      final decision = WatermarkScene.decide(
        canvasSize: canvasSize,
        settings: const WatermarkSettings(
          textStyle: WatermarkTextStyle(autoTone: true),
        ),
        analysis: transparent,
      );

      expect(decision.textTone, isNull);
    });

    test('logo tone needs its own switch and measured shading', () async {
      final logo = await _logoImage();
      addTearDown(logo.dispose);
      final background = watermarkAnalysisOf(
        20,
        15,
        (x, y) => (30, 30, 30, 255),
      );
      const luminance = WatermarkLogoLuminance(
        mean: 0.6,
        darkest: 0.3,
        brightest: 0.9,
      );

      WatermarkAutoDecision decide(
        WatermarkLogoStyle style, {
        WatermarkLogoLuminance? measured = luminance,
      }) => WatermarkScene.decide(
        canvasSize: canvasSize,
        settings: WatermarkSettings(
          textStyle: const WatermarkTextStyle(autoTone: true),
          logoStyle: style,
        ),
        analysis: background,
        logo: logo,
        logoLuminance: measured,
      );

      const toned = WatermarkLogoStyle(enabled: true, autoTone: true);
      expect(
        decide(const WatermarkLogoStyle(enabled: true)).logoFilter,
        isNull,
      );
      expect(decide(toned, measured: null).logoFilter, isNull);
      expect(decide(toned).logoFilter, isNotNull);
      expect(
        decide(toned.copyWith(toneContrast: 0.2)).logoFilter,
        isNot(decide(toned.copyWith(toneContrast: 0.9)).logoFilter),
      );
    });
  });

  test('saved copies apply auto placement at full resolution', () async {
    final source = img.Image(width: 320, height: 240);
    for (final pixel in source) {
      if (pixel.y < 120) {
        pixel.setRgb(40, 40, 40);
      } else {
        final on = (pixel.x ~/ 2 + pixel.y ~/ 2).isEven;
        pixel.setRgb(on ? 0 : 255, on ? 0 : 255, on ? 0 : 255);
      }
    }
    final sourceBytes = Uint8List.fromList(img.encodePng(source));

    final result = await WatermarkRenderService.render(
      WatermarkRenderRequest(
        sourceBytes: sourceBytes,
        settings: const WatermarkSettings(
          autoPlacement: true,
          textStyle: WatermarkTextStyle(text: 'Aaalice', autoTone: true),
        ),
        preserveMetadata: false,
      ),
    );

    final output = img.decodePng(result.bytes)!;
    int changedIn(int left, int top, int right, int bottom) {
      var changed = 0;
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          final before = source.getPixel(x, y);
          final after = output.getPixel(x, y);
          if (before.r != after.r || before.g != after.g) changed++;
        }
      }
      return changed;
    }

    expect(changedIn(160, 0, 320, 120), greaterThan(0));
    expect(changedIn(0, 120, 320, 240), 0);
  });
}

WatermarkSceneResult _paint(
  Size canvasSize, {
  WatermarkSettings settings = const WatermarkSettings(),
  ui.Image? logo,
  WatermarkAutoDecision decision = WatermarkAutoDecision.none,
}) {
  final recorder = ui.PictureRecorder();
  final result = WatermarkScene.paint(
    canvas: Canvas(recorder),
    canvasSize: canvasSize,
    settings: settings,
    logo: logo,
    decision: decision,
  );
  recorder.endRecording().dispose();
  return result;
}

Future<ui.Image> _logoImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawCircle(
    const Offset(20, 20),
    18,
    Paint()..color = const Color(0xFFFF3366),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 40);
  picture.dispose();
  return image;
}

Future<(int, int)> _paintedColumns(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgba = data!.buffer.asUint8List();
  var left = image.width;
  var right = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (rgba[(y * image.width + x) * 4 + 3] == 0) continue;
      left = math.min(left, x);
      right = math.max(right, x + 1);
    }
  }
  return (left, right);
}
