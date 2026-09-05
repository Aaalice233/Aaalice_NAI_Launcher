import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/prompt_edit_document.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_commands.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_session.dart';

void main() {
  late TextEditingController source;
  late TagEditorSession session;
  void create(String text) {
    source = TextEditingController(text: text);
    session = TagEditorSession(source);
    addTearDown(() {
      session.dispose();
      source.dispose();
    });
  }

  test('selecting all group leaves changes only the enclosing wrapper', () {
    create('1.20::cat, 0.80::dog::::, bird');
    final ids = session.tags.first.leaves.map((tag) => tag.id).toList();
    session.setSelection(ids);
    final commands = TagEditorCommands(session);
    expect(commands.weight, 1.2);
    commands.adjustWeight(step: 0.05);
    expect(source.text, '1.25::cat, 0.80::dog::::, bird');
    expect(session.selected, ids.toSet());
    commands.adjustWeight(step: 0.05);
    expect(source.text, '1.30::cat, 0.80::dog::::, bird');
    session.undo();
    expect(source.text, '1.25::cat, 0.80::dog::::, bird');
  });

  test('explicit nested group selection preserves other wrapper levels', () {
    create('{{cat, dog}}, bird');
    session.selectGroup(session.tags.first);
    TagEditorCommands(session).adjustWeight(step: 0.05);
    expect(source.text, '1.10::{cat, dog}::, bird');
    TagEditorCommands(session).adjustWeight(step: 0.05);
    expect(source.text, '1.15::{cat, dog}::, bird');
    session.setSelection(session.tags.first.leaves.map((tag) => tag.id));
    TagEditorCommands(session).adjustWeight(step: 0.05);
    expect(source.text, '1.15::1.10::cat, dog::::, bird');
  });

  test('partial and cross-group selections still adjust leaves', () {
    create('{cat, dog}, bird');
    session.setSelection([session.leaves.first.id]);
    TagEditorCommands(session).adjustWeight(step: 0.05);
    expect(source.text, '{1.05::cat::, dog}, bird');
    session.selectAll();
    expect(session.selectedGroup, isNull);
    TagEditorCommands(session).adjustWeight(step: 0.05);
    expect(source.text, '{1.10::cat::, 1.05::dog::}, 1.05::bird::');
  });

  test(
    'editing one repeated weighted tag preserves other bytes and identity',
    () {
      create(' cat , 1.20::cat::, dog\n');
      final ids = session.leaves.map((tag) => tag.id).toList();
      session.edit(ids[1]);
      session.replaceLabel(ids[1], 'kitten');
      expect(source.text, ' cat , 1.20::kitten::, dog\n');
      expect(session.leaves.map((tag) => tag.id), ids);
      session.endEdit();
      session.undo();
      expect(source.text, ' cat , 1.20::cat::, dog\n');
      session.redo();
      expect(source.text, ' cat , 1.20::kitten::, dog\n');
    },
  );
  test(
    'batch weights and disabled markers are single undoable transactions',
    () {
      create('cat, dog');
      session.selectAll();
      TagEditorCommands(session).adjustWeight(step: 0.05);
      expect(source.text, '1.05::cat::, 1.05::dog::');
      session.toggleEnabled(session.selected);
      expect(PromptEditDocument.effectiveText(source.text), '');
      session.undo();
      expect(source.text, '1.05::cat::, 1.05::dog::');
      session.undo();
      expect(source.text, 'cat, dog');
    },
  );
  test(
    'group children stay individually editable without changing group scope',
    () {
      create('1.20::{cat, dog}::, bird');
      expect(session.leaves.map((tag) => tag.span.label), [
        'cat',
        'dog',
        'bird',
      ]);
      final id = session.leaves.elementAt(1).id;
      session.replaceLabel(id, 'wolf');
      expect(source.text, '1.20::{cat, wolf}::, bird');
    },
  );
  test(
    'delete contiguous and disjoint selections without dangling separators',
    () {
      create('a, b, c, d');
      final all = session.leaves.toList();
      session.selected.addAll([all[1].id, all[3].id]);
      session.deleteSelected();
      expect(source.text, 'a, c');
      session.undo();
      session.selectAll();
      session.deleteSelected();
      expect(source.text, '');
    },
  );
  test('move adjacent tags and batches in both directions', () {
    create('a, b, c, d');
    session.select(session.leaves.elementAt(1).id);
    TagEditorCommands(session).move(TagEditorAction.previous);
    expect(source.text, 'b, a, c, d');
    session.undo();
    session.select(session.leaves.elementAt(1).id);
    TagEditorCommands(session).move(TagEditorAction.next);
    expect(source.text, 'a, c, b, d');
  });
  test('text edits and tag edits share history across mode changes', () {
    create('cat');
    source.text = 'dog';
    session.tagMode = true;
    session.selectAll();
    session.toggleEnabled(session.selected);
    session.tagMode = false;
    session.undo();
    expect(source.text, 'dog');
    session.undo();
    expect(source.text, 'cat');
  });
  test('whitespace typed in a label is replaced exactly once', () {
    create('cat, dog');
    final id = session.leaves.first.id;
    session.edit(id);
    session.replaceLabel(id, 'cat ');
    session.replaceLabel(id, 'cat sitting ');
    session.replaceLabel(id, 'cat sitting down');
    expect(source.text, 'cat sitting down, dog');
  });
  test(
    'empty inline drafts remain editable and never become stored placeholders',
    () {
      create('cat, dog');
      final id = session.leaves.first.id;
      session.edit(id);
      session.replaceLabel(id, '');
      expect(source.text, ', dog');
      expect(session.editing, id);
      session.replaceLabel(id, 'bird');
      expect(source.text, 'bird, dog');
    },
  );
  test('composition keeps comma inside one projection until commit', () {
    create('1.2::cat::, dog');
    final id = session.leaves.first.id;
    session.edit(id);
    session.replaceLabel(id, '猫,蓝', composing: true);
    expect(session.leaves, hasLength(2));
    expect(session.byId(id)!.span.label, '猫,蓝');
    session.replaceLabel(id, '猫,蓝');
    session.endEdit();
    expect(source.text, '1.2::猫,蓝::, dog');
    expect(session.leaves, hasLength(3));
  });
  test('repeated moves preserve selection identity and mixed weights', () {
    create('a, 1.2::b::, c, d');
    final id = session.leaves.elementAt(1).id;
    session.select(id);
    final commands = TagEditorCommands(session);
    commands.move(TagEditorAction.next);
    expect(session.selected, {id});
    expect(session.byId(id)!.span.raw, '1.2::b::');
    commands.move(TagEditorAction.next);
    expect(source.text, 'a, c, d, 1.2::b::');
    commands.move(TagEditorAction.first);
    expect(source.text, '1.2::b::, a, c, d');
  });
  test('copy, move and delete retain complete group boundaries', () {
    create('1.2::{cat, dog}::, bird');
    final ids = session.leaves.take(2).map((tag) => tag.id).toSet();
    session.setSelection(ids);
    expect(session.copySelection(), '1.2::{cat, dog}::');
    session.moveSelectedBefore(null);
    expect(source.text, 'bird, 1.2::{cat, dog}::');
    expect(session.selected, ids);
    session.deleteSelected();
    expect(source.text, 'bird');
    session.undo();
    expect(source.text, 'bird, 1.2::{cat, dog}::');
  });
  test('copying part of a group preserves the enclosing weight', () {
    create('1.2::{cat, dog}::, bird');
    session.select(session.leaves.first.id);
    expect(session.copySelection(), '1.2::{cat}::');
  });
  test('long press keeps an already-selected tag in touch multiselect', () {
    create('cat, dog');
    final id = session.leaves.first.id;
    session.select(id);
    session.beginTouchSelection(id);
    expect(session.selected, {id});
    expect(session.touchSelection, isTrue);
    session.select(session.leaves.last.id);
    expect(session.selected, hasLength(2));
  });
}
