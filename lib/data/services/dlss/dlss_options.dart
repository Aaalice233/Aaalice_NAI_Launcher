class DlssOptions {
  const DlssOptions({
    this.style = 'default',
    this.intensity = 1,
    this.localStructure = 1,
    this.localTone = 1,
    this.detail = 1,
    this.color = 1,
  });
  final String style;
  final double intensity;
  final double localStructure;
  final double localTone;
  final double detail;
  final double color;

  DlssOptions copyWith({
    String? style,
    double? intensity,
    double? localStructure,
    double? localTone,
    double? detail,
    double? color,
  }) => DlssOptions(
    style: style ?? this.style,
    intensity: intensity ?? this.intensity,
    localStructure: localStructure ?? this.localStructure,
    localTone: localTone ?? this.localTone,
    detail: detail ?? this.detail,
    color: color ?? this.color,
  );

  Map<String, dynamic> toJson() => {
    'style': style,
    'intensity': intensity,
    'localStructure': localStructure,
    'localTone': localTone,
    'detail': detail,
    'color': color,
  };

  factory DlssOptions.fromJson(Map<String, dynamic> json) {
    final value = DlssOptions(
      style: json['style'] as String? ?? 'default',
      intensity: (json['intensity'] as num?)?.toDouble() ?? 1,
      localStructure: (json['localStructure'] as num?)?.toDouble() ?? 1,
      localTone: (json['localTone'] as num?)?.toDouble() ?? 1,
      detail: (json['detail'] as num?)?.toDouble() ?? 1,
      color: (json['color'] as num?)?.toDouble() ?? 1,
    );
    value.validate();
    return value;
  }

  void validate() {
    if (!['default', 'natural', 'cinematic'].contains(style) ||
        [
          intensity,
          localStructure,
          localTone,
          detail,
          color,
        ].any((v) => !v.isFinite || v < 0 || v > 1)) {
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
    ];
  }
}
