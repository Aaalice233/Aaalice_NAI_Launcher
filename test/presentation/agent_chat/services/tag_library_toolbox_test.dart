import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/tag_library_portable_thumbnail_store.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/tag_library_toolbox.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  test('create schema makes resource_ref mandatory inside thumbnail', () {
    final container = _container();
    addTearDown(container.dispose);
    final create = _createTool(container, _RecordingThumbnailStore());
    final properties = create.parameters['properties'] as Map;
    final thumbnail = properties['thumbnail'] as Map;

    expect(thumbnail['required'], contains('resource_ref'));
    expect(thumbnail['description'], contains('generated image'));
  });

  test(
    'create without thumbnail keeps the existing persistence behavior',
    () async {
      final store = _RecordingThumbnailStore();
      var resourceLoads = 0;
      final container = _container();
      addTearDown(container.dispose);
      final create = _createTool(
        container,
        store,
        resourceLoader: (_) async {
          resourceLoads++;
          return null;
        },
      );

      final result = await create.execute('without-image', {
        'name': 'No image',
        'content': '1girl',
        'tags': ['portrait'],
      });

      expect(result.isError, isFalse);
      expect(resourceLoads, 0);
      expect(store.stagedEntryIds, isEmpty);
      final entry = container
          .read(tagLibraryPageNotifierProvider)
          .entries
          .single;
      expect(entry.thumbnail, isNull);
      expect(entry.content, '1girl');
    },
  );

  test(
    'create stages and commits generated image as the entry thumbnail',
    () async {
      final store = _RecordingThumbnailStore();
      final storage = _MemoryStorage();
      final reference = _generatedReference();
      final container = _container(storage: storage);
      addTearDown(container.dispose);
      final create = _createTool(
        container,
        store,
        resourceLoader: (loadedReference) async {
          expect(loadedReference, reference);
          return ResolvedAgentResource(
            reference: loadedReference,
            label: 'Generated image',
            bytes: _onePixelPng,
          );
        },
      );

      final result = await create.execute('with-image', {
        'name': 'With image',
        'content': 'blue hair',
        'thumbnail': {
          'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
            reference,
          ),
        },
      });

      expect(result.isError, isFalse);
      final entry = container
          .read(tagLibraryPageNotifierProvider)
          .entries
          .single;
      expect(store.stagedEntryIds, [entry.id]);
      expect(store.extensions, ['.png']);
      expect(store.stagedBytes.single, _onePixelPng);
      expect(entry.thumbnail, 'memory://tag-library/${entry.id}.png');
      final persistedEntries =
          jsonDecode(storage.tagLibraryEntriesJson!) as List;
      expect(persistedEntries.single['id'], entry.id);
      expect(persistedEntries.single['thumbnail'], entry.thumbnail);
      expect(store.mutations.single.committed, isTrue);
      expect(store.mutations.single.rolledBack, isFalse);
      expect(result.details['entry'], containsPair('has_thumbnail', true));
    },
  );

  test(
    'thumbnail is rolled back and no success is returned on persistence failure',
    () async {
      final store = _RecordingThumbnailStore();
      final storage = _MemoryStorage(failOnWrite: 2);
      final reference = _generatedReference();
      final container = _container(storage: storage);
      addTearDown(container.dispose);
      final create = _createTool(
        container,
        store,
        resourceLoader: (loadedReference) async => ResolvedAgentResource(
          reference: loadedReference,
          label: 'Generated image',
          bytes: _onePixelPng,
        ),
      );

      final result = await create.execute('rollback', {
        'name': 'Rollback',
        'content': 'failed persistence',
        'thumbnail': {
          'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
            reference,
          ),
        },
      });

      expect(result.isError, isTrue);
      expect(result.details, containsPair('code', 'write_failed'));
      expect(store.mutations.single.committed, isFalse);
      expect(store.mutations.single.rolledBack, isTrue);
      expect(container.read(tagLibraryPageNotifierProvider).entries, isEmpty);
    },
  );
}

ProviderContainer _container({LocalStorageService? storage}) =>
    ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          storage ?? _MemoryStorage(),
        ),
      ],
    );

AgentTool _createTool(
  ProviderContainer container,
  TagLibraryPortableThumbnailStore store, {
  TagLibraryImageResourceLoader? resourceLoader,
}) => TagLibraryToolbox(
  container.read(_refProvider),
  resourceLoader: resourceLoader ?? (_) async => null,
  thumbnailStore: store,
).tools().singleWhere((tool) => tool.name == 'create_tag_library_entry');

AgentChatResourceReference _generatedReference() => AgentChatResourceReference(
  kind: AgentChatResourceKind.generatedImage,
  source: 'generation_history',
  resourceId: 'generated-1',
);

class _MemoryStorage extends LocalStorageService {
  _MemoryStorage({this.failOnWrite});

  final int? failOnWrite;
  final Map<String, Object?> _values = {};
  int _writeCount = 0;

  String? get tagLibraryEntriesJson => getTagLibraryEntriesJson();

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (_values[key] ?? defaultValue) as T?;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _writeCount++;
    if (_writeCount == failOnWrite) throw StateError('persistence failed');
    _values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _values.remove(key);
  }
}

class _RecordingThumbnailStore extends TagLibraryPortableThumbnailStore {
  final List<String> stagedEntryIds = [];
  final List<String?> extensions = [];
  final List<Uint8List> stagedBytes = [];
  final List<_RecordingMutation> mutations = [];

  @override
  Future<PortableThumbnailMutation> stage(
    String entryId, {
    required String? extension,
    required Stream<List<int>>? bytes,
    String? existingPath,
  }) async {
    stagedEntryIds.add(entryId);
    extensions.add(extension);
    stagedBytes.add(
      Uint8List.fromList(await bytes!.expand((chunk) => chunk).toList()),
    );
    final mutation = _RecordingMutation(
      'memory://tag-library/$entryId$extension',
    );
    mutations.add(mutation);
    return mutation;
  }
}

class _RecordingMutation extends PortableThumbnailMutation {
  _RecordingMutation(String path) : super(path, null, <File, File>{});

  bool committed = false;
  bool rolledBack = false;

  @override
  Future<void> commit() async {
    committed = true;
  }

  @override
  Future<void> rollback() async {
    rolledBack = true;
  }
}

final Uint8List _onePixelPng = Uint8List.fromList(
  image_lib.encodePng(image_lib.Image(width: 1, height: 1)),
);
