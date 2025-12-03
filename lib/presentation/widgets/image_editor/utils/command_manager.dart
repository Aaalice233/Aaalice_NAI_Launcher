import '../tools/stroke.dart';

/// 可撤销的命令基类
abstract class EditorCommand {
  void execute();
  void undo();
  String get description;
}

/// 添加笔画命令
class AddStrokeCommand extends EditorCommand {
  final List<Stroke> strokes;
  final Stroke stroke;

  AddStrokeCommand({
    required this.strokes,
    required this.stroke,
  });

  @override
  void execute() {
    strokes.add(stroke);
  }

  @override
  void undo() {
    strokes.remove(stroke);
  }

  @override
  String get description => 'Add stroke';
}

/// 清除所有笔画命令
class ClearStrokesCommand extends EditorCommand {
  final List<Stroke> strokes;
  final List<Stroke> _backup;

  ClearStrokesCommand({required this.strokes}) : _backup = List.from(strokes);

  @override
  void execute() {
    strokes.clear();
  }

  @override
  void undo() {
    strokes.addAll(_backup);
  }

  @override
  String get description => 'Clear all strokes';
}

/// 命令管理器（撤销/重做）
class CommandManager {
  final List<EditorCommand> _history = [];
  final List<EditorCommand> _redoStack = [];
  static const int maxHistory = 50;

  /// 执行命令
  void execute(EditorCommand cmd) {
    cmd.execute();
    _history.add(cmd);
    _redoStack.clear();

    // 限制历史记录数量
    if (_history.length > maxHistory) {
      _history.removeAt(0);
    }
  }

  /// 撤销
  bool undo() {
    if (_history.isEmpty) return false;

    final cmd = _history.removeLast();
    cmd.undo();
    _redoStack.add(cmd);
    return true;
  }

  /// 重做
  bool redo() {
    if (_redoStack.isEmpty) return false;

    final cmd = _redoStack.removeLast();
    cmd.execute();
    _history.add(cmd);
    return true;
  }

  /// 是否可以撤销
  bool get canUndo => _history.isNotEmpty;

  /// 是否可以重做
  bool get canRedo => _redoStack.isNotEmpty;

  /// 清空历史
  void clear() {
    _history.clear();
    _redoStack.clear();
  }

  /// 历史记录数量
  int get historyCount => _history.length;

  /// 重做栈数量
  int get redoCount => _redoStack.length;
}
