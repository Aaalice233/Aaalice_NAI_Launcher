import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/autocomplete/autocomplete_settings.dart';
import '../../core/utils/nai_prompt_formatter.dart';
import '../providers/generation/generation_settings_notifiers.dart'
    show autoFormatPromptSettingsProvider;

final promptFormattingServiceProvider = Provider<PromptFormattingService>(
  PromptFormattingService.new,
);

/// Shared formatting policy for editors, transfers and random prompt results.
class PromptFormattingService {
  const PromptFormattingService(this._ref);

  final Ref _ref;

  /// Editors may explicitly override the global switch through their config.
  String format(String prompt, {bool? enabled}) {
    if (!(enabled ?? _ref.read(autoFormatPromptSettingsProvider))) {
      return prompt;
    }
    return NaiPromptFormatter.format(
      prompt,
      replaceUnderscores: _ref
          .read(autocompleteSettingsProvider)
          .replaceUnderscores,
    );
  }
}
