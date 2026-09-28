import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/platform_capabilities.dart';
import '../utils/app_logger.dart';

/// 音效播放服务
///
/// 管理完成音效播放
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  NotificationService._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  Future<void> _pendingPlayback = Future.value();

  static final AudioContext _notificationAudioContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationEvent,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  static const _managedSoundDirectoryName = 'notification_sounds';

  /// 移动端文件选择器可能只返回临时缓存路径，因此先复制到应用持久目录。
  Future<String> persistCustomSound(String sourcePath) async {
    if (!PlatformCapabilities.operatingSystem.isMobile) {
      return sourcePath;
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Custom sound file does not exist', sourcePath);
    }

    final extension = p.extension(source.path).toLowerCase();
    final supportDirectory = await getApplicationSupportDirectory();
    final managedDirectory = Directory(
      p.join(supportDirectory.path, _managedSoundDirectoryName),
    );
    await managedDirectory.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final target = File(
      p.join(managedDirectory.path, 'notification_$stamp$extension'),
    );
    final temporary = File('${target.path}.importing');

    try {
      await source.copy(temporary.path);
      if (await temporary.length() != await source.length()) {
        throw FileSystemException(
          'Custom sound copy is incomplete',
          temporary.path,
        );
      }
      await temporary.rename(target.path);
      return target.path;
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<void> deleteManagedCustomSound(String? soundPath) async {
    if (soundPath == null || !PlatformCapabilities.operatingSystem.isMobile) {
      return;
    }
    final supportDirectory = await getApplicationSupportDirectory();
    final managedDirectory = p.normalize(
      p.absolute(p.join(supportDirectory.path, _managedSoundDirectoryName)),
    );
    final candidate = p.normalize(p.absolute(soundPath));
    if (!p.isWithin(managedDirectory, candidate)) return;
    final file = File(candidate);
    if (await file.exists()) await file.delete();
  }

  /// 播放完成音效。连续完成的任务串行更新同一个播放器，避免 Android
  /// MediaPlayer 的 stop/setSource 竞争和多个完成音效叠加。
  Future<void> playSound({String? customSoundPath}) {
    final playback = _pendingPlayback.then(
      (_) => _playSound(customSoundPath: customSoundPath),
    );
    _pendingPlayback = playback.catchError((_) {});
    return playback;
  }

  Future<void> _playSound({String? customSoundPath}) async {
    try {
      final hasCustomSound =
          customSoundPath != null && await File(customSoundPath).exists();
      final source = hasCustomSound
          ? DeviceFileSource(customSoundPath)
          : AssetSource('sounds/notification.mp3');

      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.play(source, ctx: _notificationAudioContext);
      AppLogger.d(
        hasCustomSound
            ? 'Playing custom completion sound'
            : 'Playing default completion sound',
        'NotificationService',
      );
    } catch (error, stackTrace) {
      // 音效失败不得改变已完成的生成任务状态。
      AppLogger.e(
        'Failed to play completion sound',
        error,
        stackTrace,
        'NotificationService',
      );
    }
  }

  /// 触发完成音效
  Future<void> notifyGenerationComplete({
    required bool playSound,
    String? customSoundPath,
  }) async {
    if (playSound) {
      await this.playSound(customSoundPath: customSoundPath);
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
