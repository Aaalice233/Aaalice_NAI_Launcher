# NAI Launcher

<p align="center">
  <a href="README.md">简体中文</a> | English
</p>

<p align="center">
  <img src="assets/icons/Icon.png" alt="NAI Launcher Logo" width="120">
</p>

<p align="center">
  <strong>A third-party cross-platform client for NovelAI image generation</strong>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest"><img src="https://img.shields.io/github/v/release/Aaalice233/Aaalice_NAI_Launcher?display_name=tag&sort=semver" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Android-lightgrey" alt="Platforms">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <a href="https://discord.gg/R48n6GwXzD"><img src="https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white" alt="Discord"></a>
</p>

NAI Launcher is a cross-platform third-party client for NovelAI built with Flutter. It integrates image generation, image-to-image, inpainting, Vibe / Precise Reference, local gallery, online gallery, generation queues, Krita integration, and statistical tools into a single application for daily generation, batch processing, and long-term management of local artwork.

> This project is not an official NovelAI product. Please ensure you have your own NovelAI account and comply with NovelAI's Terms of Service before use.

## ✨ Features Overview

| Feature | Description |
| --- | --- |
| 🎨 Image Generation | Supports NovelAI Diffusion V1/V2/V3/V4/V4.5/V5, Furry series, common samplers, size presets, multi-character parameters, and Anlas estimation. |
| 🖼️ Image-to-Image & Editing | Supports img2img, inpainting, Focused Inpaint, Outpaint, virtual canvas expansion, hard-edge masks, and click-to-fill region selection. |
| 🌈 Reference & Style | Supports Vibe Transfer, Precise Reference, multi-image references, Vibe pack import/export, and PNG metadata embedding/export. |
| ✍️ Prompt Tools | Includes the complete offline merged Danbooru/e621 tag and alias catalog. Local Danbooru co-occurrence recommendations are delivered as an optional data pack downloaded in the background after the home screen opens. Press `Ctrl/⌘+Shift+Space` for tags related to the tag before the cursor, pin the source tag for continuous insertion, and optionally merge Danbooru online relations, Chinese translations, and AI translations for missing entries. Also includes NAI/SD weight syntax assistance, token counting, in-box prompt search, and pinned words. |
| 🎲 Random Tag Library | Includes a complete restoration of NovelAI's official random wordlists and selects Legacy Anime, Furry V3, or Character Prompts for the current model. Custom mode uses the complete offline tag catalog, while hybrid mode combines both sources. Catalog categories, groups, weights, exclusions, and dependency rules are editable; custom presets support preview, import, and export. |
| 📚 Local Gallery | Supports recursive scanning, SQLite full-text search, categories/collections/favorites, metadata parsing, batch operations, and large image previews. |
| 🌐 Online Gallery | Supports Danbooru / Safebooru / Gelbooru / AI TAG / Codex Gallery search, native rankings, multi-image details, metadata reuse, and batch downloads. |
| 📦 Generation Queue | Supports task sorting, batch generation, pause/resume, failure handling strategies, progress statistics, and queue import/export. |
| 🔌 External Integration | Desktop builds support local Krita and ComfyUI workflows, while platform integrations include system proxy, image copying, native sharing, file import/export, and file location where available. |
| 🌏 Interface Languages | Supports Simplified Chinese, Traditional Chinese, English, and Japanese. Traditional Chinese queries can use the optional Simplified Chinese tag translation dictionary. |

### Online Gallery Sources

- **Danbooru / Safebooru**: Support tag and date searches plus native daily, weekly, and monthly rankings for a selected date. Danbooru supports login and writable favorites; Safebooru uses anonymous, read-only access to `safebooru.donmai.us`.
- **Gelbooru**: Supports public search. Optional API credentials accelerate searches and enable read-only website favorites; no synthetic local ranking is presented.
- **AI TAG**: Supports combined work/author/title/tag/model queries and verbatim Prompt syntax searches such as `::artist:`, with time ranges loaded from the live source configuration. Native live monthly, historical monthly, and older archives are available. Multi-image details support navigation, prefetching, and per-image NAI / Stable Diffusion / ComfyUI metadata reuse, plus current-image and whole-work downloads. AI TAG requires no account and is read-only.
- **Codex Gallery (NovelAI QuickTagCloud)**: Browses fixed public codexes by codex, category, update batch, image state, and full text fields. Supports multi-image and text-only entries, contributor attribution, positive/negative/multi-character Prompt copying, generation and queue handoff, local favorites, and recent history. Content ratings reuse the gallery's existing selector with General, Questionable (adult), and Explicit (R18G / extreme) filters. Versioned codex JSON is cached only after size and SHA-256 verification, while images use the normal runtime network cache; all content remains upstream-only and is neither bundled nor mirrored.

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
| Android | Available | Supports Android 7.0+ phones, landscape layouts, tablets, and large screens. Generation, galleries, libraries, queues, and settings are included, together with system file picking/export, gallery saving, sharing, and APK updates. |
| Linux | Unreleased | Desktop code branches exist, but official packages are not currently provided. |

