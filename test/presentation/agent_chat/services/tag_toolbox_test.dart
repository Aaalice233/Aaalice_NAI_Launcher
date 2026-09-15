import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/agent_chat/services/tag_toolbox.dart';

final _refProvider = Provider<Ref>((ref) => ref);

String _resultText(AgentToolResult result) => result.content
    .whereType<ToolResultTextContent>()
    .map((content) => content.text)
    .join();

void main() {
  late AgentTool searchTags;

  setUp(() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    searchTags = TagToolbox(container.read(_refProvider)).tools().single;
  });

  test('search_tags rejects a blank query with a coded error', () async {
    final result = await searchTags.execute('blank', const {'query': '   '});

    expect(result.isError, isTrue);
    expect(result.details, jsonDecode(_resultText(result)));
    expect(result.details['code'], 'missing_query');
  });

  test('search_tags rejects an unknown mode before reading data', () async {
    final result = await searchTags.execute('mode', const {
      'query': 'blue sky',
      'mode': 'weird',
    });

    expect(result.isError, isTrue);
    expect(result.details, jsonDecode(_resultText(result)));
    expect(result.details['code'], 'invalid_mode');
  });
}
