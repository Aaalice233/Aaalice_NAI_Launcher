import 'dart:async';

import 'agent_loop.dart';
import 'agent_types.dart';

export 'agent_types.dart';

Future<List<Message>> defaultConvertToLlm(List<AgentMessage> messages) async {
  return messages
      .where(
        (message) =>
            message.role == 'user' ||
            message.role == 'assistant' ||
            message.role == 'toolResult',
      )
      .toList();
}

const _defaultModel = Model(
  id: 'unknown',
  name: 'unknown',
  api: 'unknown',
  provider: 'unknown',
);

class AgentQueueEntry {
  const AgentQueueEntry({required this.id, required this.message});

  final int id;
  final AgentMessage message;
}

class _PendingMessageQueue {
  final List<AgentQueueEntry> _entries = [];
  QueueMode mode;

  _PendingMessageQueue(this.mode);

  void enqueue(AgentQueueEntry entry) {
    _entries.add(entry);
  }

  bool hasItems() => _entries.isNotEmpty;

  int get length => _entries.length;

  List<AgentQueueEntry> get entries => List.unmodifiable(_entries);

  List<AgentMessage> get messages => [
    for (final entry in _entries) entry.message,
  ];

  AgentMessage removeAt(int index) => _entries.removeAt(index).message;

  AgentMessage? removeById(int id) {
    final index = _entries.indexWhere((entry) => entry.id == id);
    return index < 0 ? null : _entries.removeAt(index).message;
  }

  List<AgentMessage> drain() {
    if (mode == QueueMode.all) {
      final drained = [for (final entry in _entries) entry.message];
      _entries.clear();
      return drained;
    }

    if (_entries.isEmpty) {
      return const [];
    }
    final first = _entries.removeAt(0);
    return [first.message];
  }

  void clear() {
    _entries.clear();
  }
}

class _ActiveRun {
  const _ActiveRun({
    required this.promise,
    required this.completer,
    required this.abortController,
  });

  final Future<void> promise;
  final Completer<void> completer;
  final AbortController abortController;
}

/// Agent 构造选项。
class AgentOptions {
  const AgentOptions({
    required this.streamFn,
    this.initialSystemPrompt,
    this.initialModel,
    this.initialThinkingLevel,
    this.initialTools,
    this.initialMessages,
    this.convertToLlm,
    this.transformContext,
    this.getApiKey,
    this.beforeToolCall,
    this.afterToolCall,
    this.shouldStopAfterTurn,
    this.prepareNextTurn,
    this.prepareNextTurnWithContext,
    this.steeringMode,
    this.followUpMode,
    this.sessionId,
    this.toolExecution,
  });

  final StreamFn streamFn;
  final String? initialSystemPrompt;
  final Model? initialModel;
  final ThinkingLevel? initialThinkingLevel;
  final List<AgentTool>? initialTools;
  final List<AgentMessage>? initialMessages;
  final Future<List<Message>> Function(List<AgentMessage> messages)?
  convertToLlm;
  final Future<List<AgentMessage>> Function(
    List<AgentMessage> messages,
    AbortSignal? signal,
  )?
  transformContext;
  final Future<String?> Function(String provider)? getApiKey;
  final Future<BeforeToolCallResult?> Function(
    BeforeToolCallContext context,
    AbortSignal? signal,
  )?
  beforeToolCall;
  final Future<AfterToolCallResult?> Function(
    AfterToolCallContext context,
    AbortSignal? signal,
  )?
  afterToolCall;
  final Future<bool> Function(
    ShouldStopAfterTurnContext context,
    AbortSignal? signal,
  )?
  shouldStopAfterTurn;
  final Future<AgentLoopTurnUpdate?> Function(AbortSignal? signal)?
  prepareNextTurn;
  final Future<AgentLoopTurnUpdate?> Function(
    PrepareNextTurnContext context,
    AbortSignal? signal,
  )?
  prepareNextTurnWithContext;
  final QueueMode? steeringMode;
  final QueueMode? followUpMode;
  final String? sessionId;
  final ToolExecutionMode? toolExecution;
}

