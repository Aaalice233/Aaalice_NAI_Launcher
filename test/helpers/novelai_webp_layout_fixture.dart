import 'dart:convert';
import 'dart:typed_data';

import 'novelai_exif_fixture.dart';
import 'riff_webp_builder.dart';

const novelAiStealthPrompt = '1girl, stealth layer prompt, 隐写';
const novelAiStealthSeed = 1357924680;

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

/// [novelAiStealthWebp] 末尾追加 EXIF 块并置 VP8X 的 EXIF 标志位，块顺序与官网文件一致。
Uint8List novelAiLayoutWebp({List<int>? exif}) {
  final chunks = Uint8List.fromList(novelAiStealthWebp.sublist(12));
  if (exif == null) return riffWebp(chunks);
  // 去掉 RIFF 头后，VP8X 的标志字节紧跟在 8 字节块头之后
  chunks[8] |= 0x08;
  return riffWebp([...chunks, ...riffChunk('EXIF', exif)]);
}
