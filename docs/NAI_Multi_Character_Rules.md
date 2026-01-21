# NovelAI 多角色功能规则 (Multi-Character Rules)

> 从 NAI 官网 JS 代码中提取的 V4 模型多角色功能实现

## 概述

V4 模型（支持 `characterPrompts`）使用 `at()` 函数生成随机提示词，支持最多 6 个角色的独立提示词生成。

---

## 数据结构

### 角色提示词对象

```typescript
interface CharacterPrompt {
  prompt: string;        // 角色提示词
  uc: string;           // 负面提示词 (Undesired Content)
  center: {             // 角色在画面中的位置
    x: number;          // -1 到 1，0 为中心
    y: number;          // -1 到 1，0 为中心
  };
  enabled: boolean;     // 是否启用
}
```

### 随机生成返回格式

```javascript
// at() 函数返回数组
[
  "主提示词 (场景、背景、构图)",
  "girl, 角色1特征...",
  "boy, 角色2特征...",
  // ... 更多角色
]
```

---

## 多角色生成逻辑

### 角色数量决定

```javascript
// 角色数量概率分布
let characterCount = ty([
  [1, 70],   // 1个角色: 70%
  [2, 20],   // 2个角色: 20%
  [3, 7],    // 3个角色: 7%
  [0, 5]     // 无人物: 5%
], []);
```

### 性别分配

```javascript
// V4 模型性别概率
// 女性 60%, 男性 30%, 其他 0% (V4不生成other)
let females = 0, males = 0, others = 0;
for (let i = 0; i < characterCount; i++) {
  switch (ty([["m", 30], ["f", 60], ["o", 0]], [])) {
    case "m": males++; break;
    case "f": females++; break;
    case "o": others++; break;
  }
}
```

### 主提示词生成

主提示词包含所有角色共享的元素：

```javascript
let mainPrompt = [];

// 1. 人数标签
switch (females) {
  case 1: mainPrompt.unshift("1girl"); break;
  case 2: mainPrompt.unshift("2girls"); break;
  case 3: mainPrompt.unshift("3girls"); break;
}
switch (males) {
  case 1: mainPrompt.unshift("1boy"); break;
  case 2: mainPrompt.unshift("2boys"); break;
  case 3: mainPrompt.unshift("3boys"); break;
}

// 2. 艺术风格 (50%)
if (Math.random() < 0.5) mainPrompt.push(ty(tA, usedTags));

// 3. 背景 (80%)
if (Math.random() < 0.8) {
  let bg = ty(tS, usedTags);
  mainPrompt.push(bg);
  if (bg === "scenery" && Math.random() < 0.5) {
    // 添加 1-3 个场景元素
    let count = tf(3, 1);
    for (let i = 0; i < count; i++) {
      mainPrompt.push(ty(t0, usedTags));
    }
  }
}

// 4. 视角 (30%)
if (Math.random() < 0.3) mainPrompt.push(ty(tk, usedTags));

// 5. 构图 (70%)
let composition;
if (Math.random() < 0.7) {
  composition = ty(tj, usedTags);
  if (composition) mainPrompt.push(composition);
}

// 6. 物品 (20%)
if (Math.random() < 0.2) {
  let count = tf(4);
  if (characterCount === 2) count = tf(3);
  for (let i = 0; i < count; i++) {
    mainPrompt.push(ty(t1, usedTags));
  }
}

// 7. 视觉效果 (25%)
if (Math.random() < 0.25) {
  let count = tf(3, 1);
  for (let i = 0; i < count; i++) {
    mainPrompt.push(ty(t5, usedTags));
  }
}

// 8. 年份 (20%)
if (Math.random() < 0.2) mainPrompt.push(ty(tY, usedTags));

// 9. 焦点 (10%)
if (Math.random() < 0.1) mainPrompt.push(ty(tC, usedTags));
```

### 角色提示词生成

每个角色使用 `ae()` 函数独立生成：

```javascript
let characterPrompts = [];

// 为每个女性角色生成
for (let i = 0; i < females; i++) {
  let charTags = ["girl", ...ae(usedTags, "f", composition, characterCount)];
  characterPrompts.push(charTags);
}

// 为每个男性角色生成
for (let i = 0; i < males; i++) {
  let charTags = ["boy", ...ae(usedTags, "m", composition, characterCount)];
  characterPrompts.push(charTags);
}

// 为每个其他角色生成
for (let i = 0; i < others; i++) {
  let charTags = ["other", ...ae(usedTags, "o", composition, characterCount)];
  characterPrompts.push(charTags);
}
```

---

