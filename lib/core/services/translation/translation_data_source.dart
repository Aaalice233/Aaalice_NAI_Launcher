
/// CSV 格式配置
class CsvFormatConfig {
  /// 标签列索引
  final int tagColumnIndex;

  /// 翻译列索引
  final int translationColumnIndex;

  /// 是否有标题行
  final bool hasHeader;

  /// 分隔符
  final String delimiter;

  /// 文本限定符
  final String textQualifier;

  /// 编码
  final String encoding;

  const CsvFormatConfig({
    this.tagColumnIndex = 0,
    this.translationColumnIndex = 1,
    this.hasHeader = false,
    this.delimiter = ',',
    this.textQualifier = '"',
    this.encoding = 'utf-8',
  });
}

/// 翻译数据源配置
class TranslationDataSourceConfig {
  /// 数据源 ID
  final String id;

  /// 数据源名称
  final String name;

  /// 数据源路径（assets 路径）
  final String path;

  /// 优先级（数字越大优先级越高，高优先级会覆盖低优先级）
  final int priority;

  /// 是否启用
  final bool enabled;

  /// CSV 格式配置
  final CsvFormatConfig csvConfig;

  const TranslationDataSourceConfig({
    required this.id,
    required this.name,
    required this.path,
    this.priority = 0,
    this.enabled = true,
    this.csvConfig = const CsvFormatConfig(),
  });
}

/// 内置翻译数据源配置
/// 所有 CSV 文件都放在 assets/translations/ 目录下
class PredefinedDataSources {
  /// 本地高质量翻译 - danbooru_zh.csv
  /// 从本地 danbooru.csv 整理而来
  static const localDanbooruZh = TranslationDataSourceConfig(
    id: 'local_danbooru_zh',
    name: '本地 Danbooru 中文翻译',
    path: 'assets/translations/danbooru_zh.csv',
    priority: 100, // 最高优先级
    csvConfig: CsvFormatConfig(
      tagColumnIndex: 0,
      translationColumnIndex: 1,
      hasHeader: false,
    ),
  );

  /// HuggingFace 数据集 - 内置版本
  /// 下载地址：https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv
  /// 文件：danbooru_tags.csv
  /// 格式：tag,category,count,alias1,alias2...
  static const hfDanbooruTags = TranslationDataSourceConfig(
    id: 'hf_danbooru_tags',
    name: 'HuggingFace Danbooru Tags',
    path: 'assets/translations/hf_danbooru_tags.csv',
    priority: 50,
    csvConfig: CsvFormatConfig(
      tagColumnIndex: 0,
      translationColumnIndex: 3, // alias 列开始，取第一个
      hasHeader: true,
    ),
  );

  /// GitHub - CheNing233 - 内置版本
  /// 下载地址：https://github.com/CheNing233/datasets_danbooru_tag_wiki
  static const githubCheNing233 = TranslationDataSourceConfig(
    id: 'github_chening233',
    name: 'GitHub CheNing233 Wiki 翻译',
    path: 'assets/translations/github_chening233.csv',
    priority: 40,
    csvConfig: CsvFormatConfig(
      tagColumnIndex: 2, // tag 列
      translationColumnIndex: 3, // danbooru_translation 列
      hasHeader: true,
    ),
  );

  /// 角色翻译 - wai_characters.csv
  static const localCharacters = TranslationDataSourceConfig(
    id: 'local_characters',
    name: '本地角色翻译',
    path: 'assets/translations/wai_characters.csv',
    priority: 100,
    csvConfig: CsvFormatConfig(
      tagColumnIndex: 1, // 格式：中文名,英文名
      translationColumnIndex: 0,
      hasHeader: false,
    ),
  );

  /// 获取所有启用的内置数据源
  static List<TranslationDataSourceConfig> get all => [
    localDanbooruZh,
    localCharacters,
    hfDanbooruTags,
    githubCheNing233,
  ];
}

/// 共现标签数据源配置
class CooccurrenceDataSourceConfig {
  /// 数据源 ID
  final String id;

  /// 数据源名称
  final String name;

  /// CSV 文件路径
  final String path;

  /// 是否启用
  final bool enabled;

  const CooccurrenceDataSourceConfig({
    required this.id,
    required this.name,
    required this.path,
    this.enabled = true,
  });
}

/// 内置共现标签数据源
class PredefinedCooccurrenceSources {
  /// HuggingFace 共现数据 - 内置版本
  /// 下载地址：https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv
  /// 文件：danbooru_tags_cooccurrence.csv
  /// 格式：tag1,tag2,count
  static const hfCooccurrence = CooccurrenceDataSourceConfig(
    id: 'hf_cooccurrence',
    name: 'HuggingFace 共现标签',
    path: 'assets/translations/hf_danbooru_cooccurrence.csv',
  );

  static List<CooccurrenceDataSourceConfig> get all => [
    hfCooccurrence,
  ];
}
