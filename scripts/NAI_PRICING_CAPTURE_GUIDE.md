# NovelAI 图像生成价格捕获指南

使用 Playwright 浏览器工具从 NovelAI 官网捕获各模型、分辨率下的 Anlas 消耗价格。

## 前置条件

- 已登录 NovelAI 账号
- Claude Code 的 Playwright MCP 工具已启用

## 捕获流程

### 1. 打开 NovelAI 图片生成页面

```
使用 browser_navigate 工具访问 https://novelai.net/image
```

### 2. 注入价格监控脚本

在页面中注入 JavaScript 代码来捕获价格信息：

```javascript
// 使用 browser_evaluate 工具执行
() => {
  if (!window._naiPricing) {
    window._naiPricing = {
      records: [],
      lastAnlas: null
    };

    // 获取当前 Anlas 余额
    const getAnlas = () => {
      const el = document.querySelector('[class*="anlas"], [class*="Anlas"]');
      if (el) {
        const text = el.textContent.replace(/[^0-9]/g, '');
        return parseInt(text) || null;
      }
      return null;
    };

    // 拦截 fetch 请求
    const originalFetch = window.fetch;
    window.fetch = async function(...args) {
      const [url, options] = args;

      // 记录生成前的余额
      if (url && url.includes('generate-image')) {
        window._naiPricing.lastAnlas = getAnlas();

        try {
          if (options && options.body) {
            const body = JSON.parse(options.body);
            window._naiPricing.pendingRequest = {
              model: body.model,
              width: body.parameters?.width,
              height: body.parameters?.height,
              steps: body.parameters?.steps,
              n_samples: body.parameters?.n_samples,
              smea: body.parameters?.sm,
              smeaDyn: body.parameters?.sm_dyn,
              sampler: body.parameters?.sampler,
              timestamp: Date.now()
            };
          }
        } catch (e) {}
      }

      const response = await originalFetch.apply(this, args);

      // 生成完成后计算消耗
      if (url && url.includes('generate-image') && window._naiPricing.pendingRequest) {
        setTimeout(() => {
          const newAnlas = getAnlas();
          if (window._naiPricing.lastAnlas !== null && newAnlas !== null) {
            const cost = window._naiPricing.lastAnlas - newAnlas;
            window._naiPricing.records.push({
              ...window._naiPricing.pendingRequest,
              beforeAnlas: window._naiPricing.lastAnlas,
              afterAnlas: newAnlas,
              cost: cost
            });
            console.log('Price recorded:', cost, 'Anlas');
          }
          window._naiPricing.pendingRequest = null;
        }, 2000);
      }

      return response;
    };
  }
  return 'Pricing monitor ready, records: ' + window._naiPricing.records.length;
}
```

### 3. 测试矩阵

需要测试以下参数组合：

#### 模型列表
- `nai-diffusion-4-5-full` (V4.5 Full)
- `nai-diffusion-4-5-curated` (V4.5 Curated)
- `nai-diffusion-4-full` (V4 Full)
- `nai-diffusion-4-curated` (V4 Curated)
- `nai-diffusion-3` (V3 Anime)

#### 分辨率列表（像素数）
| 名称 | 尺寸 | 像素数 |
|------|------|--------|
| Small | 512×768 | 393,216 |
| Normal | 832×1216 | 1,011,712 |
| Large | 1024×1024 | 1,048,576 |
| Large+ | 1216×1216 | 1,478,656 |
| Wallpaper | 1536×1536 | 2,359,296 |

#### 其他参数
- **Steps**: 28 (标准), 50 (高质量)
- **n_samples**: 1, 2, 3, 4
- **SMEA**: off, on, on+dyn

### 4. 执行测试

对每个参数组合：

1. 选择模型
2. 设置分辨率
3. 设置步数和其他参数
4. 输入简单测试提示词（如 "test"）
5. 点击 Generate 按钮
6. 等待生成完成（约 5-10 秒）

### 5. 提取价格数据

```javascript
// 使用 browser_evaluate 工具执行
() => {
  if (window._naiPricing && window._naiPricing.records.length > 0) {
    return JSON.stringify(window._naiPricing.records, null, 2);
  }
  return '[]';
}
```

### 6. 清空记录（切换测试组时）

```javascript
// 使用 browser_evaluate 工具执行
() => {
  if (window._naiPricing) {
    window._naiPricing.records = [];
  }
  return 'Records cleared';
}
```

## 数据结构

### 捕获的价格记录

```json
{
  "model": "nai-diffusion-4-5-full",
  "width": 832,
  "height": 1216,
  "steps": 28,
  "n_samples": 1,
  "smea": false,
  "smeaDyn": false,
  "sampler": "k_euler_ancestral",
  "beforeAnlas": 8863,
  "afterAnlas": 8863,
  "cost": 0
}
```

### 输出文件格式

保存到 `scripts/nai_pricing_data.json`：

```json
{
  "capturedAt": "2024-XX-XX",
  "version": "1.0",
  "notes": "Captured from NovelAI official website",
  "opusFreeConditions": {
    "maxSteps": 28,
    "maxResolution": 1048576,
    "maxSamples": 1
  },
  "models": {
    "nai-diffusion-4-5-full": {
      "displayName": "NAI Diffusion V4.5 Full",
      "version": 4.5,
      "pricing": [
        {
          "resolution": 1011712,
          "steps": 28,
          "nSamples": 1,
          "smea": false,
          "cost": 0,
          "note": "Opus free"
        },
        {
          "resolution": 1011712,
          "steps": 28,
          "nSamples": 4,
          "smea": false,
          "cost": 60,
          "note": "4 images, first free"
        }
      ]
    }
  },
  "formula": {
    "description": "V3+ pricing formula",
    "baseCost": "(2.951823174884865e-21 * pixels + 5.753298233447344e-7 * pixels * steps) * smeaFactor",
    "smeaFactors": {
      "none": 1.0,
      "smea": 1.2,
      "smeaDyn": 1.4
    },
    "opusDiscount": "First image free if conditions met"
  }
}
```

## 快速测试脚本

一次性测试多个关键参数组合：

```javascript
// 获取所有记录的摘要
() => {
  if (!window._naiPricing) return 'Monitor not initialized';

  const summary = window._naiPricing.records.map(r => ({
    model: r.model.replace('nai-diffusion-', ''),
    size: `${r.width}x${r.height}`,
    pixels: r.width * r.height,
    steps: r.steps,
    n: r.n_samples,
    smea: r.smea ? (r.smeaDyn ? 'dyn' : 'on') : 'off',
    cost: r.cost
  }));

  return JSON.stringify(summary, null, 2);
}
```

## 注意事项

1. **Opus 免费条件**：
   - 分辨率 ≤ 1,048,576 像素 (1024×1024)
   - 步数 ≤ 28
   - n_samples = 1
   - 每次生成仅第一张免费

2. **价格精度**：
   - Anlas 消耗向上取整
   - 最小消耗为 2 Anlas（非免费情况）

3. **测试顺序建议**：
   - 先测试免费边界条件
   - 再测试超出免费条件的组合
   - 最后测试大分辨率和高步数

4. **页面刷新**：
   - 如果页面刷新，需要重新注入监控脚本

## 文件位置

- 价格数据：`scripts/nai_pricing_data.json`
- 本指南文档：`scripts/NAI_PRICING_CAPTURE_GUIDE.md`
