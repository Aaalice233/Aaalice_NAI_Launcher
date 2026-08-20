import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/comfyui/seedvr2_support.dart';

void main() {
  group('ComfySeedvr2Capabilities', () {
    const nativeModels = ['seedvr2_3b_int8_convrot.safetensors'];
    const legacyModels = ['seedvr2_ema_3b-Q4_K_M.gguf'];
    const vaeModels = [r'SeedVR2\ema_vae_fp16.safetensors'];

    test('automatic mode prefers the native backend', () {
      const capabilities = ComfySeedvr2Capabilities(
        nativeNodesAvailable: true,
        legacyNodesAvailable: true,
        nativeModels: nativeModels,
        legacyModels: legacyModels,
        nativeVaeModels: vaeModels,
      );

      expect(
        capabilities.resolveBackend(ComfySeedvr2Engine.automatic),
        ComfySeedvr2Backend.native,
      );
    });

    test('automatic mode falls back to installed legacy nodes', () {
      const capabilities = ComfySeedvr2Capabilities(
        legacyNodesAvailable: true,
        legacyModels: legacyModels,
      );

      expect(
        capabilities.resolveBackend(ComfySeedvr2Engine.automatic),
        ComfySeedvr2Backend.legacy,
      );
      expect(capabilities.resolveBackend(ComfySeedvr2Engine.native), isNull);
    });

    test('native backend requires nodes, a diffusion model, and the VAE', () {
      const missingVae = ComfySeedvr2Capabilities(
        nativeNodesAvailable: true,
        nativeModels: nativeModels,
      );

      expect(missingVae.nativeUsable, isFalse);
      expect(missingVae.anyUsable, isFalse);
    });

    test('prefers the official VAE even when it is in a subfolder', () {
      const capabilities = ComfySeedvr2Capabilities(
        nativeVaeModels: [
          'unrelated_seedvr2_vae.safetensors',
          r'SeedVR2\ema_vae_fp16.safetensors',
        ],
      );

      expect(
        capabilities.preferredNativeVae,
        r'SeedVR2\ema_vae_fp16.safetensors',
      );
    });
  });
}
