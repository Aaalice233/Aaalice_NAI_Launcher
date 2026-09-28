import 'dart:convert';

/// The visual treatment applied to every enabled redaction region.
enum MosaicEffect { pixelate, blur, solid }

/// Geometry used by an individual redaction region.
enum MosaicShape { roundedRectangle, ellipse, brush }

enum MosaicSettingsLoadIssue { migrated, corrupted }

class MosaicSettingsLoadResult {
  const MosaicSettingsLoadResult({required this.settings, this.issue});

  final MosaicSettings settings;
  final MosaicSettingsLoadIssue? issue;
}

/// Persisted defaults for the redaction editor.
///
/// Region coordinates are intentionally not persisted here. They are specific
/// to the source image and only live for the current editor session.
class MosaicSettings {
  const MosaicSettings({
    this.schemaVersion = currentSchemaVersion,
    this.enabled = false,
    this.preserveMetadata = false,
    this.rememberLastStyle = true,
    this.effect = MosaicEffect.pixelate,
    this.defaultShape = MosaicShape.roundedRectangle,
    this.pixelSizeRatio = 0.025,
    this.blurSigmaRatio = 0.018,
    this.opacity = 1,
    this.fillColorArgb = 0xFF000000,
    this.cornerRadiusRatio = 0.16,
    this.brushSizeRatio = 0.04,
    this.invertMask = false,
    this.showRegionLabels = true,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final bool enabled;
  final bool preserveMetadata;
  final bool rememberLastStyle;
  final MosaicEffect effect;
  final MosaicShape defaultShape;
  final double pixelSizeRatio;
  final double blurSigmaRatio;
  final double opacity;
  final int fillColorArgb;
  final double cornerRadiusRatio;
  final double brushSizeRatio;
  final bool invertMask;
  final bool showRegionLabels;

  MosaicSettings copyWith({
    bool? enabled,
    bool? preserveMetadata,
    bool? rememberLastStyle,
    MosaicEffect? effect,
    MosaicShape? defaultShape,
    double? pixelSizeRatio,
    double? blurSigmaRatio,
    double? opacity,
    int? fillColorArgb,
    double? cornerRadiusRatio,
    double? brushSizeRatio,
    bool? invertMask,
    bool? showRegionLabels,
  }) => MosaicSettings(
    enabled: enabled ?? this.enabled,
    preserveMetadata: preserveMetadata ?? this.preserveMetadata,
    rememberLastStyle: rememberLastStyle ?? this.rememberLastStyle,
    effect: effect ?? this.effect,
    defaultShape: defaultShape ?? this.defaultShape,
    pixelSizeRatio: pixelSizeRatio ?? this.pixelSizeRatio,
    blurSigmaRatio: blurSigmaRatio ?? this.blurSigmaRatio,
    opacity: opacity ?? this.opacity,
    fillColorArgb: fillColorArgb ?? this.fillColorArgb,
    cornerRadiusRatio: cornerRadiusRatio ?? this.cornerRadiusRatio,
    brushSizeRatio: brushSizeRatio ?? this.brushSizeRatio,
    invertMask: invertMask ?? this.invertMask,
    showRegionLabels: showRegionLabels ?? this.showRegionLabels,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'enabled': enabled,
    'preserveMetadata': preserveMetadata,
    'rememberLastStyle': rememberLastStyle,
    'effect': effect.name,
    'defaultShape': defaultShape.name,
    'pixelSizeRatio': pixelSizeRatio,
    'blurSigmaRatio': blurSigmaRatio,
    'opacity': opacity,
    'fillColorArgb': fillColorArgb,
    'cornerRadiusRatio': cornerRadiusRatio,
    'brushSizeRatio': brushSizeRatio,
    'invertMask': invertMask,
    'showRegionLabels': showRegionLabels,
  };

  String encode() => jsonEncode(toJson());

  static MosaicSettingsLoadResult decode(String? encoded) {
    if (encoded == null) {
      return const MosaicSettingsLoadResult(settings: MosaicSettings());
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return const MosaicSettingsLoadResult(
          settings: MosaicSettings(),
          issue: MosaicSettingsLoadIssue.corrupted,
        );
      }
      final rawVersion = decoded['schemaVersion'];
      if ((decoded.containsKey('schemaVersion') && rawVersion is! int) ||
          (rawVersion is int &&
              (rawVersion < 0 || rawVersion > currentSchemaVersion))) {
        return const MosaicSettingsLoadResult(
          settings: MosaicSettings(),
          issue: MosaicSettingsLoadIssue.corrupted,
        );
      }
      final reader = _MosaicSettingsReader(decoded);
      final settings = reader.read();
      return MosaicSettingsLoadResult(
        settings: settings,
        issue: reader.migrated ? MosaicSettingsLoadIssue.migrated : null,
      );
    } catch (_) {
      return const MosaicSettingsLoadResult(
        settings: MosaicSettings(),
        issue: MosaicSettingsLoadIssue.corrupted,
      );
    }
  }
}

/// A normalized point used by freehand brush masks.
class MosaicPoint {
  const MosaicPoint(this.x, this.y);

  final double x;
  final double y;

