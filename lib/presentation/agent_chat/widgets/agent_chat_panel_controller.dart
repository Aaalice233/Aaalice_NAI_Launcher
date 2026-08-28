import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/agent/agent_types.dart';
import '../../../../core/utils/nai_resolution_adapter.dart';
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

  static const double _scrollDeltaTolerance = 0.5;
  static const double _bottomTolerance = 2.0;

  late final AgentChatInputController inputController;
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocus = FocusNode();
  final List<PendingAgentChatImage> _pendingImages = [];
  final Map<ImageSource, Uint8List> messageImageBytes = {};
  final Map<ImageSource, Size> messageImageSizes = {};
  final Map<String, Uint8List> markdownDataImageBytes = {};

  OverlayEntry? _inlineImagePreview;
  BuildContext? _overlayContext;
  bool _autoScroll = true;
  bool _scrollToBottomScheduled = false;
  bool _adjustingScrollPosition = false;
  double? _lastObservedScrollPixels;
  double? _lastObservedMaxScrollExtent;
  int _lastScrollMessageCount = -1;
  String _lastScrollSessionId = '';
  String _lastStreamingText = '';
  List<AgentToolActivity>? _lastActivities;
  int? _hoveredUserMessageIndex;

  List<PendingAgentChatImage> get pendingImages =>
      List.unmodifiable(_pendingImages);
  int? get hoveredUserMessageIndex => _hoveredUserMessageIndex;

  void setHoveredUserMessageIndex(int? value) {
    if (_hoveredUserMessageIndex == value) return;
    _hoveredUserMessageIndex = value;
    notifyListeners();
  }

  void attachOverlayContext(BuildContext context) => _overlayContext = context;

  void observe(AgentChatState state) {
    final sessionChanged = state.activeSessionId != _lastScrollSessionId;
    final contentChanged =
        state.messages.length != _lastScrollMessageCount ||
        state.streamingText != _lastStreamingText ||
        !identical(state.activities, _lastActivities);
    _lastScrollSessionId = state.activeSessionId;
    _lastScrollMessageCount = state.messages.length;
    _lastStreamingText = state.streamingText;
    _lastActivities = state.activities;
    if (sessionChanged) {
      messageImageBytes.clear();
      messageImageSizes.clear();
      markdownDataImageBytes.clear();
      _lastObservedScrollPixels = null;
      _lastObservedMaxScrollExtent = null;
      scrollToBottom(force: true);
    } else if (contentChanged) {
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
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final pixels = position.pixels;
    final maxExtent = position.maxScrollExtent;
    final previousPixels = _lastObservedScrollPixels;
    final previousMaxExtent = _lastObservedMaxScrollExtent;
    _lastObservedScrollPixels = pixels;
    _lastObservedMaxScrollExtent = maxExtent;
    if (_adjustingScrollPosition ||
        previousPixels == null ||
        previousMaxExtent == null) {
      return;
    }
    final delta = pixels - previousPixels;
    final contentRangeChanged =
        (maxExtent - previousMaxExtent).abs() > _scrollDeltaTolerance;
    if (!contentRangeChanged && delta < -_scrollDeltaTolerance) {
      _autoScroll = false;
    } else if (position.extentAfter <= _bottomTolerance) {
      _autoScroll = true;
    }
  }

  void scrollToBottom({bool force = false}) {
    if (force) _autoScroll = true;
    if (!_autoScroll || _scrollToBottomScheduled) return;
    _scrollToBottomScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomScheduled = false;
      if (!_autoScroll || !scrollController.hasClients) return;
      final position = scrollController.position;
      if (!position.hasPixels || !position.hasContentDimensions) return;
      final target = position.maxScrollExtent;
      if (!target.isFinite || (target - position.pixels).abs() < 0.5) return;
      _adjustingScrollPosition = true;
      try {
        scrollController.jumpTo(target);
        _lastObservedScrollPixels = scrollController.position.pixels;
        _lastObservedMaxScrollExtent =
            scrollController.position.maxScrollExtent;
      } finally {
        _adjustingScrollPosition = false;
      }
    });
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
