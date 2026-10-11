/// 生成模式：Furry 模式在基础提示词前补 `fur dataset` 数据集标签。
enum ImageModelMode {
  anime,
  furry;

  /// 持久化值无法识别时回落 Anime，与官网默认一致。
  static ImageModelMode fromName(String? name) =>
      ImageModelMode.values.asNameMap()[name] ?? ImageModelMode.anime;
}
