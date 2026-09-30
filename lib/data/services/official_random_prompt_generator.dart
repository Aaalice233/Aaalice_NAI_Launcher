import 'dart:math' show Random;

import '../../core/constants/model_capabilities.dart';
import '../models/character/character_prompt.dart';
import '../models/prompt/official_wordlist.dart';
import '../models/prompt/random_prompt_result.dart';
import 'official_wordlist_errata.dart';
import 'wordlist_service.dart';

/// Executes the three random-prompt recipes from the source-locked NovelAI
/// frontend. Where upstream discards a filter result or records the wrong
/// entry field, the asset's declared intent is applied instead, so flags such
/// as `nolegs`, `legs` and `feet` actually gate the picks. Records listed in
/// [officialWordlistErrata] are corrected when the wordlist is loaded.
class OfficialRandomPromptGenerator {
  const OfficialRandomPromptGenerator(this._wordlistService);

  final WordlistService _wordlistService;

  Future<RandomPromptResult> generate({
    required RandomPromptProfile profile,
    int? seed,
    bool forceCharacters = false,
  }) async {
    final type = switch (profile) {
      RandomPromptProfile.legacyAnime => WordlistType.legacy,
      RandomPromptProfile.furryV3 => WordlistType.furry,
      RandomPromptProfile.characterPrompts => WordlistType.v4,
    };
    final library = correctedOfficialWordlist(
      await _wordlistService.getOfficialWordlist(type),
    );
    final engine = _OfficialRecipeEngine(library, Random(seed));
    final prompts = switch (profile) {
      RandomPromptProfile.legacyAnime => [
        engine.generateLegacy(forceCharacters: forceCharacters),
      ],
      RandomPromptProfile.furryV3 => engine.generateFurry(),
      RandomPromptProfile.characterPrompts => engine.generateCharacterPrompts(),
    };
    final characters = <GeneratedCharacter>[];
    for (final prompt in prompts.skip(1)) {
      final firstTag = prompt.split(', ').firstOrNull;
      characters.add(
        GeneratedCharacter(
          prompt: prompt,
          gender: firstTag == 'boy'
              ? CharacterGender.male
              : firstTag == 'other'
              ? CharacterGender.other
              : CharacterGender.female,
          centerX: 0.5,
          centerY: 0.5,
        ),
      );
    }
    final mainPrompt = prompts.first;
    return RandomPromptResult(
      mainPrompt: mainPrompt,
      characters: characters,
      noHumans:
          mainPrompt.split(', ').contains('no humans') ||
          mainPrompt.split(', ').contains('zero pictured'),
      seed: seed,
    );
  }

  /// Exposes the exact legacy dependency/weight rule for focused regression
  /// tests without coupling tests to a particular production seed.
  static String selectLegacyRecordForTest({
    required List<OfficialWordlistEntry> entries,
    required List<String> selectedTags,
    required double randomValue,
    Set<String> blockedTags = const {},
  }) => _selectLegacyRecord(
    entries,
    selectedTags,
    randomValue,
    blockedTags: blockedTags,
  );

  /// Exposes the Character Prompts require/exclude rule: fields 3 and 4 gate
  /// eligibility and a pick adds its declared field 2 flags to [state].
  static String selectCharacterRecordForTest({
    required List<OfficialWordlistEntry> entries,
    required Set<String> state,
    required double randomValue,
    Set<String> blockedTags = const {},
  }) => _selectCharacterRecord(
    entries,
    state,
    randomValue,
    blockedTags: blockedTags,
  );

  /// Exposes the state a Character Prompts role starts from.
  static Set<String> characterStateForTest({
    required Set<String> globalState,
    required String gender,
  }) => _initialCharacterState(globalState, gender);

  /// Exposes whether the legwear a role drew keeps its toes covered.
  static bool legwearHidesToesForTest(List<String> legwear) =>
      _legwearHidesToes(legwear);
}

class _OfficialRecipeEngine {
  _OfficialRecipeEngine(this.library, this.random);

  final OfficialWordlist library;
  final Random random;

  // A record joining several tags is blocked when any of them is leg clothing.
  late final Set<String> legClothingTags = {
    for (final group in _legClothingGroups[library.id]!)
      for (final entry in library.group(group).entries)
        ...entry.text.split(', '),
  };

  bool chance(double probability) => random.nextDouble() < probability;

  int randomInt(int max, [int min = 0]) =>
      (random.nextDouble() * (max - min)).floor() + min;

  String legacyChoice(
    String group,
    List<String> selectedTags, {
    bool legless = false,
  }) => _selectLegacyRecord(
    library.group(group).entries,
    selectedTags,
    random.nextDouble(),
    blockedTags: legless ? legClothingTags : const {},
  );

