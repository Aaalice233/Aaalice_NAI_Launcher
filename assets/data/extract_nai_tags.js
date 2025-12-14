/**
 * NAI 官方标签提取脚本
 *
 * 从 NovelAI 网页源码 JS 文件中提取所有标签定义
 * 并更新 assets/data/nai_official_tags.json
 *
 * 使用方法:
 *   cd assets/data
 *   node extract_nai_tags.js
 */

const fs = require('fs');
const path = require('path');

// 配置（相对于 assets/data 目录）
const SOURCE_FILE = path.join(__dirname, '../../nai_web_copy/Image Generation - NovelAI_files/9182-e447568fbb92a99a.js.下载');
const OUTPUT_FILE = path.join(__dirname, 'nai_official_tags.json');

// NAI 变量名到分类的映射
const VAR_MAPPING = {
  // 表情与姿势
  aE: { category: 'expression', name: '表情' },
  aO: { category: 'pose', name: '姿势' },

  // 场景与背景
  eV: { category: 'background', name: '背景' },
  tl: { category: 'scene', name: '场景' },
  eH: { category: 'style', name: '风格' },

  // 发型相关
  tm: { category: 'hairColor', name: '发色' },
  tp: { category: 'multicolorHair', name: '多色发' },
  eQ: { category: 'hairLength', name: '发长' },
  eK: { category: 'hairStyle', name: '发型' },
  e0: { category: 'bangs', name: '刘海' },
  eY: { category: 'hairUpdo', name: '扎发' },

  // 眼睛相关
  th: { category: 'eyeColor', name: '瞳色' },
  eX: { category: 'eyeStyle', name: '眼型' },
  eJ: { category: 'eyeVariant', name: '眼睛变体' },

  // 服装 - 上装
  e7: { category: 'tops', name: '上装' },
  // 服装 - 连衣裙
  e3: { category: 'dresses', name: '连衣裙' },
  // 服装 - 下装
  aP: { category: 'bottoms', name: '下装' },
  // 服装 - 职业/套装
  aR: { category: 'outfits', name: '职业套装' },
  // 服装 - 鞋类
  aT: { category: 'footwear', name: '鞋类' },
  // 服装 - 泳装
  tr: { category: 'swimwear', name: '泳装' },
  // 服装 - 裙装
  aq: { category: 'skirts', name: '裙装' },
  // 服装套装（复杂结构）
  tW: { category: 'clothingSets', name: '服装套装' },

  // 配饰
  e5: { category: 'hats', name: '帽子' },
  ts: { category: 'accessories', name: '配饰' },

  // 身体特征
  aI: { category: 'bodyFeature', name: '身体特征' },
  eZ: { category: 'speciesFeature', name: '种族特征' },
  e1: { category: 'chest', name: '胸部' },

  // 物品与特效
  tc: { category: 'items', name: '物品' },
  tg: { category: 'effects', name: '特效' },
  aV: { category: 'effects2', name: '特效2' },

  // 其他
  to: { category: 'year', name: '年代' },
  aB: { category: 'year2', name: '年代2' },
};

// 人数标签（硬编码，因为 NAI 源码中可能分散）
const CHARACTER_COUNT_TAGS = [
  'solo', '1girl', '1boy', '2girls', '2boys', '1girl 1boy',
  'duo', 'trio', 'group', 'multiple girls', 'multiple boys',
  '3girls', '4girls', '5girls', '6+girls',
  '3boys', '4boys', '5boys', '6+boys',
  'no humans', 'couple', 'crowd'
];

// 镜头/视角标签
const CAMERA_TAGS = [
  'portrait', 'upper body', 'cowboy shot', 'full body',
  'close-up', 'face focus', 'dutch angle', 'from above',
  'from below', 'from side', 'from behind', 'pov',
  'first-person view', 'wide shot', 'panorama',
  'fisheye', 'macro', 'split screen', 'polaroid',
  'cropped'
];

/**
 * 从 JS 内容中提取数组
 */
