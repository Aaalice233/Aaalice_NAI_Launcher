# NAI Launcher

<p align="center">
  <a href="README.md">简体中文</a> · English
</p>

<p align="center">
  <img src="assets/icons/Icon.png" alt="NAI Launcher icon" width="112">
</p>

<p align="center">
  <strong>A third-party cross-platform client for NovelAI, bringing generation, editing, galleries, tags, and queues together.</strong>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest"><img src="https://img.shields.io/github/v/release/Aaalice233/Aaalice_NAI_Launcher?display_name=tag&sort=semver" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/Windows%20%7C%20macOS%20%7C%20Android-available-6f7785" alt="Supported platforms">
  <img src="https://img.shields.io/badge/license-MIT-5b8c5a" alt="MIT License">
  <a href="https://discord.gg/R48n6GwXzD"><img src="https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white" alt="Discord community"></a>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest">Download latest release</a> ·
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues">Report an issue</a> ·
  <a href="https://discord.gg/R48n6GwXzD">Join Discord</a>
</p>

> NAI Launcher is a third-party client, not an official NovelAI product. Before using online features, make sure you have your own NovelAI account and follow the applicable terms of service and local laws.

![Generation workspace](docs/screenshots/generation-desktop.png)

## What can it do?

NAI Launcher is built for people who use NovelAI regularly: generate images, refine prompts, save references, find inspiration, and manage finished work in one application.

### 🎨 Create

- **Generation and editing**: text-to-image, image-to-image, Inpaint, Focused Inpaint, Outpaint, and upscale/enhance workflows.
- **References and characters**: Vibe Transfer, Precise Reference, multi-character prompts, reference images, and independent negative prompts.
- **Prompt workspace**: tag autocomplete, weight syntax, token counts, pinned words, random tag libraries, and prompt import/export.

### 🗂️ Organize

- **Local gallery**: scan local artwork, search Prompts and metadata, organize categories, favorites, and collections, and perform batch operations.
- **Generation queue**: submit batches, pause/resume, reorder, handle failures, and track progress.
- **Image details**: inspect generation parameters, positive/negative prompts, and character prompts; copy selected content back to the generator or tag library.
- **Statistics**: review creation habits by size, sampler, time, and Anlas usage.

### 🌐 Explore

- **Online galleries**: search Danbooru, Safebooru, Gelbooru, AI TAG, and Codex Gallery (NovelAI QuickTagCloud).
- **Source filters**: search, favorites, date/rankings, content ratings, blacklist, and output filters as provided by each source.
- **Libraries and references**: manage personal tags, pinned words, Vibe resources, and Precise Reference resources.

### 🤝 Connect

- **Agent Chat**: use the generation sidebar or mobile drawer to search tags, organize Prompts, inspect history, and prepare generations; every operation that may consume Anlas requires separate confirmation.
- **Desktop integrations**: connect Krita Bridge and local ComfyUI workflows to your existing tools.
- **Sync and backup**: manually push and pull selected data through GitHub or WebDAV; credentials and NovelAI Tokens are excluded from backups.

## Interface preview

The screenshots below follow the workflow from “generate” to “organize”, “explore”, “connect”, and “use on mobile”.

### Generation and editing

<p align="center">
  <img src="docs/screenshots/generation-desktop.png" alt="Desktop generation workspace" width="100%">
  <br>
  <em>Generation workspace: Prompt, characters, parameters, and history in one view</em>
</p>

<table>
  <tr>
    <td width="33%"><img src="docs/screenshots/generation-panel.png" alt="Character and image-to-image panel" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/generation-params.png" alt="Generation parameters" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/generation-batch.png" alt="Batch generation in progress" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/generation-results.png" alt="Batch generation results" width="100%"></td>
  </tr>
</table>

### Galleries and libraries

<table>
  <tr>
    <td width="33%"><img src="docs/screenshots/online-favorites.png" alt="Online gallery favorites and search" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/online-detail.png" alt="Online gallery image details" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/codex-detail.png" alt="Codex Gallery details" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/blacklist-settings.png" alt="Online gallery blacklist settings" width="100%"></td>
    <td><img src="docs/screenshots/vibe-library.png" alt="Vibe library" width="100%"></td>
    <td><img src="docs/screenshots/precise-reference.png" alt="Precise Reference library" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/random-library.png" alt="Random tag library configuration" width="100%"></td>
    <td><img src="docs/screenshots/tag-library.png" alt="Character and artist tag library" width="100%"></td>
    <td><img src="docs/screenshots/stats.png" alt="Statistics dashboard" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/queue.png" alt="Generation queue management" width="100%"></td>
    <td></td>
    <td></td>
  </tr>
</table>

### Agent Chat and settings

<table>
  <tr>
    <td width="33%"><img src="docs/screenshots/agent.png" alt="Agent Chat and generation collaboration" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/agent-confirm.png" alt="Agent generation confirmation" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/agent-result.png" alt="Agent generation result" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/agent-search.png" alt="Agent tag library search" width="100%"></td>
    <td><img src="docs/screenshots/generation-settings.png" alt="Generation settings" width="100%"></td>
    <td><img src="docs/screenshots/agent-settings.png" alt="Agent settings" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/data-settings.png" alt="Data and storage settings" width="100%"></td>
    <td><img src="docs/screenshots/backup-settings.png" alt="Backup and restore settings" width="100%"></td>
    <td><img src="docs/screenshots/security-settings.png" alt="Security and sharing settings" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/integrations-settings.png" alt="Integration settings" width="100%"></td>
    <td><img src="docs/screenshots/autocomplete.png" alt="Tag autocomplete" width="100%"></td>
    <td><img src="docs/screenshots/tag-search.png" alt="Tag search and library results" width="100%"></td>
  </tr>