  String characterChoice(String group, Set<String> state) =>
      _selectCharacterRecord(
        library.group(group).entries,
        state,
        random.nextDouble(),
        blockedTags: state.contains('nolegs') ? legClothingTags : const {},
      );

  T literalChoice<T>(List<(T, int)> entries) {
    final totalWeight = entries.fold<int>(
      0,
      (total, entry) => total + entry.$2,
    );
    final ticket = randomInt(totalWeight, 1);
    var cumulative = 0;
    for (final entry in entries) {
      cumulative += entry.$2;
      if (ticket <= cumulative) return entry.$1;
    }
    throw StateError('Official weighted choice exhausted unexpectedly');
  }

  String generateLegacy({required bool forceCharacters}) {
    final tags = <String>[];
    var personCount = literalChoice(const [(1, 70), (2, 20), (3, 7), (0, 5)]);
    if (forceCharacters) {
      personCount = literalChoice(const [(1, 35), (2, 20), (3, 7)]);
    }
    if (personCount == 0) {
      tags.add('no humans');
      if (chance(0.3)) tags.add(legacyChoice(r'l$', tags));
      tags.add(legacyChoice('lV', tags));
      final environmentCount = literalChoice(const [
        (2, 15),
        (3, 50),
        (4, 15),
        (5, 5),
      ]);
      for (var index = 0; index < environmentCount; index++) {
        tags.add(legacyChoice('cs', tags));
      }
      var objectCount = literalChoice(const [
        (0, 15),
        (1, 10),
        (2, 20),
        (3, 20),
        (4, 20),
        (5, 15),
      ]);
      objectCount -= personCount;
      if (objectCount < 0) objectCount = 0;
      for (var index = 0; index < objectCount; index++) {
        tags.add(legacyChoice('cl', tags));
      }
      return tags.join(', ');
    }

    String? framing;
    if (chance(0.3)) tags.add(legacyChoice(r'l$', tags));
    var femaleCount = 0;
    var maleCount = 0;
    var otherCount = 0;
    for (var index = 0; index < personCount; index++) {
      literalChoice(const [('m', 30), ('f', 50), ('o', 10)]);
      final gender = literalChoice(const [('m', 30), ('f', 50)]);
      if (gender == 'f') {
        femaleCount++;
      } else if (gender == 'm') {
        maleCount++;
      } else {
        otherCount++;
      }
    }
    _prependCharacterCount(tags, femaleCount, 'girl', 'girls');
    _prependCharacterCount(tags, maleCount, 'boy', 'boys');
    _prependCharacterCount(tags, otherCount, 'other', 'others');

    if (chance(0.8)) {
      final background = legacyChoice('lU', tags);
      tags.add(background);
      if (background == 'scenery' && chance(0.5)) {
        final count = randomInt(3, 1);
        for (var index = 0; index < count; index++) {
          tags.add(legacyChoice('cs', tags));
        }
      }
    }
    if (chance(0.3)) tags.add(legacyChoice('lF', tags));
    if (chance(0.7)) {
      framing = legacyChoice('lW', tags);
      if (framing.isNotEmpty) tags.add(framing);
    }
    for (var index = 0; index < femaleCount; index++) {
      tags.addAll(_legacyCharacter('f', framing, forceCharacters, personCount));
    }
    for (var index = 0; index < maleCount; index++) {
      tags.addAll(_legacyCharacter('m', framing, forceCharacters, personCount));
    }
    for (var index = 0; index < otherCount; index++) {
      tags.addAll(_legacyCharacter('o', framing, forceCharacters, personCount));
    }
    if (chance(0.2)) {
      var objectCount = randomInt(4);
      if (personCount == 2) objectCount = randomInt(3);
      for (var index = 0; index < objectCount; index++) {
        tags.add(legacyChoice('cl', tags));
      }
    }
    if (chance(0.25)) {
      final effectCount = randomInt(3, 1);
      for (var index = 0; index < effectCount; index++) {
        tags.add(legacyChoice('cd', tags));
      }
    }
    if (chance(0.2)) tags.add(legacyChoice('co', tags));
    if (chance(0.1)) tags.add(legacyChoice('lO', tags));

    final deduplicated = _commaStableDeduplicate(tags);
    for (var index = 0; index < deduplicated.length; index++) {
      if (chance(0.02)) deduplicated[index] = '{${deduplicated[index]}}';
    }
    return deduplicated.join(', ');
  }

