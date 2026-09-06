import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart' hide ZLibDecoder;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const dlssRuntimeFiles = {
  'nvngx_dlssnr.dll',
  'nvngx_dlss.dll',
  'nvngx.dll_dlssnr.dll',
  'video2dlssnr.exe',
};

Future<Map<String, String>> extractDlssRuntimeIsolated(
  String zipPath,
  String destination,
  int expectedBytes,
  String expectedHash,
) => Isolate.run(
  () => extractDlssRuntime(zipPath, destination, expectedBytes, expectedHash),
);

/// Runs in an isolate: only allowlisted basenames ever become output paths.
Future<Map<String, String>> extractDlssRuntime(
  String zipPath,
  String destination,
  int expectedBytes,
  String expectedHash,
) async {
  final file = File(zipPath);
  if (await file.length() != expectedBytes ||
      (await sha256.bind(file.openRead()).first).toString() != expectedHash) {
    throw const FormatException('DLSS archive size or SHA-256 mismatch');
  }
  final input = InputFileStream(zipPath);
  Archive? archive;
  final hashes = <String, String>{};
  try {
    archive = ZipDecoder().decodeBuffer(input);
    for (final entry in archive.files) {
      final name = p.posix
          .basename(entry.name.replaceAll('\\', '/'))
          .toLowerCase();
      if (!dlssRuntimeFiles.contains(name)) continue;
      if (!entry.isFile || entry.isSymbolicLink || hashes.containsKey(name)) {
        throw FormatException(
          'Invalid or duplicate runtime entry: ${entry.name}',
        );
      }
      if (entry.size < 64 || entry.size > 512 * 1024 * 1024) {
        throw FormatException('Invalid runtime entry size: ${entry.name}');
      }
      final target = File(p.join(destination, name));
      final raw = entry.rawContent!;
      Stream<List<int>> chunks() async* {
        while (!raw.isEOS) {
          final count = raw.length < 65536 ? raw.length : 65536;
          yield raw.readBytes(count).toUint8List();
        }
      }

      // Native zlib avoids the per-byte Dart inflater cost for large DLLs,
      // especially in debug builds. Stream both input and output to bound memory.
      final compressed = chunks();
      final Stream<List<int>> decoded;
      if (entry.compressionType == ArchiveFile.DEFLATE) {
        decoded = ZLibDecoder(raw: true).bind(compressed);
      } else if (entry.compressionType == ArchiveFile.STORE) {
        decoded = compressed;
      } else {
        throw FormatException('Unsupported ZIP compression: ${entry.name}');
      }
      await decoded.pipe(target.openWrite());
      if (await target.length() != entry.size) {
        throw FormatException('Incomplete runtime entry: ${entry.name}');
      }
      await validateDlssPe(target);
      hashes[name] = (await sha256.bind(target.openRead()).first).toString();
    }
    if (hashes.length != dlssRuntimeFiles.length) {
      throw FormatException(
        'Missing runtime files: ${dlssRuntimeFiles.difference(hashes.keys.toSet())}',
      );
    }
    return hashes;
  } finally {
    if (archive != null) {
      for (final entry in archive.files) {
        entry.closeSync();
      }
    }
    input.closeSync();
  }
}

Future<void> validateDlssPe(File file) async {
  final input = await file.open();
  try {
    final header = await input.read(64);
    if (header.length != 64 || header[0] != 0x4d || header[1] != 0x5a) {
      throw FormatException('Not a Windows executable: ${file.path}');
    }
    final offset =
        header[60] | header[61] << 8 | header[62] << 16 | header[63] << 24;
    if (offset < 64 || offset > await input.length() - 6) {
      throw FormatException('Invalid PE header: ${file.path}');
    }
    await input.setPosition(offset);
    final pe = await input.read(6);
    if (pe[0] != 0x50 ||
        pe[1] != 0x45 ||
        pe[2] != 0 ||
        pe[3] != 0 ||
        pe[4] != 0x64 ||
        pe[5] != 0x86) {
      throw FormatException('Runtime must be Windows x64: ${file.path}');
    }
  } finally {
    await input.close();
  }
}
