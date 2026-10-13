import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_image_token_syntax.dart';

TextEditingValue _value(String text, {int? caret, TextSelection? selection}) =>
    TextEditingValue(
      text: text,
      selection:
          selection ?? TextSelection.collapsed(offset: caret ?? text.length),
    );

void main() {
  test('renumbers later references and keeps a trailing caret in range', () {
    final result = removeAgentChatImageToken(_value('[image1] [image2] '), 1);

    expect(result.text, '[image1] ');
    expect(result.selection, const TextSelection.collapsed(offset: 9));
    expect(result.composing, TextRange.empty);
  });

  test('maps a caret placed after the removed reference', () {
    const text = 'a [image1] b [image2] c';
    final result = removeAgentChatImageToken(
      _value(text, caret: text.indexOf('b') + 1),
      1,
    );

    expect(result.text, 'a b [image1] c');
    expect(result.selection, const TextSelection.collapsed(offset: 3));
  });

  test('maps a caret inside the removed reference to its start', () {
    final result = removeAgentChatImageToken(
      _value('hi [image1] there', caret: 6),
      1,
    );

    expect(result.text, 'hi there');
    expect(result.selection, const TextSelection.collapsed(offset: 3));
  });

  test('maps both ends of a range selection across renumbering', () {
    const text = 'x [image1] y [image12] z';
    final result = removeAgentChatImageToken(
      _value(
        text,
        selection: TextSelection(
          baseOffset: text.indexOf('y'),
          extentOffset: text.length,
        ),
      ),
      1,
    );

    expect(result.text, 'x y [image11] z');
    expect(
      result.selection,
      TextSelection(baseOffset: 2, extentOffset: result.text.length),
    );
  });

  test('keeps user spacing, indentation and line breaks around it', () {
    const text = 'keep  two\n    indented [image1]\n[image2] next';
    final first = removeAgentChatImageToken(_value(text), 1);
    expect(first.text, 'keep  two\n    indented\n[image1] next');

    final second = removeAgentChatImageToken(_value(first.text), 1);
    expect(second.text, 'keep  two\n    indented\nnext');
  });

  test('removes every duplicate of the reference without overlapping', () {
    final result = removeAgentChatImageToken(_value('[image1] [image1]'), 1);

    expect(result.text, '');
    expect(result.selection, const TextSelection.collapsed(offset: 0));
  });

  test('leaves a draft without the reference untouched', () {
    final value = _value('plain [image1]', caret: 3);
    final result = removeAgentChatImageToken(value, 2);

    expect(result.text, value.text);
    expect(result.selection, value.selection);
  });
}
