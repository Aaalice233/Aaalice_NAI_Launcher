import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/widgets/drop/image_destination_dialog.dart';

void main() {
  testWidgets('shows reverse prompt before image-to-image destination', (
    tester,
  ) async {
    ImageDestination? selected;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          replicationQueueNotifierProvider.overrideWith(
            _TestReplicationQueueNotifier.new,
          ),
          queueExecutionNotifierProvider.overrideWith(
            _TestQueueExecutionNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selected = await ImageDestinationDialog.show(
                      context,
                      imageBytes: _transparentPngBytes,
                      fileName: 'dropped.png',
                      showExtractMetadata: false,
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final dialogContext = tester.element(find.byType(ImageDestinationDialog));
    final l10n = AppLocalizations.of(dialogContext)!;
    final reversePromptFinder = find.text(l10n.drop_reversePrompt);
    final img2imgFinder = find.text(l10n.drop_img2img);

    expect(reversePromptFinder, findsOneWidget);
    expect(img2imgFinder, findsOneWidget);
    expect(
      tester.getTopLeft(reversePromptFinder).dy,
      lessThan(tester.getTopLeft(img2imgFinder).dy),
    );

    await tester.tap(reversePromptFinder);
    await tester.pumpAndSettle();

    expect(selected.toString(), equals('ImageDestination.reversePrompt'));
  });
}

final _transparentPngBytes = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);

class _TestReplicationQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => const ReplicationQueueState();
}

class _TestQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}
