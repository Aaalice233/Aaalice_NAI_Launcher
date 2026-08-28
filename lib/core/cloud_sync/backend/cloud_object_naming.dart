class CloudObjectNaming {
  const CloudObjectNaming._();

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9._-]{1,180}$');

  static bool isValidId(String id) =>
      _idPattern.hasMatch(id) && id != '.' && id != '..';

  static void validateId(String id) {
    if (!isValidId(id)) {
      throw const FormatException('Invalid cloud object id');
    }
  }

  static String manifestFileName(String snapshotId) {
    validateId(snapshotId);
    return '$snapshotId.json';
  }

  static String? snapshotIdFromManifestName(String name) {
    if (!name.endsWith('.json')) return null;
    final id = name.substring(0, name.length - '.json'.length);
    return isValidId(id) ? id : null;
  }

  /// Objects produced by snapshot_uploader are `<snapshotId>.<index>`.
  static String? snapshotIdFromObjectId(String objectId) {
    if (!isValidId(objectId)) return null;
    final separator = objectId.lastIndexOf('.');
    if (separator <= 0) return null;
    final index = objectId.substring(separator + 1);
    if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(index)) return null;
    final snapshotId = objectId.substring(0, separator);
    return isValidId(snapshotId) ? snapshotId : null;
  }
}
