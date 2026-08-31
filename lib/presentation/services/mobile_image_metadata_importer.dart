import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/localization_extension.dart';
import '../utils/dropped_file_reader.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/drop/global_drop_action_coordinator.dart';

class PickedImageData {
  const PickedImageData({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

typedef ImageBytesPicker = Future<PickedImageData?> Function();
typedef PickedImageProcessor =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      PickedImageData image,
    );

/// Adapts a system-picked image to the shared desktop drop action flow.
class MobileImageMetadataImporter {
  MobileImageMetadataImporter({
    ImageBytesPicker? imageBytesPicker,
    PickedImageProcessor? imageProcessor,
  }) : _imageBytesPicker = imageBytesPicker ?? _pickImageBytes,
       _imageProcessor = imageProcessor ?? _processImage;

  static final MobileImageMetadataImporter shared =
      MobileImageMetadataImporter();

  final ImageBytesPicker _imageBytesPicker;
  final PickedImageProcessor _imageProcessor;

  Future<void> run({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final PickedImageData image;
    try {
      final selectedImage = await _imageBytesPicker();
      if (selectedImage == null || !context.mounted) return;
      image = selectedImage;
      if (image.bytes.isEmpty) {
        throw const FormatException('Selected image is empty');
      }
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to read selected image',
        error,
        stackTrace,
        'MobileMetadataImport',
      );
      if (context.mounted) {
        AppToast.error(context, context.l10n.metadataImport_readFailed);
      }
      return;
    }

    try {
      await _imageProcessor(context, ref, image);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to process selected image',
        error,
        stackTrace,
        'MobileMetadataImport',
      );
      if (context.mounted) {
        AppToast.error(context, context.l10n.metadataImport_processFailed);
      }
    }
  }

  static Future<PickedImageData?> _pickImageBytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError(
        'The system picker did not provide readable image bytes',
      );
    }
    return PickedImageData(fileName: file.name, bytes: bytes);
  }

  static Future<void> _processImage(
    BuildContext context,
    WidgetRef ref,
    PickedImageData image,
  ) {
    return GlobalDropActionCoordinator(
      context: context,
      ref: ref,
      openGenerationAfterAction: true,
      respectCurrentRouteDropTarget: false,
    ).processDroppedFile(
      DroppedFileData(fileName: image.fileName, bytes: image.bytes),
    );
  }
}
