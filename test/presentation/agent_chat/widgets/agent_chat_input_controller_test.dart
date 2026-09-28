import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_input_controller.dart';

AgentChatInputController _controller({
  required String text,
  TextRange composing = TextRange.empty,
  Set<String> commands = const {'art-prompt'},
  int imageCount = 0,
}) {
  final controller = AgentChatInputController(
    onImageEnter: (_, _) {},
    onImageExit: () {},
  );
  controller.slashCommandNames = commands;
  controller.imageCount = imageCount;
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
    composing: composing,
  );
  return controller;
}

void main() {
  late BuildContext context;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox();
          },
        ),
      ),
    );
  }

  List<(String, bool, bool)> render(
    AgentChatInputController controller, {
    bool withComposing = true,
  }) {
    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 14),
      withComposing: withComposing,
    );
    return <(String, bool, bool)>[
      for (final child in span.children!.cast<TextSpan>())
        (
          child.text!,
          child.style?.backgroundColor != null,
          child.style?.decoration == TextDecoration.underline,
        ),
    ];
  }

  testWidgets('highlights a known leading command', (tester) async {
    await pumpHost(tester);

    expect(render(_controller(text: '/art-prompt draw a cat')), const [
      ('/art-prompt', true, false),
      (' draw a cat', false, false),
    ]);
  });

  testWidgets('keeps the command highlighted while the IME composes', (
    tester,
  ) async {
    await pumpHost(tester);

    // The pre-edit text sits after the token, which is exactly the case that
    // used to hand the whole line back to the default renderer.
    final spans = render(
      _controller(
        text: '/art-prompt a',
        composing: const TextRange(start: 12, end: 13),
      ),
    );

    expect(spans, const [
      ('/art-prompt', true, false),
      (' ', false, false),
      ('a', false, true),
    ]);
  });

  testWidgets('keeps image references highlighted while the IME composes', (
    tester,
  ) async {
    await pumpHost(tester);

    final spans = render(
      _controller(
        text: '[image1] a',
        composing: const TextRange(start: 9, end: 10),
        imageCount: 1,
      ),
    );

    expect(spans, const [
      ('[image1]', true, false),
      (' ', false, false),
      ('a', false, true),
    ]);
  });

  testWidgets('underlines only the composed part of a token', (tester) async {
    await pumpHost(tester);

    final spans = render(
      _controller(
        text: '/art-prompt',
        composing: const TextRange(start: 4, end: 8),
      ),
    );

    expect(spans, const [
      ('/art', true, false),
      ('-pro', true, true),
      ('mpt', true, false),
    ]);
  });

  testWidgets('adds no underline when composing is not requested', (
    tester,
  ) async {
    await pumpHost(tester);

    final spans = render(
      _controller(
        text: '/art-prompt a',
        composing: const TextRange(start: 12, end: 13),
      ),
      withComposing: false,
    );

    expect(spans, const [('/art-prompt', true, false), (' a', false, false)]);
  });

  testWidgets('leaves an unknown command as plain text', (tester) async {
    await pumpHost(tester);

    expect(render(_controller(text: '/not-a-command hi')), const [
      ('/not-a-command hi', false, false),
    ]);
  });

  testWidgets('leaves an out-of-range image reference as plain text', (
    tester,
  ) async {
    await pumpHost(tester);

    expect(
      render(_controller(text: 'see [image3]', commands: const {})),
      const [('see ', false, false), ('[image3]', false, false)],
    );
  });
}