/// 底层 agent loop 的有状态封装。
///
/// `Agent` 持有当前转录、发出生命周期事件、执行工具，并提供
/// steering / follow-up 消息的队列 API。
class Agent {
  Agent(AgentOptions options) {
    _state = AgentState(
      systemPrompt: options.initialSystemPrompt ?? '',
      model: options.initialModel ?? _defaultModel,
      thinkingLevel: options.initialThinkingLevel ?? ThinkingLevel.off,
      tools: options.initialTools ?? const [],
      messages: options.initialMessages ?? const [],
    );
    convertToLlm = options.convertToLlm ?? defaultConvertToLlm;
    transformContext = options.transformContext;
    streamFunction = options.streamFn;
    getApiKey = options.getApiKey;
    beforeToolCall = options.beforeToolCall;
    afterToolCall = options.afterToolCall;
    _shouldStopAfterTurnOption = options.shouldStopAfterTurn;
    _prepareNextTurnOption = options.prepareNextTurn;
    prepareNextTurnWithContext = options.prepareNextTurnWithContext;
    _steeringQueue = _PendingMessageQueue(
      options.steeringMode ?? QueueMode.oneAtATime,
    );
    _followUpQueue = _PendingMessageQueue(
      options.followUpMode ?? QueueMode.oneAtATime,
    );
    sessionId = options.sessionId;
    toolExecution = options.toolExecution ?? ToolExecutionMode.parallel;
  }

  late final AgentState _state;
  final List<FutureOr<void> Function(AgentEvent event, AbortSignal signal)>
  _listeners = [];
  late final _PendingMessageQueue _steeringQueue;
  late final _PendingMessageQueue _followUpQueue;
  var _nextQueueEntryId = 0;
  _ActiveRun? _activeRun;

  late final Future<List<Message>> Function(List<AgentMessage> messages)
  convertToLlm;
  late final Future<List<AgentMessage>> Function(
    List<AgentMessage> messages,
    AbortSignal? signal,
  )?
  transformContext;
  late final StreamFn streamFunction;
  late final Future<String?> Function(String provider)? getApiKey;
  late final Future<BeforeToolCallResult?> Function(
    BeforeToolCallContext context,
    AbortSignal? signal,
  )?
  beforeToolCall;
  late final Future<AfterToolCallResult?> Function(
    AfterToolCallContext context,
    AbortSignal? signal,
  )?
  afterToolCall;
  late final Future<bool> Function(
    ShouldStopAfterTurnContext context,
    AbortSignal? signal,
  )?
  _shouldStopAfterTurnOption;
  late final Future<AgentLoopTurnUpdate?> Function(AbortSignal? signal)?
  _prepareNextTurnOption;
  late final Future<AgentLoopTurnUpdate?> Function(
    PrepareNextTurnContext context,
    AbortSignal? signal,
  )?
  prepareNextTurnWithContext;

  /// 会话标识，转发给支持缓存的后端。
  String? sessionId;

  /// 多工具调用的执行策略。
  late ToolExecutionMode toolExecution;

  /// 订阅 agent 生命周期事件。listener 按订阅顺序 await，且计入当前
  /// run 的结算。`agent_end` 是一次 run 的最后一个事件，但直到其所有
  /// listener 完成后 agent 才空闲。
  /// 返回取消订阅函数。
  void Function() subscribe(
    FutureOr<void> Function(AgentEvent event, AbortSignal signal) listener,
  ) {
    _listeners.add(listener);
    return () {
      _listeners.remove(listener);
    };
  }

  AgentState get state => _state;

  set steeringMode(QueueMode mode) {
    _steeringQueue.mode = mode;
  }

  QueueMode get steeringMode => _steeringQueue.mode;

  set followUpMode(QueueMode mode) {
    _followUpQueue.mode = mode;
  }

  QueueMode get followUpMode => _followUpQueue.mode;

  /// 排队一条消息，在当前助手 turn 结束后注入。
  int steer(AgentMessage message) {
    final id = _nextQueueEntryId++;
    _steeringQueue.enqueue(AgentQueueEntry(id: id, message: message));
    return id;
  }

  /// 排队一条消息，仅在 agent 即将停止时才运行。
  int followUp(AgentMessage message) {
    final id = _nextQueueEntryId++;
    _followUpQueue.enqueue(AgentQueueEntry(id: id, message: message));
    return id;
  }

  void clearSteeringQueue() {
    _steeringQueue.clear();
  }

  void clearFollowUpQueue() {
    _followUpQueue.clear();
  }

  void clearAllQueues() {
    clearSteeringQueue();
    clearFollowUpQueue();
  }

  bool hasQueuedMessages() =>
      _steeringQueue.hasItems() || _followUpQueue.hasItems();

