import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync_data_adapter.dart';
import 'package:nai_launcher/data/cloud_sync/portable_sync_record.dart';
import 'package:nai_launcher/data/cloud_sync/strict_hive_cloud_sync_adapter.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late StrictHiveCloudSyncAdapter adapter;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('strict-hive-sync-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('strict_models');
    adapter = StrictHiveCloudSyncAdapter(
      id: 'strict-models',
      boxName: 'strict_models',
      allowedKeys: const {'first', 'second'},
      valueNormalizer: _normalizeModel,
      modelIdOf: (_, value) => (value as Map<String, Object?>)['id'] as String?,
    );
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('rejects arbitrary local and remote keys', () async {
    await box.put('arbitrary', {'id': 'arbitrary', 'name': 'unsafe'});

    await expectLater(
      adapter.exportRecords().toList(),
      throwsA(isA<CloudSyncPreflightException>()),
    );
    await expectLater(
      adapter.preflight([_record('arbitrary')]),
      throwsA(isA<CloudSyncPreflightException>()),
    );
  });

  test('rejects remote fields discarded by the normalizer', () async {
    final record = _record(
      'first',
      value: const {'id': 'first', 'name': 'one', 'futureField': true},
    );

    await expectLater(
      adapter.preflight([record]),
      throwsA(isA<CloudSyncPreflightException>()),
    );
  });

  test('rejects secret-looking fields recursively', () async {
    final record = _record(
      'first',
      value: const {
        'id': 'first',
        'name': 'one',
        'metadata': {'apiToken': 'secret'},
      },
    );

    await expectLater(
      adapter.preflight([record]),
      throwsA(isA<CloudSyncPreflightException>()),
    );
  });

  test('rejects a model whose identity differs from its Hive key', () async {
    await expectLater(
      adapter.preflight([
        _record('first', value: const {'id': 'second', 'name': 'wrong model'}),
      ]),
      throwsA(isA<CloudSyncPreflightException>()),
    );
  });

  test('validates tombstone keys before deleting', () async {
    await box.put('first', {'id': 'first', 'name': 'one'});
    final valid = PortableSyncRecord(
      adapterId: 'strict-models',
      id: 'first',
      kind: 'item',
      deleted: true,
    );
    final invalid = PortableSyncRecord(
      adapterId: 'strict-models',
      id: 'outside',
      kind: 'item',
      deleted: true,
    );

    await expectLater(
      adapter.apply([invalid]),
      throwsA(isA<CloudSyncPreflightException>()),
    );
    expect(box.containsKey('first'), isTrue);
    await adapter.apply([valid]);
    expect(box.containsKey('first'), isFalse);
  });

  test('round-trips Map and JSON String storage values', () async {
    await box.put('first', {'id': 'first', 'name': 'map'});
    await box.put('second', '{"id":"second","name":"json"}');

    final records = await adapter.exportRecords().toList();
    await box.clear();
    await adapter.apply(records);

    expect(box.get('first'), {'id': 'first', 'name': 'map'});
    expect(box.get('second'), isA<String>());
    expect(box.get('second'), '{"id":"second","name":"json"}');
  });

  test('round-trips a pre-opened Box<String> and reopens it typed', () async {
    final stringBox = await Hive.openBox<String>('typed_models');
    await stringBox.put('first', '{"id":"first","name":"typed"}');
    final typedAdapter = StrictHiveCloudSyncAdapter(
      id: 'strict-models',
      boxName: 'typed_models',
      allowedKeys: const {'first'},
      valueNormalizer: _normalizeModel,
      modelIdOf: (_, value) => (value as Map<String, Object?>)['id'] as String?,
      typedStringBox: true,
    );

    final records = await typedAdapter.exportRecords().toList();
    await stringBox.clear();
    await stringBox.close();
    await typedAdapter.apply(records);

    final reopened = Hive.box<String>('typed_models');
    expect(reopened.get('first'), '{"id":"first","name":"typed"}');
  });

  test('preserves explicitly allowed plain strings in a typed box', () async {
    final stringBox = await Hive.openBox<String>('mixed_string_models');
    await stringBox.put('selected', 'first');
    await stringBox.put('first', '{"id":"first","name":"typed"}');
    final typedAdapter = StrictHiveCloudSyncAdapter(
      id: 'strict-models',
      boxName: 'mixed_string_models',
      allowedKeys: const {'selected', 'first'},
      valueNormalizer: (key, value) =>
          key == 'selected' ? value : _normalizeModel(key, value),
      modelIdOf: (key, value) => key == 'selected'
          ? key
          : (value as Map<String, Object?>)['id'] as String?,
      typedStringBox: true,
      plainStringKeys: const {'selected'},
    );

    final records = await typedAdapter.exportRecords().toList();
    await stringBox.clear();
    await typedAdapter.apply(records);

    expect(stringBox.get('selected'), 'first');
    expect(stringBox.get('first'), '{"id":"first","name":"typed"}');
  });
}

PortableSyncRecord _record(String key, {Map<String, Object?>? value}) =>
    PortableSyncRecord(
      adapterId: 'strict-models',
      id: key,
      kind: 'item',
      data: {
        'value': value ?? {'id': key, 'name': key},
        'storage': 'map',
      },
    );

Object? _normalizeModel(String key, Object? value) {
  final map = Map<String, Object?>.from(value! as Map);
  return <String, Object?>{'id': map['id'], 'name': map['name']};
}
