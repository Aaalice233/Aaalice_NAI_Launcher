import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nai_launcher/core/derivatives/derivative_registry.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/save_naming/image_save_naming.dart';
import 'package:nai_launcher/core/save_naming/save_name_context.dart';
import 'package:nai_launcher/core/services/system_gallery_publisher.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/presentation/screens/derivatives/derivative_copy_saver.dart';
import 'package:path/path.dart' as p;

/// 写入立即成功、写入之后的每一步都挂起，直到用例逐一放行。
class PendingDerivativeCopySaver {
  PendingDerivativeCopySaver(this.kind);

  static const galleryRoot = 'gallery-root';

  final DerivativeKind kind;
  final registering = Completer<void>();
  final copyingUsage = Completer<void>();
  final publishing = Completer<void>();
  final indexing = Completer<GalleryIndexAdmission>();
  final rescanning = Completer<Object?>();
  final writes = <String>[];
  final admissions = <List<String>>[];

  late final DerivativeCopySaver saver = DerivativeCopySaver(
    kind: kind,
    resolveGalleryRootPath: () async => galleryRoot,
    resolveNaming: () => ImageSaveNaming.standard,
    resolveSystemGallery: () => SystemGalleryPublisher(
      syncEnabled: true,
      capabilities: PlatformCapabilities.forPlatform(TargetPlatform.android),
      writeImage: (bytes, fileName, mimeType) => publishing.future,
    ),
    registerDerivative: ({required outputPath, required sourcePath}) =>
        registering.future,
    copyFixedTagUsage: ({required sourceBytes, required outputBytes}) =>
        copyingUsage.future,
    addGalleryImages: (filePaths) {
      admissions.add(filePaths);
      return indexing.future;
    },
    rescanGallery: () => rescanning.future,
    writeToGallery: _write,
  );

  String outputPathFor(String fileName) => p.join(galleryRoot, fileName);

  /// 用例结束前把仍未放行的步骤按成功收尾，不留下挂起的 Future。
  void releaseAll() {
    if (!registering.isCompleted) registering.complete();
    if (!copyingUsage.isCompleted) copyingUsage.complete();
    if (!publishing.isCompleted) publishing.complete();
    if (!indexing.isCompleted) indexing.complete(GalleryIndexAdmission.added);
    if (!rescanning.isCompleted) rescanning.complete(null);
  }

  Future<String> _write({
    required String rootPath,
    required Uint8List bytes,
    required ImageSaveNaming naming,
    required SaveNameContext context,
    String? preferredFileName,
    String protectedSuffix = '',
  }) async {
    final path = p.join(rootPath, preferredFileName ?? 'copy$protectedSuffix');
    writes.add(path);
    return path;
  }
}
