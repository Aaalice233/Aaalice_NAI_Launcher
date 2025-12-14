# NAI 官方标签库提取

从 NovelAI 网页源码 `9182-e447568fbb92a99a.js` 中提取的官方标签定义。

## 变量对应表

| 变量 | 类别 | 标签数 |
|-----|------|-------|
| aE | 表情 | 104 |
| aO | 姿势/动作 | 133 |
| eV | 背景 | 46 |
| tl | 场景 | ~120 |
| eH | 艺术风格 | 23 |
| e7 | 上装 | 63 |
| e3 | 连衣裙 | 36 |
| aP | 下装 | 41 |
| aR | 职业/套装 | 48 |
| aT | 鞋类 | 29 |
| aI | 身体特征 | 67 |
| eZ | 种族特征 | 35 |
| tm | 发色 | 18 |
| tp | 多色发 | 7 |
| eQ | 发长 | 7 |
| eK | 发型 | 11 |
| e0 | 刘海 | 24 |
| eY | 发型(扎发) | 34 |
| th | 瞳色 | 13 |
| eX | 眼型 | 9 |
| eJ | 眼睛变体 | 11 |
| e1 | 胸部 | 7 |
| e5 | 帽子 | 48 |
| ts | 配饰 | ~90 |
| tr | 泳装 | 21 |
| aq | 裙装 | 36 |
| tW | 服装套装 | 42 |
| tc | 物品 | ~250 |
| tg | 特效 | ~120 |
| aV | 特效2 | 102 |

---

## 表情 (aE) - 104 tags

```dart
static const expressionTags = [
  // 基础表情
  'smile', 'light smile', 'grin', 'smirk', 'smug',
  'frown', 'pout', 'pouting', 'serious', 'expressionless',
  'angry', 'annoyed', 'scowl', 'glare', 'sneer',
  'sad', 'crying', 'tears',
  'happy', 'laughing',
  'surprised', 'shocked', 'wide eyed',
  'embarrassed', 'blush', 'light blush', 'nose blush', 'blush stickers', 'ear blush',
  'nervous', 'nervous smile', 'nervous sweat', 'worried', 'scared', 'fear',
  'shy', 'flustered', 'guilty',
  'confused', 'thinking', 'bored', 'sleepy', 'tired', 'zzz',
  'drunk', 'ahegao', 'naughty face', 'seductive', 'bedroom eyes', 'lust',
  // 嘴部表情
  'open mouth', 'closed mouth', 'parted lips', 'puckered lips', 'licking lips',
  'tongue out', 'clenched teeth', 'teeth', 'screaming', 'yawn', 'panting',
  'triangle mouth', 'grimace',
  // 眼部表情
  'eyes closed', 'half-closed eyes', 'wink', 'one eye closed',
  'narrowed eyes', 'stare', 'cross-eyed', 'spiral eyes', 'dilated pupils',
  'raised eyebrow', 'raised eyebrows', 'furrowed brow',
  // 符号表情
  '^_^', ':d', ':o', ':3', ';)', ';d', '=_=', '>:)', 'o_o',
  // 特殊标记
  'sweatdrop', 'flying sweatdrops', 'cross-popping vein',
  'spoken heart', 'spoken question mark', 'spoken ellipsis', 'spoken exclamation mark', 'spoken musical note',
  'question mark', 'exclamation point', 'ellipsis', '?!',
  'trembling', 'wince',
  // 其他情绪
  'love', 'proud', 'unimpressed', 'disgust', 'disturbed', 'grumpy',
  'evil grin',
];
```

---

## 姿势/动作 (aO) - 133 tags

