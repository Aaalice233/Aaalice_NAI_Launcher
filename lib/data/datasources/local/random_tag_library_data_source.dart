import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/asset_database_manager.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/prompt/weighted_tag.dart';

part 'random_tag_library_data_source.g.dart';

const _randomTagLibraryAsset = 'assets/data/random_tag_library.json';
const _supportedRandomTagLibrarySchema = 1;
const _generalCatalogCategories = [0, 7, 8, 9, 10, 11, 12, 14, 15];

class RandomTagLibrarySource {
  const RandomTagLibrarySource({
    required this.name,
    required this.url,
    required this.commit,
    required this.versionDate,
    required this.sha256,
    required this.license,
    required this.catalogTagCount,
    required this.catalogAliasCount,
  });

  final String name;
  final String url;
  final String commit;
  final DateTime versionDate;
  final String sha256;
  final String license;
  final int catalogTagCount;
  final int catalogAliasCount;
}

class RandomTagCategoryRule {
  const RandomTagCategoryRule({
    this.includeGlobs = const [],
    this.includeExact = const [],
    this.includeTokens = const [],
    this.excludeTokens = const [],
  });

  final List<String> includeGlobs;
  final List<String> includeExact;
  final List<String> includeTokens;
  final List<String> excludeTokens;

  bool get isEmpty => includeGlobs.isEmpty && includeExact.isEmpty;
}

class RandomTagLibraryManifest {
  const RandomTagLibraryManifest({
    required this.schemaVersion,
    required this.dataVersion,
    required this.source,
    required this.categories,
  });

  final int schemaVersion;
  final String dataVersion;
  final RandomTagLibrarySource source;
  final Map<String, RandomTagCategoryRule> categories;

  factory RandomTagLibraryManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != _supportedRandomTagLibrarySchema) {
      throw FormatException(
        'Unsupported random tag library schema: $schemaVersion',
      );
    }
    final sourceJson = _requiredMap(json, 'source');
    final categoryJson = _requiredMap(json, 'categories');
    if (categoryJson.isEmpty) {
      throw const FormatException('Random tag library has no categories');
    }

    final categories = <String, RandomTagCategoryRule>{};
    for (final entry in categoryJson.entries) {
      final ruleJson = Map<String, dynamic>.from(entry.value as Map);
      final rule = RandomTagCategoryRule(
        includeGlobs: _stringList(ruleJson, 'includeGlobs'),
        includeExact: _stringList(ruleJson, 'includeExact'),
        includeTokens: _stringList(ruleJson, 'includeTokens'),
        excludeTokens: _stringList(ruleJson, 'excludeTokens'),
      );
      if (rule.isEmpty) {
        throw FormatException('Random tag category ${entry.key} is empty');
      }
      categories[entry.key] = rule;
    }

    return RandomTagLibraryManifest(
      schemaVersion: schemaVersion,
      dataVersion: _requiredString(json, 'dataVersion'),
      source: RandomTagLibrarySource(
        name: _requiredString(sourceJson, 'name'),
        url: _requiredString(sourceJson, 'url'),
        commit: _requiredString(sourceJson, 'commit'),
        versionDate: DateTime.parse(_requiredString(sourceJson, 'versionDate')),
        sha256: _requiredString(sourceJson, 'sha256'),
        license: _requiredString(sourceJson, 'license'),
        catalogTagCount: _requiredInt(sourceJson, 'catalogTagCount'),
        catalogAliasCount: _requiredInt(sourceJson, 'catalogAliasCount'),
      ),
      categories: Map.unmodifiable(categories),
    );
  }
}

class RandomTagLibraryLoadCancelled implements Exception {
  const RandomTagLibraryLoadCancelled();

  @override
  String toString() => 'Random tag library load cancelled';
}

class RandomTagLibraryData {
  const RandomTagLibraryData({
    required this.manifest,
    required this.categories,
  });

  final RandomTagLibraryManifest manifest;
  final Map<String, List<WeightedTag>> categories;

  int get totalTagCount =>
      categories.values.fold(0, (total, tags) => total + tags.length);
}

