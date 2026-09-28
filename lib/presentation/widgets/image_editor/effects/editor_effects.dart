import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum EditorEffectType {
  brightness,
  contrast,
  saturation,
  temperature,
  gamma,
  grayscale,
  invert,
  sepia,
  denoise,
  blur,
  sharpen,
  cropToSelection,
  rotateLeft,
  rotateRight,
  flipHorizontal,
  flipVertical,
}

String editorEffectLabel(EditorEffectType type) {
  return switch (type) {
    EditorEffectType.brightness => 'Brightness',
    EditorEffectType.contrast => 'Contrast',
    EditorEffectType.saturation => 'Saturation',
    EditorEffectType.temperature => 'Temperature',
    EditorEffectType.gamma => 'Gamma',
    EditorEffectType.grayscale => 'Grayscale',
    EditorEffectType.invert => 'Invert',
    EditorEffectType.sepia => 'Sepia',
    EditorEffectType.denoise => 'Denoise',
    EditorEffectType.blur => 'Gaussian Blur',
    EditorEffectType.sharpen => 'Sharpen',
    EditorEffectType.cropToSelection => 'Crop to Selection',
    EditorEffectType.rotateLeft => 'Rotate Left 90°',
    EditorEffectType.rotateRight => 'Rotate Right 90°',
    EditorEffectType.flipHorizontal => 'Flip Horizontal',
    EditorEffectType.flipVertical => 'Flip Vertical',
  };
}

double editorEffectDefaultIntensity(EditorEffectType type) {
  return switch (type) {
    EditorEffectType.brightness => 0.25,
    EditorEffectType.contrast => 0.25,
    EditorEffectType.saturation => 0.25,
    EditorEffectType.temperature => 0.25,
    EditorEffectType.gamma => 0.35,
    EditorEffectType.grayscale => 1.0,
    EditorEffectType.invert => 1.0,
    EditorEffectType.sepia => 0.75,
    EditorEffectType.denoise => 0.45,
    EditorEffectType.blur => 0.25,
    EditorEffectType.sharpen => 0.65,
    _ => 1.0,
  };
}

double editorEffectMin(EditorEffectType type) {
  return switch (type) {
    EditorEffectType.brightness => -0.8,
    EditorEffectType.contrast => -0.8,
    EditorEffectType.saturation => -1.0,
    EditorEffectType.temperature => -1.0,
    EditorEffectType.gamma => -1.0,
    _ => 0.0,
  };
}

double editorEffectMax(EditorEffectType type) {
  return switch (type) {
    EditorEffectType.grayscale => 1.0,
    EditorEffectType.invert => 1.0,
    EditorEffectType.sepia => 1.0,
    EditorEffectType.sharpen => 1.0,
    EditorEffectType.blur => 1.0,
    _ => 1.0,
  };
}

bool editorEffectHasIntensity(EditorEffectType type) {
  return switch (type) {
    EditorEffectType.grayscale ||
    EditorEffectType.invert ||
    EditorEffectType.cropToSelection ||
    EditorEffectType.rotateLeft ||
    EditorEffectType.rotateRight ||
    EditorEffectType.flipHorizontal ||
    EditorEffectType.flipVertical => false,
    _ => true,
  };
}

class EditorEffectCropRect {
  const EditorEffectCropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory EditorEffectCropRect.fromMessage(Map<String, Object?> message) {
    return EditorEffectCropRect(
      x: message['x']! as int,
      y: message['y']! as int,
      width: message['width']! as int,
      height: message['height']! as int,
    );
  }

  final int x;
  final int y;
  final int width;
  final int height;

  Map<String, Object?> toMessage() {
    return {'x': x, 'y': y, 'width': width, 'height': height};
  }
}

class EditorEffectJob {
  const EditorEffectJob({
    required this.imageBytes,
    required this.effectType,
    required this.intensity,
    this.maxPreviewDimension = 0,
    this.cropRect,
  });

  factory EditorEffectJob.fromMessage(Map<String, Object?> message) {
    final cropMessage = message['cropRect'] as Map<Object?, Object?>?;
    return EditorEffectJob(
      imageBytes: message['imageBytes']! as Uint8List,
      effectType: EditorEffectType.values.byName(
        message['effectType']! as String,
      ),
      intensity: message['intensity']! as double,
      maxPreviewDimension: message['maxPreviewDimension']! as int,
      cropRect: cropMessage == null
          ? null
          : EditorEffectCropRect.fromMessage(
              cropMessage.cast<String, Object?>(),
            ),
    );
  }

  final Uint8List imageBytes;
  final EditorEffectType effectType;
  final double intensity;
  final int maxPreviewDimension;
  final EditorEffectCropRect? cropRect;

  Map<String, Object?> toMessage() {
    return {
      'imageBytes': imageBytes,
      'effectType': effectType.name,
      'intensity': intensity,
      'maxPreviewDimension': maxPreviewDimension,
      'cropRect': cropRect?.toMessage(),
    };
  }
}

