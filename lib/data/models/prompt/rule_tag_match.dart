import '../../../core/utils/nai_prompt_parser.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../../../core/utils/tag_normalizer.dart';

/// DIY 规则比较标签用的键：忽略 `{}`、`[]`、`1.2::x::`、`(x:1.2)` 等权重写法与大小写，
/// 下划线与空格等价
String ruleTagMatchKey(String tag) =>
    TagNormalizer.normalizeTagForMatch(SdToNaiConverter.convert(tag));

Set<String> ruleTagMatchKeys(Iterable<String> tags) =>
    tags.map(ruleTagMatchKey).where((key) => key.isNotEmpty).toSet();

/// 把逗号分隔的标签列表拆成比较键；逗号在权重括号内时不拆
Set<String> ruleTagMatchKeysOfList(String tags) =>
    ruleTagMatchKeys(NaiPromptParser.splitSegments(tags));
