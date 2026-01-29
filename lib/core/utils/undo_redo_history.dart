/// 历史命令抽象类
abstract class HistoryCommand {
  final String description;
  HistoryCommand(this.description);

  /// 执行命令
  Future<void> execute();

  /// 撤销命令
  Future<void> undo();
}

/// 撤销/重做历史管理器
class UndoRedoHistory {
  final List<HistoryCommand> _history = [];
  final List<HistoryCommand> _redoStack = [];
  final int _maxSize;

  UndoRedoHistory({int maxSize = 50}) : _maxSize = maxSize;

  /// 获取历史记录列表（只读）
  List<HistoryCommand> get history => List.unmodifiable(_history);

  /// 获取重做栈（只读）
  List<HistoryCommand> get redoStack => List.unmodifiable(_redoStack);

  /// 是否可以撤销
  bool get canUndo => _history.isNotEmpty;

  /// 是否可以重做
  bool get canRedo => _redoStack.isNotEmpty;

  /// 添加命令
  void push(HistoryCommand command) {
    _history.add(command);
    _redoStack.clear();
    if (_history.length > _maxSize) {
      _history.removeAt(0);
    }
  }

  /// 撤销
  Future<void> undo() async {
    if (canUndo) {
      final command = _history.removeLast();
      await command.undo();
      _redoStack.add(command);
    }
  }

  /// 重做
  Future<void> redo() async {
    if (canRedo) {
      final command = _redoStack.removeLast();
      await command.execute();
      _history.add(command);
    }
  }

  /// 清空历史
  void clear() {
    _history.clear();
    _redoStack.clear();
  }
}
