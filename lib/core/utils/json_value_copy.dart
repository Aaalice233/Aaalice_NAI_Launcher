Map<String, Object?> deepFrozenJsonMap(Map<Object?, Object?> source) =>
    Map.unmodifiable({
      for (final MapEntry(:key, :value) in source.entries)
        '$key': _deepFrozenJsonValue(value),
    });

Object? _deepFrozenJsonValue(Object? value) => switch (value) {
  Map() => deepFrozenJsonMap(value),
  List() => List<Object?>.unmodifiable(value.map(_deepFrozenJsonValue)),
  _ => value,
};
