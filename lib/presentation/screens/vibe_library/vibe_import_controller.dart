import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/constants/model_capabilities.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../../../core/utils/vibe_image_embedder.dart';
import '../../../data/models/vibe/vibe_import_progress.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/vibe_import_service.dart';
import '../../../data/services/vibe_library_import_repository_impl.dart';
import '../../../data/services/vibe_library_storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/generation/generation_params_notifier.dart';
import '../../providers/vibe_library_provider.dart';
import '../../widgets/common/app_toast.dart';
import 'vibe_drop_import_preprocessor.dart';
import 'vibe_library_screen_controller.dart';
import 'widgets/vibe_bundle_import_dialog.dart' as bundle_dialog;
import 'widgets/vibe_image_encode_dialog.dart' as encode_dialog;
import 'widgets/vibe_import_naming_dialog.dart' as naming_dialog;

const _imageExtensions = ['png', 'jpg', 'jpeg', 'webp'];

/// Owns every Vibe import source and encoding orchestration path.
///
/// The screen supplies only context/ref wiring and command entry points.
class VibeImportController {
  VibeImportController({
    required this.ref,
    required this.screenController,
    required this.context,
    required this.mounted,
  });

  final WidgetRef ref;
  final VibeLibraryScreenController screenController;
  final BuildContext Function() context;
  final bool Function() mounted;

  VibeImportService get _service => VibeImportService(
    repository: VibeLibraryStorageImportRepository(
      ref.read(vibeLibraryStorageServiceProvider),
    ),
  );

  String? get _categoryId {
    final id = ref.read(vibeLibraryNotifierProvider).selectedCategoryId;
    return id == null || id == 'favorites' ? null : id;
  }

  void _beginSession() {
    screenController.beginImportSession(
      ref.read(vibeLibraryNotifierProvider).entries.map((entry) => entry.name),
    );
  }

  Future<void> importFiles() async {
    if (screenController.isBusy) return;
    final files = await screenController.pickFiles(
      allowedExtensions: ['naiv4vibe', 'naiv4vibebundle', ..._imageExtensions],
      dialogTitle: context().l10n.vibeLibrary_importFileDialogTitle,
    );
    if (files == null || files.isEmpty || !mounted()) return;
    await _runImport((epoch) async {
      final sources = await _categorize(files);
      final result = await _processSources(
        sources.images,
        sources.vibes,
        epoch,
      );
      return (success: result.success, fail: result.fail + sources.failed);
    });
  }