class EditorEffectResult {
  const EditorEffectResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  factory EditorEffectResult.fromMessage(Map<String, Object?> message) {
    return EditorEffectResult(
      bytes: message['bytes']! as Uint8List,
      width: message['width']! as int,
      height: message['height']! as int,
    );
  }

  final Uint8List bytes;
  final int width;
  final int height;

  Map<String, Object?> toMessage() {
    return {'bytes': bytes, 'width': width, 'height': height};
  }
}

Map<String, Object?> runEditorEffectJobMessage(Map<String, Object?> message) {
  return runEditorEffectJob(EditorEffectJob.fromMessage(message)).toMessage();
}

EditorEffectResult runEditorEffectJob(EditorEffectJob job) {
  var source = img.decodeImage(job.imageBytes);
  if (source == null) {
    throw StateError('Failed to decode the current layer');
  }

  var cropRect = job.cropRect;
  if (job.maxPreviewDimension > 0) {
    final maxSide = math.max(source.width, source.height);
    if (maxSide > job.maxPreviewDimension) {
      final scale = job.maxPreviewDimension / maxSide;
      source = img.copyResize(
        source,
        width: math.max(1, (source.width * scale).round()),
        height: math.max(1, (source.height * scale).round()),
      );
      if (cropRect != null) {
        cropRect = scaleEditorEffectCropRect(cropRect, scale, source);
      }
    }
  }

  final effected = applyEditorImageEffect(
    source,
    job.effectType,
    job.intensity,
    cropRect: cropRect,
  );
  return EditorEffectResult(
    bytes: Uint8List.fromList(img.encodePng(effected)),
    width: effected.width,
    height: effected.height,
  );
}

EditorEffectCropRect scaleEditorEffectCropRect(
  EditorEffectCropRect rect,
  double scale,
  img.Image source,
) {
  final x = (rect.x * scale).round().clamp(0, source.width - 1).toInt();
  final y = (rect.y * scale).round().clamp(0, source.height - 1).toInt();
  final width = math
      .max(1, (rect.width * scale).round())
      .clamp(1, source.width - x)
      .toInt();
  final height = math
      .max(1, (rect.height * scale).round())
      .clamp(1, source.height - y)
      .toInt();
  return EditorEffectCropRect(x: x, y: y, width: width, height: height);
}

img.Image applyEditorImageEffect(
  img.Image source,
  EditorEffectType effectType,
  double intensity, {
  EditorEffectCropRect? cropRect,
}) {
  final work = img.Image.from(source);
  switch (effectType) {
    case EditorEffectType.brightness:
      return img.adjustColor(
        work,
        brightness: (1.0 + intensity).clamp(0.0, 2.0),
      );
    case EditorEffectType.contrast:
      return img.adjustColor(work, contrast: (1.0 + intensity).clamp(0.0, 2.0));
    case EditorEffectType.saturation:
      return img.adjustColor(
        work,
        saturation: (1.0 + intensity).clamp(0.0, 2.0),
      );
    case EditorEffectType.temperature:
      return _applyTemperature(work, intensity);
    case EditorEffectType.gamma:
      return img.gamma(work, gamma: math.pow(2.0, intensity).toDouble());
    case EditorEffectType.grayscale:
      return img.grayscale(work);
    case EditorEffectType.invert:
      return img.invert(work);
    case EditorEffectType.sepia:
      return img.sepia(work, amount: intensity.clamp(0.0, 1.0));
    case EditorEffectType.denoise:
      return img.smooth(work, weight: (1.0 - intensity).clamp(0.05, 1.0));
    case EditorEffectType.blur:
      return img.gaussianBlur(work, radius: (intensity * 12).round());
    case EditorEffectType.sharpen:
      return img.convolution(
        work,
        filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0],
        amount: intensity.clamp(0.0, 1.0),
      );
    case EditorEffectType.cropToSelection:
      return _cropToRect(work, cropRect);
    case EditorEffectType.rotateLeft:
      return img.copyRotate(work, angle: -90);
    case EditorEffectType.rotateRight:
      return img.copyRotate(work, angle: 90);
    case EditorEffectType.flipHorizontal:
      return img.flipHorizontal(work);
    case EditorEffectType.flipVertical:
      return img.flipVertical(work);
  }
}

img.Image _applyTemperature(img.Image source, double intensity) {
  final shift = (intensity * 48).round();
  for (final pixel in source) {
    pixel
      ..r = (pixel.r + shift).round().clamp(0, 255)
      ..b = (pixel.b - shift).round().clamp(0, 255);
  }
  return source;
}

img.Image _cropToRect(img.Image source, EditorEffectCropRect? cropRect) {
  if (cropRect == null) {
    throw StateError('Create a selection before cropping to selection');
  }
  return img.copyCrop(
    source,
    x: cropRect.x,
    y: cropRect.y,
    width: cropRect.width,
    height: cropRect.height,
  );
}