## 角色特征生成 (`ae` 函数)

### V4 专用角色生成函数

```javascript
function ae(usedTags, gender, composition, totalCharacters) {
  let result = [];
  let tags = new Set(usedTags);
  
  // 1. 兽耳/种族 (10%)
  if (Math.random() < 0.1) result.push(t9(tq, tags));
  
  // 2. 肤色 (40%)
  if (Math.random() < 0.4) result.push(t9(tD, tags));
  
  // 3. 特殊眼睛 (5%)
  if (Math.random() < 0.05) result.push(t9(tM, tags));
  
  // 4. 眼睛 (如果没有 "no eyes")
  if (!tags.has("no eyes")) {
    // 眼睛类型 (20%)
    if (Math.random() < 0.2) result.push(t9(tz, tags));
    // 眼睛颜色 (80%, 如果没有 "nocoloreyes")
    if (Math.random() < 0.8 && !tags.has("nocoloreyes")) {
      result.push(t9(t6, tags));
    }
  }
  
  // 5. 发长 (80%)
  if (Math.random() < 0.8) result.push(t9(tP, tags));
  
  // 6. 发型 (70%)
  if (Math.random() < 0.7) result.push(t9(tR, tags));
  
  // 7. 头发颜色 (70%)
  if (Math.random() < 0.7) result.push(t9(t4, tags));
  
  // 8. 多彩头发 (10%)
  if (Math.random() < 0.1) {
    result.push(t9(t3, tags));
    result.push(t9(t4, tags));  // 额外发色
  }
  
  // 9. 刘海 (30%)
  if (Math.random() < 0.3) result.push(t9(tT, tags));
  
  // 10. 身体特征 (40%)
  if (Math.random() < 0.4) result.push(t9(tN, tags));
  
  // 11. 胸部 (女性, 80%)
  if (gender.startsWith("f") && Math.random() < 0.8) {
    result.push(t9(tL, tags));
  }
  
  // 12. 身体细节数量 (根据角色总数)
  let bodyCount;
  if (totalCharacters === 1) {
    bodyCount = t9([[0,10], [1,30], [2,15], [3,5]], tags);
  } else if (totalCharacters === 2) {
    bodyCount = t9([[0,20], [1,40], [2,10]], tags);
  } else {
    bodyCount = t9([[0,30], [1,30]], tags);
  }
  for (let i = 0; i < bodyCount; i++) {
    result.push(t9(tE, tags));
  }
  
  // 13. 帽子/头饰
  if (Math.random() < 0.2) {
    result.push(t9(tB, tags));  // 帽子
    if (Math.random() < 0.2) {
      result.push(t9(tG, tags));  // 帽子装饰
    }
  } else if (Math.random() < 0.3) {
    result.push(t9(tF, tags));  // 头发装饰
  }
  
  // 14. 服装类型
  switch (t9([["uniform", 25], ["swimsuit", 5], ["bodysuit", 5], ["normal clothes", 40]], tags)) {
    case "uniform":
      result.push(t9(t$, tags));
      break;
    case "swimsuit":
      result.push(t9(tX, tags));
      break;
    case "bodysuit":
      result.push(t9(tJ, tags));
      break;
    case "normal clothes":
      // 女性袜子 (50%)
      if (gender.startsWith("f") && Math.random() < 0.5) {
        result.push(t9(tO, tags));
        if (Math.random() < 0.2) {
          result.push(t9(tV, tags));
        }
      }
      
      // 女性连衣裙 (20%)
      if (gender.startsWith("f") && Math.random() < 0.2) {
        let addColor = Math.random() < 0.5;
        let color = t9(t8, tags);
        let dress = t9(tW, tags);
        if (dress) result.push(addColor ? `${color} ${dress}` : dress);
      } else {
        // 上衣 (85%)
        if (Math.random() < 0.85) {
          let addColor = Math.random() < 0.5;
          let color = t9(t8, tags);
          let top = t9(tU, tags);
          if (top) result.push(addColor ? `${color} ${top}` : top);
        }
        
        // 下装 (如果有腿部可见)
        if (tags.has("legs")) {
          if (Math.random() < 0.85) {
            let addColor = Math.random() < 0.5;
            let color = t9(t8, tags);
            let bottom = t9(tZ, tags);
            if (bottom) result.push(addColor ? `${color} ${bottom}` : bottom);
          }
          
          // 鞋子 (如果有脚部可见)
          if (tags.has("feet") && Math.random() < 0.6) {
            let addColor = Math.random() < 0.5;
            let color = t9(t8, tags);
            let footwear = t9(tH, tags);
            if (footwear) result.push(addColor ? `${color} ${footwear}` : footwear);
          }
        }
      }
      break;
  }
  
  // 15. 表情 (60%)
  if (Math.random() < 0.6) result.push(t9(tK, tags));
  
  // 16. 动作 (40%)
  if (Math.random() < 0.4) result.push(t9([...t2], tags));
  
  // 17. 配饰数量
  let accessoryCount;
  if (totalCharacters === 1) {
    accessoryCount = t9([[0,10], [1,30], [2,15], [3,5]], tags);
  } else if (totalCharacters === 2) {
    accessoryCount = t9([[0,20], [1,40], [2,10]], tags);
  } else {
    accessoryCount = t9([[0,30], [1,30]], tags);
  }
  for (let i = 0; i < accessoryCount; i++) {
    result.push(t9([...tQ], tags));
  }
  
  return result.filter(tag => tag !== "");
}
```

