import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/autocomplete/autocomplete_providers.dart';
import '../../../core/autocomplete/autocomplete_settings.dart';
import '../../../core/autocomplete/completion_models.dart';
import '../../../core/autocomplete/completion_orchestrator.dart';
import '../../../core/autocomplete/prompt_token_parser.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/generation/generation_settings_notifiers.dart'
    as generation_settings;
import '../../router/app_router.dart';
import 'autocomplete_config.dart';
import 'autocomplete_utils.dart';
import 'completion_overlay.dart';
import 'autocomplete_strategy.dart';
import 'legacy_autocomplete_wrapper.dart';

/// Unified local-first autocomplete shared by every tag and prompt field.
class AutocompleteWrapper extends ConsumerStatefulWidget {
  const AutocompleteWrapper({
    super.key,
    required this.child,
    required this.controller,
    this.strategy,
    this.asyncStrategy,
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
  @Deprecated('Use the unified autocomplete pipeline without a strategy.')
  final AutocompleteStrategy? strategy;
  @Deprecated('Use the unified autocomplete pipeline without a strategy.')
  final Future<AutocompleteStrategy>? asyncStrategy;
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

  bool get usesLegacyStrategy => strategy != null || asyncStrategy != null;

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
  final OverlayPortalController _overlayController = OverlayPortalController(
    debugLabel: 'autocomplete',
  );
  FocusNode? _ownedFocusNode;
  CompletionOrchestrator? _orchestrator;
  String? _selectedId;
  int _selectedIndex = -1;
  bool _applyingSuggestion = false;
  bool _cursorMetricsScheduled = false;
  Offset? _cursorOffset;
  double _caretLineHeight = 0;
  String? _pinnedRelatedTag;

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) _ownedFocusNode = FocusNode();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeUnified());
  }

  void _initializeUnified() {
    if (!mounted || widget.usesLegacyStrategy || _orchestrator != null) return;
    _orchestrator = ref.read(autocompleteServicesProvider).createOrchestrator()
      ..addListener(_onCompletionStateChanged);
    _updateCursorMetrics();
    if (_focusNode.hasFocus) _startQuery();
  }

  void _scheduleCursorMetricsUpdate() {
    if (_cursorMetricsScheduled || widget.usesLegacyStrategy) return;
    _cursorMetricsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cursorMetricsScheduled = false;
      _updateCursorMetrics();
    });
  }

  void _updateCursorMetrics() {
    if (!mounted || widget.usesLegacyStrategy) return;
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
    setState(() {
      _cursorOffset = nextOffset;
      _caretLineHeight = nextLineHeight;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleCursorMetricsUpdate();
  }

  @override
  void didUpdateWidget(covariant AutocompleteWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
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
    if (oldWidget.usesLegacyStrategy != widget.usesLegacyStrategy) {
      _disposeOrchestrator();
      _removeOverlay();
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeUnified());
    }
  }

  void _onTextChanged() {
    if (_applyingSuggestion || widget.usesLegacyStrategy) return;
    _scheduleCursorMetricsUpdate();
    widget.onChanged?.call(widget.controller.text);
    final composing = widget.controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) return;
    if (_focusNode.hasFocus) {
      _startQuery(
        related: _pinnedRelatedTag != null,
        relatedTagOverride: _pinnedRelatedTag,
      );
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      if (_pinnedRelatedTag == null) _removeOverlay();
    } else if (!widget.usesLegacyStrategy) {
      _scheduleCursorMetricsUpdate();
      _startQuery(
        related: _pinnedRelatedTag != null,
        relatedTagOverride: _pinnedRelatedTag,
      );
    }
  }

  void _startQuery({
    bool related = false,
    String? relatedTagOverride,
    bool resetPinnedRelatedTag = false,
  }) {
    if (!mounted || !widget.enabled || widget.usesLegacyStrategy) return;
    final settings = ref.read(autocompleteSettingsProvider);
    if (!ref.read(generation_settings.autocompleteSettingsProvider)) {
      _removeOverlay();
      return;
    }
    _maybePromptZhDictionary(settings);
    final config = widget.config;
    final selection = widget.controller.selection;
    final cursorPosition = selection.isValid
        ? selection.extentOffset
        : widget.controller.text.length;
    var query = related
        ? PromptTokenParser.parseRelated(
            text: widget.controller.text,
            cursorPosition: cursorPosition,
            limit: config?.maxSuggestions ?? settings.resultLimit,
            locale: Localizations.localeOf(context).toLanguageTag(),
            splitOnSpaces: config?.treatSpacesAsSeparators ?? false,
          )
        : PromptTokenParser.parse(
            text: widget.controller.text,
            cursorPosition: cursorPosition,
            limit: config?.maxSuggestions ?? settings.resultLimit,
            locale: Localizations.localeOf(context).toLanguageTag(),
            splitOnSpaces: config?.treatSpacesAsSeparators ?? false,
          );
    if (resetPinnedRelatedTag) _pinnedRelatedTag = null;
    if (query != null && relatedTagOverride != null) {
      query = query.copyWith(relatedTag: relatedTagOverride);
    }
    if (query == null) {
      _removeOverlay();
      return;
    }
    _orchestrator?.query(query, settings);
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
        state.query?.relatedTag != null;
    if (!hasVisibleState ||
        (!_focusNode.hasFocus && _pinnedRelatedTag == null)) {
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
    if (_overlayController.isShowing) {
      setState(() {});
    } else {
      _overlayController.show();
    }
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
    final horizontalAnchor = cursorOffset == null
        ? targetRect.left
        : targetRect.left + cursorOffset.dx;
    final verticalAnchor = cursorOffset == null
        ? targetRect.bottom
        : targetRect.top + cursorOffset.dy;
    final caretLineHeight = _caretLineHeight;
    final screen = theater.size;
    final below = screen.height - verticalAnchor - 8;
    final above = verticalAnchor - caretLineHeight - 8;
    final placeBelow = below >= 180 || below >= above;
    final availableHeight = placeBelow ? below : above;
    final maxHeight = availableHeight.clamp(132.0, 410.0);
    final maxWidth = screen.width - 16;
    final minWidth = maxWidth < 360 ? maxWidth : 360.0;
    final preferredWidth = targetRect.width < 680 ? 680.0 : targetRect.width;
    final width = preferredWidth.clamp(minWidth, maxWidth);
    final maxLeft = screen.width - width - 8;
    final left = horizontalAnchor.clamp(8.0, maxLeft);
    final settings = ref.read(autocompleteSettingsProvider);
    final dictionaryState = ref.read(zhDictionaryServiceProvider).state;

    return Positioned(
      left: left,
      top: placeBelow ? verticalAnchor + 4 : null,
      bottom: placeBelow
          ? null
          : screen.height - (verticalAnchor - caretLineHeight) + 4,
      width: width,
      child: TextFieldTapRegion(
        child: CompletionOverlay(
          state: _orchestrator!.state,
          selectedIndex: _selectedIndex,
          maxHeight: maxHeight,
          scrollController: _scrollController,
          settings: settings,
          dictionaryState: dictionaryState,
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
    if (widget.usesLegacyStrategy ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
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
    if (!_overlayController.isShowing) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) _closeOverlay();
      return KeyEventResult.handled;
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
    setState(() {});
    _ensureSelectionVisible();
  }

  void _ensureSelectionVisible() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    final itemTop = _selectedIndex * autocompleteCandidateExtent;
    final itemBottom = itemTop + autocompleteCandidateExtent;
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
    _scrollController.animateTo(
      boundedTarget,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
    );
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
    final settings = ref.read(autocompleteSettingsProvider);
    final applied = PromptTokenParser.apply(
      text: widget.controller.text,
      query: state.query!,
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
    _removeOverlay();
    final pinnedTag = _pinnedRelatedTag;
    if (settings.relatedTagsEnabled && pinnedTag != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          _startQuery(related: true, relatedTagOverride: pinnedTag);
        }
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _scheduleCursorMetricsUpdate();
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.hasFocus) {
        _startQuery(related: true, resetPinnedRelatedTag: true);
      }
    });
  }

  void _toggleRelatedPin() {
    final relatedTag = _orchestrator?.state.query?.relatedTag;
    if (relatedTag == null) return;
    setState(() {
      _pinnedRelatedTag = _pinnedRelatedTag == null ? relatedTag : null;
    });
  }

  void _closeOverlay() {
    _pinnedRelatedTag = null;
    _removeOverlay();
  }

  void _removeOverlay() {
    if (_overlayController.isShowing) _overlayController.hide();
  }

  void _openAutocompleteSettings() {
    _closeOverlay();
    _focusNode.unfocus();
    // Remove the portal child before GoRouter replaces this route. Reparenting
    // a visible portal in the same layout frame can leave Flutter's overlay
    // theater with a stale render-tree anchor.
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
    _ownedFocusNode?.dispose();
    _disposeOrchestrator();
    _removeOverlay();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.usesLegacyStrategy) {
      return LegacyAutocompleteWrapper(
        controller: widget.controller,
        strategy: widget.strategy,
        asyncStrategy: widget.asyncStrategy,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        onSuggestionSelected: widget.onSuggestionSelected,
        textStyle: widget.textStyle,
        contentPadding: widget.contentPadding,
        maxLines: widget.maxLines,
        expands: widget.expands,
        child: widget.child,
      );
    }
    ref.listen<AutocompleteSettings>(autocompleteSettingsProvider, (_, next) {
      if (!next.relatedTagsEnabled) _pinnedRelatedTag = null;
      if (_focusNode.hasFocus) {
        _startQuery(
          related: _pinnedRelatedTag != null,
          relatedTagOverride: _pinnedRelatedTag,
        );
      }
    });
    ref.listen(zhDictionaryServiceProvider, (_, __) {
      if (_overlayController.isShowing) setState(() {});
    });
    ref.listen<bool>(generation_settings.autocompleteSettingsProvider, (
      _,
      enabled,
    ) {
      if (enabled && _focusNode.hasFocus) {
        _startQuery(
          related: _pinnedRelatedTag != null,
          relatedTagOverride: _pinnedRelatedTag,
        );
      } else if (!enabled) {
        _removeOverlay();
      }
    });
    // The layout-builder portal owns a deferred layout surrogate. Route
    // replacement or hot reload can reparent that surrogate during layout and
    // trip Flutter's `node.depth > theater.depth` assertion. A regular portal
    // with a stable render anchor keeps the same root-overlay hit testing
    // without that fragile deferred-layout path.
    return OverlayPortal(
      controller: _overlayController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: _buildOverlay,
      child: SizedBox(
        key: _anchorKey,
        child: Focus(
          onKeyEvent: _onKeyEvent,
          child: Listener(onPointerUp: _onPointerUp, child: widget.child),
        ),
      ),
    );
  }
}
