import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pending_prompt_provider.freezed.dart';
part 'pending_prompt_provider.g.dart';

/// 发送目标类型
///
/// 用于指定词库条目发送到主页的目标位置
enum SendTargetType {
  /// 发送到主提示词
  mainPrompt,

  /// 替换角色提示词（清空后添加）
  replaceCharacter,

  /// 追加角色提示词（保留现有）
  appendCharacter,

  /// 智能分解（竖线格式：主提示词+角色）
  smartDecompose,
}

/// 待填充提示词状态
///
/// 用于跨页面传递提示词（如从画廊发送到主界面）
@freezed
class PendingPromptState with _$PendingPromptState {
  const factory PendingPromptState({
    /// 正向提示词
    String? prompt,

    /// 负向提示词
    String? negativePrompt,

    /// 消费后是否自动清空（默认 true）
    @Default(true) bool clearOnConsume,

    /// 发送目标类型（词库条目使用）
    SendTargetType? targetType,
  }) = _PendingPromptState;
}

/// 待填充提示词状态管理 Provider
///
/// 用于跨页面传递提示词，典型用法：
/// 1. 画廊页面调用 `set()` 设置待填充提示词
/// 2. 用户导航到主界面
/// 3. 主界面调用 `consume()` 获取并清空提示词
/// 4. 填充到输入框
///
/// ## keepAlive 策略
///
/// **保留 keepAlive: true**，原因如下：
///
/// 1. **跨页面状态传递**：核心用途是在页面间传递数据，需要跨越导航过程
///    - 源页面设置状态 → 导航到目标页面 → 目标页面消费状态
///    - 导航过程中无监听者，若无keepAlive会被dispose
///
/// 2. **用户体验期望**：用户期望从画廊发送的提示词在切换到生成页后仍然可用
///    - 若状态丢失，用户操作会无声失败，造成困惑
///
/// 3. **内存收益微小**：状态仅包含两个字符串和几个标志位，内存占用可忽略
///
/// 4. **数据无法恢复**：一旦丢失无法从其他来源重建，属于不可替代的状态
@Riverpod(keepAlive: true)
class PendingPromptNotifier extends _$PendingPromptNotifier {
  @override
  PendingPromptState build() => const PendingPromptState();

  /// 设置待填充提示词
  ///
  /// [prompt] 正向提示词
  /// [negativePrompt] 负向提示词
  /// [clearOnConsume] 消费后是否自动清空（默认 true）
  /// [targetType] 发送目标类型（可选）
  void set({
    String? prompt,
    String? negativePrompt,
    bool clearOnConsume = true,
    SendTargetType? targetType,
  }) {
    state = PendingPromptState(
      prompt: prompt,
      negativePrompt: negativePrompt,
      clearOnConsume: clearOnConsume,
      targetType: targetType,
    );
  }

  /// 消费待填充提示词
  ///
  /// 返回当前状态，如果 clearOnConsume 为 true 则自动清空
  PendingPromptState consume() {
    final current = state;
    if (current.clearOnConsume) {
      state = const PendingPromptState();
    }
    return current;
  }

  /// 清空待填充提示词
  void clear() {
    state = const PendingPromptState();
  }
}

/// 便捷 Provider：检查是否有待填充提示词
@riverpod
bool hasPendingPrompt(Ref ref) {
  final state = ref.watch(pendingPromptNotifierProvider);
  return state.prompt != null || state.negativePrompt != null;
}
