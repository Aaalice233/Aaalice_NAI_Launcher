import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/bulk_operation_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/selection_mode_provider.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_action_coordinator.dart';
import 'package:nai_launcher/presentation/services/local_gallery_deletion.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';

void main() {
  test('single-image route request keeps its typed record and action', () {
    final record = LocalImageRecord(
      path: 'gallery/image.png',
      size: 42,
      modifiedAt: DateTime(2025),
    );
    final request = LocalGalleryImageAction(
      record: record,
      action: LocalImageContextAction.sendToImg2Img,
    );

    expect(request.record, same(record));
    expect(request.action, LocalImageContextAction.sendToImg2Img);
    expect(request.metadata, isNull);
  });

  for (final scenario in [
    'cancel',
    'protection',
    'delete',
    'missing',
    'denied',
    'unreachable',
    'index error',
    'registry error',
    'batch',
    'batch current selection',
    'batch unmounted',
  ]) {
    testWidgets('图库永久删除：$scenario', (tester) async {
      final unmount = scenario == 'batch unmounted';
      final trackSelection = scenario == 'batch current selection' || unmount;
      final batch = scenario == 'batch' || trackSelection;
      final finishCleanup = unmount ? Completer<void>() : null;
      final directory = Directory.systemTemp.createTempSync('gallery_action_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final target = File('${directory.path}/target.png');
      if (scenario != 'missing') target.writeAsBytesSync([1]);
      final other = File('${directory.path}/other.png')..writeAsBytesSync([2]);
      final files = {target.path: target, other.path: other};
      final record = LocalImageRecord(
        path: target.path,
        size: 1,
        modifiedAt: DateTime(2026),
      );
      final gallery = _Gallery(
        scenario == 'index error',
        finishCleanup?.future,
        record,
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWith((_) => _Storage(scenario)),
          localGalleryNotifierProvider.overrideWith(() => gallery),
        ],
      );
      addTearDown(container.dispose);
      final actions = await _pumpCoordinator(tester, container);
      final undo = container.listen(
        bulkOperationNotifierProvider,
        (_, next) {},
      );
      addTearDown(undo.close);
      final originalState = container.read(localGalleryNotifierProvider);
      GalleryImageDeleteResult? result;
      final completed = IOOverrides.runZoned(() async {
        if (batch) {
          await actions.deleteSelectedImages(files.keys.toSet());
        } else {
          result = await actions.confirmDeleteImage(record);
        }
      }, createFile: (path) => _TestFile(files[path]!, scenario));
      await tester.pumpAndSettle();
      if (trackSelection) {
        final selection = container.listen(
          localGallerySelectionNotifierProvider,
          (_, next) {},
        );
        addTearDown(selection.close);
        container.read(localGallerySelectionNotifierProvider.notifier)
          ..enter()
          ..selectAll(files.keys);
        expect(selection.read().selectedCount, 2);
      } else if (!batch) {
        expect(
          find.text(l10n.localGallery_confirmDeleteImageContent('target.png')),
          findsOneWidget,
        );
      }
      await _answerDeleteDialogs(tester, l10n, scenario);
      if (finishCleanup != null) {
        expect(gallery.removed, [files.keys.toList()]);
        await tester.pumpWidget(const SizedBox.shrink());
        finishCleanup.complete();
      }
      await completed;
      final gone =
          batch ||
          {
            'delete',
            'missing',
            'index error',
            'registry error',
          }.contains(scenario);
      expect(target.existsSync(), !gone);
      expect(other.existsSync(), !batch);
      if (trackSelection) {
        final selection = container.read(localGallerySelectionNotifierProvider);
        expect(selection.isActive, unmount);
        expect(selection.selectedIds, unmount ? files.keys.toSet() : isEmpty);
      }
      final paths = batch ? files.keys.toList() : [target.path];
      expect(gallery.removed, gone ? [paths] : isEmpty);
      if (scenario == 'unreachable') {
        expect(
          container.read(localGalleryNotifierProvider),
          same(originalState),
        );
        expect(originalState.currentImages, [record]);
      }
      expect(undo.read().canUndo, isFalse);
      expect(result, switch (scenario) {
        'cancel' || 'protection' => GalleryImageDeleteResult.cancelled,
        'missing' => GalleryImageDeleteResult.alreadyMissing,
        'denied' || 'unreachable' => GalleryImageDeleteResult.failed,
        'batch' || 'batch current selection' || 'batch unmounted' => null,
        _ => GalleryImageDeleteResult.deleted,
      });
      _expectDeletionMessage(l10n, scenario);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  }
}

Future<LocalGalleryActionCoordinator> _pumpCoordinator(
  WidgetTester tester,
  ProviderContainer container,
) async {
  late LocalGalleryActionCoordinator actions;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) {
            actions = LocalGalleryActionCoordinator(
              ref: ref,
              context: () => context,
              mounted: () => context.mounted,
            );
            return const Scaffold();
          },
        ),
      ),
    ),
  );
  return actions;
}

