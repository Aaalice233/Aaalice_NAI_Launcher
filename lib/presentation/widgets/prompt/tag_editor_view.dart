import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/autocomplete/autocomplete_providers.dart';
import '../../../core/autocomplete/tag_translation_lookup.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/prompt_edit_document.dart';
import '../../adaptive/interaction_policy.dart';
import '../../themes/core/layered_surface_style.dart';
import '../../themes/core/input_surface_style.dart';
import '../../router/app_routes.dart';
import '../autocomplete/autocomplete_wrapper.dart';
import '../autocomplete/autocomplete_overlay_handle.dart';
import '../common/app_toast.dart';
import 'components/batch_selection/selection_overlay.dart';
import 'prompt_action_overlay.dart';
import 'prompt_translation_controller.dart';
import 'prompt_weight_controls.dart';
import 'tag_editor_tree.dart';
import 'tag_editor_commands.dart';
import 'tag_editor_session.dart';

class TagEditorView extends ConsumerStatefulWidget {
  static const scrollViewKey = ValueKey('tag-editor-scroll-view');

  static bool claimsWeightWheel(BuildContext context, Offset globalPosition) =>
      context
          .findAncestorStateOfType<_TagEditorViewState>()
          ?._claimsWeightWheel(globalPosition) ??
      false;

  const TagEditorView({
    super.key,
    required this.session,
    this.surfaceColor,
    this.bottomPadding = 58,
    this.enabled = true,
    this.enableAutocomplete = true,
    this.onSearch,
    this.focusNode,
  });
  final TagEditorSession session;
  final Color? surfaceColor;
  final double bottomPadding;
  final bool enabled;
  final bool enableAutocomplete;
  final ValueChanged<bool>? onSearch;
  final FocusNode? focusNode;
  @override
  ConsumerState<TagEditorView> createState() => _TagEditorViewState();
}