```dart
static const poseTags = [
  // 基本姿势
  'standing', 'sitting', 'lying', 'kneeling', 'crouching', 'squatting',
  'on back', 'on side', 'on front', 'on all fours', 'wariza',
  // 腿部姿势
  'legs up', 'legs together', 'spread legs', 'crossed legs', 'raised leg',
  'on one leg', 'pigeon toed', 'knock-kneed', 'knees up', 'tiptoes', 'kick',
  // 手臂姿势
  'arms up', 'arms above head', 'raised arm', 'raised hand', 'outstretched arm', 'outstretched arms',
  'spread arms', 'crossed arms', 'arms at sides', 'arm support',
  'hands behind back', 'hands behind head', 'holding own arm',
  // 手部姿势
  'hand on hip', 'hands on hips', 'hand on chest', 'hand on face', 'hand on cheek', 'hands on cheeks',
  'hand on thigh', 'hands on own thighs', 'hand on knee', 'hands on knees',
  'hand on stomach', 'hand on butt', 'hand in pocket', 'hand to mouth', 'hand between legs',
  'fist', 'open hands', 'claw pose', 'paw pose',
  // 手势
  'v sign', 'double v sign', 'peace sign', 'thumbs up', 'ok sign',
  'pointing', 'pointing up', 'pointing at viewer', 'raised index finger',
  'beckoning', 'waving', 'salute', 'shush', 'praying',
  'heart hands', 'finger to cheek',
  // 头部/视线
  'looking at viewer', 'looking away', 'looking back', 'looking up', 'looking down', 'looking aside',
  // 动作
  'walking', 'running', 'jumping', 'flying', 'falling', 'dancing', 'stretching',
  'leaning forward', 'leaning backward', 'bent over', 'arched back', 'contrapposto',
  'hugging object', 'headpat', 'licking', 'eating', 'drinking', 'singing', 'yawn',
  'wading', 'relaxing', 'sleeping', 'waking up', 'exercise', 'workout',
  // 特殊动作
  'selfie', 'pose', 'action pose', 'fighting pose',
  'shirt lift', 'clothing pull', 'straddling', 'ass up',
  'covering mouth', 'covering face', 'covering eyes', 'covering breasts', 'rubbing eyes',
  'reaching', 'reaching towards viewer', 'restrained',
  'holding object', 'holding sign', 'holding own arm', 'looking at phone',
  'shooting', 'punch', 'fleeing',
  'playing music', 'playing videogame', 'gesture',
  // 位置
  'on bed', 'on chair', 'on couch', 'on floor', 'on ground', 'on one knee',
  'against surface', 'arm under breasts',
  // 对话/思考
  'dialogue', 'thought bubble',
];
```

---

## 背景 (eV) - 46 tags

```dart
static const backgroundTags = [
  // 纯色背景
  'white background', 'grey background', 'black background', 'blue background',
  'pink background', 'red background', 'yellow background', 'green background',
  'purple background', 'orange background', 'brown background', 'aqua background',
  'beige background', 'tan background', 'light blue background', 'lavender background',
  'light brown background', 'silver background',
  // 渐变/多色
  'gradient background', 'two-tone background', 'multicolored background', 'rainbow background',
  // 图案背景
  'floral background', 'polka dot background', 'striped background', 'checkered background',
  'heart background', 'argyle background', 'plaid background', 'patterned background',
  'starry background', 'snowflake background', 'leaf background', 'bubble background',
  'grid background', 'halftone background', 'sunburst background',
  // 特殊效果
  'blurry background', 'dark background', 'abstract background', 'sparkle background',
  'fiery background', 'splatter background', 'sketch background',
  'monochrome background', 'sepia background',
  // 场景
  'scenery',
];
```

---

## 场景 (tl) - ~120 tags

```dart
static const sceneTags = [
  // 室内场景
  'indoors', 'bedroom', 'bathroom', 'kitchen', 'living room', 'classroom', 'library',
  'hallway', 'locker room', 'restaurant', 'shop', 'church', 'shrine',
  'train interior',
  // 室外场景
  'outdoors', 'nature', 'forest', 'bamboo forest', 'field', 'flower field',
  'beach', 'shore', 'ocean', 'lake', 'river', 'pond', 'waterfall', 'pool', 'onsen', 'bath',
  'mountain', 'hill', 'cave', 'ruins',
  // 城市场景
  'city', 'cityscape', 'street', 'alley', 'road', 'bridge',
  'building', 'skyscraper', 'tower', 'castle', 'house', 'rooftop', 'veranda',
  'east asian architecture',
  // 自然元素
  'sky', 'cloudy sky', 'starry sky', 'night sky', 'cloud',
  'moon', 'full moon', 'crescent moon', 'red moon',
  'sun', 'sunset', 'sunrise', 'dusk', 'evening',
  'rain', 'snow', 'snowing', 'fog',
  'water', 'water drop', 'waves', 'puddle', 'underwater', 'reflection',
  // 植物
  'tree', 'bare tree', 'palm tree', 'bamboo', 'bush', 'grass', 'moss', 'vines', 'overgrown',
  // 时间
  'day', 'night', 'horizon', 'mountainous horizon',
  // 物品/结构
  'window', 'curtains', 'door', 'sliding doors', 'stairs', 'fence', 'railing',
  'wall', 'brick wall', 'floor', 'wooden floor', 'reflective floor', 'ceiling',
  'bed', 'couch', 'desk', 'shelf', 'bookshelf', 'sink', 'futon', 'tatami',
  'torii', 'utility pole', 'tombstone',
  // 其他
  'space', 'planet', 'shooting star', 'contrail', 'city lights', 'moonlight',
  'steam', 'smoke', 'shadow', 'shade', 'crowd', 'festival', 'town',
];
```

