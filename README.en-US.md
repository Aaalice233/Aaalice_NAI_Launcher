# NAI Launcher

<p align="center">
  <a href="README.md">简体中文</a> · <a href="README.zh-TW.md">繁體中文</a> · English
</p>

<p align="center">
  <img src="assets/icons/Icon.png" alt="NAI Launcher icon" width="112">
</p>

<p align="center">
  <strong>More than image generation: your complete NovelAI creative workflow in one application.</strong>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest"><img src="https://img.shields.io/github/v/release/Aaalice233/Aaalice_NAI_Launcher?display_name=tag&sort=semver" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/Windows%20%7C%20macOS%20%7C%20Android-available-6f7785" alt="Supported platforms">
  <img src="https://img.shields.io/badge/license-MIT-5b8c5a" alt="MIT License">
  <a href="https://discord.gg/R48n6GwXzD"><img src="https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white" alt="Discord community"></a>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest">Download latest release</a> ·
  <a href="CHANGELOG.md">Read the changelog</a> ·
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues">Report an issue</a> ·
  <a href="https://discord.gg/R48n6GwXzD">Join Discord</a>
</p>

> NAI Launcher is a community-developed third-party client, not an official NovelAI product. Bring your own NovelAI account for online features, and follow the applicable terms of service, content rules, and local laws.

NAI Launcher is built for people who use NovelAI regularly. Generation, editing, Prompts, characters, references, galleries, queues, and Agent Chat connect in one workflow. Windows, macOS, and Android share the same core features, and local tools work before you sign in.

## ✨ One complete creative workflow

| What you want to do | How NAI Launcher helps |
| --- | --- |
| **Start creating** | Write a Prompt, choose a model and parameters, then add characters, Vibes, Precise References, or a source image. |
| **Keep refining** | Use image-to-image, inpainting, outpainting, variations, and enhancement, or restore selected settings from an older image. |
| **Process a batch** | Queue multiple jobs, pause, resume, reorder, retry, and see real progress and Anlas cost. |
| **Build a library** | Organize artwork in the local gallery and turn tags, Vibes, and references into searchable personal libraries. |
| **Find inspiration** | Search several online galleries, inspect original Prompts and metadata, then continue from them in generation. |
| **Move between tools** | Connect Krita, ComfyUI, and cloud backup so the same workflow can continue on Android. |

## 🚀 Feature guide

### 🎨 NovelAI generation and editing

- Text-to-image, image-to-image, regular Inpaint, Focused Inpaint, Outpaint, variations, and enhancement are supported.
- Common NovelAI V5 Curated / Full, V4.5, V4, and V3 workflows are available. Controls, defaults, Token limits, and reference features follow the selected model's capabilities.
- Configure size, sampler, Steps, CFG, Seed, noise schedule, and related parameters. Invalid NovelAI dimensions are caught early with a usable size suggestion.
- Estimated Anlas cost appears before generation. Important paid actions require separate confirmation, and balances and statistics refresh afterward.
- Built-in history and previews let you reuse Prompts, Seeds, models, or selected settings without overwriting work still being edited.

### ✍️ Prompts, pinned tags, and characters

- Positive Prompts, negative Prompts, positive and negative pinned tags, and character content have clear editing areas, even in complex setups.
- Each character can have separate positive and negative Prompts, reference images, and a position. Character count and positioning adapt to the current model.
- The offline Danbooru / e621 catalog and aliases show completion, tag type, popularity, and translations. Optional Chinese and related-tag data packs add more context.
- Related-tag completion helps explore composition, clothing, poses, and visual elements, while Danbooru online results can fill in newer tags.
- Personal tag, pinned-tag, and random-tag libraries support categories, search, batch editing, and quick insertion.
- Switch between text and tag mode at the bottom-right of the input to edit original text, adjust weights, long-press and drag selected tags to reorder them, and undo. Simplified and Traditional Chinese interfaces display the same local Chinese translations below tags; other languages show only the original text. Selecting a complete tag in text mode also displays its translation when using a Chinese interface.
- Drag the bottom edge of the main prompt editor to resize it, or double-click the handle to restore automatic height. Text and tag modes share the same height.
- Disable and restore tags without losing their content. The `/*disabled:original fragment*/` notation is saved and cloud-synced with the Prompt, while disabled content is excluded from generation, effective previews, and Token counts. This is Launcher editing syntax; older clients and external tools may not recognize it. Choose “Copy effective prompt” from the menu for external use.
- Local translation misses can be sent to a configured AI translation service.
- Prompt Assistant tasks, including reverse prompting, optimization, and translation, share a configurable response wait timeout: 1, 2, 5, 10, 15, or 30 minutes, with a 5-minute default.
- Each Prompt Assistant provider saves its own automatic or manual concurrency mode. Automatic mode starts at 5 concurrent requests, and independent tag batches translate in parallel. Each task offers the thinking levels supported by its model. Configure these local settings under Settings → Integrations → Prompt Assistant.

### 🧬 Vibe, Precise Reference, and image editing

