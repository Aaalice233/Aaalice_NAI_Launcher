import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WatermarkLogoException implements Exception {
  const WatermarkLogoException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class WatermarkLogoService {
  const WatermarkLogoService();

  static const _extensions = ['png', 'jpg', 'jpeg', 'webp'];
  static const _maxFileBytes = 32 * 1024 * 1024;
  static const _maxDimension = 8192;
  static const _maxPixels = 32000000;

  Future<String?> pickAndImport({String? dialogTitle}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensions,
      allowMultiple: false,
      withData: false,
      dialogTitle: dialogTitle,
    );
    final selectedPath = result?.files.single.path;
    if (selectedPath == null) return null;
    return importFromPath(selectedPath);
  }

  Future<String> importFromPath(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const WatermarkLogoException('The selected logo no longer exists.');
    }
    final stat = await source.stat();
    if (stat.size <= 0 || stat.size > _maxFileBytes) {
      throw const WatermarkLogoException(
        'The logo must be a non-empty image smaller than 32 MiB.',
      );
    }
    final extension = p
        .extension(source.path)
        .toLowerCase()
        .replaceFirst('.', '');
    if (!_extensions.contains(extension)) {
      throw const WatermarkLogoException(
        'Choose a static PNG, JPEG, or WebP logo.',
      );
    }
    final bytes = await source.readAsBytes();
    await validate(bytes);

    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'watermark'));
    await directory.create(recursive: true);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final target = File(p.join(directory.path, 'logo_$suffix.$extension'));
    final temporary = File('${target.path}.importing');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      return (await temporary.rename(target.path)).path;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> deleteManaged(String path) async {
    final support = await getApplicationSupportDirectory();
    final managedDirectory = p.normalize(p.join(support.path, 'watermark'));
    final candidate = p.normalize(path);
    if (p.dirname(candidate) != managedDirectory) return;
    final file = File(candidate);
    if (await file.exists()) await file.delete();
  }

  Future<Uint8List> readValidated(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const WatermarkLogoException(
        'The saved logo is missing. Choose the logo again.',
      );
    }
    final bytes = await file.readAsBytes();
    await validate(bytes);
    return bytes;
  }

  Future<void> validate(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 ||
          descriptor.height <= 0 ||
          descriptor.width > _maxDimension ||
          descriptor.height > _maxDimension ||
          descriptor.width * descriptor.height > _maxPixels) {
        throw const WatermarkLogoException(
          'The logo dimensions are invalid or too large.',
        );
      }
      codec = await descriptor.instantiateCodec();
      if (codec.frameCount != 1) {
        throw const WatermarkLogoException(
          'Animated logos are not supported. Choose a static image.',
        );
      }
      image = (await codec.getNextFrame()).image;
    } on WatermarkLogoException {
      rethrow;
    } on Object catch (error) {
      throw WatermarkLogoException(
        'The logo is damaged or unsupported.',
        error,
      );
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
