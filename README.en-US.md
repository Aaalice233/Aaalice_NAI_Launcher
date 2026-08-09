# NAI Launcher

<p align="center">
  <a href="README.md">简体中文</a> | English
</p>

<p align="center">
  <img src="assets/icons/Icon.png" alt="NAI Launcher Logo" width="120">
</p>

<p align="center">
  <strong>A third-party desktop client for NovelAI image generation</strong>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases"><img src="https://img.shields.io/badge/version-1.0.0-blue" alt="Version"></a>
  <img src="https://img.shields.io/badge/Flutter-3.44.2-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS-lightgrey" alt="Platforms">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <a href="https://discord.gg/R48n6GwXzD"><img src="https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white" alt="Discord"></a>
</p>

NAI Launcher is a third-party client for NovelAI built with Flutter. It integrates image generation, image-to-image, inpainting, Vibe / Precise Reference, local gallery, online gallery, generation queues, Krita integration, and statistical tools into a single desktop application, making it ideal for daily generation, batch processing, and long-term management of local artwork.

> This project is not an official NovelAI product. Please ensure you have your own NovelAI account and comply with NovelAI's Terms of Service before use.

## ✨ Features Overview

| Feature | Description |
| --- | --- |
| 🎨 Image Generation | Supports NovelAI Diffusion V1/V2/V3/V4/V4.5, Furry series, common samplers, size presets, multi-character parameters, and Anlas estimation. |
| 🖼️ Image-to-Image & Editing | Supports img2img, inpainting, Focused Inpaint, Outpaint, virtual canvas expansion, hard-edge masks, and click-to-fill region selection. |
| 🌈 Reference & Style | Supports Vibe Transfer, Precise Reference, multi-image references, Vibe pack import/export, and PNG metadata embedding/export. |
| ✍️ Prompt Tools | Includes the complete offline merged Danbooru/e621 tag and alias catalog plus Danbooru co-occurrence recommendations. Press `Ctrl/⌘+Shift+Space` for tags related to the tag before the cursor, pin the source tag for continuous insertion, and optionally merge Danbooru online relations, Chinese translations, and AI translations for missing entries. Also includes NAI/SD weight syntax assistance, token counting, in-box prompt search, and pinned words. |
| 📚 Local Gallery | Supports recursive scanning, SQLite full-text search, categories/collections/favorites, metadata parsing, batch operations, and large image previews. |
| 🌐 Online Gallery | Supports Danbooru / Safebooru / Gelbooru / AI TAG search, native rankings, multi-image details, metadata reuse, and batch downloads. |
| 📦 Generation Queue | Supports task sorting, batch generation, pause/resume, failure handling strategies, progress statistics, and queue import/export. |
| 🔌 External Integration | Supports local Krita integration, local ComfyUI workflows, system proxy, cross-platform image copying, and file location. |

### Online Gallery Sources

- **Danbooru / Safebooru**: Support tag and date searches plus native daily, weekly, and monthly rankings for a selected date. Danbooru supports login and writable favorites; Safebooru uses anonymous, read-only access to `safebooru.donmai.us`.
- **Gelbooru**: Supports public search. Optional API credentials accelerate searches and enable read-only website favorites; no synthetic local ranking is presented.
- **AI TAG**: Supports combined work/author/title/tag/model queries and verbatim Prompt syntax searches such as `::artist:`, with time ranges loaded from the live source configuration. Native live monthly, historical monthly, and older archives are available. Multi-image details support navigation, prefetching, and per-image NAI / Stable Diffusion / ComfyUI metadata reuse, plus current-image and whole-work downloads. AI TAG requires no account and is read-only.

## 🖥️ Interface Preview

<p align="center">
  <img src="assets/images/1.png" alt="Image Generation Interface" width="80%">
  <br>
  <em>Main image generation interface</em>
</p>

<p align="center">
  <img src="assets/images/2.png" alt="Local Gallery" width="80%">
  <br>
  <em>Local gallery and waterfall layout browsing</em>
</p>

<p align="center">
  <img src="assets/images/4.png" alt="Image Details" width="80%">
  <br>
  <em>Image details, metadata, and parameter reuse</em>
</p>

<p align="center">
  <img src="assets/images/5.png" alt="Danbooru Online Gallery" width="80%">
  <br>
  <em>Danbooru Online Gallery</em>
</p>

<p align="center">
  <img src="assets/images/7.png" alt="Statistics Dashboard" width="80%">
  <br>
  <em>Statistics Dashboard</em>
</p>

## 🧩 Platform Support

| Platform | Status | Description |
| --- | --- | --- |
| Windows | Available | Primary development and release platform. Supports system tray, window state persistence, video playback, clipboard, and file location. |
| macOS | Minimal Support | Supports building, launching, login, local database, video playback, Keychain, system proxy, image copying, and file location. System tray support to be added later. |
| Linux | Unreleased | Desktop code branches exist, but official packages are not currently provided. |
| Android | Planned | Still in the adaptation/planning phase. |

## 📦 Download & Install

Download the latest version from [Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases).

| Platform | Download File | Usage |
| --- | --- | --- |
| Windows | `NAI_Launcher_Windows_<version>_Setup.exe` | Installer version, recommended for general users. Installs to the current user directory and supports one-click in-app updates. |
| Windows | `NAI_Launcher_Windows_<version>_Portable.zip` | Portable version. Extract and run `nai_launcher.exe`; in-app updates can download the package, replace files, and restart automatically. |
| macOS | `NAI_Launcher_macOS_<version>_Portable.zip` | Portable version. Extract and open `Aaalice NAI Launcher.app`. If the notarized version is blocked, you can allow it to open in System Settings > Privacy & Security. |

