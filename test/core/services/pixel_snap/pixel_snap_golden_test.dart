import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_options.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_service.dart';

/// 与官网 Pixel Snap 输出的逐像素比对。
///
/// 样张是用户内容且有几 MB，不进版本库；缺文件时整组跳过。
/// 要跑这组测试，把源图和官网输出分别放成：
///   tool/.tmp/pixelsnap_golden/source.png
///   tool/.tmp/pixelsnap_golden/official.png
/// 官网侧参数用 Palettize=Auto、Avoid Over-Refining 关、Upscale 关。
const String _fixtureDir = 'tool/.tmp/pixelsnap_golden';

void main() {
  final File source = File('$_fixtureDir/source.png');
  final File official = File('$_fixtureDir/official.png');
  final bool hasFixtures = source.existsSync() && official.existsSync();

  test(
    'Auto 调色板下与官网输出逐像素一致',
    () async {
      final PixelSnapOutput out = await PixelSnapService.analyze(
        source.readAsBytesSync(),
        PixelSnapEngineParams.fromOptions(const PixelSnapOptions()),
      );
      final img.Image reference = img.decodePng(official.readAsBytesSync())!;

      expect(out.snappedWidth, reference.width);
      expect(out.snappedHeight, reference.height);
      expect(out.outputWidth, reference.width);
      expect(out.outputHeight, reference.height);

      final Uint8List ours = img
          .decodePng(out.pngBytes)!
          .convert(format: img.Format.uint8, numChannels: 4)
          .getBytes(order: img.ChannelOrder.rgba);
      final Uint8List theirs = reference
          .convert(format: img.Format.uint8, numChannels: 4)
          .getBytes(order: img.ChannelOrder.rgba);

      int differing = 0;
      for (int i = 0; i < reference.width * reference.height; i++) {
        if (ours[4 * i] != theirs[4 * i] ||
            ours[4 * i + 1] != theirs[4 * i + 1] ||
            ours[4 * i + 2] != theirs[4 * i + 2]) {
          differing++;
        }
      }
      expect(differing, 0);
    },
    skip: hasFixtures ? null : '缺少 $_fixtureDir 下的对比样张',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