  int get queuedMessageCount => _steeringQueue.length + _followUpQueue.length;

  List<AgentMessage> get steeringMessages => _steeringQueue.messages;

  List<AgentMessage> get followUpMessages => _followUpQueue.messages;

  List<AgentQueueEntry> get steeringQueue => _steeringQueue.entries;

  List<AgentQueueEntry> get followUpQueue => _followUpQueue.entries;

  AgentMessage removeSteeringAt(int index) => _steeringQueue.removeAt(index);

  AgentMessage removeFollowUpAt(int index) => _followUpQueue.removeAt(index);

  AgentMessage? removeSteeringById(int id) => _steeringQueue.removeById(id);

  AgentMessage? removeFollowUpById(int id) => _followUpQueue.removeById(id);

  AbortSignal? get signal => _activeRun?.abortController.signal;

  void abort() {
    _activeRun?.abortController.abort();
  }

  /// 等待当前 run 与所有被 await 的事件 listener 完成。
  Future<void> waitForIdle() => _activeRun?.promise ?? Future.value();

  /// 更新系统提示词（下次 LLM 调用生效）。
  void setSystemPrompt(String systemPrompt) {
    _state.systemPrompt = systemPrompt;
  }

  /// 清空转录状态、运行时状态与排队消息。
  void reset() {
    if (_activeRun != null) {
      throw StateError(
        'Agent is already processing. Wait for completion before resetting.',
      );
    }

    _state.messages.clear();
    _state.isStreaming = false;
    _state.streamingMessage = null;
    _state.pendingToolCalls.clear();
    _state.errorMessage = null;
    clearFollowUpQueue();
    clearSteeringQueue();
  }

  /// 以文本、单条消息或一批消息发起新 prompt。
  Future<void> prompt(Object input, [List<ImageContent>? images]) async {
    if (_activeRun != null) {
      throw StateError(
        'Agent is already processing a prompt. Use steer() or followUp() to '
        'queue messages, or wait for completion.',
      );
    }
    final messages = _normalizePromptInput(input, images);
    await _runPromptMessages(messages);
  }

  /// 从当前转录继续。最后一条消息必须是 user 或 toolResult。
  Future<void> continueRun() async {
    if (_activeRun != null) {
      throw StateError(
        'Agent is already processing. Wait for completion '
        'before continuing.',
      );
    }

    if (_state.messages.isEmpty) {
      throw StateError('No messages to continue from');
    }

    final lastMessage = _state.messages.last;
    if (lastMessage.role == 'assistant') {
      final queuedSteering = _steeringQueue.drain();
      if (queuedSteering.isNotEmpty) {
        await _runPromptMessages(queuedSteering, skipInitialSteeringPoll: true);
        return;
      }

      final queuedFollowUps = _followUpQueue.drain();
      if (queuedFollowUps.isNotEmpty) {
        await _runPromptMessages(queuedFollowUps);
        return;
      }

      throw StateError('Cannot continue from message role: assistant');
    }

    await _runContinuation();
  }

