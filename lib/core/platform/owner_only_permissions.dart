import 'dart:io';

/// Restricts `path` to its owner. Injected so the failure branch stays
/// reachable on platforms without `chmod`.
typedef OwnerOnlyPermissionGuard =
    Future<void> Function(String path, String mode);

/// Default [OwnerOnlyPermissionGuard] for discovery files that carry a
/// session secret, and for the per-user directory holding them.
// The Windows profile directory already carries per-user ACLs.
Future<void> restrictPathToOwner(String path, String mode) async {
  if (Platform.isWindows) {
    return;
  }
  final result = await Process.run('chmod', [mode, path]);
  if (result.exitCode != 0) {
    throw FileSystemException(
      'chmod $mode failed with exit code ${result.exitCode}',
      path,
    );
  }
}
