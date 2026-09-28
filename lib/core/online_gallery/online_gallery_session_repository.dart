import '../constants/storage_keys.dart';
import '../storage/local_storage_service.dart';
import '../utils/app_logger.dart';

class OnlineGallerySessionRepository {
  OnlineGallerySessionRepository(this._storage);

  final LocalStorageService _storage;
  Future<void> _writeQueue = Future<void>.value();
  String? _lastEncoded;

  String? read() =>
      _storage.getSetting<String>(StorageKeys.onlineGalleryBrowsingSessionV1);

  void seed(String encoded) => _lastEncoded = encoded;

  void save(String encoded) {
    if (encoded == _lastEncoded) return;
    _lastEncoded = encoded;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _storage.setSetting(
          StorageKeys.onlineGalleryBrowsingSessionV1,
          encoded,
        );
      } catch (error, stack) {
        AppLogger.e(
          'Failed to persist online gallery browsing session',
          error,
          stack,
          'OnlineGallery',
        );
      }
    });
  }

  Future<void> flush() => _writeQueue;
}