  List<String> _legacyCharacter(
    String gender,
    String? framing,
    bool specialMode,
    int totalCharacterCount,
  ) {
    final tags = <String>[];
    if (chance(0.1)) tags.add(legacyChoice('lH', tags));
    // Species records such as "mermaid, scales" join several tags in one value.
    final specialBody = tags
        .expand((tag) => tag.split(', '))
        .any(const {'mermaid', 'centaur', 'lamia'}.contains);
    String pick(String group) =>
        legacyChoice(group, tags, legless: specialBody);
    String pickColored(String group) =>
        _coloredLegacyChoice(group, tags, legless: specialBody);
    if (chance(0.4)) tags.add(pick('lG'));
    if (chance(0.8)) tags.add(pick('ch'));
    if (chance(0.1)) tags.add(pick('lX'));
    if (chance(0.2)) tags.add(pick('lY'));
    if (chance(0.8)) tags.add(pick('lQ'));
    if (chance(0.5)) tags.add(pick('lK'));
    if (chance(0.7)) tags.add(pick('cu'));
    if (chance(0.1)) {
      tags.add(pick('cp'));
      tags.add(pick('cu'));
    }
    if (chance(0.1)) tags.add(pick('lZ'));
    if (chance(0.2)) tags.add(pick('lJ'));
    if (gender.startsWith('f') && chance(0.5)) {
      tags.add(pick('l0'));
    }
    final featureCount = _legacyCharacterCount(totalCharacterCount, tags);
    for (var index = 0; index < featureCount; index++) {
      tags.add(pick('l3'));
    }
    if (chance(0.2)) {
      tags.add(pick('l2'));
      if (chance(0.2)) tags.add(pick('l5'));
    } else if (chance(0.3)) {
      tags.add(pick('l1'));
    }

    final clothingType = literalChoice(const [
      ('uniform', 10),
      ('swimsuit', 5),
      ('bodysuit', 5),
      ('normal clothes', 40),
    ]);
    switch (clothingType) {
      case 'uniform':
        tags.add(pick('ct'));
        break;
      case 'swimsuit':
        tags.add(pick('ci'));
        break;
      case 'bodysuit':
        tags.add(pick('cr'));
        break;
      case 'normal clothes':
        // Upstream only strips "legwear" modifiers afterwards, which misses
        // values such as thighhighs, so legwear is gated like bottoms.
        if (!specialBody && gender.startsWith('f') && chance(0.5)) {
          tags.add(pick('l4'));
          if (chance(0.2)) tags.add(pick('l8'));
        }
        final useDress = gender.startsWith('f') && chance(0.2);
        if (useDress) {
          tags.add(pickColored('l6'));
        } else {
          if (chance(0.85)) tags.add(pickColored('l7'));
          if (!specialBody) {
            final lowerRoll = chance(0.85);
            if (lowerRoll && framing != 'portrait') {
              tags.add(pickColored('l9'));
            }
            final footwearRoll = chance(0.6);
            if (footwearRoll && (framing == 'full body' || framing == null)) {
              tags.add(pickColored('ce'));
            }
          }
        }
        break;
    }
    if (chance(0.6)) tags.add(pick('cn'));
    final actionProbability = specialMode && totalCharacterCount == 1
        ? 1.0
        : 0.4;
    if (chance(actionProbability)) tags.add(pick('cc'));
    if (_containsAnyFragment(tags, const ['sleeping', 'zzz', 'closed eyes'])) {
      _removeGroupValues(tags, const ['ch']);
    }
    final miscCount = _legacyCharacterCount(totalCharacterCount, tags);
    for (var index = 0; index < miscCount; index++) {
      tags.add(pick('ca'));
    }
    if (specialBody) tags.removeWhere((tag) => tag.contains('legwear'));
    return tags;
  }

  // Upstream builds these filtered lists and then discards them.
  void _removeGroupValues(List<String> tags, List<String> groups) {
    final values = {
      for (final group in groups)
        for (final entry in library.group(group).entries) entry.text,
    };
    tags.removeWhere(values.contains);
  }

  int _legacyCharacterCount(int totalCharacterCount, List<String> tags) {
    if (totalCharacterCount == 1) {
      return literalChoice(const [(0, 10), (1, 30), (2, 15), (3, 5)]);
    }
    if (totalCharacterCount == 2) {
      return literalChoice(const [(0, 20), (1, 40), (2, 10)]);
    }
    return literalChoice(const [(0, 30), (1, 30)]);
  }

  String _coloredLegacyChoice(
    String group,
    List<String> tags, {
    required bool legless,
  }) {
    final useColor = chance(0.5);
    final color = legacyChoice('cg', tags, legless: legless);
    final value = legacyChoice(group, tags, legless: legless);
    return useColor ? '$color $value' : value;
  }

