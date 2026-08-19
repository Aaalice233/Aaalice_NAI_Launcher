import 'dart:convert';
import 'dart:io';

/// 把 NovelAI 的 Qwen 3.5 词表转换成启动器使用的紧凑资产。
///
/// 输入是 NovelAI 前端加载的原始词表（raw deflate 压缩的 JSON）：
///   https://novelai.net/tokenizer/compressed/qwen35_tokenizer.def?v=2&static=true
/// 下载后放到 `tool/.tmp/qwen35_tokenizer.def`（或用第一个参数指定路径）。
///
/// 输出 `assets/data/tokenizers/qwen35_bpe.txt.gz`，格式为 gzip 文本：
///   第一行  JSON 头（splitRegex / normalization / specialTokens）
///   其余行  每行一条 BPE merge，左右两段用空格分隔
///
/// 词表里的 vocab 只在需要 token id 时才有用；提示词计数只依赖 merge 顺序，
/// 因此这里丢弃 vocab，把 17MB 的原始 JSON 压到 1MB 出头。
void main(List<String> args) {
  final sourcePath = args.isNotEmpty
      ? args.first
      : 'tool/.tmp/qwen35_tokenizer.def';
  final outputPath = args.length > 1
      ? args[1]
      : 'assets/data/tokenizers/qwen35_bpe.txt.gz';

  final source = File(sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('找不到词表文件: $sourcePath');
    stderr.writeln(
      '请先从 https://novelai.net/tokenizer/compressed/qwen35_tokenizer.def'
      '?v=2&static=true 下载。',
    );
    exitCode = 1;
    return;
  }

  print('读取 $sourcePath');
  final compressed = source.readAsBytesSync();
  final raw = ZLibCodec(raw: true).decode(compressed);
  final data = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;

  final config = data['config'] as Map<String, dynamic>;
  final specialTokens = (data['specialTokens'] as List<dynamic>).cast<String>();
  final merges = (data['merges'] as List<dynamic>)
      .map((entry) => (entry as List<dynamic>).cast<String>())
      .toList(growable: false);

  print(
    'merges=${merges.length} specialTokens=${specialTokens.length} '
    'normalization=${config['normalization']}',
  );

  for (final merge in merges) {
    if (merge.length != 2) {
      throw StateError('意外的 merge 结构: $merge');
    }
    // byte-level 映射后不会出现空格与换行，分隔符才安全。
    if (merge.any((part) => part.contains(' ') || part.contains('\n'))) {
      throw StateError('merge 中出现了空白字符: $merge');
    }
  }

  final header = jsonEncode({
    'splitRegex': config['splitRegex'],
    'normalization': config['normalization'],
    'specialTokens': specialTokens,
  });

  final buffer = StringBuffer()..writeln(header);
  for (final merge in merges) {
    buffer.writeln('${merge[0]} ${merge[1]}');
  }

  final encoded = GZipCodec(level: 9).encode(utf8.encode(buffer.toString()));
  final output = File(outputPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(encoded);

  final sizeMb = (encoded.length / 1024 / 1024).toStringAsFixed(2);
  print('写入 ${output.path} ($sizeMb MB)');
}
