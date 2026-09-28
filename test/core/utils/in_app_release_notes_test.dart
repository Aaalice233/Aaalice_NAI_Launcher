import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/in_app_release_notes.dart';

void main() {
  group('extractInAppReleaseNotes', () {
    test('extracts only the substantive changelog section', () {
      const releaseBody = '''
# NAI Launcher v2.0.0

## 📥 按系统下载

点击对应按钮直接下载。

## 📝 更新内容

### ✨ 新增

- 新增应用内更新日志。

### 🐛 修复

- 修复下载中断问题。

## 🔐 文件校验

校验说明。
''';

      final result = extractInAppReleaseNotes(releaseBody);

      expect(result, contains('### ✨ 新增'));
      expect(result, contains('新增应用内更新日志'));
      expect(result, contains('### 🐛 修复'));
      expect(result, isNot(contains('按系统下载')));
      expect(result, isNot(contains('文件校验')));
      expect(result, isNot(contains('NAI Launcher v2.0.0')));
    });

    test('normalizes GitHub alerts that crash the Markdown renderer', () {
      const releaseBody = '''
## 📝 更新内容

> [!IMPORTANT]
> Upgrade manually.
''';

      final result = extractInAppReleaseNotes(releaseBody);

      expect(result, contains('> **IMPORTANT**'));
      expect(result, isNot(contains('[!IMPORTANT]')));
    });

    test('keeps custom release notes without the generated section', () {
      const releaseBody = '''
# Major Update

- Added a feature
- Fixed a bug
''';

      expect(extractInAppReleaseNotes(releaseBody), releaseBody.trim());
    });
  });
}
