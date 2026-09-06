import 'dart:convert';

import 'dlss_options.dart';

class DlssPreset {
  const DlssPreset({
    required this.id,
    required this.options,
    this.name,
    this.builtIn = false,
  });
  final String id;
  final String? name;
  final DlssOptions options;
  final bool builtIn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'options': options.toJson(),
  };

  factory DlssPreset.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = (json['name'] as String).trim();
    if (id.isEmpty ||
        name.isEmpty ||
        DlssPresetState.builtIns.any((preset) => preset.id == id)) {
      throw const FormatException('Invalid custom DLSS preset');
    }
    return DlssPreset(
      id: id,
      name: name,
      options: DlssOptions.fromJson(
        Map<String, dynamic>.from(json['options'] as Map),
      ),
    );
  }
}

/// The draft and its selected preset travel together in the existing portable
/// settings value. Built-ins stay in code and cannot be replaced by imported data.
class DlssPresetState {
  DlssPresetState({
    this.options = const DlssOptions(),
    this.selectedId = defaultId,
    List<DlssPreset> customPresets = const [],
  }) : customPresets = List.unmodifiable(customPresets);

  static const defaultId = 'color-light';
  // Keep stable IDs and explicit color values so saved selections and the other
  // presets retain their effects when the preferred default changes.
  static const builtIns = [
    DlssPreset(id: defaultId, options: DlssOptions(), builtIn: true),
    DlssPreset(
      id: 'material-light',
      builtIn: true,
      options: DlssOptions(
        localStructure: 1.8,
        localTone: 1.4,
        globalTone: 1.3,
        skin: 1,
        detail: 1,
        color: 0.65,
      ),
    ),
    DlssPreset(
      id: 'soft-light',
      builtIn: true,
      options: DlssOptions(intensity: 1.1, detail: 0.8, color: 1),
    ),
    DlssPreset(
      id: 'natural-light',
      builtIn: true,
      options: DlssOptions(style: 'natural', color: 1),
    ),
    DlssPreset(
      id: 'cinematic-soft',
      builtIn: true,
      options: DlssOptions(
        localTone: 1.3,
        globalTone: 1.2,
        detail: 0.9,
        color: 1,
      ),
    ),
    DlssPreset(
      id: 'crisp-light',
      builtIn: true,
      options: DlssOptions(localStructure: 1.6, detail: 1.2, color: 1),
    ),
    DlssPreset(
      id: 'cinematic-light',
      builtIn: true,
      options: DlssOptions(color: 1),
    ),
  ];

  final DlssOptions options;
  final String selectedId;
  final List<DlssPreset> customPresets;
  List<DlssPreset> get presets => [...builtIns, ...customPresets];
  DlssPreset get selected =>
      presets.where((p) => p.id == selectedId).firstOrNull ?? builtIns.first;
  bool get modified =>
      jsonEncode(options.toJson()) != jsonEncode(selected.options.toJson());

  DlssPresetState withOptions(DlssOptions value) {
    value.validate();
    return DlssPresetState(
      options: value,
      selectedId: selectedId,
      customPresets: customPresets,
    );
  }

  DlssPresetState select(String id) {
    final preset = presets.firstWhere((preset) => preset.id == id);
    return DlssPresetState(
      options: preset.options,
      selectedId: id,
      customPresets: customPresets,
    );
  }

  bool nameAvailable(String name, {String? exceptId}) =>
      name.trim().isNotEmpty &&
      !customPresets.any(
        (preset) =>
            preset.id != exceptId &&
            preset.name!.toLowerCase() == name.trim().toLowerCase(),
      );

  DlssPresetState create(String id, String name) {
    if (presets.any((preset) => preset.id == id) ||
        id.isEmpty ||
        !nameAvailable(name)) {
      throw const FormatException(
        'DLSS preset name or ID is invalid or already exists',
      );
    }
    return DlssPresetState(
      options: options,
      selectedId: id,
      customPresets: [
        ...customPresets,
        DlssPreset(id: id, name: name.trim(), options: options),
      ],
    );
  }

  DlssPresetState update(String id, {String? name, bool saveOptions = false}) {
    final preset = _custom(id);
    if (name != null && !nameAvailable(name, exceptId: id)) {
      throw const FormatException(
        'DLSS preset name is empty or already exists',
      );
    }
    final updated = DlssPreset(
      id: id,
      name: name?.trim() ?? preset.name,
      options: saveOptions ? options : preset.options,
    );
    return DlssPresetState(
      options: options,
      selectedId: selectedId,
      customPresets: [
        for (final entry in customPresets) entry.id == id ? updated : entry,
      ],
    );
  }

  DlssPresetState remove(String id) {
    _custom(id);
    return DlssPresetState(
      options: options,
      selectedId: selectedId == id ? defaultId : selectedId,
      customPresets: customPresets.where((preset) => preset.id != id).toList(),
    );
  }

  DlssPreset _custom(String id) => customPresets.firstWhere(
    (preset) => preset.id == id,
    orElse: () =>
        throw StateError('Built-in DLSS presets cannot be changed or removed'),
  );

  Map<String, dynamic> toJson() => {
    ...options.toJson(),
    'selectedPresetId': selectedId,
    'customPresets': customPresets.map((preset) => preset.toJson()).toList(),
  };

  factory DlssPresetState.fromJson(Map<String, dynamic> json) {
    final custom = (json['customPresets'] as List? ?? const [])
        .map(
          (entry) =>
              DlssPreset.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    if (custom.map((preset) => preset.id).toSet().length != custom.length ||
        custom.map((preset) => preset.name!.toLowerCase()).toSet().length !=
            custom.length) {
      throw const FormatException('Duplicate custom DLSS presets');
    }
    return DlssPresetState(
      options: DlssOptions.fromJson(json),
      selectedId: json['selectedPresetId'] as String? ?? defaultId,
      customPresets: custom,
    );
  }
}
