enum ComfySeedvr2Engine { automatic, native, legacy }

enum ComfySeedvr2Backend { native, legacy }

class ComfySeedvr2Capabilities {
  const ComfySeedvr2Capabilities({
    this.nativeNodesAvailable = false,
    this.legacyNodesAvailable = false,
    this.legacyTilingAvailable = false,
    this.nativeModels = const [],
    this.legacyModels = const [],
    this.nativeVaeModels = const [],
  });

  final bool nativeNodesAvailable;
  final bool legacyNodesAvailable;
  final bool legacyTilingAvailable;
  final List<String> nativeModels;
  final List<String> legacyModels;
  final List<String> nativeVaeModels;

  bool get nativeUsable =>
      nativeNodesAvailable &&
      nativeModels.isNotEmpty &&
      nativeVaeModels.isNotEmpty;

  bool get legacyUsable => legacyNodesAvailable && legacyModels.isNotEmpty;

  bool get anyUsable => nativeUsable || legacyUsable;

  ComfySeedvr2Backend? resolveBackend(ComfySeedvr2Engine engine) {
    return switch (engine) {
      ComfySeedvr2Engine.automatic =>
        nativeUsable
            ? ComfySeedvr2Backend.native
            : legacyUsable
            ? ComfySeedvr2Backend.legacy
            : null,
      ComfySeedvr2Engine.native =>
        nativeUsable ? ComfySeedvr2Backend.native : null,
      ComfySeedvr2Engine.legacy =>
        legacyUsable ? ComfySeedvr2Backend.legacy : null,
    };
  }

  List<String> modelsForBackend(ComfySeedvr2Backend? backend) {
    return switch (backend) {
      ComfySeedvr2Backend.native => nativeModels,
      ComfySeedvr2Backend.legacy => legacyModels,
      null => const [],
    };
  }

  String? get preferredNativeVae {
    if (nativeVaeModels.isEmpty) return null;
    for (final preferred in const [
      'seedvr2_ema_vae_fp16.safetensors',
      'ema_vae_fp16.safetensors',
    ]) {
      for (final model in nativeVaeModels) {
        final normalized = model.trim().toLowerCase().replaceAll('\\', '/');
        if (normalized.split('/').last == preferred) return model;
      }
    }
    return nativeVaeModels.first;
  }
}
