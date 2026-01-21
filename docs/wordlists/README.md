# NAI Random Prompt Wordlists - 完整提取结果

> 从 NovelAI 官网 JS 代码中提取的随机提示词词库

## 📊 提取统计

| 版本 | 条目数 | 变量数 | 适用模型 |
|------|--------|--------|----------|
| Legacy (旧版) | 1,851 | 38 | NAI Diffusion Anime V1/V2/V3 |
| V4 | 2,326 | 38 | NAI Diffusion V4 / V4 Full / V4 Curated |
| Furry | 1,639 | 40 | NAI Diffusion Furry V3 |
| **总计** | **5,816** | **116** | |

## 📁 生成的文件

| 文件 | 说明 |
|------|------|
| `wordlists_legacy.csv` | 旧版词库 (1,851 条) |
| `wordlists_v4.csv` | V4版词库 (2,326 条) - 包含排除/必需/额外条件列 |
| `wordlists_furry.csv` | Furry版词库 (1,639 条) |
| `wordlists_all.csv` | 完整词库 (5,816 条) - 包含 Version 列 |
| `variables_summary.csv` | 变量统计汇总 (116 个变量) |
| `model_mapping.json` | 模型到词库文件的映射 |

## 🔄 模型映射

```json
{
  "naiDiffusionV4": "wordlists_v4.csv",
  "naiDiffusionV4Full": "wordlists_v4.csv",
  "naiDiffusionV4CuratedPreview": "wordlists_v4.csv",
  "naiDiffusionFurryV3": "wordlists_furry.csv",
  "naiDiffusionV3": "wordlists_legacy.csv",
  "naiDiffusionV2": "wordlists_legacy.csv",
  "naiDiffusionV1": "wordlists_legacy.csv",
  "default": "wordlists_legacy.csv"
}
```

## 🏷️ 变量分类详解

### Legacy 版 (旧版) - 38 个变量

| 变量 | 分类 | 条目数 | 中文说明 |
|------|------|--------|----------|
| eG | focus_type | 6 | 焦点类型 |
| eW | focus | 8 | 焦点 |
| eO | scenery | 5 | 风景 |
| eV | background_color | 47 | 背景颜色 |
| eU | background_type | 6 | 背景类型 |
| eZ | ears | 23 | 耳朵类型 |
| eH | expressions | 36 | 表情 |
| eJ | eyes_special | 11 | 特殊眼睛效果 |
| eX | eyes_style | 9 | 眼睛风格 |
| eQ | hair_length | 7 | 发长 |
| eK | hair_style | 34 | 发型 |
| eY | hair_details | 11 | 发型细节 |
| e0 | bangs | 24 | 刘海 |
| e1 | breasts | 7 | 胸部 |
| e2 | body_features | 38 | 身体特征 |
| e5 | body_details | 48 | 身体细节 |
| e6 | skin | 7 | 肤色 |
| e4 | legwear | 5 | 腿部穿着 |
| e3 | dresses | 37 | 连衣裙 |
| e8 | skirts | 8 | 裙子 |
| e7 | muscle | 11 | 肌肉 |
| e9 | tops | 64 | 上衣 |
| te | shoes | 39 | 鞋子 |
| tt | lower_clothing | 34 | 下装 |
| ta | uniforms | 54 | 制服 |
| ti | bodysuits | 11 | 紧身衣 |
| tr | swimsuit_types | 21 | 泳装类型 |
| ts | accessories | 346 | 配饰 |
| tn | upper_clothing | 108 | 上装 |
| to | headwear | 20 | 头饰 |
| tl | backgrounds | 122 | 背景 |
| tc | swimwear | 277 | 泳装 |
| td | bottoms | 192 | 下装 |
| tg | footwear | 120 | 鞋类 |
| th | eye_colors | 13 | 瞳色 |
| tm | hair_colors | 18 | 发色 |
| tp | hair_multicolor | 7 | 多色发 |
| tu | colors | 17 | 通用颜色 |

### V4 版 - 38 个变量