- Vibe Transfer accepts images, pre-encoded Vibes, and Bundles, with information extraction and reference strength controls and model-aware encoding reuse.
- Precise Reference supports character and style references, multi-select, batch type changes, and portable packages that include their images.
- Dedicated Vibe and Precise Reference libraries provide categories, search, previews, batch management, import/export, and direct use in the current generation.
- The inpaint editor includes brushes, masks, Focused Inpaint regions, and canvas expansion. Agent Chat can prepare a mask or outpaint draft for review.
- NovelAI image metadata can restore selected model, size, sampler, Steps, CFG, Seed, pinned tags, and character content.

### 🗂️ Local gallery and artwork organization

- Scan only the folders you choose, then find artwork by folder, album, favorite status, Prompt, or generation metadata.
- Image details separate positive and negative Prompts, pinned tags, character content, and full parameters for all-at-once or selective copying.
- Batch categorization, favorites, moving, and deletion sit alongside comparison, slideshows, watermarks, redacted copies, and several viewing modes.
- Desktop gets context menus, hover previews, and drag-and-drop; touch devices get equivalent menus instead of losing features.
- Local images can go directly to generation, Agent Chat, or Krita without repeated exports and file picking.

### 🔎 Online galleries and inspiration

- Browse Danbooru, Safebooru, Gelbooru, AI TAG, and Codex Gallery (NovelAI QuickTagCloud) from one place.
- Search, popular, random, ranking, date, rating, blacklist, and output filters appear according to each source's real capabilities.
- Local favorites work independently. Danbooru sign-in and Gelbooru API settings unlock the matching account features.
- Inspect multi-image posts, original Prompts, and structured generation metadata, download a set, or return recognized settings to generation.
- Codex Gallery includes public codices, categories, versions, multi-image and text entries, contributor credits, and recently viewed items.

### 🤖 Agent Chat

- From a desktop sidebar or mobile drawer, the agent can search tags, organize Prompts, inspect generation history, use libraries, and prepare generation tasks.
- Images, Vibes, and Precise References can be added directly as context. The agent can also prepare masks, expanded canvases, and inpaint drafts.
- Preparation verifies the cost before generation. In Full Access, verified zero-Anlas generations proceed directly; deletion and paid operations still require approval.
- The default character research workflow combines online identity verification, canonical tag lookup, and gallery appearance evidence, noting disabled web access or missing evidence.
- Customize the system prompt by adding plain-language instructions or replacing the built-in body; no placeholders are needed. The working directory, web availability, Skills, and app execution rules are added automatically, with a preview of the final prompt. Customization does not bypass app permission checks.
- Structured questions offer three feasible directions, one Recommended marker, and a custom-answer option per question. Answer sequentially, then review and submit the full set. After two minutes without submission, all recommended options are selected automatically. New questions show a Toast, a question-mark entry icon, and an Android system notification.
- Supports OpenAI-compatible APIs, Google's native Gemini API, third-party Gemini-compatible relays, and OpenRouter, including model lists, thinking levels, and tool calls when supported.
- Your provider controls API keys, regional availability, and fees. Extra network tools such as web search are off by default.

### 📋 Queue, history, and statistics

- Queue multiple generations, pause, resume, reorder, cancel, and retry failures.
- See per-job status, overall progress, and failure details without supervising every request.
- Review creation activity by time, image size, sampler, model, and Anlas usage.

### 🧩 Krita and ComfyUI

- **Krita Bridge** sends a Krita canvas to Launcher for generation or inpainting, then returns the result.
- **ComfyUI** connects to a local server for regular upscale or SeedVR2 workflows. Models and custom nodes stay under your ComfyUI installation.
- **DLSSNR image enhancement (Windows)**: Install the public runtime on demand and test your NVIDIA GPU under Settings → Integrations → DLSSNR. Supports automatic enhancement after generation (off by default), manual image-card enhancement, and a draggable before/after divider. SR scale defaults to 2× and accepts manual input. A slider selects 1–3 NR layers (one by default), chained through GPU FP16 images. SR finishes before NR, and detail/color blending runs once after the final layer. Img2Img Upscale also offers DLSS SR with no NR contribution to the final image, although the current runtime still computes one NR pass. Includes six built-in style presets, with color preservation as the default and alternatives such as Vivid, plus custom presets you can save, rename, and delete; the current selection and adjustments are saved automatically. Parameters include explanations and numeric input. Images are processed locally; manual saves create a new file without overwriting the original.
- Gallery, preview, and editing flows can open these tools directly instead of requiring repeated manual exports.

### ☁️ Sync and backup

- Supports OneDrive, GitHub, and WebDAV. New Google Drive connections are temporarily disabled pending authorization approval. Connecting an account never uploads, downloads, or overwrites content by itself.
- Push, pull, and restore start only when requested, with change previews and conflict handling.
- Select settings, Prompts and libraries, previews, online-gallery settings and favorites, local albums, Agent Prompts and Skills, and optional Vibe or Precise Reference content independently.
- Original local and remote gallery images, credentials, caches, and logs never enter a backup.
- Backups use readable plain data and need no separate recovery key. Check the destination's permissions before syncing.

