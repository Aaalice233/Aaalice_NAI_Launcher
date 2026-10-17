import 'dart:convert';
import 'dart:typed_data';

import 'riff_webp_builder.dart';

const novelAiStealthPrompt = '1girl, stealth layer prompt, 隐写';
const novelAiStealthSeed = 1357924680;
const novelAiV45FullSource = 'NovelAI Diffusion V4.5 4BDE2A90';

/// 64×64 有损 WebP（VP8X + ALPH + VP8），alpha 按官方写入器的列优先规则携带隐写，
/// 载荷为 [novelAiEnvelopeJson]（[novelAiStealthPrompt]、[novelAiStealthSeed]）。
/// 由 libwebp 1.6.0 以 quality 80、alpha_quality 100 编码，alpha 无损，隐写位原样保留。
final Uint8List novelAiStealthWebp = base64Decode(
  'UklGRs4CAABXRUJQVlA4WAoAAAAQAAAAPwAAPwAAQUxQSM8BAAABD7D+ERFBoiTJpm3Ztp9t'
  '27Zt27Zt27Zt27btt7W26zci+h/jYtO0SZIhekzM97UyTNy7bX5aAz4e+mx6mpCvzMbfTRTI'
  'd7HLo0kmzBeDvw2SYf3ZlJf9Bcy70rNIZRkKxtx9UkjAxFI1R0oCxj9v+bKhAl9uTV4ZacPA'
  'XUO57kCW5ivqZLPhXNVGCw0T0nXqGrNcga95QnM3UqCgMEN/SXAoKKDjfxnWlX0/KEgC7/g8'
  'ZTarUCHosloTyBi9bvFnCTyqXZ0Uq4H3JfPTZQ0+zs3WdpYEh/YHz8slw6ZfF7pNVCHT98lj'
  'eikQNmJbhskCspZf2667BjHnbvU7JMPFBgWvTdZgo+E/NUiGc+2Ov/8tIO/km2vHCTg4ekaD'
  'YAX2XHr7p56AKpeLhJQUMK38rZkZTBhYJV/51y5sXP2qd0sT/v8dMn6kA21Ov7IzOVCyZbHa'
  'jwyI+NY2dY4DLcqt+bPNgmYfqucLMiA6YU8ZywHvdXfThlsw42BhO5MO58+P6NROh30dK0yr'
  'DrS7XKtWPWDf752/WxvQ7VL2VbNMmB/RZup1FxJWVCwVrUNij7HH2jlwPVt09Q4ufK+c/Wc+'
  'F/Z/KV/wvAXZHw66cN8AAFZQOCDYAAAAsAcAnQEqQABAAD5tMJJGsiMhoywIAkANiWI4AqvF'
  'KRJIrV0AAR0mXYAMlp9nI3K8UbtoIOfxUNDQ0F3//3bcQcG9f//5wAD+/6DaK9v380XimmAl'
  '7X5NeZheP6TPNyuy+4/Lh2qWsDZ/mPg89wuCd2pvS7MPf7SO9clDvO3olXnpyWjkTqw+5ipe'
  't2KDTP9ttDjHqCu74KrV0scs+G9RswNrf5EzWs2hk+r4cVfQgpJ3F27fffqOhrLN0qzGytGQ'
  'x2YaJgsNDEG3zLE/ErOSUoAxKuJwAAAA',
);

/// 官网元数据的外层信封：PNG 文本块去掉 Title 后的整体 JSON，WebP EXIF 与 alpha 隐写都存这一份。
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

/// [novelAiStealthWebp] 末尾追加 EXIF 块并置 VP8X 的 EXIF 标志位，块顺序与官网文件一致。
Uint8List novelAiLayoutWebp({List<int>? exif}) {
  final chunks = Uint8List.fromList(novelAiStealthWebp.sublist(12));
  if (exif == null) return riffWebp(chunks);
  // 去掉 RIFF 头后，VP8X 的标志字节紧跟在 8 字节块头之后
  chunks[8] |= 0x08;
  return riffWebp([...chunks, ...riffChunk('EXIF', exif)]);
}

enum NovelAiExifIfd0Layout {
  /// 旧版：Model 存 Source，Software 固定为 "NovelAI"。
  modelAsSource,

  /// 新版：ImageDescription 存提示词，Software 存 Source。
  softwareAsSource,
}

/// 官网 WebP 的 EXIF：大端 TIFF、无 `Exif\0\0` 头，ExifIFD 只有 UserComment 且缺 next-IFD 指针。
List<int> novelAiExif({
  required List<int> userComment,
  NovelAiExifIfd0Layout layout = NovelAiExifIfd0Layout.modelAsSource,
  String prompt = '',
  String source = novelAiV45FullSource,
}) => _tiff(
  endian: Endian.big,
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

/// 被其他程序换掉的通用 EXIF：`Exif\0\0` 头加小端 TIFF，只剩方向、分辨率与像素尺寸，没有 UserComment。
List<int> rewrittenCameraExif() => [
  ...ascii.encode('Exif\u0000\u0000'),
  ..._tiff(
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
  ),
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
