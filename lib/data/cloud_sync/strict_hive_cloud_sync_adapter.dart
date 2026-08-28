import 'dart:convert';

import 'package:hive/hive.dart';

import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

typedef StrictHiveAllowedKey = bool Function(String key);
typedef StrictHiveValueNormalizer = Object? Function(String key, Object? value);
typedef StrictHiveModelId = String? Function(String key, Object? value);

/// A Hive adapter whose portable keys and model shape are explicit.
///
/// The normalizer must return the complete canonical JSON value. Remote input
/// is accepted only when it is structurally identical to that result, so a
/// decoder cannot silently discard fields introduced by an incompatible peer.
class StrictHiveCloudSyncAdapter extends ValidatingCloudSyncDataAdapter {
  StrictHiveCloudSyncAdapter({
    required this.id,
    required this.boxName,
    Set<String>? allowedKeys,
    StrictHiveAllowedKey? allowedKeyPredicate,
    required StrictHiveValueNormalizer valueNormalizer,
    required StrictHiveModelId modelIdOf,
    this.typedStringBox = false,
    Set<String> plainStringKeys = const {},
  }) : _allowedKey = _resolveAllowedKey(allowedKeys, allowedKeyPredicate),
       _valueNormalizer = valueNormalizer,
       _modelIdOf = modelIdOf,
       _plainStringKeys = Set<String>.unmodifiable(plainStringKeys);

  @override
  final String id;
  final String boxName;
  final StrictHiveAllowedKey _allowedKey;
  final StrictHiveValueNormalizer _valueNormalizer;
  final StrictHiveModelId _modelIdOf;
  final Set<String> _plainStringKeys;

  /// Opens and accesses [boxName] as `Box<String>`.
  ///
  /// Use this when the owning storage service opens the same box with that
  /// type. Typed boxes always persist the normalized value as JSON text.
  final bool typedStringBox;

  @override
  Set<String> get allowedKinds => const {'item'};

  static StrictHiveAllowedKey _resolveAllowedKey(
    Set<String>? allowedKeys,
    StrictHiveAllowedKey? predicate,
  ) {
    if ((allowedKeys == null) == (predicate == null)) {
      throw ArgumentError(
        'Provide exactly one of allowedKeys or allowedKeyPredicate',
      );
    }
    if (allowedKeys != null) {
      final immutableKeys = Set<String>.unmodifiable(allowedKeys);
      return immutableKeys.contains;
    }
    return predicate!;
  }

  Future<Box<dynamic>> _dynamicBox() async => Hive.isBoxOpen(boxName)
      ? Hive.box<dynamic>(boxName)
      : Hive.openBox<dynamic>(boxName);

