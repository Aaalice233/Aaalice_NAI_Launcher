import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../../core/derivatives/derivative_render.dart';
import '../../../core/services/system_gallery_publisher.dart';
import '../../../core/utils/localization_extension.dart';
import '../../widgets/common/app_toast.dart';
import 'derivative_copy_saver.dart';

sealed class DerivativeCopySaveOutcome {
  const DerivativeCopySaveOutcome();
}

final class DerivativeCopySaved extends DerivativeCopySaveOutcome {
  const DerivativeCopySaved({required this.copy, required this.outputPath});

  final DerivativeRenderedCopy copy;
  final String outputPath;
}

final class DerivativeCopyCancelled extends DerivativeCopySaveOutcome {
  const DerivativeCopyCancelled();
}

final class DerivativeCopyFailed extends DerivativeCopySaveOutcome {
  const DerivativeCopyFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

/// 编辑器的一次保存副本：写盘开始前关闭编辑器即取消；写盘开始后关闭仍会写完，结果改由根 Overlay 提示。
class DerivativeCopySaveRun {
  DerivativeCopySaveRun({
    required DerivativeCopySaver saver,
    required DerivativeCopySaveNotices notices,
  }) : _saver = saver,
       _notices = notices;

  final DerivativeCopySaver _saver;
  final DerivativeCopySaveNotices _notices;
  final _cancellation = DerivativeRenderCancellationToken();
  bool _closed = false;
  bool _writeStarted = false;

  /// 编辑器已关闭或正在退出，结果不能再在编辑器里呈现。
  bool get isClosed => _closed;

  void close() {
    if (_closed) return;
    _closed = true;
    if (!_writeStarted) _cancellation.cancel();
  }

  /// 写入之后的登记与收录在后台进行，不推迟返回。
  Future<DerivativeCopySaveOutcome> save({
    required Future<DerivativeRenderedCopy> Function(
      DerivativeRenderCancellationToken cancellationToken,
    )
    render,
    required Uint8List sourceBytes,
    String? sourcePath,
  }) async {
    try {
      final copy = await _cancellation.race(render(_cancellation));
      final rootPath = await _cancellation.race(_saver.resolveGalleryRoot());
      if (rootPath == null) throw StateError(_notices.saveDirectoryNotSet);
      _cancellation.throwIfCancelled();
      _writeStarted = true;
      final outputPath = await _saver.write(
        rootPath: rootPath,
        bytes: copy.bytes,
        fileName: copy.fileName,
      );
      _notices.watch(
        _saver.followUp(
          outputPath: outputPath,
          outputBytes: copy.bytes,
          fileName: copy.fileName,
          sourceBytes: sourceBytes,
          sourcePath: sourcePath,
        ),
      );
      if (_closed) _notices.announceSaved(outputPath);
      return DerivativeCopySaved(copy: copy, outputPath: outputPath);
    } on DerivativeRenderCancelledException {
      return const DerivativeCopyCancelled();
    } on Object catch (error, stackTrace) {
      if (_closed) _notices.announceFailed();
      return DerivativeCopyFailed(error, stackTrace);
    }
  }
}

/// 编辑器可能早已关闭，提示文案与根 Overlay 必须在第一个 await 之前取好。
class DerivativeCopySaveNotices {
  DerivativeCopySaveNotices({
    required OverlayState? overlay,
    required this.saveDirectoryNotSet,
    required String saved,
    required String failed,
    required String systemGalleryFailed,
    required String galleryIndexFailed,
  }) : _overlay = overlay,
       _saved = saved,
       _failed = failed,
       _systemGalleryFailed = systemGalleryFailed,
       _galleryIndexFailed = galleryIndexFailed;

  DerivativeCopySaveNotices.capture(
    BuildContext context, {
    required String saved,
    required String failed,
    required String systemGalleryFailed,
    required String galleryIndexFailed,
  }) : this(
         overlay: Overlay.maybeOf(context, rootOverlay: true),
         saveDirectoryNotSet: context.l10n.localGallery_saveDirectoryNotSet,
         saved: saved,
         failed: failed,
         systemGalleryFailed: systemGalleryFailed,
         galleryIndexFailed: galleryIndexFailed,
       );

  final OverlayState? _overlay;
  final String saveDirectoryNotSet;
  final String _saved;
  final String _failed;
  final String _systemGalleryFailed;
  final String _galleryIndexFailed;

  // 文件名取实际写入的路径：同名时写入会追加序号
  void announceSaved(String outputPath) =>
      AppToast.successOnOverlay(_overlay, '$_saved\n${p.basename(outputPath)}');

  void announceFailed() => AppToast.errorOnOverlay(_overlay, _failed);

  void watch(DerivativeCopyFollowUp followUp) {
    unawaited(
      followUp.systemGallery.then((outcome) {
        if (outcome is SystemGalleryPublishFailed) {
          AppToast.warningOnOverlay(_overlay, _systemGalleryFailed);
        }
      }),
    );
    unawaited(
      followUp.galleryIndexed.then((indexed) {
        if (!indexed) AppToast.warningOnOverlay(_overlay, _galleryIndexFailed);
      }),
    );
  }
}
