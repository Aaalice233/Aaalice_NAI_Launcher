import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_export_dialog_advanced.dart';

void main() {
  testWidgets('单个 Vibe 的 PNG 导出保留外部 PNG 选择入口', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VibeExportDialogAdvanced(
          entries: [
            _buildEntry(
              id: 'single',
              displayName: 'Single',
              rawImageData: _createInMemoryPngBytes(),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('导出为 PNG'));
    await tester.pumpAndSettle();

    expect(find.text('选择外部 PNG 图片...'), findsOneWidget);
  });

  testWidgets('批量 PNG 导出不提供嵌入 PNG 入口', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VibeExportDialogAdvanced(
          entries: [
            _buildEntry(
              id: 'first',
              displayName: 'First',
              rawImageData: _createInMemoryPngBytes(),
            ),
            _buildEntry(
              id: 'second',
              displayName: 'Second',
              rawImageData: Uint8List.fromList(
                List<int>.from(_createInMemoryPngBytes()),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('导出为 PNG'), findsNothing);
    expect(find.text('选择外部 PNG 图片...'), findsNothing);
  });
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: const Locale('zh'),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

VibeLibraryEntry _buildEntry({
  required String id,
  required String displayName,
  Uint8List? rawImageData,
}) {
  return VibeLibraryEntry(
    id: id,
    name: displayName,
    vibeDisplayName: displayName,
    vibeEncoding: 'ZW5jb2RlZA==',
    strength: 0.6,
    infoExtracted: 0.7,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    rawImageData: rawImageData,
    createdAt: DateTime(2026, 4, 14),
  );
}

Uint8List _createInMemoryPngBytes() {
  const base64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';
  return Uint8List.fromList(base64Decode(base64Png));
}
