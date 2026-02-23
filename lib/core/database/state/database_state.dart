/// 数据库全局状态
enum DatabaseState {
  /// 初始状态，尚未初始化
  uninitialized,

  /// 正在初始化（创建连接池、检查表结构）
  initializing,

  /// 就绪状态，可以正常访问
  ready,

  /// 正在关闭（准备清除或恢复）
  closing,

  /// 已关闭，连接池已释放
  closed,

  /// 正在恢复（从损坏中恢复或重建）
  recovering,

  /// 错误状态，需要恢复操作
  error,

  /// 正在清除数据（原子操作期间）
  clearing,
}

/// 状态转换事件
enum DatabaseStateEvent {
  initialize,
  close,
  clear,
  recover,
  markReady,
  markError,
  reset,
}

/// 状态转换规则
class StateTransition {
  final DatabaseState from;
  final DatabaseStateEvent event;
  final DatabaseState to;

  const StateTransition(this.from, this.event, this.to);
}

/// 有效的状态转换表
final validTransitions = [
  // 初始化流程
  const StateTransition(DatabaseState.uninitialized, DatabaseStateEvent.initialize, DatabaseState.initializing),
  const StateTransition(DatabaseState.initializing, DatabaseStateEvent.markReady, DatabaseState.ready),
  const StateTransition(DatabaseState.initializing, DatabaseStateEvent.markError, DatabaseState.error),

  // 错误处理（任何状态都可以标记错误）
  const StateTransition(DatabaseState.uninitialized, DatabaseStateEvent.markError, DatabaseState.error),
  const StateTransition(DatabaseState.closed, DatabaseStateEvent.markError, DatabaseState.error),

  // 正常关闭
  const StateTransition(DatabaseState.ready, DatabaseStateEvent.close, DatabaseState.closing),
  const StateTransition(DatabaseState.closing, DatabaseStateEvent.markReady, DatabaseState.closed),

  // 清除流程（原子操作）
  // 从 ready 状态清除
  const StateTransition(DatabaseState.ready, DatabaseStateEvent.clear, DatabaseState.clearing),
  // 从未初始化状态也可以直接清除（用于首次清除场景）
  const StateTransition(DatabaseState.uninitialized, DatabaseStateEvent.clear, DatabaseState.clearing),
  // 从错误状态也可以清除（用于恢复后清除）
  const StateTransition(DatabaseState.error, DatabaseStateEvent.clear, DatabaseState.clearing),
  // 清除完成后进入初始化状态
  const StateTransition(DatabaseState.clearing, DatabaseStateEvent.markReady, DatabaseState.initializing),

  // 恢复流程
  const StateTransition(DatabaseState.error, DatabaseStateEvent.recover, DatabaseState.recovering),
  const StateTransition(DatabaseState.closed, DatabaseStateEvent.recover, DatabaseState.recovering),
  const StateTransition(DatabaseState.recovering, DatabaseStateEvent.markReady, DatabaseState.ready),
  const StateTransition(DatabaseState.recovering, DatabaseStateEvent.markError, DatabaseState.error),

  // 重置
  const StateTransition(DatabaseState.error, DatabaseStateEvent.reset, DatabaseState.uninitialized),
  const StateTransition(DatabaseState.closed, DatabaseStateEvent.reset, DatabaseState.uninitialized),

  // 直接标记就绪（用于简化流程）
  const StateTransition(DatabaseState.uninitialized, DatabaseStateEvent.markReady, DatabaseState.ready),
  const StateTransition(DatabaseState.closed, DatabaseStateEvent.markReady, DatabaseState.ready),
];