  MosaicPoint translated(double dx, double dy) => MosaicPoint(
    (x + dx).clamp(0.0, 1.0).toDouble(),
    (y + dy).clamp(0.0, 1.0).toDouble(),
  );
}

/// One editable mask element.
///
/// Rectangular and elliptical regions use [left], [top], [width] and [height].
/// Brush regions additionally use [points] and [brushSizeRatio].
class MosaicRegion {
  const MosaicRegion({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.shape,
    this.points = const <MosaicPoint>[],
    this.brushSizeRatio = 0.04,
    this.enabled = true,
    this.locked = false,
  });

  final String id;
  final double left;
  final double top;
  final double width;
  final double height;
  final MosaicShape shape;
  final List<MosaicPoint> points;
  final double brushSizeRatio;
  final bool enabled;
  final bool locked;

  bool get coversFullImage =>
      shape == MosaicShape.roundedRectangle &&
      left == 0 &&
      top == 0 &&
      width == 1 &&
      height == 1;

  bool get isUsable {
    if (!enabled) return false;
    if (shape == MosaicShape.brush) return points.isNotEmpty;
    return width > 0.002 && height > 0.002;
  }

  MosaicRegion copyWith({
    String? id,
    double? left,
    double? top,
    double? width,
    double? height,
    MosaicShape? shape,
    List<MosaicPoint>? points,
    double? brushSizeRatio,
    bool? enabled,
    bool? locked,
  }) => MosaicRegion(
    id: id ?? this.id,
    left: left ?? this.left,
    top: top ?? this.top,
    width: width ?? this.width,
    height: height ?? this.height,
    shape: shape ?? this.shape,
    points: points ?? this.points,
    brushSizeRatio: brushSizeRatio ?? this.brushSizeRatio,
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
  );

  MosaicRegion normalized() {
    final normalizedWidth = width.clamp(0.002, 1.0).toDouble();
    final normalizedHeight = height.clamp(0.002, 1.0).toDouble();
    final normalizedLeft = left.clamp(0.0, 1.0 - normalizedWidth).toDouble();
    final normalizedTop = top.clamp(0.0, 1.0 - normalizedHeight).toDouble();
    return copyWith(
      left: normalizedLeft,
      top: normalizedTop,
      width: normalizedWidth,
      height: normalizedHeight,
      brushSizeRatio: brushSizeRatio.clamp(0.005, 0.25).toDouble(),
      points: [
        for (final point in points)
          MosaicPoint(
            point.x.clamp(0.0, 1.0).toDouble(),
            point.y.clamp(0.0, 1.0).toDouble(),
          ),
      ],
    );
  }
}

class _MosaicSettingsReader {
  _MosaicSettingsReader(this.root);

  final Map<dynamic, dynamic> root;
  bool migrated = false;

  MosaicSettings read() {
    final version = _int('schemaVersion', 0);
    if (version != MosaicSettings.currentSchemaVersion) migrated = true;
    const fallback = MosaicSettings();
    return MosaicSettings(
      enabled: _bool('enabled', fallback.enabled),
      preserveMetadata: _bool('preserveMetadata', fallback.preserveMetadata),
      rememberLastStyle: _bool('rememberLastStyle', fallback.rememberLastStyle),
      effect: _enumValue('effect', MosaicEffect.values, fallback.effect),
      defaultShape: _enumValue(
        'defaultShape',
        MosaicShape.values,
        fallback.defaultShape,
      ),
      pixelSizeRatio: _double(
        'pixelSizeRatio',
        fallback.pixelSizeRatio,
        0.002,
        0.2,
      ),
      blurSigmaRatio: _double(
        'blurSigmaRatio',
        fallback.blurSigmaRatio,
        0.001,
        0.12,
      ),
      opacity: _double('opacity', fallback.opacity, 0.05, 1),
      fillColorArgb: _argb('fillColorArgb', fallback.fillColorArgb),
      cornerRadiusRatio: _double(
        'cornerRadiusRatio',
        fallback.cornerRadiusRatio,
        0,
        0.5,
      ),
      brushSizeRatio: _double(
        'brushSizeRatio',
        fallback.brushSizeRatio,
        0.005,
        0.25,
      ),
      invertMask: _bool('invertMask', fallback.invertMask),
      showRegionLabels: _bool('showRegionLabels', fallback.showRegionLabels),
    );
  }

  bool _bool(String key, bool fallback) {
    final value = root[key];
    if (value == null) {
      migrated = true;
      return fallback;
    }
    if (value is bool) return value;
    migrated = true;
    return fallback;
  }

  int _int(String key, int fallback) {
    final value = root[key];
    if (value is int) return value;
    migrated = true;
    return fallback;
  }

  int _argb(String key, int fallback) {
    final value = root[key];
    if (value is int && value >= 0 && value <= 0xFFFFFFFF) return value;
    migrated = true;
    return fallback;
  }

  double _double(String key, double fallback, double min, double max) {
    final value = root[key];
    if (value is num && value.isFinite) {
      return value.toDouble().clamp(min, max).toDouble();
    }
    migrated = true;
    return fallback;
  }

  T _enumValue<T>(String key, List<T> values, T fallback) {
    final raw = root[key];
    if (raw is String) {
      for (final value in values) {
        if ((value as Enum).name == raw) return value;
      }
    }
    migrated = true;
    return fallback;
  }
}
