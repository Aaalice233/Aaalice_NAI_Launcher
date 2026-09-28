import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_draft_store.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';

void main() {
  late Directory root;
  late File file;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('agent_resource_drafts_');
    file = File('${root.path}/drafts.json');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('persists pending resources independently for every session', () async {
    final store = AgentChatResourceDraftStore(file);
    final first = AgentChatResourceReference(
      kind: AgentChatResourceKind.fixedTag,
      source: 'fixed_tags',
      resourceId: 'tag-1',
      display: {'name': 'lighting'},
    );
    final second = AgentChatResourceReference(
      kind: AgentChatResourceKind.vibeLibraryEntry,
      source: 'vibe_library',
      resourceId: 'vibe-2',
    );

    await store.save('session-a', [first]);
    await store.save('session-b', [second]);

    expect(await store.load('session-a'), [first]);
    expect(await store.load('session-b'), [second]);
    await store.save('session-a', const []);
    expect(await store.load('session-a'), isEmpty);
    expect(await store.load('session-b'), [second]);
  });

  test('recovers an interrupted atomic replacement', () async {
    final store = AgentChatResourceDraftStore(file);
    final reference = AgentChatResourceReference(
      kind: AgentChatResourceKind.localGalleryImage,
      source: 'local_gallery',
      resourceId: '42',
    );
    await store.save('session', [reference]);
    final original = await file.readAsString();

    await file.rename('${file.path}.bak');
    await File('${file.path}.tmp').writeAsString(original, flush: true);

    expect(await store.load('session'), [reference]);
    expect(await file.exists(), isTrue);
    expect(await File('${file.path}.tmp').exists(), isFalse);
    expect(await File('${file.path}.bak').exists(), isFalse);
  });

  test('serializes concurrent read-modify-write operations', () async {
    final store = AgentChatResourceDraftStore(file);

    await Future.wait([
      for (var index = 0; index < 20; index++)
        store.save('session-$index', [
          AgentChatResourceReference(
            kind: AgentChatResourceKind.fixedTag,
            source: 'fixed_tags',
            resourceId: 'tag-$index',
          ),
        ]),
    ]);

    for (var index = 0; index < 20; index++) {
      expect(
        (await store.load('session-$index')).single.resourceId,
        'tag-$index',
      );
    }
  });
}
