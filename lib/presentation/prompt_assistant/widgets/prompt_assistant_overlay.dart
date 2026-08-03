import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common/app_toast.dart';
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
  /// The expanded toolbar is 32 logical pixels tall before hover scaling and
  /// sits 8 pixels above the input edge. The remaining clearance keeps prompt
  /// text and selection highlights out from underneath the toolbar.
  static const double contentBottomClearance = 48;

  const PromptAssistantOverlay({
    super.key,
    required this.sessionId,
    required this.controller,
    this.onOpenSettings,
    this.enabled = true,
  });

  final String sessionId;
  final TextEditingController controller;
  final VoidCallback? onOpenSettings;
  final bool enabled;

  @override
  ConsumerState<PromptAssistantOverlay> createState() =>
      _PromptAssistantOverlayState();
}

class _PromptAssistantOverlayState extends ConsumerState<PromptAssistantOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _streamSub;
  late final AnimationController _breathController;

  bool get _isDesktop {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  Future<void> _runTranslate() async {
    final inputText = _assistantInputText();
    await _runAction(
      context.l10n.promptAssistant_translateProcessing,
      inputText,
      (service, input) => service.translatePrompt(
        input,
        sessionId: widget.sessionId,
      ),
    );
  }

  Future<void> _runOptimize() async {
    final inputText = _assistantInputText();
    await _runAction(
      context.l10n.promptAssistant_optimizeProcessing,
      inputText,
      (service, input) => service.optimizePrompt(
        input,
        sessionId: widget.sessionId,
      ),
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
    final character =
        ref.read(reversePromptCharacterProvider.notifier).selectedCharacter;
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
          final finalText = buffer.toString();
          widget.controller.text = finalText;
          widget.controller.selection =
              TextSelection.collapsed(offset: widget.controller.text.length);
        }
        stateNotifier.finishProcessing(widget.sessionId);
        final afterText = widget.controller.text;
        ref.read(promptAssistantHistoryProvider.notifier).recordExternalChange(
              widget.sessionId,
              before: beforeText,
              after: afterText,
            );
        ref.read(promptAssistantHistoryProvider.notifier).push(
              widget.sessionId,
              afterText,
            );
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
          final finalText = buffer.toString();
          widget.controller.text = finalText;
          widget.controller.selection =
              TextSelection.collapsed(offset: widget.controller.text.length);
        }
        stateNotifier.finishProcessing(widget.sessionId);
        final afterText = widget.controller.text;
        ref.read(promptAssistantHistoryProvider.notifier).recordExternalChange(
              widget.sessionId,
              before: beforeText,
              after: afterText,
            );
        ref.read(promptAssistantHistoryProvider.notifier).push(
              widget.sessionId,
              afterText,
            );
      },
      cancelOnError: true,
    );
  }

  String _assistantInputText() {
    return ref
        .read(fixedTagsNotifierProvider)
        .stripFromPrompt(widget.controller.text);
  }

  void _undo() {
    final value = ref
        .read(promptAssistantHistoryProvider.notifier)
        .undo(widget.sessionId, widget.controller.text);
    if (value != null) {
      widget.controller.text = value;
      widget.controller.selection =
          TextSelection.collapsed(offset: value.length);
    }
  }

  void _redo() {
    final value = ref
        .read(promptAssistantHistoryProvider.notifier)
        .redo(widget.sessionId, widget.controller.text);
    if (value != null) {
      widget.controller.text = value;
      widget.controller.selection =
          TextSelection.collapsed(offset: value.length);
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
              title: Text(
                entry,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                widget.controller.text = entry;
                widget.controller.selection =
                    TextSelection.collapsed(offset: entry.length);
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
        if (value == 'cancel') {
          await ref.read(promptAssistantServiceProvider).cancelCurrentTask(
                sessionId: widget.sessionId,
              );
          ref
              .read(promptAssistantStateProvider.notifier)
              .finishProcessing(widget.sessionId);
        } else if (value != null) {
          widget.onOpenSettings?.call();
        }
      });
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(context.l10n.promptAssistant_assistantSettings),
              onTap: () {
                Navigator.pop(context);
                widget.onOpenSettings?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: Text(context.l10n.promptAssistant_serviceSettings),
              onTap: () {
                Navigator.pop(context);
                widget.onOpenSettings?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.rule),
              title: Text(context.l10n.promptAssistant_ruleSettings),
              onTap: () {
                Navigator.pop(context);
                widget.onOpenSettings?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle),
              title: Text(context.l10n.promptAssistant_cancelCurrentTask),
              onTap: () async {
                Navigator.pop(context);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(promptAssistantConfigProvider);
    if (!widget.enabled || !config.enabled) {
      return const SizedBox.shrink();
    }
    if (_isDesktop && !config.desktopOverlayEnabled) {
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

    final isExpanded = state.expanded;
    final isProcessing = state.processing;

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
      child: MouseRegion(
        onEnter: (_) => notifier.setHovering(widget.sessionId, true),
        onExit: (_) => notifier.setHovering(widget.sessionId, false),
        child: GestureDetector(
          onSecondaryTapDown: _isDesktop
              ? (details) => _showMenu(details.globalPosition)
              : null,
          child: AnimatedBuilder(
            animation: _breathController,
            builder: (context, child) {
              final breath = 0.85 + _breathController.value * 0.15;
              final glowBoost = state.hovering ? 1.35 : 1.0;
              return AnimatedScale(
                duration: const Duration(milliseconds: 140),
                scale: state.hovering ? 1.05 : 1.01,
                child: AnimatedContainer(
                  key: ValueKey<String>(
                    'prompt_assistant_toolbar_${widget.sessionId}',
                  ),
                  duration: const Duration(milliseconds: 160),
                  padding: isExpanded
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
                      : const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: state.hovering ? 0.9 : 0.82)
                        : Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(isExpanded ? 12 : 15),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(
                              alpha: isExpanded
                                  ? 0.09
                                  : (0.10 * breath * glowBoost),
                            ),
                        blurRadius: isExpanded ? 8 : (10 * breath * glowBoost),
                        spreadRadius: isExpanded ? 0 : 0.2,
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _miniButton(
                  icon: isExpanded
                      ? Icons.close_rounded
                      : Icons.auto_awesome_rounded,
                  tooltip: isExpanded
                      ? context.l10n.promptAssistant_collapseAssistant
                      : context.l10n.promptAssistant_expandAssistant,
                  onPressed: () =>
                      notifier.setExpanded(widget.sessionId, !isExpanded),
                  iconColor: isExpanded
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.78),
                  iconSize: isExpanded ? 14 : 13,
                  buttonSize: isExpanded ? 24 : 26,
                ),
                if (isExpanded) ...[
                  _miniButton(
                    icon: Icons.history,
                    tooltip: context.l10n.promptAssistant_history,
                    onPressed: _showHistory,
                  ),
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
                                .cancelCurrentTask(
                                  sessionId: widget.sessionId,
                                );
                            notifier.finishProcessing(widget.sessionId);
                          }
                        : () => _showMenu(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Positioned(
      right: 8,
      bottom: 8,
      child: child,
    );
  }

  Widget _miniButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? iconColor,
    double iconSize = 14,
    double buttonSize = 24,
  }) {
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
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: IconButton(
          constraints:
              BoxConstraints.tightFor(width: buttonSize, height: buttonSize),
          padding: EdgeInsets.zero,
          icon: Icon(icon, size: iconSize, color: iconColor),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
