import 'dart:typed_data';

import '../../../data/models/image/image_params.dart';
import '../../../data/models/image/image_stream_chunk.dart';

/// 流式生成期间保留的最新预览帧，失败或取消时据此合成历史快照。
class RememberedStreamPreview {
  const RememberedStreamPreview({
    required this.bytes,
    required this.params,
    this.focusedPreviewPlacement,
  });

  final Uint8List bytes;
  final ImageParams params;
  final FocusedStreamPreviewPlacement? focusedPreviewPlacement;
}

/// 一次请求的源图与蒙版副本，供该请求的所有预览帧共用。
///
/// 副本让快照不受调用方后续改动原缓冲的影响；复用判定走对象身份，
/// 避免逐帧比对整幅图像。
class StreamPreviewSourceSnapshot {
  StreamPreviewSourceSnapshot._({
    required Uint8List sourceOrigin,
    required Uint8List? maskOrigin,
    required this.sourceImage,
    required this.maskImage,
  }) : _sourceOrigin = sourceOrigin,
       _maskOrigin = maskOrigin;

  factory StreamPreviewSourceSnapshot.copyOf(
    FocusedStreamPreviewPlacement placement,
  ) {
    final mask = placement.maskImage;
    return StreamPreviewSourceSnapshot._(
      sourceOrigin: placement.sourceImage,
      maskOrigin: mask,
      sourceImage: Uint8List.fromList(placement.sourceImage),
      maskImage: mask == null ? null : Uint8List.fromList(mask),
    );
  }

  final Uint8List _sourceOrigin;
  final Uint8List? _maskOrigin;
  final Uint8List sourceImage;
  final Uint8List? maskImage;

  FocusedStreamPreviewPlacement? _adopted;

  bool ownsBuffersOf(FocusedStreamPreviewPlacement placement) =>
      identical(_sourceOrigin, placement.sourceImage) &&
      identical(_maskOrigin, placement.maskImage);

  /// 用快照缓冲重建 [placement]，裁剪比例不变时直接返回上一帧的实例。
  FocusedStreamPreviewPlacement adopt(FocusedStreamPreviewPlacement placement) {
    final adopted = _adopted;
    if (adopted != null &&
        adopted.xPercent == placement.xPercent &&
        adopted.yPercent == placement.yPercent &&
        adopted.widthPercent == placement.widthPercent &&
        adopted.heightPercent == placement.heightPercent) {
      return adopted;
    }
    return _adopted = FocusedStreamPreviewPlacement(
      sourceImage: sourceImage,
      maskImage: maskImage,
      xPercent: placement.xPercent,
      yPercent: placement.yPercent,
      widthPercent: placement.widthPercent,
      heightPercent: placement.heightPercent,
    );
  }
}

/// 按 `runId` 与图号保管流式预览帧，并按请求复用同一份源图与蒙版快照。
///
/// 预览帧逐帧替换；源图与蒙版只在首帧或缓冲换新时复制一次。快照绑定 run，
/// 帧全部消费完即释放，不跨 run 复用。
class StreamPreviewSnapshotStore {
  final Map<String, RememberedStreamPreview> _previews =
      <String, RememberedStreamPreview>{};
  StreamPreviewSourceSnapshot? _snapshot;
  int? _snapshotRunId;

  bool get isEmpty => _previews.isEmpty;

  /// 当前保留的源图/蒙版快照；无保留帧时为 `null`。
  StreamPreviewSourceSnapshot? get retainedSnapshot => _snapshot;

  void remember({
    required int runId,
    required int imageNumber,
    required Uint8List bytes,
    required ImageParams params,
    FocusedStreamPreviewPlacement? placement,
  }) {
    if (bytes.isEmpty) return;
    _previews[_keyFor(runId, imageNumber)] = RememberedStreamPreview(
      bytes: bytes,
      params: params,
      focusedPreviewPlacement: placement == null
          ? null
          : _snapshotFor(runId, placement).adopt(placement),
    );
  }

  RememberedStreamPreview? preview(int runId, int imageNumber) =>
      _previews[_keyFor(runId, imageNumber)];

  void release(int runId, int imageNumber) {
    _previews.remove(_keyFor(runId, imageNumber));
    if (_previews.isEmpty) _dropSnapshot();
  }

  void clear() {
    _previews.clear();
    _dropSnapshot();
  }

  StreamPreviewSourceSnapshot _snapshotFor(
    int runId,
    FocusedStreamPreviewPlacement placement,
  ) {
    final current = _snapshot;
    if (current != null &&
        _snapshotRunId == runId &&
        current.ownsBuffersOf(placement)) {
      return current;
    }
    _snapshotRunId = runId;
    return _snapshot = StreamPreviewSourceSnapshot.copyOf(placement);
  }

  void _dropSnapshot() {
    _snapshot = null;
    _snapshotRunId = null;
  }

  String _keyFor(int runId, int imageNumber) => '$runId:$imageNumber';
}
