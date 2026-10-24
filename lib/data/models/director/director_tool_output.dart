import 'dart:typed_data';

import 'package:nai_launcher/l10n/app_localizations.dart';

/// 背景移除一次返回的三种结果，按响应里的图片顺序依次对应。
enum DirectorResultVariant { masked, generated, blend }

extension DirectorResultVariantExtension on DirectorResultVariant {
  /// 保存时追加到文件名末尾，与官网自动下载的命名一致。
  String get fileNameSuffix => '_$name';

  String label(AppLocalizations l10n) {
    switch (this) {
      case DirectorResultVariant.masked:
        return l10n.img2img_directorResultMasked;
      case DirectorResultVariant.generated:
        return l10n.img2img_directorResultGenerated;
      case DirectorResultVariant.blend:
        return l10n.img2img_directorResultBlend;
    }
  }
}

/// 导演工具输出中的一张图；[variant] 为空表示该工具的结果没有命名。
class DirectorToolImage {
  const DirectorToolImage(this.bytes, {this.variant});

  final Uint8List bytes;
  final DirectorResultVariant? variant;

  String get fileNameSuffix => variant?.fileNameSuffix ?? '';

  String label(AppLocalizations l10n, int index) =>
      variant?.label(l10n) ?? l10n.img2img_directorResultNumbered(index + 1);
}

/// 一次导演工具调用的全部结果，保持响应中的原始顺序。
class DirectorToolOutput {
  DirectorToolOutput(List<DirectorToolImage> images)
    : assert(images.isNotEmpty),
      images = List.unmodifiable(images);

  DirectorToolOutput.single(Uint8List bytes)
    : this(<DirectorToolImage>[DirectorToolImage(bytes)]);

  /// 按下标套用 [variants]；张数对不上时多出的图不命名，缺的名字直接跳过。
  factory DirectorToolOutput.labelled(
    List<Uint8List> images, {
    required List<DirectorResultVariant> variants,
  }) => DirectorToolOutput(<DirectorToolImage>[
    for (final (index, bytes) in images.indexed)
      DirectorToolImage(
        bytes,
        variant: index < variants.length ? variants[index] : null,
      ),
  ]);

  final List<DirectorToolImage> images;
}
