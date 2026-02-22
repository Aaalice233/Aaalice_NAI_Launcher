import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../data/models/vibe/vibe_library_entry.dart';
import '../../data/models/vibe/vibe_reference.dart';

/// Vibe 库条目列表匹配扩展
///
/// 提供基于编码和缩略图的条目去重和查找功能
extension VibeLibraryEntryMatching on List<VibeLibraryEntry> {
  /// 根据编码和缩略图去重
  ///
  /// 优先使用 vibeEncoding 进行去重，如果没有编码则使用缩略图哈希
  /// [limit] 返回的最大条目数，默认 5
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
        uniqueEntries.add(entry);
      }

      if (uniqueEntries.length >= limit) {
        break;
      }
    }

    return uniqueEntries;
  }

  /// 查找与指定 vibe 匹配的条目
  ///
  /// 匹配优先级：
  /// 1. vibeEncoding 精确匹配
  /// 2. 缩略图哈希匹配
  /// 3. displayName 匹配
  ///
  /// 如果没有找到匹配的条目，返回 null
  VibeLibraryEntry? findMatchingEntry(VibeReference vibe) {
    if (vibe.vibeEncoding.isNotEmpty) {
      for (final entry in this) {
        if (entry.vibeEncoding.isNotEmpty &&
            entry.vibeEncoding == vibe.vibeEncoding) {
          return entry;
        }
      }
      return null;
    }

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
      return null;
    }

    for (final entry in this) {
      if (entry.vibeDisplayName == vibe.displayName) {
        return entry;
      }
    }

    return null;
  }
}

/// 计算 Vibe 缩略图的哈希值
///
/// 使用 SHA-256 计算数据哈希，取前 32 个字符（128 位）作为唯一标识
/// 用于快速比较两个缩略图是否相同
/// 使用 32 个字符提供足够的碰撞抵抗（2^128 种组合）
String _calculateVibeThumbnailHash(Uint8List data) {
  return sha256.convert(data).toString().substring(0, 32);
}
