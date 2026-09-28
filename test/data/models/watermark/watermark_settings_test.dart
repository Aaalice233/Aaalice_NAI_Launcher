import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';

void main() {
  test('defaults are safe and place text at the lower right', () {
    const settings = WatermarkSettings();

    expect(settings.schemaVersion, 1);
    expect(settings.enabled, isFalse);
    expect(settings.preserveMetadata, isFalse);
    expect(settings.rememberLayoutsByOrientation, isFalse);
    expect(settings.textStyle.enabled, isTrue);
    expect(settings.logoStyle.enabled, isFalse);
    expect(settings.universalLayout.scaleBasis, WatermarkScaleBasis.shortEdge);
    expect(
      settings.universalLayout.textPlacement.anchor,
      WatermarkAnchor.bottomRight,
    );
    expect(
      settings.universalLayout.textPlacement.sizeRatio,
      inInclusiveRange(0.1, 0.4),
    );
  });

  test('versioned JSON round-trips without a load issue', () {
    const source = WatermarkSettings(
      enabled: true,
      preserveMetadata: true,
      rememberLayoutsByOrientation: true,
      textStyle: WatermarkTextStyle(text: 'Alice', opacity: 0.6),
      logoStyle: WatermarkLogoStyle(enabled: true, opacity: 0.7),
      composition: WatermarkComposition(
        arrangement: WatermarkLayerArrangement.horizontal,
        gapRatio: 0.02,
      ),
      portraitLayout: WatermarkLayout(
        textPlacement: WatermarkPlacement(
          anchor: WatermarkAnchor.topCenter,
          sizeRatio: 0.3,
          marginRatio: 0.04,
          offsetXRatio: 0.01,
          offsetYRatio: -0.02,
          zIndex: 4,
        ),
        logoPlacement: WatermarkSettings.defaultLogoPlacement,
      ),
    );

    final loaded = WatermarkSettings.decode(source.encode());

    expect(loaded.issue, isNull);
    expect(loaded.settings.toJson(), source.toJson());
  });

  test('missing legacy fields migrate to current defaults', () {
    final loaded = WatermarkSettings.decode(
      jsonEncode({
        'enabled': true,
        'textStyle': {'text': 'legacy'},
      }),
    );

    expect(loaded.issue, WatermarkSettingsLoadIssue.migrated);
    expect(loaded.settings.schemaVersion, 1);
    expect(loaded.settings.enabled, isTrue);
    expect(loaded.settings.textStyle.text, 'legacy');
    expect(loaded.settings.logoStyle.enabled, isFalse);
    expect(
      loaded.settings.landscapeLayout.textPlacement.anchor,
      WatermarkAnchor.bottomRight,
    );
  });

  test('invalid schemas are rejected without reading their fields', () {
    for (final schemaVersion in <Object?>[
      WatermarkSettings.currentSchemaVersion + 1,
      -1,
      '1',
      null,
    ]) {
      final loaded = WatermarkSettings.decode(
        jsonEncode({
          'schemaVersion': schemaVersion,
          'enabled': true,
          'textStyle': {'text': 'invalid value'},
        }),
      );

      expect(
        loaded.issue,
        WatermarkSettingsLoadIssue.corrupted,
        reason: 'schemaVersion=$schemaVersion',
      );
      expect(loaded.settings, const WatermarkSettings());
    }
  });

  test('corrupted JSON returns defaults and exposes the issue', () {
    final loaded = WatermarkSettings.decode('{not-json');

    expect(loaded.issue, WatermarkSettingsLoadIssue.corrupted);
    expect(loaded.settings.enabled, isFalse);
    expect(loaded.settings.logoStyle.enabled, isFalse);
  });

  test('numeric bounds and unknown enums are normalized', () {
    final json = const WatermarkSettings().toJson();
    final textStyle = json['textStyle']! as Map<String, Object?>;
    textStyle['opacity'] = 9;
    textStyle['alignment'] = 'diagonal';
    textStyle['strokeWidthRatio'] = -1;
    final layouts = json['layouts']! as Map<String, Object?>;
    final universal = layouts['universal']! as Map<String, Object?>;
    final placement = universal['textPlacement']! as Map<String, Object?>;
    placement['anchor'] = 'outside';
    placement['sizeRatio'] = 20;
    placement['marginRatio'] = -4;
    placement['offsetXRatio'] = 8;
    placement['zIndex'] = 500;

    final loaded = WatermarkSettings.decode(jsonEncode(json));

    expect(loaded.issue, WatermarkSettingsLoadIssue.migrated);
    expect(loaded.settings.textStyle.opacity, 1);
    expect(loaded.settings.textStyle.alignment, WatermarkTextAlignment.right);
    expect(loaded.settings.textStyle.strokeWidthRatio, 0);
    expect(
      loaded.settings.universalLayout.textPlacement.anchor,
      WatermarkAnchor.bottomRight,
    );
    expect(loaded.settings.universalLayout.textPlacement.sizeRatio, 1);
    expect(loaded.settings.universalLayout.textPlacement.marginRatio, 0);
    expect(loaded.settings.universalLayout.textPlacement.offsetXRatio, 0.5);
    expect(loaded.settings.universalLayout.textPlacement.zIndex, 100);
  });

  test('portable configuration has no local logo path field', () {
    final encoded = const WatermarkSettings().encode();

    expect(encoded, isNot(contains('logoPath')));
    expect(encoded, isNot(contains('watermark_logo_path_v1')));
  });
}
