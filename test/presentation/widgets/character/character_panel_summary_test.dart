import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations_en.dart';
import 'package:nai_launcher/l10n/app_localizations_ja.dart';
import 'package:nai_launcher/l10n/app_localizations_zh.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_section.dart';

CharacterPrompt character(String id, String name, {bool enabled = true}) {
  return CharacterPrompt(id: id, name: name, enabled: enabled);
}

void main() {
  test('空角色与全部停用状态有明确摘要', () {
    final l10n = AppLocalizationsZh();

    expect(buildCharacterPanelSummary(l10n, const []), '未添加角色');
    expect(
      buildCharacterPanelSummary(l10n, [
        character('1', 'Alice', enabled: false),
        character('2', 'Bob', enabled: false),
      ]),
      '已启用 0 个 · 已停用 2 个',
    );
  });

  test('摘要优先使用第一个启用角色并实时反映启用数量', () {
    final l10n = AppLocalizationsEn();
    final characters = [
      character('1', 'Disabled', enabled: false),
      character('2', 'Alice'),
      character('3', 'Bob'),
    ];

    expect(
      buildCharacterPanelSummary(l10n, characters),
      '2 enabled · Alice +1',
    );
    expect(
      buildCharacterPanelSummary(
        l10n,
        characters.map((item) => item.copyWith(enabled: true)).toList(),
      ),
      '3 enabled · Disabled +2',
    );
  });

  test('空白名称回退到本地化角色编号', () {
    expect(
      buildCharacterPanelSummary(AppLocalizationsJa(), [character('1', '   ')]),
      '1人有効 · キャラクター 1',
    );
  });
}
