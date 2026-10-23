Map<String, Object?> deepFrozenJsonMap(Map<Object?, Object?> source) =>
    Map.unmodifiable({
      for (final MapEntry(:key, :value) in source.entries)
        '$key': _deepFrozenJsonValue(value),
    });

Map<String, Object?> deepMutableJsonMap(Map<Object?, Object?> source) => {
  for (final MapEntry(:key, :value) in source.entries)
    '$key': _deepMutableJsonValue(value),
};

Object? _deepFrozenJsonValue(Object? value) => switch (value) {
  Map() => deepFrozenJsonMap(value),
  List() => List<Object?>.unmodifiable(value.map(_deepFrozenJsonValue)),
  _ => value,
};

Object? _deepMutableJsonValue(Object? value) => switch (value) {
  Map() => deepMutableJsonMap(value),
  List() => [for (final item in value) _deepMutableJsonValue(item)],
  _ => value,
};