  List<String> generateFurry() {
    final tags = <String>[];
    final personCount = literalChoice(const [(1, 80), (2, 15), (3, 5), (0, 5)]);
    if (personCount == 0) {
      tags.add('zero pictured');
      if (chance(0.3)) tags.add(legacyChoice('cI', tags));
      tags.add(legacyChoice('cv', tags));
      final environmentCount = literalChoice(const [
        (2, 15),
        (3, 50),
        (4, 15),
        (5, 5),
      ]);
      for (var index = 0; index < environmentCount; index++) {
        tags.add(literalChoice(const [('inside', 50), ('outside', 50)]));
        tags.add(legacyChoice('c1', tags));
      }
      final objectCount = literalChoice(const [
        (0, 15),
        (1, 20),
        (2, 15),
        (3, 15),
        (4, 10),
        (5, 5),
      ]);
      for (var index = 0; index < objectCount; index++) {
        tags.add(legacyChoice('c5', tags));
      }
      return [tags.join(', ')];
    }

    String? framing;
    var femaleCount = 0;
    var maleCount = 0;
    var otherCount = 0;
    for (var index = 0; index < personCount; index++) {
      final gender = literalChoice(const [('m', 45), ('f', 45), ('o', 10)]);
      if (gender == 'f') {
        femaleCount++;
      } else if (gender == 'm') {
        maleCount++;
      } else {
        otherCount++;
      }
    }
    tags.add(switch (personCount) {
      1 => 'solo',
      2 => 'duo',
      _ => 'trio',
    });
    if (chance(0.3)) tags.add(legacyChoice('cI', tags));
    if (femaleCount > 0) tags.add('female');
    if (maleCount > 0) tags.add('male');
    if (otherCount > 0) tags.add('ambiguous gender');
    if (chance(0.9)) {
      final background = legacyChoice('ck', tags);
      tags.add(background);
      if (background == 'detailed background' ||
          background == 'amazing background') {
        final environmentCount = literalChoice(const [(1, 50), (2, 20)]);
        tags.add(literalChoice(const [('inside', 50), ('outside', 50)]));
        for (var index = 0; index < environmentCount; index++) {
          tags.add(legacyChoice('c1', tags));
        }
      }
    }
    if (chance(0.3)) tags.add(legacyChoice('cx', tags));
    if (chance(0.7)) {
      framing = legacyChoice('cC', tags);
      if (framing.isNotEmpty) tags.add(framing);
    }

    var containsActualFurry = false;
    final characters = <String>[];
    for (final countAndGender in [
      (femaleCount, 'f'),
      (maleCount, 'm'),
      (otherCount, 'o'),
    ]) {
      for (var index = 0; index < countAndGender.$1; index++) {
        final result = _furryCharacter(countAndGender.$2, framing, personCount);
        if (!result.flags.contains('not_furry')) containsActualFurry = true;
        characters.addAll(result.tags);
      }
    }
    if (!containsActualFurry) characters.insert(0, 'not furry');
    tags.addAll(characters);

    if (chance(0.2)) {
      var objectCount = literalChoice(const [
        (0, 40),
        (1, 20),
        (2, 10),
        (3, 2),
      ]);
      if (personCount == 2) {
        objectCount = literalChoice(const [(0, 30), (1, 20), (2, 5)]);
      }
      if (personCount == 3) {
        objectCount = literalChoice(const [(0, 20), (1, 10)]);
      }
      for (var index = 0; index < objectCount; index++) {
        tags.add(legacyChoice('c5', tags));
      }
    }
    if (chance(0.25)) {
      final effectCount = literalChoice(const [(1, 80), (2, 20)]);
      for (var index = 0; index < effectCount; index++) {
        tags.add(legacyChoice('c4', tags));
      }
    }
    if (chance(0.2)) tags.add(legacyChoice('c2', tags));
    if (chance(0.05)) tags.add(legacyChoice('cw', tags));
    return [_commaStableDeduplicate(tags).join(', ')];
  }

