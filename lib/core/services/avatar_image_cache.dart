import 'dart:io';
import 'dart:typed_data';

/// Keeps the small set of saved account avatars ready for the first shell frame.
class AvatarImageCache {
  AvatarImageCache._();

  static final AvatarImageCache instance = AvatarImageCache._();

  final Map<String, Uint8List> _bytesByPath = {};
  final Map<String, Future<Uint8List?>> _loadsByPath = {};
  final Map<String, int> _revisionsByPath = {};

  Uint8List? get(String path) => _bytesByPath[path];

  Future<Uint8List?> load(String path) {
    final cached = _bytesByPath[path];
    if (cached != null) return Future.value(cached);
    final active = _loadsByPath[path];
    if (active != null) return active;

    final revision = _revisionsByPath[path] ?? 0;
    late final Future<Uint8List?> load;
    load = _read(path, revision).whenComplete(() {
      if (identical(_loadsByPath[path], load)) {
        _loadsByPath.remove(path);
      }
    });
    _loadsByPath[path] = load;
    return load;
  }

  Future<void> preload(Iterable<String> paths) async {
    await Future.wait(paths.toSet().map(load));
  }

  void evict(String? path) {
    if (path == null || path.isEmpty) return;
    _revisionsByPath[path] = (_revisionsByPath[path] ?? 0) + 1;
    _bytesByPath.remove(path);
    _loadsByPath.remove(path);
  }

  Future<Uint8List?> _read(String path, int revision) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if ((_revisionsByPath[path] ?? 0) != revision) return null;
      _bytesByPath[path] = bytes;
      return bytes;
    } on FileSystemException {
      return null;
    }
  }
}
