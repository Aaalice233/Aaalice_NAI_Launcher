import 'dart:convert';

enum WatermarkSettingsLoadIssue { migrated, corrupted }

enum WatermarkAnchor {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

enum WatermarkTextAlignment { left, center, right }

enum WatermarkLayerArrangement { independent, horizontal, vertical }

enum WatermarkScaleBasis { shortEdge }

class WatermarkSettingsLoadResult {
  const WatermarkSettingsLoadResult({required this.settings, this.issue});

  final WatermarkSettings settings;
  final WatermarkSettingsLoadIssue? issue;
}

class WatermarkTextStyle {
  const WatermarkTextStyle({
    this.enabled = true,
    this.text = 'NovelAI',
    this.fontFamily = 'LXGW ZhenKai GB',
    this.colorArgb = 0xFFFFFFFF,
    this.opacity = 0.82,
    this.letterSpacingRatio = 0,
    this.alignment = WatermarkTextAlignment.right,
    this.strokeColorArgb = 0x99000000,
    this.strokeWidthRatio = 0.002,
    this.shadowColorArgb = 0x80000000,
    this.shadowBlurRatio = 0.008,
    this.shadowOffsetXRatio = 0.002,
    this.shadowOffsetYRatio = 0.003,
  });

  final bool enabled;
  final String text;
  final String fontFamily;
  final int colorArgb;
  final double opacity;
  final double letterSpacingRatio;
  final WatermarkTextAlignment alignment;
  final int strokeColorArgb;
  final double strokeWidthRatio;
  final int shadowColorArgb;
  final double shadowBlurRatio;
  final double shadowOffsetXRatio;
  final double shadowOffsetYRatio;

  WatermarkTextStyle copyWith({
    bool? enabled,
    String? text,
    String? fontFamily,
    int? colorArgb,
    double? opacity,
    double? letterSpacingRatio,
    WatermarkTextAlignment? alignment,
    int? strokeColorArgb,
    double? strokeWidthRatio,
    int? shadowColorArgb,
    double? shadowBlurRatio,
    double? shadowOffsetXRatio,
    double? shadowOffsetYRatio,
  }) => WatermarkTextStyle(
    enabled: enabled ?? this.enabled,
    text: text ?? this.text,
    fontFamily: fontFamily ?? this.fontFamily,
    colorArgb: colorArgb ?? this.colorArgb,
    opacity: opacity ?? this.opacity,
    letterSpacingRatio: letterSpacingRatio ?? this.letterSpacingRatio,
    alignment: alignment ?? this.alignment,
    strokeColorArgb: strokeColorArgb ?? this.strokeColorArgb,
    strokeWidthRatio: strokeWidthRatio ?? this.strokeWidthRatio,
    shadowColorArgb: shadowColorArgb ?? this.shadowColorArgb,
    shadowBlurRatio: shadowBlurRatio ?? this.shadowBlurRatio,
    shadowOffsetXRatio: shadowOffsetXRatio ?? this.shadowOffsetXRatio,
    shadowOffsetYRatio: shadowOffsetYRatio ?? this.shadowOffsetYRatio,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'text': text,
    'fontFamily': fontFamily,
    'colorArgb': colorArgb,
    'opacity': opacity,
    'letterSpacingRatio': letterSpacingRatio,
    'alignment': alignment.name,
    'strokeColorArgb': strokeColorArgb,
    'strokeWidthRatio': strokeWidthRatio,
    'shadowColorArgb': shadowColorArgb,
    'shadowBlurRatio': shadowBlurRatio,
    'shadowOffsetXRatio': shadowOffsetXRatio,
    'shadowOffsetYRatio': shadowOffsetYRatio,
  };
}

class WatermarkLogoStyle {
  const WatermarkLogoStyle({this.enabled = false, this.opacity = 0.85});

  final bool enabled;
  final double opacity;

  WatermarkLogoStyle copyWith({bool? enabled, double? opacity}) =>
      WatermarkLogoStyle(
        enabled: enabled ?? this.enabled,
        opacity: opacity ?? this.opacity,
      );

  Map<String, Object?> toJson() => {'enabled': enabled, 'opacity': opacity};
}

class WatermarkComposition {
  const WatermarkComposition({
    this.arrangement = WatermarkLayerArrangement.independent,
    this.gapRatio = 0.012,
  });

  final WatermarkLayerArrangement arrangement;
  final double gapRatio;

  WatermarkComposition copyWith({
    WatermarkLayerArrangement? arrangement,
    double? gapRatio,
  }) => WatermarkComposition(
    arrangement: arrangement ?? this.arrangement,
    gapRatio: gapRatio ?? this.gapRatio,
  );

