import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/agent/private_data_guard.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/windowing/agent_chat_shared_widgets.dart';
import '../../themes/theme_extension.dart';
import 'agent_chat_tool_widgets.dart';

/// Adapts an authoritative approval request to the approval surface shared by
/// the embedded and detached Agent clients.
class AgentChatApprovalCard extends StatefulWidget {
  const AgentChatApprovalCard({
    super.key,
    required this.toolName,
    required this.args,
    required this.estimatedAnlas,
    required this.touchOptimized,
    required this.onResolve,
  });

  final String toolName;
  final Map<String, dynamic> args;
  final int? estimatedAnlas;
  final bool touchOptimized;
  final void Function(bool approved) onResolve;

  @override
  State<AgentChatApprovalCard> createState() => _AgentChatApprovalCardState();
}

class _AgentChatApprovalCardState extends State<AgentChatApprovalCard> {
  late String _requestSignature = _signatureFor(widget);
  bool _resolutionSubmitted = false;

  @override
  void didUpdateWidget(AgentChatApprovalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _signatureFor(widget);
    if (nextSignature != _requestSignature) {
      _requestSignature = nextSignature;
      _resolutionSubmitted = false;
    }
  }

  Object? get _sanitizedArgs => _sanitizeApprovalValue(widget.args);

  String get _details {
    if (widget.args.isEmpty) return '';
    final sanitized = _sanitizedArgs;
    late String encoded;
    try {
      encoded = const JsonEncoder.withIndent('  ').convert(sanitized);
    } on JsonUnsupportedObjectError {
      encoded = sanitized.toString();
    }
    return '${context.l10n.generation_params}\n$encoded';
  }

  void _resolve(bool approved) {
    if (_resolutionSubmitted) return;
    setState(() => _resolutionSubmitted = true);
    widget.onResolve(approved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final toolLabel = agentToolLabel(context, widget.toolName);
    final description = widget.toolName.toLowerCase().contains('delete')
        ? l10n.common_deleteItemConfirm(toolLabel)
        : l10n.agentChat_approvalDescription;
    final surface = AgentChatApprovalSurface(
      title: l10n.agentChat_approvalTitle(toolLabel),
      description: description,
      details: _details,
      costLabel: widget.estimatedAnlas == null
          ? null
          : l10n.agentChat_approvalEstimatedAnlas(widget.estimatedAnlas!),
      denyLabel: l10n.agentChat_approvalDeny,
      allowLabel: l10n.agentChat_approvalAllow,
      touchOptimized: widget.touchOptimized,
      onDeny: () => _resolve(false),
      onAllow: () => _resolve(true),
    );

    return Semantics(
      enabled: !_resolutionSubmitted,
      child: FocusScope(
        canRequestFocus: !_resolutionSubmitted,
        descendantsAreFocusable: !_resolutionSubmitted,
        child: IgnorePointer(
          ignoring: _resolutionSubmitted,
          child: AnimatedOpacity(
            opacity: _resolutionSubmitted ? 0.58 : 1,
            duration: Theme.of(context).appTheme.fastDuration,
            curve: Theme.of(context).appTheme.standardCurve,
            child: surface,
          ),
        ),
      ),
    );
  }

  static String _signatureFor(AgentChatApprovalCard widget) {
    final sanitized = _sanitizeApprovalValue(widget.args);
    String encoded;
    try {
      encoded = jsonEncode(sanitized);
    } on JsonUnsupportedObjectError {
      encoded = sanitized.toString();
    }
    return '${widget.toolName}\u0000${widget.estimatedAnlas}\u0000$encoded';
  }
}

Object? _sanitizeApprovalValue(Object? value, [String? fieldName]) {
  if (value is Uint8List || value is ByteBuffer || value is ByteData) {
    return '[binary omitted]';
  }
  if (value == null || value is bool || value is num) return value;
  if (value is String) {
    if (_isSensitiveField(fieldName) ||
        PrivateDataGuard.detect(value) == 'credential') {
      return '[redacted]';
    }
    if (_isPathField(fieldName)) return '[local path]';
    if (_looksLikeEmbeddedBinary(value)) return '[binary omitted]';
    return PrivateDataGuard.redactAbsolutePaths(value);
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _sanitizeApprovalValue(
          entry.value,
          entry.key.toString(),
        ),
    };
  }
  if (value is Iterable) {
    return [for (final item in value) _sanitizeApprovalValue(item, fieldName)];
  }
  return _sanitizeApprovalValue(value.toString(), fieldName);
}

bool _isSensitiveField(String? fieldName) {
  final normalized = fieldName?.toLowerCase().replaceAll(
    RegExp('[^a-z0-9]'),
    '',
  );
  if (normalized == null) return false;
  return normalized.contains('token') ||
      normalized.contains('secret') ||
      normalized.contains('password') ||
      normalized.contains('credential') ||
      normalized.contains('authorization') ||
      normalized == 'auth' ||
      normalized == 'cookie' ||
      normalized == 'key' ||
      normalized == 'apikey' ||
      normalized == 'accesskey' ||
      normalized == 'privatekey' ||
      normalized.contains('signature');
}

bool _isPathField(String? fieldName) {
  final normalized = fieldName?.toLowerCase().replaceAll(
    RegExp('[^a-z0-9]'),
    '',
  );
  if (normalized == null) return false;
  return normalized == 'path' ||
      normalized.endsWith('path') ||
      normalized.endsWith('filepath') ||
      normalized == 'directory' ||
      normalized.endsWith('directory');
}

bool _looksLikeEmbeddedBinary(String value) {
  final normalized = value.trimLeft().toLowerCase();
  if (normalized.startsWith('data:') && normalized.contains(';base64,')) {
    return true;
  }
  return value.length > 1024 &&
      RegExp(r'^[A-Za-z0-9+/=_\s-]+$').hasMatch(value);
}