/// Loads a deterministic semantic index over the complete bundled tag catalog.
///
/// The taxonomy asset contains matching rules only. Candidate rows always come
/// from the catalog whose provenance, hash and complete counts are validated
/// before any random tags are exposed.
class RandomTagLibraryDataSource {
  RandomTagLibraryDataSource({
    AssetBundle? assetBundle,
    Future<Database> Function()? openDatabase,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _openDatabase =
           openDatabase ?? AssetDatabaseManager.instance.openTagCatalogDatabase;

  final AssetBundle _assetBundle;
  final Future<Database> Function() _openDatabase;
  RandomTagLibraryData? _cache;
  Future<RandomTagLibraryData>? _loading;
  int _generation = 0;

  Future<RandomTagLibraryData> loadData() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    final activeLoad = _loading;
    if (activeLoad != null) return activeLoad;

    final generation = _generation;
    late final Future<RandomTagLibraryData> load;
    load = _load(generation).whenComplete(() {
      if (identical(_loading, load)) _loading = null;
    });
    _loading = load;
    return load;
  }

  Future<RandomTagLibraryData> _load(int generation) async {
    final rawManifest = await _assetBundle.loadString(_randomTagLibraryAsset);
    final manifest = RandomTagLibraryManifest.fromJson(
      Map<String, dynamic>.from(jsonDecode(rawManifest) as Map),
    );
    final database = await _openDatabase();
    try {
      _throwIfStale(generation);
      await _validateCatalog(database, manifest);
      _throwIfStale(generation);
      final categories = <String, List<WeightedTag>>{};
      for (final entry in manifest.categories.entries) {
        categories[entry.key] = await _loadCategory(database, entry.value);
        _throwIfStale(generation);
      }
      final data = RandomTagLibraryData(
        manifest: manifest,
        categories: Map.unmodifiable(categories),
      );
      if (data.totalTagCount == 0) {
        throw StateError('Random tag library resolved no catalog tags');
      }
      if (generation == _generation) _cache = data;
      AppLogger.i(
        'Loaded ${data.totalTagCount} random tags from verified catalog ${manifest.dataVersion}',
        'RandomTagLibrary',
      );
      return data;
    } finally {
      await database.close();
    }
  }

  Future<void> _validateCatalog(
    Database database,
    RandomTagLibraryManifest manifest,
  ) async {
    final rows = await database.rawQuery('SELECT key, value FROM metadata');
    final metadata = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    final checks = <String, String>{
      'data_version': manifest.dataVersion,
      'source_commit': manifest.source.commit,
      'source_sha256': manifest.source.sha256,
      'tag_count': '${manifest.source.catalogTagCount}',
      'alias_count': '${manifest.source.catalogAliasCount}',
    };
    for (final check in checks.entries) {
      if (metadata[check.key] != check.value) {
        throw StateError(
          'Random tag catalog ${check.key} mismatch: '
          '${metadata[check.key]} != ${check.value}',
        );
      }
    }
  }

  Future<List<WeightedTag>> _loadCategory(
    Database database,
    RandomTagCategoryRule rule,
  ) async {
    final where = <String>[];
    final arguments = <Object?>[];

    final includes = <String>[];
    for (final glob in rule.includeGlobs) {
      includes.add('name GLOB ?');
      arguments.add(glob);
    }
    for (final name in rule.includeExact) {
      includes.add('name = ?');
      arguments.add(name);
    }
    where.add('(${includes.join(' OR ')})');

    if (rule.includeTokens.isNotEmpty) {
      where.add(_tokenClause(rule.includeTokens, arguments, negate: false));
    }
    if (rule.excludeTokens.isNotEmpty) {
      where.add(_tokenClause(rule.excludeTokens, arguments, negate: true));
    }

    final categoryPlaceholders = List.filled(
      _generalCatalogCategories.length,
      '?',
    ).join(',');
    arguments.addAll(_generalCatalogCategories);
    final rows = await database.rawQuery(
      'SELECT name, post_count FROM tags '
      'WHERE ${where.join(' AND ')} '
      'AND category IN ($categoryPlaceholders) '
      'ORDER BY post_count DESC, name ASC',
      arguments,
    );

    return List.unmodifiable(
      rows.map((row) {
        final postCount = (row['post_count'] as num).toInt();
        return WeightedTag(
          tag: (row['name'] as String).replaceAll('_', ' '),
          weight: _weightForPostCount(postCount),
          source: TagSource.catalog,
        );
      }),
    );
  }

  String _tokenClause(
    List<String> tokens,
    List<Object?> arguments, {
    required bool negate,
  }) {
    final clauses = <String>[];
    for (final token in tokens) {
      clauses.add('(name = ? OR name GLOB ? OR name GLOB ? OR name GLOB ?)');
      arguments.addAll([token, '${token}_*', '*_$token', '*_${token}_*']);
    }
    final expression = '(${clauses.join(' OR ')})';
    return negate ? 'NOT $expression' : expression;
  }

  int _weightForPostCount(int postCount) {
    if (postCount <= 0) return 1;
    return (log(postCount + 1) / ln10 * 10).round().clamp(1, 100);
  }

  void _throwIfStale(int generation) {
    if (generation != _generation) {
      throw const RandomTagLibraryLoadCancelled();
    }
  }

  void clearCache() {
    _generation++;
    _cache = null;
    _loading = null;
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing non-empty string: $key');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('Missing integer: $key');
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('Missing object: $key');
  return Map<String, dynamic>.from(value);
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$key must be a string array');
  }
  final result = value.cast<String>().map((item) => item.trim()).toList();
  if (result.any((item) => item.isEmpty) ||
      result.toSet().length != result.length) {
    throw FormatException('$key contains empty or duplicate values');
  }
  return List.unmodifiable(result);
}

@Riverpod(keepAlive: true)
RandomTagLibraryDataSource randomTagLibraryDataSource(Ref ref) {
  return RandomTagLibraryDataSource();
}

@Riverpod(keepAlive: true)
Future<RandomTagLibraryData> randomTagLibraryData(Ref ref) {
  return ref.watch(randomTagLibraryDataSourceProvider).loadData();
}