  Map<String, Object?> toJson() => {
    'arrangement': arrangement.name,
    'gapRatio': gapRatio,
  };
}

class WatermarkPlacement {
  const WatermarkPlacement({
    required this.anchor,
    required this.sizeRatio,
    required this.marginRatio,
    this.offsetXRatio = 0,
    this.offsetYRatio = 0,
    required this.zIndex,
  });

  final WatermarkAnchor anchor;
  final double sizeRatio;
  final double marginRatio;
  final double offsetXRatio;
  final double offsetYRatio;
  final int zIndex;

  WatermarkPlacement copyWith({
    WatermarkAnchor? anchor,
    double? sizeRatio,
    double? marginRatio,
    double? offsetXRatio,
    double? offsetYRatio,
    int? zIndex,
  }) => WatermarkPlacement(
    anchor: anchor ?? this.anchor,
    sizeRatio: sizeRatio ?? this.sizeRatio,
    marginRatio: marginRatio ?? this.marginRatio,
    offsetXRatio: offsetXRatio ?? this.offsetXRatio,
    offsetYRatio: offsetYRatio ?? this.offsetYRatio,
    zIndex: zIndex ?? this.zIndex,
  );

  Map<String, Object?> toJson() => {
    'anchor': anchor.name,
    'sizeRatio': sizeRatio,
    'marginRatio': marginRatio,
    'offsetXRatio': offsetXRatio,
    'offsetYRatio': offsetYRatio,
    'zIndex': zIndex,
  };
}

class WatermarkLayout {
  const WatermarkLayout({
    this.scaleBasis = WatermarkScaleBasis.shortEdge,
    required this.textPlacement,
    required this.logoPlacement,
  });

  final WatermarkScaleBasis scaleBasis;
  final WatermarkPlacement textPlacement;
  final WatermarkPlacement logoPlacement;

  WatermarkLayout copyWith({
    WatermarkScaleBasis? scaleBasis,
    WatermarkPlacement? textPlacement,
    WatermarkPlacement? logoPlacement,
  }) => WatermarkLayout(
    scaleBasis: scaleBasis ?? this.scaleBasis,
    textPlacement: textPlacement ?? this.textPlacement,
    logoPlacement: logoPlacement ?? this.logoPlacement,
  );

  Map<String, Object?> toJson() => {
    'scaleBasis': scaleBasis.name,
    'textPlacement': textPlacement.toJson(),
    'logoPlacement': logoPlacement.toJson(),
  };
}

class WatermarkSettings {
  const WatermarkSettings({
    this.schemaVersion = currentSchemaVersion,
    this.enabled = false,
    this.preserveMetadata = false,
    this.rememberLayoutsByOrientation = false,
    this.textStyle = const WatermarkTextStyle(),
    this.logoStyle = const WatermarkLogoStyle(),
    this.composition = const WatermarkComposition(),
    this.universalLayout = defaultLayout,
    this.portraitLayout = defaultLayout,
    this.squareLayout = defaultLayout,
    this.landscapeLayout = defaultLayout,
  });

  static const currentSchemaVersion = 1;
  static const defaultTextPlacement = WatermarkPlacement(
    anchor: WatermarkAnchor.bottomRight,
    sizeRatio: 0.1,
    marginRatio: 0.035,
    zIndex: 10,
  );
  static const defaultLogoPlacement = WatermarkPlacement(
    anchor: WatermarkAnchor.bottomLeft,
    sizeRatio: 0.16,
    marginRatio: 0.035,
    zIndex: 0,
  );
  static const defaultLayout = WatermarkLayout(
    textPlacement: defaultTextPlacement,
    logoPlacement: defaultLogoPlacement,
  );

  final int schemaVersion;
  final bool enabled;
  final bool preserveMetadata;
  final bool rememberLayoutsByOrientation;
  final WatermarkTextStyle textStyle;
  final WatermarkLogoStyle logoStyle;
  final WatermarkComposition composition;
  final WatermarkLayout universalLayout;
  final WatermarkLayout portraitLayout;
  final WatermarkLayout squareLayout;
  final WatermarkLayout landscapeLayout;

