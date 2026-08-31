import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_slash_syntax.dart';

TextEditingValue _value(String text, {int? caret, TextRange? composing}) =>
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret ?? text.length),
      composing: composing ?? TextRange.empty,
    );

void main() {
  group('parseSlashQuery', () {
    test('opens on a bare slash at the start', () {
      final query = parseSlashQuery(_value('/'));
      expect(query, isNotNull);
      expect(query!.query, isEmpty);
      expect(query.end, 1);
    });

    test('captures the name being typed', () {
      final query = parseSlashQuery(_value('/art-pro'));
      expect(query!.query, 'art-pro');
      expect(query.end, 8);
    });

    test('accepts a full-width slash from a CJK IME', () {
      expect(parseSlashQuery(_value('／art'))!.query, 'art');
    });

    test('ignores a slash that is not at the very start', () {
      expect(parseSlashQuery(_value('hello /art')), isNull);
      expect(parseSlashQuery(_value(' /art')), isNull);
    });

    test('closes once the caret leaves the token', () {
      expect(parseSlashQuery(_value('/art draw a cat')), isNull);
      expect(parseSlashQuery(_value('/art draw', caret: 4)), isNotNull);
      expect(parseSlashQuery(_value('/art', caret: 0)), isNull);
    });

    test('stops the token at a second slash so paths do not open the menu', () {
      expect(parseSlashQuery(_value('/usr/local/bin')), isNull);
      expect(parseSlashQuery(_value('/usr/local/bin', caret: 4))!.query, 'usr');
    });

    test('stays closed while the IME is composing', () {
      expect(
        parseSlashQuery(
          _value('/技能', composing: const TextRange(start: 1, end: 3)),
        ),
        isNull,
      );
    });

    test('stays closed for a range selection', () {
      expect(
        parseSlashQuery(
          const TextEditingValue(
            text: '/art',
            selection: TextSelection(baseOffset: 1, extentOffset: 4),
          ),
        ),
        isNull,
      );
    });
  });

  group('parseLeadingSlashToken', () {
    test('splits the name from the rest of the message', () {
      final token = parseLeadingSlashToken('/art-prompt  draw a cat');
      expect(token!.name, 'art-prompt');
      expect(token.trailingText, 'draw a cat');
    });

    test('reports an empty trailing text for a bare command', () {
      expect(parseLeadingSlashToken('/new')!.trailingText, isEmpty);
    });

    test('returns null without a name', () {
      expect(parseLeadingSlashToken('/'), isNull);
      expect(parseLeadingSlashToken('/ hello'), isNull);
      expect(parseLeadingSlashToken('hello'), isNull);
      expect(parseLeadingSlashToken(''), isNull);
    });

    test('keeps newlines in the trailing text usable', () {
      final token = parseLeadingSlashToken('/art\ndraw a cat');
      expect(token!.name, 'art');
      expect(token.trailingText, 'draw a cat');
    });
  });
}
