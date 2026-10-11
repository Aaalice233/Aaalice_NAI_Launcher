import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_composer_image_input.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';
import 'package:nai_launcher/presentation/widgets/drop/image_paste_shortcuts.dart';

void main() {
  group('AgentChatImagePasteScope', () {
    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      testWidgets(
        '${modifier.keyLabel}+V reaches the composer before an outer handler',
        (tester) async {
          var imagePastes = 0;
          var outerPastes = 0;
          final controller = TextEditingController();
          addTearDown(controller.dispose);
          _mockClipboardText(tester, 'from clipboard');
          await tester.pumpWidget(
            _scopeApp(
              controller: controller,
              onOuterPaste: () => outerPastes++,
              onPasteImage: () async {
                imagePastes++;
                return true;
              },
            ),
          );

          await _pressPaste(tester, modifier);

          expect(imagePastes, 1);
          expect(outerPastes, 0);
          expect(controller.text, isEmpty);
        },
      );
    }

    testWidgets('hands the key back to text paste when no image is taken', (
      tester,
    ) async {
      var outerPastes = 0;
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      _mockClipboardText(tester, 'from clipboard');
      await tester.pumpWidget(
        _scopeApp(
          controller: controller,
          onOuterPaste: () => outerPastes++,
          onPasteImage: () async => false,
        ),
      );

      await _pressPaste(tester, LogicalKeyboardKey.controlLeft);

      expect(controller.text, 'from clipboard');
      expect(outerPastes, 0);
    });
  });

  group('agentChatKeyboardImageInsertion', () {
    test('offers only formats the attachment policy accepts', () {
      final config = agentChatKeyboardImageInsertion((_) async {});

      expect(config.allowedMimeTypes, [
        'image/png',
        'image/jpeg',
        'image/webp',
        'image/gif',
      ]);
    });

    test('keeps the IME file name or derives one from the type', () {
      final attached = <DroppedFileData>[];
      final config = agentChatKeyboardImageInsertion(
        (files) async => attached.addAll(files),
      );

      config.onContentInserted(
        KeyboardInsertedContent(
          mimeType: 'image/png',
          uri: 'content://ime.provider/clipboard/shot.png',
          data: Uint8List.fromList([1, 2, 3]),
        ),
      );
      config.onContentInserted(
        const KeyboardInsertedContent(
          mimeType: 'image/webp',
          uri: 'content://ime.provider/media/12345',
        ),
      );

      expect(attached.map((file) => file.fileName), ['shot.png', 'image.webp']);
      expect(attached.first.bytes, [1, 2, 3]);
      expect(attached.last.bytes, isEmpty);
    });
  });
}

class _OuterPasteIntent extends Intent {
  const _OuterPasteIntent();
}

Widget _scopeApp({
  required TextEditingController controller,
  required VoidCallback onOuterPaste,
  required Future<bool> Function() onPasteImage,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Shortcuts(
        shortcuts: imagePasteShortcuts(const _OuterPasteIntent()),
        child: Actions(
          actions: <Type, Action<Intent>>{
            _OuterPasteIntent: CallbackAction<_OuterPasteIntent>(
              onInvoke: (_) {
                onOuterPaste();
                return null;
              },
            ),
          },
          child: AgentChatImagePasteScope(
            onPasteImage: onPasteImage,
            child: TextField(controller: controller, autofocus: true),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pressPaste(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
) async {
  await tester.pump();
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void _mockClipboardText(WidgetTester tester, String text) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    return switch (call.method) {
      'Clipboard.getData' => <String, Object?>{'text': text},
      'Clipboard.hasStrings' => <String, Object?>{'value': true},
      _ => null,
    };
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
}