  _FurryCharacter _furryCharacter(
    String gender,
    String? framing,
    int totalCharacterCount,
  ) {
    final tags = <String>[];
    final flags = <String>[];
    final speciesBranch = literalChoice(const [
      ('core', 50),
      ('humanoid', 20),
      ('other', 5),
    ]);
    switch (speciesBranch) {
      case 'core':
        tags.add(legacyChoice('cM', tags));
        if (chance(0.8)) tags.add(legacyChoice('cS', tags));
        break;
      case 'humanoid':
        tags.add('humanoid');
        tags.add(legacyChoice('cD', tags));
        flags.add('not_furry');
        break;
      case 'other':
        tags.add(legacyChoice('cT', tags));
        break;
    }
    final noLegsSpecies = tags.any(
      const {
        'taur',
        'serpentine',
        'naga',
        'centaur',
        'feral',
        'merfolk',
        'lamia',
      }.contains,
    );
    String pick(String group) =>
        legacyChoice(group, tags, legless: noLegsSpecies);
    String pickColored(String group) =>
        _coloredFurryChoice(group, tags, legless: noLegsSpecies);
    if (chance(0.7)) tags.add(pick('cR'));
    if (chance(0.7)) {
      final multicolorType = literalChoice(const [
        ('multicolored body', 50),
        ('two tone body', 30),
        ('rainbow body', 2),
      ]);
      final addSecondColor =
          multicolorType == 'multicolored body' ||
          (multicolorType == 'two tone body' && chance(0.5));
      if (addSecondColor) tags.add(pick('cR'));
      tags.add(multicolorType);
    }
    if (chance(0.7)) tags.add(pick('cP'));
    if (chance(0.05)) tags.add(pick('cz'));
    if (chance(0.1)) tags.add(pick('cq'));

    final notFurry = flags.contains('not_furry');
    if (chance(notFurry ? 0.7 : 0.2)) tags.add(pick('cN'));
    if (chance(notFurry ? 0.5 : 0.1)) tags.add(pick('cL'));
    if (chance(notFurry ? 0.7 : 0.1)) {
      tags.add(pick('cE'));
      if (chance(0.1)) {
        if (chance(0.5)) tags.add(pick('cE'));
        tags.add(pick('cB'));
      }
    }
    if (chance(notFurry ? 0.1 : 0.05)) tags.add(pick('cF'));
    if (chance(notFurry ? 0.1 : 0.05)) tags.add(pick('cO'));

    var breastAdded = false;
    if (gender == 'f') {
      final firstRoll = chance(0.5);
      if (firstRoll && !tags.contains('feral')) {
        tags.add(pick('cV'));
        breastAdded = true;
      }
    }
    if (!breastAdded && gender == 'f' && chance(0.1)) {
      tags.add(pick('cV'));
    }

    final featureCount = _furryCharacterCount(totalCharacterCount);
    for (var index = 0; index < featureCount; index++) {
      tags.add(pick('cU'));
    }
    if (chance(0.15)) {
      tags.add(pick('cW'));
    } else if (chance(0.2)) {
      tags.add(pick(r'c$'));
    }
    String? clothingType = literalChoice(const [
      ('uniform', 10),
      ('swimsuit', 5),
      ('bodysuit', 5),
      ('normal clothes', 40),
    ]);
    if (tags.contains('feral')) {
      if (!chance(0.6)) clothingType = null;
    } else if (chance(0.2)) {
      clothingType = null;
    }
    if (clothingType != null && chance(0.3)) tags.add('furgonomics');
    switch (clothingType) {
      case 'uniform':
        tags.add(pick('cK'));
        break;
      case 'swimsuit':
        tags.add(pick('cJ'));
        break;
      case 'bodysuit':
        tags.add(pick('cZ'));
        break;
      case 'normal clothes':
        final useDress = gender == 'f' && chance(0.2);
        if (useDress) {
          tags.add(pickColored('cH'));
          break;
        }
        if (chance(0.9)) tags.add(pickColored('cX'));
        // Upstream gates only bottoms here; its trailing substring filter
        // misses legwear and footwear values, so all three are gated alike.
        if (!noLegsSpecies) {
          final lowerRoll = chance(0.7);
          if (lowerRoll &&
              framing != null &&
              _furryLegFramings.contains(framing)) {
            tags.add(pickColored('cY'));
          }
          final legwearRoll = chance(0.5);
          if (legwearRoll &&
              framing != null &&
              _furryLegFramings.contains(framing)) {
            tags.add(pickColored('cG'));
          }
          final footwearRoll = chance(0.3);
          if (footwearRoll && framing == 'full-length portrait') {
            tags.add(pickColored('cQ'));
          }
        }
      case null:
        break;
    }
    if (chance(0.6)) tags.add(pick('c3'));
    if (chance(0.4)) tags.add(pick('c6'));
    if (_containsAnyFragment(tags, const ['sleeping', 'zzz', 'eyes closed'])) {
      _removeGroupValues(tags, const ['cP', 'cz', 'cq']);
    }
    final miscCount = _furryCharacterCount(totalCharacterCount, misc: true);
    for (var index = 0; index < miscCount; index++) {
      tags.add(pick('c0'));
    }
    if (noLegsSpecies ||
        (framing != null && !_furryLegFramings.contains(framing))) {
      tags.removeWhere(
        (tag) => tag.contains('legwear') || tag.contains('legs'),
      );
    }
    return _FurryCharacter(tags, flags);
  }

