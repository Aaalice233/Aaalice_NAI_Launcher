import 'dart:typed_data';

class DlssOptions {
  static const maximumStrength = 3.4028234663852886e38;
  const DlssOptions({
    this.style = 'cinematic',
    this.intensity = 1,
    this.localStructure = 1.2,
    this.localTone = 1.8,
    this.detail = 1.1,
    this.color = 0.25,
    this.skin = 1.2,
    this.autoMask = true,
    this.scale = 2,
  });
  final String style;
  final double intensity;
  final double localStructure;
  final double localTone;
  final double detail;
  final double color;
  final double skin;
  final bool autoMask;
  final double scale;

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
    double? skin,
    bool? autoMask,
    double? scale,
  }) => DlssOptions(
    style: style ?? this.style,
    intensity: intensity ?? this.intensity,
    localStructure: localStructure ?? this.localStructure,
    localTone: localTone ?? this.localTone,
    detail: detail ?? this.detail,
    color: color ?? this.color,
    skin: skin ?? this.skin,
    autoMask: autoMask ?? this.autoMask,
    scale: scale ?? this.scale,
  );

  Map<String, dynamic> toJson() => {
    'style': style,
    'intensity': intensity,
    'localStructure': localStructure,
    'localTone': localTone,
    'detail': detail,
    'color': color,
    'skin': skin,
    'autoMask': autoMask,
    'scale': scale,
  };

  factory DlssOptions.fromJson(Map<String, dynamic> json) {
    const defaults = DlssOptions();
    final savedIntensity =
        (json['intensity'] as num?)?.toDouble() ?? defaults.intensity;
    // Older presets allowed values above one; preserve their saturated effect.
    final intensity = savedIntensity.isFinite && savedIntensity > 1
        ? 1.0
        : savedIntensity;
    final value = DlssOptions(
      style: json['style'] as String? ?? defaults.style,
      intensity: intensity,
      localStructure:
          (json['localStructure'] as num?)?.toDouble() ??
          defaults.localStructure,
      localTone: (json['localTone'] as num?)?.toDouble() ?? defaults.localTone,
      detail: (json['detail'] as num?)?.toDouble() ?? defaults.detail,
      color: (json['color'] as num?)?.toDouble() ?? defaults.color,
      skin: (json['skin'] as num?)?.toDouble() ?? defaults.skin,
      autoMask: json['autoMask'] as bool? ?? defaults.autoMask,
      scale: (json['scale'] as num?)?.toDouble() ?? defaults.scale,
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
        intensity > 1 ||
        !_validStrength(skin, -1) ||
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
      '--style',
      '${['default', 'natural', 'cinematic'].indexOf(style)}',
      '--intensity',
      '$intensity',
      '--structure',
      '$localStructure',
      '--tone',
      '$localTone',
      '--skin',
      '$skin',
      '--auto-mask',
      autoMask ? '1' : '0',
    ];
  }
}
