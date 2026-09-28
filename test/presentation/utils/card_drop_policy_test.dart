import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/presentation/utils/card_drop_reader.dart';
import 'package:nai_launcher/presentation/utils/gallery_drop_reader.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../helpers/card_drop_test_utils.dart';

void main() {
  final image = TestCardDropItem.resource(
    'image',
    kind: AgentChatResourceKind.generatedImage,
  );
  final vibe = TestCardDropItem.resource('vibe');
  final precise = TestCardDropItem.resource(
    'precise',
    kind: AgentChatResourceKind.preciseRefLibraryEntry,
  );
  final tag = TestCardDropItem.resource(
    'tag',
    kind: AgentChatResourceKind.tagLibraryEntry,
  );
  final external = TestCardDropItem(formats: [Formats.png]);
  test(
    'single-image targets reject multiple members, empty and semantic resources',
    () {
      const policy = CardDropPolicy(allowMultiple: false);
      expect(policy.accepts([image]), isTrue);
      expect(policy.accepts([precise]), isTrue);
      expect(policy.accepts([external]), isTrue);
      for (final items in [
        [image, external],
        [vibe],
        [tag],
        <DropItem>[],
      ]) {
        expect(policy.accepts(items), isFalse);
      }
    },
  );
  test('batch image targets reject the entire mixed set', () {
    const policy = CardDropPolicy();
    expect(policy.accepts([image, precise, external]), isTrue);
    expect(policy.accepts([image, vibe]), isFalse);
    expect(policy.accepts([image, tag]), isFalse);
    expect(
      const CardDropPolicy(allowVibes: true).accepts([image, vibe, precise]),
      isTrue,
    );
  });
  test(
    'classification path targets never turn a portable resource into a gallery file',
    () {
      final local = TestCardDropItem(
        localData: {'source': 'gallery_internal', 'path': 'E:/images/a.png'},
      );
      final file = TestCardDropItem(formats: [Formats.fileUri]);
      expect(canAcceptGalleryDrop([local, file]), isTrue);
      expect(canAcceptGalleryDrop([local, file], internalOnly: true), isFalse);
      expect(canAcceptGalleryDrop([local, vibe]), isFalse);
      expect(canAcceptGalleryDrop([]), isFalse);
    },
  );
}
