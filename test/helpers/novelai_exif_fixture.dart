import 'dart:convert';
import 'dart:typed_data';

const novelAiV45FullSource = 'NovelAI Diffusion V4.5 4BDE2A90';

/// 官网元数据的外层信封：PNG 文本块去掉 Title 后的整体 JSON，EXIF UserComment 与 alpha 隐写都存这一份。
String novelAiEnvelopeJson({
  required String prompt,
  required int seed,
  String source = novelAiV45FullSource,
}) => jsonEncode({
  'Description': prompt,
  'Software': 'NovelAI',
  'Source': source,
  'Generation time': '3.351503983139992e-05',
  'Comment': jsonEncode({
    'prompt': prompt,
    'steps': 28,
    'height': 64,
    'width': 64,
    'scale': 5.0,
    'uncond_scale': 0.0,
    'cfg_rescale': 0.0,
    'seed': seed,
    'n_samples': 1,
    'noise_schedule': 'karras',
    'sampler': 'k_euler_ancestral',
    'uc': 'lowres, bad anatomy',
    'request_type': 'PromptGenerateRequest',
  }),
});

enum NovelAiExifIfd0Layout {
  /// 旧版：Model 存 Source，Software 固定为 "NovelAI"。
  modelAsSource,

  /// 新版：ImageDescription 存提示词，Software 存 Source。
  softwareAsSource,
}

/// 官网写入的 EXIF TIFF：默认大端，ExifIFD 只有 UserComment 且缺 next-IFD 指针；不带 `Exif\0\0` 头。
List<int> novelAiExif({
  required List<int> userComment,
  NovelAiExifIfd0Layout layout = NovelAiExifIfd0Layout.modelAsSource,
  String prompt = '',
  String source = novelAiV45FullSource,
  Endian endian = Endian.big,
}) => _tiff(
  endian: endian,
  ifd0: switch (layout) {
    NovelAiExifIfd0Layout.modelAsSource => [
      _IfdEntry.ascii(0x0110, source),
      _IfdEntry.ascii(0x0131, 'NovelAI'),
    ],
    NovelAiExifIfd0Layout.softwareAsSource => [
      _IfdEntry.ascii(0x010e, prompt),
      _IfdEntry.ascii(0x0131, source),
    ],
  },
  exifIfd: [_IfdEntry.undefined(0x9286, userComment)],
  exifIfdNextPointer: false,
);

/// 相机或其他程序写的通用小端 EXIF TIFF：只有方向、分辨率与像素尺寸，没有 UserComment；IFD0 条目比 [novelAiExif] 多。
List<int> cameraExifTiff() => _tiff(
  endian: Endian.little,
  ifd0: [
    _IfdEntry.short(0x0112, 1),
    _IfdEntry.rational(0x011a, 72000, 1000),
    _IfdEntry.rational(0x011b, 72000, 1000),
    _IfdEntry.short(0x0128, 2),
    _IfdEntry.short(0x0213, 1),
  ],
  exifIfd: [
    _IfdEntry.undefined(0x9000, ascii.encode('0210')),
    _IfdEntry.undefined(0x9101, const [1, 2, 3, 0]),
    _IfdEntry.undefined(0xa000, ascii.encode('0100')),
    _IfdEntry.short(0xa001, 0xffff),
    _IfdEntry.long(0xa002, 64),
    _IfdEntry.long(0xa003, 64),
  ],
  exifIfdNextPointer: true,
);

/// 被其他程序换掉的 WebP EXIF 块：`Exif\0\0` 头加 [cameraExifTiff]。
List<int> rewrittenCameraExif() => [
  ...ascii.encode('Exif\u0000\u0000'),
  ...cameraExifTiff(),
];

List<int> asciiUserComment(String text) => [
  ...ascii.encode('ASCII\u0000\u0000\u0000'),
  ...utf8.encode(text),
];

List<int> undefinedUserComment(String text) => [
  ...List<int>.filled(8, 0),
  ...utf8.encode(text),
];

List<int> unicodeUserComment(
  String text, {
  required Endian endian,
  bool byteOrderMark = true,
}) {
  final units = [if (byteOrderMark) 0xfeff, ...text.codeUnits];
  final data = ByteData(units.length * 2);
  for (var index = 0; index < units.length; index++) {
    data.setUint16(index * 2, units[index], endian);
  }
  return [...ascii.encode('UNICODE\u0000'), ...data.buffer.asUint8List()];
}

