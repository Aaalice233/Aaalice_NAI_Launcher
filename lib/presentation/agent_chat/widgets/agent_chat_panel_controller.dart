import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, KeyUpEvent, LogicalKeyboardKey;

import '../../widgets/common/image_viewport_surface.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../providers/agent_chat_notifier.dart';
import 'agent_chat_input_controller.dart';

@immutable
class PendingAgentChatImage {
  const PendingAgentChatImage({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

/// Keeps viewport ownership across responsive panel reconstruction.
class AgentChatViewportStore {
  final Map<String, ({double offset, bool autoScroll})> sessionOffsets = {};
}

/// Owns all ephemeral panel resources so the widget shell only coordinates
/// provider state and immutable view data.
class AgentChatPanelController extends ChangeNotifier {
  AgentChatPanelController({
    AgentChatViewportStore? viewportStore,
    String initialSessionId = '',
  }) : _viewportStore = viewportStore ?? AgentChatViewportStore() {
    final savedViewport = _sessionOffsets[initialSessionId];
    _lastScrollSessionId = initialSessionId;
    _autoScroll = savedViewport?.autoScroll ?? true;
    inputController = AgentChatInputController(
      onImageEnter: showInlineImagePreview,
      onImageExit: hideInlineImagePreview,
    );
    scrollController = _AgentChatScrollController(
      initialScrollOffset: savedViewport?.offset ?? 0,
      onAttachPosition: _handleScrollPositionAttached,
      onDetachPosition: _handleScrollPositionDetached,
    );
  }

  static const double _nearBottomTolerance = 48.0;
  static const double _scrollMovementTolerance = 0.01;
  static const int _retainedSessionOffsetCount = 32;
  static final Set<LogicalKeyboardKey> _viewportScrollKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
    LogicalKeyboardKey.space,
  };

  late final AgentChatInputController inputController;
  late final ScrollController scrollController;
  final FocusNode inputFocus = FocusNode();
  final List<PendingAgentChatImage> _pendingImages = [];
  final Map<ImageSource, Uint8List> messageImageBytes = {};
  final Map<ImageSource, Size> messageImageSizes = {};
  final Map<String, Uint8List> markdownDataImageBytes = {};
  final AgentChatViewportStore _viewportStore;
  final Map<ScrollPosition, String> _positionSessionIds = {};

  Map<String, ({double offset, bool autoScroll})> get _sessionOffsets =>
      _viewportStore.sessionOffsets;

  OverlayEntry? _inlineImagePreview;
  BuildContext? _overlayContext;
  bool _autoScroll = true;
  bool _userScrollActive = false;
  bool _potentialUserScroll = false;
  bool _programmaticScrollActive = false;
  double? _lastUserScrollPixels;
  bool _scrollToBottomScheduled = false;
  bool _viewportRestoreScheduled = false;
  bool _needsViewportRestore = false;
  int _viewportRestoreGeneration = 0;
  int _viewportInteractionRevision = 0;
  int _lastScrollMessageCount = -1;
  String _lastScrollSessionId = '';
  AssistantMessage? _lastStreamingMessage;
  List<AgentToolActivity>? _lastActivities;
  int? _hoveredUserMessageIndex;
  int? _focusedUserMessageIndex;
  int? _editingUserMessageIndex;
  String? _composerTextBeforeEdit;
  List<PendingAgentChatImage>? _composerImagesBeforeEdit;

  List<PendingAgentChatImage> get pendingImages =>
      List.unmodifiable(_pendingImages);
  int? get hoveredUserMessageIndex => _hoveredUserMessageIndex;
  int? get focusedUserMessageIndex => _focusedUserMessageIndex;
  int? get editingUserMessageIndex => _editingUserMessageIndex;
  bool get isEditingUserMessage => _editingUserMessageIndex != null;
  bool get showJumpToLatest => !_autoScroll;
  bool get followingLatest => _autoScroll;
  int get viewportInteractionRevision => _viewportInteractionRevision;

  void setHoveredUserMessageIndex(int? value) {
    if (_hoveredUserMessageIndex == value) return;
    _hoveredUserMessageIndex = value;
    notifyListeners();
  }

  void setFocusedUserMessageIndex(int? value) {
    if (_focusedUserMessageIndex == value) return;
    _focusedUserMessageIndex = value;
    notifyListeners();
  }

  void attachOverlayContext(BuildContext context) => _overlayContext = context;

  void observe(AgentChatState state) {
    final previousSessionId = _lastScrollSessionId;
    final sessionChanged = state.activeSessionId != previousSessionId;
    final messagesChanged = state.messages.length != _lastScrollMessageCount;
    final streamingChanged = !identical(
      state.streamingMessage,
      _lastStreamingMessage,
    );
    final activitiesChanged = !identical(state.activities, _lastActivities);
    final contentChanged =
        messagesChanged || streamingChanged || activitiesChanged;
    if (sessionChanged) {
      _logViewport(
        'observe.sessionChanged',
        detail:
            'from=${_sessionLabel(previousSessionId)} '
            'to=${_sessionLabel(state.activeSessionId)}',
      );
    }
    if (sessionChanged && previousSessionId.isNotEmpty) {
      saveSessionOffset(previousSessionId);
      _endUserScroll();
      _viewportInteractionRevision++;
    }
    _lastScrollSessionId = state.activeSessionId;
    _lastScrollMessageCount = state.messages.length;
    _lastStreamingMessage = state.streamingMessage;
    _lastActivities = state.activities;
    if (sessionChanged) {
      messageImageBytes.clear();
      messageImageSizes.clear();
      markdownDataImageBytes.clear();
      _editingUserMessageIndex = null;
      _composerTextBeforeEdit = null;
      _composerImagesBeforeEdit = null;
      final savedViewport = _sessionOffsets[state.activeSessionId];
      if (savedViewport == null) {
        scrollToBottom(force: true);
      } else {
        _autoScroll = savedViewport.autoScroll;
        _needsViewportRestore = true;
      }
    } else if (contentChanged && _autoScroll) {
      scrollToBottom();
    }
  }

  void syncComposerText(String text) {
    if (inputController.text == text) return;
    inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void addPendingImage(PendingAgentChatImage image) {
    _pendingImages.add(image);
    inputController.imageCount = _pendingImages.length;
    insertImageToken(_pendingImages.length);
    notifyListeners();
  }

  void removePendingImage(int index) {
    if (index < 0 || index >= _pendingImages.length) return;
    hideInlineImagePreview();
    _pendingImages.removeAt(index);
    final removedNumber = index + 1;
    inputController.value = inputController.value.copyWith(
      text: inputController.text
          .replaceAllMapped(AgentChatInputController.imagePattern, (match) {
            final number = int.tryParse(match.group(1) ?? '');
            if (number == null) return match.group(0)!;
            if (number == removedNumber) return '';
            return number > removedNumber
                ? '[image${number - 1}]'
                : match.group(0)!;
          })
          .replaceAll(RegExp(r' {2,}'), ' '),
      composing: TextRange.empty,
    );
    inputController.imageCount = _pendingImages.length;
    notifyListeners();
  }

  List<PendingAgentChatImage> takePendingImages() {
    final images = List<PendingAgentChatImage>.of(_pendingImages);
    hideInlineImagePreview();
    _pendingImages.clear();
    inputController.imageCount = 0;
    inputController.clear();
    notifyListeners();
    return images;
  }

  void restoreDraft(String text, List<PendingAgentChatImage> images) {
    hideInlineImagePreview();
    _pendingImages
      ..clear()
      ..addAll(images);
    inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    inputController.imageCount = images.length;
    _hoveredUserMessageIndex = null;
    notifyListeners();
  }

  void beginEditingUserMessage(
    int messageIndex,
    String text,
    List<PendingAgentChatImage> images,
  ) {
    if (!isEditingUserMessage) {
      _composerTextBeforeEdit = inputController.text;
      _composerImagesBeforeEdit = List.of(_pendingImages);
    }
    _editingUserMessageIndex = messageIndex;
    restoreDraft(text, images);
  }

  void cancelEditingUserMessage() {
    if (!isEditingUserMessage) return;
    final text = _composerTextBeforeEdit ?? '';
    final images = _composerImagesBeforeEdit ?? const <PendingAgentChatImage>[];
    finishEditingUserMessage();
    restoreDraft(text, images);
  }

  void finishEditingUserMessage() {
    if (!isEditingUserMessage) return;
    _editingUserMessageIndex = null;
    _composerTextBeforeEdit = null;
    _composerImagesBeforeEdit = null;
    notifyListeners();
  }

  List<UserContent> buildInlineUserContent(
    String text,
    List<PendingAgentChatImage> images,
  ) {
    final content = <UserContent>[];
    var textStart = 0;
    for (final match in AgentChatInputController.imagePattern.allMatches(
      text,
    )) {
      final imageNumber = int.tryParse(match.group(1) ?? '');
      if (imageNumber == null ||
          imageNumber < 1 ||
          imageNumber > images.length) {
        continue;
      }
      final leadingText = text.substring(textStart, match.start);
      if (leadingText.trim().isNotEmpty) {
        content.add(UserTextContent(leadingText));
      }
      final image = images[imageNumber - 1];
      content.add(
        UserImageContent(
          ImageContent(
            source: ImageSource.base64(
              mimeType: image.mimeType,
              base64Data: base64Encode(image.bytes),
            ),
          ),
        ),
      );
      textStart = match.end;
    }
    final trailingText = text.substring(textStart);
    if (trailingText.trim().isNotEmpty) {
      content.add(UserTextContent(trailingText));
    }
    return content;
  }

  void insertImageToken(int imageNumber) {
    final value = inputController.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    final needsLeadingSpace =
        start > 0 && !RegExp(r'\s').hasMatch(value.text[start - 1]);
    final needsTrailingSpace =
        end < value.text.length && !RegExp(r'\s').hasMatch(value.text[end]);
    final insertion =
        '${needsLeadingSpace ? ' ' : ''}[image$imageNumber]'
        '${needsTrailingSpace || end == value.text.length ? ' ' : ''}';
    inputController.value = TextEditingValue(
      text: value.text.replaceRange(start, end, insertion),
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
  }

  /// 用选中的命令替换开头正在编辑的 `/片段`，光标落到名称之后。
  void applySlashCommand(String name, int queryEnd) {
    final value = inputController.value;
    final end = queryEnd.clamp(0, value.text.length);
    final rest = value.text.substring(end);
    final insertion = rest.isEmpty || !RegExp(r'^\s').hasMatch(rest)
        ? '/$name '
        : '/$name';
    inputController.value = TextEditingValue(
      text: '$insertion$rest',
      selection: TextSelection.collapsed(offset: insertion.length),
    );
    inputFocus.requestFocus();
  }

  /// 会话命令即时执行后清掉开头片段，保留用户已写的其余内容。
  void removeLeadingSlashToken(int queryEnd) {
    final value = inputController.value;
    final end = queryEnd.clamp(0, value.text.length);
    final text = value.text.substring(end).trimLeft();
    inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void insertNewline() {
    final value = inputController.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    inputController.value = TextEditingValue(
      text: value.text.replaceRange(start, end, '\n'),
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  void setSuggestion(String suggestion) {
    inputController.text = suggestion;
    inputFocus.requestFocus();
  }

  Uint8List? bytesForMessageImage(ImageSource source) {
    final cached = messageImageBytes[source];
    if (cached != null) return cached;
    final encoded = source.base64Data;
    if (encoded == null) return null;
    try {
      final bytes = base64Decode(encoded);
      messageImageBytes[source] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Size displaySizeForMessageImage(ImageSource source, Uint8List bytes) {
    final cached = messageImageSizes[source];
    if (cached != null) return cached;
    const maxWidth = 200.0;
    const maxHeight = 180.0;
    final dimensions = NaiResolutionAdapter.readImageSize(bytes);
    if (dimensions == null || dimensions.$1 <= 0 || dimensions.$2 <= 0) {
      const fallback = Size(160, 120);
      messageImageSizes[source] = fallback;
      return fallback;
    }
    final widthScale = maxWidth / dimensions.$1;
    final heightScale = maxHeight / dimensions.$2;
    final scale = widthScale < heightScale ? widthScale : heightScale;
    final size = Size(dimensions.$1 * scale, dimensions.$2 * scale);
    messageImageSizes[source] = size;
    return size;
  }

  void showInlineImagePreview(int imageNumber, Offset pointerPosition) {
    hideInlineImagePreview();
    final context = _overlayContext;
    if (context == null ||
        imageNumber < 1 ||
        imageNumber > _pendingImages.length) {
      return;
    }
    final image = _pendingImages[imageNumber - 1];
    final dimensions = NaiResolutionAdapter.readImageSize(image.bytes);
    const maxSize = 240.0;
    final Size previewSize;
    if (dimensions == null || dimensions.$1 <= 0 || dimensions.$2 <= 0) {
      previewSize = const Size(maxSize, maxSize);
    } else {
      final widthScale = maxSize / dimensions.$1;
      final heightScale = maxSize / dimensions.$2;
      final scale = widthScale < heightScale ? widthScale : heightScale;
      previewSize = Size(dimensions.$1 * scale, dimensions.$2 * scale);
    }
    final viewport = MediaQuery.sizeOf(context);
    var left = pointerPosition.dx + 12;
    if (left + previewSize.width > viewport.width - 12) {
      left = pointerPosition.dx - previewSize.width - 12;
    }
    left = left.clamp(12.0, viewport.width - previewSize.width - 12).toDouble();
    var top = pointerPosition.dy + 16;
    if (top + previewSize.height > viewport.height - 12) {
      top = pointerPosition.dy - previewSize.height - 16;
    }
    top = top.clamp(12.0, viewport.height - previewSize.height - 12).toDouble();
    final entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: left,
        top: top,
        width: previewSize.width,
        height: previewSize.height,
        child: IgnorePointer(
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            color: ImageViewportSurface.background,
            child: Image.memory(
              image.bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(overlayContext).colorScheme.outline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _inlineImagePreview = entry;
    Overlay.of(context).insert(entry);
  }

  void hideInlineImagePreview() {
    _inlineImagePreview?.remove();
    _inlineImagePreview = null;
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || _programmaticScrollActive) return false;

    switch (notification) {
      case UserScrollNotification(:final direction):
        if (direction == ScrollDirection.idle) {
          _endUserScroll();
        } else {
          _beginUserScroll(notification.metrics);
        }
      case ScrollStartNotification(:final dragDetails)
          when dragDetails != null || _potentialUserScroll:
        _beginUserScroll(notification.metrics);
      case ScrollUpdateNotification(:final dragDetails, :final scrollDelta)
          when dragDetails != null || _userScrollActive || _potentialUserScroll:
        _beginUserScroll(notification.metrics, preserveBaseline: true);
        _updateUserScrollIntent(notification.metrics, scrollDelta: scrollDelta);
      case ScrollEndNotification():
        _endUserScroll();
      default:
        break;
    }
    _rememberValidViewport(notification.metrics);
    return false;
  }

  bool handleScrollMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    if (!_hasUsableViewport(metrics)) {
      if (!_needsViewportRestore) {
        _logViewport('metrics.invalid', metrics: metrics);
      }
      _needsViewportRestore = true;
      return false;
    }
    if (_needsViewportRestore) {
      _logViewport('metrics.validAfterInvalid', metrics: metrics);
      _scheduleViewportRestore();
    } else {
      _rememberValidViewport(metrics);
    }
    return false;
  }

  void beginPotentialUserScroll() {
    if (_programmaticScrollActive) return;
    _potentialUserScroll = true;
    if (scrollController.hasClients) {
      _lastUserScrollPixels = scrollController.position.pixels;
    }
  }

  void cancelPotentialUserScroll() {
    _potentialUserScroll = false;
    if (!_userScrollActive) _lastUserScrollPixels = null;
  }

  KeyEventResult handleViewportKeyEvent(FocusNode _, KeyEvent event) {
    if (!_viewportScrollKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      beginPotentialUserScroll();
    } else if (event is KeyUpEvent) {
      cancelPotentialUserScroll();
    }
    return KeyEventResult.ignored;
  }

  void _beginUserScroll(
    ScrollMetrics metrics, {
    bool preserveBaseline = false,
  }) {
    if (!_userScrollActive &&
        (!preserveBaseline || _lastUserScrollPixels == null)) {
      _lastUserScrollPixels = metrics.pixels;
    }
    _potentialUserScroll = false;
    _userScrollActive = true;
  }

  void _endUserScroll() {
    _potentialUserScroll = false;
    _userScrollActive = false;
    _lastUserScrollPixels = null;
  }

  void _updateUserScrollIntent(ScrollMetrics metrics, {double? scrollDelta}) {
    final previousPixels = _lastUserScrollPixels;
    final delta = previousPixels == null
        ? scrollDelta ?? 0
        : metrics.pixels - previousPixels;
    _lastUserScrollPixels = metrics.pixels;
    if (delta.abs() <= _scrollMovementTolerance) return;
    _viewportInteractionRevision++;
    if (delta > 0) {
      if (_autoScroll) {
        _logViewport('userScroll.pauseFollow', metrics: metrics);
      }
      _setAutoScroll(false);
    } else if (_isNearBottom(metrics)) {
      if (!_autoScroll) {
        _logViewport('userScroll.resumeFollow', metrics: metrics);
      }
      _setAutoScroll(true);
    }
  }

  bool _isNearBottom(ScrollMetrics metrics) =>
      metrics.pixels <= metrics.minScrollExtent + _nearBottomTolerance;

  void _setAutoScroll(bool value) {
    if (_autoScroll == value) return;
    _autoScroll = value;
    _updateSavedFollowIntent();
    notifyListeners();
  }

  bool _hasUsableViewport(ScrollMetrics metrics) =>
      metrics.hasPixels &&
      metrics.hasContentDimensions &&
      metrics.viewportDimension > 0 &&
      metrics.pixels.isFinite;

  void _rememberValidViewport(ScrollMetrics metrics) {
    final sessionId = _lastScrollSessionId;
    if (sessionId.isEmpty || !_hasUsableViewport(metrics)) return;
    _storeSessionViewport(sessionId, metrics.pixels, _autoScroll);
  }

  void _updateSavedFollowIntent() {
    final sessionId = _lastScrollSessionId;
    if (sessionId.isEmpty) return;
    final saved = _sessionOffsets[sessionId];
    if (saved != null) {
      _storeSessionViewport(sessionId, saved.offset, _autoScroll);
    } else if (scrollController.hasClients) {
      _rememberValidViewport(scrollController.position);
    }
  }

  void _storeSessionViewport(String sessionId, double offset, bool autoScroll) {
    _sessionOffsets.remove(sessionId);
    _sessionOffsets[sessionId] = (offset: offset, autoScroll: autoScroll);
    while (_sessionOffsets.length > _retainedSessionOffsetCount) {
      _sessionOffsets.remove(_sessionOffsets.keys.first);
    }
  }

  void _handleScrollPositionAttached(ScrollPosition position) {
    _positionSessionIds[position] = _lastScrollSessionId;
    _needsViewportRestore = true;
    _logViewport('position.attach', metrics: position);
    _scheduleViewportRestore();
  }

  void _handleScrollPositionDetached(ScrollPosition position) {
    final sessionId = _positionSessionIds.remove(position);
    _logViewport(
      'position.detach',
      metrics: position,
      detail: 'positionSession=${_sessionLabel(sessionId ?? '')}',
    );
    if (sessionId != null &&
        sessionId.isNotEmpty &&
        _hasUsableViewport(position)) {
      final saved = _sessionOffsets[sessionId];
      _storeSessionViewport(
        sessionId,
        position.pixels,
        saved?.autoScroll ?? _autoScroll,
      );
    }
    _needsViewportRestore = true;
    _viewportRestoreGeneration++;
    _viewportRestoreScheduled = false;
  }

  void _scheduleViewportRestore() {
    if (_viewportRestoreScheduled) return;
    _viewportRestoreScheduled = true;
    final generation = ++_viewportRestoreGeneration;
    _logViewport('restore.schedule', detail: 'generation=$generation');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportRestoreScheduled = false;
      if (generation != _viewportRestoreGeneration ||
          !_needsViewportRestore ||
          !scrollController.hasClients) {
        _logViewport(
          'restore.skip',
          detail:
              'generation=$generation current=$_viewportRestoreGeneration '
              'needs=$_needsViewportRestore',
        );
        return;
      }
      final position = scrollController.position;
      if (!_hasUsableViewport(position)) {
        _logViewport('restore.waitForUsableViewport', metrics: position);
        return;
      }
      _needsViewportRestore = false;
      final saved = _sessionOffsets[_lastScrollSessionId];
      if (saved == null) {
        _logViewport('restore.noSavedViewport', metrics: position);
        if (_autoScroll) scrollToBottom();
        return;
      }
      _logViewport(
        'restore.apply',
        metrics: position,
        detail:
            'target=${saved.offset.toStringAsFixed(1)} '
            'savedFollow=${saved.autoScroll}',
      );
      _setAutoScroll(saved.autoScroll);
      if (saved.autoScroll) {
        scrollToBottom();
      } else {
        jumpToPreservingFollow(saved.offset);
      }
    });
  }

  void saveSessionOffset(String sessionId) {
    if (sessionId.isEmpty ||
        sessionId != _lastScrollSessionId ||
        !scrollController.hasClients) {
      _logViewport(
        'session.saveSkipped',
        detail: 'requested=${_sessionLabel(sessionId)}',
      );
      return;
    }
    final position = scrollController.position;
    if (_hasUsableViewport(position)) {
      _storeSessionViewport(sessionId, position.pixels, _autoScroll);
      _logViewport('session.saved', metrics: position);
    } else {
      _logViewport('session.saveInvalidViewport', metrics: position);
    }
  }

  void restoreSessionOffset(String sessionId) {
    final saved = _sessionOffsets[sessionId];
    if (sessionId != _lastScrollSessionId ||
        saved == null ||
        !scrollController.hasClients) {
      _logViewport(
        'session.restoreSkipped',
        detail:
            'requested=${_sessionLabel(sessionId)} hasSaved=${saved != null}',
      );
      return;
    }
    final target = saved.offset
        .clamp(
          scrollController.position.minScrollExtent,
          scrollController.position.maxScrollExtent,
        )
        .toDouble();
    _logViewport(
      'session.restoreRequested',
      metrics: scrollController.position,
      detail:
          'target=${target.toStringAsFixed(1)} '
          'savedFollow=${saved.autoScroll}',
    );
    _setAutoScroll(saved.autoScroll);
    jumpToPreservingFollow(target);
  }

  void pauseFollowingLatest() {
    _endUserScroll();
    _setAutoScroll(false);
  }

  void jumpToPreservingFollow(double offset) {
    if (!scrollController.hasClients) return;
    _endUserScroll();
    final target = offset
        .clamp(
          scrollController.position.minScrollExtent,
          scrollController.position.maxScrollExtent,
        )
        .toDouble();
    _programmaticScrollActive = true;
    try {
      scrollController.jumpTo(target);
      _rememberValidViewport(scrollController.position);
    } finally {
      _programmaticScrollActive = false;
    }
  }

  void followLatest() {
    _setAutoScroll(true);
    if (scrollController.hasClients) {
      final position = scrollController.position;
      if (position.hasPixels && position.hasContentDimensions) {
        jumpToPreservingFollow(position.minScrollExtent);
      }
    }
    scrollToBottom();
  }

  void scrollToBottom({bool force = false}) {
    if (force) {
      _logViewport('scrollToBottom.forceRequested');
      _setAutoScroll(true);
    }
    if (!_autoScroll || _scrollToBottomScheduled) return;
    _scrollToBottomScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomScheduled = false;
      if (!_autoScroll || !scrollController.hasClients) return;
      final position = scrollController.position;
      if (!position.hasPixels ||
          !position.hasContentDimensions ||
          position.viewportDimension <= 0) {
        return;
      }
      final target = position.minScrollExtent;
      if (!target.isFinite || (target - position.pixels).abs() < 0.5) return;
      _logViewport(
        'scrollToBottom.apply',
        metrics: position,
        detail: 'target=${target.toStringAsFixed(1)}',
      );
      _programmaticScrollActive = true;
      try {
        scrollController.jumpTo(target);
        _rememberValidViewport(scrollController.position);
      } finally {
        _programmaticScrollActive = false;
      }
    });
  }

  /// Keeps a historical message at the same screen position while the live
  /// edge changes size in a reversed transcript.
  void restorePausedViewportAnchor({
    required double visualDelta,
    required int expectedInteractionRevision,
  }) {
    if (_autoScroll ||
        _userScrollActive ||
        _potentialUserScroll ||
        expectedInteractionRevision != _viewportInteractionRevision ||
        !scrollController.hasClients ||
        visualDelta.abs() < 0.5) {
      return;
    }
    final position = scrollController.position;
    if (!_hasUsableViewport(position)) return;
    final target = (position.pixels - visualDelta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _logViewport(
      'anchor.restore',
      metrics: position,
      detail:
          'delta=${visualDelta.toStringAsFixed(1)} '
          'target=${target.toStringAsFixed(1)}',
    );
    jumpToPreservingFollow(target);
  }

  void _logViewport(String event, {ScrollMetrics? metrics, String? detail}) {
    final saved = _sessionOffsets[_lastScrollSessionId];
    final metricsText = metrics == null
        ? 'metrics=none'
        : 'pixels=${metrics.hasPixels ? metrics.pixels.toStringAsFixed(1) : 'na'} '
              'min=${metrics.hasContentDimensions ? metrics.minScrollExtent.toStringAsFixed(1) : 'na'} '
              'max=${metrics.hasContentDimensions ? metrics.maxScrollExtent.toStringAsFixed(1) : 'na'} '
              'viewport=${metrics.hasContentDimensions ? metrics.viewportDimension.toStringAsFixed(1) : 'na'} '
              'hasContent=${metrics.hasContentDimensions}';
    final savedText = saved == null
        ? 'saved=none'
        : 'savedOffset=${saved.offset.toStringAsFixed(1)} '
              'savedFollow=${saved.autoScroll}';
    AppLogger.d(
      '$event session=${_sessionLabel(_lastScrollSessionId)} '
          'follow=$_autoScroll needsRestore=$_needsViewportRestore '
          'clients=${scrollController.hasClients} $metricsText $savedText'
          '${detail == null ? '' : ' $detail'}',
      'AgentChatScroll',
    );
  }

  String _sessionLabel(String sessionId) {
    if (sessionId.isEmpty) return 'none';
    return sessionId.length <= 8 ? sessionId : sessionId.substring(0, 8);
  }

  @override
  void dispose() {
    hideInlineImagePreview();
    inputController.dispose();
    scrollController.dispose();
    inputFocus.dispose();
    super.dispose();
  }
}

class _AgentChatScrollController extends ScrollController {
  _AgentChatScrollController({
    required super.initialScrollOffset,
    required this.onAttachPosition,
    required this.onDetachPosition,
  }) : super(keepScrollOffset: false);

  final ValueChanged<ScrollPosition> onAttachPosition;
  final ValueChanged<ScrollPosition> onDetachPosition;

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    onAttachPosition(position);
  }

  @override
  void detach(ScrollPosition position) {
    onDetachPosition(position);
    super.detach(position);
  }
}
