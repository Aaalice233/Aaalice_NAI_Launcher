# NovelAI 随机提示词规则 (Random Prompt Rules)

> 从 NAI 官网 JS 代码中提取的随机提示词生成规则

## 概述

NAI 有三个随机提示词生成函数，根据不同模型选择：

| 模型类型 | 函数 | 特点 |
|---------|------|------|
| V4 (支持 characterPrompts) | `at()` | 返回数组，支持多角色 |
| Furry V3 | `a$()` | 返回数组，Furry 专用词库 |
| 其他模型 (V3等) | `tb()` | 返回字符串 |

```javascript
// 选择逻辑
const randomFunc = (0,eA.PE)(d).characterPrompts ? at : d === eA.oM.naiDiffusionFurryV3 ? a$ : tb;
```

---

## 核心工具函数

### 随机整数生成

```javascript
function tf(max, min = 0) {
  return Math.floor(Math.random() * (max - min)) + min;
}
```

### 加权随机选择

```javascript
function ty(wordlist, existingTags) {
  // 过滤已有条件的词条
  let filtered = wordlist.filter(item => {
    if (!item[2]) return true;  // 无条件，通过
    return item[2].some(cond => existingTags.includes(cond));
  });
  
  // 计算总权重
  let totalWeight = 0;
  for (let item of filtered) {
    totalWeight += item[1];  // item[1] 是权重
  }
  
  // 随机选择
  let random = tf(totalWeight, 1);
  let cumulative = 0;
  for (let item of filtered) {
    cumulative += item[1];
    if (random <= cumulative) {
      return item[0];  // item[0] 是标签文本
    }
  }
}
```

---

## V3 模型随机规则 (`tb` 函数)

### 角色数量决定

```javascript
// 角色数量概率
let characterCount = ty([
  [1, 70],   // 1个角色: 70%
  [2, 20],   // 2个角色: 20%
  [3, 7],    // 3个角色: 7%
  [0, 5]     // 无人物: 5%
], []);
```

### 无人物场景 (0个角色)

```javascript
if (characterCount === 0) {
  result.push("no humans");
  if (Math.random() < 0.3) result.push(ty(eZ, result));  // 艺术风格 30%
  result.push(ty(eO, result));  // 风景类型 100%
  
  // 添加 2-5 个场景元素
  let sceneCount = ty([[2,15], [3,50], [4,15], [5,5]], result);
  for (let i = 0; i < sceneCount; i++) {
    result.push(ty(tl, result));  // 场景
  }
  
  // 添加 0-5 个物品
  let itemCount = ty([[0,15], [1,10], [2,20], [3,20], [4,20], [5,15]], result);
  for (let i = 0; i < itemCount; i++) {
    result.push(ty(tc, result));  // 物品
  }
}
```

### 有人物场景

```javascript
// 1. 艺术风格 (30%)
if (Math.random() < 0.3) result.push(ty(eZ, result));

// 2. 决定性别分布
let females = 0, males = 0, others = 0;
for (let i = 0; i < characterCount; i++) {
  switch (ty([["m", 30], ["f", 50]], result)) {
    case "m": males++; break;
    case "f": females++; break;
    case "o": others++; break;
  }
}

// 3. 添加人数标签
// 1girl, 2girls, 3girls, 1boy, 2boys, 3boys, 1other, 2others, 3others

// 4. 背景 (80%)
if (Math.random() < 0.8) {
  let bg = ty(eV, result);
  result.push(bg);
  if (bg === "scenery" && Math.random() < 0.5) {
    let count = tf(3, 1);
    for (let i = 0; i < count; i++) {
      result.push(ty(tl, result));
    }
  }
}

// 5. 视角 (30%)
if (Math.random() < 0.3) result.push(ty(eG, result));

// 6. 构图 (70%)
let composition;
if (Math.random() < 0.7) {
  composition = ty(eU, result);
  if (composition) result.push(composition);
}

// 7. 为每个角色生成特征
for (let i = 0; i < females; i++) {
  result.push(...t_("f", composition, hasCharacterPrompts, characterCount));
}
for (let i = 0; i < males; i++) {
  result.push(...t_("m", composition, hasCharacterPrompts, characterCount));
}
for (let i = 0; i < others; i++) {
  result.push(...t_("o", composition, hasCharacterPrompts, characterCount));
}

// 8. 物品 (20%)
if (Math.random() < 0.2) {
  let count = tf(4);
  if (characterCount === 2) count = tf(3);
  for (let i = 0; i < count; i++) {
    result.push(ty(tc, result));
  }
}

// 9. 视觉效果 (25%)
if (Math.random() < 0.25) {
  let count = tf(3, 1);
  for (let i = 0; i < count; i++) {
    result.push(ty(tg, result));
  }
}

// 10. 年份 (20%)
if (Math.random() < 0.2) result.push(ty(to, result));

// 11. 焦点 (10%)
if (Math.random() < 0.1) result.push(ty(eW, result));
```

