import 'dart:io';
import 'dart:typed_data';

import '../../../core/agent/harness/harness_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import 'generated_image_export_writer.dart';
import 'generation_image_read_contract.dart';
import 'generation_preparation_runtime.dart';
import 'generation_save_path_template.dart';
import 'image_resource_action_service.dart';

/// Writes finished images to the target chosen at preparation time, or points
/// at the gallery original when no copy is needed.
/// Failures are outcomes, never throws: the generation is already paid for and
/// must not be repeated because a file could not be written.
final class GenerationSavePathExporter {
  GenerationSavePathExporter({
    required GeneratedImageExportWriter writer,
    ImageResourceExportPreparer? prepareExport,
  }) : _writer = writer,
       _prepareExport = prepareExport;

  final GeneratedImageExportWriter _writer;
  final ImageResourceExportPreparer? _prepareExport;

  Future<GeneratedImageExportOutcome> export({
    required GenerationSavePathSource source,
    required String id,
    required int index,
    required int total,
    required int? seed,
    required Uint8List? bytes,
    required String label,
    String? template,
    String? originalPath,
  }) async {
    if (source == GenerationSavePathSource.galleryOriginal) {
      return _referenceOriginal(originalPath);
    }
    if (bytes == null) {
      return const GeneratedImageExportOutcome.failed(
        errorCode: 'image_unavailable',
        errorMessage:
            'The finished image had no bytes to write; it was not saved.',
      );
    }

    final String destination;
    try {
      destination = GenerationSavePathTemplate.expand(
        template ?? '',
        index: index,
        total: total,
        seed: seed,
        id: id,
      );
    } on GenerationSavePathSeedUnavailable {
      return const GeneratedImageExportOutcome.failed(
        errorCode: 'seed_unavailable',
        errorMessage:
            'save_path uses {seed} but this image reported no seed; it was '
            'not saved.',
      );
    }

    final Uint8List outgoing;
    if (_prepareExport case final prepare?) {
      try {
        outgoing = (await prepare(
          ResolvedImageResourceActionSource(label: label, bytes: bytes),
        )).bytes;
      } on Object {
        return const GeneratedImageExportOutcome.failed(
          errorCode: 'image_export_preparation_failed',
          errorMessage:
              'The image could not be prepared under the current sharing '
              'policy. Nothing was written and original bytes were not used '
              'as a fallback.',
        );
      }
    } else {
      outgoing = bytes;
    }

    return _write(destination, outgoing, source: source);
  }

  Future<GeneratedImageExportOutcome> _write(
    String destination,
    Uint8List outgoing, {
    required GenerationSavePathSource source,
  }) async {
    final mimeType = detectSupportedImageMimeType(outgoing);
    if (mimeType == null) {
      return const GeneratedImageExportOutcome.failed(
        errorCode: 'unsupported_image',
        errorMessage: 'The prepared image format is not supported for export.',
      );
    }

    final prepared = await _writer.prepareTarget(
      destination,
      mimeType: mimeType,
    );
    if (prepared.errorOrNull case final failure?) {
      return _prepareFailure(failure.kind);
    }
    final target = prepared.valueOrNull!;

    final writeFailure = await _writer.write(target, outgoing);
    if (writeFailure != null) return _writeFailure(writeFailure);

    return GeneratedImageExportOutcome.saved(
      target.absolutePath.replaceAll(r'\', '/'),
      source: source,
    );
  }

  /// 图库原图就是成品，引用它时不写任何文件。
  Future<GeneratedImageExportOutcome> _referenceOriginal(
    String? originalPath,
  ) async {
    if (originalPath == null || !await File(originalPath).exists()) {
      return const GeneratedImageExportOutcome.failed(
        errorCode: 'original_unavailable',
        errorMessage:
            'This image was never written to the gallery, so there is no '
            'original file to reference. Turn on automatic saving or pass an '
            'explicit save_path.',
      );
    }
    return GeneratedImageExportOutcome.saved(
      originalPath.replaceAll(r'\', '/'),
      source: GenerationSavePathSource.galleryOriginal,
    );
  }

  static GeneratedImageExportOutcome _prepareFailure(
    GeneratedImageExportFailureKind kind,
  ) => switch (kind) {
    GeneratedImageExportFailureKind.invalidTarget =>
      const GeneratedImageExportOutcome.failed(
        errorCode: 'invalid_save_path',
        errorMessage: 'save_path must identify a file, not a directory.',
      ),
    GeneratedImageExportFailureKind.extensionMismatch =>
      const GeneratedImageExportOutcome.failed(
        errorCode: 'invalid_save_path',
        errorMessage:
            'save_path must use an extension matching the prepared image '
            'format.',
      ),
    GeneratedImageExportFailureKind.outsideScope ||
    GeneratedImageExportFailureKind.unsafeChange =>
      const GeneratedImageExportOutcome.failed(
        errorCode: 'save_path_not_permitted',
        errorMessage: 'save_path is outside the permitted file scope.',
      ),
    GeneratedImageExportFailureKind.parentUnavailable ||
    GeneratedImageExportFailureKind.parentUnresolvable =>
      const GeneratedImageExportOutcome.failed(
        errorCode: 'destination_unavailable',
        errorMessage:
            'The save_path directory could not be created or resolved safely.',
      ),
    GeneratedImageExportFailureKind.checkFailed =>
      const GeneratedImageExportOutcome.failed(
        errorCode: 'destination_check_failed',
        errorMessage: 'The save_path destination could not be checked safely.',
      ),
    GeneratedImageExportFailureKind.exists =>
      const GeneratedImageExportOutcome.failed(
        errorCode: 'destination_exists',
        errorMessage:
            'The save_path destination already exists; images are never '
            'overwritten.',
      ),
    GeneratedImageExportFailureKind.writeFailed =>
      const GeneratedImageExportOutcome.failed(
        errorCode: 'save_failed',
        errorMessage: 'The image could not be written to save_path.',
      ),
  };

  static GeneratedImageExportOutcome _writeFailure(
    GeneratedImageExportFailure failure,
  ) => switch (failure.kind) {
    GeneratedImageExportFailureKind.exists =>
      const GeneratedImageExportOutcome.failed(
        errorCode: 'destination_exists',
        errorMessage:
            'The save_path destination already exists; images are never '
            'overwritten.',
      ),
    GeneratedImageExportFailureKind.unsafeChange =>
      const GeneratedImageExportOutcome.failed(
        errorCode: 'save_path_not_permitted',
        errorMessage:
            'The save_path destination changed outside the permitted file '
            'scope.',
      ),
    _ => GeneratedImageExportOutcome.failed(
      errorCode: 'save_failed',
      errorMessage:
          'The image failed during the exclusive file write'
          '${failure.error == null ? '' : ' (${failure.error.runtimeType})'}.',
    ),
  };
}
