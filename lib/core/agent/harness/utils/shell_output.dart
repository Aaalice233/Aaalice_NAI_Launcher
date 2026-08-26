import 'dart:async';
import 'dart:convert';

import '../../abort_signal.dart';
import '../harness_types.dart';
import 'truncate.dart';


int utf8ByteLengthOf(String text) => utf8.encode(text).length;

String utf8DecodeAllowMalformed(List<int> bytes) =>
    utf8.decode(bytes, allowMalformed: true);

class ShellCaptureProgress {
  const ShellCaptureProgress({
    required this.output,
    required this.truncation,
    required this.fullOutputPath,
    required this.lastLineBytes,
  });

  final String output;
  final TruncationResult truncation;
  final String? fullOutputPath;
  final int lastLineBytes;
}

class ShellCaptureOptions {
  const ShellCaptureOptions({
    this.cwd,
    this.env,
    this.inheritEnv,
    this.timeout,
    this.abortSignal,
    this.onChunk,
    this.returnExecutionErrors,
  });

  final String? cwd;
  final Map<String, String>? env;
  final bool? inheritEnv;
  final int? timeout;
  final AbortSignal? abortSignal;
  final void Function(String chunk, ShellCaptureProgress Function() getProgress)?
  onChunk;

  /// shell 执行失败时携带已捕获输出返回，而不是失败 Result。
  final bool? returnExecutionErrors;
}

class ShellCaptureResult {
  const ShellCaptureResult({
    required this.output,
    required this.truncation,
    required this.fullOutputPath,
    required this.lastLineBytes,
    required this.exitCode,
    required this.cancelled,
    required this.truncated,
    this.executionError,
  });

  final String output;
  final TruncationResult truncation;
  final String? fullOutputPath;
  final int lastLineBytes;
  final int? exitCode;
  final bool cancelled;
  final bool truncated;
  final ExecutionError? executionError;
}

ExecutionError _toExecutionError(Object error) {
  if (error is ExecutionError) {
    return error;
  }
  return ExecutionError(ExecutionErrorCode.unknown, error.toString());
}

/// 过滤二进制控制字符（保留 \t \n \r）。
String sanitizeBinaryOutput(String str) {
  final buffer = StringBuffer();
  for (final rune in str.runes) {
    if (rune == 0x09 || rune == 0x0a || rune == 0x0d) {
      buffer.writeCharCode(rune);
      continue;
    }
    if (rune <= 0x1f) {
      continue;
    }
    if (rune >= 0xfff9 && rune <= 0xfffb) {
      continue;
    }
    buffer.writeCharCode(rune);
  }
  return buffer.toString();
}

