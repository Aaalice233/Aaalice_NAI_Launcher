import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/local_onnx_model_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../helpers/shared_compute_gate.dart';

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
      supportPath: supportDirectory.path,
      temporaryPath: p.join(tempDirectory.path, 'cache'),
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

  test('lists models kept in per-model folders of a shared directory', () async {
    final root = await Directory(
      p.join(tempDirectory.path, 'comfyui_wd14_models'),
    ).create(recursive: true);
    Future<File> write(List<String> segments, [String content = '']) async {
      final file = File(p.joinAll([root.path, ...segments]));
      await file.parent.create(recursive: true);
      return file.writeAsString(content);
    }

    final topLevel = await write(['wd-v1-4-convnext-tagger-v2.onnx']);
    await write(['wd-v1-4-convnext-tagger-v2.csv'], 'name,category\n1girl,0\n');
    final perModel = await write(['wd-eva02-large-tagger-v3', 'model.onnx']);
    await write([
      'wd-eva02-large-tagger-v3',
      'selected_tags.csv',
    ], 'name,category\n1girl,0\n');
    final versioned = await write(['cl_tagger_v2', 'v2_01a', 'model.onnx']);
    await write([
      'cl_tagger_v2',
      'v2_01a',
      'model_vocabulary.json',
    ], '{"idx_to_tag":{"0":"1girl"}}');
    await write(['archive', 'old', 'nested', 'too-deep.onnx']);
    await write(['.import-1', 'staged', 'tagger.onnx']);
    await service.setTaggerDirectory(root.path);

    final models = await service.scanTaggerModels();

    expect(models.map((model) => model.path), [
      versioned.path,
      perModel.path,
      topLevel.path,
    ]);
    expect(models.map((model) => model.name), [
      p.join('cl_tagger_v2', 'v2_01a', 'model.onnx'),
      p.join('wd-eva02-large-tagger-v3', 'model.onnx'),
      'wd-v1-4-convnext-tagger-v2.onnx',
    ]);
    expect(models.first.kind, LocalOnnxModelKind.clTaggerV2);
    expect(
      models[1].labelsPath,
      p.join(root.path, 'wd-eva02-large-tagger-v3', 'selected_tags.csv'),
    );
  });

  test('recognizes CL Tagger v1 kept in its Hugging Face folders', () async {
    final root = await Directory(
      p.join(tempDirectory.path, 'ComfyUI-WD14-Tagger', 'models'),
    ).create(recursive: true);
    final modelDirectory = await Directory(
      p.join(root.path, 'cl_tagger_1_02'),
    ).create();
    for (final name in const ['model.onnx', 'model_optimized.onnx']) {
      await File(p.join(modelDirectory.path, name)).writeAsBytes([1]);
    }
    final mapping = await File(
      p.join(modelDirectory.path, 'tag_mapping.json'),
    ).writeAsString('{"0":{"tag":"1girl","category":"General"}}');
    final wd = await File(
      p.join(root.path, 'wd-eva02-large-tagger-v3', 'model.onnx'),
    ).create(recursive: true);
    await File(
      p.join(wd.parent.path, 'selected_tags.csv'),
    ).writeAsString('name,category\n1girl,0\n');

    for (final directory in [root, modelDirectory]) {
      await service.setTaggerDirectory(directory.path);

      final models = await service.scanTaggerModels();
      final clModels = models.where(
        (model) => p.equals(p.dirname(model.path), modelDirectory.path),
      );

      expect(clModels, hasLength(2));
      for (final model in clModels) {
        expect(model.kind, LocalOnnxModelKind.clTagger);
        expect(model.labelsPath, mapping.path);
      }
      for (final model in models.where((model) => model.path == wd.path)) {
        expect(model.kind, isNot(LocalOnnxModelKind.clTagger));
      }
    }
  });

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

  group('PixAI Tagger layouts', () {
    Future<List<LocalOnnxModelDescriptor>> scan(
      String folder,
      Map<String, String> files,
    ) async {
      final directory = await Directory(
        p.join(tempDirectory.path, 'pixai_layouts', folder),
      ).create(recursive: true);
      for (final MapEntry(key: name, value: content) in files.entries) {
        await File(p.join(directory.path, name)).writeAsString(content);
      }
      await service.setTaggerDirectory(directory.path);
      return service.scanTaggerModels();
    }

    test('recognizes the hugging face config layout', () async {
      final models = await scan('flat_config', {
        'model.onnx': 'onnx',
        'config.json': _pixaiConfigJson,
      });

      expect(models.single.kind, LocalOnnxModelKind.pixaiTagger);
      expect(p.basename(models.single.labelsPath!), 'config.json');
    });

    test('recognizes the category offset tag map layout', () async {
      final models = await scan('flat_tag_map', {
        'model.onnx': 'onnx',
        'model.onnx.data': 'weights',
        'tags.json': _pixaiTagMapJson,
      });

      expect(models.single.kind, LocalOnnxModelKind.pixaiTagger);
      expect(p.basename(models.single.labelsPath!), 'tags.json');
    });

    test(
      'recognizes selected_tags.csv beside a rescale_pad declaration',
      () async {
        final models = await scan('flat_csv', {
          'model.onnx': 'onnx',
          'model_fp16.onnx': 'onnx',
          'selected_tags.csv': 'tag_id,name,category,count\n0,1girl,0,0\n',
          'preprocess.json':
              '{"stages":[{"type":"rescale_pad","size":1008,"pad_value":0}]}',
        });

        expect(models.map((model) => model.kind), [
          LocalOnnxModelKind.pixaiTagger,
          LocalOnnxModelKind.pixaiTagger,
        ]);
        expect(models.map((model) => p.basename(model.labelsPath!)).toSet(), {
          'selected_tags.csv',
        });
      },
    );

    test(
      'keeps models with their own labels out of a shared rescale_pad folder',
      () async {
        final models = await scan('shared_with_other_taggers', {
          'model.onnx': 'onnx',
          'selected_tags.csv': 'tag_id,name,category,count\n0,1girl,0,0\n',
          'preprocess.json':
              '{"stages":[{"type":"rescale_pad","size":1008,"pad_value":0}]}',
          'wd-eva02-large-tagger-v3.onnx': 'onnx',
          'wd-eva02-large-tagger-v3.csv':
              'tag_id,name,category,count\n0,1girl,0,0\n',
          'pixai-tagger-v1.0.onnx': 'onnx',
          'pixai-tagger-v1.0.csv': 'tag_id,name,category,count\n0,1girl,0,0\n',
        });

        expect(
          {for (final model in models) model.name: model.kind},
          {
            'model.onnx': LocalOnnxModelKind.pixaiTagger,
            'pixai-tagger-v1.0.onnx': LocalOnnxModelKind.pixaiTagger,
            'wd-eva02-large-tagger-v3.onnx': LocalOnnxModelKind.unknown,
          },
        );
        expect(
          p.basename(
            models
                .singleWhere((model) => model.name == 'pixai-tagger-v1.0.onnx')
                .labelsPath!,
          ),
          'pixai-tagger-v1.0.csv',
        );
      },
    );

    test('recognizes a pixai folder name without other hints', () async {
      final models = await scan('pixai-tagger-v1.0-onnx', {
        'model.onnx': 'onnx',
        'selected_tags.csv': 'tag_id,name,category,count\n0,1girl,0,0\n',
      });

      expect(models.single.kind, LocalOnnxModelKind.pixaiTagger);
    });

    test('leaves generic wd14-style folders and configs alone', () async {
      final models = await scan('generic', {
        'model.onnx': 'onnx',
        'selected_tags.csv': 'tag_id,name,category,count\n0,1girl,0,0\n',
        'config.json': '{"architecture":"vit_large_patch14"}',
      });

      expect(models.single.kind, LocalOnnxModelKind.unknown);
      expect(p.basename(models.single.labelsPath!), 'selected_tags.csv');
    });

    test('does not treat an unrelated config.json as labels', () async {
      final models = await scan('config_only', {
        'model.onnx': 'onnx',
        'config.json': '{"architecture":"vit_large_patch14"}',
      });

      expect(models.single.labelsPath, isNull);
      expect(models.single.kind, LocalOnnxModelKind.unknown);
    });
  });

  test(
    'rejects unsupported files selected by an unrestricted picker',
    () async {
      final unsupported = await File(
        p.join(tempDirectory.path, 'unrelated.zip'),
      ).writeAsBytes([1, 2, 3]);

      await expectLater(
        service.importTaggerFiles([
          LocalOnnxImportSource(name: 'unrelated.zip', path: unsupported.path),
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

  test('imports supported model files from a ZIP archive', () async {
    final labels = utf8.encode('name,category\ntag,0\n');
    final archive = Archive()
      ..addFile(ArchiveFile('tagger/model.onnx', 4, [1, 2, 3, 4]))
      ..addFile(ArchiveFile('tagger/selected_tags.csv', labels.length, labels))
      ..addFile(ArchiveFile('tagger/README.md', 7, utf8.encode('ignored')));
    final zip = await File(
      p.join(tempDirectory.path, 'tagger.zip'),
    ).writeAsBytes(ZipEncoder().encode(archive)!);

    final count = await service.importTaggerSelections([
      LocalOnnxImportSource(name: 'tagger.zip', path: zip.path),
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
      await File(p.join(managedDirectory, 'selected_tags.csv')).readAsString(),
      contains('tag,0'),
    );
    expect(service.taggerDirectory, managedDirectory);
    expect(Directory(p.join(tempDirectory.path, 'cache')).listSync(), isEmpty);
  });

  test('a long unpack does not hold a shared ComputeGate permit', () async {
    final archive = Archive()..addFile(ArchiveFile('model.onnx', 2, [7, 8]));
    final zip = await File(
      p.join(tempDirectory.path, 'ungated.zip'),
    ).writeAsBytes(ZipEncoder().encode(archive)!);
    final release = holdSharedComputeGate();
    try {
      final count = await service
          .importTaggerSelections([
            LocalOnnxImportSource(name: 'ungated.zip', path: zip.path),
          ])
          .timeout(const Duration(seconds: 20));
      expect(count, 1);
    } finally {
      await release();
    }
  });

  test('rejects duplicate flattened names in a ZIP archive', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('first/model.onnx', 1, [1]))
      ..addFile(ArchiveFile('second/model.onnx', 1, [2]));
    final zip = await File(
      p.join(tempDirectory.path, 'duplicate.zip'),
    ).writeAsBytes(ZipEncoder().encode(archive)!);

    await expectLater(
      service.importTaggerSelections([
        LocalOnnxImportSource(name: 'duplicate.zip', path: zip.path),
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
    expect(
      Directory(p.join(tempDirectory.path, 'cache')).listSync(),
      isEmpty,
      reason: '解包失败后半成品目录一并清理',
    );
  });
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform({
    required this.supportPath,
    required this.temporaryPath,
  });

  final String supportPath;
  final String temporaryPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;

  @override
  Future<String?> getTemporaryPath() async {
    await Directory(temporaryPath).create(recursive: true);
    return temporaryPath;
  }
}

const _pixaiConfigJson = '''
{
  "model_type": "cls_vitdet",
  "num_classes": 2,
  "tags": ["1girl", "rating:g"],
  "tags_split": [["general", 1], ["rating", 1]]
}
''';

const _pixaiTagMapJson = '''
{
  "num_classes": 1,
  "category_order": ["general"],
  "categories": [{"name": "general", "offset": 0, "count": 1, "tags": ["1girl"]}]
}
''';
