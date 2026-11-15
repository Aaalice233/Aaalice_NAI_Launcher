import 'package:flutter_riverpod/flutter_riverpod.dart';

/// View-only state that must survive responsive generation layout replacements.
final generationComparisonEnabledProvider =
    NotifierProvider<GenerationComparisonEnabledNotifier, bool>(
      GenerationComparisonEnabledNotifier.new,
    );

class GenerationComparisonEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    state = enabled;
  }
}
