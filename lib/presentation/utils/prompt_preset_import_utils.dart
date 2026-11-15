import 'package:flutter_riverpod/misc.dart';

import '../../core/constants/api_constants.dart';
import '../providers/quality_preset_provider.dart';
import '../providers/uc_preset_provider.dart';

typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

void applyImportedQualityToggle(
  ProviderReader read,
  bool qualityToggle,
) {
  final notifier = read(qualityPresetNotifierProvider.notifier);
  if (qualityToggle) {
    notifier.setNaiDefault();
  } else {
    notifier.setNone();
  }
}

void applyImportedUcPreset(
  ProviderReader read,
  int ucPreset,
) {
  read(ucPresetNotifierProvider.notifier).setPresetType(
    UcPresets.getPresetTypeFromInt(ucPreset),
  );
}
