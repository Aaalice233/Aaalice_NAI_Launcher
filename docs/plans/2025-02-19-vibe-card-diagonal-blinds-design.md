# Vibe 卡片重构设计 - 斜向百叶窗展开效果

## 概述

统一 Bundle 和非 Bundle Vibe 卡片组件，为 Bundle 类型卡片添加斜向百叶窗展开动画效果，展示子 vibe 预览。

## 设计目标

1. **统一组件**：Bundle 和非 Bundle 使用同一卡片组件
2. **空间优化**：展开效果在卡片内部完成，不占用外部空间
3. **Steam/游戏风格**：保持科技感，边缘发光、阴影层次
4. **简洁交互**：非 Bundle 卡片保持简洁，Bundle 卡片悬停展开

## 组件架构

### 新组件：VibeCard

替换现有的 `VibeCard3D`，成为统一的 Vibe 卡片组件。

```dart
class VibeCard extends StatefulWidget {
  final VibeLibraryEntry entry;
  final double width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  // ... 其他回调
}
```

## 两种展示模式

### 1. 非 Bundle 卡片（简洁模式）

**默认状态**：
- 缩略图展示
- 名称、Strength/Info Extracted 进度条
- 收藏按钮

**悬停效果**：
- 轻微放大（scale 1.02-1.03）
- 阴影增强
- 边缘微光（主题色发光边框）
- 右侧显示操作按钮

### 2. Bundle 卡片（百叶窗展开模式）

**默认状态**：与普通卡片一致

**悬停动画 - 斜向百叶窗展开**：

```
默认状态              展开中                完全展开
┌─────────┐          ┌─────────┐          ┌─────────┐
│ 主缩略图 │    →     │╲ 1 ╱ 2 ╲│    →     │╲1╱2╲3╱4╲│
│  +信息   │          │ ╲ ╱ 3 ╲ │          │5╱───────│
│         │          │  ╲4╱5───│          │─────────│
└─────────┘          └─────────┘          └─────────┘
```

**展开效果细节**：
- **百叶窗条**：3-5 条斜向分割区域（根据子 vibe 数量动态调整）
- **展开方向**：右下到左上斜向
- **动画方式**：叶片斜向滑出/旋转打开，露出背后子 vibe
- **子 vibe 展示**：每个百叶窗条后方显示对应子 vibe 缩略图
- **动画时长**：300-400ms，easeOutCubic 曲线

**收起动画**：反向播放，叶片复位

## 视觉风格（Steam/游戏风格）

### 颜色与发光
- 边缘发光：使用主题主色
- 发光强度随悬停状态变化
- 暗色主题下效果更明显

### 阴影层次
- 默认：轻微阴影
- 悬停：多层阴影增加深度感
- Bundle 展开时：阴影进一步扩展

### 圆角与边框
- 卡片圆角：12px
- 百叶窗条圆角：与卡片一致
- 悬停时显示主题色边框

## 技术实现方案

### 动画控制器
```dart
AnimationController _blindsController;
Animation<double> _blindsAnimation;
```

### 百叶窗实现
使用 `Stack` + `Transform` + `ClipPath` 实现斜向分割：

1. **底层**：子 vibe 缩略图层（预先加载）
2. **上层**：百叶窗叶片层（默认遮盖底层）
3. **动画**：叶片斜向位移或旋转，露出底层

### 性能优化
- `RepaintBoundary` 隔离动画区域
- 子 vibe 缩略图预加载
- 使用 `Transform` 而非 `top/left` 动画

## 文件变更

### 修改
- `lib/presentation/screens/vibe_library/widgets/vibe_card_3d.dart` → 重命名为 `vibe_card.dart` 并完全重写

### 引用更新
- `vibe_library_screen.dart` 中的导入和组件使用
- `vibe_selector_dialog.dart` 中的引用
- `unified_reference_panel.dart` 中的引用

## 验收标准

1. Bundle 和非 Bundle 卡片使用统一组件
2. Bundle 卡片悬停时斜向百叶窗展开，展示子 vibe 预览
3. 非 Bundle 卡片悬停时保持简洁效果
4. 动画流畅，无卡顿
5. 支持主题色适配
6. 代码符合项目规范