Future<void> _answerDeleteDialogs(
  WidgetTester tester,
  AppLocalizations l10n,
  String scenario,
) async {
  await tester.tap(
    find.text(scenario == 'cancel' ? l10n.common_cancel : l10n.common_delete),
  );
  await tester.pumpAndSettle();
  if (scenario == 'protection') {
    expect(find.text(l10n.localGallery_protectedDeleteTitle), findsOneWidget);
    await tester.tap(find.text(l10n.common_cancel));
    await tester.pumpAndSettle();
  }
}

void _expectDeletionMessage(AppLocalizations l10n, String scenario) {
  final message = switch (scenario) {
    'delete' => l10n.localGallery_imageDeleted,
    'batch' || 'batch current selection' => l10n.localGallery_deletedImages(2),
    'missing' => l10n.localGallery_imageFileMissing,
    'denied' => l10n.localGallery_deleteFailed(
      'target.png: ${l10n.localGallery_errorPermissionDenied}',
    ),
    'unreachable' => l10n.localGallery_deleteFailed(
      'target.png: ${l10n.localGallery_unknownError}',
    ),
    'index error' => l10n.localGallery_deleteCleanupFailed(
      l10n.localGallery_deleteIndexCleanupFailed,
    ),
    'registry error' => l10n.localGallery_deleteCleanupFailed(
      'target.png: ${l10n.localGallery_deleteRegistryCleanupFailed}',
    ),
    _ => null,
  };
  if (message != null) expect(find.text(message), findsOneWidget);
}

class _TestFile extends Fake implements File {
  _TestFile(this.file, this.scenario);
  final File file;
  final String scenario;

  @override
  Directory get parent => _TestDirectory(file.parent);

  @override
  Future<bool> exists() async => file.existsSync();

  @override
  Future<File> delete({bool recursive = false}) async {
    if (scenario == 'denied') {
      throw PathAccessException(file.path, const OSError('access denied', 5));
    }
    if (scenario == 'unreachable') {
      throw PathNotFoundException(
        file.path,
        const OSError('network path unavailable', 53),
      );
    }
    file.deleteSync();
    return this;
  }
}

class _TestDirectory extends Fake implements Directory {
  _TestDirectory(this.directory);
  final Directory directory;

  @override
  Future<bool> exists() async => directory.existsSync();
}

class _Storage extends LocalStorageService {
  _Storage(this.scenario)
    : settings = {StorageKeys.protectionMode: scenario == 'protection'};
  final String scenario;
  final Map<String, Object?> settings;
  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      settings[key] as T? ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    if (scenario == 'registry error') throw StateError('registry write failed');
    settings[key] = value;
  }
}

class _Gallery extends LocalGalleryNotifier {
  _Gallery(this.fail, this.finishCleanup, this.record);
  final bool fail;
  final Future<void>? finishCleanup;
  final LocalImageRecord record;
  final removed = <List<String>>[];
  @override
  LocalGalleryState build() => LocalGalleryState(currentImages: [record]);
  @override
  Future<void> removeDeletedImages(List<String> paths) async {
    removed.add(paths);
    if (fail) throw StateError('index write failed');
    await finishCleanup;
  }
}
