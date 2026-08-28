import 'vibe_library_hive_repository.dart';
import 'vibe_library_storage_protocol.dart';

export 'vibe_library_hive_repository.dart';

/// Compatibility lifecycle boundary for integrations that used the former
/// storage lifecycle fragment directly.
///
/// New code should normally inject [VibeLibraryRepositoryProtocol] into the
/// storage facade. This class remains useful for applications that need to
/// explicitly open and close Vibe storage independently of that facade.
class VibeLibraryStorageLifecycle {
  VibeLibraryStorageLifecycle({VibeLibraryRepositoryProtocol? repository})
    : _repository = repository ?? HiveVibeLibraryRepository();

  final VibeLibraryRepositoryProtocol _repository;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await _repository.init();
    _initialized = true;
  }

  Future<void> close() async {
    if (!_initialized) return;
    await _repository.close();
    _initialized = false;
  }
}
