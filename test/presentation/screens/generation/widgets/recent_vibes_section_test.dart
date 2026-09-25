import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/recent_vibes_section.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';

import '../../../../helpers/ink_expectations.dart';

void main() {
  testWidgets('最近 Vibe 条目的反馈叠在缩略图占位之上，点击添加条目', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RecentVibesSection(
            entries: [_entry('recent')],
            isCollapsed: false,
            onToggleCollapse: () {},
            onEntryTap: (entry) => tapped.add(entry.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final item = find.descendant(
      of: find.byType(RecentVibeItem),
      matching: find.byType(SurfaceInkWell),
    );
    final theme = Theme.of(tester.element(item));
    final fill = theme.colorScheme.surfaceContainerLow;

    await hoverOver(tester, item);
    expectInkOnTop(tester, item, ink: theme.hoverColor, below: fill);

    final press = await pressAndHold(tester, item);
    expectInkOnTop(tester, item, ink: theme.highlightColor, below: fill);
    await press.up();
    await tester.pumpAndSettle();
    expect(tapped, ['recent']);
  });
}

VibeLibraryEntry _entry(String id) => VibeLibraryEntry(
  id: id,
  name: id,
  vibeDisplayName: id,
  vibeEncoding: 'ZW5jb2RlZA==',
  strength: 0.6,
  infoExtracted: 0.7,
  sourceTypeIndex: VibeSourceType.naiv4vibe.index,
  createdAt: DateTime(2026, 4, 14),
);
