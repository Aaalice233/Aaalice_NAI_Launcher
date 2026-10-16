import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/utils/exif_orientation.dart';
import '../../../core/utils/inpaint_mask_utils.dart';
import '../../../core/utils/isolate_pool.dart';
import '../../../core/utils/pica_lanczos_resizer.dart';
import '../../../data/models/image/image_stream_chunk.dart';

typedef StreamSnapshotComposer =
    Future<Uint8List> Function(StreamPreviewFrame frame);

/// 失败快照的合成执行入口，默认在后台 isolate 中运行 [composeStreamSnapshot]。
final streamSnapshotComposerProvider = Provider<StreamSnapshotComposer>(
  (ref) => composeStreamSnapshotInBackground,
);

Future<Uint8List> composeStreamSnapshotInBackground(StreamPreviewFrame frame) {
  return ComputeGate().runCompute(
    composeStreamSnapshot,
    frame,
    debugLabel: 'composeStreamSnapshot',
  );
}

/// [frame] 需要贴回源图时使用的 placement；返回 `null` 时快照直接沿用预览字节。
FocusedStreamPreviewPlacement? streamSnapshotPlacement(
  StreamPreviewFrame frame,
) {
  final placement = frame.placement;
  return placement != null && placement.isValid ? placement : null;
}

/// 把重绘预览帧按 placement 贴回源图并编码为 PNG。
///
/// 无需合成或源图、预览无法解码时原样返回 [frame] 的预览字节。
Uint8List composeStreamSnapshot(StreamPreviewFrame frame) {
  final placement = streamSnapshotPlacement(frame);
  if (placement == null) return frame.bytes;
  final source = ExifOrientation.decodeUpright(placement.sourceImage);
  final generated = img.decodeImage(frame.bytes);
  final mask = placement.maskImage == null
      ? null
      : img.decodeImage(placement.maskImage!);
  if (source == null || generated == null) return frame.bytes;
  final x = (placement.xPercent * source.width)
      .round()
      .clamp(0, max(0, source.width - 1))
      .toInt();
  final y = (placement.yPercent * source.height)
      .round()
      .clamp(0, max(0, source.height - 1))
      .toInt();
  final width = (placement.widthPercent * source.width)
      .round()
      .clamp(1, max(1, source.width - x))
      .toInt();
  final height = (placement.heightPercent * source.height)
      .round()
      .clamp(1, max(1, source.height - y))
      .toInt();
  img.Image patch;
  if (mask == null) {
    patch = PicaLanczosResizer.resizeImage(
      generated,
      width: width,
      height: height,
    );
  } else {
    final requestPreview = PicaLanczosResizer.resizeImage(
      generated,
      width: mask.width,
      height: mask.height,
    );
    patch = PicaLanczosResizer.resizeImage(
      InpaintMaskUtils.applyCompositeMaskToGeneratedImage(requestPreview, mask),
      width: width,
      height: height,
    );
  }
  final composed = img.Image.from(source, noAnimation: true);
  img.compositeImage(
    composed,
    patch,
    dstX: x,
    dstY: y,
    dstW: width,
    dstH: height,
    blend: mask == null ? img.BlendMode.direct : img.BlendMode.alpha,
  );
  return Uint8List.fromList(img.encodePng(composed, level: 1));
}
