import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/dlss/dlss_options.dart';
import 'package:nai_launcher/data/services/dlss/dlss_presets.dart';

void main() {
  test(
    'default uses color preservation with the original vivid preset last',
    () {
      final state = DlssPresetState();
      expect(state.selectedId, DlssPresetState.defaultId);
      expect(state.modified, isFalse);
      expect(state.options.toJson(), {
        'style': 'cinematic',
        'intensity': 1.6,
        'localStructure': 1.2,
        'localTone': 1.8,
        'detail': 1.1,
        'color': 0.25,
        'preset': 0,
        'skin': 1.2,
        'globalTone': 1.6,
        'autoMask': true,
        'uiCorrection': false,
        'scale': 2.0,
        'passes': 1,
      });
      expect(DlssPresetState.builtIns, hasLength(6));
      expect(DlssPresetState.builtIns.first.id, 'color-light');
      expect(DlssPresetState.builtIns.last.id, 'cinematic-light');
      expect(DlssPresetState.builtIns.last.options.color, 1);
      for (final id in ['color-light', 'cinematic-light']) {
        final saved = state
            .select(id)
            .withOptions(const DlssOptions(intensity: 2.2));
        final restored = DlssPresetState.fromJson(saved.toJson());
        expect(restored.selectedId, id);
        expect(restored.options.toJson(), saved.options.toJson());
      }
      for (final preset in DlssPresetState.builtIns) {
        expect(preset.options.validate, returnsNormally);
        expect(
          () => state.update(preset.id, saveOptions: true),
          throwsStateError,
        );
        expect(
          () => state.update(preset.id, name: 'changed'),
          throwsStateError,
        );
        expect(() => state.remove(preset.id), throwsStateError);
      }
    },
  );
  test(
    'variants only change their intended parameters from the D baseline',
    () {
      final baseline = const DlssOptions().toJson();
      const differences = {
        'soft-light': {'intensity', 'detail', 'color'},
        'natural-light': {'style', 'color'},
        'cinematic-soft': {'localTone', 'globalTone', 'detail', 'color'},
        'crisp-light': {'localStructure', 'detail', 'color'},
        'cinematic-light': {'color'},
      };
      for (final preset in DlssPresetState.builtIns.skip(1)) {
        final values = preset.options.toJson();
        expect(
          values.keys.where((key) => values[key] != baseline[key]).toSet(),
          differences[preset.id],
        );
        expect(preset.options.passes, 1);
        expect(preset.options.scale, 2);
      }
    },
  );
  test(
    'custom preset CRUD keeps draft changes separate from saved definitions',
    () {
      final draft = const DlssOptions().copyWith(intensity: 2.3, passes: 2);
      var state = DlssPresetState()
          .withOptions(draft)
          .create('custom-one', '  人像  ');
      expect(state.selected.name, '人像');
      expect(state.modified, isFalse);
      state = state.withOptions(draft.copyWith(localTone: 0.4));
      expect(state.modified, isTrue);
      expect(state.selected.options.localTone, isNot(0.4));
      state = state
          .update('custom-one', saveOptions: true)
          .update('custom-one', name: '场景');
      expect(state.selected.options.localTone, 0.4);
      expect(state.selected.name, '场景');
      expect(state.modified, isFalse);
      state = state.remove('custom-one');
      expect(state.customPresets, isEmpty);
      expect(state.selectedId, DlssPresetState.defaultId);
      expect(state.options.localTone, 0.4);
      expect(state.modified, isTrue);
      state = state.select(DlssPresetState.defaultId);
      expect(state.options.toJson(), const DlssOptions().toJson());
    },
  );
  test(
    'selection, unsaved preset edits, and custom definitions round-trip together',
    () {
      final state = DlssPresetState()
          .create('my-id', '我的预设')
          .withOptions(const DlssOptions(scale: 1, passes: 3));
      final restored = DlssPresetState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), state.toJson());
      expect(restored.selectedId, 'my-id');
      expect(restored.modified, isTrue);
      // Plain parameter readers can still recover the current draft.
      expect(
        DlssOptions.fromJson(state.toJson()).toJson(),
        state.options.toJson(),
      );
      final optionsOnly = DlssPresetState.fromJson(
        const DlssOptions(style: 'natural', scale: 1).toJson(),
      );
      expect(optionsOnly.options.style, 'natural');
      expect(optionsOnly.options.scale, 1);
    },
  );
  test(
    'imports cannot replace built-ins or introduce duplicate identities',
    () {
      final state = DlssPresetState().create('my-id', 'Texture');
      expect(() => state.create('other', 'texture'), throwsFormatException);
      expect(() => state.create('other', ' '), throwsFormatException);
      final malicious = state.toJson();
      malicious['customPresets'] = [
        {
          'id': DlssPresetState.defaultId,
          'name': 'Override',
          'options': const DlssOptions().toJson(),
        },
      ];
      expect(() => DlssPresetState.fromJson(malicious), throwsFormatException);
      final duplicate = state.toJson();
      duplicate['customPresets'] = [
        state.selected.toJson(),
        state.selected.toJson(),
      ];
      expect(() => DlssPresetState.fromJson(duplicate), throwsFormatException);
    },
  );
}
