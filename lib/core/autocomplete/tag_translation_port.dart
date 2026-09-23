/// 自动补全请求大模型翻译标签的最小接口，实现由上层注入。
abstract interface class TagTranslationPort {
  int get promptVersion;

  String routeFingerprint();

  Future<Map<String, String>> translateTags(
    List<String> canonicalTags, {
    required String sessionId,
  });

  Future<void> cancelTask({required String sessionId});
}
