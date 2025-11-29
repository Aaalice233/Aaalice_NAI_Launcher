# NovelAI 预设捕获指南

使用 Playwright 浏览器工具从 NovelAI 官网捕获质量词和负面词预设的完整流程。

## 前置条件

- 已登录 NovelAI 账号
- 有足够的 Anlas（Opus 用户免费生成）
- Claude Code 的 Playwright MCP 工具已启用

## 捕获流程

### 1. 打开 NovelAI 图片生成页面

```
使用 browser_navigate 工具访问 https://novelai.net/image
```

### 2. 注入 Fetch 拦截器

在页面中注入 JavaScript 代码来捕获 API 请求：

```javascript
// 使用 browser_evaluate 工具执行
() => {
  if (!window._naiCaptured) {
    window._naiCaptured = [];
    const originalFetch = window.fetch;
    window.fetch = async function(...args) {
      const [url, options] = args;
      if (url && url.includes('generate-image')) {
        try {
          if (options && options.body) {
            const body = JSON.parse(options.body);
            window._naiCaptured.push(body);
            console.log('Captured:', body.model);
          }
        } catch (e) {}
      }
      return originalFetch.apply(this, args);
    };
  }
  return 'Interceptor ready, captured: ' + window._naiCaptured.length;
}
```

### 3. 选择模型

1. 使用 `browser_snapshot` 获取页面状态
2. 点击模型选择器下拉菜单
3. 从列表中选择目标模型：
   - NAI Diffusion V4.5 Full
   - NAI Diffusion V4.5 Curated
   - NAI Diffusion V4 Full
   - NAI Diffusion V4 Curated
   - NAI Diffusion Anime V3

### 4. 打开 Prompt Settings 面板

点击提示词输入区域右侧的齿轮按钮，打开设置面板。

### 5. 遍历所有 UC 预设

对于每个模型，需要遍历其所有 UC Preset：

**V4.5 Full 预设：**
- Heavy (ucPreset=0)
- Light (ucPreset=1)
- Furry Focus (ucPreset=2)
- Human Focus (ucPreset=3)
- None (ucPreset=4)

**V4.5 Curated 预设：**
- Heavy (ucPreset=0)
- Light (ucPreset=1)
- Human Focus (ucPreset=2)
- None (ucPreset=3)

**V4 Full / V4 Curated 预设：**
- Heavy (ucPreset=0)
- Light (ucPreset=1)
- None (ucPreset=2)

**V3 Anime 预设：**
- Heavy (ucPreset=0)
- Light (ucPreset=1)
- Human Focus (ucPreset=2)
- None (ucPreset=3)

### 6. 对每个预设执行捕获

1. 从下拉菜单选择预设
2. 点击 Generate 按钮
3. 等待 3 秒左右
4. 提取捕获的数据：

```javascript
// 使用 browser_evaluate 工具执行
() => {
  if (window._naiCaptured && window._naiCaptured.length > 0) {
    const data = window._naiCaptured[window._naiCaptured.length - 1];
    return {
      model: data.model,
      ucPreset: data.parameters?.ucPreset,
      negative_prompt: data.parameters?.negative_prompt,
      qualityTags: data.parameters?.v4_prompt?.caption?.base_caption
    };
  }
  return null;
}
```

### 7. 记录数据

将捕获的数据记录到 `nai_presets_captured.json` 文件：

```json
{
  "capturedAt": "YYYY-MM-DD",
  "models": {
    "model-id": {
      "displayName": "Model Display Name",
      "qualityTags": "quality tags here",
      "ucPresets": {
        "Heavy": {
          "ucPreset": 0,
          "negative_prompt": "negative prompt content"
        }
      }
    }
  }
}
```

### 8. 切换模型并重复

1. 清空捕获数据：`window._naiCaptured = []`
2. 切换到下一个模型
3. 重复步骤 4-7

## 数据结构说明

### API 请求结构

NovelAI 的 `generate-image-stream` API 请求体包含：

```json
{
  "model": "nai-diffusion-4-5-full",
  "parameters": {
    "ucPreset": 0,
    "negative_prompt": "...",
    "v4_prompt": {
      "caption": {
        "base_caption": "user_prompt, quality_tags"
      }
    }
  }
}
```

### 质量词位置

- **V4+ 模型**: `parameters.v4_prompt.caption.base_caption` 中，在用户提示词后面
- 格式：`"user_input, quality_tag1, quality_tag2, ..."`

### 负面词位置

- `parameters.negative_prompt`

## 注意事项

1. 每次切换模型后需要重新打开 Settings 面板
2. qualityTags 中会包含用户输入的测试词，记录时需要去除
3. None 预设的 negative_prompt 为空字符串
4. 不同模型的预设数量可能不同
5. 如果页面刷新，需要重新注入拦截器

## 文件位置

- 捕获数据：`scripts/nai_presets_captured.json`
- 本流程文档：`scripts/NAI_PRESET_CAPTURE_GUIDE.md`
