import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'private_data_guard.dart';
import 'skill_catalog.dart';
import 'skill_install_transaction.dart';

const _transactionManager = SkillInstallTransactionManager();

class SkillArchiveItem {
  const SkillArchiveItem({
    required this.name,
    required this.description,
    required this.fileCount,
    required this.totalBytes,
    required this.conflicts,
  });

  final String name;
  final String description;
  final int fileCount;
  final int totalBytes;
  final bool conflicts;
}

class SkillArchivePreview {
  const SkillArchivePreview({required this.items});

  final List<SkillArchiveItem> items;
}

class SkillArchiveService {
  const SkillArchiveService({
    this.archiveBytesLimit = maxArchiveBytes,
    this.expandedBytesLimit = maxExpandedBytes,
    this.fileBytesLimit = maxFileBytes,
    this.fileCountLimit = maxFiles,
  });

  static const int maxArchiveBytes = 50 * 1024 * 1024;
  static const int maxExpandedBytes = 50 * 1024 * 1024;
  static const int maxFileBytes = 5 * 1024 * 1024;
  static const int maxFiles = 500;
  static const int maxPathDepth = 8;

  final int archiveBytesLimit;
  final int expandedBytesLimit;
  final int fileBytesLimit;
  final int fileCountLimit;

  Future<Uint8List> exportSkills(
    List<({String name, File manifest})> selectedSkills,
  ) async {
    if (selectedSkills.isEmpty) {
      throw const FormatException('Select at least one Skill to export.');
    }
    final files = <({String name, Uint8List bytes})>[];
    var totalBytes = 0;
    for (final selection in selectedSkills) {
      final skillName = selection.name;
      _validateSkillName(skillName);
      final skillFile = selection.manifest;
      final manifestType = await FileSystemEntity.type(
        skillFile.path,
        followLinks: false,
      );
      if (manifestType == FileSystemEntityType.link) {
        throw FormatException('$skillName/SKILL.md cannot be a symbolic link.');
      }
      if (manifestType != FileSystemEntityType.file) {
        throw FormatException('$skillName does not contain SKILL.md.');
      }
      if (p.basename(skillFile.path) != 'SKILL.md') {
        final parentRoot = await _canonicalExportRoot(skillFile.parent);
        final manifestBytes = await _readStableExportFile(
          skillFile.path,
          parentRoot,
        );
        _validateManifest(skillName, manifestBytes);
        totalBytes += manifestBytes.length;
        if (totalBytes > expandedBytesLimit || files.length >= fileCountLimit) {
          throw const FormatException('Selected Skills exceed archive limits.');
        }
        files.add((name: '$skillName/SKILL.md', bytes: manifestBytes));
        continue;
      }
      final directory = skillFile.parent;
      final canonicalRoot = await _canonicalExportRoot(directory);
      var foundManifest = false;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.link) {
          throw const FormatException(
            'Symbolic links cannot be exported from a Skill directory.',
          );
        }
        if (type != FileSystemEntityType.file) continue;
        final relative = p.relative(entity.path, from: directory.path);
        if (PrivateDataGuard.isSensitiveSkillPath(relative)) continue;
        final bytes = await _readStableExportFile(entity.path, canonicalRoot);
        if (bytes.length > fileBytesLimit) {
          throw FormatException('$relative exceeds the per-file size limit.');
        }
        PrivateDataGuard.rejectPrivateText(relative, bytes);
        if (relative == 'SKILL.md') {
          _validateManifest(skillName, bytes);
          foundManifest = true;
        }
        totalBytes += bytes.length;
        if (totalBytes > expandedBytesLimit || files.length >= fileCountLimit) {
          throw const FormatException('Selected Skills exceed archive limits.');
        }
        final archivePath = '$skillName/${relative.replaceAll('\\', '/')}';
        _validateEntryPath(archivePath);
        files.add((name: archivePath, bytes: Uint8List.fromList(bytes)));
      }
      if (!foundManifest) {
        throw FormatException('$skillName does not contain SKILL.md.');
      }
      if (await directory.resolveSymbolicLinks() != canonicalRoot) {
        throw const FileSystemException(
          'Skill directory changed while it was being exported.',
        );
      }
    }
    files.sort((a, b) => a.name.compareTo(b.name));
    final archive = Archive();
    for (final file in files) {
      final entry = ArchiveFile(file.name, file.bytes.length, file.bytes)
        ..lastModTime = 0
        ..mode = 420;
      archive.addFile(entry);
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw const FormatException('Could not encode Skill archive.');
    }
    if (encoded.length > archiveBytesLimit) {
      throw const FormatException('Skill archive exceeds the size limit.');
    }
    return Uint8List.fromList(encoded);
  }

  Future<SkillArchivePreview> previewImport({
    required Uint8List bytes,
    required Directory targetDirectory,
  }) async {
    await recoverInterruptedInstalls(targetDirectory);
    final grouped = _decodeAndValidate(bytes);
    final items = <SkillArchiveItem>[];
    for (final entry in grouped.entries) {
      final skillFile = entry.value['SKILL.md'];
      if (skillFile == null) {
        throw FormatException('${entry.key} does not contain SKILL.md.');
      }
      final metadata = parseStrictSkillManifest(skillFile);
      if (metadata.name != entry.key) {
        throw FormatException(
          'Skill name "${metadata.name}" does not match folder "${entry.key}".',
        );
      }
      items.add(
        SkillArchiveItem(
          name: entry.key,
          description: metadata.description,
          fileCount: entry.value.length,
          totalBytes: entry.value.values.fold(
            0,
            (sum, file) => sum + file.length,
          ),
          conflicts:
              await FileSystemEntity.type(
                p.join(targetDirectory.path, entry.key),
                followLinks: false,
              ) !=
              FileSystemEntityType.notFound,
        ),
      );
    }
    items.sort((a, b) => a.name.compareTo(b.name));
    return SkillArchivePreview(items: items);
  }

  Future<void> install({
    required Uint8List bytes,
    required Directory targetDirectory,
    Set<String> replaceSkillNames = const {},
  }) async {
    await targetDirectory.create(recursive: true);
    await recoverInterruptedInstalls(targetDirectory);
    final grouped = _decodeAndValidate(bytes);
    final existingNames = <String>{};
    for (final name in grouped.keys) {
      final destinationPath = p.join(targetDirectory.path, name);
      final type = await FileSystemEntity.type(
        destinationPath,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) continue;
      if (type == FileSystemEntityType.link) {
        throw FormatException('Skill "$name" cannot replace a symbolic link.');
      }
      if (!replaceSkillNames.contains(name)) {
        throw FormatException('Skill "$name" already exists.');
      }
      existingNames.add(name);
    }
    final transaction = Directory(
      p.join(
        targetDirectory.path,
        '.skill-import-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    final staged = Directory(p.join(transaction.path, 'staged'));
    final backups = Directory(p.join(transaction.path, 'backups'));
    await staged.create(recursive: true);
    await backups.create(recursive: true);
    try {
      for (final group in grouped.entries) {
        final skillFile = group.value['SKILL.md'];
        if (skillFile == null) {
          throw const FormatException(
            'Skill archive does not contain SKILL.md.',
          );
        }
        final metadata = parseStrictSkillManifest(skillFile);
        if (metadata.name != group.key) {
          throw const FormatException(
            'Skill folder and metadata name do not match.',
          );
        }
        for (final file in group.value.entries) {
          final output = File(p.join(staged.path, group.key, file.key));
          await output.parent.create(recursive: true);
          await output.writeAsBytes(file.value, flush: true);
        }
      }

      await _transactionManager.writeJournal(
        transaction: transaction,
        names: grouped.keys,
        backedUpNames: existingNames,
      );
      for (final name in grouped.keys) {
        final destinationPath = p.join(targetDirectory.path, name);
        if (existingNames.contains(name)) {
          await _transactionManager.renameEntity(
            destinationPath,
            p.join(backups.path, name),
          );
        }
        await Directory(p.join(staged.path, name)).rename(destinationPath);
      }
      await _transactionManager.markCommitted(transaction);
      await transaction.delete(recursive: true);
    } catch (installError, installStack) {
      try {
        await _transactionManager.recoverTransaction(
          transaction,
          targetDirectory,
        );
      } catch (rollbackError, rollbackStack) {
        Error.throwWithStackTrace(
          StateError(
            'Skill installation failed: $installError\n'
            'Rollback also failed: $rollbackError\n'
            'Original installation stack:\n$installStack',
          ),
          rollbackStack,
        );
      }
      Error.throwWithStackTrace(installError, installStack);
    }
  }

  Future<void> recoverInterruptedInstalls(Directory targetDirectory) =>
      _transactionManager.recoverInterruptedInstalls(targetDirectory);

  Future<String> _canonicalExportRoot(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.directory) {
      throw const FormatException(
        'A Skill export directory cannot be a symbolic link.',
      );
    }
    final canonical = await directory.resolveSymbolicLinks();
    return canonical;
  }

  Future<Uint8List> _readStableExportFile(
    String filePath,
    String canonicalRoot,
  ) async {
    if (await FileSystemEntity.type(filePath, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Skill export files must be regular files.');
    }
    final canonicalFile = await File(filePath).resolveSymbolicLinks();
    if (!p.isWithin(canonicalRoot, canonicalFile)) {
      throw const FormatException('A Skill export file escapes its root.');
    }
    final handle = await File(canonicalFile).open();
    try {
      final length = await handle.length();
      if (length > fileBytesLimit) {
        throw const FormatException('A Skill file exceeds the size limit.');
      }
      final bytes = await handle.read(length);
      if (await FileSystemEntity.type(filePath, followLinks: false) !=
              FileSystemEntityType.file ||
          await File(filePath).resolveSymbolicLinks() != canonicalFile) {
        throw const FileSystemException(
          'Skill file changed while it was being exported.',
        );
      }
      return bytes;
    } finally {
      await handle.close();
    }
  }

  void _validateManifest(String skillName, Uint8List bytes) {
    if (bytes.length > fileBytesLimit) {
      throw FormatException('$skillName/SKILL.md exceeds the size limit.');
    }
    PrivateDataGuard.rejectPrivateText('$skillName/SKILL.md', bytes);
    final metadata = parseStrictSkillManifest(bytes);
    if (metadata.name != skillName) {
      throw FormatException(
        'Skill name "${metadata.name}" does not match "$skillName".',
      );
    }
  }

  Map<String, Map<String, Uint8List>> _decodeAndValidate(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > archiveBytesLimit) {
      throw const FormatException('Skill archive is empty or too large.');
    }
    _preflightZipHeaders(bytes);
    late Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (error) {
      throw FormatException('Invalid Skill ZIP: $error');
    }
    if (archive.files.isEmpty || archive.files.length > fileCountLimit) {
      throw const FormatException('Skill archive has an invalid file count.');
    }
    var expandedBytes = 0;
    final seen = <String>{};
    final grouped = <String, Map<String, Uint8List>>{};
    for (final file in archive.files) {
      if (file.isSymbolicLink) {
        throw FormatException('Symbolic links are not allowed: ${file.name}');
      }
      if (!file.isFile) continue;
      final normalized = _validateEntryPath(file.name);
      if (PrivateDataGuard.isSensitiveSkillPath(normalized)) {
        throw FormatException(
          'Sensitive files are not allowed in Skill archives: ${file.name}',
        );
      }
      if (!seen.add(normalized.toLowerCase())) {
        throw FormatException('Duplicate archive path: ${file.name}');
      }
      if (file.size > fileBytesLimit) {
        throw FormatException('${file.name} exceeds the per-file size limit.');
      }
      expandedBytes += file.size;
      if (expandedBytes > expandedBytesLimit) {
        throw const FormatException('Expanded Skill archive is too large.');
      }
      final segments = normalized.split('/');
      final skillName = segments.first;
      _validateSkillName(skillName);
      final relative = segments.skip(1).join('/');
      if (relative.isEmpty) {
        throw const FormatException(
          'Archive file must be inside a Skill folder.',
        );
      }
      final content = file.content;
      final data = content is Uint8List
          ? content
          : Uint8List.fromList(content as List<int>);
      PrivateDataGuard.rejectPrivateText(file.name, data);
      grouped.putIfAbsent(skillName, () => {})[relative] = data;
    }
    if (grouped.isEmpty) {
      throw const FormatException('Skill archive contains no files.');
    }
    return grouped;
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
    var expandedBytes = 0;
    for (var index = 0; index < entries; index++) {
      if (cursor + 46 > endOffset ||
          data.getUint32(cursor, Endian.little) != centralSignature) {
        throw const FormatException('Malformed ZIP central directory.');
      }
      final flags = data.getUint16(cursor + 8, Endian.little);
      final compressedSize = data.getUint32(cursor + 20, Endian.little);
      final expandedSize = data.getUint32(cursor + 24, Endian.little);
      final nameLength = data.getUint16(cursor + 28, Endian.little);
      final extraLength = data.getUint16(cursor + 30, Endian.little);
      final entryCommentLength = data.getUint16(cursor + 32, Endian.little);
      if ((flags & 1) != 0 ||
          compressedSize == 0xffffffff ||
          expandedSize == 0xffffffff ||
          expandedSize > fileBytesLimit) {
        throw const FormatException(
          'Encrypted, ZIP64, or oversized entries are not supported.',
        );
      }
      expandedBytes += expandedSize;
      if (expandedBytes > expandedBytesLimit) {
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

  static String _validateEntryPath(String input) {
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

  static void _validateSkillName(String name) {
    if (!RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$').hasMatch(name) ||
        name.contains('--')) {
      throw FormatException('Invalid Skill name: $name');
    }
  }
}
