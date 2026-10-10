/// 生成档位：Medium 走模型的省算力变体，High 走完整模型。
enum GenerationEffort {
  medium,
  high;

  static GenerationEffort? tryParse(String? name) =>
      GenerationEffort.values.asNameMap()[name];
}
