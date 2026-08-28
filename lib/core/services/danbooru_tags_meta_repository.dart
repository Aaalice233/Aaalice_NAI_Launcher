import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/cache/data_source_cache_meta.dart';
import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import 'danbooru_tags_protocol.dart';

class DanbooruTagsMetaRepository {
  static const _cacheDirName = 'tag_cache';
  static const _metaFileName = 'danbooru_tags_meta.json';

  Future<void> loadInto(DanbooruTagsState state) => _load(state);

  Future<void> _load(DanbooruTagsState state) async {
    try {
      var thresholds = state.thresholds;
      final metaFile = await _metaFile();
      if (await metaFile.exists()) {
        final decoded = jsonDecode(await metaFile.readAsString());
        if (decoded is Map<String, dynamic>) {
          final lastUpdate = decoded['lastUpdate'];
          if (lastUpdate is String) {
            state.lastUpdate = DateTime.parse(lastUpdate);
          }
          thresholds = thresholds.copyWith(
            general:
                decoded['generalThreshold'] as int? ??
                decoded['hotThreshold'] as int? ??
                thresholds.general,
          );
        }
      }

      final prefs = await SharedPreferences.getInstance();
      state.thresholds = thresholds.copyWith(
        general: prefs.getInt(StorageKeys.danbooruGeneralThreshold),
        artist: prefs.getInt(StorageKeys.danbooruArtistThreshold),
        character: prefs.getInt(StorageKeys.danbooruCharacterThreshold),
        copyright: prefs.getInt(StorageKeys.danbooruCopyrightThreshold),
        meta: prefs.getInt(StorageKeys.danbooruMetaThreshold),
      );
      final days = prefs.getInt(StorageKeys.danbooruTagsRefreshIntervalDays);
      if (days != null) {
        state.refreshInterval = AutoRefreshInterval.fromDays(days);
      }
    } catch (error) {
      AppLogger.w(
        'Failed to load Danbooru tags meta: $error',
        'DanbooruTagsLazy',
      );
    }
  }

  Future<void> saveThresholds(DanbooruCategoryThresholds thresholds) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(StorageKeys.danbooruGeneralThreshold, thresholds.general),
      prefs.setInt(StorageKeys.danbooruArtistThreshold, thresholds.artist),
      prefs.setInt(
        StorageKeys.danbooruCharacterThreshold,
        thresholds.character,
      ),
      prefs.setInt(
        StorageKeys.danbooruCopyrightThreshold,
        thresholds.copyright,
      ),
      prefs.setInt(StorageKeys.danbooruMetaThreshold, thresholds.meta),
    ]);
  }

  Future<void> saveRefreshInterval(AutoRefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      StorageKeys.danbooruTagsRefreshIntervalDays,
      interval.days,
    );
  }

  Future<void> save(DanbooruTagsState state, int totalTags) async {
    try {
      final now = DateTime.now();
      final thresholds = state.thresholds;
      await (await _metaFile()).writeAsString(
        jsonEncode({
          'lastUpdate': now.toIso8601String(),
          'totalTags': totalTags,
          'generalThreshold': thresholds.general,
          'artistThreshold': thresholds.artist,
          'characterThreshold': thresholds.character,
          'copyrightThreshold': thresholds.copyright,
          'metaThreshold': thresholds.meta,
          'version': 3,
        }),
      );
      state.lastUpdate = now;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        StorageKeys.danbooruTagsLastUpdate,
        now.millisecondsSinceEpoch,
      );
    } catch (error) {
      AppLogger.w(
        'Failed to save Danbooru tags meta: $error',
        'DanbooruTagsLazy',
      );
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(StorageKeys.danbooruTagsLastUpdate),
      prefs.remove(StorageKeys.danbooruTagsRefreshIntervalDays),
      prefs.remove(StorageKeys.danbooruGeneralThreshold),
      prefs.remove(StorageKeys.danbooruArtistThreshold),
      prefs.remove(StorageKeys.danbooruCharacterThreshold),
      prefs.remove(StorageKeys.danbooruCopyrightThreshold),
      prefs.remove(StorageKeys.danbooruMetaThreshold),
    ]);
    final file = await _metaFile();
    if (await file.exists()) await file.delete();
  }

  Future<File> _metaFile() async {
    final appDirectory = await getApplicationSupportDirectory();
    final directory = Directory('${appDirectory.path}/$_cacheDirName');
    await directory.create(recursive: true);
    return File('${directory.path}/$_metaFileName');
  }
}