## 📦 Download & Install

Download the latest version from [Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases). The app persistently surfaces available updates before and after login and fully renders the GitHub Flavored Markdown under the Release’s “What’s Changed” section, including headings, lists, tables, quotes, code, links, and images, without repeating platform downloads or file verification details.

| Platform | Download File | Usage |
| --- | --- | --- |
| Windows | `NAI_Launcher_Windows_<version>_Setup.exe` | Installer version, recommended for general users. Supports resumable in-app downloads, verification, automatic installation, and restart. Manual setup also detects and closes an older version still running in the tray. |
| Windows | `NAI_Launcher_Windows_<version>_Portable.zip` | Portable version. In-app updates stage the new version, preserve user files, atomically swap directories, and automatically roll back and restart the previous version on failure. |
| macOS | `NAI_Launcher_macOS_<version>_Portable.zip` | Portable version. Extract and open `Aaalice NAI Launcher.app`. If an unnotarized build is blocked, you can allow it to open in System Settings > Privacy & Security. |
| Android | `NAI_Launcher_Android_<version>.apk` | Requires Android 7.0 or later. Let Android confirm the installation after download. First-time installs may require allowing your browser or file manager to install unknown apps; later releases can be downloaded and verified in the app before Android confirms the update. |

You can log in for the first time using your NovelAI account credentials or an API Token. Account data is stored locally on the device only. Supported platforms use system secure storage for sensitive information.

### Autocomplete Data & Privacy

- The complete base Danbooru/e621 tag and alias catalog ships with the app and is queried locally without a network connection.
- The local related-tag co-occurrence data is built by this project from a pinned revision of [newtextdoc1111/danbooru-tag-csv](https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv) and published as a separate optional data pack. When related tags are enabled, the app downloads about 30.3 MiB in the background after the home screen opens; installation uses about 78.7 MiB and never blocks startup or base autocomplete.
- If the pack is unavailable, downloading, disabled, or has failed, the related-tag popup can still show Danbooru online results. Under Settings → Data Sources & Cache you can pause, retry, repair, or remove the pack and disable automatic downloads; removal can also opt out of future automatic downloads.
- The Simplified Chinese translation dictionary is optional. Traditional Chinese UI and tag queries can use the same dictionary; queries are converted locally for matching and are not uploaded. It is downloaded directly from the [ffdkj/ComfyUI_Danbooru_Tag_Assistant](https://github.com/ffdkj/ComfyUI_Danbooru_Tag_Assistant) upstream only after user confirmation; this project does not redistribute that database.
- The Danbooru online supplement is enabled by default. It sends only the current English token under the cursor, never the complete prompt; it can be disabled and its cache cleared separately under Settings → Data Sources & Cache.
- AI translation for missing entries is disabled by default. When enabled, it reuses the Prompt Assistant `Translate` route and sends at most 8 untranslated tags to the model service selected by the user, which may incur API charges. Its cache can be cleared separately.

## 💬 Support & Contributing

- For bugs or feature requests, open a [GitHub Issue](https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues).
- Join [Discord](https://discord.gg/R48n6GwXzD) for community help and usage discussions.
- Pull Requests are welcome. Please describe the goal and verification steps, and include screenshots or recordings for UI changes when possible.
- See [CHANGELOG.md](CHANGELOG.md) or [Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases) for complete version changes.

## 🙏 Acknowledgments

- [NovelAI](https://novelai.net/) for providing the image generation service.
- [Suozhang Codex Site (Codex Gallery)](https://novelai.quicktagcloud.com/) and its [AgIzT/NovelAI-Tag](https://github.com/AgIzT/NovelAI-Tag) project for providing Codex Gallery content and services.
- [Flutter](https://flutter.dev/) for cross-platform UI capabilities.
- [Riverpod](https://riverpod.dev/) for state management capabilities.
- Thanks to all contributors and testers.

## 📄 License

This project is open-source under the MIT License. See [LICENSE](LICENSE) for details.
