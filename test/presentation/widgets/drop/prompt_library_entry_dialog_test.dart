import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/presentation/widgets/drop/prompt_library_entry_dialog.dart';

void main() {
  test('append keeps both existing and selected text byte-for-byte', () {
    const existing = 'alpha, beta  ';
    const snippet = '\n  [artist:foo], {weighted}  ';

    expect(
      appendPromptSnippet(existing, snippet, PromptAppendSeparator.none),
      '$existing$snippet',
    );
    expect(
      appendPromptSnippet(existing, snippet, PromptAppendSeparator.newline),
      '$existing\n$snippet',
    );
  });

  test('short single fragment is suggested only as a name', () {
    expect(
      suggestedPromptLibraryName('  artist:foo  ', 'Prompt snippet'),
      'artist:foo',
    );
    expect(
      suggestedPromptLibraryName('artist:foo, watercolor', 'Prompt snippet'),
      'Prompt snippet',
    );
  });

  test('available name lookup is case insensitive', () {
    final entries = [
      TagLibraryEntry.create(name: 'Prompt snippet', content: 'one'),
      TagLibraryEntry.create(name: 'prompt snippet 2', content: 'two'),
    ];

    expect(
      availablePromptLibraryName('Prompt snippet', entries),
      'Prompt snippet 3',
    );
    expect(
      availablePromptLibraryName('  Prompt snippet  ', entries),
      'Prompt snippet 3',
    );
  });

  test('entry factory can preserve selected prompt whitespace exactly', () {
    const selected = '  [artist:foo],\n1.2::watercolor::  ';

    final preserved = TagLibraryEntry.create(
      name: 'Example',
      content: selected,
      preserveContentWhitespace: true,
    );
    final legacy = TagLibraryEntry.create(name: 'Example', content: selected);

    expect(preserved.content, selected);
    expect(legacy.content, selected.trim());
  });
}
