import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/comfyui_prompt_parser/pipe_parser.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_prompt_formatter.dart';
import '../../../../core/utils/sd_to_nai_converter.dart';
import '../../../../data/models/character/character_prompt.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/pending_prompt_provider.dart';
import '../../../widgets/character/mobile_character_manager_sheet.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/prompt/random_mode_selector.dart';
import 'prompt_input_controller.dart';

/// Coordinates prompt commands that span providers, navigation and editors.
class PromptInputCoordinator {
  PromptInputCoordinator({
    required WidgetRef ref,
    required PromptInputController controller,
    required BuildContext Function() context,
    required bool Function() mounted,
  }) : _ref = ref,
       _controller = controller,
       _context = context,
       _mounted = mounted;

  final WidgetRef _ref;
  final PromptInputController _controller;
  final BuildContext Function() _context;
  final bool Function() _mounted;

  void consumePendingPrompt() {
    final pending = _ref.read(pendingPromptNotifierProvider);
    if (pending.prompt == null && pending.negativePrompt == null) return;

    final consumed = _ref
        .read(pendingPromptNotifierProvider.notifier)
        .consume();
    final target = consumed.targetType;
    final sourcePrompt = consumed.prompt;
    if (sourcePrompt != null && sourcePrompt.isNotEmpty) {
      final prompt = _normalize(sourcePrompt);
      switch (target) {
        case SendTargetType.smartDecompose:
          _applySmartDecompose(prompt, negativePrompt: consumed.negativePrompt);
        case SendTargetType.replaceCharacter:
          _applyToCharacterPrompt(
            prompt,
            negativePrompt: consumed.negativePrompt,
            clearExisting: true,
          );
        case SendTargetType.appendCharacter:
          _applyToCharacterPrompt(
            prompt,
            negativePrompt: consumed.negativePrompt,
            clearExisting: false,
          );
        case SendTargetType.mainPrompt:
        case SendTargetType.fixedTag:
        case null:
          applyToMainPrompt(prompt);
      }
    }

    if (target == null || target == SendTargetType.mainPrompt) {
      final sourceNegative = consumed.negativePrompt;
      if (sourceNegative != null && sourceNegative.isNotEmpty) {
        final negative = _normalize(sourceNegative);
        _controller.negativeController.text = negative;
        updateNegativePrompt(negative);
      }
    }
  }

  String _normalize(String prompt) =>
      NaiPromptFormatter.format(SdToNaiConverter.convert(prompt));

  void applyToMainPrompt(String prompt) {
    _controller.promptController.text = prompt;
    updatePrompt(prompt);
  }

  void _applyToCharacterPrompt(
    String prompt, {
    String? negativePrompt,
    required bool clearExisting,
  }) {
    final notifier = _ref.read(characterPromptNotifierProvider.notifier);
    if (clearExisting) notifier.clearAllCharacters();
    final normalizedNegative = negativePrompt == null
        ? null
        : _normalize(negativePrompt);

    if (PipeParser.isPipeFormat(prompt)) {
      final result = PipeParser.parse(prompt);
      if (result.globalPrompt.isNotEmpty) {
        notifier.addCharacter(
          _inferGender(result.globalPrompt),
          prompt: result.globalPrompt,
          negativePrompt: normalizedNegative,
        );
      }
      for (final character in result.characters) {
        if (character.prompt.isNotEmpty) {
          notifier.addCharacter(
            character.inferredGender ?? CharacterGender.other,
            prompt: character.prompt,
            negativePrompt: normalizedNegative,
          );
        }
      }
    } else {
      notifier.addCharacter(
        _inferGender(prompt),
        prompt: prompt,
        negativePrompt: normalizedNegative,
      );
    }

    if (_mounted()) {
      final context = _context();
      final message = clearExisting
          ? context.l10n.prompt_characterPromptReplaced
          : context.l10n.prompt_characterPromptAppended(
              _ref.read(characterPromptNotifierProvider).characters.length,
            );
      AppToast.success(context, message);
    }
  }

