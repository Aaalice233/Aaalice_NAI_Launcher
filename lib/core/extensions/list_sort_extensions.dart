extension ListSortByKey<T> on List<T> {
  /// 按 [keyOf] 的结果原地排序，每个元素的键只计算一次。
  ///
  /// 比较结果与在比较器里现算 [keyOf] 相同，键相等的元素也排出同样的顺序。
  void sortByKey<K extends Comparable<Object>>(K Function(T element) keyOf) {
    if (length < 2) return;
    final keyed = [
      for (final element in this) (key: keyOf(element), element: element),
    ]..sort((a, b) => a.key.compareTo(b.key));
    for (var index = 0; index < keyed.length; index++) {
      this[index] = keyed[index].element;
    }
  }
}
