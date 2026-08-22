import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';

class OnlineGalleryOutputFilterSettings {
  const OnlineGalleryOutputFilterSettings({required this.tags});

  /// Tags that describe source-side censoring or watermarks but are generally
  /// undesirable when recreating an image. A persisted empty list remains
  /// empty; these defaults are only used before the user saves this setting.
  static const defaultTags = <String>{
    '3rd_party_watermark',
    'artist_watermark',
    'bar_censor',
    'blur_censor',
    'blur_censorship',
    'censor_bar',
    'censored',
    'censored_version_at_source',
    'character_watermark',
    'distracting_watermark',
    'extremely_distracting_watermark',
    'miyoushe_watermark',
    'mosaic',
    'mosaic_censoring',
    'mosaic_censorship',
    'photo_date_watermark',
    'pixelated',
    'sample_watermark',
    'third-party_watermark',
    'too_many_watermarks',
    'unobtrusive_watermark',
    'watermark',
    'watermark_grid',
    'watermarked_at_source',
    'weibo_watermark',
  };

  final Set<String> tags;

  bool contains(String tag) {
    final normalized = normalizeTag(tag);
    if (normalized == null) return false;
    if (tags.contains(normalized)) return true;

    // Artist tags are rendered as `artist:name` in output, while the detail
    // menu adds the source tag (`name`). Treat both forms as the same tag.
    const artistPrefix = 'artist:';
    return normalized.startsWith(artistPrefix) &&
        tags.contains(normalized.substring(artistPrefix.length));
  }

  Iterable<String> filterTags(Iterable<String> values) sync* {
    for (final value in values) {
      if (!contains(value)) yield value;
    }
  }

  /// Filters comma-separated prompt tags by exact normalized tag identity.
  /// It deliberately never performs substring replacement, so filtering
  /// `watermark` cannot damage unrelated tags or free-form prompt text.
  String filterPrompt(String prompt) {
    if (prompt.trim().isEmpty || tags.isEmpty) return prompt.trim();
    return prompt
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && !contains(part))
        .join(', ');
  }

  static String? normalizeTag(String value) {
    var normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    while (normalized.startsWith('-')) {
      normalized = normalized.substring(1).trimLeft();
    }

    // Common NovelAI emphasis wrappers and numeric emphasis syntax should not
    // prevent an otherwise exact configured tag from matching.
    var changed = true;
    while (changed && normalized.length > 1) {
      changed = false;
      for (final wrapper in const [('(', ')'), ('[', ']'), ('{', '}')]) {
        if (normalized.startsWith(wrapper.$1) &&
            normalized.endsWith(wrapper.$2)) {
          normalized = normalized.substring(1, normalized.length - 1).trim();
          changed = true;
        }
      }
    }
    final weighted = RegExp(r'^\d+(?:\.\d+)?::(.+)::$').firstMatch(normalized);
    if (weighted != null) normalized = weighted.group(1)!.trim();

    normalized = normalized.replaceAll(RegExp(r'\s+'), '_');
    return normalized.isEmpty ? null : normalized;
  }
}

final onlineGalleryOutputFilterProvider =
    NotifierProvider<
      OnlineGalleryOutputFilterNotifier,
      OnlineGalleryOutputFilterSettings
    >(OnlineGalleryOutputFilterNotifier.new);

class OnlineGalleryOutputFilterNotifier
    extends Notifier<OnlineGalleryOutputFilterSettings> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  OnlineGalleryOutputFilterSettings build() {
    final stored = _storage.getSetting<List<dynamic>>(
      StorageKeys.onlineGalleryOutputFilterTags,
    );
    final tags = stored == null
        ? OnlineGalleryOutputFilterSettings.defaultTags
        : _normalizeTags(stored.whereType<String>());
    return OnlineGalleryOutputFilterSettings(tags: Set.unmodifiable(tags));
  }

  Future<bool> addTag(String input) async {
    final normalized = OnlineGalleryOutputFilterSettings.normalizeTag(input);
    if (normalized == null || state.tags.contains(normalized)) return false;
    await _save({...state.tags, normalized});
    return true;
  }

  Future<int> addTags(Iterable<String> inputs) async {
    final next = {...state.tags};
    for (final input in inputs) {
      final normalized = OnlineGalleryOutputFilterSettings.normalizeTag(input);
      if (normalized != null) next.add(normalized);
    }
    final added = next.length - state.tags.length;
    if (added > 0) await _save(next);
    return added;
  }

  Future<void> removeTag(String input) async {
    final normalized = OnlineGalleryOutputFilterSettings.normalizeTag(input);
    if (normalized == null || !state.tags.contains(normalized)) return;
    await _save({...state.tags}..remove(normalized));
  }

  Future<void> clear() => _save(const <String>{});

  Future<void> resetToDefaults() =>
      _save(OnlineGalleryOutputFilterSettings.defaultTags);

  Set<String> _normalizeTags(Iterable<String> values) => values
      .map(OnlineGalleryOutputFilterSettings.normalizeTag)
      .whereType<String>()
      .toSet();

  Future<void> _save(Set<String> tags) async {
    final normalized = _normalizeTags(tags);
    await _storage.setSetting<List<String>>(
      StorageKeys.onlineGalleryOutputFilterTags,
      normalized.toList()..sort(),
    );
    state = OnlineGalleryOutputFilterSettings(
      tags: Set.unmodifiable(normalized),
    );
  }
}
