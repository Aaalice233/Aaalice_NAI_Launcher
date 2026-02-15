/// UC (Undesired Content) 预设类型
/// 
/// 用于控制负面提示词的预设级别
enum UcPresetType {
  /// 严格过滤 - 最严格的负面提示词
  heavy,
  
  /// 轻度过滤 - 较轻的负面提示词
  light,
  
  /// 人体聚焦 - 针对人体相关的负面提示词
  humanFocus,
  
  /// 无预设 - 不使用预设
  none,
}
