# 随机词库功能与 DIY 自定义规则文档

> 本文档详细分析 NAI-Generator-Flutter 项目的随机词库功能实现，特别是用户 DIY 自定义随机规则的部分。每个功能都包含应用场景和详细的使用方法说明。

## 目录

1. [功能概述](#功能概述)
2. [核心数据模型](#核心数据模型)
3. [随机生成模式](#随机生成模式)
4. [预设系统](#预设系统)
5. [类别管理](#类别管理)
6. [词组管理](#词组管理)
7. [选择模式详解](#选择模式详解)
8. [权重与概率系统](#权重与概率系统)
9. [作用域系统](#作用域系统)
10. [性别限定系统](#性别限定系统)
11. [嵌套词组](#嵌套词组)
12. [外部数据源集成](#外部数据源集成)
13. [变量替换系统](#变量替换系统)
14. [完整使用示例](#完整使用示例)

---

## 功能概述

随机词库功能是一个复刻并扩展 NovelAI 官方随机提示词算法的系统。

### 核心架构

```
RandomPreset (预设)
├── AlgorithmConfig (算法配置)
│   └── CharacterCountConfig (人数配置)
├── List<RandomCategory> (类别列表)
│   └── RandomCategory (类别)
│       └── List<RandomTagGroup> (词组列表)
│           └── RandomTagGroup (词组)
│               ├── List<WeightedTag> (标签列表)
│               └── List<RandomTagGroup> (嵌套子词组)
├── List<TagGroupMapping> (Danbooru TagGroup 映射)
└── List<PoolMapping> (Danbooru Pool 映射)
```

---

## 核心数据模型

### 1. RandomPreset (随机预设)

预设是最顶层的配置单元，包含完整的随机生成配置。

#### 应用场景

| 场景 | 说明 |
|------|------|
| 风格切换 | 为不同画风创建独立预设，如"赛博朋克"、"古风"、"写实" |
| 场景切换 | 为不同场景创建预设，如"室内"、"户外"、"战斗" |
| 角色类型 | 为不同角色类型创建预设，如"萌系"、"御姐"、"正太" |
| 分享配置 | 导出预设分享给其他用户 |

#### 使用方法

**创建新预设：**
```dart
// 方法1：从零创建
final preset = RandomPreset.create(
  name: '赛博朋克风格',
  description: '专注于赛博朋克和科幻元素',
);

// 方法2：从现有预设复制
final newPreset = RandomPreset.copyFrom(existingPreset, name: '复制的预设');

// 方法3：使用默认预设
final defaultPreset = RandomPreset.defaultPreset();
```

**管理预设：**
```dart
// 保存预设
await presetNotifier.updatePreset(preset);

// 选择预设
await presetNotifier.selectPreset(presetId);

// 删除预设
await presetNotifier.deletePreset(presetId);

// 重置为默认配置
await presetNotifier.resetCurrentPreset();
```

**导入导出：**
```dart
// 导出为 JSON 字符串
final jsonString = presetNotifier.exportPreset(presetId);

// 从 JSON 导入
final importedPreset = await presetNotifier.importPreset(jsonString);
```

---

### 2. RandomCategory (随机类别)

类别是语义分组，如"发色"、"瞳色"、"背景"等。

#### 应用场景

| 场景 | 说明 |
|------|------|
| 角色外观分类 | 发色、瞳色、发型、服装等 |
| 场景分类 | 背景、场景元素、天气等 |
| 风格分类 | 画风、光影效果、色调等 |
| 动作分类 | 姿势、表情、动作等 |

#### 使用方法

**创建类别：**
```dart
final category = RandomCategory.create(
  name: '赛博朋克元素',    // 显示名称
  key: 'cyberpunk',       // 程序内部标识（唯一）
  emoji: '🤖',            // 图标
);
```

**配置类别属性：**
```dart
category = category.copyWith(
  enabled: true,                              // 是否启用
  probability: 0.8,                           // 80% 概率出现
  groupSelectionMode: SelectionMode.single,   // 从词组中单选
  groupSelectCount: 1,                        // 选择1个词组
  shuffle: true,                              // 打乱输出顺序
  scope: TagScope.global,                     // 作用域
);
```

**添加到预设：**
```dart
preset = preset.addCategory(category);
```

---

### 3. RandomTagGroup (随机标签词组)

词组是类别下的具体标签集合。

#### 应用场景

| 场景 | 说明 |
|------|------|
| 同类标签分组 | 将相似标签组织在一起，如"暖色发色"、"冷色发色" |
| 主题集合 | 创建主题词组，如"圣诞节元素"、"万圣节元素" |
| 外部数据 | 同步 Danbooru 的 Tag Group 或 Pool |
| 复杂组合 | 使用嵌套词组实现多层选择逻辑 |

#### 使用方法

**创建自定义词组：**
```dart
final group = RandomTagGroup.custom(
  name: '暖色发色',
  emoji: '🔥',
  tags: [
    WeightedTag.simple('blonde hair', 10),
    WeightedTag.simple('orange hair', 8),
    WeightedTag.simple('red hair', 6),
    WeightedTag.simple('pink hair', 5),
  ],
  selectionMode: SelectionMode.single,
  probability: 1.0,
);
```

**从内置词库创建：**
```dart
final group = RandomTagGroup.fromBuiltin(
  name: '发色',
  builtinCategoryKey: 'hairColor',  // 对应 TagSubCategory.hairColor
  emoji: '🎨',
);
```

**添加到类别：**
```dart
category = category.addGroup(group);
```

---

### 4. WeightedTag (带权重标签)

最基础的标签单元，包含权重信息。

#### 应用场景

| 场景 | 说明 |
|------|------|
| 热门标签优先 | 高权重标签更容易被选中 |
| 稀有标签 | 低权重标签偶尔出现 |
| 条件依赖 | 某些标签只在特定条件下出现 |

#### 使用方法

**创建标签：**
```dart
// 简单创建
final tag1 = WeightedTag.simple('blonde hair', 10);

// 完整创建
final tag2 = WeightedTag(
  tag: 'heterochromia',
  weight: 3,                    // 较低权重，稀有出现
  translation: '异色瞳',
  conditions: ['special eyes'],  // 条件依赖
);

// 从 Danbooru 创建（自动计算权重）
final tag3 = WeightedTag.fromDanbooru(
  name: 'black_hair',
  postCount: 1500000,
);
```

**权重计算示例：**
```dart
// 假设词组中有以下标签
List<WeightedTag> tags = [
  WeightedTag(tag: 'blonde hair', weight: 10),  // 10/23 ≈ 43%
  WeightedTag(tag: 'black hair', weight: 8),    // 8/23 ≈ 35%
  WeightedTag(tag: 'red hair', weight: 5),      // 5/23 ≈ 22%
];
// 总权重 = 10 + 8 + 5 = 23
// 每个标签被选中的概率 = 自身权重 / 总权重
```

---

## 随机生成模式

### 三种模式

```dart
enum RandomGenerationMode {
  naiOfficial,  // 官网模式（复刻 NovelAI 算法）
  custom,       // 自定义模式（使用用户预设）
  hybrid,       // 混合模式（可部分自定义）
}
```

#### 应用场景

| 模式 | 适用场景 |
|------|---------|
| 官网模式 | 想要与 NAI 官网相同的随机效果 |
| 自定义模式 | 完全按照自己的规则生成 |
| 混合模式 | 使用官方算法但替换部分词库 |

#### 使用方法

**切换模式：**
```dart
// 设置模式
ref.read(randomModeNotifierProvider.notifier).setMode(RandomGenerationMode.custom);

// 快捷切换
ref.read(randomModeNotifierProvider.notifier).useNaiOfficial();
ref.read(randomModeNotifierProvider.notifier).useCustom();
ref.read(randomModeNotifierProvider.notifier).useHybrid();

// 切换（官网 ↔ 自定义）
ref.read(randomModeNotifierProvider.notifier).toggle();
```

**生成提示词：**
```dart
// 官网模式生成
final result = await generator.generateNaiStyle(
  isV4Model: true,
  seed: 12345,
);

// 自定义预设生成
final result = await generator.generateFromPreset(
  preset: myPreset,
  isV4Model: true,
  seed: 12345,
);
```

---

## 预设系统

### 应用场景

| 场景 | 操作 |
|------|------|
| 新用户入门 | 使用默认预设开始 |
| 创建个人风格 | 复制默认预设后修改 |
| 多风格切换 | 创建多个预设快速切换 |
| 分享给他人 | 导出预设 JSON 文件 |
| 使用他人配置 | 导入预设 JSON 文件 |
| 恢复默认 | 重置当前预设 |

### 使用方法

**预设 CRUD 操作：**
```dart
// 创建
final newPreset = await presetNotifier.createPreset(
  name: '我的预设',
  description: '自定义描述',
  copyFromCurrent: true,  // 从当前预设复制
);

// 读取
final currentPreset = ref.read(randomPresetNotifierProvider).selectedPreset;
final allPresets = ref.read(randomPresetNotifierProvider).presets;

// 更新
await presetNotifier.updatePreset(modifiedPreset);

// 删除（默认预设不可删除）
await presetNotifier.deletePreset(presetId);
```

**预设选择：**
```dart
// 选择预设
await presetNotifier.selectPreset(presetId);

// 获取当前选中的预设
final selected = state.selectedPreset;
```

**预设导入导出：**
```dart
// 导出
final json = presetNotifier.exportPreset(presetId);
// json 可以保存为文件或分享

// 导入
final imported = await presetNotifier.importPreset(jsonString);
if (imported != null) {
  print('导入成功: ${imported.name}');
}
```

**复制预设：**
```dart
final duplicated = await presetNotifier.duplicatePreset(
  sourcePresetId,
  '新预设名称',
);
```

---

## 类别管理

### 应用场景

| 场景 | 操作 |
|------|------|
| 添加新的标签分类 | 创建类别 |
| 调整出现概率 | 修改 probability |
| 临时禁用某类标签 | 设置 enabled = false |
| 控制选择数量 | 设置 groupSelectionMode 和 groupSelectCount |
| 统一权重设置 | 启用 useUnifiedBracket |

### 使用方法

**类别配置详解：**
```dart
final category = RandomCategory.create(
  name: '服装',
  key: 'clothing',
  emoji: '👗',
).copyWith(
  // 基础配置
  enabled: true,           // 启用该类别
  probability: 1.0,        // 100% 概率出现
  
  // 词组选择配置
  groupSelectionMode: SelectionMode.multipleNum,  // 多选模式
  groupSelectCount: 2,     // 选择2个词组
  shuffle: true,           // 打乱输出顺序
  
  // 统一权重括号（应用于所有下属词组）
  useUnifiedBracket: true,
  unifiedBracketMin: 0,
  unifiedBracketMax: 1,    // 随机添加 0-1 层权重括号
  
  // 作用域
  scope: TagScope.character,  // 仅用于角色提示词
  
  // 性别限定
  genderRestrictionEnabled: true,
  applicableGenders: ['girl'],  // 仅适用于女性角色
);
```

**类别操作：**
```dart
// 添加类别
await presetNotifier.addCategory(newCategory);

// 更新类别
await presetNotifier.updateCategory(modifiedCategory);

// 删除类别
await presetNotifier.removeCategory(categoryId);
await presetNotifier.removeCategoryByKey('clothing');

// 更新或添加（按 key 匹配）
await presetNotifier.upsertCategoryByKey(category);
```

---

## 词组管理

### 应用场景

| 场景 | 词组类型 |
|------|---------|
| 自定义标签集合 | `custom` |
| 使用内置词库 | `builtin` |
| 同步 Danbooru 分类 | `tagGroup` |
| 同步 Danbooru 图集 | `pool` |

### 使用方法

**四种词组类型创建：**

```dart
// 1. 自定义词组
final customGroup = RandomTagGroup.custom(
  name: '霓虹灯效果',
  emoji: '💡',
  tags: [
    WeightedTag.simple('neon lights', 10),
    WeightedTag.simple('cyberpunk', 8),
  ],
);

// 2. 内置词库词组
final builtinGroup = RandomTagGroup.fromBuiltin(
  name: '发色',
  builtinCategoryKey: 'hairColor',
  emoji: '🎨',
);

// 3. Danbooru Tag Group 词组
final tagGroupGroup = RandomTagGroup.fromTagGroup(
  name: 'Hair Color (Danbooru)',
  tagGroupName: 'tag_group:hair_color',
  tags: syncedTags,  // 从 API 同步的标签
);

// 4. Danbooru Pool 词组
final poolGroup = RandomTagGroup.fromPool(
  name: 'Cyberpunk Collection',
  poolId: '12345',
  postCount: 100,
  outputConfig: PoolOutputConfig(
    includeGeneral: true,
    includeCharacter: false,
    maxTagCount: 10,
  ),
);
```

**词组配置：**
```dart
group = group.copyWith(
  // 基础配置
  enabled: true,
  probability: 0.8,  // 80% 概率生效
  
  // 选择配置
  selectionMode: SelectionMode.multipleNum,
  multipleNum: 3,    // 选择3个标签
  shuffle: true,     // 打乱顺序
  
  // 权重括号
  bracketMin: 0,
  bracketMax: 2,     // 随机 0-2 层括号
  
  // 作用域和性别
  scope: TagScope.character,
  genderRestrictionEnabled: true,
  applicableGenders: ['girl'],
);
```

**词组操作：**
```dart
// 添加词组到类别
await presetNotifier.addGroupToCategory('clothing', newGroup);

// 从类别移除词组
await presetNotifier.removeGroupFromCategory('clothing', groupId);

// 切换词组启用状态
await presetNotifier.toggleGroupEnabled('clothing', groupId);

// 更新自定义词组
await presetNotifier.updateCustomGroup(groupId, modifiedGroup);
```

---

## 选择模式详解

### SelectionMode 枚举

```dart
enum SelectionMode {
  single,       // 单选（加权随机选择一个）
  all,          // 全选（选择所有子项）
  multipleNum,  // 多选指定数量
  multipleProb, // 多选概率模式
  sequential,   // 顺序轮替
}
```

### 各模式详解

#### 1. Single (单选)

**应用场景：**
- 发色选择（一个角色只有一种发色）
- 主背景选择（一张图只有一个主背景）
- 画风选择（一张图只有一种主画风）

**使用方法：**
```dart
group = group.copyWith(
  selectionMode: SelectionMode.single,
);

// 权重越高，被选中概率越大
// 例如：
// blonde hair (weight: 10) -> 10/23 ≈ 43%
// black hair (weight: 8)   -> 8/23 ≈ 35%
// red hair (weight: 5)     -> 5/23 ≈ 22%
```

#### 2. All (全选)

**应用场景：**
- 固定标签组合（如"masterpiece, best quality"）
- 必须同时出现的标签
- 基础画质标签

**使用方法：**
```dart
group = group.copyWith(
  selectionMode: SelectionMode.all,
  shuffle: true,  // 可选：打乱输出顺序
);

// 所有启用的标签都会被选中
```

#### 3. MultipleNum (多选数量)

**应用场景：**
- 配饰选择（选择2-3个配饰）
- 场景元素（选择多个场景细节）
- 服装组合（选择多件服装）

**使用方法：**
```dart
group = group.copyWith(
  selectionMode: SelectionMode.multipleNum,
  multipleNum: 3,    // 随机选择3个不重复的标签
  shuffle: true,     // 打乱输出顺序
);
```

#### 4. MultipleProb (多选概率)

**应用场景：**
- 每个标签独立判断是否出现
- 可能出现0个、1个或多个标签
- 适合可选的装饰性元素

**使用方法：**
```dart
group = group.copyWith(
  selectionMode: SelectionMode.multipleProb,
);

// 每个标签使用自己的概率进行独立判断
// 如果标签没有设置概率，使用归一化的权重作为概率
```

#### 5. Sequential (顺序轮替)

**应用场景：**
- 批量生成时确保每次不同
- 遍历所有可能的标签
- 系统性测试不同标签效果

**使用方法：**
```dart
group = group.copyWith(
  selectionMode: SelectionMode.sequential,
);

// 跨批次保持状态
// 第1次生成: 选择第0个标签
// 第2次生成: 选择第1个标签
// ...循环往复
```

---

## 权重与概率系统

### 应用场景

| 功能 | 应用场景 |
|------|---------|
| 标签权重 | 控制标签被选中的相对概率 |
| 类别概率 | 控制整个类别是否参与生成 |
| 词组概率 | 控制词组是否参与生成 |
| 权重括号 | 在生成的提示词中添加权重修饰 |

### 使用方法

#### 标签权重

```dart
// 权重越高，被选中概率越大
List<WeightedTag> tags = [
  WeightedTag.simple('common tag', 10),   // 常见
  WeightedTag.simple('normal tag', 5),    // 普通
  WeightedTag.simple('rare tag', 1),      // 稀有
];
```

#### 类别/词组概率

```dart
// 类别概率：整个类别是否参与生成
category = category.copyWith(probability: 0.8);  // 80% 概率参与

// 词组概率：词组是否参与生成
group = group.copyWith(probability: 0.5);  // 50% 概率参与
```

#### 权重括号

```dart
// 正数使用 {} 增强权重
// 负数使用 [] 减弱权重
group = group.copyWith(
  bracketMin: 0,
  bracketMax: 2,
);
// 结果可能是: "tag", "{tag}", "{{tag}}"

group = group.copyWith(
  bracketMin: -2,
  bracketMax: 0,
);
// 结果可能是: "tag", "[tag]", "[[tag]]"

group = group.copyWith(
  bracketMin: -1,
  bracketMax: 1,
);
// 结果可能是: "[tag]", "tag", "{tag}"
```

---

## 作用域系统

### TagScope 枚举

```dart
enum TagScope {
  global,     // 仅全局/主提示词
  character,  // 仅角色提示词
  all,        // 两者都适用（默认）
}
```

### 应用场景

| 作用域 | 适用标签类型 | 示例 |
|--------|-------------|------|
| `global` | 背景、场景、风格、光影 | "sunset", "city background", "cinematic lighting" |
| `character` | 角色外观、服装、配饰 | "blonde hair", "red dress", "glasses" |
| `all` | 姿势、表情、动作 | "smile", "standing", "looking at viewer" |

### 使用方法

```dart
// 类别级作用域
category = category.copyWith(scope: TagScope.global);

// 词组级作用域
group = group.copyWith(scope: TagScope.character);

// 生成时自动过滤
// 生成主提示词时：只使用 scope = global 或 all 的内容
// 生成角色提示词时：只使用 scope = character 或 all 的内容
```

**典型配置示例：**
```dart
// 背景类别 - 仅主提示词
final bgCategory = RandomCategory.create(
  name: '背景',
  key: 'background',
).copyWith(scope: TagScope.global);

// 发色类别 - 仅角色提示词
final hairCategory = RandomCategory.create(
  name: '发色',
  key: 'hairColor',
).copyWith(scope: TagScope.character);

// 表情类别 - 两者都适用
final expressionCategory = RandomCategory.create(
  name: '表情',
  key: 'expression',
).copyWith(scope: TagScope.all);
```

---

## 性别限定系统

### 应用场景

| 场景 | 说明 |
|------|------|
| 女性专属服装 | 裙子、女性泳装等 |
| 男性专属服装 | 西装、领带等 |
| 性别特征 | 胸部特征、身材特征等 |
| 通用标签 | 适用于所有性别 |

### 使用方法

**类别级性别限定：**
```dart
final femaleClothingCategory = RandomCategory.create(
  name: '女性服装',
  key: 'clothingFemale',
).copyWith(
  genderRestrictionEnabled: true,
  applicableGenders: ['girl'],  // 仅适用于女性角色
);
```

**词组级性别限定：**
```dart
final dressGroup = RandomTagGroup.custom(
  name: '连衣裙',
  tags: [...],
).copyWith(
  genderRestrictionEnabled: true,
  applicableGenders: ['girl'],
);

final suitGroup = RandomTagGroup.custom(
  name: '西装',
  tags: [...],
).copyWith(
  genderRestrictionEnabled: true,
  applicableGenders: ['boy'],
);
```

**支持的性别值：**
- `'girl'` - 女性
- `'boy'` - 男性
- `'other'` - 其他
- 空数组 `[]` - 适用于所有性别

---

## 嵌套词组

### 应用场景

| 场景 | 说明 |
|------|------|
| 复杂服装组合 | 上衣 + 下装 + 鞋子的组合选择 |
| 分层选择 | 先选择大类，再从大类中选择具体标签 |
| 条件组合 | 某些标签组合必须一起出现 |

### 使用方法

**创建嵌套词组：**
```dart
final clothingCombo = RandomTagGroup.custom(
  name: '完整服装组合',
  nodeType: TagGroupNodeType.config,  // 设置为嵌套配置类型
  children: [
    RandomTagGroup.custom(
      name: '上衣',
      tags: [
        WeightedTag.simple('shirt', 10),
        WeightedTag.simple('blouse', 8),
        WeightedTag.simple('sweater', 6),
      ],
      selectionMode: SelectionMode.single,
    ),
    RandomTagGroup.custom(
      name: '下装',
      tags: [
        WeightedTag.simple('skirt', 10),
        WeightedTag.simple('pants', 8),
        WeightedTag.simple('shorts', 5),
      ],
      selectionMode: SelectionMode.single,
    ),
    RandomTagGroup.custom(
      name: '鞋子',
      tags: [
        WeightedTag.simple('high heels', 8),
        WeightedTag.simple('boots', 7),
        WeightedTag.simple('sneakers', 5),
      ],
      selectionMode: SelectionMode.single,
      probability: 0.7,  // 70% 概率选择鞋子
    ),
  ],
  selectionMode: SelectionMode.all,  // 选择所有子词组
);
```

**嵌套词组的选择模式：**
```dart
// 选择所有子词组
parent.copyWith(selectionMode: SelectionMode.all);

// 从子词组中随机选择一个
parent.copyWith(selectionMode: SelectionMode.single);

// 从子词组中选择指定数量
parent.copyWith(
  selectionMode: SelectionMode.multipleNum,
  multipleNum: 2,
);
```

---

## 外部数据源集成

### Danbooru Tag Group

#### 应用场景

| 场景 | 说明 |
|------|------|
| 扩展词库 | 使用 Danbooru 的丰富标签分类 |
| 保持更新 | 同步最新的热门标签 |
| 热度过滤 | 只使用达到热度阈值的标签 |

#### 使用方法

```dart
// 创建 Tag Group 映射
final mapping = TagGroupMapping.simple(
  groupTitle: 'tag_group:hair_color',
  targetCategory: TagSubCategory.hairColor,
  includeChildren: true,  // 包含子分组
);

// 添加到预设
await presetNotifier.addTagGroupMapping(mapping);

// 配置热度阈值
mapping = mapping.copyWith(
  customMinPostCount: 1000,  // 只同步热度 >= 1000 的标签
);
```

### Danbooru Pool

#### 应用场景

| 场景 | 说明 |
|------|------|
| 主题集合 | 使用特定主题的图片集合中的标签 |
| 风格学习 | 从特定艺术家或风格的集合中提取标签 |
| 角色参考 | 从角色相关的 Pool 中获取标签 |

#### 使用方法

```dart
// 创建 Pool 映射
final poolMapping = PoolMapping(
  id: 'pool_12345',
  poolId: 12345,
  poolName: 'Cyberpunk Collection',
  postCount: 100,
  targetCategory: TagSubCategory.scene,
  createdAt: DateTime.now(),
  outputConfig: PoolOutputConfig(
    includeGeneral: true,      // 包含通用标签
    includeCharacter: false,   // 不包含角色标签
    includeCopyright: false,   // 不包含版权标签
    includeArtist: false,      // 不包含艺术家标签
    maxTagCount: 10,           // 每个帖子最多取10个标签
    shuffleTags: true,         // 打乱标签顺序
  ),
);

// 添加到预设
await presetNotifier.addPoolMapping(poolMapping);
```

---

## 变量替换系统

### 应用场景

| 场景 | 说明 |
|------|------|
| 动态组合 | 在标签中引用其他类别的生成结果 |
| 复杂描述 | 构建包含随机元素的复杂描述 |
| 模板复用 | 创建可复用的标签模板 |

### 语法

```
__变量名__
```

变量名可以是：
- 类别的 `name` 或 `key`
- 词组的 `name`

### 使用方法

**基础用法：**
```dart
// 创建使用变量的标签
final tag = WeightedTag(
  tag: '__hairColor__ hair',  // 引用 hairColor 类别
  weight: 10,
);

// 生成时会自动替换
// 结果可能是: "blonde hair", "black hair", "red hair" 等
```

**复杂示例：**
```dart
// 创建一个复杂的组合描述
final complexTag = WeightedTag(
  tag: 'a girl with __hairColor__ hair and __eyeColor__ eyes',
  weight: 10,
);

// 生成结果可能是:
// "a girl with blonde hair and blue eyes"
// "a girl with black hair and red eyes"
// 等等...
```

**引用词组：**
```dart
// 假设有一个名为 "暖色发色" 的词组
final tag = WeightedTag(
  tag: '__暖色发色__',  // 引用特定词组
  weight: 10,
);
```

---

## 完整使用示例

### 示例1：创建赛博朋克风格预设

```dart
// 1. 创建预设
var preset = RandomPreset.create(
  name: '赛博朋克风格',
  description: '专注于赛博朋克和科幻元素',
);

// 2. 创建霓虹灯类别
var neonCategory = RandomCategory.create(
  name: '霓虹灯效果',
  key: 'neon',
  emoji: '💡',
).copyWith(
  probability: 0.9,
  scope: TagScope.global,
);

// 3. 添加词组
final neonGroup = RandomTagGroup.custom(
  name: '霓虹灯',
  emoji: '✨',
  tags: [
    WeightedTag.simple('neon lights', 10),
    WeightedTag.simple('neon sign', 8),
    WeightedTag.simple('neon glow', 6),
    WeightedTag.simple('colorful lights', 5),
  ],
  selectionMode: SelectionMode.multipleNum,
  multipleNum: 2,
);

neonCategory = neonCategory.addGroup(neonGroup);
preset = preset.addCategory(neonCategory);

// 4. 创建科技元素类别
var techCategory = RandomCategory.create(
  name: '科技元素',
  key: 'tech',
  emoji: '🤖',
).copyWith(
  probability: 0.8,
  scope: TagScope.all,
);

final techGroup = RandomTagGroup.custom(
  name: '科技',
  tags: [
    WeightedTag.simple('cyberpunk', 10),
    WeightedTag.simple('hologram', 8),
    WeightedTag.simple('mechanical parts', 6),
    WeightedTag.simple('wires', 4),
    WeightedTag.simple('circuit board', 3),
  ],
  selectionMode: SelectionMode.multipleNum,
  multipleNum: 3,
  bracketMin: 0,
  bracketMax: 1,
);

techCategory = techCategory.addGroup(techGroup);
preset = preset.addCategory(techCategory);

// 5. 保存预设
await presetNotifier.updatePreset(preset);

// 6. 使用预设生成
final result = await generator.generateFromPreset(
  preset: preset,
  isV4Model: true,
);

print(result.mainPrompt);
// 可能输出: "neon lights, neon glow, {cyberpunk}, hologram, mechanical parts"
```

### 示例2：配置性别特定的服装

```dart
// 创建服装类别
var clothingCategory = RandomCategory.create(
  name: '服装',
  key: 'clothing',
  emoji: '👗',
).copyWith(
  probability: 1.0,
  scope: TagScope.character,
  groupSelectionMode: SelectionMode.single,
);

// 女性服装词组
final femaleClothing = RandomTagGroup.custom(
  name: '女性服装',
  emoji: '👗',
  tags: [
    WeightedTag.simple('dress', 10),
    WeightedTag.simple('skirt', 8),
    WeightedTag.simple('blouse', 6),
  ],
  selectionMode: SelectionMode.single,
).copyWith(
  genderRestrictionEnabled: true,
  applicableGenders: ['girl'],
);

// 男性服装词组
final maleClothing = RandomTagGroup.custom(
  name: '男性服装',
  emoji: '👔',
  tags: [
    WeightedTag.simple('suit', 10),
    WeightedTag.simple('shirt', 8),
    WeightedTag.simple('jacket', 6),
  ],
  selectionMode: SelectionMode.single,
).copyWith(
  genderRestrictionEnabled: true,
  applicableGenders: ['boy'],
);

// 通用服装词组
final generalClothing = RandomTagGroup.custom(
  name: '通用服装',
  emoji: '👕',
  tags: [
    WeightedTag.simple('hoodie', 8),
    WeightedTag.simple('t-shirt', 7),
    WeightedTag.simple('coat', 6),
  ],
  selectionMode: SelectionMode.single,
);

clothingCategory = clothingCategory
  .addGroup(femaleClothing)
  .addGroup(maleClothing)
  .addGroup(generalClothing);

// 生成时会自动根据角色性别过滤词组
```

### 示例3：使用顺序轮替确保批量生成多样性

```dart
// 创建使用顺序轮替的词组
final sequentialGroup = RandomTagGroup.custom(
  name: '轮替背景',
  tags: [
    WeightedTag.simple('beach', 1),
    WeightedTag.simple('forest', 1),
    WeightedTag.simple('city', 1),
    WeightedTag.simple('mountain', 1),
    WeightedTag.simple('space', 1),
  ],
  selectionMode: SelectionMode.sequential,  // 顺序轮替
);

// 批量生成时，每次生成会使用不同的背景
// 第1次: beach
// 第2次: forest
// 第3次: city
// 第4次: mountain
// 第5次: space
// 第6次: beach (循环)
```

---

## 总结

NAI-Generator-Flutter 的随机词库系统提供了强大而灵活的 DIY 自定义能力：

| 功能 | 应用价值 |
|------|---------|
| 预设系统 | 快速切换不同风格配置 |
| 类别管理 | 组织和管理不同类型的标签 |
| 词组管理 | 灵活配置标签集合和选择规则 |
| 选择模式 | 5种模式满足不同选择需求 |
| 权重系统 | 精细控制标签出现概率 |
| 作用域 | 区分全局和角色提示词 |
| 性别限定 | 为不同性别角色配置专属标签 |
| 嵌套词组 | 实现复杂的多层选择逻辑 |
| 外部集成 | 扩展词库来源 |
| 变量替换 | 动态内容组合 |

通过这些功能的组合使用，用户可以创建出符合个人偏好的独特随机生成规则。