---

## 艺术风格 (eH) - 23 tags

```dart
static const styleTags = [
  'realistic', 'sketch', 'concept art', 'flat color',
  'watercolor (medium)', 'graphite (medium)', 'oekaki',
  'faux traditional media', 'minimalism', 'impressionism',
  'jaggy lines', 'retro artstyle', 'toon (style)', 'western comics (style)',
  'surreal', 'abstract', 'spot color', 'ai-generated',
  '1970s (style)', '1980s (style)', '1990s (style)',
];
```

---

## 发色 (tm) - 18 tags

```dart
static const hairColorTags = [
  'aqua hair', 'black hair', 'blonde hair', 'blue hair', 'brown hair',
  'green hair', 'grey hair', 'orange hair', 'pink hair', 'purple hair',
  'red hair', 'white hair', 'light brown hair', 'light purple hair',
  'dark blue hair', 'platinum blonde hair', 'silver hair', 'strawberry blonde',
];
```

---

## 多色发 (tp) - 7 tags

```dart
static const multicolorHairTags = [
  'multicolored hair', 'gradient hair', 'rainbow hair',
  'split-color hair', 'streaked hair', 'two-tone hair', 'colored inner hair',
];
```

---

## 发长 (eQ) - 7 tags

```dart
static const hairLengthTags = [
  'very short hair', 'short hair', 'medium hair', 'long hair',
  'very long hair', 'absurdly long hair', 'bald',
];
```

---

## 发型 (eK) - 11 tags

```dart
static const hairStyleTags = [
  'drill hair', 'twin drills', 'messy hair', 'wavy hair', 'curly hair',
  'straight hair', 'spiked hair', 'slicked-back hair', 'wet hair',
  'floating hair', 'wind-blown hair',
];
```

---

## 刘海 (e0) - 24 tags

```dart
static const bangsTags = [
  'bangs', 'blunt bangs', 'swept bangs', 'side-swept bangs', 'parted bangs',
  'asymmetrical bangs', 'braided bangs', 'crossed bangs', 'curtained bangs',
  'dyed bangs', 'hair over eyes', 'hair over one eye', 'hair between eyes',
  'hair intakes', 'single hair intake', 'forelock', 'front ponytail',
  'ahoge', 'antenna hair', 'heart ahoge', 'huge ahoge',
  'hair flaps', 'sidelocks', 'asymmetrical sidelocks',
];
```

---

## 扎发发型 (eY) - 34 tags

```dart
static const hairUpdoTags = [
  // 马尾
  'ponytail', 'high ponytail', 'low ponytail', 'side ponytail', 'short ponytail',
  'folded ponytail', 'braided ponytail',
  // 双马尾
  'twintails', 'short twintails', 'low twintails', 'uneven twintails',
  // 辫子
  'braid', 'braided bun', 'single braid', 'side braid', 'twin braids', 'french braid',
  'crown braid', 'front braid',
  // 发髻
  'hair bun', 'single hair bun', 'double bun', 'cone hair bun', 'braided bun',
  'doughnut hair bun', 'half updo', 'one side up',
  // 其他
  'bob cut', 'hime cut', 'pixie cut', 'bowl cut', 'undercut',
  'hair rings', 'hair pulled back',
];
```

---

## 瞳色 (th) - 13 tags

```dart
static const eyeColorTags = [
  'aqua eyes', 'black eyes', 'blue eyes', 'brown eyes', 'green eyes',
  'grey eyes', 'orange eyes', 'purple eyes', 'pink eyes', 'red eyes',
  'white eyes', 'yellow eyes', 'amber eyes',
];
```

---

## 眼型 (eX) - 9 tags

