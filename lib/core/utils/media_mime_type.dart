String mediaMimeTypeForExtension(
  String extension, {
  String fallback = 'application/octet-stream',
}) {
  final normalized = extension.trim().toLowerCase().replaceFirst(
    RegExp(r'^\.'),
    '',
  );
  return switch (normalized) {
    'jpg' || 'jpeg' || 'jpe' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'avif' => 'image/avif',
    'bmp' => 'image/bmp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'svg' => 'image/svg+xml',
    'mp4' || 'm4v' => 'video/mp4',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    'mkv' => 'video/x-matroska',
    _ => fallback,
  };
}
