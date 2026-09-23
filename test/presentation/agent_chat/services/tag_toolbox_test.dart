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

/// 11 组，每组两个标签：拆分后 22 项、不拆 11 项，两者都超过批量上限，
/// 所以能在不碰数据库的情况下用超限数量区分逗号语义。
List<String> _pairedTerms() => [
  for (var index = 0; index < 11; index++) 'tag${index}a, tag${index}b',
];

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

  test('search_tags exposes a bounded batch parameter', () {
    final properties =
        searchTags.parameters['properties'] as Map<String, dynamic>;
    final queries = properties['queries'] as Map<String, dynamic>;

    expect(queries['type'], 'array');
    expect((queries['items'] as Map)['type'], 'string');
    expect(queries['maxItems'], 10);
    // schema default 会被 MCP 客户端物化并注入，判定批量意图只能按是否传值。
    expect(queries.containsKey('default'), isFalse);
    expect(searchTags.parameters.containsKey('required'), isFalse);
  });

  test('search splits comma-separated terms into independent lookups', () async {
    final result = await searchTags.execute('batch', <String, dynamic>{
      'queries': _pairedTerms(),
    });

    expect(result.isError, isTrue);
    expect(result.details['code'], 'too_many_queries');
    expect(result.details['message'], contains('got 22'));
  });

  test('suggest keeps comma-separated tags as one context group', () async {
    final result = await searchTags.execute('batch', <String, dynamic>{
      'mode': 'suggest',
      'queries': _pairedTerms(),
    });

    expect(result.isError, isTrue);
    expect(result.details['code'], 'too_many_queries');
    expect(result.details['message'], contains('got 11'));
  });

  test('search_tags rejects a non-string entry in queries', () async {
    final result = await searchTags.execute('batch', const <String, dynamic>{
      'queries': ['blue_hair', 42],
    });

    expect(result.isError, isTrue);
    expect(result.details['code'], 'invalid_queries');
  });

  test('search_tags rejects queries that is not an array', () async {
    final result = await searchTags.execute('batch', const <String, dynamic>{
      'queries': 'blue_hair',
    });

    expect(result.isError, isTrue);
    expect(result.details['code'], 'invalid_queries');
  });

  test('search_tags rejects a batch with no usable term', () async {
    final result = await searchTags.execute('batch', const <String, dynamic>{
      'queries': ['  ', ' , '],
    });

    expect(result.isError, isTrue);
    expect(result.details['code'], 'missing_query');
    expect(result.details['message'], contains('queries'));
  });

  test('search_tags merges query into queries instead of dropping it', () async {
    final result = await searchTags.execute('batch', <String, dynamic>{
      'query': 'extra_tag',
      'queries': _pairedTerms(),
    });

    expect(result.details['code'], 'too_many_queries');
    expect(result.details['message'], contains('got 23'));
  });

  test('search_tags rejects an unknown mode before validating queries', () async {
    final result = await searchTags.execute('batch', const <String, dynamic>{
      'queries': 42,
      'mode': 'weird',
    });

    expect(result.details['code'], 'invalid_mode');
  });
}
