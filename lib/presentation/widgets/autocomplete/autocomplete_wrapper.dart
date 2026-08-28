import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/autocomplete/autocomplete_providers.dart';
import '../../../core/autocomplete/autocomplete_settings.dart';
import '../../../core/autocomplete/cooccurrence_data_pack_provider.dart';
import '../../../core/autocomplete/completion_models.dart';
import '../../../core/autocomplete/completion_orchestrator.dart';
import '../../../core/autocomplete/prompt_token_parser.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../router/app_routes.dart';
import 'autocomplete_config.dart';
import 'autocomplete_utils.dart';
import 'completion_overlay.dart';

/// Unified local-first autocomplete shared by every tag and prompt field.
class AutocompleteWrapper extends ConsumerStatefulWidget {
  const AutocompleteWrapper({
    super.key,
    required this.child,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.onChanged,
    this.onSuggestionSelected,
    this.textStyle,
    this.contentPadding,
    this.maxLines,
    this.expands = false,
    this.config,
  });

  final Widget child;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// Receives the complete updated field value after a suggestion is applied.
  final ValueChanged<String>? onSuggestionSelected;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? contentPadding;
  final int? maxLines;
  final bool expands;
  final AutocompleteConfig? config;

  factory AutocompleteWrapper.localTag({
    Key? key,
    required Widget child,
    required TextEditingController controller,
    required WidgetRef ref,
    AutocompleteConfig config = const AutocompleteConfig(),
    FocusNode? focusNode,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSuggestionSelected,
    TextStyle? textStyle,
    EdgeInsetsGeometry? contentPadding,
    int? maxLines,
    bool expands = false,
  }) {
    return AutocompleteWrapper(
      key: key,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      onSuggestionSelected: onSuggestionSelected,
      textStyle: textStyle,
      contentPadding: contentPadding,
      maxLines: maxLines,
      expands: expands,
      config: config,
      child: child,
    );
  }

  factory AutocompleteWrapper.withAlias({
    Key? key,
    required Widget child,
    required TextEditingController controller,
    required WidgetRef ref,
    AutocompleteConfig config = const AutocompleteConfig(),
    FocusNode? focusNode,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSuggestionSelected,
    TextStyle? textStyle,
    EdgeInsetsGeometry? contentPadding,
    int? maxLines,
    bool expands = false,
  }) {
    return AutocompleteWrapper.localTag(
      key: key,
      controller: controller,
      ref: ref,
      config: config,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      onSuggestionSelected: onSuggestionSelected,
      textStyle: textStyle,
      contentPadding: contentPadding,
      maxLines: maxLines,
      expands: expands,
      child: child,
    );
  }

  @override
  ConsumerState<AutocompleteWrapper> createState() =>
      _AutocompleteWrapperState();
}

class _AutocompleteWrapperState extends ConsumerState<AutocompleteWrapper> {
  final GlobalKey _anchorKey = GlobalKey(debugLabel: 'autocomplete-anchor');
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _overlayEntry;
  FocusNode? _ownedFocusNode;
  CompletionOrchestrator? _orchestrator;
  String? _selectedId;
  int _selectedIndex = -1;
  bool _applyingSuggestion = false;
  bool _cursorMetricsScheduled = false;
  bool _wasComposing = false;
  bool _descendantHasFocus = false;
  TextEditingValue? _lastObservedValue;
  bool? _keepEmptyQueryVisible;
  final Set<int> _relatedClickPointers = <int>{};
  final Set<int> _regularClickPointers = <int>{};
  Offset? _cursorOffset;
  double _caretLineHeight = 0;
  String? _pinnedRelatedTag;

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode!;

  bool get _hasInputFocus => _focusNode.hasFocus || _descendantHasFocus;

