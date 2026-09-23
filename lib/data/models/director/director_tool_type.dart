import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

/// 导演工具类型
enum DirectorToolType {
  removeBackground,
  extractLineArt,
  toSketch,
  colorize,
  fixEmotion,
  declutter,
  pixelSnap,
}

extension DirectorToolTypeExtension on DirectorToolType {
  bool get needsPrompt =>
      this == DirectorToolType.colorize || this == DirectorToolType.fixEmotion;

  bool get supportsDefry =>
      this == DirectorToolType.colorize || this == DirectorToolType.fixEmotion;

  /// 在本机算完，不发请求也不计费。
  bool get runsLocally => this == DirectorToolType.pixelSnap;

  /// 结果是像素画，预览与缩略图都必须关掉插值。
  bool get producesPixelArt => this == DirectorToolType.pixelSnap;

  IconData get icon {
    switch (this) {
      case DirectorToolType.removeBackground:
        return Icons.content_cut;
      case DirectorToolType.extractLineArt:
        return Icons.draw_outlined;
      case DirectorToolType.toSketch:
        return Icons.gesture;
      case DirectorToolType.colorize:
        return Icons.palette_outlined;
      case DirectorToolType.fixEmotion:
        return Icons.mood_outlined;
      case DirectorToolType.declutter:
        return Icons.cleaning_services_outlined;
      case DirectorToolType.pixelSnap:
        return Icons.grid_on_rounded;
    }
  }

  String labelKey(AppLocalizations l10n) {
    switch (this) {
      case DirectorToolType.removeBackground:
        return l10n.img2img_directorRemoveBackground;
      case DirectorToolType.extractLineArt:
        return l10n.img2img_directorLineArt;
      case DirectorToolType.toSketch:
        return l10n.img2img_directorSketch;
      case DirectorToolType.colorize:
        return l10n.img2img_directorColorize;
      case DirectorToolType.fixEmotion:
        return l10n.img2img_directorEmotion;
      case DirectorToolType.declutter:
        return l10n.img2img_directorDeclutter;
      case DirectorToolType.pixelSnap:
        return l10n.img2img_directorPixelSnap;
    }
  }
}
