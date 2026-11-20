import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/prompt_token_parser.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/presentation/providers/alias_resolver_service.dart';
import 'package:nai_launcher/presentation/providers/autocomplete_services_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';

void main() {
  test(
    'partial aliases rank both spellings and insert the original name',
    () async {
      final container = ProviderContainer(
        overrides: [
          tagLibraryPageNotifierProvider.overrideWith(_SeededTagLibrary.new),
        ],
      );
      addTearDown(container.dispose);
      const text = '<long_hair';
      final query = PromptTokenParser.parse(
        text: text,
        cursorPosition: text.length,
        limit: 15,
        locale: 'en',
      );
      final candidates = await container
          .read(tagLibraryCompletionSourceProvider)
          .search(query);

      expect(candidates.map((candidate) => candidate.canonicalTag), [
        'Long Hair',
        'Long Hair Extras',
        'Preset Long Hair',
        'By content',
        'By tag',
      ]);
      expect(candidates.map((candidate) => candidate.matchKind), [
        CompletionMatchKind.aliasExact,
        CompletionMatchKind.aliasPrefix,
        CompletionMatchKind.fullText,
        CompletionMatchKind.fullText,
        CompletionMatchKind.fullText,
      ]);

      final applied = PromptTokenParser.apply(
        text: text,
        query: query,
        canonicalTag: candidates.first.canonicalTag,
        autoInsertComma: false,
        replaceUnderscores: true,
      );
      final resolver = container.read(aliasResolverServiceProvider.notifier);
      expect(applied.text, '<Long Hair>');
      expect(resolver.resolveAliases(applied.text), 'exact content');
      expect(resolver.findEntryByName('long_hair'), isNull);
    },
  );
}

class _SeededTagLibrary extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() {
    final created = DateTime.utc(2026);
    TagLibraryEntry entry(
      String name,
      String content, {
      List<String> tags = const [],
    }) => TagLibraryEntry(
      id: name,
      name: name,
      content: content,
      tags: tags,
      createdAt: created,
      updatedAt: created,
    );
    return TagLibraryPageState(
      entries: [
        entry('By tag', 'portrait', tags: ['long hair']),
        entry('By content', 'long hair'),
        entry('Preset Long Hair', 'contains content'),
        entry('Long Hair Extras', 'prefix content'),
        entry('Long Hair', 'exact content'),
        entry('Short Hair', 'other content'),
      ],
    );
  }
}
