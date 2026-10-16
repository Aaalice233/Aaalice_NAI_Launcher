import 'dart:io';

import 'package:flutter/foundation.dart';

/// Tells whether the file at a path is still the one that was read earlier.
@immutable
class LocalFileIdentity {
  const LocalFileIdentity({
    required this.size,
    required this.modifiedMicros,
    required this.changedMicros,
  });

  /// Returns null when the path is not a regular file.
  static Future<LocalFileIdentity?> stat(String path) async =>
      fromStat(await FileStat.stat(path));

  /// Returns null when the path is not a regular file.
  static LocalFileIdentity? statSync(String path) =>
      fromStat(FileStat.statSync(path));

  /// Returns null when [stat] does not describe a regular file.
  static LocalFileIdentity? fromStat(FileStat stat) {
    if (stat.type != FileSystemEntityType.file) return null;
    return LocalFileIdentity(
      size: stat.size,
      modifiedMicros: stat.modified.microsecondsSinceEpoch,
      changedMicros: stat.changed.microsecondsSinceEpoch,
    );
  }

  final int size;
  final int modifiedMicros;
  // Creation time on Windows and inode change time on POSIX, which catches a
  // replacement that preserved the modification time.
  final int changedMicros;

  @override
  bool operator ==(Object other) =>
      other is LocalFileIdentity &&
      size == other.size &&
      modifiedMicros == other.modifiedMicros &&
      changedMicros == other.changedMicros;

  @override
  int get hashCode => Object.hash(size, modifiedMicros, changedMicros);

  @override
  String toString() =>
      '$size bytes, modified $modifiedMicros us, changed $changedMicros us';
}
