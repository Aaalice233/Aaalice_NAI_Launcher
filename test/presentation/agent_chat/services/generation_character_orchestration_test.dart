import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/model_capabilities.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_character_orchestration.dart';

void main() {
  group('GenerationCharacterOrchestrator', () {
    test('uses current V4/V4.5/V5 official character limits', () {
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV4Curated,
        ).maxCharacters,
        6,
      );
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV45Curated,
        ).maxCharacters,
        6,
      );
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV5Curated,
        ).maxCharacters,
        22,
      );
    });

    test('defaults multiple positionless characters to NovelAI AI layout', () {
      final snapshot = GenerationCharacterOrchestrator.normalizeExplicit(
        model: ImageModels.animeDiffusionV5Curated,
        rawLayoutMode: null,
        rawCharacters: const [
          {'prompt': 'hero'},
          {'prompt': 'companion'},
        ],
      );

      expect(snapshot.layoutMode, GenerationCharacterLayoutMode.aiChoice);
      expect(snapshot.useCoords, isFalse);
      expect(snapshot.characters.first.positionX, isNull);
      expect(snapshot.characters.first.positionY, isNull);
      expect(snapshot.characters.last.positionX, isNull);
      expect(snapshot.characters.last.positionY, isNull);
    });

    test('normalizes complete explicit manual positions', () {
      final snapshot = GenerationCharacterOrchestrator.normalizeExplicit(
        model: ImageModels.animeDiffusionV5Curated,
        rawLayoutMode: 'custom',
        rawCharacters: const [
          {'prompt': 'hero', 'position': 'B3'},
          {'prompt': 'companion', 'position_x': 0.8, 'position_y': 0.25},
        ],
      );

      expect(snapshot.useCoords, isTrue);
      expect(snapshot.characters.first.positionX, 0.3);
      expect(snapshot.characters.first.positionY, 0.5);
      expect(snapshot.characters.last.positionX, 0.8);
      expect(snapshot.characters.last.positionY, 0.25);
    });

    test('custom layout never invents missing character coordinates', () {
      expect(
        () => GenerationCharacterOrchestrator.normalizeExplicit(
          model: ImageModels.animeDiffusionV5Curated,
          rawLayoutMode: 'custom',
          rawCharacters: const [
            {'prompt': 'hero', 'position_x': 0.2, 'position_y': 0.5},
            {'prompt': 'companion'},
          ],
        ),
        throwsA(
          isA<GenerationCharacterValidationException>().having(
            (error) => error.code,
            'code',
            'missing_character_coordinates',
          ),
        ),
      );
    });

    test('AI layout rejects coordinates instead of silently ignoring them', () {
      expect(
        () => GenerationCharacterOrchestrator.normalizeExplicit(
          model: ImageModels.animeDiffusionV5Curated,
          rawLayoutMode: 'ai_choice',
          rawCharacters: const [
            {'prompt': 'hero', 'position_x': 0.25, 'position_y': 0.75},
          ],
        ),
        throwsA(
          isA<GenerationCharacterValidationException>().having(
            (error) => error.code,
            'code',
            'character_layout_conflict',
          ),
        ),
      );
    });

    test('rejects partial, non-finite, empty, and over-limit roles', () {
      expect(
        () => GenerationCharacterOrchestrator.normalizeExplicit(
          model: ImageModels.animeDiffusionV5Curated,
          rawLayoutMode: 'custom',
          rawCharacters: const [
            {'prompt': 'hero', 'position_x': 0.5},
          ],
        ),
        throwsA(
          isA<GenerationCharacterValidationException>().having(
            (error) => error.code,
            'code',
            'partial_character_coordinates',
          ),
        ),
      );
      expect(
        () => GenerationCharacterOrchestrator.normalizeExplicit(
          model: ImageModels.animeDiffusionV5Curated,
          rawLayoutMode: 'custom',
          rawCharacters: [
            {'prompt': 'hero', 'position_x': double.nan, 'position_y': 0.5},
          ],
        ),
        throwsA(
          isA<GenerationCharacterValidationException>().having(
            (error) => error.code,
            'code',
            'invalid_character_coordinate',
          ),
        ),
      );
      expect(
        () => GenerationCharacterOrchestrator.normalizeExplicit(
          model: ImageModels.animeDiffusionV5Curated,
          rawLayoutMode: 'ai_choice',
          rawCharacters: const [
            {'prompt': '   '},
          ],
        ),
        throwsA(
          isA<GenerationCharacterValidationException>().having(
            (error) => error.code,
            'code',
            'invalid_character_prompt',
          ),
        ),
      );
      expect(
        () => GenerationCharacterOrchestrator.normalizeExplicit(
          model: ImageModels.animeDiffusionV5Curated,
          rawLayoutMode: 'ai_choice',
          rawCharacters: List.generate(
            23,
            (index) => {'prompt': 'role $index'},
          ),
        ),
        throwsA(
          isA<GenerationCharacterValidationException>().having(
            (error) => error.code,
            'code',
            'model_character_limit',
          ),
        ),
      );
    });
  });
}
