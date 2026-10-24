import 'package:flutter/foundation.dart';

/// 单个导演工具自己的提示词与 defry；上色与表情各持一份，切换工具互不串值。
@immutable
class DirectorPromptParams {
  const DirectorPromptParams({this.prompt = '', this.defry = minDefry})
    : assert(defry >= minDefry && defry <= maxDefry);

  static const int minDefry = 0;
  static const int maxDefry = 5;

  final String prompt;
  final int defry;

  DirectorPromptParams copyWith({String? prompt, int? defry}) {
    return DirectorPromptParams(
      prompt: prompt ?? this.prompt,
      defry: (defry ?? this.defry).clamp(minDefry, maxDefry),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DirectorPromptParams &&
      other.prompt == prompt &&
      other.defry == defry;

  @override
  int get hashCode => Object.hash(prompt, defry);
}
