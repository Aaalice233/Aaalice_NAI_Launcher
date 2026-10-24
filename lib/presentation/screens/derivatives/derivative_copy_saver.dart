import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/derivatives/derivative_registry.dart';
import '../../../core/save_naming/image_save_naming.dart';
import '../../../core/save_naming/save_name_context.dart';
import '../../../core/services/system_gallery_publisher.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_save_utils.dart';
import '../../../data/models/gallery/gallery_index_admission.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../../data/services/fixed_tag/fixed_tag_usage_record_store.dart';
import '../../providers/image_save_settings_provider.dart';
import '../../providers/local_gallery_provider.dart';

typedef DerivativeGalleryWriter =
    Future<String> Function({
      required String rootPath,
      required Uint8List bytes,
      required ImageSaveNaming naming,
      required SaveNameContext context,
      String? preferredFileName,
      String protectedSuffix,
    });

typedef DerivativeRegistration =
    Future<void> Function({
      required String outputPath,
      required String sourcePath,
    });

// 实现须自行记录并吞掉失败：副本此时已落盘
typedef DerivativeFixedTagUsageCopier =
    Future<void> Function({
      required Uint8List sourceBytes,
      required Uint8List outputBytes,
    });

// keepAlive：编辑器卸载后写入之后的步骤仍要用这些句柄跑完
final derivativeCopySaverProvider =
    Provider.family<DerivativeCopySaver, DerivativeKind>((ref, kind) {
      final gallery = ref.read(localGalleryNotifierProvider.notifier);
      return DerivativeCopySaver(
        kind: kind,
        resolveGalleryRootPath: GalleryFolderRepository.instance.getRootPath,
        resolveNaming: () => ref.read(imageSaveSettingsNotifierProvider).naming,
        resolveSystemGallery: () => ref.read(systemGalleryPublisherProvider),
        registerDerivative: DerivativeRegistry(
          ref.read(localStorageServiceProvider),
          kind,
        ).register,
        copyFixedTagUsage: FixedTagUsageRecordStore().copyForDerivative,
        addGalleryImages: gallery.addNewlySavedImages,
      );
    });

/// 衍生副本写入图库，以及写入之后的登记与图库收录。
class DerivativeCopySaver {
  DerivativeCopySaver({
    required this.kind,
    required Future<String?> Function() resolveGalleryRootPath,
    required ImageSaveNaming Function() resolveNaming,
    required SystemGalleryPublisher Function() resolveSystemGallery,
    required DerivativeRegistration registerDerivative,
    required DerivativeFixedTagUsageCopier copyFixedTagUsage,
    required Future<GalleryIndexAdmission> Function(List<String> filePaths)
    addGalleryImages,
    DerivativeGalleryWriter? writeToGallery,
  }) : _resolveGalleryRootPath = resolveGalleryRootPath,
       _resolveNaming = resolveNaming,
       _resolveSystemGallery = resolveSystemGallery,
       _registerDerivative = registerDerivative,
       _copyFixedTagUsage = copyFixedTagUsage,
       _addGalleryImages = addGalleryImages,
       _writeToGallery = writeToGallery ?? ImageSaveUtils.saveBytesToGallery;

  static const _logTag = 'DerivativeCopySaver';

  final DerivativeKind kind;
  final Future<String?> Function() _resolveGalleryRootPath;
  final ImageSaveNaming Function() _resolveNaming;
  final SystemGalleryPublisher Function() _resolveSystemGallery;
  final DerivativeRegistration _registerDerivative;
  final DerivativeFixedTagUsageCopier _copyFixedTagUsage;
  final Future<GalleryIndexAdmission> Function(List<String> filePaths)
  _addGalleryImages;
  final DerivativeGalleryWriter _writeToGallery;

  /// 图库根目录未设置时返回 null。
  Future<String?> resolveGalleryRoot() async {
    final rootPath = await _resolveGalleryRootPath();
    return rootPath == null || rootPath.isEmpty ? null : rootPath;
  }

  /// 返回写入的文件路径；同名时自动追加序号，不覆盖已有文件。
  Future<String> write({
    required String rootPath,
    required Uint8List bytes,
    required String fileName,
  }) => _writeToGallery(
    rootPath: rootPath,
    bytes: bytes,
    naming: _resolveNaming(),
    context: SaveNameContext(createdAt: DateTime.now()),
    preferredFileName: fileName,
    protectedSuffix: kind.fileNameSuffix,
  );

  /// 各步骤立即并行开始、互不等待：图库扫描排队或后台计算拥堵只拖慢自己那一步。
  DerivativeCopyFollowUp followUp({
    required String outputPath,
    required Uint8List outputBytes,
    required String fileName,
    required Uint8List sourceBytes,
    String? sourcePath,
  }) => DerivativeCopyFollowUp(
    registered: _register(outputPath, sourcePath),
    fixedTagUsageCopied: _copyFixedTagUsage(
      sourceBytes: sourceBytes,
      outputBytes: outputBytes,
    ),
    systemGallery: _publish(outputBytes, fileName),
    galleryIndexed: _indexInGallery(outputPath),
  );

  Future<void> _register(String outputPath, String? sourcePath) async {
    if (sourcePath == null) return;
    try {
      await _registerDerivative(outputPath: outputPath, sourcePath: sourcePath);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Derivative copy saved but its source link was not registered',
        error,
        stackTrace,
        _logTag,
      );
    }
  }

  Future<SystemGalleryPublishOutcome> _publish(
    Uint8List bytes,
    String fileName,
  ) async {
    SystemGalleryPublishOutcome outcome;
    try {
      outcome = await _resolveSystemGallery().publishPng(
        bytes: bytes,
        fileName: fileName,
      );
    } on Object catch (error, stackTrace) {
      outcome = SystemGalleryPublishFailed(error, stackTrace);
    }
    if (outcome case SystemGalleryPublishFailed(
      :final error,
      :final stackTrace,
    )) {
      AppLogger.e(
        'Derivative copy saved but system gallery export failed',
        error,
        stackTrace,
        _logTag,
      );
    }
    return outcome;
  }

  // 只收录这一张；失败已由图库服务按单张重试，全量重扫修不了单张写不进去的图
  Future<bool> _indexInGallery(String outputPath) async {
    try {
      final admission = await _addGalleryImages([outputPath]);
      return admission != GalleryIndexAdmission.failed;
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Derivative copy saved but gallery indexing failed',
        error,
        stackTrace,
        _logTag,
      );
      return false;
    }
  }
}

/// 写入之后的各步骤；每个 Future 都不会抛错，失败已记录日志。
class DerivativeCopyFollowUp {
  const DerivativeCopyFollowUp({
    required this.registered,
    required this.fixedTagUsageCopied,
    required this.systemGallery,
    required this.galleryIndexed,
  });

  final Future<void> registered;
  final Future<void> fixedTagUsageCopied;
  final Future<SystemGalleryPublishOutcome> systemGallery;
  final Future<bool> galleryIndexed;
}