  Future<Box<String>> _stringBox() async => Hive.isBoxOpen(boxName)
      ? Hive.box<String>(boxName)
      : Hive.openBox<String>(boxName);

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    if (typedStringBox) {
      yield* _exportBox(await _stringBox());
    } else {
      yield* _exportBox(await _dynamicBox());
    }
  }

  Stream<PortableSyncRecord> _exportBox<T>(Box<T> box) async* {
    for (final hiveKey in box.keys) {
      final key = hiveKey.toString();
      _validateKey(key);
      final rawValue = box.get(hiveKey);
      if (rawValue == null) continue;

      final storedAsPlainString =
          rawValue is String && _plainStringKeys.contains(key);
      final storedAsJson = rawValue is String && !storedAsPlainString;
      final value = _decodeStoredValue(key, rawValue);
      ValidatingCloudSyncDataAdapter.rejectSecrets(<String, Object?>{
        'value': value,
      });
      final normalized = _normalize(key, value, requireUnchanged: true);
      final record = PortableSyncRecord(
        adapterId: id,
        id: key,
        kind: 'item',
        data: {
          'value': normalized,
          'storage': storedAsPlainString
              ? 'string'
              : storedAsJson
              ? 'json'
              : 'map',
        },
      );
      await preflight([record]);
      yield record;
    }
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    _validateKey(record.id);
    if (record.resource != null) {
      throw const CloudSyncPreflightException(
        'Hive records cannot carry resources',
      );
    }
    if (record.deleted) {
      if (record.data.isNotEmpty) {
        throw const CloudSyncPreflightException(
          'Hive tombstone contains unknown fields',
        );
      }
      return;
    }

    if (record.data.length != 2 ||
        !record.data.containsKey('value') ||
        !record.data.containsKey('storage')) {
      throw const CloudSyncPreflightException(
        'Hive record contains unknown fields',
      );
    }
    final storage = record.data['storage'];
    if (storage != 'map' && storage != 'json' && storage != 'string') {
      throw const CloudSyncPreflightException('Invalid Hive storage format');
    }
    if ((storage == 'string') != _plainStringKeys.contains(record.id)) {
      throw const CloudSyncPreflightException(
        'Hive storage format does not match its explicit key contract',
      );
    }
    _normalize(record.id, record.data['value'], requireUnchanged: true);
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    await preflight(records);
    if (typedStringBox) {
      await _applyToStringBox(await _stringBox(), records);
    } else {
      await _applyToDynamicBox(await _dynamicBox(), records);
    }
  }

  Future<void> _applyToDynamicBox(
    Box<dynamic> box,
    List<PortableSyncRecord> records,
  ) async {
    for (final record in records) {
      if (record.deleted) {
        await box.delete(record.id);
        continue;
      }
      final value = _normalize(
        record.id,
        record.data['value'],
        requireUnchanged: true,
      );
      await box.put(
        record.id,
        record.data['storage'] == 'string'
            ? value
            : record.data['storage'] == 'json'
            ? jsonEncode(value)
            : value,
      );
    }
  }

  Future<void> _applyToStringBox(
    Box<String> box,
    List<PortableSyncRecord> records,
  ) async {
    for (final record in records) {
      if (record.deleted) {
        await box.delete(record.id);
        continue;
      }
      final value = _normalize(
        record.id,
        record.data['value'],
        requireUnchanged: true,
      );
      await box.put(
        record.id,
        record.data['storage'] == 'string'
            ? value as String
            : jsonEncode(value),
      );
    }
  }

  void _validateKey(String key) {
    if (!_allowedKey(key)) {
      throw CloudSyncPreflightException('Hive key is not portable: $key');
    }
  }

  Object? _decodeStoredValue(String key, Object value) {
    if (value is Map) return _jsonValue(value);
    if (value is String) {
      if (_plainStringKeys.contains(key)) return value;
      try {
        return _jsonValue(jsonDecode(value));
      } on FormatException catch (error) {
        throw CloudSyncPreflightException('Invalid stored JSON: $error');
      }
    }
    throw const CloudSyncPreflightException(
      'Portable Hive values must be a Map or JSON String',
    );
  }

  Object? _normalize(
    String key,
    Object? value, {
    required bool requireUnchanged,
  }) {
    final jsonValue = _jsonValue(value);
    late final Object? normalized;
    try {
      normalized = _jsonValue(_valueNormalizer(key, jsonValue));
    } on CloudSyncPreflightException {
      rethrow;
    } catch (error) {
      throw CloudSyncPreflightException('Invalid Hive model: $error');
    }
    ValidatingCloudSyncDataAdapter.rejectSecrets(<String, Object?>{
      'value': normalized,
    });
    late final String? modelId;
    try {
      modelId = _modelIdOf(key, normalized);
    } catch (error) {
      throw CloudSyncPreflightException('Invalid Hive model identity: $error');
    }
    if (modelId != key) {
      throw CloudSyncPreflightException(
        'Hive model identity differs from $key',
      );
    }
    if (requireUnchanged && !_deepEquals(jsonValue, normalized)) {
      throw const CloudSyncPreflightException(
        'Hive model contains unknown or non-canonical fields',
      );
    }
    return normalized;
  }

  Object? _jsonValue(Object? value) {
    try {
      return jsonDecode(jsonEncode(value)) as Object?;
    } catch (error) {
      throw CloudSyncPreflightException('Hive value is not JSON-safe: $error');
    }
  }

  bool _deepEquals(Object? left, Object? right) {
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final entry in left.entries) {
        if (!right.containsKey(entry.key) ||
            !_deepEquals(entry.value, right[entry.key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_deepEquals(left[index], right[index])) return false;
      }
      return true;
    }
    return left == right;
  }
}
