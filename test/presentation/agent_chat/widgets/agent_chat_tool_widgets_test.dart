import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_tool_widgets.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';

void main() {
  Future<void> pumpResult(WidgetTester tester, ToolResultMessage result) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            _TestShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AgentChatToolResultTile(result: result)),
        ),
      ),
    );
  }

  testWidgets('successful result is a collapsed human readable summary', (
    tester,
  ) async {
    final result = ToolResultMessage(
      toolCallId: 'success-1',
      toolName: 'search_tags',
      content: const [
        ToolResultTextContent(
          '{"ok":true,"message":"Found 3 matching tags","items":[1,2,3]}',
        ),
      ],
    );

    await pumpResult(tester, result);

    expect(find.textContaining('Found 3 matching tags'), findsOneWidget);
    expect(find.textContaining('Success'), findsOneWidget);
    expect(find.textContaining('{"ok":true,"message"'), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-tool-result-details-success-1')),
      findsNothing,
    );
  });

  testWidgets('reasoning expansion isolates selectable scroll page storage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            key: const PageStorageKey('agent-chat-thread-test'),
            children: const [
              AgentChatReasoningTile(thinking: 'durable reasoning'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-reasoning-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('durable reasoning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('internal API diagnostics stay out of the result summary', (
    tester,
  ) async {
    final result = ToolResultMessage(
      toolCallId: 'diagnostic-1',
      toolName: 'submit_generation',
      isError: true,
      content: const [
        ToolResultTextContent(
          'DioException: status code of 400 RequestOptions '
          'validateStatus response.data private protocol body',
        ),
      ],
    );

    await pumpResult(tester, result);

    expect(find.textContaining('RequestOptions'), findsNothing);
    expect(find.textContaining('validateStatus'), findsNothing);
    expect(find.textContaining('HTTP 400'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('agent-tool-result-diagnostic-1')),
    );
    await tester.pump();
    expect(find.textContaining('RequestOptions'), findsOneWidget);
  });

  testWidgets('error summary stays visible and details can be expanded', (
    tester,
  ) async {
    final result = ToolResultMessage(
      toolCallId: 'error-1',
      toolName: 'web_search',
      isError: true,
      content: const [
        ToolResultTextContent(
          '{"error":"Network request failed","status":503}',
        ),
      ],
    );

    await pumpResult(tester, result);

    expect(find.textContaining('Network request failed'), findsOneWidget);
    expect(find.textContaining('Error'), findsOneWidget);
    expect(find.textContaining('"status": 503'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-tool-result-error-1')));
    await tester.pump();

    expect(find.textContaining('"status": 503'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-tool-result-details-error-1')),
      findsOneWidget,
    );
  });

  testWidgets('expanded detail is bounded scrollable selectable and copyable', (
    tester,
  ) async {
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final values = List<String>.generate(80, (index) => 'value-$index');
    final rawJson = jsonEncode({'values': values});
    final result = ToolResultMessage(
      toolCallId: 'detail-1',
      toolName: 'read',
      content: [ToolResultTextContent(rawJson)],
    );

    await pumpResult(tester, result);
    await tester.tap(find.byKey(const ValueKey('agent-tool-result-detail-1')));
    await tester.pump();

    final panel = find.byKey(
      const ValueKey('agent-tool-result-details-detail-1'),
    );
    expect(panel, findsOneWidget);
    expect(
      find.descendant(of: panel, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.byType(SelectableText)),
      findsOneWidget,
    );
    expect(tester.getSize(panel).height, lessThanOrEqualTo(252));

    await tester.tap(
      find.descendant(
        of: panel,
        matching: find.byKey(const ValueKey('agent-tool-detail-copy')),
      ),
    );
    await tester.pump();
    expect(copiedText, contains('"value-79"'));
    expect(copiedText, contains('\n'));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('renders explicit ToolResultImageContent previews', (
    tester,
  ) async {
    final result = ToolResultMessage(
      toolCallId: 'preview-1',
      toolName: 'preview_generated_image',
      content: [
        ToolResultImageContent(
          ImageContent(
            source: ImageSource.base64(
              mimeType: 'image/png',
              base64Data: base64Encode(_onePixelPng),
            ),
          ),
        ),
      ],
    );

    await pumpResult(tester, result);

    expect(find.byType(Image), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-tool-result-preview-1')));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('local files take precedence over inline images and open', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'agent_tool_result_mixed_image_',
    );
    final imageFile = File('${tempDir.path}${Platform.pathSeparator}result.png')
      ..writeAsBytesSync(_onePixelPng);
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final result = ToolResultMessage(
      toolCallId: 'mixed-image-1',
      toolName: 'generate_image',
      content: [
        ToolResultImageContent(
          ImageContent(
            source: ImageSource.base64(
              mimeType: 'image/png',
              base64Data: base64Encode(_onePixelPng),
            ),
          ),
        ),
      ],
      details: {
        'files': [imageFile.path],
      },
    );

    await pumpResult(tester, result);
    await tester.tap(
      find.byKey(const ValueKey('agent-tool-result-mixed-image-1')),
    );
    await tester.pump();

    final localCard = find.byKey(ValueKey(imageFile.path));
    expect(localCard, findsOneWidget);
    expect(
      find.byKey(const ValueKey('mixed-image-1-inline-0')),
      findsNothing,
      reason: 'persisted local output replaces the duplicate inline preview',
    );
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(localCard);
    await tester.pump();
    await tester.pump();

    final viewer = tester.widget<ImageDetailViewer>(
      find.byType(ImageDetailViewer),
    );
    expect(viewer.images, hasLength(1));
    expect(
      (viewer.images.single as FileImageDetailData).filePath,
      imageFile.path,
    );
  });

  testWidgets('renders persisted generation files without a display tool', (
    tester,
  ) async {
    final result = ToolResultMessage(
      toolCallId: 'generate-1',
      toolName: 'generate_image',
      content: const [ToolResultTextContent('{"ok":true}')],
      details: const {
        'files': ['missing-generated-result.png'],
      },
    );

    await pumpResult(tester, result);
    await tester.pump();

    expect(find.textContaining('missing-generated-result.png'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('agent-tool-result-generate-1')),
    );
    await tester.pump();
    expect(find.textContaining('missing-generated-result.png'), findsWidgets);
  });

  testWidgets('stable ref replaces inline thumbnail and opens original bytes', (
    tester,
  ) async {
    final originalBytes = Uint8List.fromList(
      image_lib.encodePng(image_lib.Image(width: 4, height: 3)),
    );
    final reference = AgentChatResourceReference(
      kind: AgentChatResourceKind.generatedImage,
      source: 'generation',
      resourceId: 'original-1',
    );
    final result = ToolResultMessage(
      toolCallId: 'display-ref-1',
      toolName: 'display_images',
      content: [
        ToolResultImageContent(
          ImageContent(
            source: ImageSource.base64(
              mimeType: 'image/png',
              base64Data: base64Encode(_onePixelPng),
            ),
          ),
        ),
      ],
      details: {
        'images': [
          {
            'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
              reference,
            ),
          },
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            _TestShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AgentChatToolResultMedia(
              result: result,
              resolveResource: (value) async => ResolvedAgentResource(
                reference: value,
                label: 'Original',
                bytes: originalBytes,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(
      find.byKey(const ValueKey('display-ref-1-media-inline-0')),
      findsNothing,
    );

    tester.widget<GestureDetector>(find.byType(GestureDetector)).onTap!();
    await tester.pump();
    await tester.pump();

    final viewer = tester.widget<ImageDetailViewer>(
      find.byType(ImageDetailViewer),
    );
    final detail = viewer.images.single as GeneratedImageDetailData;
    expect(detail.imageBytes, originalBytes);
    final decoded = image_lib.decodeImage(detail.imageBytes);
    expect(decoded?.width, 4);
    expect(decoded?.height, 3);
  });

  testWidgets('online gallery refs render quiet multi-card metadata layout', (
    tester,
  ) async {
    final references = [
      for (var index = 0; index < 3; index++)
        AgentChatResourceReference(
          kind: AgentChatResourceKind.onlineGalleryMedia,
          source: 'danbooru',
          resourceId: '$index',
          display: {
            'source_label': 'Danbooru',
            'title': 'Ibuki $index',
            'author': 'Artist $index',
          },
        ),
    ];
    final result = ToolResultMessage(
      toolCallId: 'display-online',
      toolName: 'display_images',
      content: [
        for (var index = 0; index < references.length; index++)
          ToolResultImageContent(
            ImageContent(
              source: ImageSource.base64(
                mimeType: 'image/png',
                base64Data: base64Encode(_onePixelPng),
              ),
            ),
          ),
      ],
      details: {
        'images': [
          for (final reference in references)
            {
              'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
                reference,
              ),
            },
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AgentChatToolResultMedia(result: result)),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('online-gallery-resource-card')),
      findsNWidgets(3),
    );
    expect(find.text('Danbooru'), findsNWidgets(3));
    expect(find.text('Ibuki 1'), findsOneWidget);
    expect(find.text('Artist 2'), findsOneWidget);
    expect(find.byType(Wrap), findsWidgets);
  });

  testWidgets('tool group hides failure payload until explicitly expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentChatToolResultGroup(
            results: [
              ToolResultMessage(
                toolCallId: 'ok',
                toolName: 'read',
                content: const [ToolResultTextContent('{"ok":true}')],
              ),
              ToolResultMessage(
                toolCallId: 'failed',
                toolName: 'web_search',
                isError: true,
                content: const [
                  ToolResultTextContent(
                    '{"error":"Upstream search timed out","status":504}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('Upstream search timed out'), findsNothing);
    expect(find.textContaining('"status"'), findsNothing);
    await tester.tap(find.text('Ran 2 actions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Upstream search timed out'), findsOneWidget);
    expect(find.textContaining('"status"'), findsNothing);
  });

  testWidgets('running activity has no perpetual animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: AgentChatToolActivityTile(
              activity: AgentToolActivity(
                toolCallId: 'running-static',
                toolName: 'web_search',
                args: {'query': 'a long query that must remain bounded'},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task hierarchy stays bounded across supported widths', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 412.0, 600.0, 840.0]) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: SizedBox(
                width: width,
                child: AgentChatToolResultGroup(
                  results: [
                    ToolResultMessage(
                      toolCallId: 'responsive-ok',
                      toolName: 'get_recent_images',
                      content: const [
                        ToolResultTextContent(
                          '{"message":"Found the most recent generated image resource"}',
                        ),
                      ],
                    ),
                    ToolResultMessage(
                      toolCallId: 'responsive-error',
                      toolName: 'web_search',
                      isError: true,
                      content: const [
                        ToolResultTextContent(
                          '{"error":"Network request timed out while loading the reference"}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const PageStorageKey('agent-tool-group-responsive-ok-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-tool-result-responsive-ok')),
        findsNothing,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}

class _TestShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=',
);
