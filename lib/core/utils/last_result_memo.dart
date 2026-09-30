/// 单槽记忆：键与上一次相等时直接返回上一次的结果。
///
/// 键按 `==` 比较，列表类输入应是不可原地修改的快照，这样按身份判等即可。
/// [compute] 只应读取键里的数据，否则键相等时会拿到过期结果。
final class LastResultMemo<K extends Object, V> {
  ({K key, V value})? _last;

  V resolve(K key, V Function(K key) compute) {
    final last = _last;
    if (last != null && last.key == key) return last.value;
    final value = compute(key);
    _last = (key: key, value: value);
    return value;
  }
}
