import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/widgets.dart';

/// 下载进度消息 key 常量
///
/// Service 层使用这些 key，UI 层通过 [localizeMessage] 转换为本地化字符串
class DownloadMessageKeys {
  DownloadMessageKeys._();

  static const String downloadingTags = 'download_tags_data';
  static const String downloadingCooccurrence = 'download_cooccurrence_data';
  static const String parsingData = 'download_parsing_data';
  static const String readingFile = 'download_reading_file';
  static const String mergingData = 'download_merging_data';
  static const String loadComplete = 'download_load_complete';

  /// 将消息 key 转换为本地化字符串
  ///
  /// 如果 message 为 null 或不是已知 key，则原样返回
  static String localizeMessage(BuildContext context, String? message) {
    if (message == null) return '';

    return switch (message) {
      downloadingTags => context.l10n.download_tags_data,
      downloadingCooccurrence => context.l10n.download_cooccurrence_data,
      parsingData => context.l10n.download_parsing_data,
      readingFile => context.l10n.download_readingFile,
      mergingData => context.l10n.download_mergingData,
      loadComplete => context.l10n.download_loadComplete,
      _ => message, // 未知 key 原样返回
    };
  }
}