const int _exifIfdPointerTag = 0x8769;
const int _ifdEntrySize = 12;

/// 依次排布：TIFF 头、IFD0、IFD0 的值、ExifIFD、ExifIFD 的值；缺 next 指针时值区紧跟在条目之后。
List<int> _tiff({
  required Endian endian,
  required List<_IfdEntry> ifd0,
  required List<_IfdEntry> exifIfd,
  required bool exifIfdNextPointer,
}) {
  const ifd0Offset = 8;
  final ifd0Size = 2 + (ifd0.length + 1) * _ifdEntrySize + 4;
  final ifd0Values = _valueAreaSize(ifd0, endian);
  final exifIfdOffset = ifd0Offset + ifd0Size + ifd0Values;
  final output = BytesBuilder(copy: false)
    ..add(ascii.encode(endian == Endian.big ? 'MM' : 'II'))
    ..add(_uint16(42, endian))
    ..add(_uint32(ifd0Offset, endian));
  _writeIfd(
    output,
    [...ifd0, _IfdEntry.long(_exifIfdPointerTag, exifIfdOffset)],
    endian,
    nextPointer: true,
  );
  _writeIfd(output, exifIfd, endian, nextPointer: exifIfdNextPointer);
  return output.takeBytes();
}

void _writeIfd(
  BytesBuilder output,
  List<_IfdEntry> entries,
  Endian endian, {
  required bool nextPointer,
}) {
  final start = output.length;
  final directorySize =
      2 + entries.length * _ifdEntrySize + (nextPointer ? 4 : 0);
  var valueOffset = start + directorySize;
  final values = BytesBuilder(copy: false);
  output.add(_uint16(entries.length, endian));
  for (final entry in entries) {
    final data = entry.encode(endian);
    output
      ..add(_uint16(entry.tag, endian))
      ..add(_uint16(entry.type, endian))
      ..add(_uint32(entry.count, endian));
    if (data.length <= 4) {
      output.add([...data, ...List<int>.filled(4 - data.length, 0)]);
    } else {
      output.add(_uint32(valueOffset, endian));
      final padded = [...data, if (data.length.isOdd) 0];
      values.add(padded);
      valueOffset += padded.length;
    }
  }
  if (nextPointer) output.add(_uint32(0, endian));
  output.add(values.takeBytes());
}

int _valueAreaSize(List<_IfdEntry> entries, Endian endian) {
  var size = 0;
  for (final entry in entries) {
    final length = entry.encode(endian).length;
    if (length > 4) size += length + (length.isOdd ? 1 : 0);
  }
  return size;
}

Uint8List _uint16(int value, Endian endian) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, value, endian);

Uint8List _uint32(int value, Endian endian) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, endian);

class _IfdEntry {
  const _IfdEntry._(this.tag, this.type, this.count, this._values);

  factory _IfdEntry.ascii(int tag, String text) {
    final bytes = [...utf8.encode(text), 0];
    return _IfdEntry._(tag, _asciiType, bytes.length, bytes);
  }

  factory _IfdEntry.undefined(int tag, List<int> bytes) =>
      _IfdEntry._(tag, _undefinedType, bytes.length, bytes);

  factory _IfdEntry.short(int tag, int value) =>
      _IfdEntry._(tag, _shortType, 1, [value]);

  factory _IfdEntry.long(int tag, int value) =>
      _IfdEntry._(tag, _longType, 1, [value]);

  factory _IfdEntry.rational(int tag, int numerator, int denominator) =>
      _IfdEntry._(tag, _rationalType, 1, [numerator, denominator]);

  static const int _asciiType = 2;
  static const int _shortType = 3;
  static const int _longType = 4;
  static const int _rationalType = 5;
  static const int _undefinedType = 7;

  final int tag;
  final int type;
  final int count;
  final List<int> _values;

  List<int> encode(Endian endian) => switch (type) {
    _shortType => [for (final value in _values) ..._uint16(value, endian)],
    _longType ||
    _rationalType => [for (final value in _values) ..._uint32(value, endian)],
    _ => _values,
  };
}
