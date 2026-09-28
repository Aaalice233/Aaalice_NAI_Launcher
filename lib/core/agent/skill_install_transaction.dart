import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class SkillInstallTransactionManager {
  const SkillInstallTransactionManager({this.maxNames = 500});

  final int maxNames;

  Future<void> writeJournal({
    required Directory transaction,
    required Iterable<String> names,
    required Iterable<String> backedUpNames,
  }) => File(p.join(transaction.path, 'transaction.json')).writeAsString(
    jsonEncode({
      'names': names.toList(),
      'backedUpNames': backedUpNames.toList(),
    }),
    flush: true,
  );

  Future<void> markCommitted(Directory transaction) => File(
    p.join(transaction.path, 'committed'),
  ).writeAsString('committed', flush: true);

  Future<void> recoverInterruptedInstalls(Directory targetDirectory) async {
    if (!await targetDirectory.exists()) return;
    await for (final entity in targetDirectory.list(followLinks: false)) {
      if (!p.basename(entity.path).startsWith('.skill-import-')) continue;
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const FormatException(
          'Skill import transaction must be a regular directory.',
        );
      }
      await recoverTransaction(Directory(entity.path), targetDirectory);
    }
  }

  Future<void> recoverTransaction(
    Directory transaction,
    Directory targetDirectory,
  ) async {
    if (!await transaction.exists()) return;
    await _validateTransactionRoot(transaction, targetDirectory);
    await _rejectLinks(transaction);
    final committedPath = p.join(transaction.path, 'committed');
    final committedType = await FileSystemEntity.type(
      committedPath,
      followLinks: false,
    );
    if (committedType == FileSystemEntityType.link) {
      throw const FormatException('Invalid Skill import commit marker.');
    }
    if (committedType == FileSystemEntityType.file) {
      await transaction.delete(recursive: true);
      return;
    }
    if (committedType != FileSystemEntityType.notFound) {
      throw const FormatException('Invalid Skill import commit marker.');
    }
    final journal = File(p.join(transaction.path, 'transaction.json'));
    final journalType = await FileSystemEntity.type(
      journal.path,
      followLinks: false,
    );
    if (journalType == FileSystemEntityType.notFound) {
      await transaction.delete(recursive: true);
      return;
    }
    if (journalType != FileSystemEntityType.file) {
      throw const FormatException('Invalid Skill import transaction journal.');
    }
    final decoded = jsonDecode(await journal.readAsString());
    if (decoded is! Map ||
        decoded.keys.any((key) => key != 'names' && key != 'backedUpNames') ||
        decoded['names'] is! List ||
        decoded['backedUpNames'] is! List) {
      throw const FormatException('Invalid Skill import transaction.');
    }
    final names = _validatedNames(decoded['names'] as List);
    final backedUpNames = _validatedNames(
      decoded['backedUpNames'] as List,
    ).toSet();
    if (!names.toSet().containsAll(backedUpNames)) {
      throw const FormatException('Invalid Skill import transaction names.');
    }
    final backups = Directory(p.join(transaction.path, 'backups'));
    final backupsType = await FileSystemEntity.type(
      backups.path,
      followLinks: false,
    );
    if (backupsType != FileSystemEntityType.directory) {
      throw const FormatException('Invalid Skill import backup directory.');
    }
    final backupEntities = <String, FileSystemEntityType>{};
    await for (final entity in backups.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!backedUpNames.contains(name)) {
        throw const FormatException('Unexpected Skill import backup.');
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.directory) {
        throw const FormatException('Invalid Skill import backup entity.');
      }
      backupEntities[name] = type;
    }
    for (final name in backedUpNames) {
      if (backupEntities.containsKey(name)) continue;
      final destinationType = await FileSystemEntity.type(
        p.join(targetDirectory.path, name),
        followLinks: false,
      );
      if (destinationType != FileSystemEntityType.file &&
          destinationType != FileSystemEntityType.directory) {
        throw const FileSystemException(
          'Skill backup and original are both missing or unsafe.',
        );
      }
    }
    for (final name in names.reversed) {
      final destinationPath = p.join(targetDirectory.path, name);
      final backupPath = p.join(transaction.path, 'backups', name);
      if (backedUpNames.contains(name)) {
        if (!backupEntities.containsKey(name)) continue;
        await deleteEntityIfPresent(destinationPath);
        await renameEntity(backupPath, destinationPath);
      } else {
        await deleteEntityIfPresent(destinationPath);
      }
    }
    await transaction.delete(recursive: true);
  }

  Future<void> _validateTransactionRoot(
    Directory transaction,
    Directory targetDirectory,
  ) async {
    if (await FileSystemEntity.type(transaction.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FormatException(
        'Skill import transaction must be a regular directory.',
      );
    }
    final targetRoot = await targetDirectory.resolveSymbolicLinks();
    final transactionRoot = await transaction.resolveSymbolicLinks();
    if (p.dirname(p.normalize(p.absolute(transaction.path))) !=
            p.normalize(p.absolute(targetDirectory.path)) ||
        !p.isWithin(targetRoot, transactionRoot)) {
      throw const FormatException('Skill import transaction escapes target.');
    }
  }

  Future<void> _rejectLinks(Directory transaction) async {
    await for (final entity in transaction.list(
      recursive: true,
      followLinks: false,
    )) {
      if (await FileSystemEntity.type(entity.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FormatException(
          'Symbolic links are not allowed in Skill import transactions.',
        );
      }
    }
  }

  List<String> _validatedNames(List<Object?> values) {
    final names = <String>[];
    for (final value in values) {
      if (value is! String ||
          !RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$').hasMatch(value) ||
          value.contains('--')) {
        throw const FormatException('Invalid Skill import transaction name.');
      }
      names.add(value);
    }
    if (names.length != names.toSet().length || names.length > maxNames) {
      throw const FormatException('Invalid Skill import transaction names.');
    }
    return names;
  }

  Future<void> renameEntity(String source, String destination) async {
    final type = await FileSystemEntity.type(source, followLinks: false);
    switch (type) {
      case FileSystemEntityType.directory:
        await Directory(source).rename(destination);
        return;
      case FileSystemEntityType.file:
        await File(source).rename(destination);
        return;
      case FileSystemEntityType.link:
        throw FileSystemException(
          'Symbolic links cannot be moved by Skill transactions.',
          source,
        );
      case FileSystemEntityType.notFound:
        throw FileSystemException(
          'Import transaction entity is missing.',
          source,
        );
      default:
        throw FileSystemException(
          'Unsupported import transaction entity.',
          source,
        );
    }
  }

  Future<void> deleteEntityIfPresent(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
        return;
      case FileSystemEntityType.file:
        await File(path).delete();
        return;
      case FileSystemEntityType.link:
        await Link(path).delete();
        return;
      case FileSystemEntityType.notFound:
        return;
      default:
        throw FileSystemException(
          'Unsupported import transaction entity.',
          path,
        );
    }
  }
}
