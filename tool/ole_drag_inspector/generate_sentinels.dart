import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

Future<void> main(List<String> arguments) async {
  final requestedOutput = _readOption(arguments, '--output');
  final token = _createToken();
  final outputDirectory = Directory(
    requestedOutput ??
        p.join(
          Directory.systemTemp.path,
          'nai_launcher_ole_sentinels',
          'sentinels_$token',
        ),
  );
  await outputDirectory.create(recursive: true);

  final sentinels = <Map<String, Object?>>[];
  sentinels.add(
    await _writeSentinel(
      outputDirectory,
      token: token,
      payload: 'text',
      palette: const [
        [244, 67, 54],
        [76, 175, 80],
        [33, 150, 243],
        [255, 193, 7],
      ],
    ),
  );
  sentinels.add(
    await _writeSentinel(
      outputDirectory,
      token: token,
      payload: 'stealth',
      palette: const [
        [156, 39, 176],
        [0, 188, 212],
        [255, 87, 34],
        [63, 81, 181],
      ],
    ),
  );

  final manifest = File(p.join(outputDirectory.path, 'sentinels.json'));
  await manifest.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'token': token,
      'directory': outputDirectory.absolute.path,
      'sentinels': sentinels,
    }),
    encoding: utf8,
    flush: true,
  );

  stdout.writeln(manifest.absolute.path);
}

Future<Map<String, Object?>> _writeSentinel(
  Directory outputDirectory, {
  required String token,
  required String payload,
  required List<List<int>> palette,
}) async {
  const width = 512;
  const height = 384;
  final promptToken = 'NAI_OLE_${payload.toUpperCase()}_$token';
  final metadata = jsonEncode({
    'prompt': promptToken,
    'uc': 'NAI_OLE_NEGATIVE_$token',
    'seed': payload == 'text' ? 1357911 : 2468022,
    'width': width,
    'height': height,
    'steps': 28,
    'scale': 5.0,
    'sampler': 'k_euler',
    'noise_schedule': 'native',
  });

  final image = _buildPattern(width, height, palette, payload == 'stealth');
  final basePng = Uint8List.fromList(img.encodePng(image));
  late Uint8List bytes;
  if (payload == 'text') {
    bytes = UnifiedMetadataParser.embedTextChunkOnly(
      basePng,
      'Comment',
      metadata,
    );
    bytes = UnifiedMetadataParser.embedTextChunkOnly(
      bytes,
      'Description',
      promptToken,
    );
    bytes = UnifiedMetadataParser.embedTextChunkOnly(
      bytes,
      'Software',
      'NovelAI',
    );
    bytes = UnifiedMetadataParser.embedTextChunkOnly(
      bytes,
      'Source',
      'NovelAI OLE inspector sentinel',
    );
  } else {
    final withStealth = await UnifiedMetadataParser.embedMetadata(
      basePng,
      metadata,
      useStealth: true,
    );
    bytes = _removeTextChunksWithoutReencoding(withStealth);
  }

  final parseResult = UnifiedMetadataParser.parseFromPng(
    bytes,
    useCache: false,
  );
  if (!parseResult.success ||
      parseResult.rawData?.contains(promptToken) != true) {
    throw StateError(
      'Sentinel self-check failed for $payload: '
      '${parseResult.errorMessage ?? parseResult.sourceFormat}',
    );
  }
  if (payload == 'stealth' &&
      parseResult.sourceFormat != 'NovelAI stealth_pngcomp') {
    throw StateError(
      'Stealth sentinel was parsed through ${parseResult.sourceFormat}',
    );
  }
  if (payload == 'text' &&
      parseResult.sourceFormat == 'NovelAI stealth_pngcomp') {
    throw StateError('Text sentinel unexpectedly contains stealth metadata');
  }

  final file = File(p.join(outputDirectory.path, 'nai_ole_$payload.png'));
  await file.writeAsBytes(bytes, flush: true);
  return {
    'payload': payload,
    'filePath': file.absolute.path,
    'sha256': sha256.convert(bytes).toString(),
    'length': bytes.length,
    'promptToken': promptToken,
    'metadataJson': metadata,
    'sourceFormat': parseResult.sourceFormat,
    'width': width,
    'height': height,
    'palette': [
      for (final color in palette)
        '#${color.map((value) => value.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}',
    ],
  };
}

img.Image _buildPattern(
  int width,
  int height,
  List<List<int>> palette,
  bool stealth,
) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final quadrant = (y < height ~/ 2 ? 0 : 2) + (x < width ~/ 2 ? 0 : 1);
      var color = palette[quadrant];
      final diagonal = ((x + y) % 97) < 9;
      final reverseDiagonal = ((width - x + y) % 131) < 9;
      if (diagonal) {
        color = stealth ? const [255, 255, 255] : const [12, 12, 12];
      } else if (reverseDiagonal) {
        color = stealth ? const [12, 12, 12] : const [255, 255, 255];
      }
      image.setPixelRgba(x, y, color[0], color[1], color[2], 255);
    }
  }
  return image;
}

Uint8List _removeTextChunksWithoutReencoding(Uint8List png) {
  const signatureLength = 8;
  if (png.length < signatureLength || !UnifiedMetadataParser.isPngHeader(png)) {
    throw const FormatException('Expected a PNG sentinel');
  }

  final output = BytesBuilder(copy: false)
    ..add(png.sublist(0, signatureLength));
  var offset = signatureLength;
  while (offset + 12 <= png.length) {
    final length = ByteData.sublistView(png, offset, offset + 4).getUint32(0);
    final end = offset + 12 + length;
    if (end > png.length) {
      throw const FormatException('Truncated PNG chunk');
    }
    final type = ascii.decode(png.sublist(offset + 4, offset + 8));
    if (type != 'tEXt' && type != 'zTXt' && type != 'iTXt') {
      output.add(png.sublist(offset, end));
    }
    offset = end;
    if (type == 'IEND') break;
  }
  if (offset != png.length) {
    throw const FormatException('Unexpected bytes after PNG IEND');
  }
  return output.takeBytes();
}

String _createToken() {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36);
  final random = Random.secure().nextInt(0x7fffffff).toRadixString(36);
  return '${now}_$random'.toUpperCase();
}

String? _readOption(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0) return null;
  if (index + 1 >= arguments.length) {
    throw FormatException('$name requires a value');
  }
  return arguments[index + 1];
}