---

## 角色特征生成 (`t_` 函数)

为单个角色生成特征：

```javascript
function t_(gender, composition, hasCharacterPrompts, totalCharacters) {
  let result = [];
  let isAnimalPerson = false;  // 是否有动物特征
  
  // 1. 兽耳/种族 (10%)
  if (Math.random() < 0.1) {
    result.push(ty(eH, result));
  }
  isAnimalPerson = result.some(tag => tw.has(tag));  // tw = ["mermaid", "centaur", "lamia"]
  
  // 2. 肤色 (40%)
  if (Math.random() < 0.4) result.push(ty(e$, result));
  
  // 3. 眼睛颜色 (80%)
  if (Math.random() < 0.8) result.push(ty(th, result));
  
  // 4. 特殊眼睛 (10%)
  if (Math.random() < 0.1) result.push(ty(eJ, result));
  
  // 5. 眼睛类型 (20%)
  if (Math.random() < 0.2) result.push(ty(eX, result));
  
  // 6. 发长 (80%)
  if (Math.random() < 0.8) result.push(ty(eQ, result));
  
  // 7. 发型 (50%)
  if (Math.random() < 0.5) result.push(ty(eK, result));
  
  // 8. 头发颜色 (70%)
  if (Math.random() < 0.7) result.push(ty(tm, result));
  
  // 9. 多彩头发 (10%) - 会额外加一个发色
  if (Math.random() < 0.1) {
    result.push(ty(tp, result));
    result.push(ty(tm, result));
  }
  
  // 10. 发型细节 (10%)
  if (Math.random() < 0.1) result.push(ty(eY, result));
  
  // 11. 刘海 (20%)
  if (Math.random() < 0.2) result.push(ty(e0, result));
  
  // 12. 胸部 (仅女性, 50%)
  if (gender.startsWith("f") && Math.random() < 0.5) {
    result.push(ty(e1, result));
  }
  
  // 13. 身体特征数量 (根据角色总数变化)
  let bodyCount;
  if (totalCharacters === 1) {
    bodyCount = ty([[0,10], [1,30], [2,15], [3,5]], result);
  } else if (totalCharacters === 2) {
    bodyCount = ty([[0,20], [1,40], [2,10]], result);
  } else {
    bodyCount = ty([[0,30], [1,30]], result);
  }
  for (let i = 0; i < bodyCount; i++) {
    result.push(ty(e2, result));
  }
  
  // 14. 帽子 (20% 帽子, 20% 帽子装饰) 或 头发装饰 (30%)
  if (Math.random() < 0.2) {
    result.push(ty(e5, result));  // 帽子
    if (Math.random() < 0.2) {
      result.push(ty(e4, result));  // 帽子装饰
    }
  } else if (Math.random() < 0.3) {
    result.push(ty(e6, result));  // 头发装饰
  }
  
  // 15. 服装类型决定
  switch (ty([["uniform", 10], ["swimsuit", 5], ["bodysuit", 5], ["normal clothes", 40]], result)) {
    case "uniform":
      result.push(ty(ta, result));  // 制服
      break;
    case "swimsuit":
      result.push(ty(tr, result));  // 泳装
      break;
    case "bodysuit":
      result.push(ty(ti, result));  // 紧身衣
      break;
    case "normal clothes":
      // 女性: 50% 穿袜子
      if (gender.startsWith("f") && Math.random() < 0.5) {
        result.push(ty(e8, result));  // 袜子
        if (Math.random() < 0.2) {
          result.push(ty(e7, result));  // 袜子装饰
        }
      }
      
      // 女性: 20% 连衣裙
      if (gender.startsWith("f") && Math.random() < 0.2) {
        let addColor = Math.random() < 0.5;
        let color = ty(tu, result);
        let dress = ty(e3, result);
        result.push(addColor ? `${color} ${dress}` : dress);
      } else {
        // 上衣 (85%)
        if (Math.random() < 0.85) {
          let addColor = Math.random() < 0.5;
          let color = ty(tu, result);
          let top = ty(e9, result);
          result.push(addColor ? `${color} ${top}` : top);
        }
        
        // 非动物下半身 (不是美人鱼等)
        if (!isAnimalPerson) {
          // 裤子/裙子 (85%, 非 portrait)
          if (Math.random() < 0.85 && composition !== "portrait") {
            let addColor = Math.random() < 0.5;
            let color = ty(tu, result);
            let bottom = ty(te, result);
            result.push(addColor ? `${color} ${bottom}` : bottom);
          }
          
          // 鞋子 (60%, full body 或无构图)
          if (Math.random() < 0.6 && (composition === "full body" || composition === undefined)) {
            let addColor = Math.random() < 0.5;
            let color = ty(tu, result);
            let footwear = ty(tt, result);
            result.push(addColor ? `${color} ${footwear}` : footwear);
          }
        }
      }
      break;
  }
  
  // 16. 表情 (60%)
  if (Math.random() < 0.6) result.push(ty(tn, result));
  
  // 17. 动作/姿势 (概率根据条件变化)
  if (Math.random() < (hasCharacterPrompts && totalCharacters === 1 ? 1 : 0.4)) {
    result.push(ty(td, result));
  }
  
  // 18. 处理睡觉相关标签 (移除眼睛颜色)
  if (result.some(tag => tag.includes("sleeping") || tag.includes("zzz") || tag.includes("closed eyes"))) {
    result = result.filter(tag => !th.some(eye => tag === eye[0]));
  }
  
  // 19. 配饰数量 (根据角色总数变化)
  let accessoryCount;
  if (totalCharacters === 1) {
    accessoryCount = ty([[0,10], [1,30], [2,15], [3,5]], result);
  } else if (totalCharacters === 2) {
    accessoryCount = ty([[0,20], [1,40], [2,10]], result);
  } else {
    accessoryCount = ty([[0,30], [1,30]], result);
  }
  for (let i = 0; i < accessoryCount; i++) {
    result.push(ty(ts, result));  // 配饰
  }
  
  // 20. 动物人过滤腿部穿着
  if (isAnimalPerson) {
    result = result.filter(tag => !tag.includes("legwear"));
  }
  
  return result;
}
```