## 🖼️ Interface preview

### 🖥️ Desktop

<table>
  <tr>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-generation-desktop.png" alt="Generation workspace and Agent Chat" width="100%"><br>
      <sub>Generation workspace: Prompts, parameters, preview, and Agent Chat together</sub>
    </td>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-local-gallery-desktop.png" alt="Local gallery" width="100%"><br>
      <sub>Local gallery: search, albums, folders, and batch organization</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-online-gallery-desktop.png" alt="Online galleries" width="100%"><br>
      <sub>Online galleries: multiple sources, filters, and masonry browsing</sub>
    </td>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-statistics-desktop.png" alt="Statistics dashboard" width="100%"><br>
      <sub>Statistics dashboard: artwork, settings, and Anlas usage</sub>
    </td>
  </tr>
</table>

## 💻 Platform support

| Platform | Current status | Notes |
| --- | --- | --- |
| **Windows** | Primary development and release platform | Installer and portable packages are available. Well suited to long sessions, batch work, and Krita / ComfyUI integration. |
| **macOS** | Available and still being refined | A portable package is available. If macOS blocks an unnotarized build, allow it through the system security prompt. |
| **Android** | Beta | Supports phones, landscape, tablets, and large screens, with touch access to generation, galleries, libraries, queues, Agent Chat, and settings. |
| **Linux** | No official release package | No official download is currently provided. |

## ⚡ Download and get started

### 1. Download the package for your platform

Open [GitHub Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest):

| Platform | File | Usage |
| --- | --- | --- |
| Windows | `NAI_Launcher_Windows_<version>_Setup.exe` | Installer recommended for most users. |
| Windows | `NAI_Launcher_Windows_<version>_Portable.zip` | Portable package; extract and run. |
| macOS | `NAI_Launcher_macOS_<version>_Portable.zip` | Extract and open `Aaalice NAI Launcher.app`. |
| Android | `NAI_Launcher_Android_<version>.apk` | Sideload the APK. The first install may require permission to install unknown apps. |

Every release includes `checksums.txt`. If an archive cannot be extracted or installed, verify the downloaded file first.

### 2. Sign in to NovelAI

Sign in with NovelAI credentials or a **Persistent API Token**. If web security verification prevents password login, a Persistent API Token is usually more reliable. The token is stored only in the current device's secure storage.

### 3. Set up the resources you use

- Select your artwork folders in Settings, then open the local gallery to start scanning.
- Manage the Chinese translation catalog, related-tag data pack, and online caches under **Settings → Data Sources & Cache**.
- For Krita, enable Krita Bridge and follow the [Krita plugin guide](krita_plugin/README.md).
- For ComfyUI, enter the local address and choose a workflow under **Settings → ComfyUI**.
- For cross-device use, connect a destination on the cloud-sync page and carefully select what should be included.

## 🔒 Data and privacy

NAI Launcher does not host your account or artwork on a project-operated server. Data is sent to another service only when you actively use the related feature:

| Feature in use | Where the data goes |
| --- | --- |
| Generation, image-to-image, inpainting, Vibe encoding | NovelAI, including the Prompt, parameters, and source or reference images required for that request. |
| Online gallery search and downloads | The third-party gallery you selected. Availability, rate limits, and content rules belong to each site. |
| AI translation or Agent Chat | The model service you configured. Conversations, attached images, and tool results required by the task may incur provider fees. |
| Sync and backup | Your selected Google Drive, OneDrive, GitHub, or WebDAV destination. Only explicitly selected content is uploaded. |

- NovelAI Tokens, OAuth access/refresh tokens, WebDAV passwords, and GitHub Tokens use device secure storage and are never written into backups.
- Local Prompts, gallery indexes, tags, resource libraries, and Agent sessions stay on the device by default.
- Cloud backups store selected data in plaintext. Local gallery image files are not uploaded; albums, categories, and membership references can sync as lightweight data.
- Online galleries can contain third-party content. Rating filters do not replace user judgment.
- WebDAV security depends on the server and transport you configure. Keep a local copy of important data.

## 🆘 Support and feedback

- If something goes wrong, use **Settings → About → Export diagnostic logs** and attach the exported information to your report.
- [Open an Issue](https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues) for a reproducible bug or feature request.
- [Join Discord](https://discord.gg/R48n6GwXzD) for usage discussion and community help.
- [View Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases) to download packages, verify files, and read release notes.

## 🙏 Acknowledgments

Thanks to [NovelAI](https://novelai.net/), [Codex Gallery](https://novelai.quicktagcloud.com/), [AgIzT/NovelAI-Tag](https://github.com/AgIzT/NovelAI-Tag), [Flutter](https://flutter.dev/), [Riverpod](https://riverpod.dev/), and all contributors and testers.

## 📄 License

This project is open source under the [MIT License](LICENSE).
