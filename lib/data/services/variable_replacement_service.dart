/// 变量替换服务
///
/// 负责解析和替换文本中的变量引用
/// 复刻 RandomPromptGenerator 的变量替换功能
///
/// 主要功能：
/// - 解析 __变量名__ 格式的变量引用
/// - 支持同步和异步变量解析
/// - 批量处理字符串列表
/// - 保持未解析变量原样
///
/// 变量格式：
/// - __变量名__: 变量引用，会被替换为解析后的值
/// - 支持中英文变量名
/// - 支持嵌套变量替换
///
/// 示例：
/// ```dart
/// final service = VariableReplacementService();
///
/// // 定义解析器
/// String resolver(String varName) {
///   if (varName == 'hair') return 'blonde hair';
///   if (varName == 'eyes') return 'blue eyes';
///   return null; // 保持原样
/// }
///
/// // 单个字符串替换
/// final result = service.replace('beautiful __hair__', resolver);
/// // 'beautiful blonde hair'
///
/// // 批量替换
/// final results = service.replaceList(
///   ['__hair__', '__eyes__', 'unknown'],
///   resolver,
/// );
/// // ['blonde hair', 'blue eyes', 'unknown']
/// ```
class VariableReplacementService {
  /// 变量引用正则：__变量名__
  ///
  /// 匹配规则：
  /// - 以 __ 开头和结尾
  /// - 变量名中不含空格和下划线（除边界外）
  /// - 支持中英文字符
  static final RegExp variablePattern = RegExp(
    r'__([^\s_][^_]*?)__',
    unicode: true,
  );

  /// 替换字符串中的变量引用
  ///
  /// 在文本中查找所有 __变量名__ 格式的变量引用，
  /// 并使用提供的解析器替换为实际值。
  ///
  /// [text] 要处理的文本
  /// [resolver] 变量解析函数，接收变量名，返回替换值（null 表示保持原样）
  ///
  /// 返回替换后的文本
  ///
  /// 示例：
  /// ```dart
  /// final service = VariableReplacementService();
  ///
  /// String resolver(String varName) {
  ///   return varName == 'color' ? 'red' : null;
  /// }
  ///
  /// service.replace('The __color__ flower', resolver);
  /// // 'The red flower'
  ///
  /// service.replace('Unknown __var__', resolver);
  /// // 'Unknown __var__' (保持原样)
  /// ```
  String replace(
    String text,
    String? Function(String variableName) resolver,
  ) {
    // 快速检查：如果不包含 __，直接返回
    if (!text.contains('__')) return text;

    // 查找所有匹配项
    final matches = variablePattern.allMatches(text).toList();
    if (matches.isEmpty) return text;

    // 从后向前替换（避免位置变化）
    var result = text;
    for (final match in matches.reversed) {
      final varName = match.group(1)!;
      final replacement = resolver(varName);

      // 如果解析器返回 null，保持原样
      final value = replacement ?? match.group(0)!;
      result = result.replaceRange(match.start, match.end, value);
    }

    return result;
  }

  /// 替换字符串中的变量引用（异步版本）
  ///
  /// 异步版本的变量替换，用于需要异步解析的场景。
  ///
  /// [text] 要处理的文本
  /// [resolver] 异步变量解析函数，接收变量名，返回替换值（null 表示保持原样）
  ///
  /// 返回替换后的文本
  ///
  /// 示例：
  /// ```dart
  /// final service = VariableReplacementService();
  ///
  /// Future<String?> resolver(String varName) async {
  ///   if (varName == 'user') {
  ///     return await fetchUserName();
  ///   }
  ///   return null;
  /// }
  ///
  /// final result = await service.replaceAsync('Hello __user__', resolver);
  /// ```
  Future<String> replaceAsync(
    String text,
    Future<String?> Function(String variableName) resolver,
  ) async {
    // 快速检查
    if (!text.contains('__')) return text;

    // 查找所有匹配项
    final matches = variablePattern.allMatches(text).toList();
    if (matches.isEmpty) return text;

    // 从后向前替换
    var result = text;
    for (final match in matches.reversed) {
      final varName = match.group(1)!;
      final replacement = await resolver(varName);

      // 如果解析器返回 null，保持原样
      final value = replacement ?? match.group(0)!;
      result = result.replaceRange(match.start, match.end, value);
    }

    return result;
  }