---

## V4 模型多角色规则 (`at` 函数)

V4 模型返回数组：
- `result[0]` = 主提示词 (场景、背景、构图等)
- `result[1...n]` = 角色提示词 (每个角色单独的特征)

### 返回格式

```javascript
function at() {
  let mainPrompt = [];      // 主提示词
  let characterPrompts = []; // 角色提示词数组
  
  // ... 生成逻辑 ...
  
  // 返回: [主提示词, 角色1, 角色2, ...]
  return [mainPrompt.join(", "), ...characterPrompts.map(c => c.join(", "))];
}
```

### 主提示词包含

- 人数标签 (1girl, 2girls, 1boy, etc.)
- 艺术风格 (50%)
- 背景 (80%)
- 视角 (30%)
- 构图 (70%)
- 物品 (20%)
- 视觉效果 (25%)
- 年份 (20%)
- 焦点 (10%)

### 角色提示词包含

每个角色以 "girl" / "boy" / "other" 开头，然后是：
- 种族/耳朵 (10%)
- 肤色 (40%)
- 特殊眼睛 (5%)
- 眼睛类型 (20%)
- 眼睛颜色 (80%)
- 发长 (80%)
- 发型 (70%)
- 头发颜色 (70%)
- 多彩头发 (10%)
- 刘海 (30%)
- 身体特征 (40%)
- 胸部 (女性, 80%)
- 服装 (帽子/头饰/连衣裙/上衣/下装/鞋子)
- 表情 (60%)
- 动作 (40%)
- 配饰

