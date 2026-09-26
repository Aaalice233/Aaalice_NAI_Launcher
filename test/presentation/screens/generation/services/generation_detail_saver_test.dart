import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/services/system_gallery_publisher.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/fixed_tag/fixed_tag_usage_record_store.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/screens/generation/services/generation_detail_saver.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory hiveDirectory;
  late Directory galleryRoot;
  late List<(String, String)> recordedPaths;
  late List<(Uint8List, String)> systemGalleryWrites;
  late int refreshCount;
  final plainPng = Uint8List.fromList(
    image_lib.encodePng(image_lib.Image(width: 2, height: 2)),
  );

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'generation_detail_saver_hive_',
    );
    Hive.init(hiveDirectory.path);
    galleryRoot = await Directory.systemTemp.createTemp(
      'generation_detail_saver_root_',
    );
    recordedPaths = [];
    systemGalleryWrites = [];
    refreshCount = 0;
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
    await galleryRoot.delete(recursive: true);
  });

  GenerationDetailSaver saver({
    bool rootConfigured = true,
    GalleryIndexAdmission admission = GalleryIndexAdmission.added,
  }) => GenerationDetailSaver(
    resolveGalleryRootPath: () async =>
        rootConfigured ? galleryRoot.path : null,
    systemGallery: SystemGalleryPublisher(
      syncEnabled: true,
      capabilities: PlatformCapabilities.forPlatform(TargetPlatform.android),
      writeImage: (bytes, fileName, _) async =>
          systemGalleryWrites.add((bytes, fileName)),
    ),
    recordSavedPath: (id, path) => recordedPaths.add((id, path)),
    addGalleryImages: (_) async => admission,
    refreshGallery: () async => refreshCount++,
  );

  test('缺内嵌元数据的结果图按自身元数据补写，并把路径记回生成结果', () async {
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

    final result = await saver().save(
      GeneratedImageDetailData(
        imageBytes: plainPng,
        metadata: const NaiImageMetadata(prompt: 'own prompt', seed: 31),
        id: 'image-1',
        fixedTagUsageSnapshot: snapshot,
      ),
    );

    final saved = result!.saved;
    expect(result.rootPath, galleryRoot.path);
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
    expect(result.systemGalleryOutcome, isA<SystemGalleryPublished>());
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
    final result = await saver().save(
      GeneratedImageDetailData(imageBytes: plainPng, id: 'image-2'),
    );

    expect(result!.saved.bytes, orderedEquals(plainPng));
    expect(
      UnifiedMetadataParser.extractPngTextData(
        await File(result.saved.path).readAsBytes(),
      ),
      isEmpty,
    );
  });

  test('要求保留原字节的外部结果不补写元数据', () async {
    final result = await saver().save(
      GeneratedImageDetailData(
        imageBytes: plainPng,
        metadata: const NaiImageMetadata(prompt: 'own prompt', seed: 31),
        id: 'image-3',
        preserveOriginalBytesOnSave: true,
      ),
    );

    expect(result!.saved.bytes, orderedEquals(plainPng));
  });

  test('图库索引与磁盘不一致时才全量重扫', () async {
    await saver(admission: GalleryIndexAdmission.failed).save(
      GeneratedImageDetailData(imageBytes: plainPng, id: 'image-4'),
    );

    expect(refreshCount, 1);
  });

  test('图库根目录未设置时不落盘也不回写路径', () async {
    final result = await saver(rootConfigured: false).save(
      GeneratedImageDetailData(imageBytes: plainPng, id: 'image-5'),
    );

    expect(result, isNull);
    expect(recordedPaths, isEmpty);
    expect(systemGalleryWrites, isEmpty);
    expect(galleryRoot.listSync(), isEmpty);
  });

  test('预览区与历史栏的详情页保存走同一个实现', () {
    const entries = [
      'lib/presentation/screens/generation/widgets/image_preview.dart',
      'lib/presentation/screens/generation/widgets/history_panel.dart',
    ];
    for (final entry in entries) {
      final source = File(entry).readAsStringSync();
      expect(
        source,
        contains('GenerationSaveService.saveImageFromDetail('),
        reason: entry,
      );
      expect(source, isNot(contains('saveResultImage(')), reason: entry);
      expect(
        source,
        isNot(contains('rebuildImageBytesWithMetadata(')),
        reason: entry,
      );
    }
  });
}
