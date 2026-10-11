import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/antialiased_bilinear_resampler.dart';

// 期望值来自 torch 2.8 的
// F.interpolate(mode='bilinear', align_corners=False, antialias=True)
void main() {
  group('AntialiasedBilinearResampler.resizeRgbToPlanes', () {
    test('matches torchvision when shrinking both axes', () {
      _expectMatchesTorch(5, 7, 2, 3, const [
        0.0745098, 0.1333334, 0.1921569, 0.1764706, 0.2352941, 0.2941176, //
        0.2705882, 0.3294118, 0.3882353, 0.372549, 0.4313726, 0.4901961, //
        0.4666667, 0.5254903, 0.5843138, 0.5686274, 0.627451, 0.6862745,
      ]);
    });

    test('matches torchvision when stretching rows and shrinking columns', () {
      _expectMatchesTorch(5, 7, 9, 4, const [
        0.0143791, 0.057098, 0.1076078, 0.1503268, 0.0313726, 0.0740915, //
        0.1246013, 0.1673203, 0.059695, 0.102414, 0.1529237, 0.1956427, //
        0.0880174, 0.1307364, 0.1812462, 0.2239651, 0.1163399, 0.1590588, //
        0.2095686, 0.2522876, 0.1446623, 0.1873813, 0.2378911, 0.28061, //
        0.1729847, 0.2157037, 0.2662135, 0.3089325, 0.2013072, 0.2440262, //
        0.2945359, 0.3372549, 0.2183006, 0.2610196, 0.3115294, 0.3542483, //
        0.2104575, 0.2531765, 0.3036863, 0.3464052, 0.227451, 0.27017, //
        0.3206797, 0.3633987, 0.2557734, 0.2984924, 0.3490022, 0.3917211, //
        0.2840958, 0.3268148, 0.3773246, 0.4200435, 0.3124183, 0.3551373, //
        0.405647, 0.448366, 0.3407407, 0.3834597, 0.4339695, 0.4766884, //
        0.3690632, 0.4117822, 0.4622919, 0.5050109, 0.3973856, 0.4401046, //
        0.4906144, 0.5333334, 0.4143791, 0.4570981, 0.5076078, 0.5503268, //
        0.4065359, 0.4492549, 0.4997647, 0.5424837, 0.4235294, 0.4662484, //
        0.5167582, 0.5594772, 0.4518518, 0.4945709, 0.5450807, 0.5877995, //
        0.4801743, 0.5228933, 0.5734031, 0.616122, 0.5084967, 0.5512158, //
        0.6017255, 0.6444445, 0.5368192, 0.5795382, 0.6300479, 0.6727669, //
        0.5651416, 0.6078606, 0.6583704, 0.7010893, 0.5934641, 0.6361831, //
        0.6866928, 0.7294118, 0.6104575, 0.6531765, 0.7036862, 0.7464052,
      ]);
    });

    test('splits unchanged sizes into planes without filtering', () {
      final planes = AntialiasedBilinearResampler.resizeRgbToPlanes(
        _pattern(4, 4),
        sourceWidth: 4,
        sourceHeight: 4,
        targetWidth: 4,
        targetHeight: 4,
      );

      for (var channel = 0; channel < 3; channel++) {
        for (var y = 0; y < 4; y++) {
          for (var x = 0; x < 4; x++) {
            expect(
              planes[channel * 16 + y * 4 + x],
              closeTo(_sample(x, y, channel) / 255, 1e-7),
            );
          }
        }
      }
    });

    test('rejects buffers shorter than the declared source', () {
      expect(
        () => AntialiasedBilinearResampler.resizeRgbToPlanes(
          Uint8List(11),
          sourceWidth: 2,
          sourceHeight: 2,
          targetWidth: 1,
          targetHeight: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}

int _sample(int x, int y, int channel) => (x * 7 + y * 13 + channel * 50) % 256;

Uint8List _pattern(int width, int height) {
  final rgb = Uint8List(width * height * 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      for (var channel = 0; channel < 3; channel++) {
        rgb[(y * width + x) * 3 + channel] = _sample(x, y, channel);
      }
    }
  }
  return rgb;
}

void _expectMatchesTorch(
  int sourceHeight,
  int sourceWidth,
  int targetHeight,
  int targetWidth,
  List<double> expected,
) {
  final planes = AntialiasedBilinearResampler.resizeRgbToPlanes(
    _pattern(sourceWidth, sourceHeight),
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );

  expect(planes, hasLength(expected.length));
  for (var index = 0; index < expected.length; index++) {
    expect(planes[index], closeTo(expected[index], 1e-6), reason: '$index');
  }
}