```dart
static const eyeStyleTags = [
  'crazy eyes', 'empty eyes', 'glowing eyes', 'heterochromia',
  'jitome', 'tareme', 'tsurime', 'sanpaku', 'long eyelashes',
];
```

---

## 眼睛变体 (eJ) - 11 tags

```dart
static const eyeVariantTags = [
  'heart-shaped pupils', 'star-shaped pupils', 'symbol-shaped pupils',
  'slit pupils', 'ringed eyes', 'multicolored eyes', 'gradient eyes',
  'sparkling eyes', 'no pupils', 'constricted pupils', 'blank eyes',
];
```

---

## 胸部 (e1) - 7 tags

```dart
static const breastsTags = [
  'flat chest', 'small breasts', 'medium breasts', 'large breasts',
  'huge breasts', 'gigantic breasts', 'alternate breast size',
];
```

---

## 身体特征 (aI) - 67 tags

```dart
static const bodyFeatureTags = [
  // 体型
  'slim', 'athletic', 'muscular', 'stocky', 'overweight', 'slightly chubby',
  'skinny', 'curvy figure', 'hourglass figure', 'pear-shaped figure', 'voluptuous',
  'short', 'tall', 'short stack',
  // 身体部位
  'small waist', 'wide hips', 'thigh gap', 'thick thighs',
  'small butt', 'big butt', 'huge butt',
  'abs', 'biceps', 'big muscles', 'musclegut',
  'thick arms', 'thick lips', 'lips', 'long eyelashes', 'thick eyebrows', 'thick eyelashes',
  // 特征
  'beauty mark', 'freckles', 'scar', 'eye scar', 'markings',
  'body hair', 'teeth',
  // 非人类特征
  'tail', 'long ears', 'big ears', 'pointy ears', 'floppy ears', 'pivoted ears', 'dipstick ears',
  'scales', 'feathers', 'fur', 'bioluminescence',
  // 多重
  '3 eyes', '1 eye', 'multi eye', 'multi arm', 'multi horn', 'multi tail', 'multi wing',
  // 风格
  'girly', 'manly', 'mature', 'young', 'old', 'teapot (body type)',
  // 效果
  'glistening body', 'glowing body', 'metallic body', 'mottled body',
  'spotted body', 'striped body', 'translucent body',
];
```

---

## 种族特征 (eZ) - 35 tags

```dart
static const speciesFeatureTags = [
  // 兽耳
  'cat ears, cat tail', 'dog ears, dog tail', 'fox ears, fox tail', 'wolf ears, wolf tail',
  'rabbit ears', 'bear ears', 'mouse ears, mouse tail', 'squirrel ears, squirrel tail',
  'horse ears, horse tail', 'cow ears, cow horns, cow tail', 'sheep ears, sheep horns',
  'deer ears, deer antlers', 'tiger ears, tiger tail', 'monkey ears, monkey tail',
  'raccoon ears, raccoon tail', 'bat ears, bat wings',
  // 奇幻种族
  'elf, pointy ears', 'elf, long pointy ears', 'dark elf, pointy ears', 'dark elf, long pointy ears',
  'fairy', 'angel', 'demon horns, demon tail', 'dragon horns, dragon tail',
  'oni, oni horns', 'mermaid, scales', 'head fins, fish tail',
  'slime girl', 'lamia', 'harpy', 'centaur',
  // 其他
  'android', 'orc', 'cyclops', 'monster',
];
```

---

## 上装 (e7) - 63 tags

```dart
static const topsTags = [
  // 衬衫/上衣
  'shirt', 'blouse', 'collared shirt', 'dress shirt', 't-shirt',
  'frilled shirt', 'sleeveless shirt', 'off-shoulder shirt', 'striped shirt',
  'crop top', 'tank top', 'tube top', 'bandeau', 'halterneck', 'criss-cross halter',
  'camisole', 'bustier', 'front-tie top', 'compression shirt',
  // 毛衣/针织
  'sweater', 'turtleneck', 'sleeveless turtleneck', 'ribbed sweater',
  'aran sweater', 'argyle sweater', 'virgin killer sweater', 'cardigan', 'cardigan vest',
  // 外套
  'jacket', 'blazer', 'cropped jacket', 'letterman jacket', 'safari jacket',
  'suit jacket', 'leather jacket', 'hoodie',
  'coat', 'duffel coat', 'fur coat', 'fur-trimmed coat', 'long coat',
  'overcoat', 'raincoat', 'trench coat', 'winter coat',
  'poncho', 'shrug (clothing)', 'surcoat', 'tabard', 'tailcoat',
  // 背心
  'vest', 'sweater vest', 'waistcoat',
  // 内衣
  'babydoll', 'chemise', 'nightgown', 'underbust', 'sarashi', 'tunic',
  'raglan sleeves', 'breast curtains', 'pasties', 'heart pasties',
];
```

