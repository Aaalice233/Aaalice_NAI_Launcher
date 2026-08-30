import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, KeyUpEvent, LogicalKeyboardKey;

import '../../../core/agent/agent_types.dart';
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

/// Owns all ephemeral panel resources so the widget shell only coordinates
/// provider state and immutable view data.
class AgentChatPanelController extends ChangeNotifier {
  AgentChatPanelController() {
    inputController = AgentChatInputController(
      onImageEnter: showInlineImagePreview,
      onImageExit: hideInlineImagePreview,
    );
    scrollController.addListener(_handleScrollPositionChanged);
  }

  static const double _atBottomTolerance = 2.0;
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
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocus = FocusNode();
  final List<PendingAgentChatImage> _pendingImages = [];
  final Map<ImageSource, Uint8List> messageImageBytes = {};
  final Map<ImageSource, Size> messageImageSizes = {};
  final Map<String, Uint8List> markdownDataImageBytes = {};
  final Map<String, ({double offset, bool autoScroll})> _sessionOffsets = {};

  OverlayEntry? _inlineImagePreview;
  BuildContext? _overlayContext;
  bool _autoScroll = true;
  bool _userScrollActive = false;
  bool _potentialUserScroll = false;
  bool _programmaticScrollActive = false;
  double? _lastUserScrollPixels;
  bool _scrollToBottomScheduled = false;
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
      scrollToBottom(force: true);
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
            color: Theme.of(overlayContext).colorScheme.surface,
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

  void _handleScrollPositionChanged() {
    if (!scrollController.hasClients || _programmaticScrollActive) return;
    final position = scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    if (_isAtBottom(position) && !_autoScroll) {
      _setAutoScroll(true);
    }
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
      _setAutoScroll(false);
    } else if (_isNearBottom(metrics)) {
      _setAutoScroll(true);
    }
  }

  bool _isAtBottom(ScrollMetrics metrics) =>
      metrics.pixels <= metrics.minScrollExtent + _atBottomTolerance;

  bool _isNearBottom(ScrollMetrics metrics) =>
      metrics.pixels <= metrics.minScrollExtent + _nearBottomTolerance;

  void _setAutoScroll(bool value) {
    if (_autoScroll == value) return;
    _autoScroll = value;
    notifyListeners();
  }

  void saveSessionOffset(String sessionId) {
    if (sessionId.isEmpty ||
        sessionId != _lastScrollSessionId ||
        !scrollController.hasClients) {
      return;
    }
    _sessionOffsets.remove(sessionId);
    _sessionOffsets[sessionId] = (
      offset: scrollController.offset,
      autoScroll: _autoScroll,
    );
    while (_sessionOffsets.length > _retainedSessionOffsetCount) {
      _sessionOffsets.remove(_sessionOffsets.keys.first);
    }
  }

  void restoreSessionOffset(String sessionId) {
    final saved = _sessionOffsets[sessionId];
    if (sessionId != _lastScrollSessionId ||
        saved == null ||
        !scrollController.hasClients) {
      return;
    }
    final target = saved.offset
        .clamp(
          scrollController.position.minScrollExtent,
          scrollController.position.maxScrollExtent,
        )
        .toDouble();
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
    if (force) _setAutoScroll(true);
    if (!_autoScroll || _scrollToBottomScheduled) return;
    _scrollToBottomScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomScheduled = false;
      if (!_autoScroll || !scrollController.hasClients) return;
      final position = scrollController.position;
      if (!position.hasPixels || !position.hasContentDimensions) return;
      final target = position.minScrollExtent;
      if (!target.isFinite || (target - position.pixels).abs() < 0.5) return;
      _programmaticScrollActive = true;
      try {
        scrollController.jumpTo(target);
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
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final target = (position.pixels - visualDelta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    jumpToPreservingFollow(target);
  }

  @override
  void dispose() {
    hideInlineImagePreview();
    inputController.dispose();
    scrollController.removeListener(_handleScrollPositionChanged);
    scrollController.dispose();
    inputFocus.dispose();
    super.dispose();
  }
}
