import 'dart:async';

import '../../agent_types.dart';
import '../harness_types.dart';
import '../tools/path_utils.dart';
import '../utils/shell_output.dart';
import '../utils/truncate.dart';


const int _maxTimeoutSeconds = 2147483647 ~/ 1000;
const int _bashUpdateThrottleMs = 100;

class BashToolDetails {
  const BashToolDetails({this.truncation, this.fullOutputPath});

  final TruncationResult? truncation;
  final String? fullOutputPath;
}

class BashExecution {
  BashExecution({
    required this.command,
    required this.cwd,
    required this.env,
    required this.inheritEnv,
  });

  String command;
  String cwd;
  Map<String, String> env;
  bool inheritEnv;
}

typedef BashPrepare = Future<void> Function(
  BashExecution execution,
  ExecutionToolContext context, [
  AbortSignal? signal,
]);

class BashToolOptions {
  const BashToolOptions({this.commandPrefix, this.prepare});

  final String? commandPrefix;
  final BashPrepare? prepare;
}

void _validateTimeout(int? timeout) {
  if (timeout == null) {
    return;
  }
  if (timeout <= 0) {
    throw StateError(
      'Invalid timeout: must be a finite number of seconds',
    );
  }
  if (timeout > _maxTimeoutSeconds) {
    throw StateError(
      'Invalid timeout: maximum is $_maxTimeoutSeconds seconds',
    );
  }
}

class BashHarnessTool extends AgentHarnessTool {
  BashHarnessTool({this.options})
    : super(
        name: 'bash',
        label: 'bash',
        description:
            'Execute a bash command in the current working directory. '
            'Returns stdout and stderr. Output is truncated to last '
            '$defaultMaxLines lines or ${defaultMaxBytes ~/ 1024}KB '
            '(whichever is hit first). If truncated, full output is saved to '
            'a temp file. Optionally provide a timeout in seconds.',
        parameters: const {
          'type': 'object',
          'properties': {
            'command': {
              'type': 'string',
              'description': 'Bash command to execute',
            },
            'timeout': {
              'type': 'number',
              'description':
                  'Timeout in seconds (optional, no default timeout)',
            },
          },
          'required': ['command'],
        },
      );

  final BashToolOptions? options;

  @override
  Future<AgentToolResult> executeWithContext(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
    dynamic context,
  ]) async {
    final command = params['command'] as String;
    final timeout = (params['timeout'] as num?)?.toInt();
    _validateTimeout(timeout);
    final toolContext = context as ExecutionToolContext;
    final env = toolContext.env;
    final execution = BashExecution(
      command: options?.commandPrefix != null
          ? '${options!.commandPrefix}\n$command'
          : command,
      cwd: env.cwd,
      env: {},
      inheritEnv: true,
    );
    await options?.prepare?.call(execution, toolContext, signal);

    ShellCaptureProgress Function()? getLatestProgress;
    Timer? updateTimer;
    var updateDirty = false;
    var lastUpdateAt = 0;

    void emitOutputUpdate() {
      if (onUpdate == null || !updateDirty || getLatestProgress == null) {
        return;
      }
      updateDirty = false;
      lastUpdateAt = DateTime.now().millisecondsSinceEpoch;
      final progress = getLatestProgress!();
      onUpdate(
        AgentToolResult(
          content: [ToolResultTextContent(progress.output)],
          details: BashToolDetails(
            truncation: progress.truncation.truncated
                ? progress.truncation
                : null,
            fullOutputPath: progress.fullOutputPath,
          ),
        ),
      );
    }

    void clearUpdateTimer() {
      updateTimer?.cancel();
      updateTimer = null;
    }

    void scheduleOutputUpdate() {
      if (onUpdate == null) {
        return;
      }
      updateDirty = true;
      final delay =
          _bashUpdateThrottleMs - (DateTime.now().millisecondsSinceEpoch - lastUpdateAt);
      if (delay <= 0) {
        clearUpdateTimer();
        emitOutputUpdate();
        return;
      }
      updateTimer ??= Timer(Duration(milliseconds: delay), () {
        updateTimer = null;
        emitOutputUpdate();
      });
    }

    onUpdate?.call(
      AgentToolResult(content: const [], details: null),
    );
    try {
      final captureResult = await executeShellWithCapture(
        env,
        execution.command,
        ShellCaptureOptions(
          cwd: execution.cwd,
          env: execution.env,
          inheritEnv: execution.inheritEnv,
          timeout: timeout,
          abortSignal: signal,
          returnExecutionErrors: true,
          onChunk: (chunk, getProgress) {
            getLatestProgress = getProgress;
            scheduleOutputUpdate();
          },
        ),
      );
      clearUpdateTimer();
      final capture = getOrThrow(captureResult);
      getLatestProgress = () => ShellCaptureProgress(
        output: capture.output,
        truncation: capture.truncation,
        fullOutputPath: capture.fullOutputPath,
        lastLineBytes: capture.lastLineBytes,
      );
      updateDirty = true;
      emitOutputUpdate();

      var outputText = capture.output;
      BashToolDetails? details;
      if (capture.truncation.truncated) {
        details = BashToolDetails(
          truncation: capture.truncation,
          fullOutputPath: capture.fullOutputPath,
        );
        final startLine =
            capture.truncation.totalLines - capture.truncation.outputLines + 1;
        final endLine = capture.truncation.totalLines;
        if (capture.truncation.lastLinePartial) {
          final lastLineSize = formatSize(capture.lastLineBytes);
          outputText +=
              '\n\n[Showing last ${formatSize(capture.truncation.outputBytes)} '
              'of line $endLine (line is $lastLineSize). Full output: '
              '${capture.fullOutputPath}]';
        } else if (capture.truncation.truncatedBy == TruncatedBy.lines) {
          outputText +=
              '\n\n[Showing lines $startLine-$endLine of '
              '${capture.truncation.totalLines}. Full output: '
              '${capture.fullOutputPath}]';
        } else {
          outputText +=
              '\n\n[Showing lines $startLine-$endLine of '
              '${capture.truncation.totalLines} '
              '(${formatSize(defaultMaxBytes)} limit). Full output: '
              '${capture.fullOutputPath}]';
        }
      }

      String appendStatus(String status) =>
          outputText.isEmpty ? status : '$outputText\n\n$status';
      if (capture.cancelled) {
        throw StateError(appendStatus('Command aborted'));
      }
      if (capture.executionError?.code == ExecutionErrorCode.timeout) {
        throw StateError(
          appendStatus('Command timed out after $timeout seconds'),
        );
      }
      if (capture.executionError != null) {
        throw capture.executionError!;
      }
      if (capture.exitCode != null && capture.exitCode != 0) {
        throw StateError(
          appendStatus('Command exited with code ${capture.exitCode}'),
        );
      }
      return AgentToolResult(
        content: [
          ToolResultTextContent(
            outputText.isEmpty ? '(no output)' : outputText,
          ),
        ],
        details: details,
      );
    } finally {
      clearUpdateTimer();
    }
  }
}

AgentHarnessTool createBashTool([BashToolOptions? options]) {
  return BashHarnessTool(options: options);
}
