import 'dart:typed_data';

class DlssOptions {
  static const maximumStrength = 3.4028234663852886e38;
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
    this.scale = 2,
    this.passes = 1,
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
  final double scale;
  final int passes;

  // The native CLI parses scale as float32 before calculating target dimensions.
  double get nativeScale => (Float32List(1)..[0] = scale)[0];

  (int, int) targetSize(int width, int height) {
    validate();
    final targetWidth = (width * nativeScale).round();
    final targetHeight = (height * nativeScale).round();
    if (width < 1 ||
        height < 1 ||
        targetWidth < 1 ||
        targetHeight < 1 ||
        targetWidth > 16384 ||
        targetHeight > 16384) {
      throw const FormatException(
        'DLSS output exceeds the D3D12 texture limit (16384 pixels per dimension)',
      );
    }
    return (targetWidth, targetHeight);
  }

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
    double? scale,
    int? passes,
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
    scale: scale ?? this.scale,
    passes: passes ?? this.passes,
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
    'scale': scale,
    'passes': passes,
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
      scale: (json['scale'] as num?)?.toDouble() ?? 2,
      passes: json['passes'] as int? ?? 1,
    );
    value.validate();
    return value;
  }

  void validate() {
    // The CLI forwards strengths as float32; the upstream slider maximum is not
    // an engine limit. Colour remains a blend factor between its two endpoints.
    if (!['default', 'natural', 'cinematic'].contains(style) ||
        !scale.isFinite ||
        scale < 1 ||
        scale > 16384 ||
        passes < 1 ||
        preset < 0 ||
        preset > 3 ||
        [skin, globalTone].any((v) => !_validStrength(v, -1)) ||
        [
          intensity,
          localStructure,
          localTone,
          detail,
        ].any((v) => !_validStrength(v, 0)) ||
        !color.isFinite ||
        color < 0 ||
        color > 1) {
      throw const FormatException('Invalid DLSS enhancement parameters');
    }
  }

  static bool _validStrength(double value, double minimum) =>
      value.isFinite && value >= minimum && value <= maximumStrength;

  List<String> get arguments {
    validate();
    return [
      '--nr-scale',
      '$scale',
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
