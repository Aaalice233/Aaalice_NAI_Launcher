import 'dart:ui';

import 'package:flutter/foundation.dart';

/// 点「完成」后生成页实际会发送的请求尺寸与预计点数
@immutable
class EditorRequestEstimate {
  const EditorRequestEstimate({
    required this.requestWidth,
    required this.requestHeight,
    required this.cost,
  });

  final int requestWidth;
  final int requestHeight;
  final int cost;

  @override
  bool operator ==(Object other) =>
      other is EditorRequestEstimate &&
      other.requestWidth == requestWidth &&
      other.requestHeight == requestHeight &&
      other.cost == cost;

  @override
  int get hashCode => Object.hash(requestWidth, requestHeight, cost);
}

/// 取景框工具与界面入口使用的命令集，由重绘工作区的取景框控制器实现。
abstract interface class EditorFrameCommands implements Listenable {
  /// 当前原图在文档中的矩形；没有原图时为 null
  Rect? get sourceRect;

  /// 本次会话不裁切时会把生成结果贴回整张画布
  bool get supportsPasteBack;

  /// 调用方没有提供生成页的请求上下文时为 null
  EditorRequestEstimate? get requestEstimate;

  bool get canMoveFrame;

  /// 平移预览：按 64 格量化，并保证与原图至少重叠
  Rect resolveMove(Rect startFrame, Offset delta);

  void commitMove(Rect from, Rect to);

  bool get canResetFrame;

  void resetFrame();

  bool get canCropToFrame;

  bool get isCroppingToFrame;

  /// 丢弃取景框外的内容；准备阶段失败时文档保持不变并抛出异常
  Future<void> cropToFrame();
}
