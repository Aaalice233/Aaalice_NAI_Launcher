import 'package:nai_launcher/core/storage/local_storage_service.dart';

class MemoryLocalStorage extends LocalStorageService {
  final values = <String, Object?>{};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      values.containsKey(key) ? values[key] as T? : defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    values.remove(key);
  }
}
