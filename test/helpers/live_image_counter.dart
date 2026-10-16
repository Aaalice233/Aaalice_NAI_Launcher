import 'dart:ui' as ui;

/// 只统计 [install] 之后创建的图像：[created] 累计创建数，[count] 创建加一、释放减一
class LiveImageCounter {
  int count = 0;
  int created = 0;
  ui.ImageEventCallback? _previousCreate;
  ui.ImageEventCallback? _previousDispose;

  void install() {
    _previousCreate = ui.Image.onCreate;
    _previousDispose = ui.Image.onDispose;
    ui.Image.onCreate = (_) {
      count++;
      created++;
    };
    ui.Image.onDispose = (_) => count--;
  }

  void restore() {
    ui.Image.onCreate = _previousCreate;
    ui.Image.onDispose = _previousDispose;
  }
}
