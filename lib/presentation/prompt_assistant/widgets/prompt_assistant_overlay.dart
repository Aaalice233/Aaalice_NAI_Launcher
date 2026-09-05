import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common/app_toast.dart';
import '../../widgets/common/context_menu_anchor.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/prompt_editor_preferences_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../widgets/tag_library/tag_library_picker_dialog.dart';
import '../models/prompt_assistant_models.dart';
import '../providers/prompt_assistant_config_provider.dart';
import '../providers/prompt_assistant_history_provider.dart';
import '../providers/prompt_assistant_state_provider.dart';
import '../services/prompt_assistant_service.dart';
import 'prompt_assistant_custom_dialog.dart';
import 'prompt_assistant_toolbar.dart';
import '../../widgets/prompt/prompt_viewport_actions.dart';

enum _PromptAssistantMenuAction {
  history,
  undo,
  redo,
  translate,
  optimize,
  custom,
  characterReplace,
  assistantSettings,
  serviceSettings,
  ruleSettings,
}

/// Inline mounts size to the toolbar; editor mounts belong directly in a Stack;
/// viewport mounts fill the editor and stay within its visible scrolling region.
enum PromptAssistantPlacement { inline, editor, viewport }

class PromptAssistantOverlay extends ConsumerStatefulWidget {
  const PromptAssistantOverlay({
    super.key,
    required this.sessionId,
    required this.controller,
    this.onChanged,
    this.onOpenSettings,
    this.enabled = true,
    this.placement = PromptAssistantPlacement.editor,
    this.expandInPlace = true,
    this.iconOnly = false,
    this.compactDesktopToolbar = false,
    this.tapRegionGroupId,
    this.interactionPolicy,
    this.stripFixedTagsFromInput = true,
    this.supportsTagMode = false,
    this.tagModeSessionId,
  });

  final String sessionId;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onOpenSettings;
  final bool enabled;
  final PromptAssistantPlacement placement;
  final bool expandInPlace;
  final bool iconOnly;
  final bool compactDesktopToolbar;
  final Object? tapRegionGroupId;
  final InteractionPolicy? interactionPolicy;
  final bool stripFixedTagsFromInput;
  final bool supportsTagMode;
  final Object? tagModeSessionId;

  bool isVisible(BuildContext context, WidgetRef ref) {
    final config = ref.watch(promptAssistantConfigProvider);
    final policy = interactionPolicy ?? context.interactionPolicy;
    return enabled &&
        config.enabled &&
        (!policy.usesAnchoredMenus || config.desktopOverlayEnabled);
  }

  String? collapsedLabel(BuildContext context) {
    final policy = interactionPolicy ?? context.interactionPolicy;
    return expandInPlace && policy.usesAnchoredMenus && !iconOnly
        ? context.l10n.promptAssistant_assistant
        : null;
  }

  PromptAssistantToolbarMetrics metrics(BuildContext context) {
    final policy = interactionPolicy ?? context.interactionPolicy;
    return PromptAssistantToolbarMetrics.resolve(
      context,
      policy: policy,
      collapsedLabel: collapsedLabel(context),
      actionCount: !policy.usesAnchoredMenus || compactDesktopToolbar ? 6 : 8,
    );
  }

  @override
  ConsumerState<PromptAssistantOverlay> createState() =>
      _PromptAssistantOverlayState();
}

