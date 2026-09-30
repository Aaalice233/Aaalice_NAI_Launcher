import 'dart:async';

import 'package:uuid/uuid.dart';

import 'generation_models.dart';

/// 仍在合成的失败快照：各自在历史中的预留位置与落地任务。
///
/// 预留时记下排在快照下方的条目，落地时插在其中最靠上的一条之上，
/// 捕获之后才进入历史的结果因此仍排在快照上面。
class PendingFailedSnapshots {
  final Map<String, Set<String>> _floors = <String, Set<String>>{};
  final Set<Future<void>> _landings = <Future<void>>{};

  /// 在 [history] 顶部为一张快照预留位置并返回它将使用的 id。
  ///
  /// 更早预留、尚未落地的快照同样排在它下方。
  String reserve(Iterable<GeneratedImage> history) {
    final id = const Uuid().v4();
    _floors[id] = <String>{
      for (final image in history) image.id,
      ..._floors.keys,
    };
    return id;
  }

  /// 从更早会话恢复的条目追加在历史末尾，归入全部预留位置的下方。
  void placeBelowAll(Iterable<String> ids) {
    final older = ids.toSet();
    for (final floor in _floors.values) {
      floor.addAll(older);
    }
  }

  /// 取出 [id] 的预留位置；位置已被 [discardAll] 丢弃时返回 `null`。
  Set<String>? take(String id) => _floors.remove(id);

  /// 丢弃全部预留位置，仍在合成的快照落地时直接舍弃。
  void discardAll() => _floors.clear();

  /// 登记一次落地任务；任务自身的异常照常交给所在 zone。
  void track(Future<void> landing) {
    _landings.add(landing);
    unawaited(landing.whenComplete(() => _landings.remove(landing)));
  }

  /// 等待当前已登记的落地任务全部结束。
  Future<void> settled() {
    return Future.wait<void>([
      // 失败已经由 track 交给 zone，这里只等结束。
      for (final landing in _landings) landing.catchError((Object _) {}),
    ]);
  }

  /// 把 [snapshot] 插到 [history] 中最靠上的 [floor] 条目之上；它们都已不在时放到末尾。
  static List<GeneratedImage> insert(
    List<GeneratedImage> history,
    GeneratedImage snapshot,
    Set<String> floor,
  ) {
    final index = history.indexWhere((image) => floor.contains(image.id));
    final position = index < 0 ? history.length : index;
    return <GeneratedImage>[
      ...history.take(position),
      snapshot,
      ...history.skip(position),
    ];
  }
}