---

## 连衣裙 (e3) - 36 tags

```dart
static const dressTags = [
  // 西式连衣裙
  'dress', 'cocktail dress', 'evening gown', 'gown', 'wedding dress',
  'sundress', 'sweater dress', 'sailor dress', 'santa dress',
  'pencil dress', 'tube dress', 'dirndl', 'funeral dress', 'nightgown',
  // 样式变体
  'armored dress', 'backless dress', 'collared dress', 'frilled dress',
  'halter dress', 'latex dress', 'layered dress', 'long dress',
  'off-shoulder dress', 'pleated dress', 'ribbed dress', 'ribbon-trimmed dress',
  'short dress', 'see-through dress', 'sleeveless dress', 'strapless dress',
  'fur-trimmed dress',
  // 东方服饰
  'china dress', 'kimono', 'yukata', 'furisode', 'hakama', 'fundoshi',
];
```

---

## 下装 (aP) - 41 tags

```dart
static const bottomsTags = [
  // 裤子
  'pants', 'jeans', 'tight pants', 'baggy pants', 'sweatpants',
  'capri pants', 'bell-bottoms', 'rolled up pants',
  'cargo pants', 'camo pants', 'harem pants', 'leather pants', 'sagging pants',
  // 短裤
  'shorts', 'short shorts', 'denim shorts', 'dolphin shorts', 'gym shorts',
  'micro shorts', 'booty shorts', 'cargo shorts', 'daisy dukes',
  'hot pants', 'track shorts', 'suspender shorts',
  // 裙子
  'skirt', 'miniskirt', 'microskirt', 'long skirt', 'pleated skirt',
  'plaid skirt', 'high-waist skirt', 'suspender skirt', 'overall skirt', 'grass skirt',
  // 其他
  'buruma', 'chaps', 'kilt', 'pelvic curtain', 'petticoat',
];
```

---

## 职业/套装 (aR) - 48 tags

```dart
static const outfitTags = [
  // 制服
  'school uniform', 'serafuku', 'gym uniform', 'military uniform',
  'police', 'firefighter uniform', 'employee uniform',
  'maid', 'waitress', 'nurse',
  // 运动装
  'soccer uniform', 'baseball uniform', 'basketball uniform', 'cheerleader', 'race queen',
  // 职业装
  'business suit', 'pant suit', 'skirt suit', 'black tie (suit)', 'lab coat',
  // 特殊服装
  'armor', 'power armor', 'bikini armor', 'armored dress',
  'pilot suit', 'hazmat suit', 'spacesuit', 'track suit',
  'santa costume', 'ghost costume', 'magical girl', 'bride',
  // 角色类型
  'knight', 'soldier', 'samurai', 'pirate', 'cowboy outfit',
  'princess', 'dancer', 'gyaru', 'kogal', 'tomboy',
  'priest', 'nun', 'miko',
  // 休闲
  'pajamas', 'overalls', 'harem outfit', 'cassock', 'tutu',
];
```

---

## 鞋类 (aT) - 29 tags

```dart
static const footwearTags = [
  // 靴子
  'boots', 'ankle boots', 'cowboy boots', 'knee boots',
  'high heel boots', 'lace-up boots', 'rubber boots', 'thigh boots',
  // 高跟鞋
  'high heels', 'pumps', 'wedge heels', 'platform footwear',
  // 皮鞋
  'dress shoes', 'loafers', 'mary janes', 'flats', 'pointy footwear',
  // 运动鞋
  'sneakers', 'high tops', 'converse',
  // 凉鞋/拖鞋
  'sandals', 'flip-flops', 'geta', 'gladiator sandals',
  'slippers', 'animal slippers', 'ballet slippers', 'crocs',
  // 其他
  'toeless footwear', 'footwear',
];
```

---

## 帽子 (e5) - ~48 tags

