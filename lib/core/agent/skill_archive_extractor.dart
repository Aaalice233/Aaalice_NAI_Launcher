import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'private_data_guard.dart';

class ExtractedSkillGroup {
  const ExtractedSkillGroup({
    required this.directory,
    required this.files,
    required this.totalBytes,
  });

  final Directory directory;
  final Map<String, File> files;
  final int totalBytes;
}

class SkillArchiveExtractor {
  const SkillArchiveExtractor({
    required this.archiveBytesLimit,
    required this.expandedBytesLimit,
    required this.fileBytesLimit,
    required this.fileCountLimit,
    required this.maxPathDepth,
  });

  final int archiveBytesLimit;
  final int expandedBytesLimit;
  final int fileBytesLimit;
  final int fileCountLimit;
  final int maxPathDepth;

  Future<Map<String, ExtractedSkillGroup>> extract({
    required Uint8List bytes,
    required Directory outputRoot,
  }) async {
    if (bytes.isEmpty || bytes.length > archiveBytesLimit) {
      throw const FormatException('Skill archive is empty or too large.');
    }
    _preflightZipHeaders(bytes);
    late Archive archive;
    try {
      archive = ZipDecoder().decodeBuffer(InputStream(bytes));
    } catch (error) {
      throw FormatException('Invalid Skill ZIP: $error');
    }
    if (archive.files.isEmpty || archive.files.length > fileCountLimit) {
      throw const FormatException('Skill archive has an invalid file count.');
    }

    await outputRoot.create(recursive: true);
    final seen = <String>{};
    final filesBySkill = <String, Map<String, File>>{};
    final bytesBySkill = <String, int>{};
    var expandedBytes = 0;
    try {
      for (final entry in archive.files) {
        if (entry.isSymbolicLink) {
          throw FormatException(
            'Symbolic links are not allowed: ${entry.name}',
          );
        }
        final normalized = validateSkillArchiveEntryPath(
          entry.name,
          maxPathDepth: maxPathDepth,
        );
        if (PrivateDataGuard.isSensitiveSkillPath(normalized)) {
          throw FormatException(
            'Sensitive files are not allowed in Skill archives: ${entry.name}',
          );
        }
        final collisionKey = normalized.toLowerCase();
        if (!_registerArchivePath(seen, collisionKey, isFile: entry.isFile)) {
          throw FormatException('Colliding archive path: ${entry.name}');
        }
        if (!entry.isFile) continue;
        if (entry.size < 0 || entry.size > fileBytesLimit) {
          throw FormatException(
            '${entry.name} exceeds the per-file size limit.',
          );
        }
        final segments = normalized.split('/');
        final skillName = segments.first;
        validateSkillArchiveName(skillName);
        final relative = segments.skip(1).join('/');
        if (relative.isEmpty) {
          throw const FormatException(
            'Archive file must be inside a Skill folder.',
          );
        }
        final output = File(p.joinAll([outputRoot.path, ...segments]));
        await output.parent.create(recursive: true);
        final sink = _BoundedArchiveOutput(
          output.path,
          fileLimit: fileBytesLimit,
          reserveBytes: (count) {
            if (expandedBytes + count > expandedBytesLimit) {
              throw const FormatException(
                'Expanded Skill archive is too large.',
              );
            }
            expandedBytes += count;
          },
        );
        try {
          entry.clear();
          entry.decompress(sink);
          await sink.close();
        } on FormatException {
          await sink.close();
          rethrow;
        } catch (error) {
          await sink.close();
          throw FormatException(
            '${entry.name} has invalid compressed data: $error',
          );
        }
        if (sink.length != entry.size) {
          throw FormatException(
            '${entry.name} expanded to an unexpected size.',
          );
        }
        if (entry.crc32 != null && sink.crc32 != entry.crc32) {
          throw FormatException('${entry.name} failed CRC validation.');
        }
        final data = await output.readAsBytes();
        PrivateDataGuard.rejectPrivateText(entry.name, data);
        filesBySkill.putIfAbsent(skillName, () => {})[relative] = output;
        bytesBySkill[skillName] = (bytesBySkill[skillName] ?? 0) + sink.length;
      }
    } catch (_) {
      if (await outputRoot.exists()) await outputRoot.delete(recursive: true);
      rethrow;
    } finally {
      for (final entry in archive.files) {
        entry.closeSync();
      }
    }
    if (filesBySkill.isEmpty) {
      throw const FormatException('Skill archive contains no files.');
    }
    return {
      for (final group in filesBySkill.entries)
        group.key: ExtractedSkillGroup(
          directory: Directory(p.join(outputRoot.path, group.key)),
          files: Map.unmodifiable(group.value),
          totalBytes: bytesBySkill[group.key] ?? 0,
        ),
    };
  }

