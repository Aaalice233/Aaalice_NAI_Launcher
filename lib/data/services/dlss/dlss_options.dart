class DlssOptions {
  const DlssOptions({
    this.style = 'cinematic',
    this.intensity = 1,
    this.localStructure = 1,
    this.localTone = 1,
    this.detail = 1,
    this.color = 1,
    this.preset = 0,
    this.skin = -1,
    this.globalTone = -1,
    this.autoMask = false,
    this.uiCorrection = false,
  });
  final String style;
  final double intensity;
  final double localStructure;
  final double localTone;
  final double detail;
  final double color;
  final int preset;
  final double skin;
  final double globalTone;
  final bool autoMask;
  final bool uiCorrection;

  DlssOptions copyWith({
    String? style,
    double? intensity,
    double? localStructure,
    double? localTone,
    double? detail,
    double? color,
    int? preset,
    double? skin,
    double? globalTone,
    bool? autoMask,
    bool? uiCorrection,
  }) => DlssOptions(
    style: style ?? this.style,
    intensity: intensity ?? this.intensity,
    localStructure: localStructure ?? this.localStructure,
    localTone: localTone ?? this.localTone,
    detail: detail ?? this.detail,
    color: color ?? this.color,
    preset: preset ?? this.preset,
    skin: skin ?? this.skin,
    globalTone: globalTone ?? this.globalTone,
    autoMask: autoMask ?? this.autoMask,
    uiCorrection: uiCorrection ?? this.uiCorrection,
  );

  Map<String, dynamic> toJson() => {
    'style': style,
    'intensity': intensity,
    'localStructure': localStructure,
    'localTone': localTone,
    'detail': detail,
    'color': color,
    'preset': preset,
    'skin': skin,
    'globalTone': globalTone,
    'autoMask': autoMask,
    'uiCorrection': uiCorrection,
  };

  factory DlssOptions.fromJson(Map<String, dynamic> json) {
    final value = DlssOptions(
      style: json['style'] as String? ?? 'cinematic',
      intensity: (json['intensity'] as num?)?.toDouble() ?? 1,
      localStructure: (json['localStructure'] as num?)?.toDouble() ?? 1,
      localTone: (json['localTone'] as num?)?.toDouble() ?? 1,
      detail: (json['detail'] as num?)?.toDouble() ?? 1,
      color: (json['color'] as num?)?.toDouble() ?? 1,
      preset: json['preset'] as int? ?? 0,
      skin: (json['skin'] as num?)?.toDouble() ?? -1,
      globalTone: (json['globalTone'] as num?)?.toDouble() ?? -1,
      autoMask: json['autoMask'] as bool? ?? false,
      uiCorrection: json['uiCorrection'] as bool? ?? false,
    );
    value.validate();
    return value;
  }

  void validate() {
    // Ranges follow v1.3 app.py; they are UI limits, not a claimed SDK limit.
    if (!['default', 'natural', 'cinematic'].contains(style) ||
        preset < 0 ||
        preset > 3 ||
        [skin, globalTone].any((v) => !v.isFinite || v < -1 || v > 2) ||
        [
          intensity,
          localStructure,
          localTone,
          detail,
        ].any((v) => !v.isFinite || v < 0 || v > 2) ||
        !color.isFinite ||
        color < 0 ||
        color > 1) {
      throw const FormatException('Invalid DLSS enhancement parameters');
    }
  }

  List<String> get arguments {
    validate();
    return [
      '--nr-style',
      '${['default', 'natural', 'cinematic'].indexOf(style)}',
      '--nr-intensity',
      '$intensity',
      '--nr-local-structure',
      '$localStructure',
      '--nr-local-tone',
      '$localTone',
      '--nr-detail',
      '$detail',
      '--nr-color',
      '$color',
      '--nr-preset',
      '$preset',
      '--nr-skin',
      '$skin',
      '--nr-global-tone',
      '$globalTone',
      '--nr-ui-correction',
      uiCorrection ? '1' : '0',
      if (autoMask) '--nr-auto-mask',
    ];
  }
}