function extractArray(content, varName) {
  const idx = content.indexOf(varName + '=[');
  if (idx === -1) return [];

  let depth = 0;
  let start = idx + varName.length + 1;
  let end = start;

  for (let i = start; i < content.length; i++) {
    if (content[i] === '[') depth++;
    if (content[i] === ']') depth--;
    if (depth === 0) {
      end = i + 1;
      break;
    }
  }

  const arrayStr = content.substring(start, end);
  const matches = arrayStr.match(/"[^"]+"/g) || [];

  // 清理并转换为下划线格式
  return matches
    .map(s => s.replace(/"/g, '').trim())
    .filter(s => s.length > 0 && !['female', 'male', 'strapped'].includes(s))
    .map(s => s.replace(/ /g, '_'));
}

/**
 * 合并并去重标签
 */
function mergeTags(...arrays) {
  const set = new Set();
  for (const arr of arrays) {
    for (const tag of arr) {
      set.add(tag);
    }
  }
  return Array.from(set).sort();
}

/**
 * 主函数
 */
function main() {
  console.log('📖 读取 NAI 源码...');
  const content = fs.readFileSync(SOURCE_FILE, 'utf-8');
  console.log(`   文件大小: ${(content.length / 1024).toFixed(1)} KB`);

  console.log('\n🔍 提取标签数组...');
  const extracted = {};
  let totalTags = 0;

  for (const [varName, config] of Object.entries(VAR_MAPPING)) {
    const tags = extractArray(content, varName);
    extracted[config.category] = tags;
    console.log(`   ${varName} (${config.name}): ${tags.length} 个`);
    totalTags += tags.length;
  }

  console.log(`\n📊 总计提取: ${totalTags} 个标签`);

  // 合并相关类别
  console.log('\n🔧 合并分类...');

  // 合并服装类别
  const clothing = mergeTags(
    extracted.tops || [],
    extracted.dresses || [],
    extracted.bottoms || [],
    extracted.outfits || [],
    extracted.footwear || [],
    extracted.swimwear || [],
    extracted.skirts || [],
    extracted.clothingSets || []
  );
  console.log(`   服装合并: ${clothing.length} 个`);

  // 合并配饰类别
  const accessories = mergeTags(
    extracted.hats || [],
    extracted.accessories || []
  );
  console.log(`   配饰合并: ${accessories.length} 个`);

  // 合并特效类别
  const effects = mergeTags(
    extracted.effects || [],
    extracted.effects2 || []
  );
  console.log(`   特效合并: ${effects.length} 个`);

  // 合并身体特征
  const bodyFeature = mergeTags(
    extracted.bodyFeature || [],
    extracted.chest || []
  );
  console.log(`   身体特征合并: ${bodyFeature.length} 个`);

  // 合并年代
  const year = mergeTags(
    extracted.year || [],
    extracted.year2 || []
  );

  // 发色关键词
  const hairColorKeywords = [
    'blonde', 'blue', 'black', 'brown', 'red', 'white', 'pink',
    'green', 'purple', 'silver', 'grey', 'gray', 'orange',
    'multicolored', 'gradient', 'two-tone', 'streaked',
    'aqua', 'platinum', 'strawberry', 'light', 'dark'
  ];

  // 构建最终 JSON
  const outputData = {
    version: '2.0.0',
    source: 'NovelAI Web JS Bundle (9182-e447568fbb92a99a.js)',
    lastUpdated: new Date().toISOString().split('T')[0],
    extractedBy: 'scripts/extract_nai_tags.js',
    categories: {
      // 表情与姿势
      expression: extracted.expression || [],
      pose: extracted.pose || [],

      // 场景
      scene: extracted.scene || [],
      background: extracted.background || [],
      style: extracted.style || [],

      // 头发
      hairColor: extracted.hairColor || [],
      multicolorHair: extracted.multicolorHair || [],
      hairLength: extracted.hairLength || [],
      hairStyle: extracted.hairStyle || [],
      bangs: extracted.bangs || [],
      hairUpdo: extracted.hairUpdo || [],

      // 眼睛
      eyeColor: extracted.eyeColor || [],
      eyeStyle: extracted.eyeStyle || [],
      eyeVariant: extracted.eyeVariant || [],

      // 服装（合并后）
      clothing: clothing,

      // 配饰（合并后）
      accessory: accessories,

      // 身体特征
      bodyFeature: bodyFeature,
      speciesFeature: extracted.speciesFeature || [],

      // 物品与特效
      items: extracted.items || [],
      effect: effects,

      // 人数与镜头
      characterCount: CHARACTER_COUNT_TAGS.map(t => t.replace(/ /g, '_')),
      camera: CAMERA_TAGS.map(t => t.replace(/ /g, '_')),

      // 年代
      year: year,
    },
    hairColorKeywords: hairColorKeywords,
  };

  // 统计最终数量
  let finalTotal = 0;
  console.log('\n📋 最终分类统计:');
  for (const [cat, tags] of Object.entries(outputData.categories)) {
    console.log(`   ${cat}: ${tags.length} 个`);
    finalTotal += tags.length;
  }
  console.log(`\n✅ 最终总计: ${finalTotal} 个标签`);

  // 写入文件
  console.log('\n💾 写入 JSON 文件...');
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(outputData, null, 2), 'utf-8');
  console.log(`   已保存到: ${OUTPUT_FILE}`);

  console.log('\n🎉 完成！');
}

main();