  CharacterGender _inferGender(String prompt) {
    final value = prompt.toLowerCase();
    if (value.contains('1boy') ||
        value.contains('2boys') ||
        value.contains('male')) {
      return CharacterGender.male;
    }
    if (value.contains('1girl') ||
        value.contains('2girls') ||
        value.contains('female')) {
      return CharacterGender.female;
    }
    return CharacterGender.other;
  }

  void _applySmartDecompose(String prompt, {String? negativePrompt}) {
    final result = PipeParser.parse(prompt);
    if (result.globalPrompt.isNotEmpty) applyToMainPrompt(result.globalPrompt);
    final normalizedNegative = negativePrompt == null
        ? null
        : _normalize(negativePrompt);

    final notifier = _ref.read(characterPromptNotifierProvider.notifier);
    notifier.clearAllCharacters();
    for (final character in result.characters) {
      if (character.prompt.isNotEmpty) {
        notifier.addCharacter(
          character.inferredGender ?? CharacterGender.other,
          prompt: character.prompt,
          negativePrompt: normalizedNegative,
        );
      }
    }

    if (_mounted()) {
      final context = _context();
      final count = result.characters.length;
      AppToast.success(
        context,
        count > 0
            ? context.l10n.prompt_smartDecomposedWithCharacters(count)
            : context.l10n.prompt_appliedToMainPrompt,
      );
    }
  }

  void updatePrompt(String value) {
    _ref.read(generationParamsNotifierProvider.notifier).updatePrompt(value);
  }

  void updateNegativePrompt(String value) {
    _ref
        .read(generationParamsNotifierProvider.notifier)
        .updateNegativePrompt(value);
  }

  void importComfyuiPrompt(
    String globalPrompt,
    List<CharacterPrompt> characters,
  ) {
    final notifier = _ref.read(characterPromptNotifierProvider.notifier);
    notifier.clearAll();
    notifier.replaceAll(characters);
    updatePrompt(globalPrompt);
    if (_mounted()) {
      final context = _context();
      AppToast.success(
        context,
        context.l10n.prompt_importedCharacters(characters.length),
      );
    }
  }

  void clearPrompt() {
    _controller.promptController.clear();
    updatePrompt('');
    _ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();
  }

  void clearNegativePrompt() {
    _controller.negativeController.clear();
    updateNegativePrompt('');
  }

  Future<void> generateRandomPrompt() async {
    try {
      await _ref
          .read(imageGenerationNotifierProvider.notifier)
          .generateAndApplyRandomPrompt();
      final characters = _ref
          .read(characterPromptNotifierProvider)
          .characters
          .where(
            (character) => character.enabled && character.prompt.isNotEmpty,
          )
          .length;
      if (characters > 0) _showGeneratedCharacters(characters);
    } catch (error) {
      _showRandomError(error);
    }
  }

  void _showGeneratedCharacters(int characters) {
    if (!_mounted()) return;
    final context = _context();
    AppToast.success(
      context,
      context.l10n.tagLibrary_generatedCharacters(characters.toString()),
    );
  }

  void _showRandomError(Object error) {
    if (!_mounted()) return;
    final context = _context();
    AppToast.error(
      context,
      context.l10n.tagLibrary_generateFailed(error.toString()),
    );
  }

  void showRandomModeSelector() {
    if (_mounted()) RandomModeBottomSheet.show(_context());
  }

  void openAssistantSettings() {
    if (!_mounted()) return;
    showModalBottomSheet<void>(
      context: _context(),
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final config = ref.watch(promptAssistantConfigProvider);
          final notifier = ref.read(promptAssistantConfigProvider.notifier);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(context.l10n.promptAssistant_enableAssistant),
                  value: config.enabled,
                  onChanged: notifier.setEnabled,
                ),
                SwitchListTile(
                  title: Text(context.l10n.promptAssistant_desktopOverlay),
                  value: config.desktopOverlayEnabled,
                  onChanged: notifier.setDesktopOverlayEnabled,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> showMobileCharacterManager() async {
    if (!_mounted()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _ref.read(selectedCharacterIdProvider.notifier).clear();
    await showModalBottomSheet<void>(
      context: _context(),
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MobileCharacterManagerSheet(),
    );
    if (_mounted()) _ref.read(selectedCharacterIdProvider.notifier).clear();
  }
}
