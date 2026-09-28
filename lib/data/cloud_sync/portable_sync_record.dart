import 'dart:collection';

/// Business-layer record independent from any cloud transport or snapshot.
class PortableSyncRecord {
  PortableSyncRecord({
    required this.adapterId,
    required this.id,
    required this.kind,
    Map<String, Object?> data = const {},
    this.resource,
    this.deleted = false,
  }) : data = UnmodifiableMapView(Map.of(data)) {
    if (!_identity.hasMatch(adapterId) || !_identity.hasMatch(id)) {
      throw const FormatException('Invalid portable sync record identity');
    }
    if (!_kind.hasMatch(kind)) {
      throw const FormatException('Invalid portable sync record kind');
    }
    if (deleted && resource != null) {
      throw const FormatException('A tombstone cannot carry a resource');
    }
  }

  static final RegExp _identity = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,191}$',
  );
  static final RegExp _kind = RegExp(r'^[a-z][a-z0-9._-]{0,63}$');

  final String adapterId;
  final String id;
  final String kind;
  final Map<String, Object?> data;
  final PortableSyncResource? resource;
  final bool deleted;
}

typedef PortableResourceReader = Stream<List<int>> Function();

/// Lazy binary payload. [openRead] must create a fresh stream on every call.
class PortableSyncResource {
  PortableSyncResource({
    required this.relativePath,
    required this.length,
    required this.openRead,
    this.mediaType = 'application/octet-stream',
  }) {
    final normalized = relativePath.replaceAll('\\', '/');
    if (length < 0 ||
        normalized != relativePath ||
        normalized.length > 1024 ||
        normalized.contains('\u0000') ||
        normalized.startsWith('/') ||
        normalized
            .split('/')
            .any(
              (part) =>
                  part.isEmpty ||
                  part == '.' ||
                  part == '..' ||
                  part.contains(':'),
            )) {
      throw const FormatException('Unsafe portable resource path');
    }
  }

  final String relativePath;
  final int length;
  final String mediaType;
  final PortableResourceReader openRead;
}
