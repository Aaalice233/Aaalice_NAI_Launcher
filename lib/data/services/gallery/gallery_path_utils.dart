import 'dart:io';

String normalizeGalleryFilePath(String filePath) {
  final trimmed = filePath.trim();
  if (!Platform.isWindows) return trimmed;

  var normalized = trimmed.replaceAll('/', r'\');
  if (normalized.startsWith(r'\\?\UNC\')) {
    normalized = r'\\' + normalized.substring(r'\\?\UNC\'.length);
  } else if (normalized.startsWith(r'\\?\')) {
    normalized = normalized.substring(r'\\?\'.length);
  }
  return normalized;
}

String galleryFilePathKey(String filePath) {
  final normalized = normalizeGalleryFilePath(filePath);
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

bool galleryFilePathsEqual(String left, String right) =>
    galleryFilePathKey(left) == galleryFilePathKey(right);
