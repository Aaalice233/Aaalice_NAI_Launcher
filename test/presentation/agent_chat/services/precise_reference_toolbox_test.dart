import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/validate_tool_arguments.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/reference_library_toolbox.dart';
import 'package:path/path.dart' as p;

final _refProvider = Provider<Ref>((ref) => ref);

Uint8List _pngBytes() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(50, 60, 70));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PreciseRefLibraryStorageService storage;
  late ProviderContainer container;
  late List<AgentTool> tools;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'precise_reference_toolbox_test_',
    );
    Hive.init(p.join(tempDir.path, 'hive'));
    storage = PreciseRefLibraryStorageService(
      overrideDirectory: p.join(tempDir.path, 'images'),
    );
    container = ProviderContainer(
      overrides: [
        preciseRefLibraryStorageServiceProvider.overrideWithValue(storage),
      ],
    );
    final ref = container.read(_refProvider);
    tools = ReferenceLibraryToolbox(ref, AgentResourceResolver(ref)).tools();
  });

  tearDown(() async {
    container.dispose();
    await storage.close();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  AgentTool tool(String name) => tools.singleWhere((t) => t.name == name);

  Future<Map<String, dynamic>> run(
    String name,
    Map<String, dynamic> params,
  ) async {
    final result = await tool(name).execute('call', params);
    return Map<String, dynamic>.from(result.details as Map);
  }

  Future<String> importEntry(PreciseRefType type) async =>
      (await storage.importFromBytes(
        _pngBytes(),
        name: type.name,
        type: type,
      )).id;

  test('entries report the effective outfit preference per type', () async {
    final character = await importEntry(PreciseRefType.character);
    final both = await importEntry(PreciseRefType.characterAndStyle);
    final style = await importEntry(PreciseRefType.style);

    Future<Object?> preference(String id) async =>
        ((await run('get_precise_reference_entry', {'entry_id': id}))['entry']
            as Map)['prefer_same_outfit'];

    expect(await preference(character), isFalse);
    expect(await preference(both), isTrue);
    expect(await preference(style), isNull);
  });

  test(
    'update stores the outfit preference and keeps it on later edits',
    () async {
      final id = await importEntry(PreciseRefType.characterAndStyle);

      final updated = await run('update_precise_reference_entry', {
        'entry_id': id,
        'prefer_same_outfit': false,
      });
      expect(updated['ok'], isTrue);
      expect((updated['entry'] as Map)['prefer_same_outfit'], isFalse);

      await run('update_precise_reference_entry', {
        'entry_id': id,
        'strength': 3.5,
      });
      final stored = (await storage.getAllEntries()).single;
      expect(stored.preferSameOutfit, isFalse);
      expect(stored.strength, 3.5);
    },
  );

  test(
    'changing type without a preference resets it to the type default',
    () async {
      final id = await importEntry(PreciseRefType.characterAndStyle);
      await run('update_precise_reference_entry', {
        'entry_id': id,
        'prefer_same_outfit': false,
      });

      final updated = await run('update_precise_reference_entry', {
        'entry_id': id,
        'type': 'character',
      });

      expect((updated['entry'] as Map)['prefer_same_outfit'], isFalse);
      expect((await storage.getAllEntries()).single.preferSameOutfit, isNull);
    },
  );

  test('rejects an outfit preference for types that do not use it', () async {
    final id = await importEntry(PreciseRefType.style);

    final result = await run('update_precise_reference_entry', {
      'entry_id': id,
      'prefer_same_outfit': true,
    });
    final switched = await run('update_precise_reference_entry', {
      'entry_id': id,
      'type': 'costume',
      'prefer_same_outfit': false,
    });

    expect(result['code'], 'invalid_outfit_preference');
    expect(switched['code'], 'invalid_outfit_preference');
    final stored = (await storage.getAllEntries()).single;
    expect(stored.type, PreciseRefType.style);
    expect(stored.preferSameOutfit, isNull);
  });

  test(
    'create rejects an outfit preference before reading the image',
    () async {
      final result = await run('create_precise_reference_entry', {
        'resource_ref': <String, dynamic>{},
        'name': 'outfit',
        'type': 'costume',
        'prefer_same_outfit': true,
      });

      expect(result['code'], 'invalid_outfit_preference');
    },
  );

  test('schemas bound strength to the V5 range and fidelity to 0..1', () {
    for (final name in [
      'create_precise_reference_entry',
      'update_precise_reference_entry',
    ]) {
      final properties = tool(name).parameters['properties'] as Map;
      expect(properties['prefer_same_outfit']['type'], 'boolean');
      expect(properties['strength']['minimum'], 0);
      expect(properties['strength']['maximum'], 5);
      expect(properties['fidelity']['maximum'], 1);

      ToolCallContent call(Map<String, dynamic> arguments) =>
          ToolCallContent(id: name, name: name, arguments: arguments);
      final base = name == 'create_precise_reference_entry'
          ? <String, dynamic>{'resource_ref': {}, 'name': 'n'}
          : <String, dynamic>{'entry_id': 'id'};
      expect(
        () => validateToolArguments(tool(name), call({...base, 'strength': 5})),
        returnsNormally,
      );
      expect(
        () =>
            validateToolArguments(tool(name), call({...base, 'strength': 5.5})),
        throwsFormatException,
      );
      expect(
        () =>
            validateToolArguments(tool(name), call({...base, 'fidelity': 1.5})),
        throwsFormatException,
      );
    }
  });
}