---

## 前端集成

### 随机提示词按钮处理

```javascript
function handleRandomPromptClick(numCharacters) {
  // 选择随机函数
  const randomFunc = model.characterPrompts ? at : 
                     model === furryV3 ? a$ : tb;
  
  // 生成随机提示词
  const result = randomFunc(numCharacters);
  
  if (typeof result === "string") {
    // V3: 单个字符串
    setRandomPrompt(result);
    setCharacterPrompts([]);
  } else {
    // V4: 数组
    setRandomPrompt(result[0]);  // 主提示词
    
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

### 角色位置控制

V4 支持每个角色的位置控制：

```javascript
// center 坐标系统
// x: -1 (左) 到 1 (右), 0 = 中心
// y: -1 (上) 到 1 (下), 0 = 中心

// 示例：两个角色左右分布
characters[0].center = { x: -0.3, y: 0 };  // 左侧
characters[1].center = { x: 0.3, y: 0 };   // 右侧
```

---

## V4 vs V3 对比

| 特性 | V3 模型 | V4 模型 |
|-----|---------|---------|
| 返回类型 | 字符串 | 数组 |
| 多角色支持 | ❌ 所有特征混在一起 | ✅ 每个角色独立 |
| 角色位置控制 | ❌ | ✅ |
| 角色独立负面提示词 | ❌ | ✅ |
| 最大角色数 | 3 | 6 |
| 角色特征分离 | ❌ | ✅ |

---

## 构图与可见性规则

V4 使用条件数组来控制哪些特征在特定构图下可见：

```javascript
// 词库格式: [标签, 权重, 需要的标签, 必须有的标签, 排除的标签]
const t2 = [
  ["sitting", 12, [], ["body"], []],       // 需要 body 可见
  ["standing", 12, [], ["body"], []],      // 需要 body 可见
  ["hand on own ass", 12, [], ["body"], ["front"]],  // 需要 body，排除 front
  ["tiptoes", 12, [], ["feet"], []],       // 需要 feet 可见
  // ...
];

// 构图定义的可见部分
const tj = [
  ["headshot portrait", 2, [], [], []],           // 只有头
  ["bust portrait", 2, [], [], []],               // 胸以上
  ["half-length portrait", 8, [], [], []],        // 半身
  ["three-quarter length portrait", 8, [], [], []], // 3/4身
  ["full-length portrait", 4, [], [], []],        // 全身
  ["close-up", 1, [], [], []]
];

// 可见性集合
const ac = new Set(["half-length portrait", "three-quarter length portrait", "full-length portrait"]);  // 有腿
const ad = new Set(["full-length portrait"]);  // 有脚
```

---

## 使用示例

### 生成 2 个角色的随机提示词

```javascript
const result = at();
// 可能的输出:
// [
//   "2girls, detailed background, from above, half-length portrait",
//   "girl, blonde hair, blue eyes, medium hair, smile, school uniform",
//   "girl, black hair, red eyes, long hair, ponytail, maid"
// ]
```

### 前端状态更新

```javascript
// 设置主提示词
prompt = "2girls, detailed background, from above, half-length portrait";

// 设置角色提示词
characterPrompts = [
  {
    prompt: "girl, blonde hair, blue eyes, medium hair, smile, school uniform",
    uc: "lowres, aliasing, ",
    center: { x: -0.3, y: 0 },
    enabled: true
  },
  {
    prompt: "girl, black hair, red eyes, long hair, ponytail, maid",
    uc: "lowres, aliasing, ",
    center: { x: 0.3, y: 0 },
    enabled: true
  }
];
```

---

*文档生成于 NAI 官网 JS 代码分析*
*源文件: 6043-bb32818315113a80.js*
