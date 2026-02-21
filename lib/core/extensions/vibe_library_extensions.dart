import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';

/// Extension methods for matching and deduplicating VibeLibraryEntry lists
extension VibeLibraryEntryMatching on List<VibeLibraryEntry> {
  /// Deduplicates entries by their encoding or thumbnail hash
  ///
  /// Returns a list of unique entries, limited to [limit] items.
  /// Priority is given to entries with vibeEncoding, falling back to
  /// thumbnail hash comparison for entries without encoding.
  List<VibeLibraryEntry> deduplicateByEncodingAndThumbnail({int limit = 5}) {
    final seenEncodings = <String>{};
    final seenImageHashes = <String>{};
    final uniqueEntries = <VibeLibraryEntry>[];

    for (final entry in this) {
      if (entry.vibeEncoding.isNotEmpty) {
        if (seenEncodings.contains(entry.vibeEncoding)) {
          continue;
        }
        seenEncodings.add(entry.vibeEncoding);
        uniqueEntries.add(entry);
      } else if (entry.hasThumbnail && entry.thumbnail != null) {
        final hash = _calculateVibeThumbnailHash(entry.thumbnail!);
        if (seenImageHashes.contains(hash)) {
          continue;
        }
        seenImageHashes.add(hash);
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

  /// Finds a matching entry for the given [vibe] reference
  ///
  /// Matching priority:
  /// 1. Vibe encoding (most accurate)
  /// 2. Thumbnail hash comparison
  ///
  /// Returns null if no match is found.
  VibeLibraryEntry? findMatchingEntry(VibeReference vibe) {
    // 优先使用 encoding 匹配（最准确）
    if (vibe.vibeEncoding.isNotEmpty) {
      for (final entry in this) {
        if (entry.vibeEncoding.isNotEmpty &&
            entry.vibeEncoding == vibe.vibeEncoding) {
          return entry;
        }
      }
      // encoding 不为空但没有匹配，说明是新 vibe
      return null;
    }

    // 其次使用 thumbnail 哈希匹配
    if (vibe.thumbnail != null) {
      final vibeHash = _calculateVibeThumbnailHash(vibe.thumbnail!);
      for (final entry in this) {
        if (entry.hasThumbnail && entry.thumbnail != null) {
          final entryHash = _calculateVibeThumbnailHash(entry.thumbnail!);
          if (entryHash == vibeHash) {
            return entry;
          }
        }
      }
    }

    // 不再仅根据名称匹配，避免误判
    // 只有 encoding 或 thumbnail 完全匹配才认为是同一个 vibe
    return null;
  }
}

/// Calculates a hash for vibe thumbnail data
///
/// Returns the first 16 characters of the SHA-256 hash of the data.
String _calculateVibeThumbnailHash(Uint8List data) {
  return sha256.convert(data).toString().substring(0, 16);
}