---

## 前端使用逻辑

```javascript
function handleRandomPrompt(numCharacters) {
  // 获取随机函数
  const randomFunc = model.characterPrompts ? at : model === furryV3 ? a$ : tb;
  
  // 生成随机提示词
  const result = randomFunc(numCharacters);
  
  if (typeof result === "string") {
    // V3 模型: 直接设置提示词
    setRandomPrompt(result);
    setCharacterPrompts([]);
  } else {
    // V4 模型: 分离主提示词和角色提示词
    setRandomPrompt(result[0]);
    
    const characters = [];
    for (let i = 1; i < result.length; i++) {
      characters.push({
        prompt: result[i],
        uc: "lowres, aliasing, ",  // 默认负面提示词
        center: { x: 0, y: 0 },
        enabled: true
      });
    }
    setCharacterPrompts(characters);
  }
}
```

---

## 特殊规则

### 2% 强调概率

生成完成后，每个标签有 2% 概率被添加强调括号：

```javascript
result = [...new Set(result.join(", ").split(", "))];  // 去重
for (let i = 0; i < result.length; i++) {
  if (Math.random() < 0.02) {
    result[i] = `{${result[i]}}`;  // 添加强调
  }
}
return result.join(", ");
```

### 圣诞节特殊词库

12月1日-31日期间，有额外的圣诞节词库可能被使用：

```javascript
const tx = [
  ["christmas", 6],
  ["christmas tree", 6],
  ["santa hat", 6],
  ["santa costume", 6],
  ["merry christmas", 6],
  ["gift", 6],
  ["christmas ornaments", 6],
  ["gift box", 6],
  ["christmas lights", 6],
  ["holly", 6],
  ["reindeer antlers", 6],
  ["candy cane", 6],
  ["gingerbread", 6],
  ["fireplace", 6],
  ["chimney", 6],
  ["pine tree", 6],
  ["snowman", 6],
  ["snow", 6],
  ["winter", 6],
  ["winter clothes", 6],
  ["snowflake", 6],
  ["snowing", 6],
  ["mittens", 6],
  ["snowscape", 6],
  ["earmuffs", 6],
  ["star (symbol)", 6],
  ["snowflake background", 6],
  ["mistletoe", 6],
  ["wreath", 6],
  ["christmas wreath", 6]
];

function isChristmasSeason() {
  const date = new Date();
  const month = date.getMonth();  // 0-11
  const day = date.getDate();
  return month === 11 && day >= 1 && day <= 31;  // 12月
}
```

### 不穿腿部服装的种族

以下种族会过滤掉腿部穿着 (legwear)：

```javascript
const tw = new Set(["mermaid", "centaur", "lamia"]);
```

---

## 概率总结表

| 特征 | 概率 | 备注 |
|-----|------|------|
| 艺术风格 | 30% | |
| 背景 | 80% | |
| 视角 | 30% | |
| 构图 | 70% | |
| 物品 | 20% | 0-4个 |
| 视觉效果 | 25% | 1-3个 |
| 年份 | 20% | |
| 焦点 | 10% | |
| **角色特征** | | |
| 兽耳/种族 | 10% | |
| 肤色 | 40% | |
| 眼睛颜色 | 80% | |
| 特殊眼睛 | 10% | |
| 眼睛类型 | 20% | |
| 发长 | 80% | |
| 发型 | 50% | |
| 头发颜色 | 70% | |
| 多彩头发 | 10% | 额外加一个发色 |
| 发型细节 | 10% | |
| 刘海 | 20% | |
| 胸部 (女) | 50% | |
| 帽子 | 20% | |
| 表情 | 60% | |
| 动作 | 40% | |

---

*文档生成于 NAI 官网 JS 代码分析*
*源文件: 6043-bb32818315113a80.js*
