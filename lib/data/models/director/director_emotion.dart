import 'package:nai_launcher/l10n/app_localizations.dart';

/// 表情工具可选的情绪，顺序与官网下拉列表一致；枚举名即请求里的情绪关键词。
enum DirectorEmotion {
  neutral,
  happy,
  sad,
  angry,
  scared,
  surprised,
  tired,
  excited,
  nervous,
  thinking,
  confused,
  shy,
  disgusted,
  smug,
  bored,
  laughing,
  irritated,
  aroused,
  embarrassed,
  worried,
  love,
  determined,
  hurt,
  playful,
}

extension DirectorEmotionExtension on DirectorEmotion {
  String get mood => name;

  String label(AppLocalizations l10n) {
    switch (this) {
      case DirectorEmotion.neutral:
        return l10n.img2img_directorEmotionNeutral;
      case DirectorEmotion.happy:
        return l10n.img2img_directorEmotionHappy;
      case DirectorEmotion.sad:
        return l10n.img2img_directorEmotionSad;
      case DirectorEmotion.angry:
        return l10n.img2img_directorEmotionAngry;
      case DirectorEmotion.scared:
        return l10n.img2img_directorEmotionScared;
      case DirectorEmotion.surprised:
        return l10n.img2img_directorEmotionSurprised;
      case DirectorEmotion.tired:
        return l10n.img2img_directorEmotionTired;
      case DirectorEmotion.excited:
        return l10n.img2img_directorEmotionExcited;
      case DirectorEmotion.nervous:
        return l10n.img2img_directorEmotionNervous;
      case DirectorEmotion.thinking:
        return l10n.img2img_directorEmotionThinking;
      case DirectorEmotion.confused:
        return l10n.img2img_directorEmotionConfused;
      case DirectorEmotion.shy:
        return l10n.img2img_directorEmotionShy;
      case DirectorEmotion.disgusted:
        return l10n.img2img_directorEmotionDisgusted;
      case DirectorEmotion.smug:
        return l10n.img2img_directorEmotionSmug;
      case DirectorEmotion.bored:
        return l10n.img2img_directorEmotionBored;
      case DirectorEmotion.laughing:
        return l10n.img2img_directorEmotionLaughing;
      case DirectorEmotion.irritated:
        return l10n.img2img_directorEmotionIrritated;
      case DirectorEmotion.aroused:
        return l10n.img2img_directorEmotionAroused;
      case DirectorEmotion.embarrassed:
        return l10n.img2img_directorEmotionEmbarrassed;
      case DirectorEmotion.worried:
        return l10n.img2img_directorEmotionWorried;
      case DirectorEmotion.love:
        return l10n.img2img_directorEmotionLove;
      case DirectorEmotion.determined:
        return l10n.img2img_directorEmotionDetermined;
      case DirectorEmotion.hurt:
        return l10n.img2img_directorEmotionHurt;
      case DirectorEmotion.playful:
        return l10n.img2img_directorEmotionPlayful;
    }
  }
}