class _PromptAssistantOverlayState
    extends ConsumerState<PromptAssistantOverlay> {
  StreamSubscription<StreamingChunk>? _streamSub;
  int _operation = 0;
  VoidCallback? _abandonOperation;

  bool get _processing =>
      ref.read(promptAssistantStateProvider)[widget.sessionId]?.processing ??
      false;

  InteractionPolicy get _interactionPolicy =>
      widget.interactionPolicy ?? context.interactionPolicy;

  bool get _usesAnchoredMenus => _interactionPolicy.usesAnchoredMenus;

  @override
  void didUpdateWidget(PromptAssistantOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.controller != widget.controller) {
      _operation++;
      _abandonOperation?.call();
      _abandonOperation = null;
      unawaited(_streamSub?.cancel());
      _streamSub = null;
    }
  }

  @override
  void dispose() {
    _operation++;
    _abandonOperation?.call();
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _runTranslate() async {
    final inputText = _assistantInputText();
    final tagMode =
        widget.supportsTagMode &&
        ref.read(
          promptTagModeProvider(widget.tagModeSessionId ?? widget.sessionId),
        );
    await _runAction(
      context.l10n.promptAssistant_translateProcessing,
      inputText,
      (service, input) => tagMode
          ? service.translateTagLabels(input, sessionId: widget.sessionId)
          : service.translatePrompt(input, sessionId: widget.sessionId),
    );
  }

  Future<void> _runOptimize() async {
    final inputText = _assistantInputText();
    await _runAction(
      context.l10n.promptAssistant_optimizeProcessing,
      inputText,
      (service, input) =>
          service.optimizePrompt(input, sessionId: widget.sessionId),
    );
  }

  Future<void> _runCustom() async {
    if (_processing) return;
    final inputText = _assistantInputText();
    final provider = _activeProviderForTask(AssistantTaskType.custom);
    final result = await PromptAssistantCustomDialog.show(
      context: context,
      currentPrompt: inputText,
      allowImages: provider?.allowImageInput ?? false,
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.images.isNotEmpty && provider?.allowImageInput != true) {
      if (mounted) {
        AppToast.warning(
          context,
          context.l10n.promptAssistant_imageInputDisabled,
        );
      }
      return;
    }
    await _runCustomAction(inputText, result);
  }

  ProviderConfig? _activeProviderForTask(AssistantTaskType taskType) {
    final config = ref.read(promptAssistantConfigProvider);
    final providerId = config.routing.providerIdFor(taskType);
    final enabledProviders = config.providers.where((p) => p.enabled).toList();
    if (enabledProviders.isEmpty) return null;
    return enabledProviders.cast<ProviderConfig?>().firstWhere(
      (provider) => provider?.id == providerId,
      orElse: () => enabledProviders.first,
    );
  }

  Future<void> _runCharacterReplace() async {
    if (_processing) return;
    final processingLabel =
        context.l10n.promptAssistant_characterReplaceProcessing;
    final character = await _pickReplacementCharacterFromLibrary();
    if (!mounted || character == null) {
      return;
    }

    final inputText = _assistantInputText();
    await _runAction(
      processingLabel,
      inputText,
      (service, input) => service.replaceCharacterPrompt(
        input,
        sessionId: widget.sessionId,
        characterName: character.name,
        characterPrompt: character.prompt,
      ),
    );
  }

  Future<CharacterPrompt?> _pickReplacementCharacterFromLibrary() async {
    final entry = await TagLibraryPickerDialog.show(
      context,
      title: context.l10n.reversePrompt_selectReplacementTargetTitle,
    );
    if (!mounted || entry == null) return null;

    ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entry.id);
    final character = CharacterPrompt.create(
      name: entry.displayName,
      prompt: entry.content,
      thumbnailPath: entry.thumbnail,
    );
    return character;
  }

  Future<void> _runAction(
    String label,
    String inputText,
    Stream<StreamingChunk> Function(
      PromptAssistantService service,
      String input,
    )
    builder, {
    bool allowEmpty = false,
  }) async {
    if (!mounted || _processing) return;
    final text = inputText.trim();
    if (!allowEmpty && text.isEmpty) {
      AppToast.warning(context, context.l10n.promptAssistant_needPrompt);
      return;
    }
    final operation = ++_operation;
    final sessionId = widget.sessionId;
    final beforeText = widget.controller.text;
    final history = ref.read(promptAssistantHistoryProvider.notifier);
    final stateNotifier = ref.read(promptAssistantStateProvider.notifier);
    final service = ref.read(promptAssistantServiceProvider);
    history.push(sessionId, beforeText);
    stateNotifier.startProcessing(sessionId, label);
    _abandonOperation = () {
      unawaited(service.cancelCurrentTask(sessionId: sessionId));
      // Defer provider mutation when the owning editor is being unmounted.
      if (!stateNotifier.mounted) return;
      final abandonedState = stateNotifier.getState(sessionId);
      scheduleMicrotask(() {
        if (stateNotifier.mounted &&
            identical(stateNotifier.getState(sessionId), abandonedState)) {
          stateNotifier.finishProcessing(sessionId);
        }
      });
    };
    final buffer = StringBuffer();
    bool current() => mounted && operation == _operation;
    void fail(Object error) {
      if (!mounted || !current()) return;
      _abandonOperation = null;
      stateNotifier.setError(sessionId, error.toString());
      AppToast.error(
        context,
        context.l10n.promptAssistant_requestFailed(error),
      );
    }

    try {
      await _streamSub?.cancel();
      if (!mounted || !current()) return;
      _streamSub = builder(service, text).listen(
        (chunk) {
          if (!current() || chunk.done == true) return;
          buffer.write(chunk.delta);
        },
        onError: (Object error) => fail(error),
        onDone: () {
          if (!mounted || !current()) return;
          _abandonOperation = null;
          if (buffer.isNotEmpty) _replaceText(buffer.toString());
          stateNotifier.finishProcessing(sessionId);
          stateNotifier.setExpanded(sessionId, true);
          final afterText = widget.controller.text;
          history.recordExternalChange(
            sessionId,
            before: beforeText,
            after: afterText,
          );
          history.push(sessionId, afterText);
          AppToast.success(context, context.l10n.promptAssistant_completed);
        },
        cancelOnError: true,
      );
    } catch (error) {
      fail(error);
    }
  }

  Future<void> _runCustomAction(
    String inputText,
    PromptAssistantCustomDialogResult result,
  ) => _runAction(
    context.l10n.promptAssistant_customProcessing,
    inputText,
    (service, input) => service.customPrompt(
      input,
      sessionId: widget.sessionId,
      userRequest: result.userRequest,
      images: result.images,
    ),
    allowEmpty: true,
  );

  String _assistantInputText() {
    if (!widget.stripFixedTagsFromInput) return widget.controller.text;
    return ref
        .read(fixedTagsNotifierProvider)
        .stripFromPrompt(widget.controller.text);
  }

  void _replaceText(String value) {
    widget.controller.text = value;
    widget.controller.selection = TextSelection.collapsed(offset: value.length);
    widget.onChanged?.call(value);
  }

  void _undo() {
    final value = ref
        .read(promptAssistantHistoryProvider.notifier)
        .undo(widget.sessionId, widget.controller.text);
    if (value != null) {
      _replaceText(value);
    }
  }

  void _redo() {
    final value = ref
        .read(promptAssistantHistoryProvider.notifier)
        .redo(widget.sessionId, widget.controller.text);
    if (value != null) {
      _replaceText(value);
    }
  }

  void _showHistory() {
    final stack = ref.read(promptAssistantHistoryProvider)[widget.sessionId];
    final history = stack?.history ?? const <String>[];
    AdaptivePresenter.showPanel<void>(
      context: context,
      titleBuilder: (context) => Text(
        context.l10n.promptAssistant_history,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      builder: (context, scrollController) => ListView.builder(
        controller: scrollController,
        itemCount: history.length,
        itemBuilder: (context, index) {
          final entry = history[history.length - 1 - index];
          return ListTile(
            title: Text(entry, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () {
              _replaceText(entry);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Future<void> _handleMenuAction(_PromptAssistantMenuAction action) async {
    if (!mounted || _processing) {
      return;
    }

    switch (action) {
      case _PromptAssistantMenuAction.history:
        _showHistory();
      case _PromptAssistantMenuAction.undo:
        _undo();
      case _PromptAssistantMenuAction.redo:
        _redo();
      case _PromptAssistantMenuAction.translate:
        await _runTranslate();
      case _PromptAssistantMenuAction.optimize:
        await _runOptimize();
      case _PromptAssistantMenuAction.custom:
        await _runCustom();
      case _PromptAssistantMenuAction.characterReplace:
        await _runCharacterReplace();
      case _PromptAssistantMenuAction.assistantSettings:
      case _PromptAssistantMenuAction.serviceSettings:
      case _PromptAssistantMenuAction.ruleSettings:
        widget.onOpenSettings?.call();
    }
  }

  void _selectPanelAction(
    BuildContext panelContext,
    _PromptAssistantMenuAction action,
  ) {
    Navigator.pop(panelContext);
    if (!mounted) return;
    unawaited(_handleMenuAction(action));
  }

  Future<void> _showMenu([Offset? position]) async {
    if (_processing) return;
    final history = ref.read(promptAssistantHistoryProvider)[widget.sessionId];

    if (_usesAnchoredMenus && position != null) {
      final selected = await showMenu<_PromptAssistantMenuAction>(
        context: context,
        position: contextMenuAnchorAt(context, position),
        items: [
          PopupMenuItem(
            value: _PromptAssistantMenuAction.history,
            enabled: history?.history.isNotEmpty ?? false,
            child: Text(context.l10n.promptAssistant_history),
          ),
          PopupMenuItem(
            value: _PromptAssistantMenuAction.undo,
            enabled: history?.canUndo ?? false,
            child: Text(context.l10n.promptAssistant_undo),
          ),
          PopupMenuItem(
            value: _PromptAssistantMenuAction.redo,
            enabled: history?.canRedo ?? false,
            child: Text(context.l10n.promptAssistant_redo),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _PromptAssistantMenuAction.translate,
            child: Text(context.l10n.promptAssistant_translate),
          ),
          PopupMenuItem(
            value: _PromptAssistantMenuAction.optimize,
            child: Text(context.l10n.promptAssistant_optimize),
          ),
          PopupMenuItem(
            value: _PromptAssistantMenuAction.custom,
            child: Text(context.l10n.promptAssistant_custom),
          ),
          PopupMenuItem(
            value: _PromptAssistantMenuAction.characterReplace,
            child: Text(context.l10n.promptAssistant_characterReplace),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _PromptAssistantMenuAction.assistantSettings,
            child: Text(context.l10n.promptAssistant_assistantSettings),
          ),
          PopupMenuItem(
            value: _PromptAssistantMenuAction.serviceSettings,
            child: Text(context.l10n.promptAssistant_serviceSettings),
          ),
          PopupMenuItem(
            value: _PromptAssistantMenuAction.ruleSettings,
            child: Text(context.l10n.promptAssistant_ruleSettings),
          ),
        ],
      );
      if (!mounted || selected == null) return;
      await _handleMenuAction(selected);
      return;
    }

    AdaptivePresenter.showPanel<void>(
      context: context,
      titleBuilder: (context) => Text(
        context.l10n.promptAssistant_menu,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      builder: (sheetContext, scrollController) => ListView(
        controller: scrollController,
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(context.l10n.promptAssistant_history),
            enabled: history?.history.isNotEmpty ?? false,
            onTap: () => _selectPanelAction(
              sheetContext,
              _PromptAssistantMenuAction.history,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.undo),
            title: Text(context.l10n.promptAssistant_undo),
            enabled: history?.canUndo ?? false,
            onTap: () => _selectPanelAction(
              sheetContext,
              _PromptAssistantMenuAction.undo,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.redo),
            title: Text(context.l10n.promptAssistant_redo),
            enabled: history?.canRedo ?? false,
            onTap: () => _selectPanelAction(
              sheetContext,
              _PromptAssistantMenuAction.redo,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(context.l10n.promptAssistant_translate),
            onTap: () => _selectPanelAction(
              sheetContext,
              _PromptAssistantMenuAction.translate,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.auto_fix_high),
            title: Text(context.l10n.promptAssistant_optimize),
            onTap: () => _selectPanelAction(
              sheetContext,
              _PromptAssistantMenuAction.optimize,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: Text(context.l10n.promptAssistant_custom),
            onTap: () => _selectPanelAction(
              sheetContext,
              _PromptAssistantMenuAction.custom,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_rounded),
            title: Text(context.l10n.promptAssistant_characterReplace),
            onTap: () => _selectPanelAction(
              sheetContext,
              _PromptAssistantMenuAction.characterReplace,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(context.l10n.promptAssistant_assistantSettings),
            onTap: () => _selectPanelAction(
              sheetContext,
              _PromptAssistantMenuAction.assistantSettings,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible(context, ref)) return const SizedBox.shrink();
    final state = ref.watch(
      promptAssistantStateProvider.select(
        (states) =>
            states[widget.sessionId] ?? const PromptAssistantOperationState(),
      ),
    );
    final history = ref.watch(
      promptAssistantHistoryProvider.select(
        (states) => states[widget.sessionId] ?? const PromptHistoryStack(),
      ),
    );
    final expanded =
        widget.expandInPlace && state.expanded && !state.processing;
    final toolbar = TapRegion(
      groupId: widget.tapRegionGroupId,
      child: TapRegion(
        // The editor's shared group keeps its edit state alive, while dismissal
        // belongs only to this toolbar, including its rounded corner padding.
        behavior: HitTestBehavior.opaque,
        onTapOutside: expanded
            ? (_) => ref
                  .read(promptAssistantStateProvider.notifier)
                  .setExpanded(widget.sessionId, false)
            : null,
        child: Focus(
          skipTraversal: true,
          onKeyEvent: _toolbarKeyEvent,
          child: GestureDetector(
            onSecondaryTapUp: _usesAnchoredMenus
                ? (details) => _showMenu(details.globalPosition)
                : null,
            child: PromptAssistantToolbar(
              sessionId: widget.sessionId,
              metrics: widget.metrics(context),
              policy: _interactionPolicy,
              expanded: expanded,
              processing: state.processing,
              processingLabel: state.action,
              onCancel: _cancelToolbarTask,
              actions: _toolbarActions(expanded, history),
            ),
          ),
        ),
      ),
    );
    return switch (widget.placement) {
      PromptAssistantPlacement.inline => toolbar,
      PromptAssistantPlacement.viewport => PromptViewportActions(
        child: toolbar,
      ),
      PromptAssistantPlacement.editor => Positioned(
        left: 8,
        right: 8,
        bottom: 8,
        child: Align(alignment: Alignment.bottomRight, child: toolbar),
      ),
    };
  }

  KeyEventResult _toolbarKeyEvent(FocusNode node, KeyEvent event) {
    if (_processing || !_usesAnchoredMenus || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed || !keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      _runOptimize();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyT) {
      _runTranslate();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<PromptAssistantToolbarAction> _toolbarActions(
    bool expanded,
    PromptHistoryStack history,
  ) {
    final l10n = context.l10n;
    final notifier = ref.read(promptAssistantStateProvider.notifier);
    if (!expanded) {
      return [
        PromptAssistantToolbarAction(
          icon: Icons.auto_awesome_rounded,
          tooltip: widget.expandInPlace
              ? l10n.promptAssistant_expandAssistant
              : l10n.promptAssistant_menu,
          label: widget.collapsedLabel(context),
          onPressed: widget.expandInPlace
              ? () => notifier.setExpanded(widget.sessionId, true)
              : () => _showMenu(),
        ),
      ];
    }
    return [
      if (_usesAnchoredMenus && !widget.compactDesktopToolbar) ...[
        PromptAssistantToolbarAction(
          icon: Icons.undo,
          tooltip: l10n.promptAssistant_undo,
          onPressed: history.canUndo ? _undo : null,
        ),
        PromptAssistantToolbarAction(
          icon: Icons.redo,
          tooltip: l10n.promptAssistant_redo,
          onPressed: history.canRedo ? _redo : null,
        ),
      ],
      PromptAssistantToolbarAction(
        icon: Icons.translate,
        tooltip: l10n.promptAssistant_translate,
        onPressed: _runTranslate,
      ),
      PromptAssistantToolbarAction(
        icon: Icons.auto_fix_high,
        tooltip: l10n.promptAssistant_optimize,
        onPressed: _runOptimize,
      ),
      PromptAssistantToolbarAction(
        icon: Icons.tune_rounded,
        tooltip: l10n.promptAssistant_custom,
        onPressed: _runCustom,
      ),
      PromptAssistantToolbarAction(
        icon: Icons.manage_accounts_rounded,
        tooltip: l10n.promptAssistant_characterReplace,
        onPressed: _runCharacterReplace,
      ),
      PromptAssistantToolbarAction(
        icon: Icons.more_horiz,
        tooltip: l10n.promptAssistant_menu,
        onPressed: () => _showMenu(),
      ),
      PromptAssistantToolbarAction(
        icon: Icons.keyboard_arrow_down_rounded,
        tooltip: l10n.promptAssistant_collapseAssistant,
        onPressed: () => notifier.setExpanded(widget.sessionId, false),
      ),
    ];
  }

  Future<void> _cancelToolbarTask() async {
    final service = ref.read(promptAssistantServiceProvider);
    final notifier = ref.read(promptAssistantStateProvider.notifier);
    final sessionId = widget.sessionId;
    _operation++;
    _abandonOperation = null;
    final subscription = _streamSub;
    _streamSub = null;
    try {
      final requestCancellation = service.cancelCurrentTask(
        sessionId: sessionId,
      );
      final streamCancellation = subscription?.cancel();
      await Future.wait([
        requestCancellation,
        if (streamCancellation != null) streamCancellation,
      ]);
      if (notifier.mounted) notifier.finishProcessing(sessionId);
    } catch (error) {
      if (notifier.mounted) notifier.setError(sessionId, error.toString());
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.promptAssistant_requestFailed(error),
        );
      }
    }
  }
}