  Future<void> importImages() async {
    if (screenController.isBusy) return;
    final files = await screenController.pickFiles(
      allowedExtensions: _imageExtensions,
      dialogTitle: context().l10n.vibeLibrary_importImageDialogTitle,
      useInjectedPicker: false,
    );
    if (files == null || files.isEmpty || !mounted()) return;
    await _runImport((epoch) async {
      var success = 0;
      var failure = 0;
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        try {
          final image = VibeImageImportItem(
            source: file.name,
            bytes: await _readBytes(file),
          );
          final imported = await _processImage(image);
          if (imported == true) success++;
          if (imported == false) failure++;
        } catch (error, stackTrace) {
          failure++;
          AppLogger.e(
            'Failed to read ${file.name}',
            error,
            stackTrace,
            'VibeLibrary',
          );
        }
        screenController.updateProgress(
          epoch,
          ImportProgress(current: index + 1, total: files.length),
        );
      }
      return (success: success, fail: failure);
    });
  }

  Future<void> importClipboard() async {
    if (screenController.isBusy) return;
    await _runImport((_) async {
      final value = (await Clipboard.getData(
        Clipboard.kTextPlain,
      ))?.text?.trim();
      if (value == null || value.isEmpty) {
        if (mounted()) {
          AppToast.error(context(), context().l10n.vibeLibrary_clipboardEmpty);
        }
        return (success: 0, fail: 0);
      }
      final result = await _service.importFromEncoding(
        items: [VibeEncodingImportItem(source: '剪贴板', encoding: value)],
        categoryId: _categoryId,
      );
      return (success: result.successCount, fail: result.failCount);
    });
  }

  Future<void> importDrop(PerformDropEvent event) async {
    if (screenController.isBusy) return;
    await _runImport((epoch) async {
      final paths = await _readDropPaths(event);
      final classified = await compute(_classifyPaths, paths);
      for (final folder in classified.folders) {
        final nested = await _scanFolder(folder);
        classified.images.addAll(nested.images);
        classified.vibes.addAll(nested.vibes);
      }
      final images = await VibeDropImportPreprocessor.collectImageItems(
        classified.images,
      );
      final result = await _processSources(images.items, [
        for (final path in classified.vibes)
          PlatformFile(name: p.basename(path), path: path, size: 0),
      ], epoch);
      return (
        success: result.success,
        fail:
            result.fail +
            images.failedCount +
            images.skippedOversizedCount +
            images.skippedTotalLimitCount,
      );
    }, preparing: true);
  }

  Future<void> _runImport(
    Future<({int success, int fail})> Function(int epoch) operation, {
    bool preparing = false,
  }) async {
    if (screenController.isBusy) return;
    _beginSession();
    final epoch = screenController.beginOperation(
      progress: preparing
          ? ImportProgress(message: context().l10n.vibeLibrary_preparingImport)
          : const ImportProgress(),
    );
    try {
      final result = await operation(epoch);
      if (mounted() && screenController.isCurrentOperation(epoch)) {
        await _complete(result.success, result.fail);
      }
    } catch (error, stackTrace) {
      AppLogger.e('Vibe import failed', error, stackTrace, 'VibeLibrary');
      if (mounted()) await _complete(0, 1);
    } finally {
      screenController.endImportSession();
      screenController.finishOperation(epoch);
    }
  }

  Future<
    ({List<VibeImageImportItem> images, List<PlatformFile> vibes, int failed})
  >
  _categorize(List<PlatformFile> files) async {
    final images = <VibeImageImportItem>[];
    final vibes = <PlatformFile>[];
    var failed = 0;
    for (final file in files) {
      final extension = file.extension?.toLowerCase() ?? '';
      if (_imageExtensions.contains(extension)) {
        try {
          images.add(
            VibeImageImportItem(
              source: file.name,
              bytes: await _readBytes(file),
            ),
          );
        } catch (error, stackTrace) {
          failed++;
          AppLogger.e(
            'Failed to read ${file.name}',
            error,
            stackTrace,
            'VibeLibrary',
          );
        }
      } else if (extension == 'naiv4vibe' || extension == 'naiv4vibebundle') {
        vibes.add(file);
      }
    }
    return (images: images, vibes: vibes, failed: failed);
  }

  Future<({int success, int fail})> _processSources(
    List<VibeImageImportItem> images,
    List<PlatformFile> files,
    int epoch,
  ) async {
    var success = 0;
    var failure = 0;
    final total = images.length + files.length;
    for (var index = 0; index < images.length; index++) {
      final imported = await _processImage(images[index]);
      if (imported == true) success++;
      if (imported == false) failure++;
      screenController.updateProgress(
        epoch,
        ImportProgress(current: index + 1, total: total),
      );
    }
    if (files.isNotEmpty) {
      try {
        var applyAll = false;
        String? batchName;
        final result = await _service.importFromFile(
          files: files,
          categoryId: _categoryId,
          onProgress: (current, _, message) {
            screenController.updateProgress(
              epoch,
              ImportProgress(
                current: images.length + current,
                total: total,
                message: message,
              ),
            );
          },
          onNaming: (suggested, {required isBatch, thumbnail}) async {
            if (isBatch && applyAll && batchName != null) return batchName;
            final naming = await screenController.runDialogLocked(
              () => naming_dialog.VibeImportNamingDialog.show(
                context: context(),
                suggestedName: suggested,
                thumbnail: thumbnail,
                isBatchImport: isBatch,
              ),
            );
            if (naming == null || naming.name.trim().isEmpty) return null;
            if (isBatch && naming.applyToAll) {
              applyAll = true;
              batchName = naming.name.trim();
            }
            return naming.name.trim();
          },
          onBundleOption: _chooseBundle,
        );
        success += result.successCount;
        failure += result.failCount;
      } catch (error, stackTrace) {
        failure += files.length;
        AppLogger.e(
          'Failed to import Vibe files',
          error,
          stackTrace,
          'VibeLibrary',
        );
      }
    }
    return (success: success, fail: failure);
  }

  Future<BundleImportOption?> _chooseBundle(
    String name,
    List<VibeReference> vibes,
  ) async {
    final option = await screenController.runDialogLocked(
      () => bundle_dialog.VibeBundleImportDialog.show(
        context: context(),
        bundleName: name,
        vibeNames: vibes.map((vibe) => vibe.displayName).toList(),
        vibeReferences: vibes,
      ),
    );
    if (option == null) return null;
    return switch (option.option) {
      bundle_dialog.BundleImportOption.keepAsBundle =>
        BundleImportOption.keepAsBundle(
          configuredReferences: option.configuredVibes,
        ),
      bundle_dialog.BundleImportOption.split => BundleImportOption.split(
        configuredReferences: option.configuredVibes,
      ),
      bundle_dialog.BundleImportOption.importSelected =>
        BundleImportOption.select(
          option.selectedIndices ?? const [],
          configuredReferences: option.configuredVibes,
        ),
    };
  }

  Future<bool?> _processImage(VibeImageImportItem image) async {
    try {
      final parsed = await VibeFileParser.parseFile(image.source, image.bytes);
      final encoded = parsed
          .where((vibe) => vibe.vibeEncoding.isNotEmpty)
          .toList();
      if (encoded.isEmpty) return _encodeImage(image);
      if (encoded.length == 1) return _save(encoded.first);
      return _saveBundle(image.source, encoded);
    } on NoVibeDataException {
      return _encodeImage(image);
    } catch (error, stackTrace) {
      if (error.toString().contains('No naiv4vibe metadata')) {
        return _encodeImage(image);
      }
      AppLogger.e(
        'Failed to process ${image.source}',
        error,
        stackTrace,
        'VibeLibrary',
      );
      return false;
    }
  }

  Future<bool?> _saveBundle(String name, List<VibeReference> vibes) async {
    final option = await _chooseBundle(name, vibes);
    if (option == null) return null;
    final configured = option.configuredReferences?.length == vibes.length
        ? option.configuredReferences!
        : vibes;
    final selected = option.selectedIndices == null
        ? configured
        : option.selectedIndices!
              .where((index) => index >= 0 && index < configured.length)
              .map((index) => configured[index])
              .toList();
    if (selected.isEmpty) return null;
    if (option.keepAsBundle) {
      return await ref
              .read(vibeLibraryNotifierProvider.notifier)
              .saveImportedBundle(
                selected,
                name: screenController.reserveUniqueName(name),
                categoryId: _categoryId,
              ) !=
          null;
    }
    var count = 0;
    for (final vibe in selected) {
      if (await _save(vibe)) count++;
    }
    return count > 0;
  }

  Future<bool> _save(VibeReference vibe) async {
    final base = vibe.displayName.trim().isEmpty
        ? 'vibe_${DateTime.now().millisecondsSinceEpoch}'
        : vibe.displayName.trim();
    final entry = VibeLibraryEntry.fromVibeReference(
      name: screenController.reserveUniqueName(base),
      vibeData: vibe,
      categoryId: _categoryId,
    );
    return await ref
            .read(vibeLibraryNotifierProvider.notifier)
            .saveImportedEntry(entry) !=
        null;
  }

  Future<bool?> _encodeImage(VibeImageImportItem image) async {
    final model = ref.read(generationParamsNotifierProvider).model;
    final supportsEncoding = ModelCapabilityRegistry.of(
      model,
    ).supportsEncodedVibeTransfer;
    final config = await screenController.runDialogLocked(
      () => encode_dialog.VibeImageEncodeDialog.show(
        context: context(),
        imageBytes: image.bytes,
        fileName: image.source,
        encodeImage: supportsEncoding,
      ),
    );
    if (config == null || !mounted()) return null;
    if (!supportsEncoding) {
      return _save(
        VibeReference(
          displayName: config.name,
          vibeEncoding: '',
          thumbnail: image.bytes,
          rawImageData: image.bytes,
          strength: config.strength,
          infoExtracted: config.infoExtracted,
          sourceType: VibeSourceType.rawImage,
        ),
      );
    }
    final generation = ref.read(generationParamsNotifierProvider.notifier);
    if (!generation.hasCachedVibeEncoding(
          image.bytes,
          model: model,
          informationExtracted: config.infoExtracted,
        ) &&
        !requireAuthenticatedWidgetAction(ref, AuthPromptReason.vibeEncoding)) {
      return null;
    }

    final l10n = context().l10n;
    while (mounted()) {
      final dialogCompleter = Completer<void>();
      BuildContext? dialogContext;
      unawaited(
        showDialog<void>(
          context: context(),
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (dialogBuildContext) {
            dialogContext = dialogBuildContext;
            if (!dialogCompleter.isCompleted) dialogCompleter.complete();
            return const encode_dialog.VibeImageEncodingDialog();
          },
        ),
      );
      await dialogCompleter.future;

      String? encoding;
      String? errorMessage;
      try {
        encoding = await generation
            .encodeVibeWithCache(
              image.bytes,
              model: model,
              informationExtracted: config.infoExtracted,
              vibeName: config.name,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                errorMessage = l10n.vibeLibrary_encodeTimeout;
                return null;
              },
            );
      } catch (error, stackTrace) {
        errorMessage = '$error';
        AppLogger.e(
          'Vibe 编码失败: ${image.source}',
          error,
          stackTrace,
          'VibeLibrary',
        );
      } finally {
        final currentDialogContext = dialogContext;
        if (currentDialogContext != null && currentDialogContext.mounted) {
          Navigator.of(currentDialogContext).pop();
        }
      }

      if (encoding != null && mounted()) {
        return _save(
          VibeReference(
            displayName: config.name,
            vibeEncoding: encoding,
            thumbnail: image.bytes,
            rawImageData: image.bytes,
            strength: config.strength,
            infoExtracted: config.infoExtracted,
            encodingModel: model,
            sourceType: VibeSourceType.naiv4vibe,
          ),
        );
      }
      if (!mounted()) return null;

      final action = await screenController.runDialogLocked(
        () => encode_dialog.VibeImageEncodeErrorDialog.show(
          context: context(),
          fileName: image.source,
          errorMessage: errorMessage ?? l10n.vibeLibrary_unknownError,
        ),
      );
      if (action == encode_dialog.VibeEncodeErrorAction.skip) return false;
      if (action == null) return null;
    }
    return null;
  }

  Future<Uint8List> _readBytes(PlatformFile file) {
    if (file.bytes != null) return Future.value(file.bytes!);
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw ArgumentError('File path is empty: ${file.name}');
    }
    return File(path).readAsBytes();
  }

  Future<List<String>> _readDropPaths(PerformDropEvent event) async {
    final paths = <String>[];
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null || !reader.canProvide(Formats.fileUri)) continue;
      final completer = Completer<Uri?>();
      final progress = reader.getValue<Uri>(
        Formats.fileUri,
        completer.complete,
        onError: (_) => completer.complete(null),
      );
      if (progress == null) continue;
      final uri = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (uri != null) paths.add(uri.toFilePath());
    }
    return paths;
  }

  Future<void> _complete(int success, int failure) async {
    if (success == 0 && failure == 0) return;
    if (success > 0) {
      await ref.read(vibeLibraryNotifierProvider.notifier).loadFromCache();
      if (!mounted()) return;
    }
    if (failure == 0) {
      AppToast.success(
        context(),
        context().l10n.vibeLibrary_importSuccessCount(success),
      );
    } else {
      AppToast.warning(
        context(),
        context().l10n.vibeLibrary_importSummary(success, failure),
      );
    }
  }
}