  /// 批量替换字符串列表中的变量引用
  ///
  /// 对列表中的每个字符串执行变量替换。
  ///
  /// [tags] 字符串列表
  /// [resolver] 变量解析函数，接收变量名，返回替换值（null 表示保持原样）
  ///
  /// 返回替换后的字符串列表
  ///
  /// 示例：
  /// ```dart
  /// final service = VariableReplacementService();
  ///
  /// String resolver(String varName) {
  ///   if (varName == 'hair') return 'blonde';
  ///   if (varName == 'eyes') return 'blue';
  ///   return null;
  /// }
  ///
  /// final results = service.replaceList(
  ///   ['__hair__', '__eyes__', 'normal text'],
  ///   resolver,
  /// );
  /// // ['blonde', 'blue', 'normal text']
  /// ```
  List<String> replaceList(
    List<String> tags,
    String? Function(String variableName) resolver,
  ) {
    return tags.map((tag) => replace(tag, resolver)).toList();
  }

  /// 批量替换字符串列表中的变量引用（异步版本）
  ///
  /// 异步版本的批量变量替换。
  ///
  /// [tags] 字符串列表
  /// [resolver] 异步变量解析函数，接收变量名，返回替换值（null 表示保持原样）
  ///
  /// 返回替换后的字符串列表
  ///
  /// 示例：
  /// ```dart
  /// final service = VariableReplacementService();
  ///
  /// Future<String?> resolver(String varName) async {
  ///   return await fetchFromDatabase(varName);
  /// }
  ///
  /// final results = await service.replaceListAsync(
  ///   ['__var1__', '__var2__'],
  ///   resolver,
  /// );
  /// ```
  Future<List<String>> replaceListAsync(
    List<String> tags,
    Future<String?> Function(String variableName) resolver,
  ) async {
    final results = <String>[];
    for (final tag in tags) {
      results.add(await replaceAsync(tag, resolver));
    }
    return results;
  }

  /// 提取文本中的所有变量名
  ///
  /// 扫描文本并提取所有 __变量名__ 格式的变量名。
  /// 不执行替换，仅用于分析。
  ///
  /// [text] 要分析的文本
  ///
  /// 返回找到的变量名列表（去重）
  ///
  /// 示例：
  /// ```dart
  /// final service = VariableReplacementService();
  ///
  /// service.extractVariables('__hair__ and __eyes__');
  /// // ['hair', 'eyes']
  ///
  /// service.extractVariables('no variables here');
  /// // []
  /// ```
  List<String> extractVariables(String text) {
    if (!text.contains('__')) return [];

    final matches = variablePattern.allMatches(text);
    return matches
        .map((m) => m.group(1)!)
        .toSet() // 去重
        .toList();
  }

  /// 检查文本是否包含变量引用
  ///
  /// 快速检查文本中是否存在 __变量名__ 格式的变量引用。
  ///
  /// [text] 要检查的文本
  ///
  /// 返回 true 如果文本包含变量引用
  ///
  /// 示例：
  /// ```dart
  /// final service = VariableReplacementService();
  ///
  /// service.containsVariables('__hair__ is beautiful'); // true
  /// service.containsVariables('normal text'); // false
  /// ```
  bool containsVariables(String text) {
    return variablePattern.hasMatch(text);
  }

  /// 计算文本中的变量引用数量
  ///
  /// 统计文本中包含的变量引用总数（包括重复的变量）。
  ///
  /// [text] 要分析的文本
  ///
  /// 返回变量引用的数量
  ///
  /// 示例：
  /// ```dart
  /// final service = VariableReplacementService();
  ///
  /// service.countVariables('__hair__ and __eyes__'); // 2
  /// service.countVariables('__hair__ is __hair__'); // 2
  /// service.countVariables('no variables'); // 0
  /// ```
  int countVariables(String text) {
    if (!text.contains('__')) return 0;

    return variablePattern.allMatches(text).length;
  }
}