  WatermarkSettings copyWith({
    bool? enabled,
    bool? preserveMetadata,
    bool? rememberLayoutsByOrientation,
    WatermarkTextStyle? textStyle,
    WatermarkLogoStyle? logoStyle,
    WatermarkComposition? composition,
    WatermarkLayout? universalLayout,
    WatermarkLayout? portraitLayout,
    WatermarkLayout? squareLayout,
    WatermarkLayout? landscapeLayout,
  }) => WatermarkSettings(
    enabled: enabled ?? this.enabled,
    preserveMetadata: preserveMetadata ?? this.preserveMetadata,
    rememberLayoutsByOrientation:
        rememberLayoutsByOrientation ?? this.rememberLayoutsByOrientation,
    textStyle: textStyle ?? this.textStyle,
    logoStyle: logoStyle ?? this.logoStyle,
    composition: composition ?? this.composition,
    universalLayout: universalLayout ?? this.universalLayout,
    portraitLayout: portraitLayout ?? this.portraitLayout,
    squareLayout: squareLayout ?? this.squareLayout,
    landscapeLayout: landscapeLayout ?? this.landscapeLayout,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'enabled': enabled,
    'preserveMetadata': preserveMetadata,
    'rememberLayoutsByOrientation': rememberLayoutsByOrientation,
    'textStyle': textStyle.toJson(),
    'logoStyle': logoStyle.toJson(),
    'composition': composition.toJson(),
    'layouts': {
      'universal': universalLayout.toJson(),
      'portrait': portraitLayout.toJson(),
      'square': squareLayout.toJson(),
      'landscape': landscapeLayout.toJson(),
    },
  };

  String encode() => jsonEncode(toJson());

  static WatermarkSettingsLoadResult decode(String? encoded) {
    if (encoded == null) {
      return const WatermarkSettingsLoadResult(settings: WatermarkSettings());
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return const WatermarkSettingsLoadResult(
          settings: WatermarkSettings(),
          issue: WatermarkSettingsLoadIssue.corrupted,
        );
      }
      final reader = _WatermarkJsonReader(decoded);
      final settings = reader.readSettings();
      return WatermarkSettingsLoadResult(
        settings: settings,
        issue: reader.migrated ? WatermarkSettingsLoadIssue.migrated : null,
      );
    } catch (_) {
      return const WatermarkSettingsLoadResult(
        settings: WatermarkSettings(),
        issue: WatermarkSettingsLoadIssue.corrupted,
      );
    }
  }
}

class _WatermarkJsonReader {
  _WatermarkJsonReader(Map<dynamic, dynamic> value) : root = value;

  final Map<dynamic, dynamic> root;
  bool migrated = false;

  WatermarkSettings readSettings() {
    final version = _int(root, 'schemaVersion', 0);
    if (version != WatermarkSettings.currentSchemaVersion) migrated = true;
    final layouts = _map(root, 'layouts');
    return WatermarkSettings(
      enabled: _bool(root, 'enabled', false),
      preserveMetadata: _bool(root, 'preserveMetadata', false),
      rememberLayoutsByOrientation: _bool(
        root,
        'rememberLayoutsByOrientation',
        false,
      ),
      textStyle: _textStyle(_map(root, 'textStyle')),
      logoStyle: _logoStyle(_map(root, 'logoStyle')),
      composition: _composition(_map(root, 'composition')),
      universalLayout: _layout(
        _map(layouts, 'universal'),
        WatermarkSettings.defaultLayout,
      ),
      portraitLayout: _layout(
        _map(layouts, 'portrait'),
        WatermarkSettings.defaultLayout,
      ),
      squareLayout: _layout(
        _map(layouts, 'square'),
        WatermarkSettings.defaultLayout,
      ),
      landscapeLayout: _layout(
        _map(layouts, 'landscape'),
        WatermarkSettings.defaultLayout,
      ),
    );
  }

  WatermarkTextStyle _textStyle(Map<dynamic, dynamic> value) {
    const fallback = WatermarkTextStyle();
    return WatermarkTextStyle(
      enabled: _bool(value, 'enabled', fallback.enabled),
      text: _string(value, 'text', fallback.text),
      fontFamily: _string(value, 'fontFamily', fallback.fontFamily),
      colorArgb: _argb(value, 'colorArgb', fallback.colorArgb),
      opacity: _double(value, 'opacity', fallback.opacity, 0, 1),
      letterSpacingRatio: _double(
        value,
        'letterSpacingRatio',
        fallback.letterSpacingRatio,
        -0.1,
        0.2,
      ),
      alignment: _enumValue(
        value,
        'alignment',
        WatermarkTextAlignment.values,
        fallback.alignment,
      ),
      strokeColorArgb: _argb(
        value,
        'strokeColorArgb',
        fallback.strokeColorArgb,
      ),
      strokeWidthRatio: _double(
        value,
        'strokeWidthRatio',
        fallback.strokeWidthRatio,
        0,
        0.05,
      ),
      shadowColorArgb: _argb(
        value,
        'shadowColorArgb',
        fallback.shadowColorArgb,
      ),
      shadowBlurRatio: _double(
        value,
        'shadowBlurRatio',
        fallback.shadowBlurRatio,
        0,
        0.1,
      ),
      shadowOffsetXRatio: _double(
        value,
        'shadowOffsetXRatio',
        fallback.shadowOffsetXRatio,
        -0.25,
        0.25,
      ),
      shadowOffsetYRatio: _double(
        value,
        'shadowOffsetYRatio',
        fallback.shadowOffsetYRatio,
        -0.25,
        0.25,
      ),
    );
  }

