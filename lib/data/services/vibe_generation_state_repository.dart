import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import 'vibe_library_storage_protocol.dart';

/// Persists generation state in a document, with the historical preference key
/// retained as a read/write fallback.
typedef VibeGenerationStateFileResolver =
    Future<File?> Function({required bool createDirectory});

class VibeGenerationStateRepository
    implements VibeGenerationStateRepositoryProtocol {
  VibeGenerationStateRepository({VibeGenerationStateFileResolver? fileResolver})
    : _fileResolver = fileResolver;

  static const generationStateKey = 'generation_state';
  static const generationStateFileName = 'generation_state.json';
  static const _tag = 'VibeLibrary';

  final VibeGenerationStateFileResolver? _fileResolver;
  String? _filePath;

  Future<File?> _resolveFile({required bool createDirectory}) async {
    try {
      final injectedResolver = _fileResolver;
      if (injectedResolver != null) {
        return await injectedResolver(createDirectory: createDirectory);
      }
      final cached = _filePath;
      if (cached != null) {
        final file = File(cached);
        if (createDirectory) await file.parent.create(recursive: true);
        return file;
      }
      final appDir = await getApplicationSupportDirectory();
      final directory = Directory(p.join(appDir.path, 'generation_state'));
      if (createDirectory) await directory.create(recursive: true);
      final file = File(p.join(directory.path, generationStateFileName));
      _filePath = file.path;
      return file;
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to resolve generation state file, falling back to SharedPreferences',
        error,
        stackTrace,
        _tag,
      );
      return null;
    }
  }

  @override
  Future<void> saveJson(String stateJson) async {
    final file = await _resolveFile(createDirectory: true);
    if (file != null) {
      try {
        await file.writeAsString(stateJson);
        unawaited(_removeLegacyPreference());
        return;
      } catch (error, stackTrace) {
        AppLogger.e(
          'Failed to write generation state file, falling back to SharedPreferences',
          error,
          stackTrace,
          _tag,
        );
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(generationStateKey, stateJson);
  }

  @override
  Future<String?> loadJson() async {
    final file = await _resolveFile(createDirectory: false);
    if (file != null) {
      try {
        if (await file.exists()) return file.readAsString();
      } catch (error, stackTrace) {
        AppLogger.e(
          'Failed to read generation state file, falling back to SharedPreferences',
          error,
          stackTrace,
          _tag,
        );
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(generationStateKey);
  }

  Future<void> _removeLegacyPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(generationStateKey)) {
      await prefs.remove(generationStateKey);
    }
  }

  @override
  Future<void> clear() async {
    final file = await _resolveFile(createDirectory: false);
    if (file != null && await file.exists()) await file.delete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(generationStateKey);
  }
}
