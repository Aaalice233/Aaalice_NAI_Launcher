import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/derivatives/derivative_registry.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/save_naming/image_save_naming.dart';
import 'package:nai_launcher/core/save_naming/save_name_context.dart';
import 'package:nai_launcher/core/services/system_gallery_publisher.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/presentation/screens/derivatives/derivative_copy_saver.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory galleryRoot;
  late List<(String, String)> registrations;
  late List<(Uint8List, Uint8List)> usageCopies;
  late List<(Uint8List, String)> systemGalleryWrites;
  late List<List<String>> admissions;
  late int rescanCount;
  final sourceBytes = Uint8List.fromList([1, 2, 3]);
  final outputBytes = Uint8List.fromList([4, 5, 6, 7]);

  setUp(() async {
    galleryRoot = await Directory.systemTemp.createTemp(
      'derivative_copy_saver_root_',
    );
    registrations = [];
    usageCopies = [];
    systemGalleryWrites = [];
    admissions = [];
    rescanCount = 0;
  });

  tearDown(() => galleryRoot.delete(recursive: true));

  DerivativeCopySaver saver({
    DerivativeKind? kind,
    String? Function()? rootPath,
    TargetPlatform platform = TargetPlatform.android,
    SystemGalleryImageWriter? writeSystemGalleryImage,
    DerivativeRegistration? registerDerivative,
    DerivativeFixedTagUsageCopier? copyFixedTagUsage,
    Future<GalleryIndexAdmission> Function(List<String> filePaths)?
    addGalleryImages,
    Future<Object?> Function()? rescanGallery,
    DerivativeGalleryWriter? writeToGallery,
  }) => DerivativeCopySaver(
    kind: kind ?? DerivativeKind.watermark,
    resolveGalleryRootPath: () async =>
        rootPath == null ? galleryRoot.path : rootPath(),
    resolveNaming: () => ImageSaveNaming.standard,
    resolveSystemGallery: () => SystemGalleryPublisher(
      syncEnabled: true,
      capabilities: PlatformCapabilities.forPlatform(platform),
      writeImage:
          writeSystemGalleryImage ??
          (bytes, fileName, _) async =>
              systemGalleryWrites.add((bytes, fileName)),
    ),
    registerDerivative:
        registerDerivative ??
        ({required outputPath, required sourcePath}) async =>
            registrations.add((outputPath, sourcePath)),
    copyFixedTagUsage:
        copyFixedTagUsage ??
        ({required sourceBytes, required outputBytes}) async =>
            usageCopies.add((sourceBytes, outputBytes)),
    addGalleryImages:
        addGalleryImages ??
        (paths) async {
          admissions.add(paths);
          return GalleryIndexAdmission.added;
        },
    rescanGallery:
        rescanGallery ??
        () async {
          rescanCount++;
          return null;
        },
    writeToGallery: writeToGallery,
  );

  DerivativeCopyFollowUp followUp(
    DerivativeCopySaver target, {
    String outputPath = 'out_watermarked.png',
    String? sourcePath = 'source.png',
  }) => target.followUp(
    outputPath: outputPath,
    outputBytes: outputBytes,
    fileName: 'out_watermarked.png',
    sourceBytes: sourceBytes,
    sourcePath: sourcePath,
  );

  group('gallery root and write', () {
    test('missing or empty root means the gallery folder is not set', () async {
      expect(await saver(rootPath: () => null).resolveGalleryRoot(), isNull);
      expect(await saver(rootPath: () => '').resolveGalleryRoot(), isNull);
      expect(await saver().resolveGalleryRoot(), galleryRoot.path);
    });

    test('writes beside earlier copies without overwriting them', () async {
      final target = saver();
      final root = (await target.resolveGalleryRoot())!;

      final first = await target.write(
        rootPath: root,
        bytes: outputBytes,
        fileName: 'source_watermarked.png',
      );
      final second = await target.write(
        rootPath: root,
        bytes: sourceBytes,
        fileName: 'source_watermarked.png',
      );

      expect(p.isWithin(root, first), isTrue);
      expect(p.basename(first), 'source_watermarked.png');
      expect(p.basename(second), 'source_watermarked-2.png');
      expect(await File(first).readAsBytes(), outputBytes);
      expect(await File(second).readAsBytes(), sourceBytes);
    });

    test('protects the suffix of the editor family it saves for', () async {
      final protectedSuffixes = <String>[];
      Future<String> spyWriter({
        required String rootPath,
        required Uint8List bytes,
        required ImageSaveNaming naming,
        required SaveNameContext context,
        String? preferredFileName,
        String protectedSuffix = '',
      }) async {
        protectedSuffixes.add(protectedSuffix);
        return p.join(rootPath, preferredFileName);
      }

      for (final kind in [DerivativeKind.watermark, DerivativeKind.mosaic]) {
        await saver(kind: kind, writeToGallery: spyWriter).write(
          rootPath: galleryRoot.path,
          bytes: outputBytes,
          fileName: 'copy.png',
        );
      }

      expect(protectedSuffixes, ['_watermarked', '_redacted']);
    });
  });

  group('follow-up', () {
    test('admits only the new copy and skips the full rescan', () async {
      final steps = followUp(saver(), outputPath: 'a/out_watermarked.png');
      await steps.settled;

      expect(await steps.galleryIndexed, isTrue);
      expect(admissions, [
        ['a/out_watermarked.png'],
      ]);
      expect(rescanCount, 0);
      expect(registrations, [('a/out_watermarked.png', 'source.png')]);
      expect(usageCopies, [(sourceBytes, outputBytes)]);
      expect(systemGalleryWrites, [(outputBytes, 'out_watermarked.png')]);
      expect(await steps.systemGallery, isA<SystemGalleryPublished>());
    });

    for (final admission in [
      GalleryIndexAdmission.alreadyIndexed,
      GalleryIndexAdmission.deferred,
    ]) {
      test('${admission.name} admission needs no rescan', () async {
        final steps = followUp(saver(addGalleryImages: (_) async => admission));

        expect(await steps.galleryIndexed, isTrue);
        expect(rescanCount, 0);
      });
    }

    test('failed admission falls back to one full rescan', () async {
      final steps = followUp(
        saver(addGalleryImages: (_) async => GalleryIndexAdmission.failed),
      );

      expect(await steps.galleryIndexed, isTrue);
      expect(rescanCount, 1);
    });

    test('a rescan that reports a new error marks indexing failed', () async {
      final steps = followUp(
        saver(
          addGalleryImages: (_) async => GalleryIndexAdmission.failed,
          rescanGallery: () async => 'refreshFailed',
        ),
      );

      expect(await steps.galleryIndexed, isFalse);
    });

    test('a copy without a known original registers no source link', () async {
      await followUp(saver(), sourcePath: null).settled;

      expect(registrations, isEmpty);
      expect(usageCopies, hasLength(1));
    });

    test('a stalled gallery index never holds back the other steps', () async {
      final indexing = Completer<GalleryIndexAdmission>();
      final steps = followUp(saver(addGalleryImages: (_) => indexing.future));

      await steps.registered;
      await steps.fixedTagUsageCopied;
      expect(await steps.systemGallery, isA<SystemGalleryPublished>());
      expect(registrations, hasLength(1));

      var indexed = false;
      unawaited(steps.galleryIndexed.then((_) => indexed = true));
      await Future<void>.delayed(Duration.zero);
      expect(indexed, isFalse);

      indexing.complete(GalleryIndexAdmission.added);
      expect(await steps.galleryIndexed, isTrue);
    });

    test('every step contains its own failure', () async {
      final steps = followUp(
        saver(
          registerDerivative: ({required outputPath, required sourcePath}) =>
              throw StateError('registry'),
          copyFixedTagUsage: ({required sourceBytes, required outputBytes}) =>
              Future<void>.error(StateError('usage')),
          addGalleryImages: (_) => Future.error(StateError('index')),
          writeSystemGalleryImage: (bytes, fileName, mimeType) =>
              Future<void>.error(StateError('media store')),
        ),
      );

      await expectLater(steps.settled, completes);
      expect(await steps.galleryIndexed, isFalse);
      final outcome = await steps.systemGallery;
      expect(outcome, isA<SystemGalleryPublishFailed>());
      expect(
        (outcome as SystemGalleryPublishFailed).error,
        isA<StateError>().having((e) => e.message, 'message', 'media store'),
      );
    });

    test('platforms without a system gallery skip the export', () async {
      final steps = followUp(saver(platform: TargetPlatform.windows));

      expect(await steps.systemGallery, isA<SystemGalleryUnsupported>());
      expect(systemGalleryWrites, isEmpty);
    });
  });
}