| 变量 | 分类 | 条目数 | 中文说明 |
|------|------|--------|----------|
| tk | camera_angle | 7 | 镜头角度 |
| tj | framing | 4 | 构图/取景 |
| tC | focus | 8 | 焦点 |
| tI | scenery | 5 | 风景 |
| tS | background | 49 | 背景 |
| tA | lighting | 37 | 光照 |
| tq | animal_features | 55 | 动物特征 (兽耳/兽尾) |
| tD | skin | 15 | 肤色 |
| tM | eyes_special | 19 | 特殊眼睛效果 |
| tz | eyes_style | 9 | 眼睛风格 |
| tP | hair_length | 8 | 发长 |
| tR | hair_style | 56 | 发型 |
| tT | hair_accessories | 13 | 发饰 |
| tN | bangs | 32 | 刘海 |
| tL | expressions | 7 | 表情 |
| tE | emotions | 55 | 情绪 |
| tB | body | 58 | 身体特征 |
| tF | poses | 16 | 姿势 |
| tG | actions | 7 | 动作 |
| tW | clothing | 42 | 服装 |
| tO | accessories | 11 | 配饰 |
| tV | background_detail | 10 | 背景细节 |
| tU | atmosphere | 74 | 氛围 |
| tZ | camera | 45 | 镜头效果 |
| tH | quality | 36 | 质量标签 |
| tJ | style | 15 | 风格 |
| tX | effects | 25 | 特效 |
| tQ | composition | 495 | 构图/场景 |
| tK | mood | 147 | 情绪/氛围 |
| tY | theme | 20 | 主题 |
| t0 | outfits_casual | 127 | 休闲装 |
| t1 | outfits_formal | 319 | 正装/制服 |
| t2 | outfits_fantasy | 262 | 幻想服装 |
| t5 | outfits_special | 179 | 特殊服装 |
| t6 | outfits_minimal | 13 | 简约服装 |
| t4 | outfits_swimwear | 19 | 泳装 |
| t3 | outfits_underwear | 9 | 内衣 |
| t8 | outfits_accessories | 18 | 服装配件 |

### Furry 版 - 40 个变量

| 变量 | 分类 | 条目数 | 中文说明 |
|------|------|--------|----------|
| ar | camera_view | 7 | 镜头视角 |
| as | focus | 5 | 焦点 |
| an | scenery | 4 | 风景 |
| ao | background | 26 | 背景 |
| al | lighting | 6 | 光照 |
| ag | quality | 30 | 质量标签 |
| ah | style | 79 | 风格 |
| am | mood | 18 | 情绪 |
| ap | theme | 28 | 主题 |
| au | poses | 7 | 姿势 |
| af | expressions | 16 | 表情 |
| ay | body | 14 | 身体特征 |
| a_ | body_type | 12 | 体型 |
| ab | markings | 16 | 标记/斑纹 |
| aw | features | 16 | 特征 |
| ax | extras | 5 | 额外特征 |
| av | clothing | 4 | 服装 |
| ak | species | 16 | 物种 |
| aj | species_features | 13 | 物种特征 |
| aC | colors | 5 | 颜色 |
| aI | patterns | 5 | 花纹 |
| aS | accessories | 68 | 配饰 |
| aA | actions | 32 | 动作 |
| aq | extras2 | 6 | 额外标签 |
| aD | special | 36 | 特殊标签 |
| aM | species_cat | 11 | 猫科 |
| az | species_canine | 61 | 犬科 |
| aP | species_other | 42 | 其他物种 |
| aR | species_mythical | 30 | 神话生物 |
| aT | species_aquatic | 49 | 水生生物 |
| aN | species_bird | 11 | 鸟类 |
| aL | species_reptile | 18 | 爬行动物 |
| aE | clothing_full | 244 | 完整服装 |
| aB | clothing_top | 105 | 上装 |
| aF | clothing_bottom | 20 | 下装 |
| aG | clothing_accessories | 108 | 服装配饰 |
| aW | clothing_special | 212 | 特殊服装 |
| aO | clothing_fantasy | 134 | 幻想服装 |
| aV | clothing_casual | 103 | 休闲装 |
| aU | clothing_formal | 17 | 正装 |

## 🔧 CSV 格式说明

### Legacy/Furry 版格式
```csv
Variable,Category,Tag,Weight
eH,expressions,smile,5
```

### V4 版格式 (扩展)
```csv
Variable,Category,Tag,Weight,Exclude,Require,Extra
tC,focus,breast focus,4,[],["female"],[]
```

| 字段 | 说明 | 示例 |
|------|------|------|
| Exclude | 当这些标签存在时，此条目不会被选中 | `["portrait"]` |
| Require | 必须存在这些标签才会选中此条目 | `["female"]` |
| Extra | 附加条件 | `["front"]` |

## 📝 提取脚本

```bash
# 使用 v3 脚本 (推荐，按函数引用分类)
python scripts/extract_nai_wordlists_v3.py <JS文件> [输出目录]

# 示例
python scripts/extract_nai_wordlists_v3.py "NAI COPY/.../6043-xxx.js.下载" docs/wordlists
```

## 🔗 相关文件

- JS 源文件: `NAI COPY/Image Generation - NovelAI_files/6043-bb32818315113a80.js.下载`
- 提取脚本: `scripts/extract_nai_wordlists_v3.py`
