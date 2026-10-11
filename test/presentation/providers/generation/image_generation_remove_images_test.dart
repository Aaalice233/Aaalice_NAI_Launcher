import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/services/generation_history_storage_service.dart';

void main() {
  late Directory directory;
  late ProviderContainer container;
  late _RecordingGalleryNotifier gallery;
  late _RecordingHistoryStorage historyStorage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nai_remove_images_');
    gallery = _RecordingGalleryNotifier();
    historyStorage = _RecordingHistoryStorage();
  });

  tearDown(() async {
    container.dispose();
    await historyStorage.flush();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  ImageGenerationNotifier notifierWith(ImageGenerationState initial) {
    container = ProviderContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          () => _SeededImageGenerationNotifier(initial),
        ),
        localGalleryNotifierProvider.overrideWith(() => gallery),
        localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
        generationHistoryStorageServiceProvider.overrideWithValue(
          historyStorage,
        ),
      ],
    );
    return container.read(imageGenerationNotifierProvider.notifier);
  }

  Future<String> savedFile(String name) async {
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(_pngBytes);
    return file.path;
  }

  test('从当前批次、历史与中央预览移除，并删除关联的图库文件', () async {
    final linkedPath = await savedFile('linked.png');
    final removed = _image('removed').copyWithFilePath(linkedPath);
    final kept = _image('kept');
    final notifier = notifierWith(
      ImageGenerationState(
        status: GenerationStatus.error,
        errorMessage: 'previous failure',
        currentImages: [removed, kept],
        history: [removed, kept],
        displayImages: [removed, kept],
        completionPreviews: {
          'removed': StreamPreviewFrame(bytes: _pngBytes),
          'kept': StreamPreviewFrame(bytes: _pngBytes),
        },
      ),
    );

    final result = await notifier.removeImages(['removed']);

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.currentImages, [kept]);
    expect(state.history, [kept]);
    expect(state.displayImages, [kept]);
    expect(state.completionPreviews.keys, ['kept']);
    expect(state.errorMessage, 'previous failure');
    expect(result.removedCount, 1);
    expect(result.files.deletedPaths, [linkedPath]);
    expect(result.files.failures, isEmpty);
    expect(await File(linkedPath).exists(), isFalse);
    expect(gallery.removals, [
      [linkedPath],
    ]);
    expect(gallery.refreshCount, 0);
    await historyStorage.flush();
    expect(historyStorage.lastOrder, ['kept']);
  });

  test('只移除记录、没有关联文件时不触碰图库', () async {
    final notifier = notifierWith(
      ImageGenerationState(history: [_image('a'), _image('b')]),
    );

    final result = await notifier.removeImages(['a']);

    expect(
      container.read(imageGenerationNotifierProvider).history.map((i) => i.id),
      ['b'],
    );
    expect(result.removedCount, 1);
    expect(result.files.deletedPaths, isEmpty);
    expect(gallery.removals, isEmpty);
    expect(gallery.refreshCount, 0);
  });

  test('仍被其他结果引用的文件保留', () async {
    final sharedPath = await savedFile('shared.png');
    final notifier = notifierWith(
      ImageGenerationState(
        history: [
          _image('a').copyWithFilePath(sharedPath),
          _image('b').copyWithFilePath(sharedPath),
        ],
      ),
    );

    final result = await notifier.removeImages(['a']);

    expect(result.files.deletedPaths, isEmpty);
    expect(await File(sharedPath).exists(), isTrue);
  });

  test('未知 id 不改动状态', () async {
    final initial = ImageGenerationState(history: [_image('a')]);
    final notifier = notifierWith(initial);

    final result = await notifier.removeImages(['missing']);

    expect(result.removedCount, 0);
    expect(container.read(imageGenerationNotifierProvider), same(initial));
  });

  test('删除后才回写的保存路径会连文件一起清掉，不再挂回记录', () async {
    final notifier = notifierWith(
      ImageGenerationState(history: [_image('a'), _image('b')]),
    );
    await notifier.removeImages(['a']);
    final latePath = await savedFile('late.png');

    notifier.updateImageFilePath('a', latePath);
    await _eventually(() async => !await File(latePath).exists());

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.findImageById('a'), isNull);
    expect(await File(latePath).exists(), isFalse);
  });

  test('保存途中被删除的结果，保存完成后删掉刚写入的文件', () async {
    final notifier = notifierWith(const ImageGenerationState());
    final subscription = container.listen<ImageGenerationState>(
      imageGenerationNotifierProvider,
      (previous, next) {
        if (next.history.isEmpty || (previous?.history.isNotEmpty ?? false)) {
          return;
        }
        final id = next.history.first.id;
        scheduleMicrotask(() => unawaited(notifier.removeImages([id])));
      },
    );
    addTearDown(subscription.close);

    final savedPath = await notifier.registerExternalImage(
      _pngBytes,
      params: const ImageParams(seed: 123),
      saveToLocal: true,
      saveDirectoryPath: directory.path,
      embedNaiMetadata: false,
    );

    expect(savedPath, isNull);
    expect(container.read(imageGenerationNotifierProvider).history, isEmpty);
    final remaining = await directory
        .list(recursive: true)
        .where((entity) => entity is File)
        .toList();
    expect(remaining, isEmpty);
  });
}

final _pngBytes = Uint8List.fromList(
  image_lib.encodePng(image_lib.Image(width: 2, height: 2)),
);

GeneratedImage _image(String id) =>
    GeneratedImage(id: id, bytes: _pngBytes, width: 2, height: 2);

Future<void> _eventually(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('condition was not met');
}

class _SeededImageGenerationNotifier extends ImageGenerationNotifier {
  _SeededImageGenerationNotifier(this.initial);

  final ImageGenerationState initial;

  @override
  ImageGenerationState build() {
    super.build();
    return initial;
  }
}

class _RecordingGalleryNotifier extends LocalGalleryNotifier {
  var refreshCount = 0;
  final removals = <List<String>>[];

  @override
  LocalGalleryState build() => const LocalGalleryState(isInitialized: true);

  @override
  Future<void> refresh({bool scan = true}) async => refreshCount++;

  @override
  Future<void> removeDeletedImages(List<String> filePaths) async =>
      removals.add(filePaths);

  @override
  Future<GalleryIndexAdmission> addNewlySavedImages(
    List<String> filePaths,
  ) async => GalleryIndexAdmission.added;
}

class _RecordingHistoryStorage extends GenerationHistoryStorageService {
  _RecordingHistoryStorage() : super(enabled: false);

  List<String>? lastOrder;

  @override
  Future<void> persistImages({
    required Iterable<GeneratedImage> changedImages,
    required List<String> order,
  }) {
    lastOrder = order;
    return super.persistImages(changedImages: changedImages, order: order);
  }
}

class _MemoryStorage extends LocalStorageService {
  final values = <String, Object?>{};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
