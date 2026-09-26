/// 随机配置里各项概率的百分比文本；滑块读屏读数与界面数值共用它
String formatProbabilityPercent(double probability) =>
    '${(probability * 100).round()}%';
