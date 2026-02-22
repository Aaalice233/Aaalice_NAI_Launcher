# Vibe 测试数据说明

> 本目录存放 Vibe 导入导出功能的测试数据文件。

## 目录结构

```
test/fixtures/vibe_samples/
├── README.md              # 本文件
├── valid/                 # 有效的测试文件
│   ├── bundle_single.naiv4vibe      # 单个 Vibe Bundle
│   ├── bundle_multiple.naiv4vibe    # 多个 Vibe Bundle
│   ├── embed_vibe.png               # 包含嵌入 Vibe 的图片
│   └── embed_vibe.jpg               # 包含嵌入 Vibe 的 JPEG
├── invalid/               # 用于错误处理的测试文件
│   ├── empty.naiv4vibe              # 空的 Bundle 文件
│   ├── corrupted.png                # 损坏的图片文件
│   ├── fake_vibe.png                # 伪装成图片的文本文件
│   └── old_version.naiv4vibe        # 旧版本格式的 Bundle
└── large/                 # 大文件测试
    └── large_bundle.naiv4vibe       # 包含大量 Vibe 的 Bundle
```

## 如何创建测试文件

### 1. 创建有效的 Bundle 文件（.naiv4vibe）

**方法 A: 从应用导出**
1. 在 NAI Launcher 中创建测试 Vibe
2. 使用导出功能 → 选择 "Export Bundle"
3. 将导出的文件复制到此目录

**方法 B: 手动构造（用于自动化测试）**
```dart
// Bundle 文件格式为 JSON，结构如下：
{
  "version": "1.0.0",
  "vibes": [
    {
      "id": "uuid-string",
      "name": "Test Vibe",
      "prompt": "test prompt",
      "negativePrompt": "",
      "strength": 0.5,
      "fidelity": 0.5,
      // ... 其他字段
    }
  ]
}
```

### 2. 创建包含嵌入 Vibe 的图片

**方法: 从应用导出**
1. 在 NAI Launcher 中选择一个 Vibe
2. 使用导出功能 → 选择 "Embed to Image"
3. 选择一张普通图片作为载体
4. 将生成的图片复制到此目录

### 3. 创建损坏的测试文件

**损坏的图片文件**:
```bash
# 创建一个截断的 PNG 文件
head -c 100 valid_image.png > corrupted.png
```

**伪装的图片文件**:
```bash
# 创建一个文本文件，修改扩展名为 .png
echo "This is not an image" > fake_vibe.png
```

**空的 Bundle 文件**:
```bash
# 创建一个 0 字节的文件
touch empty.naiv4vibe
```

### 4. 创建大文件测试数据

**批量导出**: 
1. 在应用中创建 50+ 个 Vibe
2. 使用批量导出功能
3. 将导出的 Bundle 文件复制到 `large/` 目录

## 测试数据规范

### Vibe 测试数据字段

| 字段 | 类型 | 说明 | 示例值 |
|------|------|------|--------|
| id | String | UUID | "550e8400-e29b-41d4-a716-446655440000" |
| name | String | Vibe 名称 | "Test Character" |
| prompt | String | 提示词 | "1girl, solo, ..." |
| negativePrompt | String | 负面提示词 | "lowres, bad anatomy" |
| strength | double | 强度 (0-1) | 0.5 |
| fidelity | double | 保真度 (0-1) | 0.5 |
| seed | int | 随机种子 | 42 |
| referenceImageUrls | List<String> | 参考图片 URL | ["http://..."] |

### 文件大小参考

| 文件类型 | 典型大小 | 备注 |
|---------|---------|------|
| 单个 Vibe Bundle | 1-5 KB | 仅元数据 |
| 多个 Vibe Bundle | 10-100 KB | 取决于数量 |
| 嵌入 Vibe 的 PNG | 原图大小 + 5KB | 元数据开销 |
| 大 Bundle (50+ Vibes) | 500KB - 2MB | |

## 命名规范

测试文件应使用描述性命名：

```
[类型]_[描述]_[版本].扩展名

例如：
- bundle_single_v1.naiv4vibe      # 单个 Vibe Bundle
- bundle_multi_10items_v1.naiv4vibe  # 10 个 Vibe 的 Bundle
- embed_character_v1.png          # 包含角色 Vibe 的图片
- embed_style_v1.jpg              # 包含风格 Vibe 的 JPEG
- corrupt_truncated.png           # 截断的图片
- empty_v1.naiv4vibe              # 空 Bundle
```

## 注意事项

1. **不要提交大文件**: 超过 10MB 的文件不应提交到 Git
2. **版权问题**: 测试图片使用无版权的占位图
3. **定期更新**: 当 Vibe 格式变更时，更新测试文件
4. **版本管理**: 旧版本格式的测试文件保留用于兼容性测试

## 自动化测试使用

```dart
// 示例：在测试中使用这些文件
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vibe Import Tests', () {
    test('should import valid bundle', () async {
      final file = File('test/fixtures/vibe_samples/valid/bundle_single.naiv4vibe');
      // 测试导入逻辑
    });
    
    test('should handle corrupted file', () async {
      final file = File('test/fixtures/vibe_samples/invalid/corrupted.png');
      // 测试错误处理
    });
  });
}
```

---

*最后更新: 2026-02-12*
