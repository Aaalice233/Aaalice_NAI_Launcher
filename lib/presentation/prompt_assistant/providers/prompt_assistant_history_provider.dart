import 'package:flutter_riverpod/flutter_riverpod.dart';

class PromptHistorySessionIds {
  const PromptHistorySessionIds._();

  static const String generationPrompt = 'generation_prompt_main';
  static const String generationNegative = 'generation_prompt_negative';

  static String characterPrompt(String characterId) =>
      'generation_character_${characterId}_prompt';

  static String characterNegative(String characterId) =>
      'generation_character_${characterId}_negative';

  static String fixedTag(String entryId) => 'fixed_tag_${entryId}_prompt';

  static String tagLibraryEntry(String entryId) =>
      'tag_library_${entryId}_prompt';
}

class PromptHistoryStack {
  final List<String> undoStack;
  final List<String> redoStack;
  final List<String> externalUndoStack;
  final List<String> externalRedoStack;
  final String? externalCurrentText;
  final List<String> history;

  const PromptHistoryStack({
    this.undoStack = const [],
    this.redoStack = const [],
    this.externalUndoStack = const [],
    this.externalRedoStack = const [],
    this.externalCurrentText,
    this.history = const [],
  });

  PromptHistoryStack copyWith({
    List<String>? undoStack,
    List<String>? redoStack,
    List<String>? externalUndoStack,
    List<String>? externalRedoStack,
    String? externalCurrentText,
    List<String>? history,
  }) {
    return PromptHistoryStack(
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      externalUndoStack: externalUndoStack ?? this.externalUndoStack,
      externalRedoStack: externalRedoStack ?? this.externalRedoStack,
      externalCurrentText: externalCurrentText ?? this.externalCurrentText,
      history: history ?? this.history,
    );
  }

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  bool get canUndoExternal => externalUndoStack.isNotEmpty;
  bool get canRedoExternal => externalRedoStack.isNotEmpty;
}

final promptAssistantHistoryProvider = StateNotifierProvider<
    PromptAssistantHistoryNotifier, Map<String, PromptHistoryStack>>(
  (ref) => PromptAssistantHistoryNotifier(),
);

class PromptAssistantHistoryNotifier
    extends StateNotifier<Map<String, PromptHistoryStack>> {
  PromptAssistantHistoryNotifier() : super(const {});

  PromptHistoryStack stackOf(String sessionId) {
    return state[sessionId] ?? const PromptHistoryStack();
  }

  void _put(String sessionId, PromptHistoryStack stack) {
    state = {...state, sessionId: stack};
  }

  void push(String sessionId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final stack = stackOf(sessionId);
    final undo = [...stack.undoStack];
    if (undo.isNotEmpty && undo.last == text) return;
    undo.add(text);
    if (undo.length > 50) {
      undo.removeAt(0);
    }

    final history = [...stack.history];
    if (history.isEmpty || history.last != text) {
      history.add(text);
      if (history.length > 50) {
        history.removeAt(0);
      }
    }

    _put(
      sessionId,
      stack.copyWith(
        undoStack: undo,
        redoStack: const [],
        history: history,
      ),
    );
  }

  void recordExternalChange(
    String sessionId, {
    required String before,
    required String after,
  }) {
    if (before == after || after.trim().isEmpty) return;
    final stack = stackOf(sessionId);
    final undo = [...stack.externalUndoStack];
    if (undo.isEmpty || undo.last != before) {
      undo.add(before);
    }
    if (undo.length > 100) {
      undo.removeRange(0, undo.length - 100);
    }

    final history = [...stack.history];
    if (history.isEmpty || history.last != after) {
      history.add(after);
      if (history.length > 50) {
        history.removeAt(0);
      }
    }

    _put(
      sessionId,
      stack.copyWith(
        externalUndoStack: undo,
        externalRedoStack: const [],
        externalCurrentText: after,
        history: history,
      ),
    );
  }

  String? undoExternal(String sessionId, String currentText) {
    final stack = stackOf(sessionId);
    if (stack.externalUndoStack.isEmpty) return null;
    if (stack.externalCurrentText != currentText) return null;
    final undo = [...stack.externalUndoStack];
    final redo = [...stack.externalRedoStack];

    redo.add(currentText);
    final value = undo.removeLast();
    _put(
      sessionId,
      stack.copyWith(
        externalUndoStack: undo,
        externalRedoStack: redo,
        externalCurrentText: value,
      ),
    );
    return value;
  }

  String? redoExternal(String sessionId, String currentText) {
    final stack = stackOf(sessionId);
    if (stack.externalRedoStack.isEmpty) return null;
    if (stack.externalCurrentText != currentText) return null;
    final undo = [...stack.externalUndoStack, currentText];
    final redo = [...stack.externalRedoStack];
    final value = redo.removeLast();
    _put(
      sessionId,
      stack.copyWith(
        externalUndoStack: undo,
        externalRedoStack: redo,
        externalCurrentText: value,
      ),
    );
    return value;
  }

  String? undo(String sessionId, String currentText) {
    final stack = stackOf(sessionId);
    if (stack.undoStack.isEmpty) return null;
    final undo = [...stack.undoStack];
    final redo = [...stack.redoStack];

    if (undo.isNotEmpty && undo.last == currentText) {
      redo.add(undo.removeLast());
    } else {
      redo.add(currentText);
    }

    if (undo.isEmpty) {
      _put(sessionId, stack.copyWith(undoStack: undo, redoStack: redo));
      return null;
    }

    final value = undo.removeLast();
    _put(sessionId, stack.copyWith(undoStack: undo, redoStack: redo));
    return value;
  }

  String? redo(String sessionId, String currentText) {
    final stack = stackOf(sessionId);
    if (stack.redoStack.isEmpty) return null;
    final undo = [...stack.undoStack, currentText];
    final redo = [...stack.redoStack];
    final value = redo.removeLast();
    _put(sessionId, stack.copyWith(undoStack: undo, redoStack: redo));
    return value;
  }
}