  bool get _supportsNewlines => widget.expands || (widget.maxLines ?? 1) > 1;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) _ownedFocusNode = FocusNode();
    _lastObservedValue = widget.controller.value;
    final composing = widget.controller.value.composing;
    _wasComposing = composing.isValid && !composing.isCollapsed;
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeUnified());
  }

  void _initializeUnified() {
    if (!mounted || _orchestrator != null) return;
    _orchestrator = ref.read(autocompleteServicesProvider).createOrchestrator()
      ..addListener(_onCompletionStateChanged);
    _updateCursorMetrics();
  }

  void _scheduleCursorMetricsUpdate() {
    if (_cursorMetricsScheduled) return;
    _cursorMetricsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cursorMetricsScheduled = false;
      _updateCursorMetrics();
    });
  }

  void _updateCursorMetrics() {
    if (!mounted) return;
    final anchorContext = _anchorKey.currentContext;
    if (anchorContext == null) return;
    final isMultiline = AutocompleteUtils.isMultilineTextInput(
      context: anchorContext,
      maxLines: widget.maxLines,
      expands: widget.expands,
    );
    final nextOffset = isMultiline
        ? AutocompleteUtils.getCursorOffset(
            context: anchorContext,
            controller: widget.controller,
            textStyle: widget.textStyle,
            contentPadding: widget.contentPadding,
            maxLines: widget.maxLines,
            expands: widget.expands,
          )
        : null;
    final nextLineHeight = isMultiline
        ? AutocompleteUtils.getPreferredLineHeight(
            context: anchorContext,
            textStyle: widget.textStyle,
          )
        : 0.0;
    if (_cursorOffset == nextOffset && _caretLineHeight == nextLineHeight) {
      return;
    }
    _cursorOffset = nextOffset;
    _caretLineHeight = nextLineHeight;
    _overlayEntry?.markNeedsBuild();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleCursorMetricsUpdate();
  }

  @override
  void reassemble() {
    super.reassemble();
    _lastObservedValue = widget.controller.value;
    final composing = widget.controller.value.composing;
    _wasComposing = composing.isValid && !composing.isCollapsed;
  }

  @override
  void didUpdateWidget(covariant AutocompleteWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      _lastObservedValue = widget.controller.value;
      final composing = widget.controller.value.composing;
      _wasComposing = composing.isValid && !composing.isCollapsed;
      widget.controller.addListener(_onTextChanged);
    }
    _scheduleCursorMetricsUpdate();
    if (oldWidget.focusNode != widget.focusNode) {
      final oldFocus = oldWidget.focusNode ?? _ownedFocusNode;
      oldFocus?.removeListener(_onFocusChanged);
      if (oldWidget.focusNode == null) _ownedFocusNode?.dispose();
      _ownedFocusNode = widget.focusNode == null ? FocusNode() : null;
      _focusNode.addListener(_onFocusChanged);
    }
  }

  void _onTextChanged() {
    final value = widget.controller.value;
    final previousValue = _lastObservedValue;
    _lastObservedValue = value;
    if (previousValue == null) {
      _recoverAfterStateReload(value);
      return;
    }

    final text = value.text;
    final textChanged = text != previousValue.text;
    final activeTokenChanged =
        textChanged &&
        PromptTokenParser.editChangesActiveToken(
          previousText: previousValue.text,
          previousCursorPosition: _cursorPosition(previousValue),
          currentText: text,
          currentCursorPosition: _cursorPosition(value),
          splitOnSpaces: widget.config?.treatSpacesAsSeparators ?? false,
        );
    final composingRange = value.composing;
    final isComposing = composingRange.isValid && !composingRange.isCollapsed;
    final compositionCommitted = _wasComposing && !isComposing;
    _wasComposing = isComposing;

    if (_applyingSuggestion) return;
    _scheduleCursorMetricsUpdate();
    if (textChanged) widget.onChanged?.call(text);

    // NaiSyntaxController also notifies listeners when only its paint cache or
    // search highlighting changes. Ignore those identical value notifications;
    // only a real caret/selection move should dismiss an unpinned popup.
    if (!textChanged && !compositionCommitted) {
      final selectionChanged = value.selection != previousValue.selection;
      final composingChanged = value.composing != previousValue.composing;
      if (!selectionChanged && !composingChanged) return;
      // Click-opened and related popups own their pointer lifecycle: pointer-up
      // either opens the newly clicked tag or explicitly closes the popup, and
      // caret movement keys are handled below. Ignoring controller selection
      // synchronization here prevents the tap recognizer's delayed caret update
      // from closing the menu it just opened.
      if (_keepEmptyQueryVisible ?? false) return;
      if (_pinnedRelatedTag == null) _dismissOverlay('selection changed');
      return;
    }
    if (isComposing) {
      if (_pinnedRelatedTag == null) _dismissOverlay('composition started');
      return;
    }
    if (textChanged && !activeTokenChanged) {
      _closeOverlay();
      return;
    }
    if (_hasInputFocus) {
      _startQuery(
        related: _pinnedRelatedTag != null,
        relatedTagOverride: _pinnedRelatedTag,
      );
    }
  }

  void _recoverAfterStateReload(TextEditingValue value) {
    final composing = value.composing;
    _wasComposing = composing.isValid && !composing.isCollapsed;
    if (_applyingSuggestion || _wasComposing || !_hasInputFocus) {
      return;
    }
    widget.onChanged?.call(value.text);
    _startQuery(
      related: _pinnedRelatedTag != null,
      relatedTagOverride: _pinnedRelatedTag,
    );
  }

  int _cursorPosition(TextEditingValue value) => value.selection.isValid
      ? value.selection.extentOffset
      : value.text.length;

  void _onFocusChanged() => _handleEffectiveFocusChanged();

  void _onDescendantFocusChanged(bool hasFocus) {
    _descendantHasFocus = hasFocus;
    _handleEffectiveFocusChanged();
  }

  void _handleEffectiveFocusChanged() {
    if (!_hasInputFocus) {
      if (_pinnedRelatedTag == null) _dismissOverlay('focus lost');
      return;
    }
    _scheduleCursorMetricsUpdate();
  }

  void _startQuery({
    bool related = false,
    String? relatedTagOverride,
    bool resetPinnedRelatedTag = false,
    bool keepEmptyVisible = false,
  }) {
    if (!mounted || !widget.enabled) return;
    final settings = ref.read(autocompleteSettingsProvider);
    _maybePromptZhDictionary(settings);
    final config = widget.config;
    final selection = widget.controller.selection;
    final cursorPosition = selection.isValid
        ? selection.extentOffset
        : widget.controller.text.length;
    final fallbackQuery = PromptTokenParser.parse(
      text: widget.controller.text,
      cursorPosition: cursorPosition,
      limit: config?.maxSuggestions ?? settings.resultLimit,
      locale: Localizations.localeOf(context).toLanguageTag(),
      splitOnSpaces: config?.treatSpacesAsSeparators ?? false,
    );
    var query = related
        ? PromptTokenParser.parseRelated(
            text: widget.controller.text,
            cursorPosition: cursorPosition,
            limit: config?.maxSuggestions ?? settings.resultLimit,
            locale: Localizations.localeOf(context).toLanguageTag(),
            splitOnSpaces: config?.treatSpacesAsSeparators ?? false,
          )
        : fallbackQuery;
    if (resetPinnedRelatedTag) _pinnedRelatedTag = null;
    if (query != null && relatedTagOverride != null) {
      query = query.copyWith(relatedTag: relatedTagOverride);
    }
    if (query == null) {
      _dismissOverlay();
      return;
    }
    _keepEmptyQueryVisible = keepEmptyVisible || query.relatedTag != null;
    _orchestrator?.query(
      query,
      settings,
      relatedFallbackQuery: related && relatedTagOverride == null
          ? fallbackQuery
          : null,
    );
  }

  void _maybePromptZhDictionary(AutocompleteSettings settings) {
    if (!settings.showTranslations || settings.zhInstallPromptDismissed) return;
    if (!Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('zh')) {
      return;
    }
    final dictionary = ref.read(zhDictionaryServiceProvider);
    if (dictionary.state.isInstalled || dictionary.state.isBusy) return;
    ref.read(autocompleteSettingsProvider.notifier).dismissZhInstallPrompt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.autocomplete_zhInstallPrompt),
          action: SnackBarAction(
            label: context.l10n.autocomplete_install,
            onPressed: () => dictionary.installOrUpdate(),
          ),
        ),
      );
    });
  }

  void _onCompletionStateChanged() {
    if (!mounted) return;
    final state = _orchestrator!.state;
    final candidates = state.candidates;
    final hasVisibleState =
        candidates.isNotEmpty ||
        state.isLocalLoading ||
        state.isRemoteLoading ||
        state.localError?.isNotEmpty == true ||
        state.remoteError?.isNotEmpty == true ||
        state.translationError?.isNotEmpty == true ||
        state.query?.relatedTag != null ||
        ((_keepEmptyQueryVisible ?? false) && state.query != null);
    if (!hasVisibleState || (!_hasInputFocus && _pinnedRelatedTag == null)) {
      if (_overlayEntry != null) {
        AppLogger.d(
          'Removing popup from state: visible=$hasVisibleState '
              'related=${state.query?.relatedTag ?? ''} '
              'localLoading=${state.isLocalLoading} '
              'remoteLoading=${state.isRemoteLoading} '
              'focused=$_hasInputFocus',
          'Autocomplete',
        );
      }
      _removeOverlay();
      return;
    }
    if (candidates.isEmpty) {
      _selectedIndex = -1;
      _selectedId = null;
      _showOrUpdateOverlay();
      return;
    }
    final stableIndex = _selectedId == null
        ? -1
        : candidates.indexWhere((value) => value.stableId == _selectedId);
    if (stableIndex >= 0) {
      _selectedIndex = stableIndex;
    } else {
      _selectedIndex = candidates.indexWhere((value) => !value.isExisting);
      if (_selectedIndex < 0) _selectedIndex = 0;
      _selectedId = candidates[_selectedIndex].stableId;
    }
    _showOrUpdateOverlay();
  }

  void _showOrUpdateOverlay() {
    final currentEntry = _overlayEntry;
    if (currentEntry != null) {
      currentEntry.markNeedsBuild();
      return;
    }
    final entry = OverlayEntry(builder: _buildOverlay);
    _overlayEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final anchor = _anchorKey.currentContext?.findRenderObject();
    final rootOverlay = Overlay.of(context, rootOverlay: true);
    final theater = rootOverlay.context.findRenderObject();
    if (anchor is! RenderBox ||
        theater is! RenderBox ||
        !anchor.attached ||
        !theater.attached ||
        !anchor.hasSize ||
        !theater.hasSize) {
      return const SizedBox.shrink();
    }
    final targetRect =
        anchor.localToGlobal(Offset.zero, ancestor: theater) & anchor.size;
    final cursorOffset = _cursorOffset;
    final caretLeft = cursorOffset == null
        ? targetRect.left
        : targetRect.left + cursorOffset.dx;
    final caretBottom = cursorOffset == null
        ? targetRect.bottom
        : targetRect.top + cursorOffset.dy;
    final caretTop = cursorOffset == null
        ? targetRect.top
        : caretBottom - _caretLineHeight;
    final screen = theater.size;
    const viewportInset = 8.0;
    const caretGap = 8.0;
    final touchCompact =
        PlatformCapabilities.current.hasTouchInput && screen.width < 600;
    final flutterView = View.of(overlayContext);
    final rawKeyboardInset =
        flutterView.viewInsets.bottom / flutterView.devicePixelRatio;
    final keyboardInset = math
        .max(MediaQuery.viewInsetsOf(overlayContext).bottom, rawKeyboardInset)
        .clamp(0.0, screen.height);
    final visibleBottom = screen.height - keyboardInset;
    final below = math.max(
      visibleBottom - viewportInset - caretBottom - caretGap,
      0.0,
    );
    final above = math.max(caretTop - caretGap - viewportInset, 0.0);
    final placeBelow = below >= 180 || below >= above;
    final availableHeight = placeBelow ? below : above;
    final minimumUsableHeight = touchCompact ? 152.0 : 90.0;
    if (availableHeight < minimumUsableHeight) {
      return const SizedBox.shrink();
    }
    final maxHeight = math.min(availableHeight, touchCompact ? 320.0 : 410.0);

    // Phone completion is a stable edge-aligned panel. Roomy viewports retain
    // the editor-style footprint and keep some leading text visible.
    final availableWidth = math.max(screen.width - viewportInset * 2, 0.0);
    final responsiveWidth = touchCompact
        ? availableWidth
        : math.max(360.0, availableWidth * 0.62);
    final width = math.min(672.0, math.min(availableWidth, responsiveWidth));
    final leadingContext = math.min(width * 0.12, 72.0);
    final maxLeft = screen.width - viewportInset - width;
    final left = touchCompact
        ? viewportInset
        : (caretLeft - leadingContext).clamp(viewportInset, maxLeft);
    final settings = ref.read(autocompleteSettingsProvider);
    final dictionaryState = ref.read(zhDictionaryServiceProvider).state;
    final cooccurrenceDataPackState = ref.read(
      cooccurrenceDataPackServiceProvider,
    );

    return Positioned(
      left: left,
      top: placeBelow ? caretBottom + caretGap : null,
      bottom: placeBelow ? null : screen.height - caretTop + caretGap,
      width: width,
      child: TextFieldTapRegion(
        child: CompletionOverlay(
          state: _orchestrator!.state,
          selectedIndex: _selectedIndex,
          maxHeight: maxHeight,
          scrollController: _scrollController,
          settings: settings,
          dictionaryState: dictionaryState,
          cooccurrenceDataPackState: cooccurrenceDataPackState,
          showAliases:
              settings.showAliases && (widget.config?.showTranslation ?? true),
          showTranslations:
              settings.showTranslations &&
              (widget.config?.showTranslation ?? true),
          showCategory: widget.config?.showCategory ?? true,
          showCount: widget.config?.showCount ?? true,
          onSelected: _selectIndex,
          onClose: _closeOverlay,
          onOpenSettings: _openAutocompleteSettings,
          isRelatedPinned: _pinnedRelatedTag != null,
          onToggleRelatedPin: _orchestrator!.state.query?.relatedTag == null
              ? null
              : _toggleRelatedPin,
        ),
      ),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final relatedShortcut =
        event.logicalKey == LogicalKeyboardKey.space &&
        keyboard.isShiftPressed &&
        (keyboard.isControlPressed || keyboard.isMetaPressed);
    if (relatedShortcut) {
      _startQuery(related: true, resetPinnedRelatedTag: true);
      return KeyEventResult.handled;
    }
    if (_overlayEntry == null) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        keyboard.isShiftPressed &&
        _supportsNewlines) {
      if (event is KeyDownEvent) _closeOverlay();
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) _closeOverlay();
      return KeyEventResult.handled;
    }
    final movesTextCaret =
        event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.home ||
        event.logicalKey == LogicalKeyboardKey.end;
    if (movesTextCaret) {
      if (event is KeyDownEvent) _dismissOverlay('keyboard caret move');
      return KeyEventResult.ignored;
    }
    final candidates = _orchestrator?.state.candidates ?? const [];
    if (candidates.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1, candidates);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1, candidates);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      if (event is KeyDownEvent) {
        _selectIndex(_selectedIndex);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  void _moveSelection(int delta, List<CompletionCandidate> candidates) {
    _selectedIndex = (_selectedIndex + delta) % candidates.length;
    if (_selectedIndex < 0) _selectedIndex += candidates.length;
    _selectedId = candidates[_selectedIndex].stableId;
    _overlayEntry?.markNeedsBuild();
    _ensureSelectionVisible();
  }

  void _ensureSelectionVisible() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    final itemExtent = effectiveAutocompleteCandidateExtent;
    final itemTop = _selectedIndex * itemExtent;
    final itemBottom = itemTop + itemExtent;
    final viewportTop = position.pixels;
    final viewportBottom = viewportTop + position.viewportDimension;
    double? target;

    if (itemTop < viewportTop) {
      target = itemTop;
    } else if (itemBottom > viewportBottom) {
      target = itemBottom - position.viewportDimension;
    }
    if (target == null) return;

    final boundedTarget = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((boundedTarget - position.pixels).abs() < 0.5) return;
    // Keyboard repeat is a high-frequency interaction. Match the reference
    // plugin's immediate edge scroll instead of starting overlapping animations
    // that make the list appear to bounce between rows.
    _scrollController.jumpTo(boundedTarget);
  }

  void _selectIndex(int index) {
    final state = _orchestrator?.state;
    if (state?.query == null ||
        index < 0 ||
        index >= state!.candidates.length) {
      return;
    }
    final candidate = state.candidates[index];
    if (candidate.isExisting) return;
    final query = state.query!;
    final settings = ref.read(autocompleteSettingsProvider);
    final completedTag = query.kind == CompletionQueryKind.tag
        ? candidate.canonicalTag
        : null;
    final applied = PromptTokenParser.apply(
      text: widget.controller.text,
      query: query,
      canonicalTag: candidate.canonicalTag,
      autoInsertComma:
          settings.autoInsertComma && (widget.config?.autoInsertComma ?? true),
      replaceUnderscores:
          settings.replaceUnderscores ||
          (widget.config?.replaceUnderscoreWithSpace ?? false),
    );
    _applyingSuggestion = true;
    widget.controller.value = TextEditingValue(
      text: applied.text,
      selection: TextSelection.collapsed(offset: applied.cursorPosition),
    );
    _applyingSuggestion = false;
    _scheduleCursorMetricsUpdate();
    widget.onChanged?.call(applied.text);
    widget.onSuggestionSelected?.call(applied.text);
    _selectedId = null;
    _dismissOverlay();
    final nextRelatedTag = _pinnedRelatedTag ?? completedTag;
    if (settings.relatedTagsEnabled && nextRelatedTag != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasInputFocus) {
          _startQuery(related: true, relatedTagOverride: nextRelatedTag);
        }
      });
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final isPrimaryClick = event.buttons == kPrimaryButton;
    final requestsRelated = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (isPrimaryClick && requestsRelated) {
      _relatedClickPointers.add(event.pointer);
      _regularClickPointers.remove(event.pointer);
    } else if (isPrimaryClick) {
      _regularClickPointers.add(event.pointer);
      _relatedClickPointers.remove(event.pointer);
    } else {
      _relatedClickPointers.remove(event.pointer);
      _regularClickPointers.remove(event.pointer);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _scheduleCursorMetricsUpdate();
    final keyboard = HardwareKeyboard.instance;
    final startedAsRelated = _relatedClickPointers.remove(event.pointer);
    final startedAsRegular = _regularClickPointers.remove(event.pointer);
    final isPrimaryClick = startedAsRelated || startedAsRegular;
    final requestsRelated =
        isPrimaryClick &&
        (startedAsRelated ||
            keyboard.isControlPressed ||
            keyboard.isMetaPressed);
    if (requestsRelated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasInputFocus) {
          _startQuery(
            related: true,
            resetPinnedRelatedTag: true,
            keepEmptyVisible: true,
          );
        }
      });
      return;
    }

    final settings = ref.read(autocompleteSettingsProvider);
    final selection = widget.controller.selection;
    if (!startedAsRegular ||
        !settings.openOnTagClick ||
        !selection.isValid ||
        !selection.isCollapsed) {
      if (_pinnedRelatedTag == null) {
        _dismissOverlay('pointer interaction without an open intent');
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hasInputFocus) {
        _startQuery(resetPinnedRelatedTag: true, keepEmptyVisible: true);
      }
    });
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _relatedClickPointers.remove(event.pointer);
    _regularClickPointers.remove(event.pointer);
  }

  void _toggleRelatedPin() {
    final relatedTag = _orchestrator?.state.query?.relatedTag;
    if (relatedTag == null) return;
    _pinnedRelatedTag = _pinnedRelatedTag == null ? relatedTag : null;
    _overlayEntry?.markNeedsBuild();
  }

  void _closeOverlay() {
    _pinnedRelatedTag = null;
    _dismissOverlay('explicit close');
  }

  void _dismissOverlay([String reason = 'query replaced']) {
    _keepEmptyQueryVisible = false;
    final state = _orchestrator?.state;
    if (_overlayEntry != null || state?.query != null) {
      AppLogger.d(
        'Closing popup: reason=$reason '
            'query=${state?.query?.token ?? ''} '
            'related=${state?.query?.relatedTag ?? ''} '
            'localLoading=${state?.isLocalLoading ?? false} '
            'remoteLoading=${state?.isRemoteLoading ?? false} '
            'focused=$_hasInputFocus',
        'Autocomplete',
      );
    }
    _orchestrator?.cancel();
    _removeOverlay();
  }

  void _removeOverlay() {
    final entry = _overlayEntry;
    if (entry == null) return;
    _overlayEntry = null;
    entry.remove();
    entry.dispose();
  }

  void _openAutocompleteSettings() {
    _closeOverlay();
    _focusNode.unfocus();
    // Let the root overlay entry detach before GoRouter replaces its anchor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('${AppRoutes.settings}?section=storage');
    });
  }

  void _disposeOrchestrator() {
    _orchestrator?.removeListener(_onCompletionStateChanged);
    _orchestrator?.dispose();
    _orchestrator = null;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    _ownedFocusNode?.dispose();
    _disposeOrchestrator();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AutocompleteSettings>(autocompleteSettingsProvider, (_, next) {
      if (!next.enabled) {
        _dismissOverlay('autocomplete disabled');
        return;
      }
      if (!next.relatedTagsEnabled) _pinnedRelatedTag = null;
      final activeRelatedTag = _orchestrator?.state.query?.relatedTag;
      final relatedTag = _pinnedRelatedTag ?? activeRelatedTag;
      if (_hasInputFocus && (_overlayEntry != null || relatedTag != null)) {
        _startQuery(
          related: relatedTag != null,
          relatedTagOverride: relatedTag,
          keepEmptyVisible: _keepEmptyQueryVisible ?? false,
        );
      }
    });
    ref.listen(zhDictionaryServiceProvider, (_, __) {
      _overlayEntry?.markNeedsBuild();
    });
    return SizedBox(
      key: _anchorKey,
      child: Focus(
        onFocusChange: _onDescendantFocusChanged,
        onKeyEvent: _onKeyEvent,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: widget.child,
        ),
      ),
    );
  }
}
