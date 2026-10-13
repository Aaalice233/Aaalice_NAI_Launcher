import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_controller.dart';

PendingAgentChatImage _image(int seed) => PendingAgentChatImage(
  name: 'image$seed.png',
  bytes: Uint8List.fromList([seed, seed + 1, seed + 2]),
  mimeType: 'image/png',
);

List<Object> _describe(List<UserContent> content) => [
  for (final block in content)
    switch (block) {
      UserTextContent(:final text) => text,
      UserImageContent(:final image) => image.source.bytes!.first,
    },
];

void main() {
  late AgentChatPanelController controller;

  setUp(() => controller = AgentChatPanelController());
  tearDown(() => controller.dispose());

  group('buildInlineUserContent', () {
    test('keeps referenced images inline in text order', () {
      final content = controller.buildInlineUserContent(
        'see [image2] then [image1]',
        [_image(10), _image(20)],
      );

      expect(_describe(content), ['see ', 20, ' then ', 10]);
    });

    test('appends attachments the text no longer references', () {
      final content = controller.buildInlineUserContent('look [image2]', [
        _image(10),
        _image(20),
        _image(30),
      ]);

      expect(_describe(content), ['look ', 20, 10, 30]);
    });

    test('sends attachments alone when every reference was deleted', () {
      final content = controller.buildInlineUserContent('  ', [
        _image(10),
        _image(20),
      ]);

      expect(_describe(content), [10, 20]);
    });

    test('keeps an out-of-range reference as plain text', () {
      final content = controller.buildInlineUserContent('[image3]', [
        _image(10),
      ]);

      expect(_describe(content), ['[image3]', 10]);
    });

    test('returns nothing for an empty draft without attachments', () {
      expect(controller.buildInlineUserContent(' \n', const []), isEmpty);
    });
  });

  group('removePendingImage', () {
    test('keeps the caret inside the shortened draft', () {
      controller
        ..addPendingImage(_image(10))
        ..addPendingImage(_image(20));
      expect(controller.inputController.text, '[image1] [image2] ');

      controller.removePendingImage(0);

      final value = controller.inputController.value;
      expect(value.text, '[image1] ');
      expect(
        value.selection,
        TextSelection.collapsed(offset: value.text.length),
      );
      expect(controller.pendingImages.single.bytes.first, 20);
      expect(controller.inputController.imageCount, 1);
    });

    test('lets the next attachment insert where the caret was', () {
      controller.inputController.value = const TextEditingValue(
        text: 'a ',
        selection: TextSelection.collapsed(offset: 2),
      );
      controller
        ..addPendingImage(_image(10))
        ..addPendingImage(_image(20));
      controller.removePendingImage(1);

      controller.addPendingImage(_image(30));

      expect(controller.inputController.text, 'a [image1] [image2] ');
    });
  });

  test(
    'inserting at a stale out-of-range selection appends instead of throwing',
    () {
      controller.inputController.value = const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 40),
      );

      controller.addPendingImage(_image(10));
      expect(controller.inputController.text, 'abc [image1] ');

      controller.inputController.value = const TextEditingValue(
        text: 'abc',
        selection: TextSelection(baseOffset: 1, extentOffset: 40),
      );
      controller.insertNewline();
      expect(controller.inputController.text, 'a\n');
    },
  );
}
