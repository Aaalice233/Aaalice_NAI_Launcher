import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common/app_toast.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/reverse_prompt_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../widgets/tag_library/tag_library_picker_dialog.dart';
import '../models/prompt_assistant_models.dart';
import '../providers/prompt_assistant_config_provider.dart';
import '../providers/prompt_assistant_history_provider.dart';
import '../providers/prompt_assistant_state_provider.dart';
import '../services/prompt_assistant_service.dart';
import 'prompt_assistant_custom_dialog.dart';

class PromptAssistantOverlay extends ConsumerStatefulWidget {
  /// Bottom inset the prompt editor reserves while this overlay is visible.
  ///
  /// Keeps prompt text and selection highlights clear of the overlay toolbar.
  static double get contentBottomClearance =>
      PlatformCapabilities.current.hasTouchInput ? 68 : 56;

  /// Shared inline toolbar height for both collapsed and expanded states.
  static double get inlineToolbarHeight =>
      PlatformCapabilities.current.hasTouchInput ? 48 : 32;

  const PromptAssistantOverlay({
    super.key,
    required this.sessionId,
    required this.controller,
    this.onChanged,
    this.onOpenSettings,
    this.enabled = true,
    this.floatOverEditor = true,
    this.expandInPlace = true,
    this.iconOnly = false,
    this.compactDesktopToolbar = false,
    this.expandInRootOverlay = false,
    this.tapRegionGroupId,
  });

  final String sessionId;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onOpenSettings;
  final bool enabled;

  /// Whether the trigger floats over the bottom-right corner of an editor.
  final bool floatOverEditor;

  /// Whether the trigger expands into an inline toolbar.
  ///
  /// Compact editors use the existing bottom-sheet menu instead, keeping the
  /// prompt surface free of controls and preserving its readable area.
  final bool expandInPlace;

  /// Keeps the collapsed entry icon-only, including on desktop.
  final bool iconOnly;

  /// Keeps priority actions inline and moves history into the overflow menu.
  final bool compactDesktopToolbar;

  static double collapsedInlineButtonWidth(BuildContext context, String label) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return (textPainter.width + 41)
        .ceilToDouble()
        .clamp(64, double.infinity)
        .toDouble();
  }

  /// Renders the expanded action row in the root overlay above clipped cards.
  final bool expandInRootOverlay;

  /// Keeps root-overlay actions inside an owning editor's tap region.
  final Object? tapRegionGroupId;

  @override
  ConsumerState<PromptAssistantOverlay> createState() =>
      _PromptAssistantOverlayState();
}

