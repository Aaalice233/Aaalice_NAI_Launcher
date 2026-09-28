import 'package:flutter/material.dart';

import '../../../../core/utils/nai_prompt_parser.dart';
import '../../../widgets/prompt/nai_syntax_controller.dart';

/// Owns the long-lived editor objects used by [PromptInputWidget].
///
/// Keeping these objects outside the view widgets preserves controller identity
/// when the responsive layout or prompt type changes.
class PromptInputController extends ChangeNotifier {
  PromptInputController({
    required String prompt,
    required String negativePrompt,
    ValueNotifier<bool>? negativeModeNotifier,
  }) : promptController = NaiSyntaxController(text: prompt),
       negativeController = NaiSyntaxController(text: negativePrompt),
       promptFocusNode = FocusNode(),
       negativeFocusNode = FocusNode(),
       _negativeModeNotifier = negativeModeNotifier,
       _isNegativeMode = negativeModeNotifier?.value ?? false {
    promptFocusNode.addListener(_notifyFocusChanged);
    negativeFocusNode.addListener(_notifyFocusChanged);
    _negativeModeNotifier?.addListener(_onExternalNegativeModeChanged);
  }

  final NaiSyntaxController promptController;
  final NaiSyntaxController negativeController;
  final FocusNode promptFocusNode;
  final FocusNode negativeFocusNode;

  ValueNotifier<bool>? _negativeModeNotifier;
  bool _isNegativeMode;

  bool get isNegativeMode => _isNegativeMode;

  void bindNegativeModeNotifier(ValueNotifier<bool>? notifier) {
    if (identical(notifier, _negativeModeNotifier)) return;
    _negativeModeNotifier?.removeListener(_onExternalNegativeModeChanged);
    _negativeModeNotifier = notifier;
    _negativeModeNotifier?.addListener(_onExternalNegativeModeChanged);
    final next = notifier?.value;
    if (next != null && next != _isNegativeMode) {
      _isNegativeMode = next;
      notifyListeners();
    }
  }

  void setNegativeMode(bool value) {
    if (value == _isNegativeMode) return;
    _isNegativeMode = value;
    if (_negativeModeNotifier?.value != value) {
      _negativeModeNotifier?.value = value;
    }
    notifyListeners();
  }

  void syncPrompt(String prompt) {
    if (promptController.text != prompt) promptController.text = prompt;
  }

  void syncNegativePrompt(String prompt) {
    if (negativeController.text != prompt) negativeController.text = prompt;
  }

  void configureHighlighting({
    required bool enabled,
    required bool numericEmphasisEnabled,
  }) {
    promptController.highlightEnabled = enabled;
    negativeController.highlightEnabled = enabled;
    promptController.numericEmphasisEnabled = numericEmphasisEnabled;
    negativeController.numericEmphasisEnabled = numericEmphasisEnabled;
  }

  int get promptCount => _tagCount(promptController.text);
  int get negativePromptCount => _tagCount(negativeController.text);

  static int _tagCount(String value) =>
      NaiPromptParser.splitSegments(value).length;

  void _notifyFocusChanged() => notifyListeners();

  void _onExternalNegativeModeChanged() {
    final value = _negativeModeNotifier?.value;
    if (value == null || value == _isNegativeMode) return;
    _isNegativeMode = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _negativeModeNotifier?.removeListener(_onExternalNegativeModeChanged);
    promptFocusNode.removeListener(_notifyFocusChanged);
    negativeFocusNode.removeListener(_notifyFocusChanged);
    promptController.dispose();
    negativeController.dispose();
    promptFocusNode.dispose();
    negativeFocusNode.dispose();
    super.dispose();
  }
}
