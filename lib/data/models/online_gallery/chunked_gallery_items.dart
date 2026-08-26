import 'dart:collection';

import 'gallery_item.dart';

/// Read-only list backed by immutable response-page chunks.
///
/// Appending never copies earlier items. Random access uses a binary search over
/// cumulative chunk ends and stable-key lookup remains O(1).
class ChunkedGalleryItems extends ListBase<GalleryItem> {
  ChunkedGalleryItems()
    : _chunks = const <List<GalleryItem>>[],
      _endOffsets = const <int>[],
      _indicesByStableKey = const <String, int>{};

  factory ChunkedGalleryItems.from(Iterable<GalleryItem> items) {
    return ChunkedGalleryItems().appendPage(items);
  }

  ChunkedGalleryItems._({
    required List<List<GalleryItem>> chunks,
    required List<int> endOffsets,
    required Map<String, int> indicesByStableKey,
  }) : _chunks = List<List<GalleryItem>>.unmodifiable(chunks),
       _endOffsets = List<int>.unmodifiable(endOffsets),
       _indicesByStableKey = Map<String, int>.unmodifiable(indicesByStableKey);

  final List<List<GalleryItem>> _chunks;
  final List<int> _endOffsets;
  final Map<String, int> _indicesByStableKey;

  @override
  int get length => _endOffsets.isEmpty ? 0 : _endOffsets.last;

  @override
  set length(int value) =>
      throw UnsupportedError('ChunkedGalleryItems is read-only');

  @override
  Iterator<GalleryItem> get iterator =>
      _chunks.expand((chunk) => chunk).iterator;

  @override
  GalleryItem operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    var low = 0;
    var high = _endOffsets.length - 1;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (index < _endOffsets[middle]) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    final chunkStart = low == 0 ? 0 : _endOffsets[low - 1];
    return _chunks[low][index - chunkStart];
  }

  @override
  void operator []=(int index, GalleryItem value) =>
      throw UnsupportedError('ChunkedGalleryItems is read-only');

  ChunkedGalleryItems appendPage(Iterable<GalleryItem> page) {
    return mergePage(page);
  }

  /// Appends unseen rows and combines duplicate rows when requested.
  ///
  /// Existing chunks are shared unless they contain a replaced row, so a
  /// local favorite snapshot can enrich a remote list row without rebuilding
  /// the complete collection.
  ChunkedGalleryItems mergePage(
    Iterable<GalleryItem> page, {
    GalleryItem Function(GalleryItem current, GalleryItem incoming)?
    mergeDuplicate,
  }) {
    final indices = Map<String, int>.of(_indicesByStableKey);
    final appended = <GalleryItem>[];
    final replacements = <int, GalleryItem>{};
    for (final item in page) {
      final existingIndex = indices[item.stableKey];
      if (existingIndex == null) {
        indices[item.stableKey] = length + appended.length;
        appended.add(item);
        continue;
      }
      if (existingIndex >= length) {
        final appendedIndex = existingIndex - length;
        final current = appended[appendedIndex];
        appended[appendedIndex] =
            mergeDuplicate?.call(current, item) ?? current;
        continue;
      }
      final current = replacements[existingIndex] ?? this[existingIndex];
      final merged = mergeDuplicate?.call(current, item) ?? current;
      if (!identical(merged, current)) replacements[existingIndex] = merged;
    }
    if (appended.isEmpty && replacements.isEmpty) return this;

    final chunks = List<List<GalleryItem>>.of(_chunks);
    if (replacements.isNotEmpty) {
      var chunkStart = 0;
      for (var chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        final chunkEnd = _endOffsets[chunkIndex];
        final affected = replacements.entries.where(
          (entry) => entry.key >= chunkStart && entry.key < chunkEnd,
        );
        if (affected.isNotEmpty) {
          final mutable = List<GalleryItem>.of(chunks[chunkIndex]);
          for (final entry in affected) {
            mutable[entry.key - chunkStart] = entry.value;
          }
          chunks[chunkIndex] = List<GalleryItem>.unmodifiable(mutable);
        }
        chunkStart = chunkEnd;
      }
    }
    final endOffsets = List<int>.of(_endOffsets);
    if (appended.isNotEmpty) {
      final immutablePage = List<GalleryItem>.unmodifiable(appended);
      chunks.add(immutablePage);
      endOffsets.add(length + immutablePage.length);
    }
    return ChunkedGalleryItems._(
      chunks: chunks,
      endOffsets: endOffsets,
      indicesByStableKey: indices,
    );
  }

  /// Removes rows without copying chunks that contain no matching keys.
  ChunkedGalleryItems removeStableKeys(Set<String> stableKeys) {
    if (stableKeys.isEmpty ||
        !stableKeys.any(_indicesByStableKey.containsKey)) {
      return this;
    }

    final chunks = <List<GalleryItem>>[];
    final endOffsets = <int>[];
    final indices = <String, int>{};
    var length = 0;
    for (final chunk in _chunks) {
      final affected = chunk.any((item) => stableKeys.contains(item.stableKey));
      final retained = affected
          ? List<GalleryItem>.unmodifiable(
              chunk.where((item) => !stableKeys.contains(item.stableKey)),
            )
          : chunk;
      if (retained.isEmpty) continue;
      for (final item in retained) {
        indices[item.stableKey] = length++;
      }
      chunks.add(retained);
      endOffsets.add(length);
    }
    return ChunkedGalleryItems._(
      chunks: chunks,
      endOffsets: endOffsets,
      indicesByStableKey: indices,
    );
  }

  bool containsStableKey(String stableKey) =>
      _indicesByStableKey.containsKey(stableKey);

  int? indexOfStableKey(String stableKey) => _indicesByStableKey[stableKey];

  int get chunkCount => _chunks.length;

  List<int> get chunkSizes =>
      List<int>.unmodifiable(_chunks.map((chunk) => chunk.length));
}