class _PromptAssistantOverlayState
    extends ConsumerState<PromptAssistantOverlay> {
  StreamSubscription? _streamSub;
  final LayerLink _rootOverlayLink = LayerLink();
  OverlayEntry? _rootOverlayEntry;
  Widget? _rootOverlayChild;
  bool _rootOverlayDesiredVisible = false;
  bool _overlaySyncScheduled = false;

  bool get _isDesktop => PlatformCapabilities.current.hasPrecisePointer;

  @override
  void didUpdateWidget(PromptAssistantOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      unawaited(_streamSub?.cancel());
      _streamSub = null;
    }
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.expandInRootOverlay != widget.expandInRootOverlay) {
      _syncRootOverlay(false);
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _removeRootOverlay();
    super.dispose();
  }

  void _syncRootOverlay(bool visible) {
    _rootOverlayDesiredVisible = visible;
    if (_overlaySyncScheduled) return;
    _overlaySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlaySyncScheduled = false;
      if (!mounted) return;
      final expanded =
          ref.read(promptAssistantStateProvider)[widget.sessionId]?.expanded ??
          false;
      if (!widget.expandInRootOverlay ||
          !expanded ||
          !_rootOverlayDesiredVisible) {
        _removeRootOverlay();
        return;
      }
      if (_rootOverlayEntry != null) {
        _rootOverlayEntry!.markNeedsBuild();
        return;
      }
      _rootOverlayEntry = OverlayEntry(
        builder: (overlayContext) => CompositedTransformFollower(
          link: _rootOverlayLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topRight,
          followerAnchor: Alignment.topRight,
          child: TapRegion(
            groupId: widget.tapRegionGroupId,
            child: UnconstrainedBox(
              alignment: Alignment.topRight,
              child: Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(overlayContext).width - 16,
                  ),
                  child: _rootOverlayChild ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );
      Overlay.of(context, rootOverlay: true).insert(_rootOverlayEntry!);
    });
  }

  void _removeRootOverlay() {
    _rootOverlayEntry?.remove();
    _rootOverlayEntry = null;
    _rootOverlayChild = null;
  }

  Future<void> _runTranslate() async {
    final inputText = _assistantInputText();
    await _runAction(
      context.l10n.promptAssistant_translateProcessing,
      inputText,
      (service, input) =>
          service.translatePrompt(input, sessionId: widget.sessionId),
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
    final inputText = _assistantInputText();
    final provider = _activeProviderForTask(AssistantTaskType.custom);
    final result = await showDialog<PromptAssistantCustomDialogResult>(
      context: context,
      builder: (context) => PromptAssistantCustomDialog(
        currentPrompt: inputText,
        allowImages: provider?.allowImageInput ?? false,
      ),
    );
    if (result == null) {
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
    final processingLabel =
        context.l10n.promptAssistant_characterReplaceProcessing;
    final character = await _selectCharacterForReplacement();
    if (character == null) {
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

  Future<CharacterPrompt?> _selectCharacterForReplacement() async {
    final character = ref
        .read(reversePromptCharacterProvider.notifier)
        .selectedCharacter;
    if (character != null) {
      return character;
    }
    return await _pickReplacementCharacterFromLibrary();
  }

  Future<CharacterPrompt?> _pickReplacementCharacterFromLibrary() async {
    final entry = await showDialog<TagLibraryEntry>(
      context: context,
      builder: (context) => TagLibraryPickerDialog(
        title: context.l10n.reversePrompt_selectReplacementTargetTitle,
      ),
    );
    if (entry == null) {
      if (mounted) {
        AppToast.warning(context, context.l10n.promptAssistant_needCharacter);
      }
      return null;
    }

    ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entry.id);
    final character = CharacterPrompt.create(
      name: entry.displayName,
      prompt: entry.content,
      thumbnailPath: entry.thumbnail,
    );
    ref
        .read(reversePromptCharacterProvider.notifier)
        .setReplacementCharacter(character);
    return character;
  }

  Future<void> _runAction(
    String label,
    String inputText,
    Stream<dynamic> Function(PromptAssistantService service, String input)
    builder,
  ) async {
    final text = inputText.trim();
    if (text.isEmpty) {
      if (mounted) {
        AppToast.warning(context, context.l10n.promptAssistant_needPrompt);
      }
      return;
    }

    final beforeText = widget.controller.text;
    ref
        .read(promptAssistantHistoryProvider.notifier)
        .push(widget.sessionId, beforeText);

    final stateNotifier = ref.read(promptAssistantStateProvider.notifier);
    stateNotifier.startProcessing(widget.sessionId, label);

    final service = ref.read(promptAssistantServiceProvider);
    final buffer = StringBuffer();

    await _streamSub?.cancel();
    _streamSub = builder(service, text).listen(
      (chunk) {
        if (chunk.done == true) return;
        final delta = chunk.delta as String? ?? '';
        if (delta.isEmpty) return;
        buffer.write(delta);
      },
      onError: (e) {
        stateNotifier.setError(widget.sessionId, e.toString());
        if (mounted) {
          AppToast.error(
            context,
            context.l10n.promptAssistant_requestFailed(e),
          );
        }
      },
      onDone: () {
        if (buffer.isNotEmpty) {
          _replaceText(buffer.toString());
        }
        stateNotifier.finishProcessing(widget.sessionId);
        final afterText = widget.controller.text;
        ref
            .read(promptAssistantHistoryProvider.notifier)
            .recordExternalChange(
              widget.sessionId,
              before: beforeText,
              after: afterText,
            );
        ref
            .read(promptAssistantHistoryProvider.notifier)
            .push(widget.sessionId, afterText);
      },
      cancelOnError: true,
    );
  }

  Future<void> _runCustomAction(
    String inputText,
    PromptAssistantCustomDialogResult result,
  ) async {
    final beforeText = widget.controller.text;
    ref
        .read(promptAssistantHistoryProvider.notifier)
        .push(widget.sessionId, beforeText);

    final stateNotifier = ref.read(promptAssistantStateProvider.notifier);
    stateNotifier.startProcessing(
      widget.sessionId,
      context.l10n.promptAssistant_customProcessing,
    );

    final service = ref.read(promptAssistantServiceProvider);
    final buffer = StringBuffer();

    await _streamSub?.cancel();
    _streamSub = service
        .customPrompt(
          inputText,
          sessionId: widget.sessionId,
          userRequest: result.userRequest,
          images: result.images,
        )
        .listen(
          (chunk) {
            if (chunk.done == true) return;
            final delta = chunk.delta as String? ?? '';
            if (delta.isEmpty) return;
            buffer.write(delta);
          },
          onError: (e) {
            stateNotifier.setError(widget.sessionId, e.toString());
            if (mounted) {
              AppToast.error(
                context,
                context.l10n.promptAssistant_requestFailed(e),
              );
            }
          },
          onDone: () {
            if (buffer.isNotEmpty) {
              _replaceText(buffer.toString());
            }
            stateNotifier.finishProcessing(widget.sessionId);
            final afterText = widget.controller.text;
            ref
                .read(promptAssistantHistoryProvider.notifier)
                .recordExternalChange(
                  widget.sessionId,
                  before: beforeText,
                  after: afterText,
                );
            ref
                .read(promptAssistantHistoryProvider.notifier)
                .push(widget.sessionId, afterText);
          },
          cancelOnError: true,
        );
  }

  String _assistantInputText() {
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView.builder(
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
        );
      },
    );
  }

  void _showMenu([Offset? position]) {
    if (_isDesktop && position != null) {
      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx,
          position.dy,
        ),
        items: [
          PopupMenuItem(
            value: 'history',
            enabled:
                ref
                    .read(promptAssistantHistoryProvider)[widget.sessionId]
                    ?.history
                    .isNotEmpty ??
                false,
            child: Text(context.l10n.promptAssistant_history),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'assistant_settings',
            child: Text(context.l10n.promptAssistant_assistantSettings),
          ),
          PopupMenuItem(
            value: 'service_settings',
            child: Text(context.l10n.promptAssistant_serviceSettings),
          ),
          PopupMenuItem(
            value: 'rule_settings',
            child: Text(context.l10n.promptAssistant_ruleSettings),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'cancel',
            child: Text(context.l10n.promptAssistant_cancelCurrentTask),
          ),
        ],
      ).then((value) async {
        if (value == 'history') {
          _showHistory();
        } else if (value == 'cancel') {
          await ref
              .read(promptAssistantServiceProvider)
              .cancelCurrentTask(sessionId: widget.sessionId);
          ref
              .read(promptAssistantStateProvider.notifier)
              .finishProcessing(widget.sessionId);
        } else if (value != null) {
          widget.onOpenSettings?.call();
        }
      });
      return;
    }

    final operationState = ref.read(
      promptAssistantStateProvider.select(
        (states) =>
            states[widget.sessionId] ?? const PromptAssistantOperationState(),
      ),
    );
    final history = ref.read(promptAssistantHistoryProvider)[widget.sessionId];
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(context.l10n.promptAssistant_history),
                enabled: history?.history.isNotEmpty ?? false,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showHistory();
                },
              ),
              ListTile(
                leading: const Icon(Icons.undo),
                title: Text(context.l10n.promptAssistant_undo),
                enabled: history?.canUndo ?? false,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _undo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.redo),
                title: Text(context.l10n.promptAssistant_redo),
                enabled: history?.canRedo ?? false,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _redo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(context.l10n.promptAssistant_translate),
                enabled: !operationState.processing,
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_runTranslate());
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_fix_high),
                title: Text(context.l10n.promptAssistant_optimize),
                enabled: !operationState.processing,
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_runOptimize());
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: Text(context.l10n.promptAssistant_custom),
                enabled: !operationState.processing,
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_runCustom());
                },
              ),
              ListTile(
                leading: const Icon(Icons.manage_accounts_rounded),
                title: Text(context.l10n.promptAssistant_characterReplace),
                enabled: !operationState.processing,
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_runCharacterReplace());
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: Text(context.l10n.promptAssistant_assistantSettings),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onOpenSettings?.call();
                },
              ),
              if (operationState.processing)
                ListTile(
                  leading: const Icon(Icons.stop_circle),
                  title: Text(context.l10n.promptAssistant_cancelCurrentTask),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await ref
                        .read(promptAssistantServiceProvider)
                        .cancelCurrentTask(sessionId: widget.sessionId);
                    ref
                        .read(promptAssistantStateProvider.notifier)
                        .finishProcessing(widget.sessionId);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(promptAssistantConfigProvider);
    if (!widget.enabled || !config.enabled) {
      if (widget.expandInRootOverlay) _syncRootOverlay(false);
      return const SizedBox.shrink();
    }
    if (_isDesktop && !config.desktopOverlayEnabled) {
      if (widget.expandInRootOverlay) _syncRootOverlay(false);
      return const SizedBox.shrink();
    }

    final state = ref.watch(
      promptAssistantStateProvider.select(
        (m) => m[widget.sessionId] ?? const PromptAssistantOperationState(),
      ),
    );
    final history = ref.watch(
      promptAssistantHistoryProvider.select(
        (m) => m[widget.sessionId] ?? const PromptHistoryStack(),
      ),
    );
    final notifier = ref.read(promptAssistantStateProvider.notifier);

    final isExpanded = widget.expandInPlace && state.expanded;
    final isProcessing = state.processing;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final child = Focus(
      onKeyEvent: (node, event) {
        if (!_isDesktop || event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyE) {
          _runOptimize();
          return KeyEventResult.handled;
        }
        if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyT) {
          _runTranslate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onSecondaryTapDown: _isDesktop
            ? (details) => _showMenu(details.globalPosition)
            : null,
        child: AnimatedContainer(
          key: ValueKey<String>('prompt_assistant_toolbar_${widget.sessionId}'),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
          padding: !widget.floatOverEditor
              ? EdgeInsets.zero
              : isExpanded
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
              : const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: !widget.floatOverEditor
                ? Colors.transparent
                : isExpanded
                ? Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.82)
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(isExpanded ? 12 : 15),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: isExpanded,
            clipBehavior: widget.floatOverEditor ? Clip.none : Clip.hardEdge,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isExpanded)
                  if (widget.expandInPlace && _isDesktop && !widget.iconOnly)
                    _collapsedInlineButton(
                      label: context.l10n.promptAssistant_assistant,
                      tooltip: context.l10n.promptAssistant_expandAssistant,
                      onPressed: () =>
                          notifier.setExpanded(widget.sessionId, true),
                    )
                  else
                    _miniButton(
                      icon: Icons.auto_awesome_rounded,
                      tooltip: widget.expandInPlace
                          ? context.l10n.promptAssistant_expandAssistant
                          : context.l10n.promptAssistant_menu,
                      onPressed: widget.expandInPlace
                          ? () => notifier.setExpanded(widget.sessionId, true)
                          : () => _showMenu(),
                      iconColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
                if (isExpanded &&
                    (!_isDesktop || widget.compactDesktopToolbar)) ...[
                  _miniButton(
                    icon: Icons.translate,
                    tooltip: context.l10n.promptAssistant_translate,
                    onPressed: isProcessing ? null : _runTranslate,
                  ),
                  _miniButton(
                    icon: Icons.auto_fix_high,
                    tooltip: context.l10n.promptAssistant_optimize,
                    onPressed: isProcessing ? null : _runOptimize,
                  ),
                  _miniButton(
                    icon: Icons.tune_rounded,
                    tooltip: context.l10n.promptAssistant_custom,
                    onPressed: isProcessing ? null : _runCustom,
                  ),
                  _miniButton(
                    icon: Icons.manage_accounts_rounded,
                    tooltip: context.l10n.promptAssistant_characterReplace,
                    onPressed: isProcessing ? null : _runCharacterReplace,
                  ),
                  _miniButton(
                    icon: isProcessing ? Icons.stop_circle : Icons.more_horiz,
                    tooltip: isProcessing
                        ? context.l10n.promptAssistant_cancelTask
                        : context.l10n.promptAssistant_menu,
                    onPressed: isProcessing
                        ? () async {
                            await ref
                                .read(promptAssistantServiceProvider)
                                .cancelCurrentTask(sessionId: widget.sessionId);
                            notifier.finishProcessing(widget.sessionId);
                          }
                        : () => _showMenu(),
                  ),
                  _miniButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    tooltip: context.l10n.promptAssistant_collapseAssistant,
                    onPressed: () =>
                        notifier.setExpanded(widget.sessionId, false),
                  ),
                ] else if (isExpanded) ...[
                  // History stays in the overflow menu so the full action row
                  // remains inside narrow desktop generation sidebars.
                  _miniButton(
                    icon: Icons.undo,
                    tooltip: context.l10n.promptAssistant_undo,
                    onPressed: history.canUndo ? _undo : null,
                  ),
                  _miniButton(
                    icon: Icons.redo,
                    tooltip: context.l10n.promptAssistant_redo,
                    onPressed: history.canRedo ? _redo : null,
                  ),
                  _miniButton(
                    icon: Icons.translate,
                    tooltip: context.l10n.promptAssistant_translate,
                    onPressed: isProcessing ? null : _runTranslate,
                  ),
                  _miniButton(
                    icon: Icons.auto_fix_high,
                    tooltip: context.l10n.promptAssistant_optimize,
                    onPressed: isProcessing ? null : _runOptimize,
                  ),
                  _miniButton(
                    icon: Icons.tune_rounded,
                    tooltip: context.l10n.promptAssistant_custom,
                    onPressed: isProcessing ? null : _runCustom,
                  ),
                  _miniButton(
                    icon: Icons.manage_accounts_rounded,
                    tooltip: context.l10n.promptAssistant_characterReplace,
                    onPressed: isProcessing ? null : _runCharacterReplace,
                  ),
                  _miniButton(
                    icon: isProcessing ? Icons.stop_circle : Icons.more_horiz,
                    tooltip: isProcessing
                        ? context.l10n.promptAssistant_cancelTask
                        : context.l10n.promptAssistant_menu,
                    onPressed: isProcessing
                        ? () async {
                            await ref
                                .read(promptAssistantServiceProvider)
                                .cancelCurrentTask(sessionId: widget.sessionId);
                            notifier.finishProcessing(widget.sessionId);
                          }
                        : () => _showMenu(),
                  ),
                  _miniButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    tooltip: context.l10n.promptAssistant_collapseAssistant,
                    onPressed: () =>
                        notifier.setExpanded(widget.sessionId, false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.expandInRootOverlay) {
      _rootOverlayChild = isExpanded ? child : null;
      _syncRootOverlay(isExpanded);
      return CompositedTransformTarget(
        link: _rootOverlayLink,
        child: SizedBox.square(
          dimension: PromptAssistantOverlay.inlineToolbarHeight,
          child: isExpanded ? null : child,
        ),
      );
    }

    if (!widget.floatOverEditor) {
      return child;
    }

    // Give the expanding toolbar the editor's real horizontal constraint. An
    // unconstrained right-anchored child grows to its full intrinsic width and
    // gets clipped past the editor's left edge on narrow desktop panels.
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: Align(alignment: Alignment.bottomRight, child: child),
    );
  }

  Widget _collapsedInlineButton({
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final foregroundColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.78);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 180),
      showDuration: const Duration(milliseconds: 1200),
      verticalOffset: 12,
      preferBelow: false,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      child: SizedBox(
        width: PromptAssistantOverlay.collapsedInlineButtonWidth(
          context,
          label,
        ),
        height: _isDesktop ? 32 : 48,
        child: TextButton.icon(
          key: const ValueKey('prompt_assistant_collapsed_button'),
          onPressed: onPressed,
          icon: Icon(Icons.auto_awesome_rounded, size: _isDesktop ? 17 : 20),
          label: Text(label, maxLines: 1),
          style: TextButton.styleFrom(
            foregroundColor: foregroundColor,
            minimumSize: Size(0, _isDesktop ? 32 : 48),
            padding: EdgeInsets.symmetric(horizontal: _isDesktop ? 8 : 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: TextStyle(fontSize: _isDesktop ? 12 : 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? iconColor,
    double iconSize = 17,
    double buttonSize = 32,
  }) {
    final effectiveButtonSize = _isDesktop ? buttonSize : 48.0;
    final effectiveIconSize = _isDesktop ? iconSize : 20.0;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 180),
      showDuration: const Duration(milliseconds: 1200),
      verticalOffset: 12,
      preferBelow: false,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: IconButton(
          constraints: BoxConstraints.tightFor(
            width: effectiveButtonSize,
            height: effectiveButtonSize,
          ),
          padding: EdgeInsets.zero,
          icon: Icon(icon, size: effectiveIconSize, color: iconColor),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
