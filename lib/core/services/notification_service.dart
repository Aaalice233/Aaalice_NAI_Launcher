import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import '../utils/app_logger.dart';

/// 音效播放服务
///
/// 管理完成音效播放
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  NotificationService._();

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// 播放完成音效
  Future<void> playSound({String? customSoundPath}) async {
    try {
      if (customSoundPath != null && File(customSoundPath).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(customSoundPath));
        AppLogger.d(
          'Playing custom sound: $customSoundPath',
          'NotificationService',
        );
      } else {
        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
        AppLogger.d('Playing default sound', 'NotificationService');
      }
    } catch (e) {
      // 音效播放失败不阻塞
      AppLogger.e('Failed to play sound: $e', 'NotificationService');
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
