import 'dart:typed_data';

/// 待落盘快照里的图片；没有 toJson，任何序列化路径误碰到它都会直接失败。
final class PendingSnapshotBlob {
  const PendingSnapshotBlob(this.bytes);

  final Uint8List bytes;
}

/// 快照中承载图片的槽位：源图、蒙版、Vibe 原图与编码、精准参考图。
abstract final class SnapshotBlobSlots {
  static const List<String> _topLevel = ['sourceImage', 'maskImage'];
  static const String _vibes = 'vibeReferences';
  static const List<String> _vibeSlots = ['rawImageData', 'vibeEncoding'];
  static const String _precise = 'preciseReferences';
  static const List<String> _preciseSlots = ['image'];

  /// 按固定顺序给出所有非空槽位的值；结构非法的部分跳过，交给解码报错。
  static Iterable<Object> values(Map<String, dynamic> snapshot) sync* {
    for (final key in _topLevel) {
      final value = snapshot[key];
      if (value != null) yield value;
    }
    yield* _itemValues(snapshot[_vibes], _vibeSlots);
    yield* _itemValues(snapshot[_precise], _preciseSlots);
  }

  /// 逐槽位替换后返回新快照，键序不变，非槽位字段与原快照共享；[convert] 同时收到槽位名。
  static Map<String, dynamic> map(
    Map<String, dynamic> snapshot,
    Object Function(Object value, String slot) convert,
  ) {
    final result = Map<String, dynamic>.of(snapshot);
    for (final key in _topLevel) {
      final value = result[key];
      if (value != null) result[key] = convert(value, key);
    }
    _mapItems(result, _vibes, _vibeSlots, convert);
    _mapItems(result, _precise, _preciseSlots, convert);
    return result;
  }

  static Iterable<Object> _itemValues(Object? items, List<String> slots) sync* {
    if (items is! List) return;
    for (final item in items) {
      if (item is! Map) continue;
      for (final slot in slots) {
        final value = item[slot];
        if (value != null) yield value;
      }
    }
  }

  static void _mapItems(
    Map<String, dynamic> snapshot,
    String key,
    List<String> slots,
    Object Function(Object value, String slot) convert,
  ) {
    final items = snapshot[key];
    if (items is! List) return;
    snapshot[key] = [
      for (final item in items)
        if (item is Map)
          {
            for (final MapEntry(key: name, :value) in item.entries)
              name as String: value != null && slots.contains(name)
                  ? convert(value as Object, name)
                  : value,
          }
        else
          item,
    ];
  }
}
