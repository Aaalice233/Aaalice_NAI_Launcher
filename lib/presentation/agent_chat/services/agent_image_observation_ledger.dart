import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';

/// 按会话记录模型真正以视觉输入收到过的图片，以及收到时的最大长边。
///
/// 应用不检测模型视觉能力，缺了这道台账，Agent 可能只见过展示缩略图甚至只见过
/// 结果里的 size 字段，就编出坐标，最终花 Anlas 重绘错位置。
class AgentImageObservationLedger {
  final Map<String, Map<String, int>> _observedBySession = {};

  /// 判据是结果里是否真的挂了图片内容：读文本不会产生 [ToolResultImageContent]。
  void recordToolResult(String sessionId, AgentToolResult result) {
    if (result.isError) return;
    final images = result.content.whereType<ToolResultImageContent>().toList();
    if (images.isEmpty) return;
    final longSide = _feedLongSide(images);
    if (longSide == null) return;
    final details = result.details;
    if (details is! Map) return;
    final keys = _identityKeys(details);
    if (keys.isEmpty) return;
    final observed = _observedBySession.putIfAbsent(sessionId, () => {});
    for (final key in keys) {
      final previous = observed[key];
      observed[key] = previous == null
          ? longSide
          : math.max(previous, longSide);
    }
  }

  bool hasObserved(
    String sessionId, {
    Iterable<String> paths = const [],
    Iterable<AgentChatResourceReference> references = const [],
    required int sourceLongSide,
  }) {
    final observed = _observedBySession[sessionId];
    if (observed == null) return false;
    final keys = [
      for (final path in paths) _pathKey(path),
      for (final reference in references) _referenceKey(reference),
    ];
    return keys.any((key) {
      final observedLongSide = observed[key];
      return observedLongSide != null &&
          isUsableObservation(
            observedLongSide: observedLongSide,
            sourceLongSide: sourceLongSide,
          );
    });
  }

  /// 展示缩略图不是测量输入；但源图本身不大于缩略图时，缩略图就是原图。
  static bool isUsableObservation({
    required int observedLongSide,
    required int sourceLongSide,
  }) =>
      observedLongSide > DisplayThumbnailUtils.maxDimension ||
      observedLongSide >= sourceLongSide;

  void forgetSession(String sessionId) => _observedBySession.remove(sessionId);

  /// 传入的是当前仍然存活的全部会话：断开的会话不能继续替后来者放行。
  void retainSessions(Iterable<String> sessionIds) {
    final live = sessionIds.toSet();
    _observedBySession.removeWhere((sessionId, _) => !live.contains(sessionId));
  }

  void clear() => _observedBySession.clear();

  /// 一个结果里的多张图与多个身份无法逐一对齐，取最小长边是保守做法。
  static int? _feedLongSide(List<ToolResultImageContent> images) {
    int? smallest;
    for (final image in images) {
      final bytes = image.image.source.bytes;
      if (bytes == null) return null;
      final size = NaiResolutionAdapter.readImageSize(bytes);
      if (size == null) return null;
      final longSide = math.max(size.$1, size.$2);
      smallest = smallest == null ? longSide : math.min(smallest, longSide);
    }
    return smallest;
  }

  static List<String> _identityKeys(Map<Object?, Object?> details) {
    final keys = <String>[];
    final files = details['files'];
    if (files is List) {
      for (final file in files) {
        if (file is String && file.trim().isNotEmpty) keys.add(_pathKey(file));
      }
    }
    final images = details['images'];
    if (images is List) {
      for (final image in images) {
        if (image is! Map) continue;
        final reference = _tryDecodeReference(image['resource_ref']);
        if (reference != null) keys.add(_referenceKey(reference));
      }
    }
    return keys;
  }

  static AgentChatResourceReference? _tryDecodeReference(Object? encoded) {
    if (encoded is! Map || encoded.keys.any((key) => key is! String)) {
      return null;
    }
    try {
      return AgentChatResourceReferenceCodec.decodeJsonMap(
        Map<String, dynamic>.from(encoded),
      );
    } on FormatException {
      return null;
    }
  }

  static String _pathKey(String path) => 'path:${p.canonicalize(path)}';

  static String _referenceKey(AgentChatResourceReference reference) =>
      'ref:${reference.identityKey}';
}

/// 转发工具调用，并把成功返回图片的那次调用记进 [AgentImageObservationLedger]。
class ImageObservingAgentTool extends AgentTool {
  ImageObservingAgentTool(
    AgentTool inner, {
    required AgentImageObservationLedger ledger,
    required String Function() activeSessionId,
  }) : _inner = inner,
       _ledger = ledger,
       _activeSessionId = activeSessionId,
       super(
         name: inner.name,
         description: inner.description,
         parameters: inner.parameters,
         label: inner.label,
       );

  final AgentTool _inner;
  final AgentImageObservationLedger _ledger;
  final String Function() _activeSessionId;

  @override
  Map<String, dynamic> prepareArguments(Map<String, dynamic> args) =>
      _inner.prepareArguments(args);

  @override
  ToolExecutionMode? get executionMode => _inner.executionMode;

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    final result = await _inner.execute(toolCallId, params, signal, onUpdate);
    _ledger.recordToolResult(_activeSessionId(), result);
    return result;
  }
}
