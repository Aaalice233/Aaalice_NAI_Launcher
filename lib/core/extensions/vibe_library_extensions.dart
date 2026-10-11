import 'dart:typed_data';

import '../../../data/models/vibe/vibe_library_entry.dart';
import '../utils/byte_content.dart';

/// Deduplication helpers for VibeLibraryEntry lists
extension VibeLibraryEntryDeduplication on List<VibeLibraryEntry> {
  /// Deduplicates entries by their encoding or thumbnail content
  ///
  /// Returns a list of unique entries, limited to [limit] items.
  /// Priority is given to entries with vibeEncoding, falling back to
  /// thumbnail content comparison for entries without encoding.
  List<VibeLibraryEntry> deduplicateByEncodingAndThumbnail({int limit = 5}) {
    final seenEncodings = <String>{};
    final seenThumbnails = <Uint8List>[];
    final uniqueEntries = <VibeLibraryEntry>[];

    for (final entry in this) {
      if (entry.vibeEncoding.isNotEmpty) {
        if (seenEncodings.contains(entry.vibeEncoding)) {
          continue;
        }
        seenEncodings.add(entry.vibeEncoding);
        uniqueEntries.add(entry);
      } else if (entry.hasThumbnail) {
        final thumbnail = entry.thumbnail!;
        if (seenThumbnails.any((seen) => ByteContent.equals(seen, thumbnail))) {
          continue;
        }
        seenThumbnails.add(thumbnail);
        uniqueEntries.add(entry);
      } else {
        // 既没有 encoding 也没有 thumbnail 的条目
        // 基于名称进行去重（防止完全重复的条目）
        final isDuplicate = uniqueEntries.any(
          (e) =>
              e.vibeEncoding.isEmpty &&
              !e.hasThumbnail &&
              e.name.toLowerCase() == entry.name.toLowerCase(),
        );
        if (isDuplicate) {
          continue;
        }
        uniqueEntries.add(entry);
      }

      if (uniqueEntries.length >= limit) {
        break;
      }
    }

    return uniqueEntries;
  }
}