</table>

### Android

<table>
  <tr>
    <td width="25%"><img src="docs/screenshots/mobile-generation-progress.png" alt="Android generation in progress" width="100%"></td>
    <td width="25%"><img src="docs/screenshots/generation-mobile.png" alt="Android completed generation" width="100%"></td>
    <td width="25%"><img src="docs/screenshots/mobile-viewer.png" alt="Android image viewer" width="100%"></td>
    <td width="25%"><img src="docs/screenshots/mobile-image-menu.png" alt="Android image actions" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/mobile-generation-settings.png" alt="Android generation settings" width="100%"></td>
    <td><img src="docs/screenshots/mobile-agent.png" alt="Android Agent Chat" width="100%"></td>
    <td><img src="docs/screenshots/mobile-agent-result.png" alt="Android Agent generation flow" width="100%"></td>
    <td><img src="docs/screenshots/mobile-gallery.png" alt="Android local gallery" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/mobile-library.png" alt="Android tag library" width="100%"></td>
    <td><img src="docs/screenshots/mobile-more.png" alt="Android more menu" width="100%"></td>
    <td><img src="docs/screenshots/mobile-settings.png" alt="Android settings" width="100%"></td>
    <td><img src="docs/screenshots/mobile-extensions.png" alt="Android extensions" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/mobile-image-menu-alt.png" alt="Android image menu" width="100%"></td>
    <td><img src="docs/screenshots/mobile-tag-library.png" alt="Android tag library" width="100%"></td>
    <td></td>
    <td></td>
  </tr>
</table>

## Platform support

| Platform | Current status | Notes |
| --- | --- | --- |
| **Windows** | Primary development and release platform | Suited to long sessions, batch generation, and Krita / ComfyUI integration. Installer and portable packages are available. |
| **macOS** | Available and still being refined | Portable package available. If macOS blocks an unnotarized build, allow it in the system security prompt. |
| **Android** | Beta | Supports phones, landscape layouts, tablets, and large screens, with mobile entry points for generation, galleries, libraries, queues, and settings. |
| **Linux** | No official release package | Not currently a supported download target. |

## Download and first steps

### 1. Download

Download the package for your platform from [GitHub Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest). Every release also includes `checksums.txt`, which can help diagnose a damaged download or installation failure.

| Platform | File | Notes |
| --- | --- | --- |
| Windows | `NAI_Launcher_Windows_<version>_Setup.exe` | Installer package, recommended for most users. |
| Windows | `NAI_Launcher_Windows_<version>_Portable.zip` | Portable package; extract and run without installing. |
| macOS | `NAI_Launcher_macOS_<version>_Portable.zip` | Extract and open `Aaalice NAI Launcher.app`. |
| Android | `NAI_Launcher_Android_<version>.apk` | Sideload the APK; the first installation may require permission to install unknown apps. |

### 2. Sign in to NovelAI

You can sign in with NovelAI credentials or a **Persistent API Token**. If web security verification prevents password login, Persistent API Token is the more reliable option. Local galleries, libraries, resource libraries, and settings can be used without signing in; generation, Vibe encoding, cloud upscale, and other online operations require authentication.

### 3. Set up your workflow

- **Local gallery**: choose artwork folders in Settings, then open the gallery to start scanning. Scanning is performed on demand rather than immediately on application startup.
- **Autocomplete**: the base tag catalog is included and works offline. Related-tag recommendations, the Chinese tag dictionary, and AI translation are optional data sources managed under **Settings → Data Sources & Cache**.
- **Krita**: enable Krita Bridge in Launcher Settings, then follow [`krita_plugin/README.md`](krita_plugin/README.md) to install the plugin.
- **ComfyUI**: configure the local ComfyUI address and workflow under **Settings → Integrations**. Models and nodes remain managed by your ComfyUI environment.

## Data and privacy

NAI Launcher does not host your account or artwork on a project-operated server. Different features send data to different services:

| Feature in use | Recipient |
| --- | --- |
| Generation, image-to-image, editing, Vibe encoding | NovelAI, including the relevant Prompt, parameters, and reference/source images. |
| Online gallery search and downloads | The third-party gallery you selected; availability, rate limits, and content rules belong to each site. |
| AI translation or Agent Chat | The model service you configured; conversations, attached images, and tool results needed for the task may incur service charges. |
| Sync and backup | The GitHub or WebDAV storage you configured; only the data categories you explicitly select are uploaded. |

- NovelAI Tokens, WebDAV passwords, and GitHub Tokens are stored in the device secure store and are not included in backups.
- Local Prompts, gallery indexes, tags, and Agent sessions are stored on the device by default; Agent web tools are off by default.
- Online galleries contain third-party content. Rating filters do not replace user judgment; follow source-site rules, local laws, and NovelAI's terms of service.
- WebDAV security depends on the server and transport you configure. Confirm that the server is trusted and keep important local backups before syncing.

## Support and feedback

- [Open an Issue](https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues) for a reproducible bug or feature request.
- [Join Discord](https://discord.gg/R48n6GwXzD) for usage discussion and community help.
- [View Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases) for packages, checksums, and release notes.
- Pull Requests are welcome. For UI changes, include screenshots or a recording to make review and reproduction easier.

## Acknowledgments

Thanks to [NovelAI](https://novelai.net/), [Codex Gallery](https://novelai.quicktagcloud.com/), [AgIzT/NovelAI-Tag](https://github.com/AgIzT/NovelAI-Tag), [Flutter](https://flutter.dev/), [Riverpod](https://riverpod.dev/), and all contributors and testers.

## License

This project is open source under the [MIT License](LICENSE).
