enum QuickTagCloudBrowseScope { catalog, latest, recent }

enum QuickTagCloudMediaFilter { all, withImages, withoutImages }

class QuickTagCloudGalleryQuery {
  const QuickTagCloudGalleryQuery({
    this.codexId = 'suozhang',
    this.categoryPath = const [],
    this.updateFilterId = '',
    this.scope = QuickTagCloudBrowseScope.catalog,
    this.mediaFilter = QuickTagCloudMediaFilter.all,
    this.allowNsfw = false,
    this.allowR18g = false,
    this.favoritesOnly = false,
  });

  static const defaultStableKey = 'suozhang|||catalog|all|false|false|false';

  static QuickTagCloudGalleryQuery? tryParseStableKey(String? value) {
    if (value == null || value.length > 4096) return null;
    final parts = value.split('|');
    if (parts.length != 8) return null;
    try {
      final codexId = Uri.decodeComponent(parts[0]);
      if (codexId.isEmpty) return null;
      final categoryPath = parts[1].isEmpty
          ? const <String>[]
          : parts[1]
                .split('/')
                .map(Uri.decodeComponent)
                .where((part) => part.isNotEmpty)
                .toList(growable: false);
      final updateFilterId = Uri.decodeComponent(parts[2]);
      final scope = _enumByName(QuickTagCloudBrowseScope.values, parts[3]);
      final mediaFilter = _enumByName(
        QuickTagCloudMediaFilter.values,
        parts[4],
      );
      final allowNsfw = _parseStableKeyBool(parts[5]);
      final allowR18g = _parseStableKeyBool(parts[6]);
      final favoritesOnly = _parseStableKeyBool(parts[7]);
      if (scope == null ||
          mediaFilter == null ||
          allowNsfw == null ||
          allowR18g == null ||
          favoritesOnly == null) {
        return null;
      }
      return QuickTagCloudGalleryQuery(
        codexId: codexId,
        categoryPath: categoryPath,
        updateFilterId: updateFilterId,
        scope: scope,
        mediaFilter: mediaFilter,
        allowNsfw: allowNsfw,
        allowR18g: allowR18g,
        favoritesOnly: favoritesOnly,
      );
    } on FormatException {
      return null;
    }
  }

  final String codexId;
  final List<String> categoryPath;
  final String updateFilterId;
  final QuickTagCloudBrowseScope scope;
  final QuickTagCloudMediaFilter mediaFilter;
  final bool allowNsfw;
  final bool allowR18g;
  final bool favoritesOnly;

  String get stableKey => [
    Uri.encodeComponent(codexId),
    categoryPath.map(Uri.encodeComponent).join('/'),
    Uri.encodeComponent(updateFilterId),
    scope.name,
    mediaFilter.name,
    allowNsfw,
    allowR18g,
    favoritesOnly,
  ].join('|');
}

T? _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

bool? _parseStableKeyBool(String value) => switch (value) {
  'true' => true,
  'false' => false,
  _ => null,
};

typedef QuickTagCloudQueryReader = QuickTagCloudGalleryQuery Function();