```dart
static const hatTags = [
  'hat', 'beret', 'beanie', 'baseball cap', 'cabbie hat', 'bowler hat',
  'top hat', 'sun hat', 'straw hat', 'witch hat', 'wizard hat',
  'santa hat', 'party hat', 'nurse cap', 'chef hat', 'graduation cap',
  'crown', 'tiara', 'diadem', 'circlet',
  'helmet', 'military helmet', 'viking helmet',
  'hood', 'hood up', 'hood down', 'animal hood',
  'veil', 'bridal veil', 'face veil',
  'headband', 'bandana', 'do-rag', 'headscarf', 'hijab', 'turban',
  'hair ornament', 'hairpin', 'hair bow', 'hair ribbon', 'hair flower',
  'maid headdress', 'headdress', 'headpiece', 'headwear',
  'earmuffs', 'ear covers',
];
```

---

## 配饰 (ts) - ~90 tags

```dart
static const accessoryTags = [
  // 眼镜
  'glasses', 'round eyewear', 'sunglasses', 'goggles', 'monocle', 'eyepatch',
  // 项链/领部
  'necklace', 'pendant', 'choker', 'collar', 'scarf', 'necktie', 'bowtie',
  'neck ribbon', 'neckerchief', 'jabot', 'cravat',
  // 耳饰
  'earrings', 'stud earrings', 'hoop earrings', 'ear piercing',
  // 手部饰品
  'bracelet', 'wristband', 'watch', 'ring', 'wedding ring',
  'gloves', 'fingerless gloves', 'elbow gloves', 'mittens',
  // 腿部饰品
  'thighhighs', 'stockings', 'pantyhose', 'fishnets', 'leg warmers',
  'socks', 'ankle socks', 'loose socks', 'garter belt', 'garter straps',
  // 腰部
  'belt', 'utility belt', 'suspenders', 'sash', 'obi',
  // 翅膀/尾巴
  'wings', 'angel wings', 'demon wings', 'bat wings', 'butterfly wings', 'fairy wings',
  'tail', 'cat tail', 'fox tail', 'demon tail', 'dragon tail',
  // 头部装饰
  'halo', 'horns', 'antlers', 'animal ears', 'cat ears', 'dog ears', 'fox ears',
  'rabbit ears', 'wolf ears', 'fake animal ears',
  // 其他
  'mask', 'face mask', 'gas mask', 'surgical mask',
  'headphones', 'earphones', 'headset',
  'bag', 'backpack', 'handbag', 'shoulder bag',
  'umbrella', 'parasol', 'fan', 'folding fan',
  'cape', 'cloak', 'mantle',
  'apron', 'frilled apron', 'maid apron',
];
```

---

## 泳装 (tr) - 21 tags

```dart
static const swimsuitTags = [
  'swimsuit', 'bikini', 'side-tie bikini', 'string bikini', 'micro bikini',
  'sports bikini', 'highleg bikini', 'o-ring bikini', 'front-tie bikini',
  'one-piece swimsuit', 'competition swimsuit', 'school swimsuit',
  'sling bikini', 'c-string', 'tankini', 'swim trunks', 'swim briefs',
  'sarong', 'cover-up', 'wet clothes', 'wet shirt',
];
```

---

## 物品 (tc) - ~250 tags

```dart
static const objectTags = [
  // 食物
  'strawberry', 'apple', 'cherry', 'lemon', 'watermelon', 'cake', 'cookie',
  'ice cream', 'candy', 'chocolate', 'lollipop', 'doughnut', 'bread', 'rice',
  'sushi', 'ramen', 'pizza', 'burger',
  // 饮料
  'drink', 'water bottle', 'wine', 'wine glass', 'beer', 'coffee', 'tea', 'cup',
  // 武器
  'sword', 'katana', 'knife', 'dagger', 'spear', 'lance', 'axe', 'hammer',
  'bow (weapon)', 'arrow', 'gun', 'rifle', 'pistol', 'sniper rifle', 'machine gun',
  'staff', 'wand', 'magic wand', 'scepter', 'scythe', 'trident',
  'shield', 'sheath',
  // 乐器
  'guitar', 'electric guitar', 'bass guitar', 'violin', 'cello', 'piano',
  'flute', 'trumpet', 'drums', 'microphone', 'headphones',
  // 日用品
  'phone', 'smartphone', 'laptop', 'book', 'notebook', 'pen', 'pencil',
  'camera', 'mirror', 'brush', 'comb', 'towel', 'pillow', 'blanket',
  'clock', 'watch', 'calendar', 'photo', 'picture frame',
  // 玩具
  'teddy bear', 'plush toy', 'doll', 'ball', 'balloon', 'yo-yo',
  'playing card', 'dice', 'chess', 'game controller',
  // 其他
  'flower', 'rose', 'lily', 'sunflower', 'cherry blossoms', 'lotus',
  'candle', 'lantern', 'lamp', 'flashlight', 'key', 'lock',
  'rope', 'chain', 'ribbon', 'bandage', 'syringe',
  'cigarette', 'pipe', 'cigar',
];
```

