import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../../core/utils/app_logger.dart';

/// 图层底图像素：图层、撤销记录与烘焙结果共用一份，最后一个持有者归还时释放。
/// PNG 字节只在确实需要时编码并缓存。
class LayerRaster {
  /// [image] 的所有权移交给句柄
  LayerRaster(ui.Image image, {Uint8List? bytes})
    : _image = image,
      _bytes = bytes;

  /// 当帧把 [picture]（所有权移交）光栅化成可绘制的图像
  LayerRaster.render(ui.Picture picture, int width, int height)
    : _image = picture.toImageSync(width, height) {
    picture.dispose();
    _detaching = _detach();
  }

  ui.Image _image;
  Uint8List? _bytes;
  Future<Uint8List?>? _encoding;
  Future<void>? _detaching;
  int _holders = 1;

  ui.Image get image {
    assert(_holders > 0, 'LayerRaster used after its last release.');
    return _image;
  }

  int get width => _image.width;

  int get height => _image.height;

  /// 已编码的 PNG 字节；尚未编码时为 null，需要时用 [encodePng]
  Uint8List? get bytes => _bytes;

  /// 当帧光栅化的图像已换成独立纹理
  Future<void> get detached => _detaching ?? Future<void>.value();

  /// 再占一份持有，交给新的持有者
  LayerRaster retain() {
    assert(_holders > 0, 'LayerRaster retained after its last release.');
    _holders++;
    return this;
  }

  void release() {
    assert(_holders > 0, 'LayerRaster released more times than it was held.');
    _holders--;
    if (_holders == 0) _image.dispose();
  }

  Future<Uint8List?> encodePng() {
    final bytes = _bytes;
    if (bytes != null) return Future.value(bytes);
    return _encoding ??= _encode();
  }

  Future<Uint8List?> _encode() async {
    if (_holders == 0) return null;
    final handle = _image.clone();
    try {
      final data = await handle.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      return _bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    } finally {
      handle.dispose();
      _encoding = null;
    }
  }

  // toImageSync 的图像一直引用录制时的绘制来源，连续写回会把历次底图串成链全部留在内存里
  Future<void> _detach() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImage(_image, Offset.zero, Paint());
    final copy = recorder.endRecording();
    try {
      final standalone = await copy.toImage(width, height);
      if (_holders == 0) {
        standalone.dispose();
        return;
      }
      _image.dispose();
      _image = standalone;
    } on Object catch (error) {
      AppLogger.w('Failed to detach layer raster: $error', 'ImageEditor');
    } finally {
      copy.dispose();
    }
  }
}
