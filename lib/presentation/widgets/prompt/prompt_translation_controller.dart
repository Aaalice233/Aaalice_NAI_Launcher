import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/autocomplete/tag_translation_lookup.dart';
import '../../../core/utils/app_logger.dart';

enum PromptTranslationStatus { pending, translated, missing, failed }

class PromptTranslation {
  const PromptTranslation(this.status, [this.text]);
  final PromptTranslationStatus status;
  final String? text;
}

/// Shared by the tag view and text-selection caption. Request generations are
/// independent of widget identity, so an old response cannot label new input.
class PromptTranslationController extends ChangeNotifier {
  PromptTranslationController(this.lookup);
  final TagTranslationLookup lookup;
  Map<String, PromptTranslation> values = {};
  Set<String> _texts = {};
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  bool _composing = false;

  void update(
    Iterable<String> texts, {
    bool composing = false,
    bool immediate = false,
    bool force = false,
  }) {
    final next = texts.where((text) => text.trim().isNotEmpty).toSet();
    if (!force && setEquals(next, _texts) && composing == _composing) return;
    _composing = composing;
    _timer?.cancel();
    final generation = ++_generation;
    _texts = next;
    values = {
      for (final text in next)
        text:
            !force && values[text]?.status == PromptTranslationStatus.translated
            ? values[text]!
            : const PromptTranslation(PromptTranslationStatus.pending),
    };
    notifyListeners();
    if (composing || next.isEmpty) return;
    if (immediate) {
      unawaited(_query(generation, next));
    } else {
      _timer = Timer(
        const Duration(milliseconds: 150),
        () => _query(generation, next),
      );
    }
  }

  Future<void> _query(int generation, Set<String> texts) async {
    try {
      final translations = await lookup.translateBatch(texts.toList());
      if (_disposed || generation != _generation) return;
      values = {
        for (final text in texts)
          text: _translation(
            translations[TagTranslationLookup.normalizeTag(text)],
          ),
      };
    } catch (error, stack) {
      AppLogger.e('Prompt tag translation failed', error, stack);
      if (_disposed || generation != _generation) return;
      values = {
        for (final text in texts)
          text: const PromptTranslation(PromptTranslationStatus.failed),
      };
    }
    notifyListeners();
  }

  PromptTranslation _translation(String? text) => text == null
      ? const PromptTranslation(PromptTranslationStatus.missing)
      : PromptTranslation(PromptTranslationStatus.translated, text);

  void retry() => update(_texts, immediate: true, force: true);

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
