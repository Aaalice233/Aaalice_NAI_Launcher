/// Effect Module Tests
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/effect_module.dart';

void main() {
  group('Effect Modules', () {
    final modules = [
      const NoneEffect(),
      const GlassmorphismEffect(),
      const NeonGlowEffect(),
      const TextureEffect.paper(),
    ];

    for (final module in modules) {
      group('${module.runtimeType}', () {
        test('should have valid blur strength', () {
          expect(module.blurStrength, greaterThanOrEqualTo(0));
        });

        test('should have valid texture type', () {
          expect(module.textureType, isA<TextureType>());
        });
      });
    }
  });

  group('NoneEffect', () {
    test('should have all effects disabled', () {
      const effect = NoneEffect();
      expect(effect.enableGlassmorphism, isFalse);
      expect(effect.enableNeonGlow, isFalse);
      expect(effect.textureType, TextureType.none);
      expect(effect.blurStrength, 0.0);
    });
  });

  group('GlassmorphismEffect', () {
    test('should have glassmorphism enabled', () {
      const effect = GlassmorphismEffect();
      expect(effect.enableGlassmorphism, isTrue);
      expect(effect.blurStrength, greaterThan(0));
    });
  });

  group('NeonGlowEffect', () {
    test('should have neon glow enabled', () {
      const effect = NeonGlowEffect();
      expect(effect.enableNeonGlow, isTrue);
      expect(effect.glowColor, isNotNull);
    });

    test('should accept custom glow color', () {
      const effect = NeonGlowEffect(glowColor: Colors.cyan);
      expect(effect.glowColor, Colors.cyan);
    });
  });

  group('TextureEffect', () {
    test('paper should have paperGrain texture', () {
      const effect = TextureEffect.paper();
      expect(effect.textureType, TextureType.paperGrain);
    });

    test('grunge should have grunge texture', () {
      const effect = TextureEffect.grunge();
      expect(effect.textureType, TextureType.grunge);
    });

    test('halftone should have halftone texture', () {
      const effect = TextureEffect.halftone();
      expect(effect.textureType, TextureType.halftone);
    });

    test('dotMatrix should have dotMatrix texture', () {
      const effect = TextureEffect.dotMatrix();
      expect(effect.textureType, TextureType.dotMatrix);
    });
  });
}
