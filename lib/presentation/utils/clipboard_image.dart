import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:super_clipboard/super_clipboard.dart';

/// 把图片字节写入系统剪贴板，统一规范化为 PNG。
///
/// 背景：本地画廊图片可能是 jpg/jpeg/webp/bmp/gif。若直接用 [Formats.png]
/// 写非 PNG 原始字节，剪贴板会把它们当成 PNG，导致粘贴到其它 app 时图片
/// 无效。原 Windows 端走 PowerShell + System.Drawing 能容忍任意格式，而
/// super_clipboard 要求字节与声明格式一致。所以这里写入前确保是 PNG：已是
/// PNG 原样透传，否则先解码再重新编码成 PNG，保证粘贴一定有效。
///
/// 无法解码时抛出 [FormatException]，由调用方走「复制失败」提示，而不是把
/// 损坏字节塞进剪贴板。当前平台无系统剪贴板时抛出 [UnsupportedError]。
Future<void> writeImageBytesToClipboardAsPng(Uint8List bytes) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    throw UnsupportedError('当前平台不支持系统剪贴板');
  }
  final png = await _ensurePngBytes(bytes);
  final item = DataWriterItem();
  item.add(Formats.png(png));
  await clipboard.write([item]);
}

/// 已是 PNG 则原样返回；否则在后台 isolate 解码后重新编码成 PNG，避免大图
/// 解码阻塞 UI 线程。
Future<Uint8List> _ensurePngBytes(Uint8List bytes) async {
  if (_looksLikePng(bytes)) {
    return bytes;
  }
  return Isolate.run(() {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('无法解码图片用于复制到剪贴板');
    }
    return img.encodePng(decoded);
  });
}

/// 从系统剪贴板读取图片字节（PNG 优先，依次尝试常见格式）。
///
/// 偏离上游：上游本文件只有写入方向（[writeImageBytesToClipboardAsPng]），
/// 没有任何读取函数——桌面端靠把文件拖进窗口取图，所以从来不需要读剪贴板。
/// 移动端没有 OS 级文件拖入，「从别处复制一张图再粘进来」是唯一顺手的取图
/// 路径，所以这里补上读取方向；它是生成页导入入口与四个面板粘贴入口的公共
/// 底层。
///
/// 依次尝试 PNG / JPEG / WEBP / BMP：iOS 的截图与「拷贝照片」给的是 PNG，
/// Safari「拷贝图像」常见 JPEG，Android 各家相册则 WEBP/BMP 都出现过，单试
/// PNG 会大量漏读。
///
/// 剪贴板无图片或当前平台无系统剪贴板时返回 null（不抛），由调用方提示
/// 「剪贴板里没有图片」。
Future<Uint8List?> readImageBytesFromClipboard() async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    return null;
  }
  final reader = await clipboard.read();
  for (final format in [Formats.png, Formats.jpeg, Formats.webp, Formats.bmp]) {
    if (!reader.canProvide(format)) {
      continue;
    }
    // super_clipboard 的 getFile 是回调式且可能同步失败，包成 Completer 才能
    // 在循环里顺序 await 下一个格式。
    final completer = Completer<Uint8List?>();
    reader.getFile(
      format,
      (file) async {
        try {
          completer.complete(await file.readAll());
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    final bytes = await completer.future;
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }
  }
  return null;
}

bool _looksLikePng(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < signature.length) {
    return false;
  }
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) {
      return false;
    }
  }
  return true;
}
