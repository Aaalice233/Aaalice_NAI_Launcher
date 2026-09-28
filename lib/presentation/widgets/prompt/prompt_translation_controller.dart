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
  PromptTranslationController(this.lookup) {
    lookup.addListener(_lookupUpdated);
  }
  final TagTranslationLookup lookup;
  Map<String, PromptTranslation> values = {};
  Set<String> _texts = {};
  Timer? _timer;
  int _generation = 0;
  final Map<String, int> _inFlight = {};
  bool _disposed = false;
  bool _composing = false;

  void _lookupUpdated() {
    final updated = <String, PromptTranslation>{};
    for (final text in _texts) {
      final translation = lookup.cachedTranslation(text);
      if (translation == null || values[text]?.text == translation) continue;
      _inFlight.remove(text);
      updated[text] = PromptTranslation(
        PromptTranslationStatus.translated,
        translation,
      );
    }
    if (updated.isEmpty) return;
    values = {...values, ...updated};
    notifyListeners();
  }

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
    _texts = next;
    _inFlight.removeWhere((text, _) => force || !next.contains(text));
    values = {
      for (final text in next)
        text: !force && values.containsKey(text)
            ? values[text]!
            : const PromptTranslation(PromptTranslationStatus.pending),
    };
    notifyListeners();
    final pending = next
        .where(
          (text) =>
              values[text]!.status == PromptTranslationStatus.pending &&
              !_inFlight.containsKey(text),
        )
        .toSet();
    if (composing || pending.isEmpty) return;
    if (immediate) {
      unawaited(_query(pending));
    } else {
      _timer = Timer(const Duration(milliseconds: 150), () => _query(pending));
    }
  }

  Future<void> _query(Set<String> texts) async {
    final generation = ++_generation;
    for (final text in texts) {
      _inFlight[text] = generation;
    }
    Map<String, PromptTranslation> resolved;
    try {
      final translations = await lookup.translateBatch(texts.toList());
      resolved = {
        for (final text in texts)
          text: _translation(
            translations[TagTranslationLookup.normalizeTag(text)],
          ),
      };
    } catch (error, stack) {
      AppLogger.e('Prompt tag translation failed', error, stack);
      resolved = {
        for (final text in texts)
          text: const PromptTranslation(PromptTranslationStatus.failed),
      };
    }
    if (_disposed) return;
    final accepted = <String, PromptTranslation>{};
    for (final entry in resolved.entries) {
      if (_inFlight[entry.key] != generation) continue;
      _inFlight.remove(entry.key);
      accepted[entry.key] = entry.value;
    }
    if (accepted.isEmpty) return;
    values = {...values, ...accepted};
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
    lookup.removeListener(_lookupUpdated);
    super.dispose();
  }
}
