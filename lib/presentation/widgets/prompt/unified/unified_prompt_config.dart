import '../../../widgets/autocomplete/autocomplete_controller.dart';

/// 统一提示词输入配置
///
/// 定义 [UnifiedPromptInput] 组件的功能开关和外观选项。
/// 支持通过预设配置快速适配不同使用场景。
class UnifiedPromptConfig {
  // ==================== 功能开关 ====================

  /// 是否启用自动补全
  ///
  /// 启用后，用户输入时会显示标签建议列表。
  final bool enableAutocomplete;

  /// 是否启用语法高亮
  ///
  /// 启用后，在文本模式下对 NAI 语法进行着色显示。
  final bool enableSyntaxHighlight;

  /// 是否启用自动格式化（失焦时）
  ///
  /// 启用后，当输入框失去焦点时自动格式化提示词文本。
  final bool enableAutoFormat;

  /// 是否启用 SD 语法自动转换
  ///
  /// 启用后，自动将 Stable Diffusion 语法转换为 NAI 语法。
  final bool enableSdSyntaxAutoConvert;

  /// 是否启用 ComfyUI 多角色语法导入
  ///
  /// 启用后，粘贴 ComfyUI Prompt Control 格式的多角色提示词时
  /// 会弹出导入确认框，支持转换为 NAI 多角色格式。
  final bool enableComfyuiImport;

  // ==================== 外观选项 ====================

  /// 是否紧凑模式
  ///
  /// 紧凑模式下隐藏视图切换按钮等额外 UI 元素。
  final bool compact;

  /// 是否只读
  ///
  /// 只读模式下禁用所有编辑功能。
  final bool readOnly;

  /// 最大高度（用于标签视图）
  ///
  /// 设置后，标签视图超出此高度时显示滚动条。
  final double? maxHeight;

  /// 空状态提示文本
  ///
  /// 当内容为空时显示的提示文本。
  final String? emptyHint;

  /// 输入框提示文本
  final String? hintText;

  // ==================== 自动补全配置 ====================

  /// 自动补全配置
  final AutocompleteConfig autocompleteConfig;

  const UnifiedPromptConfig({
    this.enableAutocomplete = true,
    this.enableSyntaxHighlight = true,
    this.enableAutoFormat = true,
    this.enableSdSyntaxAutoConvert = false,
    this.enableComfyuiImport = false,
    this.compact = false,
    this.readOnly = false,
    this.maxHeight,
    this.emptyHint,
    this.hintText,
    this.autocompleteConfig = const AutocompleteConfig(),
  });

  /// 角色编辑器预设配置
  ///
  /// 适用于 [CharacterDetailPanel] 中的提示词输入。
  /// 启用语法高亮和自动补全。
  static const characterEditor = UnifiedPromptConfig(
    enableAutocomplete: true,
    enableSyntaxHighlight: true,
    enableAutoFormat: true,
    enableSdSyntaxAutoConvert: false,
    compact: false,
    readOnly: false,
    autocompleteConfig: AutocompleteConfig(
      maxSuggestions: 15,
      showTranslation: true,
      showCategory: true,
      autoInsertComma: true,
    ),
  );

  /// 紧凑模式预设配置
  ///
  /// 适用于空间有限的场景。
  static const compactMode = UnifiedPromptConfig(
    enableAutocomplete: true,
    enableSyntaxHighlight: true,
    enableAutoFormat: true,
    enableSdSyntaxAutoConvert: false,
    compact: true,
    readOnly: false,
    autocompleteConfig: AutocompleteConfig(
      maxSuggestions: 10,
      showTranslation: true,
      autoInsertComma: true,
    ),
  );

  /// 创建配置副本并覆盖指定属性
  UnifiedPromptConfig copyWith({
    bool? enableAutocomplete,
    bool? enableSyntaxHighlight,
    bool? enableAutoFormat,
    bool? enableSdSyntaxAutoConvert,
    bool? enableComfyuiImport,
    bool? compact,
    bool? readOnly,
    double? maxHeight,
    String? emptyHint,
    String? hintText,
    AutocompleteConfig? autocompleteConfig,
  }) {
    return UnifiedPromptConfig(
      enableAutocomplete: enableAutocomplete ?? this.enableAutocomplete,
      enableSyntaxHighlight:
          enableSyntaxHighlight ?? this.enableSyntaxHighlight,
      enableAutoFormat: enableAutoFormat ?? this.enableAutoFormat,
      enableSdSyntaxAutoConvert:
          enableSdSyntaxAutoConvert ?? this.enableSdSyntaxAutoConvert,
      enableComfyuiImport: enableComfyuiImport ?? this.enableComfyuiImport,
      compact: compact ?? this.compact,
      readOnly: readOnly ?? this.readOnly,
      maxHeight: maxHeight ?? this.maxHeight,
      emptyHint: emptyHint ?? this.emptyHint,
      hintText: hintText ?? this.hintText,
      autocompleteConfig: autocompleteConfig ?? this.autocompleteConfig,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedPromptConfig &&
        other.enableAutocomplete == enableAutocomplete &&
        other.enableSyntaxHighlight == enableSyntaxHighlight &&
        other.enableAutoFormat == enableAutoFormat &&
        other.enableSdSyntaxAutoConvert == enableSdSyntaxAutoConvert &&
        other.enableComfyuiImport == enableComfyuiImport &&
        other.compact == compact &&
        other.readOnly == readOnly &&
        other.maxHeight == maxHeight &&
        other.emptyHint == emptyHint &&
        other.hintText == hintText;
  }

  @override
  int get hashCode {
    return Object.hash(
      enableAutocomplete,
      enableSyntaxHighlight,
      enableAutoFormat,
      enableSdSyntaxAutoConvert,
      enableComfyuiImport,
      compact,
      readOnly,
      maxHeight,
      emptyHint,
      hintText,
    );
  }
}
