import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_identifier.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_validator.dart';
import 'package:nai_launcher/data/models/online_gallery/quick_tag_cloud_codex.dart';

void main() {
  final pathLikeIds = [
    quickTagCloudEntryWorkId('builtin', 'entry-1'),
    quickTagCloudEntryWorkId('community:codex', 'entry/1 中'),
    '${quickTagCloudEntryWorkId('codex', 'generated-0123456789abcdef0123')}:12',
    quickTagCloudEntryWorkId('..', '.hidden'),
    quickTagCloudEntryWorkId('+@%', "(it's)!*~"),
    quickTagCloudEntryWorkId('emoji', '🎨 sketch'),
    'a/${'Ab12' * 20}',
    'enc.already-prefixed',
    'http://example.test/x',
    '../escape',
    '',
  ];

  test('accepted identifiers pass through unchanged', () {
    for (final id in ['101', '101_p0', 'no-image', 'a:b@c+d', 'resource-42']) {
      expect(AgentChatResourceIdentifier.encode(id), id);
      expect(AgentChatResourceIdentifier.decode(id), id);
    }
  });

  test('other ids encode into accepted identifiers and decode back', () {
    for (final id in pathLikeIds) {
      final encoded = AgentChatResourceIdentifier.encode(id);

      expect(encoded, startsWith(AgentChatResourceIdentifier.encodedPrefix));
      expect(
        AgentChatResourceReferenceValidator.isOpaqueIdentifier(encoded),
        isTrue,
        reason: encoded,
      );
      expect(AgentChatResourceIdentifier.decode(encoded), id);
    }
  });

  test('distinct ids never share an encoding', () {
    final ids = [...pathLikeIds, 'a%2Fb', 'a/b', 'a@2Fb', 'a+2Fb', 'enc.a+2Fb'];
    final encoded = ids.map(AgentChatResourceIdentifier.encode).toSet();

    expect(encoded, hasLength(ids.toSet().length));
  });

  test('percent-encoded work ids keep their length', () {
    final workId = quickTagCloudEntryWorkId('社区法典', '条目一');

    expect(
      AgentChatResourceIdentifier.encode(workId).length,
      workId.length + AgentChatResourceIdentifier.encodedPrefix.length + 2,
    );
  });

  test('non-canonical encodings are rejected', () {
    for (final id in [
      'enc.abc',
      'enc.a+2fb',
      'enc.a+2',
      'enc.a+G1',
      'enc.+41',
      'enc.a/b',
      'enc.+FF',
      'enc.a++2Fb',
    ]) {
      expect(AgentChatResourceIdentifier.decode(id), isNull, reason: id);
    }
  });
}