class _TagEditorViewState extends ConsumerState<TagEditorView> {
  late FocusNode _focus;
  final FocusNode _addFocus = FocusNode();
  final TextEditingController _add = TextEditingController();
  final GlobalKey _surfaceKey = GlobalKey();
  final GlobalKey _boxKey = GlobalKey();
  final Map<int, GlobalKey> _keys = {};
  final OverlayPortalController _overlay = OverlayPortalController();
  final _toolbarRevision = ValueNotifier<int>(0);
  bool _toolbarRefreshPending = false;
  final AutocompleteOverlayHandle _autocomplete = AutocompleteOverlayHandle();
  late final ScrollController _scroll;
  PromptTranslationController? _translations;
  TagTranslationLookup? _lookup;
  bool _chinese = false;
  bool _dictionaryNotified = false;
  bool _composing = false;
  bool _rebuildPending = false;
  bool _boxSelecting = false;
  bool _draggingTags = false;
  bool _adding = false;
  bool _menuOpen = false;
  int? _insertOffset;
  TextRange? _pendingAddRange;
  bool _writingAddition = false;
  bool _clearingAddition = false;
  TextEditingValue _lastAddition = TextEditingValue.empty;
  String _lastSourceText = '';
  TextSelection _lastSourceSelection = const TextSelection.collapsed(
    offset: -1,
  );
  Set<int> _boxBase = {};
  TagEditorSession get session => widget.session;
  TagEditorCommands get commands => TagEditorCommands(session);

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _autocomplete.addListener(_refresh);
    session.addListener(_sessionChanged);
    _lastSourceText = session.controller.text;
    _add.addListener(_additionChanged);
    _addFocus.addListener(_additionFocusChanged);
    _scroll = ScrollController(initialScrollOffset: session.scrollOffset)
      ..addListener(_scrolled);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(TagEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
    }
    if (oldWidget.session != session) {
      oldWidget.session.removeListener(_sessionChanged);
      session.addListener(_sessionChanged);
    }
  }

  void _scrolled() {
    session.scrollOffset = _scroll.offset;
    if (!_overlay.isShowing || _toolbarRefreshPending) return;
    _toolbarRefreshPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toolbarRefreshPending = false;
      if (mounted) _toolbarRevision.value++;
    });
  }

  void _refresh() {
    if (!mounted || _rebuildPending) return;
    _rebuildPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildPending = false;
      if (!mounted) return;
      setState(() {});
      final show =
          session.selected.isNotEmpty &&
          session.editing == null &&
          !_boxSelecting &&
          !_draggingTags &&
          !_menuOpen;
      if (show && !_overlay.isShowing) _overlay.show();
      if (!show && _overlay.isShowing) _overlay.hide();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _sessionChanged() {
    final source = session.controller.text;
    if (!_writingAddition &&
        source != _lastSourceText &&
        _pendingAddRange != null) {
      _pendingAddRange = null;
      _insertOffset = null;
      _clearAddition();
    }
    if (source != _lastSourceText) {
      _keys.removeWhere((id, _) => session.nodeById(id) == null);
      _syncTranslations();
    }
    _lastSourceText = source;
    _refresh();
    final selection = session.controller.selection;
    if (selection != _lastSourceSelection &&
        selection.isValid &&
        !selection.isCollapsed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _keys[session.selected.firstOrNull]?.currentContext;
        if (target != null) Scrollable.ensureVisible(target, alignment: 0.3);
      });
    }
    _lastSourceSelection = selection;
  }

  void _syncTranslations({bool immediate = false}) => _translations?.update(
    _chinese ? session.leaves.map((tag) => tag.span.label) : const [],
    composing: _composing,
    immediate: immediate,
  );

  Future<void> _checkDictionary() async {
    if (!_chinese || _dictionaryNotified) return;
    _dictionaryNotified = true;
    final dictionary = ref.read(zhDictionaryServiceProvider);
    try {
      await dictionary.initialize();
      if (!mounted || dictionary.state.isInstalled) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.tagMode_dictionaryMissing),
          action: SnackBarAction(
            label: context.l10n.tagMode_dictionaryAction,
            onPressed: () => context.go(AppRoutes.storageSettings),
          ),
        ),
      );
    } catch (error, stack) {
      AppLogger.e('Tag editor dictionary initialization failed', error, stack);
      if (mounted) {
        AppToast.error(context, context.l10n.tagMode_translationFailed);
      }
    }
  }

  void _translated() {
    _refresh();
    if (_translations?.values.values.any(
          (value) => value.status == PromptTranslationStatus.missing,
        ) ??
        false) {
      unawaited(_checkDictionary());
    }
  }

  @override
  void dispose() {
    session.removeListener(_sessionChanged);
    _autocomplete.removeListener(_refresh);
    _addFocus.removeListener(_additionFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _autocomplete.dispose(),
    );
    _translations?.dispose();
    _scroll.dispose();
    _toolbarRevision.dispose();
    if (widget.focusNode == null) _focus.dispose();
    _addFocus.dispose();
    _add.dispose();
    super.dispose();
  }

  void _select(PromptEditorTag tag) {
    if (!widget.enabled) return;
    if (tag.children.isNotEmpty) {
      _focus.requestFocus();
      session.selectGroup(tag);
      return;
    }
    final keyboard = HardwareKeyboard.instance;
    if (session.selected.length == 1 &&
        session.selected.contains(tag.id) &&
        !session.touchSelection &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isShiftPressed) {
      session.edit(tag.id);
    } else {
      _focus.requestFocus();
      session.select(
        tag.id,
        additive: keyboard.isControlPressed || keyboard.isMetaPressed,
        range: keyboard.isShiftPressed,
      );
    }
  }

  void _dismissTouchSelection() {
    if (!_menuOpen && session.editing == null && !_draggingTags) {
      session.clearSelection();
    }
  }

  void _edit(PromptEditorTag tag, TextEditingValue value) {
    final previousText = session.controller.text;
    _composing = value.composing.isValid && !value.composing.isCollapsed;
    session.replaceLabel(tag.id, value.text, composing: _composing);
    if (previousText == session.controller.text) _syncTranslations();
    if (_composing) return;
    final parsed = PromptEditDocument.parse(value.text);
    if (parsed.length > 1 ||
        (value.text.endsWith(',') && parsed.every((span) => span.complete))) {
      session.endEdit();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (value.text.endsWith(',')) {
          _insertOffset = session.controller.selection.extentOffset;
          _openAddition();
        } else {
          final cursor = session.controller.selection.extentOffset;
          final matches = session.leaves.where(
            (item) => item.span.end == cursor,
          );
          if (matches.isNotEmpty) session.edit(matches.last.id);
        }
      });
    }
  }

  void _additionFocusChanged() {
    if (!_addFocus.hasFocus && _add.text.isEmpty) _adding = false;
    _refresh();
  }

  void _openAddition({bool atEnd = false}) {
    if (atEnd) _insertOffset = null;
    session.clearSelection();
    setState(() => _adding = true);
    _addFocus.requestFocus();
  }

  void _submitAdd() {
    if (!_add.value.composing.isCollapsed) return;
    if (_add.text.isEmpty) {
      _addFocus.unfocus();
      _focus.requestFocus();
      return;
    }
    _startAddedTag(_add.text);
    session.endEdit();
    _openAddition();
  }

  void _clearAddition() {
    _clearingAddition = true;
    _add.clear();
    _lastAddition = _add.value;
    _clearingAddition = false;
  }

  void _additionChanged() {
    final value = _add.value;
    if (_clearingAddition ||
        (value.text == _lastAddition.text &&
            value.composing == _lastAddition.composing)) {
      return;
    }
    _lastAddition = value;
    _startAddedTag(value.text);
  }

  void _startAddedTag(String text) {
    final composing =
        _add.value.composing.isValid && !_add.value.composing.isCollapsed;
    _composing = composing;
    final range = _pendingAddRange;
    if (range == null && text.isEmpty) return;
    _writingAddition = true;
    try {
      if (range == null) {
        session.insert(text, at: _insertOffset);
        final end = session.controller.selection.extentOffset;
        _pendingAddRange = TextRange(start: end - text.length, end: end);
      } else {
        session.apply([
          PromptTextPatch(range.start, range.end, text),
        ], typing: true);
        _pendingAddRange = TextRange(
          start: range.start,
          end: range.start + text.length,
        );
      }
    } finally {
      _writingAddition = false;
    }
    _syncTranslations();
    if (composing) {
      _refresh();
      return;
    }
    final cursor = _pendingAddRange!.end;
    _pendingAddRange = null;
    _insertOffset = text.endsWith(',') ? cursor : null;
    _clearAddition();
    if (text.endsWith(',')) return;
    final added = session.leaves
        .where((tag) => tag.span.end == cursor)
        .lastOrNull;
    if (added != null) session.edit(added.id, selectText: false);
  }

  bool get _wheelAdjustmentEnabled =>
      widget.enabled && commands.canAdjust && session.editing == null;

  bool _claimsWeightWheel(Offset globalPosition) {
    if (!_wheelAdjustmentEnabled) return false;
    final surface = _surfaceKey.currentContext?.findRenderObject();
    if (surface is! RenderBox) return false;
    final local = surface.globalToLocal(globalPosition);
    final group = session.selectedGroup;
    if (group != null &&
        (_tagRect(group.id, surface)?.contains(local) ?? false)) {
      return true;
    }
    return session.selected.any(
      (id) => _tagRect(id, surface)?.contains(local) ?? false,
    );
  }

  void _wheel(PointerSignalEvent event, {int? tagId}) {
    if (!_wheelAdjustmentEnabled ||
        event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        (tagId != null && !session.selected.contains(tagId))) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      commands.adjustWeight(step: scroll.scrollDelta.dy < 0 ? 0.05 : -0.05);
      scroll.respond(allowPlatformDefault: false);
    });
  }

  Future<void> _action(TagEditorAction action) async {
    if (!widget.enabled || !commands.available(action)) return;
    switch (action) {
      case TagEditorAction.weight:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.tagMode_weight),
            content: ListenableBuilder(
              listenable: session,
              builder: (context, _) => PromptWeightControls(
                onClose: session.clearSelection,
                weight: commands.weight,
                enabled: widget.enabled && commands.canAdjust,
                onWeight: (value) => commands.adjustWeight(value: value),
                onStep: (step) => commands.adjustWeight(step: step),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.common_close),
              ),
            ],
          ),
        );
      case TagEditorAction.edit:
        session.edit(session.selected.single);
      case TagEditorAction.enable:
        session.toggleEnabled(session.selected, enabled: true);
      case TagEditorAction.disable:
        session.toggleEnabled(session.selected, enabled: false);
      case TagEditorAction.copy ||
          TagEditorAction.copyEffective ||
          TagEditorAction.cut:
        final before = session.controller.text;
        final ids = Set<int>.of(session.selected);
        await Clipboard.setData(
          ClipboardData(
            text: session.copySelection(
              effective: action == TagEditorAction.copyEffective,
            ),
          ),
        );
        if (!mounted) return;
        if (action == TagEditorAction.cut &&
            session.controller.text == before &&
            session.selected.containsAll(ids) &&
            session.selected.length == ids.length) {
          session.deleteSelected();
        }
      case TagEditorAction.paste:
        final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
        if (mounted && clipboard?.text != null) {
          session.insert(clipboard!.text!);
        }
      case TagEditorAction.delete:
        session.deleteSelected();
      case TagEditorAction.selectAll:
        session.selectAll();
      case TagEditorAction.undo:
        session.undo();
      case TagEditorAction.redo:
        session.redo();
      case TagEditorAction.previous ||
          TagEditorAction.next ||
          TagEditorAction.first ||
          TagEditorAction.last:
        commands.move(action);
    }
  }

  Future<void> _menu(Offset globalPosition, {PromptEditorTag? tag}) async {
    if (!widget.enabled) return;
    if (tag != null && !session.selected.contains(tag.id)) {
      session.touchSelection = false;
      session.select(tag.id);
    }
    session.endEdit();
    _menuOpen = true;
    _refresh();
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = overlay.globalToLocal(globalPosition);
    try {
      final result = await showMenu<TagEditorAction>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromLTWH(position.dx, position.dy, 1, 1),
          Offset.zero & overlay.size,
        ),
        items: [
          for (final action in TagEditorAction.values)
            PopupMenuItem(
              value: action,
              enabled: commands.available(action),
              child: Builder(
                builder: (context) => Row(
                  children: [
                    Icon(
                      tagEditorActionIcon(action),
                      size: 18,
                      color: DefaultTextStyle.of(context).style.color,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(tagEditorActionLabel(action, context.l10n)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
      if (mounted && result != null) await _action(result);
    } finally {
      if (mounted) {
        _menuOpen = false;
        _refresh();
      }
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !widget.enabled) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final modifier = keyboard.isControlPressed || keyboard.isMetaPressed;
    final key = event.logicalKey;
    if (modifier &&
        (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.keyH)) {
      if (widget.onSearch != null) session.endEdit();
      widget.onSearch?.call(key == LogicalKeyboardKey.keyH);
      return widget.onSearch == null
          ? KeyEventResult.ignored
          : KeyEventResult.handled;
    }
    if (modifier && key == LogicalKeyboardKey.keyZ) {
      keyboard.isShiftPressed ? session.redo() : session.undo();
      return KeyEventResult.handled;
    }
    if (modifier && key == LogicalKeyboardKey.keyY) {
      session.redo();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_addFocus.hasFocus) {
        _addFocus.unfocus();
        _focus.requestFocus();
        return KeyEventResult.handled;
      }
      if (session.editing != null) {
        session.endEdit();
        _focus.requestFocus();
      } else {
        session.clearSelection();
      }
      return KeyEventResult.handled;
    }
    if (session.editing != null || _addFocus.hasFocus) {
      if (key == LogicalKeyboardKey.enter &&
          !keyboard.isShiftPressed &&
          !_composing) {
        if (_addFocus.hasFocus) {
          _submitAdd();
        } else {
          session.endEdit();
          _focus.requestFocus();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    TagEditorAction? action;
    if (modifier) {
      action = switch (key) {
        LogicalKeyboardKey.keyA => TagEditorAction.selectAll,
        LogicalKeyboardKey.keyC => TagEditorAction.copy,
        LogicalKeyboardKey.keyX => TagEditorAction.cut,
        LogicalKeyboardKey.keyV => TagEditorAction.paste,
        _ => null,
      };
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      action = TagEditorAction.delete;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.f2) {
      action = TagEditorAction.edit;
    }
    if (action == null) return KeyEventResult.ignored;
    unawaited(_action(action));
    return KeyEventResult.handled;
  }

  Rect? _tagRect(int id, RenderBox relativeTo) {
    final box = _keys[id]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(relativeTo),
      Offset.zero & box.size,
    );
  }

  List<Rect> _boxRects() {
    final box = _boxKey.currentContext?.findRenderObject();
    return [
      for (final tag in session.leaves)
        box is RenderBox ? _tagRect(tag.id, box) ?? Rect.zero : Rect.zero,
    ];
  }

  Widget _toolbar(BuildContext context, OverlayChildLayoutInfo info) {
    final surface = _surfaceKey.currentContext?.findRenderObject();
    // Group actions must clear the header as well as the selected leaves.
    final id = session.selectedGroup?.id ?? session.selected.firstOrNull;
    final local = id != null && surface is RenderBox
        ? _tagRect(id, surface)
        : null;
    if (local == null) return const SizedBox.shrink();
    final anchor = MatrixUtils.transformRect(info.childPaintTransform, local);
    final allDisabled = session.selectedTags.every((tag) => tag.span.disabled);
    return PromptActionOverlay(
      anchor: anchor,
      overlaySize: info.overlaySize,
      child: TapRegion(
        groupId: session,
        child: TextFieldTapRegion(
          child: Listener(
            onPointerSignal: _wheel,
            child: PromptActionSurface(
              key: const ValueKey('tag-action-toolbar'),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: PromptWeightControls(
                  showEdit:
                      context.interactionPolicy.shouldExposeTouchAlternatives,
                  onEdit:
                      widget.enabled && commands.available(TagEditorAction.edit)
                      ? () => _action(TagEditorAction.edit)
                      : null,
                  onClose: session.clearSelection,
                  weight: commands.weight,
                  enabled: widget.enabled && commands.canAdjust,
                  onWeight: (value) => commands.adjustWeight(value: value),
                  onStep: (step) => commands.adjustWeight(step: step),
                  trailing: [
                    IconButton(
                      tooltip: allDisabled
                          ? context.l10n.tagMode_enable
                          : context.l10n.tagMode_disable,
                      onPressed: widget.enabled && commands.canAdjust
                          ? () => session.toggleEnabled(
                              session.selected,
                              enabled: allDisabled,
                            )
                          : null,
                      icon: Icon(
                        allDisabled
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('tag-delete-button'),
                      tooltip: context.l10n.tagMode_deleteTags,
                      onPressed:
                          widget.enabled &&
                              commands.available(TagEditorAction.delete)
                          ? () => _action(TagEditorAction.delete)
                          : null,
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                    Builder(
                      builder: (buttonContext) => IconButton(
                        tooltip: context.l10n.common_moreActions,
                        onPressed: () {
                          final box =
                              buttonContext.findRenderObject()! as RenderBox;
                          unawaited(
                            _menu(
                              box.localToGlobal(Offset(0, box.size.height)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.more_horiz, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startBoxSelection() {
    _boxSelecting = true;
    final keyboard = HardwareKeyboard.instance;
    _boxBase = keyboard.isControlPressed || keyboard.isMetaPressed
        ? Set.of(session.selected)
        : {};
    _focus.requestFocus();
    _refresh();
  }

  void _boxSelectionChanged(Set<int> indices) {
    final all = session.leaves.toList();
    session.setSelection({
      ..._boxBase,
      ...indices.where((i) => i < all.length).map((i) => all[i].id),
    });
  }

  Widget _buildAddition() {
    final colors = Theme.of(context).colorScheme;
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide.none,
    );
    if (!_adding) {
      final diameter = context.interactionPolicy.minimumControlExtent.clamp(
        44.0,
        double.infinity,
      );
      return TextFieldTapRegion(
        child: Tooltip(
          message: context.l10n.tagMode_add,
          child: TextButton(
            key: const ValueKey('tag-add-button'),
            onPressed: widget.enabled ? () => _openAddition(atEnd: true) : null,
            style: TextButton.styleFrom(
              fixedSize: Size.square(diameter),
              minimumSize: Size.square(diameter),
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              foregroundColor: colors.onSurfaceVariant,
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.add, size: 20),
          ),
        ),
      );
    }
    return SizedBox(
      width: 200,
      child: AutocompleteWrapper(
        overlayHandle: _autocomplete,
        controller: _add,
        focusNode: _addFocus,
        enabled: widget.enabled && widget.enableAutocomplete,
        child: TextField(
          key: const ValueKey('tag-add-input'),
          controller: _add,
          focusNode: _addFocus,
          enabled: widget.enabled,
          maxLines: null,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: context.l10n.tagMode_add,
            filled: true,
            fillColor: controlSurfaceColor(colors),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: inputBorder,
            disabledBorder: inputBorder,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 8,
            ),
          ),
          onSubmitted: (_) => _submitAdd(),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BoxConstraints constraints) {
    final width = (constraints.maxWidth - 24).clamp(0.0, double.infinity);
    return BoxSelectionOverlay(
      key: _boxKey,
      enabled:
          widget.enabled &&
          session.editing == null &&
          context.interactionPolicy.precisePointerAvailable,
      startOnEmptySpace: true,
      getTagRects: _boxRects,
      onSelectionStart: _startBoxSelection,
      onSelectionChanged: _boxSelectionChanged,
      onSelectionEnd: () {
        _boxSelecting = false;
        _refresh();
      },
      child: SizedBox(
        width: constraints.maxWidth,
        child: SingleChildScrollView(
          key: TagEditorView.scrollViewKey,
          controller: _scroll,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, widget.bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TagEditorTree(
                  autocompleteOverlay: _autocomplete,
                  addition: _buildAddition(),
                  onDraggingChanged: (dragging) {
                    _draggingTags = dragging;
                    _refresh();
                  },
                  session: session,
                  pendingAddition: _pendingAddRange,
                  width: width,
                  keys: _keys,
                  enabled: widget.enabled,
                  enableAutocomplete: widget.enableAutocomplete,
                  showTranslation: _chinese,
                  translations: _translations?.values,
                  onRetryTranslation: () => _translations?.retry(),
                  onSelect: _select,
                  onEdit: _edit,
                  onMenu: (position, tag) => _menu(position, tag: tag),
                  onWheel: (event, id) => _wheel(event, tagId: id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _chinese = Localizations.localeOf(context).languageCode == 'zh';
    final lookup = _chinese ? ref.watch(tagTranslationLookupProvider) : null;
    if (!identical(lookup, _lookup)) {
      _translations?.dispose();
      _lookup = lookup;
      _translations = lookup == null
          ? null
          : (PromptTranslationController(lookup)..addListener(_translated));
      _syncTranslations(immediate: true);
    }
    return PopScope(
      canPop:
          !_autocomplete.isOpen &&
          !_addFocus.hasFocus &&
          session.editing == null &&
          session.selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_autocomplete.isOpen) {
          _autocomplete.dismiss();
        } else if (_addFocus.hasFocus) {
          _addFocus.unfocus();
          _focus.requestFocus();
        } else if (session.editing != null) {
          session.endEdit();
          _focus.requestFocus();
        } else {
          session.clearSelection();
        }
      },
      child: TapRegion(
        groupId: session,
        onTapOutside: (event) {
          if (event.kind == PointerDeviceKind.touch ||
              event.kind == PointerDeviceKind.stylus) {
            _dismissTouchSelection();
          }
        },
        child: Focus(
          focusNode: _focus,
          onKeyEvent: _key,
          child: OverlayPortal.overlayChildLayoutBuilder(
            controller: _overlay,
            overlayChildBuilder: (context, info) => ValueListenableBuilder<int>(
              valueListenable: _toolbarRevision,
              builder: (context, _, _) => _toolbar(context, info),
            ),
            child: Material(
              key: _surfaceKey,
              borderRadius:
                  Theme.of(context).inputDecorationTheme.border
                      is OutlineInputBorder
                  ? (Theme.of(context).inputDecorationTheme.border!
                            as OutlineInputBorder)
                        .borderRadius
                  : BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              color:
                  widget.surfaceColor ??
                  inputSurfaceFillColor(Theme.of(context).colorScheme),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: context.interactionPolicy.prefersTouchPresentation
                    ? _dismissTouchSelection
                    : null,
                child: LayoutBuilder(builder: _buildContent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
