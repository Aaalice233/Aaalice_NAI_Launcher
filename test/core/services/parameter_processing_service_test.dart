import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/parameter_processing_service.dart';
import 'package:nai_launcher/core/utils/alias_parser.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';

void main() {
  group('ParameterProcessingService', () {
    group('constructor', () {
      test('should create with default empty lists', () {
        final service = ParameterProcessingService();

        expect(service.tagLibraryEntries, isEmpty);
        expect(service.fixedTags, isEmpty);
      });

      test('should create with provided tag library entries', () {
        final entries = [
          TagLibraryEntry.create(name: 'test1', content: 'content1'),
          TagLibraryEntry.create(name: 'test2', content: 'content2'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        expect(service.tagLibraryEntries.length, equals(2));
      });

      test('should create with provided fixed tags', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'prefix1',
            content: 'prefix content',
            position: FixedTagPosition.prefix,
          ),
          FixedTagEntry.create(
            name: 'suffix1',
            content: 'suffix content',
            position: FixedTagPosition.suffix,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        expect(service.fixedTags.length, equals(2));
      });

      test('should create with both tag libraries and fixed tags', () {
        final entries = [TagLibraryEntry.create(name: 'test', content: 'content')];
        final fixedTags = [FixedTagEntry.create(name: 'fixed', content: 'fixed content')];

        final service = ParameterProcessingService(
          tagLibraryEntries: entries,
          fixedTags: fixedTags,
        );

        expect(service.tagLibraryEntries.length, equals(1));
        expect(service.fixedTags.length, equals(1));
      });
    });

    group('process - basic', () {
      test('should return unprocessed result when both flags are false', () {
        final service = ParameterProcessingService();
        const prompt = 'test prompt';
        const negativePrompt = 'negative prompt';

        final result = service.process(
          prompt: prompt,
          negativePrompt: negativePrompt,
          resolveAliases: false,
          applyFixedTags: false,
        );

        expect(result.prompt, equals(prompt));
        expect(result.negativePrompt, equals(negativePrompt));
        expect(result.aliasesResolved, isFalse);
        expect(result.fixedTagsApplied, isFalse);
        expect(result.fixedTagsCount, equals(0));
      });

      test('should process with default flags (both true)', () {
        final service = ParameterProcessingService();

        final result = service.process(
          prompt: 'simple prompt',
          negativePrompt: 'simple negative',
        );

        expect(result.prompt, equals('simple prompt'));
        expect(result.negativePrompt, equals('simple negative'));
      });

      test('should handle empty prompts', () {
        final service = ParameterProcessingService();

        final result = service.process(
          prompt: '',
          negativePrompt: '',
        );

        expect(result.prompt, equals(''));
        expect(result.negativePrompt, equals(''));
      });
    });

    group('process - alias resolution', () {
      test('should resolve simple alias in prompt', () {
        final entries = [
          TagLibraryEntry.create(name: 'character', content: 'girl, beautiful'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        final result = service.process(
          prompt: '1girl, <character>, standing',
          negativePrompt: 'simple',
        );

        expect(result.prompt, equals('1girl, girl, beautiful, standing'));
        expect(result.aliasesResolved, isTrue);
      });

      test('should resolve alias in negative prompt', () {
        final entries = [
          TagLibraryEntry.create(name: 'badhands', content: 'bad hands, extra fingers'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        final result = service.process(
          prompt: 'simple',
          negativePrompt: '<badhands>, blurry',
        );

        expect(result.negativePrompt, equals('bad hands, extra fingers, blurry'));
        expect(result.aliasesResolved, isTrue);
      });

      test('should resolve multiple aliases', () {
        final entries = [
          TagLibraryEntry.create(name: 'hair', content: 'long hair'),
          TagLibraryEntry.create(name: 'eyes', content: 'blue eyes'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        final result = service.process(
          prompt: '<hair>, <eyes>, smiling',
          negativePrompt: 'simple',
        );

        expect(result.prompt, equals('long hair, blue eyes, smiling'));
      });

      test('should resolve aliases with case insensitive matching', () {
        final entries = [
          TagLibraryEntry.create(name: 'Character', content: 'female character'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        final result = service.process(
          prompt: '<character>',
          negativePrompt: '',
        );

        expect(result.prompt, equals('female character'));
      });

      test('should not resolve unknown aliases', () {
        final service = ParameterProcessingService();

        final result = service.process(
          prompt: '<unknown>, test',
          negativePrompt: '',
        );

        // Unknown alias should remain as-is in the text
        expect(result.prompt, equals('<unknown>, test'));
        // Since no aliases were actually resolved, aliasesResolved is false
        expect(result.aliasesResolved, isFalse);
      });

      test('should skip alias resolution when resolveAliases is false', () {
        final entries = [
          TagLibraryEntry.create(name: 'test', content: 'resolved'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        final result = service.process(
          prompt: '<test>',
          negativePrompt: '',
          resolveAliases: false,
        );

        expect(result.prompt, equals('<test>'));
        expect(result.aliasesResolved, isFalse);
      });

      test('should resolve random alias', () {
        final entries = [
          TagLibraryEntry.create(name: 'optionA', content: 'content A'),
          TagLibraryEntry.create(name: 'optionB', content: 'content B'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        final result = service.process(
          prompt: '<random:optionA,optionB>',
          negativePrompt: '',
        );

        // Random should resolve to one of the valid entries
        expect(result.aliasesResolved, isTrue);
        expect(
          result.prompt == 'content A' || result.prompt == 'content B',
          isTrue,
        );
      });

      test('should resolve weighted alias', () {
        final entries = [
          TagLibraryEntry.create(name: 'weightedA', content: 'content A'),
          TagLibraryEntry.create(name: 'weightedB', content: 'content B'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        final result = service.process(
          prompt: '<weighted:weightedA:2,weightedB:1>',
          negativePrompt: '',
        );

        // Weighted random should resolve to one of the entries
        expect(result.aliasesResolved, isTrue);
        expect(
          result.prompt == 'content A' || result.prompt == 'content B',
          isTrue,
        );
      });
    });

    group('process - fixed tags', () {
      test('should apply enabled prefix fixed tags', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'quality',
            content: 'masterpiece, best quality',
            position: FixedTagPosition.prefix,
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final result = service.process(
          prompt: '1girl',
          negativePrompt: '',
        );

        expect(result.prompt, equals('masterpiece, best quality, 1girl'));
        expect(result.fixedTagsApplied, isTrue);
        expect(result.fixedTagsCount, equals(1));
      });

      test('should apply enabled suffix fixed tags', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'details',
            content: 'detailed background',
            position: FixedTagPosition.suffix,
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final result = service.process(
          prompt: '1girl',
          negativePrompt: '',
        );

        expect(result.prompt, equals('1girl, detailed background'));
      });

      test('should apply both prefix and suffix fixed tags', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'quality',
            content: 'masterpiece',
            position: FixedTagPosition.prefix,
            enabled: true,
          ),
          FixedTagEntry.create(
            name: 'details',
            content: 'detailed',
            position: FixedTagPosition.suffix,
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final result = service.process(
          prompt: 'girl',
          negativePrompt: '',
        );

        expect(result.prompt, equals('masterpiece, girl, detailed'));
      });

      test('should not apply disabled fixed tags', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'disabled',
            content: 'disabled content',
            position: FixedTagPosition.prefix,
            enabled: false,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final result = service.process(
          prompt: 'test',
          negativePrompt: '',
        );

        expect(result.prompt, equals('test'));
        expect(result.fixedTagsApplied, isFalse);
        expect(result.fixedTagsCount, equals(0));
      });

      test('should apply fixed tags in sort order', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'third',
            content: 'third',
            position: FixedTagPosition.prefix,
            enabled: true,
          ).copyWith(sortOrder: 2),
          FixedTagEntry.create(
            name: 'first',
            content: 'first',
            position: FixedTagPosition.prefix,
            enabled: true,
          ).copyWith(sortOrder: 0),
          FixedTagEntry.create(
            name: 'second',
            content: 'second',
            position: FixedTagPosition.prefix,
            enabled: true,
          ).copyWith(sortOrder: 1),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final result = service.process(
          prompt: 'test',
          negativePrompt: '',
        );

        expect(result.prompt, equals('first, second, third, test'));
      });

      test('should apply weight to fixed tags', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'emphasized',
            content: 'masterpiece',
            position: FixedTagPosition.prefix,
            weight: 1.2,
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final result = service.process(
          prompt: 'test',
          negativePrompt: '',
        );

        // Weight 1.2 should add braces
        expect(result.prompt.contains('{masterpiece}'), isTrue);
      });

      test('should skip fixed tags application when applyFixedTags is false', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'quality',
            content: 'masterpiece',
            position: FixedTagPosition.prefix,
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final result = service.process(
          prompt: 'test',
          negativePrompt: '',
          applyFixedTags: false,
        );

        expect(result.prompt, equals('test'));
        expect(result.fixedTagsApplied, isFalse);
      });

      test('should not modify result when user prompt is empty', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'prefix',
            content: 'prefix',
            position: FixedTagPosition.prefix,
            enabled: true,
          ),
          FixedTagEntry.create(
            name: 'suffix',
            content: 'suffix',
            position: FixedTagPosition.suffix,
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final result = service.process(
          prompt: '',
          negativePrompt: '',
        );

        // Should still include fixed tags even if user prompt is empty
        expect(result.prompt, equals('prefix, suffix'));
      });
    });

    group('process - combined operations', () {
      test('should resolve aliases then apply fixed tags', () {
        final entries = [
          TagLibraryEntry.create(name: 'char', content: 'beautiful girl'),
        ];
        final fixedTags = [
          FixedTagEntry.create(
            name: 'quality',
            content: 'masterpiece',
            position: FixedTagPosition.prefix,
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(
          tagLibraryEntries: entries,
          fixedTags: fixedTags,
        );

        final result = service.process(
          prompt: '<char>, standing',
          negativePrompt: '',
        );

        expect(result.prompt, equals('masterpiece, beautiful girl, standing'));
        expect(result.aliasesResolved, isTrue);
        expect(result.fixedTagsApplied, isTrue);
      });

      test('should handle complex scenario with multiple features', () {
        final entries = [
          TagLibraryEntry.create(name: 'hair', content: 'long hair'),
          TagLibraryEntry.create(name: 'eyes', content: 'blue eyes'),
        ];
        final fixedTags = [
          FixedTagEntry.create(
            name: 'quality',
            content: 'best quality',
            position: FixedTagPosition.prefix,
            enabled: true,
          ),
          FixedTagEntry.create(
            name: 'lighting',
            content: 'cinematic lighting',
            position: FixedTagPosition.suffix,
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(
          tagLibraryEntries: entries,
          fixedTags: fixedTags,
        );

        final result = service.process(
          prompt: '1girl, <hair>, <eyes>, smiling',
          negativePrompt: 'low quality, <bad>',
        );

        expect(result.prompt, equals('best quality, 1girl, long hair, blue eyes, smiling, cinematic lighting'));
        expect(result.negativePrompt, equals('low quality, <bad>'));
      });
    });

    group('resolveAliases', () {
      test('should resolve alias using public method', () {
        final entries = [
          TagLibraryEntry.create(name: 'test', content: 'resolved content'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        final result = service.resolveAliases('prefix <test> suffix');

        expect(result, equals('prefix resolved content suffix'));
      });

      test('should return original text when no aliases found', () {
        final service = ParameterProcessingService();

        final result = service.resolveAliases('no aliases here');

        expect(result, equals('no aliases here'));
      });

      test('should handle empty text', () {
        final service = ParameterProcessingService();

        final result = service.resolveAliases('');

        expect(result, equals(''));
      });
    });

    group('applyFixedTags', () {
      test('should apply fixed tags using public method', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'prefix',
            content: 'masterpiece',
            position: FixedTagPosition.prefix,
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final result = service.applyFixedTags('1girl');

        expect(result, equals('masterpiece, 1girl'));
      });

      test('should return original when no enabled fixed tags', () {
        final service = ParameterProcessingService();

        final result = service.applyFixedTags('test');

        expect(result, equals('test'));
      });
    });

    group('isAliasValid', () {
      test('should return true for valid alias', () {
        final entries = [
          TagLibraryEntry.create(name: 'valid', content: 'content'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);
        final ref = AliasReference(
          type: AliasReferenceType.simple,
          start: 0,
          end: 8,
          rawText: '<valid>',
          entryNames: ['valid'],
        );

        expect(service.isAliasValid(ref), isTrue);
      });

      test('should return false for invalid alias', () {
        final service = ParameterProcessingService();
        final ref = AliasReference(
          type: AliasReferenceType.simple,
          start: 0,
          end: 10,
          rawText: '<invalid>',
          entryNames: ['invalid'],
        );

        expect(service.isAliasValid(ref), isFalse);
      });
    });

    group('isEntryNameValid', () {
      test('should return true for existing entry name', () {
        final entries = [
          TagLibraryEntry.create(name: 'TestEntry', content: 'content'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        expect(service.isEntryNameValid('TestEntry'), isTrue);
        expect(service.isEntryNameValid('testentry'), isTrue); // case insensitive
      });

      test('should return false for non-existing entry name', () {
        final service = ParameterProcessingService();

        expect(service.isEntryNameValid('nonexistent'), isFalse);
      });

      test('should return false for empty name', () {
        final service = ParameterProcessingService();

        expect(service.isEntryNameValid(''), isFalse);
      });
    });

    group('getStatistics', () {
      test('should return zero statistics for empty service', () {
        final service = ParameterProcessingService();

        final stats = service.getStatistics();

        expect(stats.totalCount, equals(0));
        expect(stats.enabledCount, equals(0));
        expect(stats.prefixCount, equals(0));
        expect(stats.suffixCount, equals(0));
        expect(stats.disabledCount, equals(0));
      });

      test('should return correct statistics', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'enabled_prefix',
            content: 'content',
            position: FixedTagPosition.prefix,
            enabled: true,
          ),
          FixedTagEntry.create(
            name: 'enabled_suffix',
            content: 'content',
            position: FixedTagPosition.suffix,
            enabled: true,
          ),
          FixedTagEntry.create(
            name: 'disabled',
            content: 'content',
            position: FixedTagPosition.prefix,
            enabled: false,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final stats = service.getStatistics();

        expect(stats.totalCount, equals(3));
        expect(stats.enabledCount, equals(2));
        expect(stats.prefixCount, equals(1));
        expect(stats.suffixCount, equals(1));
        expect(stats.disabledCount, equals(1));
      });

      test('should have correct toString format', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'test',
            content: 'content',
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final stats = service.getStatistics();

        expect(
          stats.toString(),
          equals('FixedTagsStatistics(total: 1, enabled: 1, prefix: 1, suffix: 0)'),
        );
      });
    });

    group('ParameterProcessingResult', () {
      test('should create result with default values', () {
        const result = ParameterProcessingResult(
          prompt: 'test',
          negativePrompt: 'negative',
        );

        expect(result.prompt, equals('test'));
        expect(result.negativePrompt, equals('negative'));
        expect(result.aliasesResolved, isFalse);
        expect(result.fixedTagsApplied, isFalse);
        expect(result.fixedTagsCount, equals(0));
      });

      test('should create result with all values', () {
        const result = ParameterProcessingResult(
          prompt: 'processed',
          negativePrompt: 'processed negative',
          aliasesResolved: true,
          fixedTagsApplied: true,
          fixedTagsCount: 2,
        );

        expect(result.prompt, equals('processed'));
        expect(result.negativePrompt, equals('processed negative'));
        expect(result.aliasesResolved, isTrue);
        expect(result.fixedTagsApplied, isTrue);
        expect(result.fixedTagsCount, equals(2));
      });

      test('should create unprocessed result using factory', () {
        final result = ParameterProcessingResult.unprocessed('prompt', 'negative');

        expect(result.prompt, equals('prompt'));
        expect(result.negativePrompt, equals('negative'));
        expect(result.aliasesResolved, isFalse);
        expect(result.fixedTagsApplied, isFalse);
        expect(result.fixedTagsCount, equals(0));
      });
    });

    group('edge cases', () {
      test('should handle aliases with special characters in content', () {
        final entries = [
          TagLibraryEntry.create(
            name: 'special',
            content: 'content with {braces} and [brackets]',
          ),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        final result = service.resolveAliases('<special>');

        expect(result, equals('content with {braces} and [brackets]'));
      });

      test('should handle overlapping alias resolution positions', () {
        final entries = [
          TagLibraryEntry.create(name: 'first', content: 'replaced first'),
          TagLibraryEntry.create(name: 'second', content: 'replaced second'),
        ];
        final service = ParameterProcessingService(tagLibraryEntries: entries);

        final result = service.resolveAliases('<first> and <second>');

        expect(result, equals('replaced first and replaced second'));
      });

      test('should handle empty content in fixed tag', () {
        final fixedTags = [
          FixedTagEntry.create(
            name: 'empty',
            content: '',
            position: FixedTagPosition.prefix,
            enabled: true,
          ),
          FixedTagEntry.create(
            name: 'valid',
            content: 'valid content',
            position: FixedTagPosition.prefix,
            enabled: true,
          ),
        ];
        final service = ParameterProcessingService(fixedTags: fixedTags);

        final result = service.applyFixedTags('test');

        expect(result, equals('valid content, test'));
      });

      test('should handle very long prompts', () {
        final service = ParameterProcessingService();
        final longPrompt = 'word, ' * 1000;

        final result = service.process(
          prompt: longPrompt,
          negativePrompt: 'negative',
        );

        expect(result.prompt.length, equals(longPrompt.length));
      });

      test('should handle multiple consecutive commas gracefully', () {
        final service = ParameterProcessingService();

        final result = service.process(
          prompt: 'test,,,value',
          negativePrompt: '',
        );

        expect(result.prompt, equals('test,,,value'));
      });
    });
  });
}
