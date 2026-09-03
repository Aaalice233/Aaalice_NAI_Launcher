import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/local_onnx_model_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Directory supportDirectory;
  late LocalStorageService storage;
  late LocalOnnxModelService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'local_onnx_model_service_test_',
    );
    supportDirectory = await Directory(
      p.join(tempDirectory.path, 'support'),
    ).create(recursive: true);
    PathProviderPlatform.instance = _TestPathProviderPlatform(
      supportDirectory.path,
    );
    Hive.init(p.join(tempDirectory.path, 'hive'));
    await Hive.openBox(StorageKeys.settingsBox);
    storage = LocalStorageService();
    service = LocalOnnxModelService(storage);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'imports selected model files atomically into managed storage',
    () async {
      final sourceDirectory = await Directory(
        p.join(tempDirectory.path, 'picked'),
      ).create();
      final model = await File(
        p.join(sourceDirectory.path, 'model.onnx'),
      ).writeAsBytes([1, 2, 3, 4]);
      final labels = await File(
        p.join(sourceDirectory.path, 'selected_tags.csv'),
      ).writeAsString('name,category\ntag,0\n');

      final count = await service.importTaggerFiles([
        LocalOnnxImportSource(name: 'model.onnx', path: model.path),
        LocalOnnxImportSource(name: 'selected_tags.csv', path: labels.path),
      ]);

      final managedDirectory = await service.getManagedTaggerDirectory();
      expect(count, 2);
      expect(await File(p.join(managedDirectory, 'model.onnx')).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
      expect(
        await File(
          p.join(managedDirectory, 'selected_tags.csv'),
        ).readAsString(),
        contains('tag,0'),
      );
      expect(service.taggerDirectory, managedDirectory);
      expect(
        Directory(managedDirectory).listSync().whereType<Directory>().where(
          (entry) => p.basename(entry.path).startsWith('.import-'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'recovers an interrupted replacement before the next operation',
    () async {
      final managedDirectory = Directory(
        await service.getManagedTaggerDirectory(),
      );
      await managedDirectory.create(recursive: true);
      final destination = await File(
        p.join(managedDirectory.path, 'model.onnx'),
      ).writeAsString('partially committed replacement');
      final transaction = await Directory(
        p.join(managedDirectory.path, '.import-interrupted'),
      ).create();
      final backupDirectory = await Directory(
        p.join(transaction.path, 'backup'),
      ).create();
      await Directory(p.join(transaction.path, 'staged')).create();
      await File(
        p.join(backupDirectory.path, 'model.onnx'),
      ).writeAsString('previous model');
      await File(p.join(transaction.path, 'manifest.json')).writeAsString(
        jsonEncode({
          'phase': 'committing',
          'previousDirectory': 'previous/location',
          'entries': [
            {'fileName': 'model.onnx', 'hadDestination': true},
          ],
        }),
      );
      await service.setTaggerDirectory(managedDirectory.path);

      final count = await service.managedFileCount();

      expect(count, 1);
      expect(await destination.readAsString(), 'previous model');
      expect(service.taggerDirectory, 'previous/location');
      expect(await transaction.exists(), isFalse);
    },
  );

  test(
    'rejects duplicate destination names before changing managed files',
    () async {
      final first = await File(
        p.join(tempDirectory.path, 'first.onnx'),
      ).writeAsBytes([1]);
      final second = await File(
        p.join(tempDirectory.path, 'second.onnx'),
      ).writeAsBytes([2]);

      await expectLater(
        service.importTaggerFiles([
          LocalOnnxImportSource(name: 'MODEL.onnx', path: first.path),
          LocalOnnxImportSource(name: 'model.onnx', path: second.path),
        ]),
        throwsA(isA<FormatException>()),
      );

      final managedDirectory = Directory(
        await service.getManagedTaggerDirectory(),
      );
      expect(
        managedDirectory.existsSync() ? managedDirectory.listSync() : const [],
        isEmpty,
      );
      expect(service.taggerDirectory, isEmpty);
    },
  );

  test(
    'discovers CL Tagger v2 vocabulary beside an external-data model',
    () async {
      final modelDirectory = await Directory(
        p.join(tempDirectory.path, 'cl_tagger_v2', 'v2_01a'),
      ).create(recursive: true);
      final model = await File(
        p.join(modelDirectory.path, 'model.onnx'),
      ).writeAsBytes([1]);
      await File('${model.path}.data').writeAsBytes([2]);
      final vocabulary = await File(
        p.join(modelDirectory.path, 'model_vocabulary.json'),
      ).writeAsString('{"idx_to_tag":{"0":"1girl"}}');
      await service.setTaggerDirectory(modelDirectory.path);

      final models = await service.scanTaggerModels();

      expect(models, hasLength(1));
      expect(models.single.path, model.path);
      expect(models.single.kind, LocalOnnxModelKind.clTaggerV2);
      expect(models.single.labelsPath, vocabulary.path);
    },
  );

  test('recognizes the AnimeTimm EVA02 model family', () async {
    for (final layout in const [
      (
        directory: 'reported_names',
        model: 'eva02_large_patch14.onnx',
        labels: 'eva02_large_patch14.csv',
      ),
      (
        directory: 'eva02_large_patch14_448.dbv4-full',
        model: 'model.onnx',
        labels: 'selected_tags.csv',
      ),
    ]) {
      final modelDirectory = await Directory(
        p.join(tempDirectory.path, 'animetimm', layout.directory),
      ).create(recursive: true);
      final model = await File(
        p.join(modelDirectory.path, layout.model),
      ).writeAsBytes([1]);
      final labels = await File(
        p.join(modelDirectory.path, layout.labels),
      ).writeAsString('name,category,best_threshold\n1girl,0,0.4\n');
      await service.setTaggerDirectory(modelDirectory.path);

      final models = await service.scanTaggerModels();

      expect(models, hasLength(1));
      expect(models.single.path, model.path);
      expect(models.single.kind, LocalOnnxModelKind.animeTimmEva02);
      expect(models.single.labelsPath, labels.path);
    }
  });
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}
