import '../constants/model_capabilities.dart';
import '../enums/image_model_mode.dart';

/// Furry 模式补在基础提示词最前面的数据集标签。
abstract final class NovelAiDatasetPrefix {
  static const String furryTag = 'fur dataset';
  static const String backgroundTag = 'background dataset';
  static const String _furryPrefix = '$furryTag, ';

  /// 与官网一致只看原文开头：用户已手写任一数据集标签时不再补。
  static String apply(
    String prompt, {
    required ImageModelMode mode,
    required ModelCapabilities capabilities,
  }) {
    if (!capabilities.hasFurryMode || mode != ImageModelMode.furry) {
      return prompt;
    }
    if (prompt.startsWith(furryTag) || prompt.startsWith(backgroundTag)) {
      return prompt;
    }
    return '$_furryPrefix$prompt';
  }

  /// 从图片提示词识别模式并剥掉前缀；模型没有 Furry 模式时 mode 为 null，不应改动当前模式。
  static ({String prompt, ImageModelMode? mode}) strip(
    String prompt, {
    required ModelCapabilities capabilities,
  }) {
    if (!capabilities.hasFurryMode) return (prompt: prompt, mode: null);
    if (!prompt.startsWith(_furryPrefix)) {
      return (prompt: prompt, mode: ImageModelMode.anime);
    }
    return (
      prompt: prompt.substring(_furryPrefix.length),
      mode: ImageModelMode.furry,
    );
  }

  static bool hasFurryPrefix(String prompt) => prompt.startsWith(_furryPrefix);
}
