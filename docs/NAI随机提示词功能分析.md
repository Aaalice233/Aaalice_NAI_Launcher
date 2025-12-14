# NovelAI 随机提示词按钮功能分析

> **分析版本**: NovelAI Image Generation (2025年12月)
> **分析方法**: JavaScript Bundle 逆向工程
> **主要文件**: `9182-e447568fbb92a99a.js.下载` (685KB)

---

## 目录

1. [概述](#概述)
2. [核心发现](#核心发现)
   - [纯前端实现](#1-纯前端实现)
   - [数据结构](#2-数据结构)
   - [核心算法](#3-核心算法)
   - [生成逻辑](#4-生成逻辑)
3. [技术架构](#技术架构)
4. [主提示词与角色提示词的联动机制](#主提示词与角色提示词的联动机制)
   - [混淆函数名称对照表](#混淆函数名称对照表)
   - [角色数量决策](#1-角色数量决策)
   - [返回值格式](#2-返回值格式)
   - [联动分发逻辑](#3-联动分发逻辑)
   - [Dart 实现示例](#8-dart-实现示例)
   - [注意事项与已知限制](#9-注意事项与已知限制)
5. [Danbooru 标签数据库详解](#danbooru-标签数据库详解)
6. [实现建议](#实现建议)
7. [附录：常用 API 查询示例](#附录常用-api-查询示例)
8. [快速参考](#快速参考)

---

## 概述

本文档通过逆向分析 NovelAI 官网的 JavaScript 代码，详细记录了**随机提示词按钮**（Random Prompt Button）的实现原理。

### 分析目的

- 理解 NovelAI 随机提示词的生成算法
- 掌握主提示词与角色提示词的联动机制
- 为本地实现类似功能提供参考

### 适用场景

- NovelAI V4 / V4.5 模型（支持多角色提示词）
- NovelAI Furry V3 模型（使用专用词库）
- 传统模型（单提示词模式）

---

## 核心发现

### 1. 纯前端实现

- 点击随机按钮时**没有任何网络请求**
- 标签词库完全**硬编码在 JavaScript bundle** 中
- 主要代码位于 `9182-e447568fbb92a99a.js.下载`（685KB）

### 2. 数据结构

标签使用**带权重的数组**格式存储：

```javascript
["标签名称", 权重, [可选的条件数组]]
```

实际示例：
```javascript
["blonde hair", 5]
["blue eyes", 6]
["scenery", 100]
["abstract background", 1]
["abs", 5]
["ahoge", 6]
["angel", 2]
["android", 5]
```

权重越高，被随机选中的概率越大。

### 3. 核心算法

加权随机选择函数 `ty`（混淆后名称）：

```javascript
/**
 * 加权随机选择函数
 * @param e - 标签数组，每个元素格式为 [标签名, 权重, 条件数组?]
 * @param t - 当前上下文（用于条件过滤）
 * @returns 选中的标签名称
 */
function ty(e, t) {
  // 1. 过滤符合条件的标签（如果有条件数组，检查是否满足）
  let a = e.filter(e => !e[2] || e[2].some(e => t.includes(e)));

  // 2. 计算总权重
  let i = 0;
  for (let e of a) i += e[1];

  // 3. 生成 [1, 总权重] 范围内的随机数
  let r = tf(i, 1);  // tf(max, min) = Math.random() * (max - min) + min

  // 4. 累加权重直到超过随机数，返回对应标签
  let s = 0;
  for (let e of a) {
    if (r <= (s += e[1])) return e[0];
  }
  throw Error("getWeightedChoice: should not reach here");
}
```

### 4. 生成逻辑

随机提示词通过**概率性组合多个标签类别**生成：

```javascript
// 伪代码示意（变量名为混淆后名称）
// 每个类别约 50% 概率被选中
Math.random() > 0.5 && result.push(ty(eZ, ctx))  // eZ = 发色数组
Math.random() > 0.5 && result.push(ty(e$, ctx))  // e$ = 瞳色数组
Math.random() > 0.5 && result.push(ty(th, ctx))  // th = 服装数组
Math.random() > 0.5 && result.push(ty(eJ, ctx))  // eJ = 姿势数组
Math.random() > 0.5 && result.push(ty(eX, ctx))  // eX = 背景数组
Math.random() > 0.5 && result.push(ty(eQ, ctx))  // eQ = 场景数组
// ... 更多类别
```

> **注意**：每个类别有约 50% 概率被包含在最终提示词中，这确保了生成结果的多样性。

### 5. 标签分类（从代码推断）

| 类别 | 示例标签 |
|------|----------|
| 发色 | blonde hair, blue hair, black hair, brown hair |
| 瞳色 | blue eyes, amber eyes, red eyes |
| 发型 | long hair, short hair, ahoge, afro |
| 背景 | scenery, abstract background, blurred background |
| 姿势 | action pose, all fours, against wall |
| 物种 | angel, android, alien, amphibian |
| 风格 | photorealistic, abstract |

### 6. 示例输出

从 HTML 快照中捕获的实际输出：
```
no humans, photorealistic, scenery, building, nature, sky, jack-o'-lantern, fruit, lemon, smoking pipe
```

## 技术架构

```
┌──────────────────────────────────────────────────────────┐
│                   点击 Random 按钮                        │
└────────────────────────┬─────────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────────┐
│  遍历各个标签类别（发色、瞳色、背景、姿势等）              │
│  对每个类别：                                             │
│    if (Math.random() > 0.5) {                            │
│      选中的标签.push( 加权随机选择(该类别标签数组) )       │
│    }                                                      │
└────────────────────────┬─────────────────────────────────┘
                         ▼
┌──────────────────────────────────────────────────────────┐
│  将所有选中的标签用逗号连接                               │
│  输出: "blonde hair, blue eyes, scenery, ..."            │
└──────────────────────────────────────────────────────────┘
```

---

## 主提示词与角色提示词的联动机制

NovelAI V4/V4.5 模型支持**多角色提示词**功能，随机按钮会智能生成主提示词和角色提示词的组合。

### 混淆函数名称对照表

由于 JavaScript 代码经过混淆处理，以下是关键函数的原始含义：

| 混淆名称 | 推断功能 | 说明 |
|---------|---------|------|
| `t7` | `getWeightedChoice` | 加权随机选择函数 |
| `tf` | `randomInRange` | 生成指定范围内的随机数 |
| `ty` | `getWeightedChoiceFiltered` | 带条件过滤的加权随机选择 |
| `eZ`, `e$`, `th`... | 各类别标签数组 | 如发色、瞳色、服装等 |
| `at` | `multiCharacterTemplate` | V4/V4.5 多角色模板 |
| `tb` | `legacyTemplate` | 传统单提示词模板 |

### 1. 角色数量决策

首先通过加权随机决定生成几个角色：

```javascript
// 角色数量权重分布
// t7 是混淆后的加权随机选择函数，等价于 getWeightedChoice
t7([[1, 70], [2, 20], [3, 7], [0, 5]], context)
```

| 角色数量 | 权重 | 概率 |
|---------|------|------|
| 1 个角色 | 70 | ~70% |
| 2 个角色 | 20 | ~20% |
| 3 个角色 | 7 | ~7% |
| 0 个角色（no humans） | 5 | ~5% |

### 2. 返回值格式

随机生成函数始终返回**数组格式**，根据角色数量包含不同数量的元素：

```javascript
// 无角色场景（no humans）：返回单元素数组
return [noHumanPrompt.join(", ")]  // 例: ["no humans, scenery, building"]

// 有角色场景：返回多元素数组
return [
  mainPrompt.join(", "),           // result[0] = 主提示词（背景、画风等）
  ...characterPrompts.map(e => e.join(", "))  // result[1], result[2]... = 各角色提示词
]
// 例: ["solo, detailed background", "1girl, blonde hair, blue eyes"]
```

### 3. 联动分发逻辑

点击随机按钮后，将生成结果自动分发到主提示词和角色提示词输入框：

```javascript
function handleRandomClick() {
  let result = generateRandomPrompt();  // 调用随机生成函数，返回数组

  // 第一个元素始终是主提示词
  setRandomPrompt(result[0]);

  // 如果只有一个元素（no humans 场景），清空角色提示词
  if (result.length === 1) {
    setCharacterPrompts([]);
    return;
  }

  // 后续元素转换为角色提示词对象
  let charPrompts = [];
  for (let i = 1; i < result.length; i++) {
    charPrompts.push({
      prompt: result[i],           // 角色描述
      uc: "lowres, aliasing, ",    // 默认负面提示词
      center: { x: 0, y: 0 },      // 默认位置（中心）
      enabled: true
    });
  }
  setCharacterPrompts(charPrompts);  // 设置角色提示词数组
}
```

### 4. 不同模型的模板选择

根据当前选择的模型，使用不同的随机生成模板：

```javascript
// 模型判断逻辑
const randomTemplate = useMemo(() => {
  if (model.characterPrompts) {
    return multiCharacterTemplate;     // V4/V4.5: 支持多角色
  }
  if (model === naiDiffusionFurryV3) {
    return furryTemplate;              // Furry V3: 使用 Furry 专用词库
  }
  return legacyTemplate;               // 其他模型: 传统单提示词
}, [model]);
```

### 5. 多角色生成流程（V4/V4.5）

```
┌────────────────────────────────────────────────────────────┐
│                     点击 Random 按钮                        │
└─────────────────────────┬──────────────────────────────────┘
                          ▼
┌────────────────────────────────────────────────────────────┐
│  1. 决定角色数量 (1/2/3/0)                                  │
│     权重: [[1,70], [2,20], [3,7], [0,5]]                   │
└─────────────────────────┬──────────────────────────────────┘
                          ▼
           ┌──────────────┴──────────────┐
           ▼                              ▼
┌─────────────────────┐      ┌─────────────────────────────┐
│ 角色数=0            │      │ 角色数>=1                    │
│ 生成 "no humans"    │      │ 为每个角色生成独立提示词     │
│ + 场景/物品标签     │      │ + 生成共享的主提示词         │
└─────────┬───────────┘      └─────────────┬───────────────┘
          ▼                                ▼
┌─────────────────────┐      ┌─────────────────────────────┐
│ 返回: [主提示词]    │      │ 返回: [主提示词, 角色1,     │
│ (单元素数组)        │      │        角色2, ...]          │
└─────────┬───────────┘      └─────────────┬───────────────┘
          └──────────────┬─────────────────┘
                         ▼
┌────────────────────────────────────────────────────────────┐
│  2. 分发到 UI                                               │
│     - result[0] → 主提示词输入框                            │
│     - result[1...n] → 角色提示词列表                        │
└────────────────────────────────────────────────────────────┘
```

### 6. 单角色生成内容

当生成单个角色时，包含以下内容：

```javascript
// 主提示词包含的元素
let mainPrompt = [];

// 30% 概率添加画风
if (0.3 > Math.random()) mainPrompt.push(getWeighted(styleArray));

// 添加 "solo" (单人)
mainPrompt.push("solo");

// 添加背景 (90% 概率)
if (0.9 > Math.random()) {
  let bg = getWeighted(backgroundArray);
  mainPrompt.push(bg);
  // 如果是详细背景，添加额外场景元素
  if (bg === "detailed background" || bg === "amazing background") {
    let sceneCount = getWeighted([[1, 50], [2, 20]]);
    for (let i = 0; i < sceneCount; i++) {
      mainPrompt.push(getWeighted(sceneArray));
    }
  }
}

// 角色提示词包含的元素
let charPrompt = [];
charPrompt.push("1girl");  // 或 1boy
charPrompt.push(getWeighted(hairColorArray));   // 发色
charPrompt.push(getWeighted(eyeColorArray));    // 瞳色
charPrompt.push(getWeighted(clothingArray));    // 服装
// ... 更多角色特征
```

### 7. Furry 模式的性别分布

Furry V3 模型使用不同的性别权重：

```javascript
// 性别权重分布
getWeighted([["m", 45], ["f", 45], ["o", 10]])
```

| 性别 | 标签 | 权重 |
|------|------|------|
| 男性 (m) | `male` | 45% |
| 女性 (f) | `female` | 45% |
| 其他 (o) | `ambiguous gender` | 10% |

```javascript
// 根据性别计数添加标签
if (femaleCount > 0) mainPrompt.push("female");
if (maleCount > 0) mainPrompt.push("male");
if (otherCount > 0) mainPrompt.push("ambiguous gender");

// 添加人数描述
// 注意: "duo" 和 "trio" 是 Danbooru 已废弃的标签，Furry 模式使用具体组合
switch (characterCount) {
  case 1: mainPrompt.push("solo"); break;
  case 2: mainPrompt.push("2girls"); break;  // 或根据性别: 2boys, 1girl 1boy
  case 3: mainPrompt.push("multiple girls"); break;  // 或根据性别组合
}
```

### 8. Dart 实现示例

```dart
/// 随机生成结果
class RandomPromptResult {
  final String mainPrompt;
  final List<CharacterPrompt> characterPrompts;

  RandomPromptResult({
    required this.mainPrompt,
    this.characterPrompts = const [],
  });
}

/// 角色提示词
class CharacterPrompt {
  final String prompt;
  final String uc;
  final Point center;
  final bool enabled;

  CharacterPrompt({
    required this.prompt,
    this.uc = "lowres, aliasing, ",
    this.center = const Point(0, 0),
    this.enabled = true,
  });
}

/// 生成带联动的随机提示词
RandomPromptResult generateRandomPromptWithCharacters({
  required Map<String, List<WeightedTag>> mainCategories,
  required Map<String, List<WeightedTag>> characterCategories,
}) {
  final random = Random();

  // 1. 决定角色数量
  final characterCountWeights = [
    WeightedTag('1', 70),
    WeightedTag('2', 20),
    WeightedTag('3', 7),
    WeightedTag('0', 5),
  ];
  final characterCount = int.parse(getWeightedChoice(characterCountWeights));

  // 2. 无角色场景
  if (characterCount == 0) {
    final mainTags = <String>['no humans'];

    // 添加场景/物品标签
    for (final category in mainCategories.values) {
      if (random.nextBool()) {
        mainTags.add(getWeightedChoice(category));
      }
    }

    return RandomPromptResult(mainPrompt: mainTags.join(', '));
  }

  // 3. 有角色场景 - 生成主提示词
  final mainTags = <String>[];
  if (characterCount == 1) mainTags.add('solo');
  // 注意: 不使用已废弃的 'duo' 和 'trio'，而是使用具体的角色组合标签
  if (characterCount == 2) mainTags.add('2girls');  // 或根据性别组合: 2boys, 1girl, 1boy
  if (characterCount == 3) mainTags.add('multiple girls');  // 或根据性别组合

  // 添加背景等共享元素
  for (final category in mainCategories.values) {
    if (random.nextBool()) {
      mainTags.add(getWeightedChoice(category));
    }
  }

  // 4. 为每个角色生成提示词
  final characters = <CharacterPrompt>[];
  for (int i = 0; i < characterCount; i++) {
    final charTags = <String>[];

    // 人数标签
    charTags.add(i == 0 ? '1girl' : (random.nextBool() ? '1girl' : '1boy'));

    // 角色特征
    for (final category in characterCategories.values) {
      if (random.nextBool()) {
        charTags.add(getWeightedChoice(category));
      }
    }

    characters.add(CharacterPrompt(prompt: charTags.join(', ')));
  }

  return RandomPromptResult(
    mainPrompt: mainTags.join(', '),
    characterPrompts: characters,
  );
}
```

### 9. 注意事项与已知限制

#### 实现注意事项

1. **词库更新频率**：NovelAI 的标签词库硬编码在 JS 中，不会动态更新，需要定期检查是否有变化
2. **权重调整**：实际权重可能会根据用户反馈进行微调，具体数值以实际代码为准
3. **条件标签**：部分标签有条件依赖（如某些服装只在特定性别时出现），实现时需要考虑

#### 已知限制

- **最大角色数**：随机生成最多支持 3 个角色
- **位置固定**：随机生成的角色位置始终为中心 `{x: 0, y: 0}`，不会随机分布
- **负面提示词固定**：角色的默认 UC 始终为 `"lowres, aliasing, "`

#### 与 NovelAI 的差异

| 特性 | NovelAI 官方 | 本地实现建议 |
|-----|-------------|-------------|
| 词库来源 | 内置 JS 硬编码 | 可从 Danbooru API 动态获取 |
| 权重更新 | 随版本更新 | 可根据使用频率自动调整 |
| 角色位置 | 固定中心 | 可添加随机位置分布 |

---

## Danbooru 标签数据库详解

NovelAI 的标签来源于 **Danbooru**（动漫图片标签数据库）。

### 1. Danbooru 官方分类系统

Danbooru 使用 `category` 字段将标签分为 5 大类：

| category 值 | 类别名称 | 颜色 | 说明 | 示例 |
|------------|---------|------|------|------|
| **0** | General | 蓝色 | 通用标签（描述画面内容） | `blonde_hair`, `sitting`, `scenery` |
| **1** | Artist | 红色 | 画师/创作者名称 | `hatsune_miku_(vocaloid)` |
| **3** | Copyright | 紫色 | 作品/版权/系列 | `fate/grand_order`, `genshin_impact` |
| **4** | Character | 绿色 | 角色名称 | `hatsune_miku`, `rem_(re:zero)` |
| **5** | Meta | 黄色 | 元数据（图片属性） | `highres`, `absurdres`, `translated` |

> **注意**：category=2 未使用（历史遗留）

### 2. 如何判断标签类别

#### 方法一：直接查询 Danbooru API

```bash
# 查询单个标签的分类
GET https://danbooru.donmai.us/tags.json?search[name]=blonde_hair

# 返回示例
{
  "id": 87788,
  "name": "blonde_hair",
  "post_count": 1868014,
  "category": 0,           // 0 = General
  "created_at": "2013-02-28T11:45:11",
  "is_deprecated": false
}
```

#### 方法二：按类别批量获取

```bash
# 获取 General 类别中最热门的标签
GET https://danbooru.donmai.us/tags.json?search[category]=0&search[order]=count&limit=100

# 获取所有 Character 标签
GET https://danbooru.donmai.us/tags.json?search[category]=4&search[order]=count&limit=1000
```

#### 方法三：按命名模式过滤（用于 General 子分类）

```bash
# 获取所有发色标签
GET https://danbooru.donmai.us/tags.json?search[name_matches]=*_hair&search[category]=0&search[order]=count

# 获取所有瞳色标签
GET https://danbooru.donmai.us/tags.json?search[name_matches]=*_eyes&search[category]=0&search[order]=count

# 获取所有背景标签
GET https://danbooru.donmai.us/tags.json?search[name_matches]=*_background&search[category]=0&search[order]=count
```

### 3. General 类别的语义子分类

Danbooru 的 General (category=0) 类别非常庞大，NovelAI 对其进行了**语义子分类**。

判断方法主要通过**命名后缀模式**：

| 子类别 | 命名模式 | API 查询 | 热门示例（按使用量排序） |
|-------|---------|----------|-------------------------|
| **发色** | `*_hair` | `search[name_matches]=*_hair` | `long_hair` (5.3M), `black_hair` (1.9M), `blonde_hair` (1.9M) |
| **瞳色** | `*_eyes` | `search[name_matches]=*_eyes` | `blue_eyes` (2.1M), `red_eyes` (1.5M), `green_eyes` (1.0M) |
| **背景** | `*_background` | `search[name_matches]=*_background` | `simple_background` (2.3M), `white_background` (1.9M) |
| **服装** | `*_dress`, `*_shirt`, `*_skirt` | 多模式组合 | `shirt` (2.4M), `dress` (1.2M) |
| **表情** | `*_mouth`, 特定词 | 特定列表 | `smile` (3.5M), `blush` (3.5M), `open_mouth` (2.9M) |
| **姿势** | 无固定模式 | 需人工分类 | `looking_at_viewer` (4.1M), `sitting` (1.5M) |

### 4. 实际热门标签数据

#### General 类别 TOP 20（按使用量）

| 排名 | 标签 | 使用量 | 子类别 |
|-----|------|--------|--------|
| 1 | `1girl` | 7,213,798 | 人物数量 |
| 2 | `solo` | 6,024,857 | 人物数量 |
| 3 | `long_hair` | 5,295,081 | 发型 |
| 4 | `breasts` | 4,205,971 | 身体特征 |
| 5 | `looking_at_viewer` | 4,122,087 | 姿势/视线 |
| 6 | `smile` | 3,532,052 | 表情 |
| 7 | `blush` | 3,524,765 | 表情 |
| 8 | `open_mouth` | 2,928,648 | 表情 |
| 9 | `short_hair` | 2,714,190 | 发型 |
| 10 | `shirt` | 2,386,095 | 服装 |
| 11 | `simple_background` | 2,334,846 | 背景 |
| 12 | `blue_eyes` | 2,124,620 | 瞳色 |
| 13 | `long_sleeves` | 1,974,256 | 服装 |
| 14 | `white_background` | 1,933,043 | 背景 |
| 15 | `large_breasts` | 1,922,664 | 身体特征 |
| 16 | `black_hair` | 1,868,269 | 发色 |

#### Meta 类别热门标签

| 标签 | 使用量 | 说明 |
|------|--------|------|
| `highres` | 6,715,588 | 高分辨率 |
| `commentary_request` | 5,107,618 | 请求评论 |
| `absurdres` | 2,382,116 | 超高分辨率 |
| `commentary` | 2,139,681 | 有评论 |

### 5. 获取完整词库的方法

#### 方式一：Danbooru API 分页获取

```python
import requests

def fetch_all_tags(category=0, min_post_count=100):
    """获取指定类别的所有标签"""
    tags = []
    page = 1

    while True:
        url = f"https://danbooru.donmai.us/tags.json"
        params = {
            "search[category]": category,
            "search[order]": "count",
            "search[post_count]": f">={min_post_count}",
            "limit": 1000,
            "page": page
        }

        resp = requests.get(url, params=params)
        data = resp.json()

        if not data:
            break

        tags.extend(data)
        page += 1

    return tags

# 获取所有热门 General 标签（使用量 >= 1000）
general_tags = fetch_all_tags(category=0, min_post_count=1000)
```

#### 方式二：HuggingFace 数据集

推荐使用预处理好的数据集：

```python
from datasets import load_dataset

# 加载 Danbooru 标签数据集
dataset = load_dataset("qdlabs/danbooru-tags")

# 数据结构
# {
#   "id": 12345,
#   "name": "blonde_hair",
#   "category": 0,
#   "post_count": 1868014
# }
```

### 6. 构建自己的分类词库

#### Dart 实现示例

```dart
/// 标签分类枚举
enum TagCategory {
  general(0),
  artist(1),
  copyright(3),
  character(4),
  meta(5);

  final int value;
  const TagCategory(this.value);
}

/// 语义子分类枚举（仅用于 General）
enum GeneralSubCategory {
  hairColor,    // *_hair 且颜色相关
  hairStyle,    // *_hair 且非颜色
  eyeColor,     // *_eyes
  background,   // *_background
  clothing,     // *_dress, *_shirt, *_skirt
  expression,   // smile, blush, etc.
  pose,         // sitting, standing, etc.
  bodyFeature,  // breasts, abs, etc.
  other,
}

/// 判断 General 标签的子分类
GeneralSubCategory classifyGeneralTag(String tagName) {
  // 发色（颜色 + hair）
  final hairColorPattern = RegExp(
    r'^(blonde|blue|black|brown|red|white|pink|green|purple|silver|grey|orange|multicolored)_hair$'
  );
  if (hairColorPattern.hasMatch(tagName)) {
    return GeneralSubCategory.hairColor;
  }

  // 发型（其他 *_hair）
  if (tagName.endsWith('_hair')) {
    return GeneralSubCategory.hairStyle;
  }

  // 瞳色
  if (tagName.endsWith('_eyes')) {
    return GeneralSubCategory.eyeColor;
  }

  // 背景
  if (tagName.endsWith('_background')) {
    return GeneralSubCategory.background;
  }

  // 服装
  final clothingPatterns = ['_dress', '_shirt', '_skirt', '_pants', '_shoes'];
  if (clothingPatterns.any((p) => tagName.endsWith(p))) {
    return GeneralSubCategory.clothing;
  }

  // 表情
  final expressions = ['smile', 'blush', 'open_mouth', 'closed_eyes', 'frown', 'crying'];
  if (expressions.contains(tagName)) {
    return GeneralSubCategory.expression;
  }

  return GeneralSubCategory.other;
}

/// 从 Danbooru API 获取分类标签
Future<Map<GeneralSubCategory, List<WeightedTag>>> fetchCategorizedTags() async {
  final result = <GeneralSubCategory, List<WeightedTag>>{};

  // 获取发色
  final hairColors = await fetchTags('*_hair', minCount: 10000);
  result[GeneralSubCategory.hairColor] = hairColors
      .where((t) => classifyGeneralTag(t.name) == GeneralSubCategory.hairColor)
      .map((t) => WeightedTag(t.name.replaceAll('_', ' '), t.postCount ~/ 100000))
      .toList();

  // 获取瞳色
  final eyeColors = await fetchTags('*_eyes', minCount: 50000);
  result[GeneralSubCategory.eyeColor] = eyeColors
      .map((t) => WeightedTag(t.name.replaceAll('_', ' '), t.postCount ~/ 100000))
      .toList();

  // ... 其他类别

  return result;
}
```

---

## 实现建议

### 本地实现架构

本应用的词库数据来源分为两部分：

1. **NAI 固定词库**：从 NovelAI 官方 JS bundle 提取的固定标签数据，存储在本地 `assets/data/` 目录
2. **Pool 扩展词库**（可选）：通过 Danbooru Pools API 获取特定系列/主题的高频标签，由 `DanbooruPoolService` 负责同步

> **注意**：已移除基于正则匹配的热度标签同步功能，改用更精准的 Pool 同步机制。

### Dart 实现示例

```dart
import 'dart:math';

/// 带权重的标签
class WeightedTag {
  final String tag;
  final int weight;
  final List<String>? conditions;

  WeightedTag(this.tag, this.weight, [this.conditions]);
}

/// 加权随机选择
String getWeightedChoice(List<WeightedTag> tags, [List<String>? context]) {
  final random = Random();

  // 过滤符合条件的标签
  final filtered = tags.where((t) =>
    t.conditions == null ||
    t.conditions!.any((c) => context?.contains(c) ?? false)
  ).toList();

  // 计算总权重
  final totalWeight = filtered.fold<int>(0, (sum, t) => sum + t.weight);

  // 生成随机数并选择
  var target = random.nextInt(totalWeight) + 1;
  var cumulative = 0;

  for (final tag in filtered) {
    cumulative += tag.weight;
    if (target <= cumulative) return tag.tag;
  }

  return filtered.last.tag;
}

/// 生成随机提示词
String generateRandomPrompt(Map<String, List<WeightedTag>> categories) {
  final random = Random();
  final selected = <String>[];

  for (final category in categories.values) {
    // 每个类别有 50% 概率被选中
    if (random.nextBool()) {
      selected.add(getWeightedChoice(category));
    }
  }

  return selected.join(', ');
}
```

### 词库数据示例

```dart
final hairColors = [
  WeightedTag('blonde hair', 5),
  WeightedTag('blue hair', 4),
  WeightedTag('black hair', 6),
  WeightedTag('brown hair', 5),
  WeightedTag('red hair', 3),
  WeightedTag('white hair', 3),
  WeightedTag('pink hair', 2),
  WeightedTag('green hair', 2),
];

final eyeColors = [
  WeightedTag('blue eyes', 6),
  WeightedTag('amber eyes', 5),
  WeightedTag('red eyes', 3),
  WeightedTag('green eyes', 4),
];

final backgrounds = [
  WeightedTag('scenery', 100),
  WeightedTag('abstract background', 1),
  WeightedTag('blurred background', 5),
  WeightedTag('simple background', 10),
];
```

---

## 附录：常用 API 查询示例

```bash
# 获取标签详情
GET https://danbooru.donmai.us/tags.json?search[name]=blonde_hair

# 按类别获取（0=general, 1=artist, 3=copyright, 4=character, 5=meta）
GET https://danbooru.donmai.us/tags.json?search[category]=0&limit=100

# 按使用量排序
GET https://danbooru.donmai.us/tags.json?search[order]=count&limit=50

# 按命名模式搜索
GET https://danbooru.donmai.us/tags.json?search[name_matches]=*_hair

# 组合查询：获取热门发色标签
GET https://danbooru.donmai.us/tags.json?search[name_matches]=*_hair&search[category]=0&search[order]=count&limit=20

# 获取使用量大于 N 的标签
GET https://danbooru.donmai.us/tags.json?search[post_count]=>100000&search[category]=0
```

---

## 快速参考

### 关键参数速查表

| 参数 | 值 | 说明 |
|-----|-----|------|
| **角色数量权重** | `[[1,70], [2,20], [3,7], [0,5]]` | 1人70%、2人20%、3人7%、无人5% |
| **Furry性别权重** | `[["m",45], ["f",45], ["o",10]]` | 男45%、女45%、其他10% |
| **类别选中概率** | `~50%` | 每个标签类别约50%概率被选中 |
| **默认角色UC** | `"lowres, aliasing, "` | 角色提示词的默认负面提示词 |
| **默认角色位置** | `{x: 0, y: 0}` | 角色默认位于画面中心 |

### 模型与模板对应关系

| 模型 | 模板类型 | 特性 |
|-----|---------|------|
| V4 / V4.5 | `multiCharacterTemplate` | 支持多角色提示词，返回数组 |
| Furry V3 | `furryTemplate` | 使用 Furry 专用词库 |
| V3 及更早 | `legacyTemplate` | 传统单提示词，返回字符串 |

### 返回值格式对照

> 注意: "duo" 和 "trio" 是 Danbooru 已废弃的标签，实际使用具体的角色组合标签

```javascript
// 无角色场景 (no humans)
["no humans, scenery, building, ..."]

// 单角色场景
["solo, detailed background, ...", "1girl, blonde hair, blue eyes, ..."]

// 双角色场景 (使用具体组合，如 2girls 或 1girl, 1boy)
["2girls, outdoors, ...", "1girl, ...", "1girl, ..."]
// 或混合性别:
["1girl, 1boy, outdoors, ...", "1girl, ...", "1boy, ..."]

// 三角色场景 (使用 multiple girls 或具体组合)
["multiple girls, indoors, ...", "1girl, ...", "1girl, ...", "1girl, ..."]
// 或混合性别:
["2girls, 1boy, indoors, ...", "1girl, ...", "1girl, ...", "1boy, ..."]
```

### 核心函数签名

```javascript
// 加权随机选择
function getWeightedChoice(tags: [string, number, string[]?][], context?: string[]): string

// 随机生成主函数 (V4/V4.5)
function generateRandomPrompt(): string | string[]

// 结果分发
function handleRandomClick(): void {
  const result = generateRandomPrompt();
  setRandomPrompt(result[0]);
  setCharacterPrompts(result.slice(1).map(p => ({
    prompt: p,
    uc: "lowres, aliasing, ",
    center: {x: 0, y: 0},
    enabled: true
  })));
}
```

---

*文档生成日期: 2025-12-13*
*最后更新: 2025-12-13*
*分析来源: NovelAI 官网 JavaScript bundle 逆向分析 + Danbooru API 文档*
