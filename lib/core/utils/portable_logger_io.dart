import 'dart:io';

class PortableLogger {
  PortableLogger._();

  static void d(Object message, [String? tag]) {}

  static void w(Object message, [String? tag]) {
    stderr.writeln(_format(message, tag));
  }

  static void e(
    Object message, [
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    stderr.writeln(_format(message, tag));
    if (error != null) stderr.writeln(error);
    if (stackTrace != null) stderr.writeln(stackTrace);
  }

  static String _format(Object message, String? tag) {
    return tag == null || tag.isEmpty ? '$message' : '[$tag] $message';
  }
}
