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
    final indices = Map<String, int>.of(_indicesByStableKey);
    final unique = <GalleryItem>[];
    for (final item in page) {
      if (indices.containsKey(item.stableKey)) continue;
      indices[item.stableKey] = length + unique.length;
      unique.add(item);
    }
    if (unique.isEmpty) return this;

    final immutablePage = List<GalleryItem>.unmodifiable(unique);
    return ChunkedGalleryItems._(
      chunks: <List<GalleryItem>>[..._chunks, immutablePage],
      endOffsets: <int>[..._endOffsets, length + immutablePage.length],
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
