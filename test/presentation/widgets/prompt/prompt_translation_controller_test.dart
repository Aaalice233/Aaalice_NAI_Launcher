import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_translation_controller.dart';

void main() {
  testWidgets(
    'assistant translations refresh missing captions and beat stale lookup',
    (tester) async {
      final slow = Completer<Map<String, String>>();
      final lookup = TagTranslationLookup.fromResolver((_) => slow.future);
      final controller = PromptTranslationController(lookup);
      addTearDown(controller.dispose);
      controller.update(['a bird rests on the branch'], immediate: true);
      lookup.addTranslations({'a_bird_rests_on_the_branch': '一只鸟停在树枝上'});
      expect(controller.values['a bird rests on the branch']!.text, '一只鸟停在树枝上');
      slow.complete({});
      await tester.pump();
      expect(controller.values['a bird rests on the branch']!.text, '一只鸟停在树枝上');
      expect(await lookup.translate('a bird rests on the branch'), '一只鸟停在树枝上');
      controller.update(['dog'], composing: true);
      lookup.addTranslations({'a_bird_rests_on_the_branch': '鸟停在树枝上'});
      expect(controller.values.keys, ['dog']);
    },
  );

  testWidgets(
    'assistant fills an already missing caption without changing input',
    (tester) async {
      final lookup = TagTranslationLookup.fromResolver((_) async => {});
      final controller = PromptTranslationController(lookup);
      addTearDown(controller.dispose);
      controller.update(['unknown'], immediate: true);
      await tester.pump();
      expect(
        controller.values['unknown']!.status,
        PromptTranslationStatus.missing,
      );
      lookup.addTranslations({'unknown': '补充翻译'});
      expect(controller.values['unknown']!.text, '补充翻译');
    },
  );
  testWidgets(
    'editing one tag keeps completed and missing entries and pending requests',
    (tester) async {
      final requests = <List<String>>[];
      final slow = Completer<Map<String, String>>();
      final controller = PromptTranslationController(
        TagTranslationLookup.fromResolver((tags) {
          requests.add(tags);
          if (tags.contains('slow')) return slow.future;
          return Future.value({
            for (final tag in tags.where((tag) => tag != 'missing'))
              tag: '译文 $tag',
          });
        }),
      );
      addTearDown(controller.dispose);
      controller.update(['cat', 'missing'], immediate: true);
      await tester.pump();
      final cat = controller.values['cat'];
      final missing = controller.values['missing'];
      controller.update(['cat', 'missing', 'slow'], immediate: true);
      controller.update(['cat', 'missing', 'slow', 'dog'], immediate: true);
      await tester.pump();
      expect(controller.values['cat'], same(cat));
      expect(controller.values['missing'], same(missing));
      expect(
        controller.values['missing']!.status,
        PromptTranslationStatus.missing,
      );
      expect(requests, [
        ['cat', 'missing'],
        ['slow'],
        ['dog'],
      ]);
      slow.complete({'slow': '慢'});
      await tester.pump();
      expect(controller.values['slow']!.text, '慢');
      expect(controller.values['dog']!.text, '译文 dog');
      expect(controller.values['cat'], same(cat));
    },
  );
  testWidgets(
    'debounces committed input, deduplicates and rejects stale responses',
    (tester) async {
      final requests = <String, Completer<Map<String, String>>>{};
      final controller = PromptTranslationController(
        TagTranslationLookup.fromResolver((tags) {
          final request = Completer<Map<String, String>>();
          requests[tags.join(',')] = request;
          return request.future;
        }),
      );
      addTearDown(controller.dispose);
      controller.update(['cat', 'cat'], immediate: true);
      await tester.pump();
      controller.update(['dog'], composing: true);
      await tester.pump(const Duration(milliseconds: 200));
      expect(requests.keys, ['cat']);
      requests['cat']!.complete({'cat': '猫'});
      await tester.pump();
      expect(controller.values.keys, ['dog']);
      expect(controller.values['dog']!.status, PromptTranslationStatus.pending);
      controller.update(['dog']);
      await tester.pump(const Duration(milliseconds: 149));
      expect(requests.containsKey('dog'), isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      requests['dog']!.complete({'dog': '狗'});
      await tester.pump();
      expect(controller.values['dog']!.text, '狗');
    },
  );
  testWidgets('failed lookup can retry and absence has its own status', (
    tester,
  ) async {
    var fail = true;
    final controller = PromptTranslationController(
      TagTranslationLookup.fromResolver((tags) async {
        if (fail) throw StateError('dictionary unavailable');
        return {};
      }),
    );
    addTearDown(controller.dispose);
    controller.update(['missing'], immediate: true);
    await tester.pump();
    expect(
      controller.values['missing']!.status,
      PromptTranslationStatus.failed,
    );
    fail = false;
    controller.retry();
    await tester.pump();
    expect(
      controller.values['missing']!.status,
      PromptTranslationStatus.missing,
    );
  });
}