  List<AgentMessage> _normalizePromptInput(
    Object input, [
    List<ImageContent>? images,
  ]) {
    if (input is List<AgentMessage>) {
      return input;
    }
    if (input is AgentMessage) {
      return [input];
    }
    if (input is String) {
      final content = <UserContent>[UserTextContent(input)];
      if (images != null && images.isNotEmpty) {
        content.addAll([for (final image in images) UserImageContent(image)]);
      }
      return [
        UserMessage(
          content: content,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ];
    }
    throw ArgumentError('Unsupported prompt input: ${input.runtimeType}');
  }

  Future<void> _runPromptMessages(
    List<AgentMessage> messages, {
    bool skipInitialSteeringPoll = false,
  }) async {
    await _runWithLifecycle((signal) {
      return runAgentLoop(
        messages,
        _createContextSnapshot(),
        _createLoopConfig(skipInitialSteeringPoll: skipInitialSteeringPoll),
        _processEvents,
        signal,
        streamFunction,
      );
    });
  }

  Future<void> _runContinuation() async {
    await _runWithLifecycle((signal) {
      return runAgentLoopContinue(
        _createContextSnapshot(),
        _createLoopConfig(),
        _processEvents,
        signal,
        streamFunction,
      );
    });
  }

  AgentContext _createContextSnapshot() {
    return AgentContext(
      systemPrompt: _state.systemPrompt,
      messages: List<AgentMessage>.of(_state.messages),
      tools: List<AgentTool>.of(_state.tools),
    );
  }

  AgentLoopConfig _createLoopConfig({bool skipInitialSteeringPoll = false}) {
    var skipSteeringPoll = skipInitialSteeringPoll;
    return AgentLoopConfig(
      model: _state.model,
      apiKey: null,
      signal: null,
      sessionId: sessionId,
      reasoning: _state.thinkingLevel == ThinkingLevel.off
          ? null
          : _state.thinkingLevel.name,
      convertToLlm: convertToLlm,
      transformContext: transformContext,
      getApiKey: getApiKey,
      shouldStopAfterTurn: _shouldStopAfterTurnOption == null
          ? null
          : (context) async {
              return _shouldStopAfterTurnOption(context, signal);
            },
      prepareNextTurn:
          (prepareNextTurnWithContext != null || _prepareNextTurnOption != null)
          ? (context) async {
              if (prepareNextTurnWithContext != null) {
                return prepareNextTurnWithContext!(context, signal);
              }
              return _prepareNextTurnOption?.call(signal);
            }
          : null,
      getSteeringMessages: () async {
        if (skipSteeringPoll) {
          skipSteeringPoll = false;
          return const <AgentMessage>[];
        }
        return _steeringQueue.drain();
      },
      getFollowUpMessages: () async => _followUpQueue.drain(),
      toolExecution: toolExecution,
      beforeToolCall: beforeToolCall,
      afterToolCall: afterToolCall,
    );
  }

  Future<void> _runWithLifecycle(
    Future<void> Function(AbortSignal signal) executor,
  ) async {
    if (_activeRun != null) {
      throw StateError('Agent is already processing.');
    }

    final abortController = AbortController();
    final runCompleter = Completer<void>();
    final run = _ActiveRun(
      promise: runCompleter.future,
      completer: runCompleter,
      abortController: abortController,
    );
    _activeRun = run;

    _state.isStreaming = true;
    _state.streamingMessage = null;
    _state.errorMessage = null;

    try {
      await executor(abortController.signal);
    } catch (error) {
      await _handleRunFailure(error, abortController.signal.aborted);
    } finally {
      _finishRun();
    }
  }

  Future<void> _handleRunFailure(Object error, bool aborted) async {
    final failureMessage = AssistantMessage(
      content: const [AssistantTextContent('')],
      stopReason: aborted ? StopReason.aborted : StopReason.error,
      errorMessage: error.toString(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await _processEvents(AgentEventMessageStart(message: failureMessage));
    await _processEvents(AgentEventMessageEnd(message: failureMessage));
    await _processEvents(
      AgentEventTurnEnd(message: failureMessage, toolResults: const []),
    );
    await _processEvents(AgentEventAgentEnd(messages: [failureMessage]));
  }

  void _finishRun() {
    final run = _activeRun;
    _state.isStreaming = false;
    _state.streamingMessage = null;
    _state.pendingToolCalls.clear();
    _activeRun = null;
    if (run != null && !run.completer.isCompleted) {
      run.completer.complete();
    }
  }

  /// 对 loop 事件先做内部状态归约，再 await listener。
  ///
  /// `agent_end` 只表示不再发出 loop 事件；直到其所有 listener 完成且
  /// `_finishRun` 清理运行态之后，run 才算空闲。
  Future<void> _processEvents(AgentEvent event) async {
    switch (event) {
      case AgentEventMessageStart():
        _state.streamingMessage = event.message;
      case AgentEventMessageUpdate():
        _state.streamingMessage = event.message;
      case AgentEventMessageEnd():
        _state.streamingMessage = null;
        _state.messages.add(event.message);
      case AgentEventToolExecutionStart():
        _state.pendingToolCalls.add(event.toolCallId);
      case AgentEventToolExecutionEnd():
        _state.pendingToolCalls.remove(event.toolCallId);
      case AgentEventTurnEnd():
        final message = event.message;
        if (message is AssistantMessage && message.errorMessage != null) {
          _state.errorMessage = message.errorMessage;
        }
      case AgentEventAgentEnd():
        _state.streamingMessage = null;
      default:
        break;
    }

    final signal = _activeRun?.abortController.signal;
    if (signal == null) {
      throw StateError('Agent listener invoked outside active run');
    }
    for (final listener in List.of(_listeners)) {
      await listener(event, signal);
    }
  }
}