  int _furryCharacterCount(int count, {bool misc = false}) {
    if (misc) {
      if (count == 1) {
        return literalChoice(const [(0, 20), (1, 20), (2, 10), (3, 2)]);
      }
      if (count == 2) {
        return literalChoice(const [(0, 30), (1, 30), (2, 5)]);
      }
      return literalChoice(const [(0, 30), (1, 15)]);
    }
    if (count == 1) {
      return literalChoice(const [(0, 10), (1, 30), (2, 15), (3, 5)]);
    }
    if (count == 2) {
      return literalChoice(const [(0, 20), (1, 40), (2, 10)]);
    }
    return literalChoice(const [(0, 30), (1, 30)]);
  }

  String _coloredFurryChoice(
    String group,
    List<String> tags, {
    required bool legless,
  }) {
    final useColor = chance(0.5);
    final color = legacyChoice('c8', tags, legless: legless);
    final value = legacyChoice(group, tags, legless: legless);
    return useColor ? '$color $value' : value;
  }

  List<String> generateCharacterPrompts() {
    final globalTags = <String>[];
    final state = <String>{};
    final characters = <List<String>>[];
    final personCount = _characterLiteralChoice(const [
      (1, 70),
      (2, 20),
      (3, 7),
      (0, 5),
    ], state);
    if (personCount == 0) {
      globalTags.add('no humans');
      if (chance(0.5)) globalTags.add(characterChoice('dl', state));
      globalTags.add(characterChoice('dn', state));
      final environmentCount = _characterLiteralChoice(const [
        (2, 15),
        (3, 50),
        (4, 15),
        (5, 5),
      ], state);
      for (var index = 0; index < environmentCount; index++) {
        globalTags.add(characterChoice('dz', state));
      }
      var objectCount = _characterLiteralChoice(const [
        (0, 15),
        (1, 10),
        (2, 20),
        (3, 20),
        (4, 20),
        (5, 15),
      ], state);
      objectCount -= personCount;
      if (objectCount < 0) objectCount = 0;
      for (var index = 0; index < objectCount; index++) {
        globalTags.add(characterChoice('dq', state));
      }
      return [globalTags.join(', ')];
    }

    String? framing;
    if (chance(0.5)) globalTags.add(characterChoice('dl', state));
    var femaleCount = 0;
    var maleCount = 0;
    var otherCount = 0;
    for (var index = 0; index < personCount; index++) {
      final gender = _characterLiteralChoice(const [
        ('m', 30),
        ('f', 60),
        ('o', 0),
      ], state);
      if (gender == 'f') {
        femaleCount++;
      } else if (gender == 'm') {
        maleCount++;
      } else {
        otherCount++;
      }
    }
    _prependCharacterCount(globalTags, femaleCount, 'girl', 'girls');
    _prependCharacterCount(globalTags, maleCount, 'boy', 'boys');
    _prependCharacterCount(globalTags, otherCount, 'other', 'others');
    if (chance(0.8)) {
      final background = characterChoice('ds', state);
      globalTags.add(background);
      if (background == 'scenery' && chance(0.5)) {
        final count = randomInt(3, 1);
        for (var index = 0; index < count; index++) {
          globalTags.add(characterChoice('dz', state));
        }
      }
    }
    if (chance(0.3)) globalTags.add(characterChoice('dr', state));
    if (chance(0.7)) {
      framing = characterChoice('di', state);
      if (framing.isNotEmpty) globalTags.add(framing);
    }
    for (final countAndGender in [
      (femaleCount, 'f', 'girl'),
      (maleCount, 'm', 'boy'),
      (otherCount, 'o', 'other'),
    ]) {
      for (var index = 0; index < countAndGender.$1; index++) {
        characters.add([
          countAndGender.$3,
          ..._characterPromptCharacter(
            state,
            countAndGender.$2,
            framing,
            personCount,
          ),
        ]);
      }
    }
    if (chance(0.2)) {
      var objectCount = randomInt(4);
      if (personCount == 2) objectCount = randomInt(3);
      for (var index = 0; index < objectCount; index++) {
        globalTags.add(characterChoice('dq', state));
      }
    }
    if (chance(0.25)) {
      final effectCount = randomInt(3, 1);
      for (var index = 0; index < effectCount; index++) {
        globalTags.add(characterChoice('dB', state));
      }
    }
    if (chance(0.2)) globalTags.add(characterChoice('dP', state));
    if (chance(0.1)) globalTags.add(characterChoice('da', state));
    final deduplicated = _commaStableDeduplicate(
      globalTags,
    ).where((tag) => tag.isNotEmpty).toList();
    return [
      deduplicated.join(', '),
      ...characters.map((tags) => tags.join(', ')),
    ];
  }