You can log in for the first time using your NovelAI account credentials or an API Token. Account data is stored locally on the device only. The desktop app uses the system's secure storage for sensitive information.

### Autocomplete Data & Privacy

- The base Danbooru tag and alias catalog ships with the app and is queried locally without a network connection.
- The Simplified Chinese translation dictionary is optional. It is downloaded directly from the [ffdkj/ComfyUI_Danbooru_Tag_Assistant](https://github.com/ffdkj/ComfyUI_Danbooru_Tag_Assistant) upstream only after user confirmation; this project does not redistribute that database.
- The Danbooru online supplement is enabled by default. It sends only the current English token under the cursor, never the complete prompt; it can be disabled and its cache cleared separately under Settings → Data Sources & Cache.
- AI translation for missing entries is disabled by default. When enabled, it reuses the Prompt Assistant `Translate` route and sends at most 8 untranslated tags to the model service selected by the user, which may incur API charges. Its cache can be cleared separately.

## 🛠️ Build from Source

### Environment Requirements

- Flutter `3.44.2` (project minimum requirement is Flutter `3.35.0` / Dart `3.10.7`)
- Git LFS, required for pulling `assets/databases/*.db`
- Windows Build: Visual Studio 2022 with Desktop development with C++
- Windows Build: [NuGet CLI](https://learn.microsoft.com/nuget/install-nuget-client-tools), the directory containing `nuget.exe` must be added to `PATH`
- macOS Build: Full Xcode, CocoaPods, Git LFS

### General Steps

```bash
git clone https://github.com/Aaalice233/Aaalice_NAI_Launcher.git
cd Aaalice_NAI_Launcher

git lfs install
git lfs pull --include="assets/databases/*.db"

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

### Windows

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_nuget.ps1
flutter build windows --release
```

The Windows implementation of `flutter_inappwebview` fetches native dependencies like the WebView2 SDK via NuGet during compilation. If `verify_nuget.ps1` fails, please install the NuGet CLI first and ensure `nuget help` runs directly in a new PowerShell window.

Output directory:

```text
build/windows/x64/runner/Release/
```

For Windows desktop development, start a dedicated hot-reload session:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/dev_hot_reload_window.ps1
```

After editing code, safely trigger that existing session from any terminal without starting a second `flutter attach`:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/trigger_hot_reload.ps1
# To reset application state:
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/trigger_hot_reload.ps1 -Restart
```

To inspect the real desktop window, capture it directly into the project temp directory. Direct rendering also works when the window is covered:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/capture_dev_window.ps1
# Custom output path or capture without activating the window:
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/capture_dev_window.ps1 -OutputPath tool/.tmp/ui.png -NoActivate
```

### macOS

```bash
flutter build macos --release
```

Output path:

```text
build/macos/Build/Products/Release/Aaalice NAI Launcher.app
```

During local development, if the Keychain repeatedly prompts for authorization, you can first create a stable local signing certificate and then run the signed launch script:

```bash
scripts/create_macos_dev_cert.sh
scripts/dev_run_macos_signed.sh debug
```

## 🚀 Release Process

Releases are handled by the `Release` workflow in GitHub Actions. After pushing a `v*` tag, the workflow will build the Windows installer, Windows portable, and macOS portable versions separately, and generate `release_manifest.json`, `checksums.txt`, and Release notes.

```bash
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

Before releasing, please ensure:

- The version number in `pubspec.yaml` has been updated; the tag must match the version without the `+build` suffix, e.g., `1.0.0+17` corresponds to `v1.0.0`.
- `CHANGELOG.md` has been updated and categorized under `✨ Added`, `🛠 Improved`, `🐛 Fixed`, and `📦 Release Files`.
- `assets/databases/tag_catalog.db` and `assets/databases/cooccurrence.db` are actual SQLite files rather than Git LFS pointers and pass `dart run tool/tag_catalog/verify_bundled_databases.dart`.
- The Windows installer depends on NSIS; for local packaging, you can run `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/package_windows_release.ps1`.

## 🗂️ Project Structure

```text
nai_launcher/
├── assets/                 # Icons, screenshots, sound effects, tag data, preset databases
├── installer/              # Installer scripts
├── krita_plugin/           # Krita plugin and packaging/validation scripts
├── lib/
│   ├── core/               # Core features: networking, database, caching, encryption, file I/O, shortcuts, etc.
│   ├── data/               # API clients, models, repositories, and business data services
│   ├── l10n/               # Chinese, English, and Japanese UI strings and generated files
│   └── presentation/       # Pages, components, state management, themes, and routing
├── macos/                  # macOS runner
├── scripts/                # Build, signing, database, and testing helper scripts
├── test/                   # Unit tests and widget tests
├── tool/                   # Dev tools, data processing, icon generation, and diagnostic scripts
└── windows/                # Windows runner
```

## 💻 Development Conventions

Common commands:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format lib test
flutter analyze
flutter test
```

Commit messages should follow the format:

```text
type(scope): 中文描述
```

Descriptions are written in Chinese, consistent with the repository history. Common types: `feat`, `fix`, `refactor`, `perf`, `style`, `docs`, `test`, `chore`.

## 🤝 Contributing

Contributions via Issues and Pull Requests are welcome. Before submitting a PR, please describe the goal of the changes, the scope of impact, and how to verify them. For UI or cross-platform behavior changes, please attach screenshots or recordings where possible.

## 🙏 Acknowledgments

- [NovelAI](https://novelai.net/) for providing the image generation service.
- [Flutter](https://flutter.dev/) for cross-platform UI capabilities.
- [Riverpod](https://riverpod.dev/) for state management capabilities.
- Thanks to all contributors and testers.

## 📄 License

This project is open-source under the MIT License. See [LICENSE](LICENSE) for details.
