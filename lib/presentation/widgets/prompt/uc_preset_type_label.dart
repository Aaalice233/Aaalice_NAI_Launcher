import '../../../core/constants/api_constants.dart';
import '../../../l10n/app_localizations.dart';

extension UcPresetTypeLabel on UcPresetType {
  String label(AppLocalizations l10n) => switch (this) {
    UcPresetType.heavy => l10n.ucPreset_heavy,
    UcPresetType.light => l10n.ucPreset_light,
    UcPresetType.furryFocus => l10n.ucPreset_furryFocus,
    UcPresetType.humanFocus => l10n.ucPreset_humanFocus,
    UcPresetType.none => l10n.ucPreset_none,
  };
}