typedef VibeDropClassifiedPaths = ({
  List<String> folders,
  List<String> images,
  List<String> vibes,
});

typedef VibeDropPathTypeReader =
    Future<FileSystemEntityType> Function(String path);
typedef VibeDropFolderExistsReader = Future<bool> Function(String path);
typedef VibeDropFolderLister = Stream<FileSystemEntity> Function(String path);

Future<VibeDropClassifiedPaths> _classifyPaths(List<String> paths) =>
    classifyVibeDropPaths(paths);

@visibleForTesting
Future<VibeDropClassifiedPaths> classifyVibeDropPaths(
  List<String> paths, {
  VibeDropPathTypeReader typeReader = _readPathType,
}) async {
  final result = (folders: <String>[], images: <String>[], vibes: <String>[]);
  for (final path in paths) {
    try {
      final type = await typeReader(path);
      if (type == FileSystemEntityType.directory) {
        result.folders.add(path);
      } else if (type == FileSystemEntityType.file) {
        _classifyFile(path, result.images, result.vibes);
      }
    } catch (_) {
      // A stale or inaccessible drop item must not discard the other items.
    }
  }
  return result;
}

Future<FileSystemEntityType> _readPathType(String path) =>
    FileSystemEntity.type(path, followLinks: false);

Future<VibeDropClassifiedPaths> _scanFolder(String path) =>
    scanVibeDropFolder(path);

@visibleForTesting
Future<VibeDropClassifiedPaths> scanVibeDropFolder(
  String path, {
  VibeDropFolderExistsReader existsReader = _folderExists,
  VibeDropFolderLister folderLister = _listFolder,
}) async {
  final result = (folders: <String>[], images: <String>[], vibes: <String>[]);
  try {
    if (!await existsReader(path)) return result;
    await for (final entity in folderLister(path)) {
      if (entity is File) {
        _classifyFile(entity.path, result.images, result.vibes);
      }
    }
  } catch (error, stackTrace) {
    AppLogger.e(
      'Failed to scan folder: $path',
      error,
      stackTrace,
      'VibeLibrary',
    );
  }
  return result;
}

Future<bool> _folderExists(String path) => Directory(path).exists();

Stream<FileSystemEntity> _listFolder(String path) =>
    Directory(path).list(recursive: true, followLinks: false);

void _classifyFile(String path, List<String> images, List<String> vibes) {
  final extension = p.extension(path).toLowerCase().replaceFirst('.', '');
  if (_imageExtensions.contains(extension)) {
    images.add(path);
  } else if (extension == 'naiv4vibe' || extension == 'naiv4vibebundle') {
    vibes.add(path);
  }
}
