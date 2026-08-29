import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/agent_chat/services/online_gallery_toolbox.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late ProviderContainer container;
  late List<AgentTool> tools;

  setUp(() {
    container = ProviderContainer();
    tools = OnlineGalleryToolbox(container.read(_refProvider)).tools();
  });

  tearDown(() => container.dispose());

  AgentTool tool(String name) => tools.singleWhere((tool) => tool.name == name);

  test('browse contract defines bounded tags and random sample limit', () {
    final browse = tool('browse_online_gallery');
    final properties = browse.parameters['properties'] as Map;

    expect(browse.description, contains('at most 6 ordinary tags'));
    expect(browse.description, contains('random=true, limit=N'));
    expect(browse.description, contains('display_images'));
    expect(properties['query']['description'], contains('at most 6'));
    expect(properties['random']['description'], contains('random_feeds'));
    expect(properties['limit']['description'], contains('sample size'));
    expect(properties['limit']['minimum'], 1);
  });

  test(
    'browse rejects more than six ordinary tags before loading gallery',
    () async {
      final result = await tool('browse_online_gallery').execute('too-many', {
        'source': 'danbooru',
        'mode': 'search',
        'query': 'one two three four five six seven',
      });

      expect(result.isError, isTrue);
      expect(result.details, containsPair('code', 'too_many_query_tags'));
    },
  );

  test('source list explains tier limits and residual filtering', () async {
    final result = await tool(
      'list_online_gallery_sources',
    ).execute('list', {});
    final sources = result.details['sources'] as List;
    final danbooru = sources.cast<Map>().singleWhere(
      (source) => source['source'] == 'danbooru',
    );
    final tagSearch = danbooru['tag_search'] as Map;

    expect(tagSearch['strategy'], 'accountTierSeedResidual');
    expect(tagSearch['max_query_tags'], 6);
    expect(tagSearch['server_limits'], {
      'anonymous': 2,
      'authenticated': 2,
      'gold': 6,
      'max_query_tags_from_account_level': 31,
    });
    expect(tagSearch['residual_filtering'], contains('client'));
  });

  test('display_images remains the only explicit display contract', () {
    expect(
      tools.map((tool) => tool.name),
      isNot(contains('display_online_gallery')),
    );
    expect(
      tool('browse_online_gallery').description,
      contains('never displays'),
    );
  });
}
