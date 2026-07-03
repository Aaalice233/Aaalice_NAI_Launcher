import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/cache/danbooru_image_cache_manager.dart';
import '../../../core/utils/app_logger.dart';

/// 简洁视频播放器组件
///
/// 功能特性：
/// - 极简控制：仅播放/暂停 + 进度条
/// - 点击视频画面切换播放/暂停
/// - 底部细长进度条（可拖动）
/// - 中央半透明播放/暂停图标（淡入淡出）
/// - 自动播放 + 循环播放
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  static int _activeVideoPlayers = 0;

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;
  bool _registeredActivePlayer = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: onlineGalleryImageHeadersForUrl(widget.videoUrl),
      );

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();

      _registeredActivePlayer = true;
      _activeVideoPlayers++;
      AppLogger.d(
        'Online gallery video player initialized: '
            'source=${describeOnlineGalleryVideoSourceForDiagnostics(widget.videoUrl)}, '
            'active=$_activeVideoPlayers',
        'OnlineGalleryVideo',
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'Online gallery video player initialization failed: '
            'source=${describeOnlineGalleryVideoSourceForDiagnostics(widget.videoUrl)}, '
            'errorType=${e.runtimeType}',
        null,
        stackTrace,
        'OnlineGalleryVideo',
      );
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    if (_registeredActivePlayer) {
      if (_activeVideoPlayers > 0) {
        _activeVideoPlayers--;
      }
      AppLogger.d(
        'Online gallery video player disposed: '
            'source=${describeOnlineGalleryVideoSourceForDiagnostics(widget.videoUrl)}, '
            'active=$_activeVideoPlayers',
        'OnlineGalleryVideo',
      );
    }
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }

    setState(() {
      _showControls = true;
    });

    // 播放时3秒后隐藏控制
    if (_controller!.value.isPlaying) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller!.value.isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _onTap() {
    if (!_isInitialized) return;

    _togglePlayPause();
  }

  @override
  Widget build(BuildContext context) {
    // 错误状态
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                '视频加载失败',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 加载状态
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: GestureDetector(
        onTap: _onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 视频画面
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
            OnlineGalleryVideoControls(
              valueListenable: _controller!,
              showControls: _showControls,
              onTogglePlayPause: _togglePlayPause,
              onSeek: _controller!.seekTo,
            ),
          ],
        ),
      ),
    );
  }
}

class OnlineGalleryVideoControls extends StatelessWidget {
  const OnlineGalleryVideoControls({
    super.key,
    required this.valueListenable,
    required this.showControls,
    required this.onTogglePlayPause,
    required this.onSeek,
  });

  final ValueListenable<VideoPlayerValue> valueListenable;
  final bool showControls;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: valueListenable,
      builder: (context, value, child) {
        final isPlaying = value.isPlaying;
        final position = value.position;
        final duration = value.duration;
        final progress = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds)
                  .clamp(0.0, 1.0)
                  .toDouble()
            : 0.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: showControls && !isPlaying ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: onTogglePlayPause,
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatVideoDuration(position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10,
                            ),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            thumbColor: Colors.white,
                            overlayColor: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: progress,
                            onChanged: (sliderValue) {
                              onSeek(
                                Duration(
                                  milliseconds:
                                      (sliderValue * duration.inMilliseconds)
                                          .round(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatVideoDuration(duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String describeOnlineGalleryVideoSourceForDiagnostics(String videoUrl) {
  final uri = Uri.tryParse(videoUrl);
  if (uri == null || uri.scheme.isEmpty) {
    return 'invalid-url';
  }

  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
  final fileName = segments.isEmpty ? '' : '/${segments.last}';
  final host = uri.host.isEmpty ? 'local' : uri.host;
  return '${uri.scheme}://$host$fileName';
}

String _formatVideoDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