  List<String> _characterPromptCharacter(
    Set<String> globalState,
    String gender,
    String? framing,
    int totalCharacterCount,
  ) {
    final tags = <String>[];
    final state = _initialCharacterState(globalState, gender);
    if (chance(0.1)) tags.add(characterChoice('dc', state));
    _dropLegFlagsForLeglessBody(state);
    if (chance(0.4)) tags.add(characterChoice('dd', state));
    if (chance(0.05)) tags.add(characterChoice('dh', state));
    // "no eyes" declares the noeyes flag; upstream checks the tag text instead.
    if (!state.contains('noeyes')) {
      if (chance(0.2)) tags.add(characterChoice('du', state));
      final eyeColorRoll = chance(0.8);
      if (eyeColorRoll && !state.contains('nocoloreyes')) {
        tags.add(characterChoice('dN', state));
      }
    }
    if (chance(0.8)) tags.add(characterChoice('dp', state));
    if (chance(0.7)) tags.add(characterChoice('dg', state));
    if (chance(0.7)) tags.add(characterChoice('dL', state));
    if (chance(0.1)) {
      tags.add(characterChoice('dF', state));
      tags.add(characterChoice('dL', state));
    }
    if (chance(0.3)) tags.add(characterChoice('dm', state));
    if (chance(0.4)) tags.add(characterChoice('df', state));
    if (gender.startsWith('f') && chance(0.8)) {
      tags.add(characterChoice('dy', state));
    }
    final featureCount = _characterPromptCount(totalCharacterCount, state);
    for (var index = 0; index < featureCount; index++) {
      tags.add(characterChoice('d_', state));
    }
    if (chance(0.2)) {
      tags.add(characterChoice('db', state));
      if (chance(0.2)) tags.add(characterChoice('dw', state));
    } else if (chance(0.3)) {
      tags.add(characterChoice('dx', state));
    }
    final clothingType = _characterLiteralChoice(const [
      ('uniform', 25),
      ('swimsuit', 5),
      ('bodysuit', 5),
      ('normal clothes', 40),
    ], state);
    var feetCovered = false;
    switch (clothingType) {
      case 'uniform':
        tags.add(characterChoice('dM', state));
        break;
      case 'swimsuit':
        tags.add(characterChoice('dD', state));
        break;
      case 'bodysuit':
        tags.add(characterChoice('dS', state));
        break;
      case 'normal clothes':
        feetCovered = _dressInSeparates(tags, state, gender);
        break;
    }
    _markBarefoot(state, feetCovered: feetCovered);
    if (chance(0.6)) tags.add(characterChoice('dR', state));
    if (chance(0.4)) tags.add(characterChoice('dE', state));
    final miscCount = _characterPromptCount(totalCharacterCount, state);
    for (var index = 0; index < miscCount; index++) {
      tags.add(characterChoice('dT', state));
    }
    return tags.where((tag) => tag.isNotEmpty).toList(growable: false);
  }

  /// Returns whether footwear or legwear hiding the toes was drawn.
  bool _dressInSeparates(List<String> tags, Set<String> state, String gender) {
    final legwear = <String>[];
    if (gender.startsWith('f') && chance(0.5)) {
      legwear.add(characterChoice('dk', state));
      if (chance(0.2)) legwear.add(characterChoice('dC', state));
      tags.addAll(legwear);
    }
    var wearsFootwear = false;
    final useDress = gender.startsWith('f') && chance(0.2);
    if (useDress) {
      final value = _coloredCharacterChoice('dv', state);
      if (value.isNotEmpty) tags.add(value);
    } else {
      if (chance(0.85)) {
        final value = _coloredCharacterChoice('dj', state);
        if (value.isNotEmpty) tags.add(value);
      }
      if (state.contains('legs')) {
        if (chance(0.85)) {
          final value = _coloredCharacterChoice('dA', state);
          if (value.isNotEmpty) tags.add(value);
        }
        if (state.contains('feet') && chance(0.6)) {
          final value = _coloredCharacterChoice('dI', state);
          if (value.isNotEmpty) tags.add(value);
          wearsFootwear = value.isNotEmpty;
        }
      }
    }
    return wearsFootwear || _legwearHidesToes(legwear);
  }

  int _characterPromptCount(int count, Set<String> state) {
    if (count == 1) {
      return _characterLiteralChoice(const [
        (0, 10),
        (1, 30),
        (2, 15),
        (3, 5),
      ], state);
    }
    if (count == 2) {
      return _characterLiteralChoice(const [(0, 20), (1, 40), (2, 10)], state);
    }
    return _characterLiteralChoice(const [(0, 30), (1, 30)], state);
  }

  T _characterLiteralChoice<T>(List<(T, int)> entries, Set<String> state) {
    final totalWeight = entries.fold<int>(
      0,
      (total, entry) => total + entry.$2,
    );
    final ticket = randomInt(totalWeight, 1);
    var cumulative = 0;
    for (final entry in entries) {
      cumulative += entry.$2;
      if (ticket <= cumulative) return entry.$1;
    }
    throw StateError('Official Character Prompt choice exhausted unexpectedly');
  }

