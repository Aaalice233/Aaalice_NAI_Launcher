

---

## Task 9: PreciseRefType UI 扩展提取

### 决策: 使用命名参数方式传递本地化字符串

**问题**: 扩展方法无法直接访问 `BuildContext`，如何获取本地化显示名称？

**选项对比**:

| 方案 | 实现 | 优点 | 缺点 |
|------|------|------|------|
| A: 传入 context | `getDisplayName(BuildContext context)` | 调用简洁 | 扩展依赖 Flutter，与 UI 紧密耦合 |
| B: 传入本地化字符串 | `getDisplayName({required String character, ...})` | 解耦，可测试，灵活 | 调用时参数较多 |
| C: 返回 key | 只返回 `displayNameKey` | 最简单 | 调用方仍需处理本地化 |

**选择**: 方案 B

**理由**:
1. 扩展方法应保持与 UI 框架的解耦（虽然需要 Flutter 的 IconData）
2. 方便单元测试，不需要 mock BuildContext
3. 调用方可以根据上下文决定使用本地化还是硬编码字符串
4. 明确的参数名称提高了代码可读性

### 实现细节

```dart
extension PreciseRefTypeUI on PreciseRefType {
  String getDisplayName({
    required String character,
    required String style,
    required String characterAndStyle,
  });
  
  IconData get icon; // 使用 getter 比方法更简洁
}
```

### 代码复用效果

**Before**: 两个类中重复定义相同方法（父类 17 行 + 子类 8 行 = 25 行重复代码）

**After**: 扩展文件 28 行，两处调用各 1-2 行

### 执行时间
- 文件创建: 1 次
- 面板更新: 3 处修改（导入 + 2 处调用）
- 重复代码移除: 2 个方法

---

验证完成: Task 9

## Task 8: Anlas Cost Badge Extraction
- **Component**: `AnlasCostBadge` created in `lib/presentation/widgets/common/anlas_cost_badge.dart`.
- **Logic**: Encapsulated `estimatedCostProvider`, `isFreeGenerationProvider`, `isBalanceInsufficientProvider`.
- **Visibility**: Badge hides itself when `isGenerating` (prop) or `isFree` (internal state) is true.
- **Spacing**: Included `margin-left: 8` within the badge to handle spacing from preceding text, returning `SizedBox.shrink()` when hidden to collapse spacing. This avoids conditional spacing logic in parent layouts.
- **Testing**: Added unit tests for visibility and color states in `test/presentation/widgets/common/anlas_cost_badge_test.dart`.
