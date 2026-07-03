double coerceWindowDimension(Object? value, {required double fallback}) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  return fallback;
}

double? coerceWindowPosition(Object? value) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  return null;
}
