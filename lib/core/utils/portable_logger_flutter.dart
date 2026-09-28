import 'app_logger.dart';

class PortableLogger {
  PortableLogger._();

  static void d(Object message, [String? tag]) => AppLogger.d(message, tag);

  static void w(Object message, [String? tag]) => AppLogger.w(message, tag);

  static void e(
    Object message, [
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  ]) => AppLogger.e(message, error, stackTrace, tag);
}
