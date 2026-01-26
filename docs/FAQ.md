# 常见问题解答 | Frequently Asked Questions

**Last Updated:** 2026-01-26
**Version:** 1.0.0

---

## 目录 | Table of Contents

1. [一般问题 | General Questions](#一般问题--general-questions)
2. [安装与设置 | Installation & Setup](#安装与设置--installation--setup)
3. [功能使用 | Feature Usage](#功能使用--feature-usage)
4. [主题与界面 | Themes & Interface](#主题与界面--themes--interface)
5. [账户与认证 | Account & Authentication](#账户与认证--account--authentication)
6. [隐私与数据 | Privacy & Data](#隐私与数据--privacy--data)
7. [故障排除 | Troubleshooting](#故障排除--troubleshooting)
8. [开发相关 | Development](#开发相关--development)

---

## 一般问题 | General Questions

### NAI Launcher 是什么？ | What is NAI Launcher?

#### 中文 | Chinese

**回答：**
NAI Launcher 是一个跨平台的 NovelAI 第三方客户端，提供更现代化的用户界面和增强的功能。它是一个纯客户端应用，无需额外的后端服务，直接连接 NovelAI 官方 API。

**主要特点：**
- 跨平台支持（Windows、Android、Linux）
- 完整的图像生成功能
- 多套精美主题
- 中英双语界面
- 响应式设计

#### English

**Answer:**
NAI Launcher is a cross-platform third-party NovelAI client that provides a more modern user interface and enhanced features. It's a pure client-side application that connects directly to NovelAI's official API without requiring additional backend services.

**Key Features:**
- Cross-platform support (Windows, Android, Linux)
- Complete image generation capabilities
- Multiple beautiful themes
- Bilingual interface (Chinese & English)
- Responsive design

---

### NAI Launcher 是官方应用吗？ | Is NAI Launcher an Official Application?

#### 中文 | Chinese

**回答：**
不是。NAI Launcher 是一个由社区开发的第三方开源客户端，与 NovelAI 官方没有任何关联。您需要拥有自己的 NovelAI 账户才能使用本应用。

**注意事项：**
- 本应用不会收集您的账户信息
- 所有 API 请求直接发送到 NovelAI 官方服务器
- 请遵守 NovelAI 的服务条款

#### English

**Answer:**
No. NAI Launcher is a third-party open-source client developed by the community and is not affiliated with NovelAI. You need your own NovelAI account to use this application.

**Important Notes:**
- This application does not collect your account information
- All API requests are sent directly to NovelAI's official servers
- Please comply with NovelAI's Terms of Service

---

### 支持哪些平台？ | Which Platforms Are Supported?

#### 中文 | Chinese

**回答：**
NAI Launcher 目前支持以下平台：

- **Windows** - Windows 10 或更高版本
- **Android** - Android 6.0 (API Level 23) 或更高版本
- **Linux** - 主流 Linux 发行版（Ubuntu、Fedora、Debian 等）

**未来计划：**
- macOS 支持（开发中）
- iOS 支持（计划中）

#### English

**Answer:**
NAI Launcher currently supports the following platforms:

- **Windows** - Windows 10 or higher
- **Android** - Android 6.0 (API Level 23) or higher
- **Linux** - Major Linux distributions (Ubuntu, Fedora, Debian, etc.)

**Planned:**
- macOS support (in development)
- iOS support (planned)

---

## 安装与设置 | Installation & Setup

### 如何安装 NAI Launcher？ | How Do I Install NAI Launcher?

#### 中文 | Chinese

**回答：**

**Windows 用户：**
1. 下载最新版本的 Windows 安装包（`.exe` 文件）
2. 双击运行安装程序
3. 按照安装向导完成安装

**Android 用户：**
1. 从 GitHub Releases 下载最新的 APK 文件
2. 在手机设置中启用"安装未知来源应用"
3. 打开 APK 文件并完成安装

**从源代码构建：**
```bash
# 克隆仓库
git clone https://github.com/your-username/nai-launcher.git
cd nai-launcher

# 获取依赖
flutter pub get

# 生成代码
dart run build_runner build --delete-conflicting-outputs

# 运行应用
flutter run
```

#### English

**Answer:**

**For Windows Users:**
1. Download the latest Windows installer (`.exe` file)
2. Double-click to run the installer
3. Follow the installation wizard to complete setup

**For Android Users:**
1. Download the latest APK file from GitHub Releases
2. Enable "Install Unknown Apps" in your phone settings
3. Open the APK file and complete installation

**Building from Source:**
```bash
# Clone the repository
git clone https://github.com/your-username/nai-launcher.git
cd nai-launcher

# Get dependencies
flutter pub get

# Generate code
dart run build_runner build --delete-conflicting-outputs

# Run the application
flutter run
```

---

### 是否需要 NovelAI 账户？ | Do I Need a NovelAI Account?

#### 中文 | Chinese

**回答：**
是的，您必须拥有自己的 NovelAI 账户才能使用 NAI Launcher 的所有功能。

**登录方式：**
1. 启动应用后，点击登录按钮
2. 输入您的 NovelAI 电子邮箱和密码
3. 应用将安全地存储您的登录凭证

**安全提示：**
- 您的凭证仅存储在本地设备上
- 所有请求直接发送到 NovelAI 官方服务器
- 应用不会将您的凭证发送到任何第三方服务器

#### English

**Answer:**
Yes, you must have your own NovelAI account to use all features of NAI Launcher.

**How to Login:**
1. Launch the application and click the login button
2. Enter your NovelAI email and password
3. The app will securely store your login credentials

**Security Note:**
- Your credentials are stored only on your local device
- All requests are sent directly to NovelAI's official servers
- The app does not send your credentials to any third-party servers

---

## 功能使用 | Feature Usage

### 如何生成图像？ | How Do I Generate Images?

#### 中文 | Chinese

**回答：**

**基本步骤：**
1. 登录到您的 NovelAI 账户
2. 在主界面找到图像生成区域
3. 输入提示词（Prompt）- 描述您想要生成的图像
4. （可选）输入负面提示词（Undesired Content）- 描述您不希望出现的内容
5. 选择生成参数（模型、尺寸、步数等）
6. 点击"生成"按钮

**提示词技巧：**
- 使用英文提示词效果更好
- 描述越详细，生成结果越精确
- 使用标签式格式（例如：`masterpiece, best quality, 1girl`）
- 可以点击"随机提示词"按钮获取灵感

#### English

**Answer:**

**Basic Steps:**
1. Login to your NovelAI account
2. Locate the image generation area in the main interface
3. Enter a prompt - describe the image you want to generate
4. (Optional) Enter an undesired content prompt - describe what you don't want
5. Select generation parameters (model, size, steps, etc.)
6. Click the "Generate" button

**Prompt Tips:**
- English prompts generally work better
- More detailed descriptions yield more precise results
- Use tag-style format (e.g., `masterpiece, best quality, 1girl`)
- Click the "Random Prompt" button for inspiration

---

### 什么是图生图（Image to Image）？ | What is Image to Image?

#### 中文 | Chinese

**回答：**
图生图（Img2Img）功能允许您使用一张现有图像作为参考，生成新的图像。这个功能可以：
- 修改图像风格
- 改变图像细节
- 在保持构图的同时重新绘制

**使用方法：**
1. 点击"图生图"标签
2. 上传或选择参考图像
3. 设置强度值（Strength）- 控制参考图像对结果的影响
   - 较低的值（0.3-0.5）= 保持更多原图细节
   - 较高的值（0.6-0.9）= 更大幅度地改变图像
4. 输入提示词描述您想要的修改
5. 点击"生成"

#### English

**Answer:**
The Image to Image (Img2Img) feature allows you to use an existing image as a reference to generate new images. This feature can:
- Modify image style
- Change image details
- Redraw while maintaining composition

**How to Use:**
1. Click the "Image to Image" tab
2. Upload or select a reference image
3. Set the strength value - controls how much the reference image influences the result
   - Lower values (0.3-0.5) = Keep more of the original image details
   - Higher values (0.6-0.9) = More drastically change the image
4. Enter a prompt describing the changes you want
5. Click "Generate"

---

### 如何保存生成的图像？ | How Do I Save Generated Images?

#### 中文 | Chinese

**回答：**

**自动保存：**
- 所有生成的图像会自动保存到应用内的图库
- 可以在"历史记录"或"图库"标签中查看

**手动保存到设备：**
1. 在图库中选择要保存的图像
2. 点击"下载"或"保存"按钮
3. 图像将保存到设备的默认下载文件夹

**导出功能：**
- 支持批量导出多个图像
- 可以选择导出格式（PNG、JPEG）

#### English

**Answer:**

**Auto-save:**
- All generated images are automatically saved to the in-app gallery
- View them in the "History" or "Gallery" tab

**Manual Save to Device:**
1. Select the image you want to save from the gallery
2. Click the "Download" or "Save" button
3. The image will be saved to your device's default download folder

**Export Feature:**
- Supports batch export of multiple images
- Choose export format (PNG, JPEG)

---

## 主题与界面 | Themes & Interface

### 如何切换主题？ | How Do I Switch Themes?

#### 中文 | Chinese

**回答：**

**切换方法：**
1. 点击主界面右上角的设置图标（齿轮）
2. 在设置菜单中选择"主题"或"外观"
3. 从主题列表中选择您喜欢的主题
4. 应用会立即应用新主题

**可用主题：**
- **Invoke Style** - 类似 NovelAI 官方界面
- **Discord** - 深色社交风格
- **Linear** - 现代极简主义
- **Cassette Futurism** - 复古未来主义风格
- **Motorola Beeper** - 寻呼机风格

**主题特点：**
- 所有主题都支持亮色和暗色模式
- 主题会应用到整个应用界面
- 可以随时切换，无需重启

#### English

**Answer:**

**How to Switch:**
1. Click the settings icon (gear) in the top-right corner of the main interface
2. Select "Theme" or "Appearance" in the settings menu
3. Choose your preferred theme from the list
4. The new theme will be applied immediately

**Available Themes:**
- **Invoke Style** - Similar to NovelAI's official interface
- **Discord** - Dark social style
- **Linear** - Modern minimalist
- **Cassette Futurism** - Retro-futuristic style
- **Motorola Beeper** - Pager style

**Theme Features:**
- All themes support light and dark modes
- Themes apply to the entire application interface
- Switch anytime without restarting

---

### 如何切换语言？ | How Do I Switch Language?

#### 中文 | Chinese

**回答：**

**切换方法：**
1. 打开设置菜单
2. 选择"语言"或"Language"选项
3. 选择"中文"或"English"
4. 应用会立即更新界面语言

**注意：**
- 语言设置会立即应用到所有界面
- 应用会记住您的选择
- 某些技术文档可能仅提供英文版本

#### English

**Answer:**

**How to Switch:**
1. Open the settings menu
2. Select the "Language" option
3. Choose "中文" or "English"
4. The interface will update immediately

**Note:**
- Language settings apply immediately to all interfaces
- The app will remember your selection
- Some technical documentation may only be available in English

---

## 账户与认证 | Account & Authentication

### 如何管理多个账户？ | How Do I Manage Multiple Accounts?

#### 中文 | Chinese

**回答：**
NAI Launcher 支持添加和切换多个 NovelAI 账户。

**添加新账户：**
1. 在登录界面，点击"添加账户"按钮
2. 输入另一个 NovelAI 账户的凭证
3. 应用会将新账户添加到账户列表

**切换账户：**
1. 点击侧边栏的账户头像或用户名
2. 从账户列表中选择要切换的账户
3. 应用会切换到选定的账户

**删除账户：**
1. 在账户管理页面选择要删除的账户
2. 点击"删除"或"移除"按钮
3. 确认删除操作

#### English

**Answer:**
NAI Launcher supports adding and switching between multiple NovelAI accounts.

**Add a New Account:**
1. On the login screen, click the "Add Account" button
2. Enter credentials for another NovelAI account
3. The app will add the new account to your account list

**Switch Accounts:**
1. Click your account avatar or username in the sidebar
2. Select the account you want to switch to from the list
3. The app will switch to the selected account

**Remove an Account:**
1. Select the account you want to remove from the account management page
2. Click the "Delete" or "Remove" button
3. Confirm the removal operation

---

### 登录凭证存储在哪里？ | Where Are Login Credentials Stored?

#### 中文 | Chinese

**回答：**
您的登录凭证安全地存储在您的本地设备上。

**存储方式：**
- 使用操作系统提供的安全存储机制
- Windows: Credential Manager
- Android: Encrypted SharedPreferences (需要锁屏密码/指纹)
- Linux: Keyring

**安全特性：**
- 凭证永远不会上传到任何服务器
- 所有数据仅存储在本地
- 应用程序卸载后，凭证也会被删除

**建议：**
- 在公共设备上使用后，记得登出账户
- 定期更改您的 NovelAI 密码
- 不要与他人共享您的登录凭证

#### English

**Answer:**
Your login credentials are securely stored on your local device.

**Storage Method:**
- Uses the operating system's secure storage mechanism
- Windows: Credential Manager
- Android: Encrypted SharedPreferences (requires lock screen password/fingerprint)
- Linux: Keyring

**Security Features:**
- Credentials are never uploaded to any server
- All data is stored locally only
- Credentials are deleted when the app is uninstalled

**Recommendations:**
- Remember to log out after using on public devices
- Regularly change your NovelAI password
- Do not share your login credentials with others

---

## 隐私与数据 | Privacy & Data

### NAI Launcher 会收集我的数据吗？ | Does NAI Launcher Collect My Data?

#### 中文 | Chinese

**回答：**
不会。NAI Launcher 是一个纯客户端应用，不会收集或上传您的任何个人数据。

**数据政策：**
- ✅ 所有操作仅在本地设备执行
- ✅ API 请求直接发送到 NovelAI 官方服务器
- ✅ 不包含任何分析或追踪代码
- ✅ 不包含任何广告
- ✅ 开源代码，可自行审计

**什么数据会发送到 NovelAI：**
- 提示词和生成参数（用于图像生成）
- 图像数据（图生图功能）
- 登录凭证（直接发送到 NovelAI）

**什么数据不会离开您的设备：**
- 生成历史记录
- 保存的图像
- 应用设置和偏好

#### English

**Answer:**
No. NAI Launcher is a pure client-side application and does not collect or upload any of your personal data.

**Data Policy:**
- ✅ All operations are executed locally on your device
- ✅ API requests are sent directly to NovelAI's official servers
- ✅ Contains no analytics or tracking code
- ✅ Contains no advertisements
- ✅ Open-source code, available for audit

**What Data is Sent to NovelAI:**
- Prompts and generation parameters (for image generation)
- Image data (Image to Image feature)
- Login credentials (sent directly to NovelAI)

**What Data Never Leaves Your Device:**
- Generation history
- Saved images
- App settings and preferences

---

### 生成的图像存储在哪里？ | Where Are Generated Images Stored?

#### 中文 | Chinese

**回答：**

**默认存储位置：**
- **Windows**: `%USERPROFILE%\Pictures\NAI Launcher\`
- **Android**: `/storage/emulated/0/ Pictures/NAI Launcher/`
- **Linux**: `~/Pictures/NAI Launcher/`

**应用内存储：**
- 图像元数据（提示词、参数等）存储在应用数据库中
- 图像文件可以存储在应用内部或设备相册中

**自定义存储路径：**
1. 打开设置
2. 选择"存储"或"存储路径"
3. 指定您想要的保存位置

**存储空间管理：**
- 定期清理旧的生成记录
- 可以批量删除不需要的图像
- 设置中可以查看当前使用的存储空间

#### English

**Answer:**

**Default Storage Locations:**
- **Windows**: `%USERPROFILE%\Pictures\NAI Launcher\`
- **Android**: `/storage/emulated/0/Pictures/NAI Launcher/`
- **Linux**: `~/Pictures/NAI Launcher/`

**In-App Storage:**
- Image metadata (prompts, parameters, etc.) is stored in the app database
- Image files can be stored in-app or in the device gallery

**Custom Storage Path:**
1. Open settings
2. Select "Storage" or "Storage Path"
3. Specify your desired save location

**Storage Management:**
- Regularly clean up old generation records
- Batch delete unwanted images
- View current storage usage in settings

---

## 故障排除 | Troubleshooting

### 应用无法启动怎么办？ | What Should I Do If the App Won't Start?

#### 中文 | Chinese

**回答：**

**Windows 用户：**
1. 检查是否安装了必要的 Visual C++ 运行库
2. 尝试以管理员身份运行
3. 检查防火墙和杀毒软件设置
4. 查看日志文件：`%APPDATA%\nai-launcher\logs\`

**Android 用户：**
1. 清除应用缓存
2. 卸载并重新安装应用
3. 检查设备存储空间是否充足
4. 确认 Android 版本符合要求（6.0+）

**通用解决方法：**
- 重启设备
- 更新到最新版本
- 查看详细的故障排除指南：`docs/TROUBLESHOOTING.md`

#### English

**Answer:**

**For Windows Users:**
1. Check if necessary Visual C++ runtimes are installed
2. Try running as administrator
3. Check firewall and antivirus settings
4. View log files: `%APPDATA%\nai-launcher\logs\`

**For Android Users:**
1. Clear app cache
2. Uninstall and reinstall the app
3. Check if device has sufficient storage space
4. Confirm Android version meets requirements (6.0+)

**General Solutions:**
- Restart your device
- Update to the latest version
- Check the detailed troubleshooting guide: `docs/TROUBLESHOOTING.md`

---

### 生成失败或出错怎么办？ | What Should I Do If Generation Fails?

#### 中文 | Chinese

**回答：**

**常见原因：**
1. **网络连接问题** - 检查您的网络连接
2. **API 余额不足** - 确认您的 NovelAI 账户有足够的训练点数
3. **提示词过长** - 减少提示词长度
4. **服务器繁忙** - 稍后重试

**解决步骤：**
1. 检查网络连接
2. 确认已登录 NovelAI 账户
3. 查看错误消息了解具体问题
4. 尝试简化提示词
5. 如果问题持续，请查看 `docs/TROUBLESHOOTING.md`

#### English

**Answer:**

**Common Causes:**
1. **Network connection issues** - Check your network connection
2. **Insufficient API balance** - Ensure your NovelAI account has enough training points
3. **Prompt too long** - Reduce prompt length
4. **Server busy** - Try again later

**Troubleshooting Steps:**
1. Check your network connection
2. Confirm you're logged into your NovelAI account
3. Read the error message to understand the specific issue
4. Try simplifying your prompt
5. If the problem persists, check `docs/TROUBLESHOOTING.md`

---

## 开发相关 | Development

### 如何报告 Bug 或建议新功能？ | How Do I Report Bugs or Suggest New Features?

#### 中文 | Chinese

**回答：**

**报告 Bug：**
1. 访问 GitHub Issues 页面
2. 搜索是否已有相同问题
3. 如果没有，创建新的 Issue
4. 提供详细的信息：
   - 问题描述
   - 复现步骤
   - 预期行为和实际行为
   - 应用版本和操作系统
   - 截图或日志（如果适用）

**建议新功能：**
1. 访问 GitHub Issues 页面
2. 使用 "Feature request" 模板
3. 描述功能需求和使用场景
4. 解释为什么这个功能有用

**贡献代码：**
- 欢迎提交 Pull Request
- 请先阅读贡献指南：`CONTRIBUTING.md`
- 遵循代码风格规范

#### English

**Answer:**

**Report Bugs:**
1. Visit the GitHub Issues page
2. Search if the issue already exists
3. If not, create a new Issue
4. Provide detailed information:
   - Problem description
   - Steps to reproduce
   - Expected and actual behavior
   - App version and operating system
   - Screenshots or logs (if applicable)

**Suggest New Features:**
1. Visit the GitHub Issues page
2. Use the "Feature request" template
3. Describe the feature requirements and use cases
4. Explain why this feature would be useful

**Contribute Code:**
- Pull Requests are welcome
- Please read the contribution guide first: `CONTRIBUTING.md`
- Follow the code style guidelines

---

### 如何构建开发版本？ | How Do I Build a Development Version?

#### 中文 | Chinese

**回答：**

**环境要求：**
- Flutter SDK 3.16+
- Dart SDK 3.2+
- Git

**构建步骤：**
```bash
# 1. 克隆仓库
git clone https://github.com/your-username/nai-launcher.git
cd nai-launcher

# 2. 安装依赖
flutter pub get

# 3. 生成代码（Freezed, Riverpod）
dart run build_runner build --delete-conflicting-outputs

# 4. 运行开发版本
flutter run

# 5. 构建发布版本
# Windows
flutter build windows --release

# Android
flutter build apk --release

# Linux
flutter build linux --release
```

**开发提示：**
- 使用 `flutter run` 进行热重载开发
- 运行 `flutter test` 执行测试
- 查看 `CONTRIBUTING.md` 了解更多开发指南

#### English

**Answer:**

**Requirements:**
- Flutter SDK 3.16+
- Dart SDK 3.2+
- Git

**Build Steps:**
```bash
# 1. Clone the repository
git clone https://github.com/your-username/nai-launcher.git
cd nai-launcher

# 2. Install dependencies
flutter pub get

# 3. Generate code (Freezed, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# 4. Run development version
flutter run

# 5. Build release version
# Windows
flutter build windows --release

# Android
flutter build apk --release

# Linux
flutter build linux --release
```

**Development Tips:**
- Use `flutter run` for hot reload development
- Run `flutter test` to execute tests
- Check `CONTRIBUTING.md` for more development guidelines

---

### 如何参与开发？ | How Can I Contribute to Development?

#### 中文 | Chinese

**回答：**

**贡献方式：**
1. **修复 Bug** - 查看 GitHub Issues 并标记为 "good first issue"
2. **添加新功能** - 先创建 Feature Request 讨论实现方案
3. **改进文档** - 修正错误或补充说明
4. **翻译** - 帮助完善多语言支持
5. **测试** - 报告 Bug 并提供测试反馈

**贡献流程：**
1. Fork 项目仓库
2. 创建功能分支
3. 提交代码更改
4. 确保代码通过测试
5. 提交 Pull Request

**重要资源：**
- 贡献指南：`CONTRIBUTING.md`
- 代码规范：遵循项目现有的代码风格
- 技术文档：查看 `docs/` 目录

#### English

**Answer:**

**Ways to Contribute:**
1. **Fix Bugs** - Check GitHub Issues labeled "good first issue"
2. **Add New Features** - Create a Feature Request first to discuss the implementation
3. **Improve Documentation** - Correct errors or add clarifications
4. **Translation** - Help improve multi-language support
5. **Testing** - Report bugs and provide testing feedback

**Contribution Process:**
1. Fork the project repository
2. Create a feature branch
3. Commit your code changes
4. Ensure code passes tests
5. Submit a Pull Request

**Important Resources:**
- Contribution guide: `CONTRIBUTING.md`
- Code standards: Follow the project's existing code style
- Technical documentation: Check the `docs/` directory

---

## 其他问题 | Other Questions

### 没有找到答案？ | Can't Find Your Answer?

#### 中文 | Chinese

**其他资源：**
- **故障排除指南** - 查看 `docs/TROUBLESHOOTING.md` 获取详细的技术问题解决方案
- **贡献指南** - 查看 `CONTRIBUTING.md` 了解如何参与开发
- **GitHub Issues** - 搜索或提问：[github.com/your-username/nai-launcher/issues](https://github.com/your-username/nai-launcher/issues)
- **Discord 社区** - 加入我们的 Discord 服务器与其他用户交流

**联系我们：**
- GitHub Issues - 技术问题和 Bug 报告
- Email - 一般咨询（如果有提供）

#### English

**Other Resources:**
- **Troubleshooting Guide** - Check `docs/TROUBLESHOOTING.md` for detailed solutions to technical issues
- **Contribution Guide** - Check `CONTRIBUTING.md` to learn how to contribute to development
- **GitHub Issues** - Search or ask questions: [github.com/your-username/nai-launcher/issues](https://github.com/your-username/nai-launcher/issues)
- **Discord Community** - Join our Discord server to chat with other users

**Contact Us:**
- GitHub Issues - Technical issues and bug reports
- Email - General inquiries (if provided)

---

**最后更新：** 2026-01-26
**文档版本：** 1.0.0

**需要帮助？** 请查看我们的 [故障排除指南](TROUBLESHOOTING.md) 或在 [GitHub Issues](https://github.com/your-username/nai-launcher/issues) 提问。

---

**Last Updated:** 2026-01-26
**Document Version:** 1.0.0

**Need Help?** Check our [Troubleshooting Guide](TROUBLESHOOTING.md) or ask in [GitHub Issues](https://github.com/your-username/nai-launcher/issues).
