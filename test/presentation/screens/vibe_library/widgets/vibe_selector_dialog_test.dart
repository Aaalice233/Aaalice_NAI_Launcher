import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_selector_dialog.dart';

void main() {
  test('热门标签只基于有限样本计算，避免打开选择器时整库聚合', () {
    final entries = [
      for (var i = 0; i < 80; i++)
        _buildEntry(
          id: 'entry-$i',
          tags: i < 40 ? ['focus', 'common'] : ['late-$i'],
        ),
    ];

    final topTags = computeInitialTopTags(entries);

    expect(topTags, containsAll(['focus', 'common']));
    expect(
      topTags.any((tag) => tag.startsWith('late-')),
      isFalse,
      reason: '首屏热门标签不应为整库扫描所有条目付出同步开销',
    );
  });
}

VibeLibraryEntry _buildEntry({
  required String id,
  required List<String> tags,
}) {
  return VibeLibraryEntry(
    id: id,
    name: id,
    vibeDisplayName: id,
    vibeEncoding: 'encoding-$id',
    strength: 0.6,
    infoExtracted: 0.7,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    tags: tags,
    createdAt: DateTime(2026, 4, 14),
  );
}
