import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/agent/agent_types.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_resolution_adapter.dart';
import '../providers/agent_chat_notifier.dart';

class AgentChatToolActivityTile extends StatelessWidget {
  const AgentChatToolActivityTile({super.key, required this.activity});

  final AgentToolActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final (icon, color, label) = switch (activity.status) {
      AgentToolActivityStatus.running => (
        Icons.hourglass_top,
        theme.colorScheme.onSurface.withValues(alpha: 0.5),
        l10n.agentChat_toolRunning,
      ),
      AgentToolActivityStatus.succeeded => (
        Icons.check_circle_outline,
        theme.colorScheme.tertiary,
        activity.toolName,
      ),
      AgentToolActivityStatus.failed => (
        Icons.error_outline,
        theme.colorScheme.error,
        activity.toolName,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label · ${_summarize(activity)}',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _summarize(AgentToolActivity activity) {
    if (activity.status == AgentToolActivityStatus.running) {
      return activity.toolName;
    }
    final text = activity.content.trim();
    if (text.isEmpty) return activity.toolName;
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    return normalized.length <= 60
        ? normalized
        : '${normalized.substring(0, 60)}…';
  }
}

class AgentChatToolResultTile extends StatelessWidget {
  const AgentChatToolResultTile({super.key, required this.result});

  final ToolResultMessage result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = _extractImageFiles(result);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isError
                    ? Icons.error_outline
                    : Icons.build_circle_outlined,
                size: 12,
                color: result.isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  result.toolName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: result.isError
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final path in files)
                    _ToolResultImage(key: ValueKey(path), path: path),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

List<String> _extractImageFiles(ToolResultMessage result) {
  final details = result.details;
  if (details is Map && details['files'] is List) {
    final files = [
      for (final file in details['files'] as List)
        if (file is String) file,
    ];
    if (files.isNotEmpty) return files;
  }
  for (final content in result.content) {
    if (content is! ToolResultTextContent) continue;
    final text = content.text.trim();
    if (!text.startsWith('{')) continue;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['images'] is List) {
        return [
          for (final image in decoded['images'] as List)
            if (image is Map && image['file'] is String)
              image['file'] as String,
        ];
      }
    } catch (_) {
      // Tool output may be ordinary text rather than a persisted JSON report.
    }
  }
  return const [];
}

class _ToolResultImage extends StatelessWidget {
  const _ToolResultImage({super.key, required this.path});

  static const int _maxHeaderBytes = 64 * 1024;
  static final Map<String, double> _aspectCache = {};
  final String path;

  double _readAspect(File file) {
    final cached = _aspectCache[path];
    if (cached != null) return cached;
    var aspect = 4 / 3;
    RandomAccessFile? handle;
    try {
      final length = file.lengthSync();
      final headerLength = length < _maxHeaderBytes ? length : _maxHeaderBytes;
      handle = file.openSync();
      final dimensions = NaiResolutionAdapter.readImageSize(
        handle.readSync(headerLength),
      );
      if (dimensions != null && dimensions.$1 > 0 && dimensions.$2 > 0) {
        aspect = dimensions.$1 / dimensions.$2;
      }
    } catch (_) {
      // Keep a stable placeholder ratio for damaged or unsupported files.
    } finally {
      handle?.closeSync();
    }
    _aspectCache[path] = aspect;
    return aspect;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(path);
    if (!file.existsSync()) return _missing(theme);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
          child: AspectRatio(
            aspectRatio: _readAspect(file),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _missing(theme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _missing(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      '找不到图片：$path',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    ),
  );
}