/// 执行 shell 命令并捕获尾部截断的输出。
Future<HarnessResult<ShellCaptureResult, ExecutionError>>
executeShellWithCapture(
  ExecutionEnv env,
  String command, [
  ShellCaptureOptions? options,
]) async {
  var tailOutput = '';
  const maxOutputBytes = defaultMaxBytes * 2;

  var totalBytes = 0;
  var completedLines = 0;
  var hasOpenLine = false;
  var currentLineBytes = 0;
  String? fullOutputPath;
  var fullOutputRequested = false;
  var acceptingOutput = true;
  var writeChain = Future<HarnessResult<void, ExecutionError>>.value(
    ok(null),
  );
  ExecutionError? captureError;

  void appendFullOutput(String text) {
    if (!fullOutputRequested || captureError != null) {
      return;
    }
    writeChain = writeChain.then((previous) async {
      if (previous is HarnessErr) {
        return previous;
      }
      if (fullOutputPath == null) {
        return err(
          ExecutionError(
            ExecutionErrorCode.unknown,
            'Full output path was not created',
          ),
        );
      }
      final appendResult = await env.appendFile(fullOutputPath!, text);
      return appendResult is HarnessOk
          ? ok(null)
          : err(_toExecutionError((appendResult as HarnessErr).error));
    });
  }

  void ensureFullOutputFile(String initialContent) {
    if (fullOutputRequested || captureError != null) {
      return;
    }
    fullOutputRequested = true;
    writeChain = writeChain.then((previous) async {
      if (previous is HarnessErr) {
        return previous;
      }
      final tempFile = await env.createTempFile(
        prefix: 'bash-',
        suffix: '.log',
      );
      final path = tempFile.valueOrNull;
      if (path == null) {
        return err(_toExecutionError(tempFile.errorOrNull!));
      }
      fullOutputPath = path;
      final appendResult = await env.appendFile(path, initialContent);
      return appendResult is HarnessOk
          ? ok(null)
          : err(_toExecutionError((appendResult as HarnessErr).error));
    });
  }

  ShellCaptureProgress createProgress() {
    final tailTruncation = truncateTail(tailOutput);
    final totalLines = completedLines + (hasOpenLine ? 1 : 0);
    final truncated = totalLines > defaultMaxLines || totalBytes > defaultMaxBytes;
    final truncation = TruncationResult(
      content: tailTruncation.content,
      truncated: truncated,
      truncatedBy: truncated
          ? (tailTruncation.truncatedBy ??
                (totalBytes > defaultMaxBytes
                    ? TruncatedBy.bytes
                    : TruncatedBy.lines))
          : null,
      totalLines: totalLines,
      totalBytes: totalBytes,
      outputLines: tailTruncation.outputLines,
      outputBytes: tailTruncation.outputBytes,
      lastLinePartial: tailTruncation.lastLinePartial,
      firstLineExceedsLimit: tailTruncation.firstLineExceedsLimit,
      maxLines: tailTruncation.maxLines,
      maxBytes: tailTruncation.maxBytes,
    );
    return ShellCaptureProgress(
      output: truncated ? truncation.content : tailOutput,
      truncation: truncation,
      fullOutputPath: fullOutputPath,
      lastLineBytes: currentLineBytes,
    );
  }

  void onChunk(String chunk) {
    if (!acceptingOutput) {
      return;
    }
    try {
      final text = sanitizeBinaryOutput(chunk).replaceAll('\r', '');
      final textBytes = utf8ByteLengthOf(text);
      totalBytes += textBytes;
      final newlineCount = '\n'.allMatches(text).length;
      completedLines += newlineCount;
      final lastNewline = text.lastIndexOf('\n');
      if (lastNewline >= 0) {
        final trailingText = text.substring(lastNewline + 1);
        currentLineBytes = utf8ByteLengthOf(trailingText);
        hasOpenLine = trailingText.isNotEmpty;
      } else if (text.isNotEmpty) {
        currentLineBytes += textBytes;
        hasOpenLine = true;
      }

      tailOutput += text;
      final totalLines = completedLines + (hasOpenLine ? 1 : 0);
      if ((totalBytes > defaultMaxBytes || totalLines > defaultMaxLines) &&
          !fullOutputRequested) {
        ensureFullOutputFile(tailOutput);
      } else if (fullOutputRequested) {
        appendFullOutput(text);
      }
      tailOutput = _trimToLastUtf8Bytes(tailOutput, maxOutputBytes);
      options?.onChunk?.call(text, createProgress);
    } catch (error) {
      captureError = _toExecutionError(error);
    }
  }

  try {
    final result = await env.exec(
      command,
      ShellExecOptions(
        cwd: options?.cwd,
        env: options?.env,
        inheritEnv: options?.inheritEnv ?? true,
        timeout: options?.timeout,
        abortSignal: options?.abortSignal,
        onStdout: onChunk,
        onStderr: onChunk,
      ),
    );
    acceptingOutput = false;
    var progress = createProgress();
    if (progress.truncation.truncated && !fullOutputRequested) {
      ensureFullOutputFile(tailOutput);
    }
    final writeResult = await writeChain;
    final writeError = writeResult.errorOrNull;
    if (writeError != null) {
      return err(writeError);
    }
    if (captureError != null) {
      return err(captureError!);
    }
    progress = createProgress();

    final value = result.valueOrNull;
    if (value == null) {
      final error = result.errorOrNull!;
      if (error.code == ExecutionErrorCode.aborted ||
          options?.abortSignal?.aborted == true) {
        return ok(
          ShellCaptureResult(
            output: progress.output,
            truncation: progress.truncation,
            fullOutputPath: progress.fullOutputPath,
            lastLineBytes: progress.lastLineBytes,
            exitCode: null,
            cancelled: true,
            truncated: progress.truncation.truncated,
          ),
        );
      }
      if (options?.returnExecutionErrors == true) {
        return ok(
          ShellCaptureResult(
            output: progress.output,
            truncation: progress.truncation,
            fullOutputPath: progress.fullOutputPath,
            lastLineBytes: progress.lastLineBytes,
            exitCode: null,
            cancelled: false,
            truncated: progress.truncation.truncated,
            executionError: error,
          ),
        );
      }
      return err(error);
    }
    final cancelled = options?.abortSignal?.aborted ?? false;
    return ok(
      ShellCaptureResult(
        output: progress.output,
        truncation: progress.truncation,
        fullOutputPath: progress.fullOutputPath,
        lastLineBytes: progress.lastLineBytes,
        exitCode: cancelled ? null : value.exitCode,
        cancelled: cancelled,
        truncated: progress.truncation.truncated,
      ),
    );
  } catch (error) {
    acceptingOutput = false;
    return err(_toExecutionError(error));
  }
}

String _trimToLastUtf8Bytes(String text, int maxBytes) {
  final bytes = utf8.encode(text);
  if (bytes.length <= maxBytes) {
    return text;
  }
  var start = bytes.length - maxBytes;
  while (start < bytes.length && (bytes[start] & 0xc0) == 0x80) {
    start++;
  }
  return utf8DecodeAllowMalformed(bytes.sublist(start));
}
