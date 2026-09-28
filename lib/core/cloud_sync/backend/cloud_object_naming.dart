class CloudObjectNaming {
  const CloudObjectNaming._();

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9._-]{1,180}$');
  static final RegExp _contentAddressPattern = RegExp(r'^[a-f0-9]{64}$');

  static bool isContentAddressedId(String id) =>
      _contentAddressPattern.hasMatch(id);

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
}
