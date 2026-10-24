import 'dart:convert';
import 'dart:math';

/// Compares two secrets without leaking the first mismatching position
/// through timing.
bool constantTimeEquals(String expected, String actual) {
  final expectedBytes = utf8.encode(expected);
  final actualBytes = utf8.encode(actual);
  var difference = expectedBytes.length ^ actualBytes.length;
  final length = max(expectedBytes.length, actualBytes.length);
  for (var index = 0; index < length; index++) {
    final left = index < expectedBytes.length ? expectedBytes[index] : 0;
    final right = index < actualBytes.length ? actualBytes[index] : 0;
    difference |= left ^ right;
  }
  return difference == 0;
}

/// Like [constantTimeEquals], but an unset or empty secret never matches.
bool secretsMatch(String? expected, String? presented) {
  if (expected == null ||
      expected.isEmpty ||
      presented == null ||
      presented.isEmpty) {
    return false;
  }
  return constantTimeEquals(expected, presented);
}
