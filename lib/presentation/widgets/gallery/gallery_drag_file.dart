import 'dart:async';
import 'dart:io';

import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_share_sanitizer.dart';

/// 临时共享文件随原生数据项存活，不依赖卡片的 hover 或 Widget 生命周期。
class GalleryDragFile {
  GalleryDragFile({
    required this.item,
    required this.session,
    this.writeFile = ImageShareSanitizer.writeTempShareFile,
    this.deleteFile = _deleteFile,
  }) {
    item.onRegistered.addListener(_onRegistered);
    item.onDisposed.addListener(_releaseInBackground);
    session.dragCompleted.addListener(_onDragCompleted);
    _onDragCompleted();
  }

  final DragItem item;
  final DragSession session;
  final ShareImageWriteTempFileFunction writeFile;
  final Future<void> Function(File) deleteFile;
  final _preparationFinished = Completer<void>();
  File? _file;
  bool _registered = false;
  bool _released = false;
  Future<void>? _releaseFuture;

  /// 手势在准备期间取消时不再发布文件，但仍等待写入结束并回收。
  Future<bool> addImage(SanitizedShareImage image) async {
    try {
      if (_released) return false;
      // 同毫秒内的多个拖拽数据项也必须各自拥有文件，不能互相提前删除。
      _file = await writeFile(
        SanitizedShareImage(
          bytes: image.bytes,
          fileName: '${const Uuid().v4()}_${image.fileName}',
          mimeType: image.mimeType,
        ),
      );
      if (_released) return false;
      item.add(Formats.png(image.bytes));
      item.add(Formats.fileUri(_file!.uri));
      return true;
    } catch (_) {
      _releaseInBackground();
      rethrow;
    } finally {
      _preparationFinished.complete();
    }
  }

  void _onRegistered() => _registered = true;

  void _onDragCompleted() {
    // 已注册的数据项可能仍被目标应用读取，必须等待 onDisposed。
    // 未注册的取消手势不会收到 onDisposed，改由会话结束负责回收。
    if (!_registered && session.dragCompleted.value != null) {
      _releaseInBackground();
    }
  }

  void _releaseInBackground() {
    unawaited(
      release().catchError((Object error, StackTrace stack) {
        AppLogger.e(
          'Failed to remove gallery drag file: ${_file?.path}',
          error,
          stack,
          'GalleryDragFile',
        );
      }),
    );
  }

  Future<void> release() {
    if (_releaseFuture != null) return _releaseFuture!;
    _released = true;
    item.onRegistered.removeListener(_onRegistered);
    item.onDisposed.removeListener(_releaseInBackground);
    session.dragCompleted.removeListener(_onDragCompleted);
    return _releaseFuture = _deleteAfterPreparation();
  }

  Future<void> _deleteAfterPreparation() async {
    await _preparationFinished.future;
    final file = _file;
    if (file != null) await deleteFile(file);
    _file = null;
  }

  static Future<void> _deleteFile(File file) async {
    if (await file.exists()) await file.delete();
  }
}