  bool _registerArchivePath(
    Set<String> seen,
    String path, {
    required bool isFile,
  }) {
    final encoded = '${isFile ? 'f' : 'd'}:$path';
    if (seen.any((entry) => entry.substring(2) == path)) return false;
    for (final entry in seen) {
      if (!entry.startsWith('f:')) continue;
      final existingFile = entry.substring(2);
      if (path.startsWith('$existingFile/') ||
          (isFile && existingFile.startsWith('$path/'))) {
        return false;
      }
    }
    seen.add(encoded);
    return true;
  }

  void _preflightZipHeaders(Uint8List bytes) {
    const endSignature = 0x06054b50;
    const centralSignature = 0x02014b50;
    if (bytes.length < 22) {
      throw const FormatException('Skill archive has no valid ZIP directory.');
    }
    final data = ByteData.sublistView(bytes);
    final searchStart = bytes.length - 22;
    final searchEnd = bytes.length > 65557 ? bytes.length - 65557 : 0;
    var endOffset = -1;
    for (var offset = searchStart; offset >= searchEnd; offset--) {
      if (data.getUint32(offset, Endian.little) == endSignature &&
          offset + 22 <= bytes.length &&
          offset + 22 + data.getUint16(offset + 20, Endian.little) ==
              bytes.length) {
        endOffset = offset;
        break;
      }
    }
    if (endOffset < 0 || endOffset + 22 > bytes.length) {
      throw const FormatException('Skill archive has no valid ZIP directory.');
    }
    final disk = data.getUint16(endOffset + 4, Endian.little);
    final centralDisk = data.getUint16(endOffset + 6, Endian.little);
    final diskEntries = data.getUint16(endOffset + 8, Endian.little);
    final entries = data.getUint16(endOffset + 10, Endian.little);
    final centralSize = data.getUint32(endOffset + 12, Endian.little);
    final centralOffset = data.getUint32(endOffset + 16, Endian.little);
    final commentLength = data.getUint16(endOffset + 20, Endian.little);
    if (disk != 0 ||
        centralDisk != 0 ||
        diskEntries != entries ||
        entries == 0 ||
        entries > fileCountLimit ||
        centralSize == 0xffffffff ||
        centralOffset == 0xffffffff ||
        endOffset + 22 + commentLength != bytes.length ||
        centralOffset + centralSize > endOffset) {
      throw const FormatException('Unsupported or malformed ZIP directory.');
    }

    var cursor = centralOffset;
    var declaredExpandedBytes = 0;
    for (var index = 0; index < entries; index++) {
      if (cursor + 46 > endOffset ||
          data.getUint32(cursor, Endian.little) != centralSignature) {
        throw const FormatException('Malformed ZIP central directory.');
      }
      final creator = data.getUint16(cursor + 4, Endian.little) >> 8;
      final flags = data.getUint16(cursor + 8, Endian.little);
      final compressedSize = data.getUint32(cursor + 20, Endian.little);
      final expandedSize = data.getUint32(cursor + 24, Endian.little);
      final nameLength = data.getUint16(cursor + 28, Endian.little);
      final extraLength = data.getUint16(cursor + 30, Endian.little);
      final entryCommentLength = data.getUint16(cursor + 32, Endian.little);
      final unixMode = data.getUint32(cursor + 38, Endian.little) >> 16;
      final isUnixLink = creator == 3 && (unixMode & 0xf000) == 0xa000;
      if ((flags & 1) != 0 ||
          isUnixLink ||
          compressedSize == 0xffffffff ||
          expandedSize == 0xffffffff ||
          expandedSize > fileBytesLimit) {
        throw const FormatException(
          'Encrypted, linked, ZIP64, or oversized entries are not supported.',
        );
      }
      declaredExpandedBytes += expandedSize;
      if (declaredExpandedBytes > expandedBytesLimit) {
        throw const FormatException('Expanded Skill archive is too large.');
      }
      cursor += 46 + nameLength + extraLength + entryCommentLength;
      if (cursor > centralOffset + centralSize) {
        throw const FormatException('Malformed ZIP central directory.');
      }
    }
    if (cursor != centralOffset + centralSize) {
      throw const FormatException('Malformed ZIP central directory size.');
    }
  }
}

