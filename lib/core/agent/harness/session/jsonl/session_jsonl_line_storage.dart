import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

/// Append-only line storage that scans a file in bounded chunks.
///
/// A valid final JSON line is preserved even without a trailing newline. An
/// invalid final line is treated as an interrupted append and ignored. No file
/// handle escapes this method, even if a caller only consumes the first line.
class SessionJsonlLineStorage {
  const SessionJsonlLineStorage(this.file, {this.chunkSize = 64 * 1024});

  final io.File file;
  final int chunkSize;

  Iterable<String> readCompleteLinesSync() {
    if (!file.existsSync()) return const [];
    final lines = <String>[];
    final handle = file.openSync();
    final pending = BytesBuilder(copy: false);
    try {
      while (true) {
        final chunk = handle.readSync(chunkSize);
        if (chunk.isEmpty) break;
        var start = 0;
        for (var index = 0; index < chunk.length; index++) {
          if (chunk[index] != 0x0a) continue;
          pending.add(chunk.sublist(start, index));
          final bytes = pending.takeBytes();
          final length = bytes.isNotEmpty && bytes.last == 0x0d
              ? bytes.length - 1
              : bytes.length;
          lines.add(
            utf8.decode(bytes.sublist(0, length), allowMalformed: true),
          );
          start = index + 1;
        }
        if (start < chunk.length) pending.add(chunk.sublist(start));
      }
      final tail = pending.takeBytes();
      if (_isCompleteJsonLine(tail)) {
        lines.add(utf8.decode(tail));
      }
    } finally {
      handle.closeSync();
    }
    return lines;
  }

  void appendJsonSync(Map<String, dynamic> value) {
    _truncateIncompleteTailSync();
    file.writeAsStringSync('${jsonEncode(value)}\n', mode: io.FileMode.append);
  }

  void _truncateIncompleteTailSync() {
    if (!file.existsSync()) return;
    final handle = file.openSync(mode: io.FileMode.append);
    try {
      final length = handle.lengthSync();
      if (length == 0) return;
      handle.setPositionSync(length - 1);
      if (handle.readByteSync() == 0x0a) return;

      var end = length;
      while (end > 0) {
        final start = (end - chunkSize).clamp(0, end);
        handle.setPositionSync(start);
        final chunk = handle.readSync(end - start);
        final newline = chunk.lastIndexOf(0x0a);
        if (newline >= 0) {
          final tailStart = start + newline + 1;
          handle.setPositionSync(tailStart);
          final tail = handle.readSync(length - tailStart);
          if (_isCompleteJsonLine(tail)) {
            handle.setPositionSync(length);
            handle.writeByteSync(0x0a);
          } else {
            handle.truncateSync(tailStart);
          }
          return;
        }
        end = start;
      }

      handle.setPositionSync(0);
      final tail = handle.readSync(length);
      if (_isCompleteJsonLine(tail)) {
        handle.setPositionSync(length);
        handle.writeByteSync(0x0a);
      } else {
        handle.truncateSync(0);
      }
    } finally {
      handle.closeSync();
    }
  }

  bool _isCompleteJsonLine(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    try {
      jsonDecode(utf8.decode(bytes));
      return true;
    } on FormatException {
      return false;
    }
  }
}
