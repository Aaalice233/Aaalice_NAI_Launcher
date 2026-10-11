import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/services/system_gallery_publisher.dart';
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/fixed_tag/fixed_tag_usage_record_store.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';
import 'package:nai_launcher/presentation/screens/generation/services/generation_result_saver.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory hiveDirectory;
  late Directory galleryRoot;
  late List<(String, String)> recordedPaths;
  late List<(Uint8List, String)> systemGalleryWrites;
  late List<List<String>> admittedPaths;
  late int refreshCount;
  final plainPng = Uint8List.fromList(
    image_lib.encodePng(image_lib.Image(width: 2, height: 2)),
  );
  const snapshot = FixedTagUsageSnapshot(
    entries: [
      FixedTagUsageEntry(
        fixedTagId: 'fixed-own',
        name: 'Own',
        content: 'masterpiece',
        weight: 1,
        renderedContent: 'masterpiece',
        position: FixedTagPosition.prefix,
        promptType: FixedTagPromptType.positive,
        order: 0,
      ),
    ],
  );

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'generation_result_saver_hive_',
    );
    Hive.init(hiveDirectory.path);
    galleryRoot = await Directory.systemTemp.createTemp(
      'generation_result_saver_root_',
    );
    recordedPaths = [];
    systemGalleryWrites = [];
    admittedPaths = [];
    refreshCount = 0;
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
    await galleryRoot.delete(recursive: true);
  });

  GenerationResultSaver saver({
    String? rootPath,
    bool rootConfigured = true,
    GalleryIndexAdmission admission = GalleryIndexAdmission.added,
    Set<String> failingRecordIds = const {},
  }) => GenerationResultSaver(
    resolveGalleryRootPath: () async =>
        rootConfigured ? rootPath ?? galleryRoot.path : null,
    systemGallery: SystemGalleryPublisher(
      syncEnabled: true,
      capabilities: PlatformCapabilities.forPlatform(TargetPlatform.android),
      writeImage: (bytes, fileName, _) async =>
          systemGalleryWrites.add((bytes, fileName)),
    ),
    recordSavedPath: (id, path) {
      if (failingRecordIds.contains(id)) throw StateError('record $id');
      recordedPaths.add((id, path));
    },
    addGalleryImages: (paths) async {
      admittedPaths.add(paths);
      return admission;
    },
    refreshGallery: () async => refreshCount++,
  );

  GenerationResultSaveRequest request(
    String id, {
    NaiImageMetadata? metadata,
    FixedTagUsageSnapshot? fixedTagUsageSnapshot,
    bool preserveOriginalBytes = false,
    String? savedPath,
  }) => GenerationResultSaveRequest(
    imageId: id,
    bytes: plainPng,
    preserveOriginalBytes: preserveOriginalBytes,
    metadata: metadata,
    fixedTagUsageSnapshot: fixedTagUsageSnapshot,
    savedPath: savedPath,
  );

  List<String> pngFilesUnder(Directory root) => [
    for (final entity in root.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.png')) entity.path,
  ];

  test('缺内嵌元数据的结果图按自身元数据补写，并把路径记回生成结果', () async {
    final file =
        await saver().save(
              request(
                'image-1',
                metadata: const NaiImageMetadata(
                  prompt: 'own prompt',
                  seed: 31,
                ),
                fixedTagUsageSnapshot: snapshot,
              ),
            )
            as GenerationResultNewlySaved;

    final saved = file.saved;
    expect(file.rootPath, galleryRoot.path);
    expect(p.isWithin(galleryRoot.path, saved.path), isTrue);
    expect(p.basenameWithoutExtension(saved.path), endsWith('-31'));
    final metadata = UnifiedMetadataParser.parseFromPng(
      await File(saved.path).readAsBytes(),
    ).metadata!;
    expect(metadata.prompt, 'own prompt');
    expect(metadata.seed, 31);
    expect(recordedPaths, [('image-1', saved.path)]);
    expect(systemGalleryWrites.single.$1, orderedEquals(saved.bytes));
    expect(systemGalleryWrites.single.$2, p.basename(saved.path));
    expect(file.systemGalleryOutcome, isA<SystemGalleryPublished>());
    expect(admittedPaths, [
      [saved.path],
    ]);
    expect(refreshCount, 0);
    expect(
      FixedTagUsageRecordStore()
          .lookup(saved.contentHash)
          ?.entries
          .single
          .fixedTagId,
      'fixed-own',
    );
  });

  test('图像自身没有元数据时原样落盘，不从别处补写', () async {
    final file = await saver().save(request('image-2'));

    final saved = (file! as GenerationResultNewlySaved).saved;
    expect(saved.bytes, orderedEquals(plainPng));
    expect(
      UnifiedMetadataParser.extractPngTextData(
        await File(saved.path).readAsBytes(),
      ),
      isEmpty,
    );
  });

  test('要求保留原字节的外部结果不补写元数据，也不记固定词', () async {
    final file = await saver().save(
      request(
        'image-3',
        metadata: const NaiImageMetadata(prompt: 'own prompt', seed: 31),
        fixedTagUsageSnapshot: snapshot,
        preserveOriginalBytes: true,
      ),
    );

    final saved = (file! as GenerationResultNewlySaved).saved;
    expect(saved.bytes, orderedEquals(plainPng));
    await FixedTagUsageRecordStore().initialize();
    expect(FixedTagUsageRecordStore().lookup(saved.contentHash), isNull);
  });

  test('图库索引与磁盘不一致时才全量重扫', () async {
    await saver(
      admission: GalleryIndexAdmission.failed,
    ).save(request('image-4'));

    expect(refreshCount, 1);
  });

  for (final rootPath in [null, '']) {
    test('图库根目录${rootPath == null ? '未设置' : '为空'}时不落盘也不回写路径', () async {
      final target = saver(
        rootConfigured: rootPath != null,
        rootPath: rootPath,
      );

      expect(await target.save(request('image-5')), isNull);
      expect(await target.saveAll([request('image-6')]), isNull);
      expect(recordedPaths, isEmpty);
      expect(systemGalleryWrites, isEmpty);
      expect(admittedPaths, isEmpty);
      expect(galleryRoot.listSync(), isEmpty);
    });
  }

  test('已在当前图库里的结果复用原文件，不重复落盘', () async {
    final existing = await ImageSaveUtils.saveBytesToDatedPath(
      rootPath: galleryRoot.path,
      bytes: plainPng,
    );

    final file = await saver().save(request('image-7', savedPath: existing));

    expect(file, isA<GenerationResultAlreadySaved>());
    expect(file!.path, existing);
    expect(file.rootPath, galleryRoot.path);
    expect(pngFilesUnder(galleryRoot), [existing]);
    expect(recordedPaths, isEmpty);
    expect(systemGalleryWrites, isEmpty);
    expect(admittedPaths, isEmpty);
  });

  test('记录的文件已被删掉时重新落盘并改记新路径', () async {
    final missing = p.join(galleryRoot.path, 'gone.png');

    final file = await saver().save(request('image-8', savedPath: missing));

    expect(file, isA<GenerationResultNewlySaved>());
    expect(file!.path, isNot(missing));
    expect(recordedPaths, [('image-8', file.path)]);
  });

  test('换过图库根目录后重新落到当前图库', () async {
    final previousRoot = await Directory.systemTemp.createTemp(
      'generation_result_saver_previous_',
    );
    addTearDown(() => previousRoot.delete(recursive: true));
    final previous = await ImageSaveUtils.saveBytesToDatedPath(
      rootPath: previousRoot.path,
      bytes: plainPng,
    );

    final file = await saver().save(request('image-9', savedPath: previous));

    expect(file, isA<GenerationResultNewlySaved>());
    expect(p.isWithin(galleryRoot.path, file!.path), isTrue);
    expect(recordedPaths, [('image-9', file.path)]);
    expect(await File(previous).exists(), isTrue);
  });

  test('批量保存单张失败不阻断其余，新文件合并成一次收录', () async {
    final existing = await ImageSaveUtils.saveBytesToDatedPath(
      rootPath: galleryRoot.path,
      bytes: plainPng,
    );

    final report = await saver(failingRecordIds: {'bad'}).saveAll([
      request('first'),
      request('bad'),
      request('reused', savedPath: existing),
      request('last'),
    ]);

    expect(report!.isComplete, isFalse);
    expect(report.failures.single.imageId, 'bad');
    expect(report.failures.single.error, isA<StateError>());
    expect(
      [for (final file in report.files) file.runtimeType],
      [
        GenerationResultNewlySaved,
        GenerationResultAlreadySaved,
        GenerationResultNewlySaved,
      ],
    );
    expect([for (final (id, _) in recordedPaths) id], ['first', 'last']);
    expect(admittedPaths, [
      [report.files.first.path, report.files.last.path],
    ]);
  });

  test('单张保存失败直接抛出原始错误', () async {
    await expectLater(
      saver(failingRecordIds: {'bad'}).save(request('bad')),
      throwsA(isA<StateError>()),
    );
  });

  group('系统相册结果汇总', () {
    GenerationResultNewlySaved newlySaved(SystemGalleryPublishOutcome o) =>
        GenerationResultNewlySaved(
          rootPath: 'root',
          saved: SavedResultImage(
            path: 'root/a.png',
            bytes: Uint8List(0),
            contentHash: 'hash',
          ),
          systemGalleryOutcome: o,
        );
    GenerationResultSaveReport report(List<GenerationResultFile> files) =>
        GenerationResultSaveReport(
          rootPath: 'root',
          files: files,
          failures: const [],
        );
    final failed = SystemGalleryPublishFailed(
      StateError('media store'),
      StackTrace.empty,
    );

    test('任一张发布失败即视为失败', () {
      expect(
        report([
          newlySaved(const SystemGalleryPublished()),
          newlySaved(failed),
          newlySaved(const SystemGalleryPublished()),
        ]).systemGalleryOutcome,
        same(failed),
      );
    });

    test('全部成功时取最后一次结果', () {
      expect(
        report([
          newlySaved(const SystemGallerySyncDisabled()),
          newlySaved(const SystemGalleryPublished()),
        ]).systemGalleryOutcome,
        isA<SystemGalleryPublished>(),
      );
    });

    test('只复用已有文件时没有发布结果', () {
      expect(
        report([
          const GenerationResultAlreadySaved(
            rootPath: 'root',
            path: 'root/a.png',
          ),
        ]).systemGalleryOutcome,
        isNull,
      );
    });
  });

  group('保存请求只取图像自身数据', () {
    test('生成结果带上当前记录的文件路径', () {
      final image = GeneratedImage(
        id: 'image-10',
        bytes: plainPng,
        width: 2,
        height: 2,
        metadata: const NaiImageMetadata(prompt: 'own'),
        fixedTagUsageSnapshot: snapshot,
        preserveOriginalBytesOnSave: true,
        filePath: 'root/saved.png',
      );

      final request = GenerationResultSaveRequest.fromImage(image);

      expect(request.imageId, 'image-10');
      expect(request.bytes, same(plainPng));
      expect(request.metadata?.prompt, 'own');
      expect(request.fixedTagUsageSnapshot, same(snapshot));
      expect(request.preserveOriginalBytes, isTrue);
      expect(request.savedPath, 'root/saved.png');
    });

    test('详情页数据带上固定词快照与调用方给的路径', () async {
      final request = await GenerationResultSaveRequest.fromDetail(
        GeneratedImageDetailData(
          imageBytes: plainPng,
          metadata: const NaiImageMetadata(prompt: 'own'),
          id: 'image-11',
          preserveOriginalBytesOnSave: true,
          fixedTagUsageSnapshot: snapshot,
        ),
        savedPath: 'root/saved.png',
      );

      expect(request.imageId, 'image-11');
      expect(request.bytes, same(plainPng));
      expect(request.metadata?.prompt, 'own');
      expect(request.fixedTagUsageSnapshot, same(snapshot));
      expect(request.preserveOriginalBytes, isTrue);
      expect(request.savedPath, 'root/saved.png');
    });
  });

  test('生成页所有手动保存入口走同一个落盘实现', () {
    const pages = [
      'lib/presentation/screens/generation/widgets/image_preview.dart',
      'lib/presentation/screens/generation/widgets/history_panel.dart',
    ];
    for (final page in pages) {
      final source = File(page).readAsStringSync();
      expect(
        source,
        contains('GenerationSaveService.saveImageFromDetail('),
        reason: page,
      );
      expect(
        source,
        contains('GenerationSaveService.saveImages('),
        reason: page,
      );
      expect(
        source,
        contains('GeneratedImageFileLink.ensureSaved('),
        reason: page,
      );
    }

    const entries = [
      ...pages,
      'lib/presentation/screens/generation/services/generation_save_service.dart',
      'lib/presentation/screens/generation/services/generation_image_batch_actions.dart',
      'lib/presentation/screens/generation/services/generated_image_file_link.dart',
      'lib/presentation/widgets/common/image_card_actions.dart',
    ];
    for (final entry in entries) {
      final source = File(entry).readAsStringSync();
      for (final bypass in const [
        'saveResultImage(',
        'saveBytesToDatedPath(',
        'rebuildImageBytesWithMetadata(',
      ]) {
        expect(source, isNot(contains(bypass)), reason: '$entry: $bypass');
      }
    }
  });
}
