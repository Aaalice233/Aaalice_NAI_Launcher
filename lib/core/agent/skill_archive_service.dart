import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'private_data_guard.dart';
import 'skill_archive_extractor.dart';
import 'skill_catalog.dart';
import 'skill_install_transaction.dart';

const _transactionManager = SkillInstallTransactionManager();

enum SkillConflictKind { none, directory, file, symbolicLink, other }

class SkillArchiveItem {
  const SkillArchiveItem({
    required this.name,
    required this.description,
    required this.fileCount,
    required this.totalBytes,
    required this.conflictKind,
  });

  final String name;
  final String description;
  final int fileCount;
  final int totalBytes;
  final SkillConflictKind conflictKind;

  bool get conflicts => conflictKind != SkillConflictKind.none;

  bool get canReplace => conflictKind == SkillConflictKind.directory;
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
        if (PrivateDataGuard.isSensitiveSkillPath(relative)) {
          throw FormatException(
            'Sensitive files cannot be exported: $skillName/$relative',
          );
        }
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
    bool recoverInterruptedTransactions = true,
  }) async {
    if (recoverInterruptedTransactions) {
      await recoverInterruptedInstalls(targetDirectory);
    }
    final temporary = await Directory.systemTemp.createTemp(
      'aaalice-skill-preview-',
    );
    try {
      final grouped = await _extract(bytes, temporary);
      final items = <SkillArchiveItem>[];
      for (final entry in grouped.entries) {
        final metadata = await _validateExtractedManifest(
          entry.key,
          entry.value,
        );
        final targetType = await FileSystemEntity.type(
          p.join(targetDirectory.path, entry.key),
          followLinks: false,
        );
        items.add(
          SkillArchiveItem(
            name: entry.key,
            description: metadata.description,
            fileCount: entry.value.files.length,
            totalBytes: entry.value.totalBytes,
            conflictKind: _conflictKind(targetType),
          ),
        );
      }
      items.sort((a, b) => a.name.compareTo(b.name));
      return SkillArchivePreview(items: items);
    } finally {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    }
  }

  Future<void> install({
    required Uint8List bytes,
    required Directory targetDirectory,
    Set<String> replaceSkillNames = const {},
  }) async {
    await targetDirectory.create(recursive: true);
    await recoverInterruptedInstalls(targetDirectory);
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
      final grouped = await _extract(bytes, staged);
      final existingNames = <String>{};
      for (final group in grouped.entries) {
        await _validateExtractedManifest(group.key, group.value);
        final destinationPath = p.join(targetDirectory.path, group.key);
        final type = await FileSystemEntity.type(
          destinationPath,
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound) continue;
        if (type != FileSystemEntityType.directory) {
          throw FormatException(
            'Skill "${group.key}" cannot replace a file, link, or special entity.',
          );
        }
        if (!replaceSkillNames.contains(group.key)) {
          throw FormatException('Skill "${group.key}" already exists.');
        }
        existingNames.add(group.key);
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

  static String _validateEntryPath(String input) {
    return validateSkillArchiveEntryPath(input, maxPathDepth: maxPathDepth);
  }

  static void _validateSkillName(String name) {
    validateSkillArchiveName(name);
  }

  Future<Map<String, ExtractedSkillGroup>> _extract(
    Uint8List bytes,
    Directory outputRoot,
  ) => SkillArchiveExtractor(
    archiveBytesLimit: archiveBytesLimit,
    expandedBytesLimit: expandedBytesLimit,
    fileBytesLimit: fileBytesLimit,
    fileCountLimit: fileCountLimit,
    maxPathDepth: maxPathDepth,
  ).extract(bytes: bytes, outputRoot: outputRoot);

  Future<SkillManifestMetadata> _validateExtractedManifest(
    String skillName,
    ExtractedSkillGroup group,
  ) async {
    final skillFile = group.files['SKILL.md'];
    if (skillFile == null) {
      throw FormatException('$skillName does not contain SKILL.md.');
    }
    final metadata = parseStrictSkillManifest(await skillFile.readAsBytes());
    if (metadata.name != skillName) {
      throw FormatException(
        'Skill name "${metadata.name}" does not match folder "$skillName".',
      );
    }
    return metadata;
  }

  SkillConflictKind _conflictKind(FileSystemEntityType type) => switch (type) {
    FileSystemEntityType.notFound => SkillConflictKind.none,
    FileSystemEntityType.directory => SkillConflictKind.directory,
    FileSystemEntityType.file => SkillConflictKind.file,
    FileSystemEntityType.link => SkillConflictKind.symbolicLink,
    _ => SkillConflictKind.other,
  };
}
