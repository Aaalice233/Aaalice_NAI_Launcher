import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/file_system_error_summary.dart';

void main() {
  test('keeps errno but drops the path and OS error message', () {
    const error = FileSystemException(
      'Cannot delete private vibe name',
      r'C:\Users\John Smith\private vibe name.naiv4vibe',
      OSError('Access denied for private vibe name', 5),
    );
    expect('$error', contains('John Smith'));
    expect(fileSystemErrorSummary(error), 'FileSystemException(errno: 5)');
  });

  test('omits an absent or unknown OS error code', () {
    expect(
      fileSystemErrorSummary(const FileSystemException('private message')),
      'FileSystemException',
    );
    expect(
      fileSystemErrorSummary(
        const FileSystemException(
          'private message',
          '/home/private',
          OSError(),
        ),
      ),
      'FileSystemException',
    );
  });

  test('other errors keep only the runtime type without calling toString', () {
    expect(
      fileSystemErrorSummary(const FormatException('private', 'private', 2)),
      'FormatException',
    );
    expect(fileSystemErrorSummary(_UnprintableError()), '_UnprintableError');
  });
}

class _UnprintableError implements Exception {
  @override
  String toString() => throw StateError('Exception text must not be read');
}