---

## 特效 (tg + aV) - ~220 tags

```dart
static const effectTags = [
  // 光效
  'sparkle', 'sparkles', 'glitter', 'glow', 'glowing', 'shiny',
  'lens flare', 'light rays', 'sunlight', 'moonlight', 'backlighting',
  'rim lighting', 'dramatic lighting', 'soft lighting', 'hard lighting',
  'bokeh', 'depth of field', 'motion blur', 'speed lines',
  // 粒子效果
  'petals', 'falling petals', 'cherry blossoms', 'flower petals',
  'leaves', 'falling leaves', 'snowflakes', 'confetti',
  'bubbles', 'water drops', 'splashing', 'ripples',
  'fire', 'flames', 'smoke', 'steam', 'mist', 'fog',
  'electricity', 'lightning', 'plasma', 'energy', 'aura',
  'magic', 'magic circle', 'glowing eyes', 'glowing hair',
  // 氛围效果
  'starry sky', 'shooting star', 'aurora', 'rainbow',
  'sunrise', 'sunset', 'dusk', 'dawn', 'golden hour',
  'night', 'moonlit', 'candlelight',
  // 风格效果
  'chromatic aberration', 'film grain', 'vignette', 'halftone',
  'bloom', 'soft focus', 'dreamy', 'ethereal',
  // 动态效果
  'wind', 'wind blown', 'floating', 'flying', 'splashing',
  'explosion', 'impact', 'shockwave',
];
```

---

## 视角/构图 (eG + eU + eW) - 20 tags

```dart
static const cameraTags = [
  // 角度
  'from above', 'from below', 'from behind', 'from side', 'straight-on', 'dutch angle',
  // 构图
  'portrait', 'upper body', 'cowboy shot', 'full body', 'close-up', 'split crop',
  // 焦点
  'solo focus', 'face focus', 'eye focus', 'ass focus', 'foot focus',
  'male focus', 'female focus', 'group focus',
];
```

---

## 人数标签 (内置)

```dart
static const characterCountTags = [
  'solo', '1girl', '1boy', '1other',
  '2girls', '2boys', '3girls', '3boys',
  '4girls', '4boys', '5girls', '5boys',
  '6+girls', '6+boys', 'multiple girls', 'multiple boys',
  'couple', 'group', 'crowd', 'no humans',
];
```

---

## 年代标签 (to + aB) - 20 tags

```dart
static const yearTags = [
  'year 2005', 'year 2006', 'year 2007', 'year 2008', 'year 2009',
  'year 2010', 'year 2011', 'year 2012', 'year 2013', 'year 2014',
  'year 2015', 'year 2016', 'year 2017', 'year 2018', 'year 2019',
  'year 2020', 'year 2021', 'year 2022', 'year 2023', 'year 2024',
];
```

---

## 数据迁移说明

原先硬编码在 `lib/data/models/prompt/tag_category.dart` 中的标签列表已迁移到 JSON 数据文件：

### 文件位置
- **JSON 数据**: `assets/data/nai_official_tags.json`
- **加载服务**: `lib/data/datasources/local/nai_tags_data_source.dart`

### 使用方式

```dart
// 通过 Riverpod Provider 获取数据
final naiTagsData = await ref.watch(naiTagsDataProvider.future);

// 访问各类别标签
final expressions = naiTagsData.expressionTags;
final poses = naiTagsData.poseTags;
final scenes = naiTagsData.sceneTags;
// ... 等等
```

### 优势
1. **数据与代码分离**: 标签数据独立于业务逻辑
2. **易于更新**: 修改 JSON 文件即可更新标签，无需重新编译
3. **可扩展**: 文件夹 `assets/data/` 可放置其他数据 JSON 文件
4. **缓存支持**: `NaiTagsDataSource` 提供内存缓存，避免重复加载
