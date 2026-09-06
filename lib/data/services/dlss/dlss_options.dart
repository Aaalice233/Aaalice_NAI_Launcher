import 'dart:math' as math;
import 'dart:typed_data';

class DlssOptions {
  static const maximumStrength = 3.4028234663852886e38;
  static const maximumPasses = 3;
  const DlssOptions({
    this.style = 'cinematic',
    this.intensity = 1.6,
    this.localStructure = 1.2,
    this.localTone = 1.8,
    this.detail = 1.1,
    this.color = 0.25,
    this.preset = 0,
    this.skin = 1.2,
    this.globalTone = 1.6,
    this.autoMask = true,
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
    const defaults = DlssOptions();
    final value = DlssOptions(
      style: json['style'] as String? ?? defaults.style,
      intensity: (json['intensity'] as num?)?.toDouble() ?? defaults.intensity,
      localStructure:
          (json['localStructure'] as num?)?.toDouble() ??
          defaults.localStructure,
      localTone: (json['localTone'] as num?)?.toDouble() ?? defaults.localTone,
      detail: (json['detail'] as num?)?.toDouble() ?? defaults.detail,
      color: (json['color'] as num?)?.toDouble() ?? defaults.color,
      preset: json['preset'] as int? ?? defaults.preset,
      skin: (json['skin'] as num?)?.toDouble() ?? defaults.skin,
      globalTone:
          (json['globalTone'] as num?)?.toDouble() ?? defaults.globalTone,
      autoMask: json['autoMask'] as bool? ?? defaults.autoMask,
      uiCorrection: json['uiCorrection'] as bool? ?? defaults.uiCorrection,
      scale: (json['scale'] as num?)?.toDouble() ?? defaults.scale,
      // Older presets allowed unbounded passes. Keep them loadable under the
      // current user-facing limit without changing the remaining parameters.
      passes: math.min(
        json['passes'] as int? ?? defaults.passes,
        maximumPasses,
      ),
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
        passes > maximumPasses ||
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
      '--passes',
      '$passes',
      '--style',
      '${['default', 'natural', 'cinematic'].indexOf(style)}',
      '--intensity',
      '$intensity',
      '--structure',
      '$localStructure',
      '--tone',
      '$localTone',
      '--preset',
      '$preset',
      '--skin',
      '$skin',
      '--global-tone',
      '$globalTone',
      '--ui-correction',
      uiCorrection ? '1' : '0',
      '--auto-mask',
      autoMask ? '1' : '0',
    ];
  }
}
