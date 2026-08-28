import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/file_name_sanitizer.dart';
import '../../core/utils/novelai_vibe_codec.dart';
import '../../core/utils/vibe_library_path_helper.dart';

/// Streams cloud resources into the canonical Vibe library directory.
class VibePortableFileStore {
  static const _singleExtension = '.naiv4vibe';
  static const _bundleExtension = '.naiv4vibebundle';

  Future<int> fileLength(String filePath) => File(filePath).length();

  Future<bool> exists(String filePath) => File(filePath).exists();

  Stream<List<int>> openRead(String filePath) => File(filePath).openRead();

  Future<String> import(
    Stream<List<int>> bytes, {
    required String fileName,
  }) async {
    final extension = p.extension(fileName).toLowerCase();
    if (extension != _singleExtension && extension != _bundleExtension) {
      throw const FormatException('Unsupported portable Vibe file type');
    }

    final directory = Directory(await VibeLibraryPathHelper.instance.getPath());
    await directory.create(recursive: true);
    final baseName = FileNameSanitizer.sanitize(
      p.basenameWithoutExtension(fileName),
      fallback: 'vibe',
      maxLength: 120,
    );
    final target = File(
      p.join(directory.path, await _uniqueName(directory, baseName, extension)),
    );
    final staged = File('${target.path}.cloud-import');
    IOSink? sink;
    try {
      sink = staged.openWrite(mode: FileMode.writeOnly);
      await sink.addStream(bytes);
      await sink.flush();
      await sink.close();
      sink = null;
      await _validate(staged, extension);
      await staged.rename(target.path);
      return target.path;
    } catch (_) {
      await sink?.close();
      if (await staged.exists()) await staged.delete();
      rethrow;
    }
  }

  Future<String> _uniqueName(
    Directory directory,
    String baseName,
    String extension,
  ) async {
    var candidate = '$baseName$extension';
    var counter = 2;
    while (await File(p.join(directory.path, candidate)).exists()) {
      candidate = '$baseName ($counter)$extension';
      counter++;
    }
    return candidate;
  }

  Future<void> _validate(File file, String extension) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Portable Vibe document must be an object');
    }
    if (extension == _singleExtension &&
        !NovelAiVibeCodec.validateSingleMap(decoded)) {
      throw const FormatException('Invalid portable Vibe document');
    }
    if (extension == _bundleExtension && decoded['vibes'] is! List) {
      throw const FormatException('Invalid portable Vibe bundle');
    }
  }
}
