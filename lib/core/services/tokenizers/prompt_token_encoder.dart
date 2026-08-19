/// 提示词分词器接口。
///
/// 不同模型家族使用不同的分词器（V4 系列 T5、V5 Qwen 3.5），
/// 计数逻辑只依赖这个接口。
abstract class PromptTokenEncoder {
  Future<int> countTokens(String text);
}