String validateSkillArchiveEntryPath(
  String input, {
  required int maxPathDepth,
}) {
  if (input.isEmpty || input.contains('\u0000')) {
    throw const FormatException('Archive contains an invalid path.');
  }
  final value = input.replaceAll('\\', '/');
  if (value.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(value)) {
    throw FormatException('Absolute archive paths are not allowed: $input');
  }
  final segments = value.split('/');
  if (segments.length > maxPathDepth ||
      segments.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw FormatException('Unsafe or overly nested archive path: $input');
  }
  return segments.join('/');
}

void validateSkillArchiveName(String name) {
  if (!RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$').hasMatch(name) ||
      name.contains('--')) {
    throw FormatException('Invalid Skill name: $name');
  }
}

class _BoundedArchiveOutput extends OutputStreamBase {
  _BoundedArchiveOutput(
    String path, {
    required this.fileLimit,
    required this.reserveBytes,
  }) : _output = OutputFileStream(path, bufferSize: 64 * 1024);

  final int fileLimit;
  final void Function(int count) reserveBytes;
  final OutputFileStream _output;
  final Crc32 _crc = Crc32();
  final Uint8List _history = Uint8List(32 * 1024);
  var _historyCursor = 0;
  var _historyLength = 0;
  var _length = 0;

  int get crc32 => _crc.hash;

  @override
  int get length => _length;

  void _write(List<int> bytes, [int? length]) {
    final count = length ?? bytes.length;
    if (_length + count > fileLimit) {
      throw const FormatException('A Skill file expanded past its size limit.');
    }
    reserveBytes(count);
    final data = count == bytes.length ? bytes : bytes.sublist(0, count);
    _crc.add(data);
    _output.writeBytes(data);
    for (final byte in data) {
      _history[_historyCursor] = byte;
      _historyCursor = (_historyCursor + 1) % _history.length;
      if (_historyLength < _history.length) _historyLength++;
    }
    _length += count;
  }

  List<int> subset(int start, [int? end]) {
    final absoluteStart = start < 0 ? _length + start : start;
    final absoluteEnd = end == null
        ? _length
        : end < 0
        ? _length + end
        : end;
    final historyStart = _length - _historyLength;
    if (absoluteStart < historyStart ||
        absoluteEnd < absoluteStart ||
        absoluteEnd > _length) {
      throw const FormatException('Invalid ZIP back-reference.');
    }
    return [
      for (var index = absoluteStart; index < absoluteEnd; index++)
        _history[(_historyCursor - _historyLength + index - historyStart) %
            _history.length],
    ];
  }

  Future<void> close() => _output.close();

  @override
  void flush() => _output.flush();

  @override
  void writeByte(int value) => _write([value]);

  @override
  void writeBytes(List<int> bytes, [int? len]) => _write(bytes, len);

  @override
  void writeInputStream(InputStreamBase stream) {
    while (!stream.isEOS) {
      final chunk = stream.readBytes(stream.length.clamp(1, 64 * 1024));
      _write(chunk.toUint8List());
    }
  }

  @override
  void writeUint16(int value) => _write([value & 0xff, (value >> 8) & 0xff]);

  @override
  void writeUint32(int value) => _write([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);

  @override
  void writeUint64(int value) => _write([
    for (var shift = 0; shift < 64; shift += 8) (value >> shift) & 0xff,
  ]);
}
