import '../../data/models/character/character_prompt.dart' as ui_character;
import '../../data/models/image/image_params.dart';
import '../utils/app_logger.dart';

/// 角色转换结果
///
/// 包含转换后的 API 角色列表和相关信息
class CharacterConversionResult {
  /// 转换后的 API 角色列表
  final List<CharacterPrompt> characters;

  /// 是否启用了坐标模式（有角色且非全局AI选择）
  final bool useCoords;

  /// 转换的角色数量
  final int convertedCount;

  /// 是否解析了别名
  final bool aliasesResolved;

  const CharacterConversionResult({
    required this.characters,
    required this.useCoords,
    required this.convertedCount,
    this.aliasesResolved = false,
  });

  /// 创建空结果
  factory CharacterConversionResult.empty() {
    return const CharacterConversionResult(
      characters: [],
      useCoords: false,
      convertedCount: 0,
      aliasesResolved: false,
    );
  }

  /// 检查是否有角色
  bool get hasCharacters => characters.isNotEmpty;
}

/// 别名解析器接口
///
/// 用于解析提示词中的别名引用
abstract class AliasResolver {
  /// 解析文本中的所有别名
  ///
  /// [text] 包含别名的原始文本
  /// 返回解析后的文本
  String resolveAliases(String text);
}

/// 角色转换服务
///
/// 负责将 UI 层的角色提示词配置转换为 API 层的格式，包括：
/// - 过滤启用且有提示词的角色
/// - 位置信息转换（自定义位置转 NAI 网格格式）
/// - 别名解析（角色提示词中的别名展开）
///
/// 这是一个纯服务类，不依赖 Riverpod，便于单元测试和复用
class CharacterConversionService {
  /// 别名解析器（可选）
  final AliasResolver? _aliasResolver;

  /// 创建角色转换服务
  ///
  /// [aliasResolver] 别名解析器，用于解析角色提示词中的别名
  CharacterConversionService({
    AliasResolver? aliasResolver,
  }) : _aliasResolver = aliasResolver;

  /// 转换角色配置为 API 格式
  ///
  /// [config] UI 层的角色提示词配置
  /// [resolveAliases] 是否解析别名（默认 true）
  ///
  /// 返回转换结果，包含 API 格式的角色列表和坐标模式状态
  CharacterConversionResult convert(
    ui_character.CharacterPromptConfig config, {
    bool resolveAliases = true,
  }) {
    // 过滤出启用且有提示词的角色
    final enabledCharacters = config.characters
        .where((c) => c.enabled && c.prompt.isNotEmpty)
        .toList();

    if (enabledCharacters.isEmpty) {
      return CharacterConversionResult.empty();
    }

    bool aliasesWereResolved = false;

    final apiCharacters = enabledCharacters.map((uiChar) {
      // 计算位置字符串
      String? position;
      if (!config.globalAiChoice &&
          uiChar.positionMode == ui_character.CharacterPositionMode.custom &&
          uiChar.customPosition != null) {
        position = uiChar.customPosition!.toNaiString();
      }

      // 解析角色提示词中的别名
      String resolvedPrompt = uiChar.prompt;
      String resolvedNegativePrompt = uiChar.negativePrompt;

      if (resolveAliases) {
        final aliasResolver = _aliasResolver;
        if (aliasResolver != null) {
          final promptWithAliases = aliasResolver.resolveAliases(uiChar.prompt);
          final negativeWithAliases =
              aliasResolver.resolveAliases(uiChar.negativePrompt);

          if (promptWithAliases != uiChar.prompt ||
              negativeWithAliases != uiChar.negativePrompt) {
            resolvedPrompt = promptWithAliases;
            resolvedNegativePrompt = negativeWithAliases;
            aliasesWereResolved = true;
          }
        }
      }

      return CharacterPrompt(
        prompt: resolvedPrompt,
        negativePrompt: resolvedNegativePrompt,
        position: position,
      );
    }).toList();

    // 确定是否启用坐标模式：有角色且非全局AI选择
    final useCoords = apiCharacters.isNotEmpty && !config.globalAiChoice;

    if (aliasesWereResolved) {
      AppLogger.d(
        'Resolved aliases in character prompts',
        'CharacterConversionService',
      );
    }

    return CharacterConversionResult(
      characters: apiCharacters,
      useCoords: useCoords,
      convertedCount: apiCharacters.length,
      aliasesResolved: aliasesWereResolved,
    );
  }

  /// 快速转换（不解析别名）
  ///
  /// [config] UI 层的角色提示词配置
  ///
  /// 返回转换后的 API 角色列表
  List<CharacterPrompt> convertCharacters(
    ui_character.CharacterPromptConfig config,
  ) {
    final result = convert(config, resolveAliases: false);
    return result.characters;
  }

  /// 检查配置中是否有启用的角色
  ///
  /// [config] UI 层的角色提示词配置
  bool hasEnabledCharacters(ui_character.CharacterPromptConfig config) {
    return config.characters.any((c) => c.enabled && c.prompt.isNotEmpty);
  }

  /// 获取启用的角色数量
  ///
  /// [config] UI 层的角色提示词配置
  int getEnabledCharacterCount(ui_character.CharacterPromptConfig config) {
    return config.characters
        .where((c) => c.enabled && c.prompt.isNotEmpty)
        .length;
  }
}
