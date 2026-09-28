import '../../../core/constants/model_capabilities.dart';
import '../../../data/models/image/image_params.dart';

enum GenerationCharacterLayoutMode { aiChoice, custom }

extension GenerationCharacterLayoutModeName on GenerationCharacterLayoutMode {
  String get schemaName => switch (this) {
    GenerationCharacterLayoutMode.aiChoice => 'ai_choice',
    GenerationCharacterLayoutMode.custom => 'custom',
  };
}

class GenerationCharacterSnapshot {
  const GenerationCharacterSnapshot({
    required this.characters,
    required this.layoutMode,
  });

  final List<CharacterPrompt> characters;
  final GenerationCharacterLayoutMode layoutMode;

  bool get useCoords =>
      characters.isNotEmpty &&
      layoutMode == GenerationCharacterLayoutMode.custom;
}

class GenerationCharacterValidationException implements Exception {
  const GenerationCharacterValidationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

abstract final class GenerationCharacterOrchestrator {
  static GenerationCharacterSnapshot normalizeExplicit({
    required Object? rawCharacters,
    required Object? rawLayoutMode,
    required String model,
  }) {
    if (rawCharacters is! List) {
      throw const GenerationCharacterValidationException(
        'invalid_characters',
        'Parameter "characters" must be an array.',
      );
    }

    final capabilities = ModelCapabilityRegistry.of(model);
    if (rawCharacters.isNotEmpty && capabilities.maxCharacters == 0) {
      throw GenerationCharacterValidationException(
        'model_character_unsupported',
        'Model $model does not support character prompts.',
      );
    }
    if (rawCharacters.length > capabilities.maxCharacters) {
      throw GenerationCharacterValidationException(
        'model_character_limit',
        'Model $model supports at most ${capabilities.maxCharacters} '
            'characters; ${rawCharacters.length} were provided.',
      );
    }

    final parsed = <_ParsedCharacter>[];
    var hasManualPosition = false;
    for (var index = 0; index < rawCharacters.length; index++) {
      final value = rawCharacters[index];
      if (value is! Map) {
        throw GenerationCharacterValidationException(
          'invalid_character',
          'Character ${index + 1} must be an object.',
        );
      }
      final promptValue = value['prompt'];
      if (promptValue is! String || promptValue.trim().isEmpty) {
        throw GenerationCharacterValidationException(
          'invalid_character_prompt',
          'Character ${index + 1} requires a non-empty prompt.',
        );
      }
      final negativeValue = value['negative_prompt'];
      if (negativeValue != null && negativeValue is! String) {
        throw GenerationCharacterValidationException(
          'invalid_character_negative_prompt',
          'Character ${index + 1} negative_prompt must be a string.',
        );
      }

      final hasX = value.containsKey('position_x');
      final hasY = value.containsKey('position_y');
      if (hasX != hasY) {
        throw GenerationCharacterValidationException(
          'partial_character_coordinates',
          'Character ${index + 1} must provide position_x and position_y '
              'together.',
        );
      }
      final gridValue = value['position'];
      if (gridValue != null && gridValue is! String) {
        throw GenerationCharacterValidationException(
          'invalid_character_position',
          'Character ${index + 1} position must be an A1-E5 grid string.',
        );
      }
      if (gridValue != null && hasX) {
        throw GenerationCharacterValidationException(
          'character_position_conflict',
          'Character ${index + 1} cannot combine position with continuous '
              'coordinates.',
        );
      }

      double? x;
      double? y;
      if (hasX) {
        x = _coordinate(value['position_x'], index: index, axis: 'x');
        y = _coordinate(value['position_y'], index: index, axis: 'y');
        hasManualPosition = true;
      } else if (gridValue != null) {
        final grid = _parseLegacyGrid(gridValue, index);
        x = grid.x;
        y = grid.y;
        hasManualPosition = true;
      }
      parsed.add(
        _ParsedCharacter(
          prompt: promptValue.trim(),
          negativePrompt: (negativeValue as String?)?.trim() ?? '',
          x: x,
          y: y,
        ),
      );
    }

    final layoutMode = _parseLayoutMode(
      rawLayoutMode,
      inferredCustom: hasManualPosition,
    );
    if (layoutMode == GenerationCharacterLayoutMode.aiChoice &&
        hasManualPosition) {
      throw const GenerationCharacterValidationException(
        'character_layout_conflict',
        'AI layout cannot include position, position_x, or position_y.',
      );
    }

    if (layoutMode == GenerationCharacterLayoutMode.custom) {
      final missingPosition = parsed.indexWhere(
        (character) => character.x == null || character.y == null,
      );
      if (missingPosition >= 0) {
        throw GenerationCharacterValidationException(
          'missing_character_coordinates',
          'Character ${missingPosition + 1} requires both position_x and '
              'position_y in custom layout.',
        );
      }
    }

    return GenerationCharacterSnapshot(
      layoutMode: layoutMode,
      characters: [
        for (final character in parsed)
          CharacterPrompt(
            prompt: character.prompt,
            negativePrompt: character.negativePrompt,
            positionX: layoutMode == GenerationCharacterLayoutMode.custom
                ? character.x
                : null,
            positionY: layoutMode == GenerationCharacterLayoutMode.custom
                ? character.y
                : null,
          ),
      ],
    );
  }

  static GenerationCharacterLayoutMode _parseLayoutMode(
    Object? value, {
    required bool inferredCustom,
  }) {
    if (value == null) {
      return inferredCustom
          ? GenerationCharacterLayoutMode.custom
          : GenerationCharacterLayoutMode.aiChoice;
    }
    return switch (value) {
      'ai_choice' => GenerationCharacterLayoutMode.aiChoice,
      'custom' => GenerationCharacterLayoutMode.custom,
      _ => throw const GenerationCharacterValidationException(
        'invalid_character_layout_mode',
        'character_layout_mode must be "ai_choice" or "custom".',
      ),
    };
  }

  static double _coordinate(
    Object? value, {
    required int index,
    required String axis,
  }) {
    if (value is! num) {
      throw GenerationCharacterValidationException(
        'invalid_character_coordinate',
        'Character ${index + 1} position_$axis must be a finite number '
            'between 0 and 1.',
      );
    }
    final coordinate = value.toDouble();
    if (!coordinate.isFinite || coordinate < 0 || coordinate > 1) {
      throw GenerationCharacterValidationException(
        'invalid_character_coordinate',
        'Character ${index + 1} position_$axis must be a finite number '
            'between 0 and 1.',
      );
    }
    return coordinate;
  }

  static ({double x, double y}) _parseLegacyGrid(String value, int index) {
    final normalized = value.trim().toUpperCase();
    final match = RegExp(r'^([A-E])([1-5])$').firstMatch(normalized);
    if (match == null) {
      throw GenerationCharacterValidationException(
        'invalid_character_position',
        'Character ${index + 1} position must be a valid A1-E5 grid value.',
      );
    }
    final column = match.group(1)!.codeUnitAt(0) - 'A'.codeUnitAt(0);
    final row = int.parse(match.group(2)!) - 1;
    // The legacy selector denotes cells, while the API consumes their centers.
    return (x: (column + 0.5) / 5, y: (row + 0.5) / 5);
  }
}

class _ParsedCharacter {
  const _ParsedCharacter({
    required this.prompt,
    required this.negativePrompt,
    this.x,
    this.y,
  });

  final String prompt;
  final String negativePrompt;
  final double? x;
  final double? y;
}
