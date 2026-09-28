import 'completion_models.dart';

class LibraryCompletionEntry {
  const LibraryCompletionEntry({
    required this.name,
    required this.contentPreview,
    required this.useCount,
  });

  final String name;
  final String contentPreview;
  final int useCount;
}

class TagLibraryCompletionSource implements CompletionSource {
  const TagLibraryCompletionSource({required this.searchEntries});

  static const int maxResults = 15;

  final List<LibraryCompletionEntry> Function(String query, int limit)
  searchEntries;

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    if (query.kind != CompletionQueryKind.libraryAlias) return const [];

    final limit = query.limit.clamp(1, maxResults);
    final normalizedQuery = query.token.toLowerCase();
    return searchEntries(query.token, limit)
        .map(
          (entry) => CompletionCandidate(
            canonicalTag: entry.name,
            category: TagCategory.library,
            postCount: entry.useCount,
            translation: entry.contentPreview,
            matchKind: _matchKind(entry.name, normalizedQuery),
            sources: const {CompletionSourceKind.library},
          ),
        )
        .toList(growable: false);
  }

  static CompletionMatchKind _matchKind(String name, String query) {
    if (query.isEmpty) return CompletionMatchKind.fullText;
    final normalizedName = name.toLowerCase();
    if (normalizedName == query) return CompletionMatchKind.aliasExact;
    if (normalizedName.startsWith(query)) {
      return CompletionMatchKind.aliasPrefix;
    }
    return CompletionMatchKind.fullText;
  }
}
