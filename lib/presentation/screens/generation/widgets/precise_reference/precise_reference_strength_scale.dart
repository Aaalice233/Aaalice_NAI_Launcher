double preciseReferenceStrengthPosition(double value, double maximum) {
  final strength = value.clamp(0.0, maximum);
  if (maximum == 1) return strength;
  return strength <= 1
      ? strength / 2
      : 0.5 + (strength - 1) / (2 * (maximum - 1));
}

double preciseReferenceStrengthAtPosition(double value, double maximum) {
  final position = value.clamp(0.0, 1.0);
  final strength = maximum == 1
      ? position
      : position <= 0.5
      ? position * 2
      : 1 + (position - 0.5) * 2 * (maximum - 1);
  return (strength * 20).round() / 20;
}