  WatermarkLogoStyle _logoStyle(Map<dynamic, dynamic> value) {
    const fallback = WatermarkLogoStyle();
    return WatermarkLogoStyle(
      enabled: _bool(value, 'enabled', fallback.enabled),
      opacity: _double(value, 'opacity', fallback.opacity, 0, 1),
    );
  }

  WatermarkComposition _composition(Map<dynamic, dynamic> value) {
    const fallback = WatermarkComposition();
    return WatermarkComposition(
      arrangement: _enumValue(
        value,
        'arrangement',
        WatermarkLayerArrangement.values,
        fallback.arrangement,
      ),
      gapRatio: _double(value, 'gapRatio', fallback.gapRatio, 0, 0.25),
    );
  }

  WatermarkLayout _layout(
    Map<dynamic, dynamic> value,
    WatermarkLayout fallback,
  ) => WatermarkLayout(
    scaleBasis: _enumValue(
      value,
      'scaleBasis',
      WatermarkScaleBasis.values,
      fallback.scaleBasis,
    ),
    textPlacement: _placement(
      _map(value, 'textPlacement'),
      fallback.textPlacement,
    ),
    logoPlacement: _placement(
      _map(value, 'logoPlacement'),
      fallback.logoPlacement,
    ),
  );

  WatermarkPlacement _placement(
    Map<dynamic, dynamic> value,
    WatermarkPlacement fallback,
  ) => WatermarkPlacement(
    anchor: _enumValue(
      value,
      'anchor',
      WatermarkAnchor.values,
      fallback.anchor,
    ),
    sizeRatio: _double(value, 'sizeRatio', fallback.sizeRatio, 0.02, 1),
    marginRatio: _double(value, 'marginRatio', fallback.marginRatio, 0, 0.25),
    offsetXRatio: _double(
      value,
      'offsetXRatio',
      fallback.offsetXRatio,
      -0.5,
      0.5,
    ),
    offsetYRatio: _double(
      value,
      'offsetYRatio',
      fallback.offsetYRatio,
      -0.5,
      0.5,
    ),
    zIndex: _int(value, 'zIndex', fallback.zIndex, min: -100, max: 100),
  );

  Map<dynamic, dynamic> _map(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value is Map) return value;
    migrated = true;
    return const {};
  }

  bool _bool(Map<dynamic, dynamic> map, String key, bool fallback) {
    final value = map[key];
    if (value is bool) return value;
    migrated = true;
    return fallback;
  }

  String _string(Map<dynamic, dynamic> map, String key, String fallback) {
    final value = map[key];
    if (value is String) return value;
    migrated = true;
    return fallback;
  }

  int _argb(Map<dynamic, dynamic> map, String key, int fallback) {
    final value = map[key];
    if (value is int && value >= 0 && value <= 0xFFFFFFFF) return value;
    migrated = true;
    if (value is num) return value.toInt().clamp(0, 0xFFFFFFFF);
    return fallback;
  }

  int _int(
    Map<dynamic, dynamic> map,
    String key,
    int fallback, {
    int? min,
    int? max,
  }) {
    final value = map[key];
    if (value is! num || !value.isFinite) {
      migrated = true;
      return fallback;
    }
    final integer = value.toInt();
    final normalized = integer.clamp(min ?? integer, max ?? integer);
    if (value != integer || normalized != integer) migrated = true;
    return normalized;
  }

  double _double(
    Map<dynamic, dynamic> map,
    String key,
    double fallback,
    double min,
    double max,
  ) {
    final value = map[key];
    if (value is! num || !value.isFinite) {
      migrated = true;
      return fallback;
    }
    final normalized = value.toDouble().clamp(min, max);
    if (normalized != value.toDouble()) migrated = true;
    return normalized;
  }

  T _enumValue<T extends Enum>(
    Map<dynamic, dynamic> map,
    String key,
    List<T> values,
    T fallback,
  ) {
    final value = map[key];
    if (value is String) {
      for (final candidate in values) {
        if (candidate.name == value) return candidate;
      }
    }
    migrated = true;
    return fallback;
  }
}