  String _coloredCharacterChoice(String group, Set<String> state) {
    final useColor = chance(0.5);
    final color = characterChoice('dO', state);
    final value = characterChoice(group, state);
    if (value.isEmpty) return '';
    return useColor ? '$color $value' : value;
  }
}

String _selectLegacyRecord(
  List<OfficialWordlistEntry> entries,
  List<String> selectedTags,
  double randomValue, {
  Set<String> blockedTags = const {},
}) {
  final eligible = entries
      .where((entry) {
        if (_joinsBlockedTag(entry, blockedTags)) return false;
        final dependencies = entry.stringFieldValues(2);
        return dependencies.isEmpty || dependencies.any(selectedTags.contains);
      })
      .toList(growable: false);
  final totalWeight = eligible.fold<int>(
    0,
    (total, entry) => total + entry.weight,
  );
  final ticket = (randomValue * (totalWeight - 1)).floor() + 1;
  var cumulative = 0;
  for (final entry in eligible) {
    cumulative += entry.weight;
    if (ticket <= cumulative) return entry.text;
  }
  throw StateError('Official legacy weighted choice exhausted unexpectedly');
}

String _selectCharacterRecord(
  List<OfficialWordlistEntry> entries,
  Set<String> state,
  double randomValue, {
  Set<String> blockedTags = const {},
}) {
  final eligible = entries
      .where((entry) {
        if (_joinsBlockedTag(entry, blockedTags)) return false;
        final excluded = entry.stringFieldValues(4);
        if (excluded.any(state.contains)) return false;
        final required = entry.stringFieldValues(3);
        return required.every(state.contains);
      })
      .toList(growable: false);
  final totalWeight = eligible.fold<int>(
    0,
    (total, entry) => total + entry.weight,
  );
  final ticket = (randomValue * (totalWeight - 1)).floor() + 1;
  var cumulative = 0;
  for (final entry in eligible) {
    cumulative += entry.weight;
    if (ticket <= cumulative) {
      // Upstream re-adds field 3 here, so no declared flag ever reaches state.
      state.addAll(entry.stringFieldValues(2));
      return entry.text;
    }
  }
  return '';
}

// The asset declares no provider for gender flags and upstream checks gender
// only in code, so each role's own state is seeded from its gender here.
const _characterGenderFlags = {'f': 'female', 'm': 'male'};

Set<String> _initialCharacterState(Set<String> globalState, String gender) {
  final genderFlag = _characterGenderFlags[gender];
  return {...globalState, if (genderFlag != null) genderFlag};
}

// The asset never declares that nolegs cancels the legs/feet flags that
// framing adds to the shared state, so a legless body drops its own copy.
void _dropLegFlagsForLeglessBody(Set<String> state) {
  if (state.contains('nolegs')) state.removeAll(const {'legs', 'feet'});
}

// The asset requires barefoot for toenail polish, yet nothing provides it.
void _markBarefoot(Set<String> state, {required bool feetCovered}) {
  if (state.contains('feet') && !feetCovered) state.add('barefoot');
}

// No legwear record declares toe coverage; only a named opening uncovers toes.
bool _legwearHidesToes(List<String> legwear) =>
    legwear.any((value) => value.isNotEmpty) &&
    !legwear.any((value) => _toeOpenings.any(value.contains));

const _toeOpenings = ['toeless', 'stirrup'];

bool _joinsBlockedTag(OfficialWordlistEntry entry, Set<String> blockedTags) =>
    blockedTags.isNotEmpty && entry.text.split(', ').any(blockedTags.contains);

bool _containsAnyFragment(List<String> tags, List<String> fragments) =>
    tags.any((tag) => fragments.any(tag.contains));

void _prependCharacterCount(
  List<String> tags,
  int count,
  String singular,
  String plural,
) {
  if (count == 1) {
    tags.insert(0, '1$singular');
  } else if (count > 1) {
    tags.insert(0, '$count$plural');
  }
}

List<String> _commaStableDeduplicate(List<String> tags) {
  final seen = <String>{};
  final result = <String>[];
  for (final tag in tags.join(', ').split(', ')) {
    if (seen.add(tag)) result.add(tag);
  }
  return result;
}

const _legClothingGroups = {
  'legacyAnime': ['l9', 'ce', 'l4'],
  'furryV3': ['cY', 'cQ', 'cG'],
  'characterPrompts': ['dA', 'dI', 'dk'],
};

const _furryLegFramings = {
  'half-length portrait',
  'three-quarter length portrait',
  'full-length portrait',
};

class _FurryCharacter {
  const _FurryCharacter(this.tags, this.flags);

  final List<String> tags;
  final List<String> flags;
}
