# NAI Launcher

<p align="center">
  <a href="README.md">简体中文</a> · 繁體中文 · <a href="README.en-US.md">English</a>
</p>

<p align="center">
  <img src="assets/icons/Icon.png" alt="NAI Launcher 圖示" width="112">
</p>

<p align="center">
  <strong>不只是生成圖片，而是把整套 NovelAI 創作流程放進一個應用程式。</strong>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest"><img src="https://img.shields.io/github/v/release/Aaalice233/Aaalice_NAI_Launcher?display_name=tag&sort=semver" alt="最新版本"></a>
  <img src="https://img.shields.io/badge/Windows%20%7C%20macOS%20%7C%20Android-available-6f7785" alt="支援平台">
  <img src="https://img.shields.io/badge/license-MIT-5b8c5a" alt="MIT License">
  <a href="https://discord.gg/R48n6GwXzD"><img src="https://img.shields.io/badge/Discord-加入社群-5865F2?logo=discord&logoColor=white" alt="Discord 社群"></a>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest">下載最新版本</a> ·
  <a href="CHANGELOG.md">查看更新記錄</a> ·
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues">回報問題</a> ·
  <a href="https://discord.gg/R48n6GwXzD">加入 Discord</a>
</p>

> NAI Launcher 是社群開發的第三方用戶端，並非 NovelAI 官方產品。使用線上功能前，請準備自己的 NovelAI 帳號，並遵守相關服務條款、內容規則與當地法律。

NAI Launcher 面向經常使用 NovelAI 的圖像創作者。生成、改圖、Prompt、角色、參考圖、圖庫、佇列和智慧代理都能在同一套工作流程中銜接；Windows、macOS 與 Android 共用核心能力，不登入也能先使用本機工具。

## ✨ 一套完整的創作流程

| 你想做什麼 | NAI Launcher 可以怎麼幫你 |
| --- | --- |
| **開始創作** | 寫 Prompt、選模型和參數，再加入角色、Vibe、Precise Reference 或來源圖片。 |
| **反覆調整** | 圖片生成圖片、局部重繪、擴圖、變體、增強，隨時從歷史圖片取回部分參數。 |
| **批次處理** | 把多組任務交給佇列，暫停、繼續、排序、重試，並查看真實進度與 Anlas 消耗。 |
| **累積素材** | 將作品放進本機圖庫，把標籤、Vibe 和精準參考整理成可搜尋、可分類的個人資源庫。 |
| **尋找靈感** | 搜尋多個線上圖庫，查看原始 Prompt 與生成資訊，再送回生成頁面繼續創作。 |
| **跨工具與裝置** | 連接 Krita、ComfyUI 和雲端備份，讓桌面創作流程延續到 Android。 |

## 🚀 功能總覽

### 🎨 NovelAI 生成與編輯

- 支援文字生成圖片、圖片生成圖片、一般 Inpaint、Focused Inpaint、Outpaint、變體和增強。
- 支援 NovelAI V5 Curated / Full、V4.5、V4 與 V3 系列常用工作流程；切換模型時，可用參數、預設值、Token 上限與參考功能會跟隨模型能力變化。
- 可設定尺寸、採樣器、Steps、CFG、Seed、噪聲排程等參數；尺寸不符合 NovelAI 限制時，會先提供可用建議。
- 生成前顯示預估 Anlas 消耗；可能產生費用的重要操作會另外確認，完成後自動更新餘額與統計。
- 內建生成歷史與預覽，可重用 Prompt、Seed、模型和部分參數，不會覆蓋仍在編輯的內容。

### ✍️ Prompt、固定詞與角色

- 正向 Prompt、負向 Prompt、正負面固定詞和角色內容分區編輯，複雜工作流程也能看清每一部分的來源。
- 多角色可以分別設定正負面 Prompt、參考圖與畫面位置，並依目前模型處理角色數量和定位能力。
- 內建 Danbooru / e621 基礎標籤與別名，可離線顯示補全、類型、熱度和翻譯；也可安裝中文詞庫與相關標籤資料包。
- 相關標籤補全能繼續尋找構圖、服裝、動作和畫面元素；Danbooru 線上結果可補充較新的標籤。
- 自訂標籤詞庫、固定詞和隨機詞庫都支援分類、搜尋、批次編輯與快速插入。
- 輸入框右下角可切換文字／標籤模式，直接編輯原文、調整權重、多選後長按標籤拖動排序及復原；簡中與繁中介面在標籤下顯示同一份本機中文譯文，其他語言只顯示原文。文字模式選取完整標籤時也可查看譯文。
- 主提示詞輸入框底部可拖動調整高度，按兩下拖動條恢復自動增高；文字與標籤模式共用高度。
- 標籤可停用後恢復，原文中的 `/*disabled:原片段*/` 會隨提示詞儲存和雲端同步，但停用內容不參與生成、有效預覽和 Token 計數。這是 Launcher 編輯語法，舊版用戶端及外部工具不保證識別；外部使用請在選單選擇「複製有效提示詞」。
- 本機譯文未命中的內容可交給你設定的 AI 翻譯服務。
- 提示詞助手的反推、最佳化、翻譯等任務支援統一設定回應等待逾時，可選 1、2、5、10、15 或 30 分鐘，預設 5 分鐘。
- 提示詞助手的提供商可獨立儲存自動或手動並行模式，預設自動從 5 個請求開始調整；獨立標籤批次並行翻譯。各任務可選擇模型支援的思考等級，設定統一位於「設定 → 整合 → 提示詞助手」，儲存在本機。

### 🧬 Vibe、精準參考與圖片編輯

- Vibe Transfer 支援圖片、預編碼 Vibe 與 Bundle，可調整資訊提取和參考強度，並依模型重用已有編碼。
- Precise Reference 可用於角色或風格參考，支援多選、批次修改類型，以及包含圖片的設定包匯入匯出。
- Vibe 與 Precise Reference 都有獨立資源庫，可分類、搜尋、預覽、批次管理，並直接送到目前生成任務。
- 重繪編輯器提供畫筆、遮罩、Focused Inpaint 區域和畫布擴展；也可先讓智慧代理準備遮罩或擴圖草稿，再由你檢查後送出。
- 可從 NovelAI 圖片中讀取模型、尺寸、採樣器、Steps、CFG、Seed、固定詞和角色內容，並選擇性還原。

### 🗂️ 本機圖庫與作品整理

- 只掃描你指定的目錄，再依資料夾、相簿、收藏、Prompt 和生成資訊尋找作品。
- 圖片詳情會拆分正負面 Prompt、固定詞、角色內容與完整參數，可整組複製，也可只取需要的部分。
- 支援批次分類、收藏、移動與刪除，並提供圖片比較、幻燈片、浮水印、遮蔽副本和多種檢視方式。
- 桌面版提供右鍵、懸停預覽和拖放，觸控端提供對應選單；核心操作不會因換到手機而消失。
- 本機圖片可直接傳送到生成頁面、智慧代理或 Krita，省去重複匯出和選擇檔案。

### 🔎 線上圖庫與靈感收集

- 聚合 Danbooru、Safebooru、Gelbooru、AI TAG 與法典圖鑑（NovelAI QuickTagCloud）。
- 依來源提供搜尋、熱門、隨機、排行榜、日期、內容分級、黑名單與輸出篩選，不把不支援的功能硬套到所有網站。
- 支援本機收藏；登入 Danbooru 或設定 Gelbooru API 後，可使用對應帳號功能。
- 可查看多圖作品、原始 Prompt 和結構化生成資訊，整組下載，或把可識別的參數送回生成頁面。
- 法典圖鑑支援公開法典、分類、版本、多圖與純文字條目、貢獻者資訊和最近瀏覽。

### 🤖 智慧代理

- 在桌面側欄或行動版抽屜中對話，讓代理查詢標籤、整理 Prompt、查看生成歷史、操作資源庫並準備生成任務。
- 圖片、Vibe 和 Precise Reference 可直接加入會話；代理也能準備重繪遮罩、擴展畫布與重繪草稿。
- 「準備任務」和「真正生成」嚴格分開：代理規劃不會扣 Anlas，實際送出前仍需要明確確認。
- 支援 OpenAI 相容介面、Google Gemini 原生介面、第三方 Gemini 相容中轉與 OpenRouter；可取得模型清單，並依模型能力啟用思考等級和工具呼叫。
- 模型服務、API Key、可用地區和費用由你選擇的供應商負責；網路搜尋等額外工具預設關閉。

### 📋 佇列、歷史與統計

- 生成任務可批次加入佇列，支援暫停、繼續、調整順序、取消和重試失敗任務。
- 執行中可查看單項狀態、整體進度和失敗原因，不必守著每一次請求。
- 統計頁面可依時間、尺寸、採樣器、模型與 Anlas 消耗回顧創作記錄。

### 🧩 Krita 與 ComfyUI

- **Krita Bridge**：把 Krita 畫布送到 Launcher 生成或重繪，再將結果送回 Krita。
- **ComfyUI**：連接本機伺服器，執行一般放大或 SeedVR2 工作流程；伺服器模型與自訂節點仍由你的 ComfyUI 環境負責。
- 從圖庫、預覽和編輯流程都能進入這些工具，不必每次手動匯出再重新選擇檔案。

### ☁️ 同步與備份

- 支援 OneDrive、GitHub 與 WebDAV；Google Drive 因授權審核尚未通過，暫時停用新增連線入口。連接帳號不會自動上傳、下載或覆蓋內容。
- 推送、拉取和還原都由你主動開始，並可預覽差異與處理衝突。
- 可分別選擇設定、Prompt 與詞庫、詞庫預覽圖、線上圖庫設定與收藏、本機相簿、智慧代理 Prompt 與 Skill，以及可選的 Vibe、Precise Reference。
- 本機圖庫原圖、遠端圖庫原圖、帳號憑證、快取和日誌不會進入備份。
- 備份使用方便查看與移轉的明文資料，不需要額外復原金鑰；請自行確認目標空間的存取權限。

## 🖼️ 介面預覽

### 🖥️ 桌面版

<table>
  <tr>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-generation-desktop.png" alt="生成工作區與智慧代理" width="100%"><br>
      <sub>生成工作區：Prompt、參數、預覽與智慧代理同畫面協作</sub>
    </td>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-local-gallery-desktop.png" alt="本機圖庫" width="100%"><br>
      <sub>本機圖庫：搜尋、相簿、資料夾與批次整理</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-online-gallery-desktop.png" alt="線上圖庫" width="100%"><br>
      <sub>線上圖庫：多個來源、篩選與瀑布流瀏覽</sub>
    </td>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-statistics-desktop.png" alt="統計儀表板" width="100%"><br>
      <sub>統計儀表板：作品、參數與 Anlas 使用情況</sub>
    </td>
  </tr>
</table>

## 💻 支援平台

| 平台 | 目前狀態 | 說明 |
| --- | --- | --- |
| **Windows** | 主要開發與發佈平台 | 提供安裝版和可攜版，適合長時間創作、批次任務以及 Krita / ComfyUI 串接。 |
| **macOS** | 可用，持續改善中 | 提供可攜版；若系統阻止開啟未公證應用程式，請依 macOS 安全提示手動允許。 |
| **Android** | Beta | 支援手機、橫向畫面、平板和大螢幕；生成、圖庫、詞庫、佇列、代理與設定都有觸控入口。 |
| **Linux** | 暫無正式發行包 | 目前不提供正式下載包。 |

## ⚡ 下載與開始使用

### 1. 下載對應平台的安裝包

前往 [GitHub Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest)：

| 平台 | 檔案 | 用法 |
| --- | --- | --- |
| Windows | `NAI_Launcher_Windows_<version>_Setup.exe` | 推薦給大多數使用者的安裝版。 |
| Windows | `NAI_Launcher_Windows_<version>_Portable.zip` | 解壓縮後直接執行的可攜版。 |
| macOS | `NAI_Launcher_macOS_<version>_Portable.zip` | 解壓縮後開啟 `Aaalice NAI Launcher.app`。 |
| Android | `NAI_Launcher_Android_<version>.apk` | 側載 APK；首次安裝可能需要允許目前的應用程式安裝未知來源軟體。 |

每個 Release 都會提供 `checksums.txt`。如果下載後無法解壓縮或安裝，可以先核對檔案校驗值。

### 2. 登入 NovelAI

可以使用 NovelAI 帳號密碼或 **Persistent API Token** 登入。如果網頁安全驗證造成密碼登入失敗，建議改用 Persistent API Token。Token 只會儲存在目前裝置的安全儲存空間中。

### 3. 設定常用資源

- 在「設定」中選擇本機作品目錄，進入本機圖庫後開始掃描。
- 在「設定 → 資料來源與快取」中管理中文詞庫、相關標籤資料包和線上快取。
- 需要 Krita 串接時，先啟用 Krita Bridge，再按照 [Krita 外掛說明](krita_plugin/README.md) 安裝外掛。
- 需要 ComfyUI 時，在「設定 → ComfyUI」中填寫本機位址並選擇工作流程。
- 需要跨裝置使用時，在雲端同步頁面連接一個備份目標，並仔細確認要同步的內容。

## 🔒 資料與隱私

NAI Launcher 不會在專案自有伺服器上託管你的帳號或作品。只有在你主動使用對應功能時，資料才會傳送給相關服務：

| 使用的功能 | 資料會傳送到哪裡 |
| --- | --- |
| 生成、圖片生成圖片、重繪、Vibe 編碼 | NovelAI；包括本次請求所需的 Prompt、參數和來源圖片或參考圖。 |
| 線上圖庫搜尋與下載 | 你選擇的第三方圖庫；可用性、速率限制和內容規則由各網站決定。 |
| AI 翻譯或智慧代理 | 你設定的模型服務；對話、附加圖片和完成任務所需的工具結果可能產生服務費用。 |
| 同步與備份 | 你選擇的 Google Drive、OneDrive、GitHub 或 WebDAV；只上傳明確勾選的內容。 |

- NovelAI Token、OAuth access/refresh token、WebDAV 密碼和 GitHub Token 使用裝置安全儲存，不會寫入備份。
- 本機 Prompt、圖庫索引、標籤、資源庫和代理工作階段預設儲存在本機。
- 雲端備份以明文儲存所選資料；本機圖庫的圖像本體不上傳，相簿、分類和成員引用可作為輕量資料同步。
- 線上圖庫可能包含第三方內容；分級篩選不能取代使用者判斷。
- WebDAV 的安全性取決於你設定的伺服器與傳輸方式，請保留重要資料的本機副本。

## 🆘 支援與回饋

- 如遇異常，請透過「設定 → 關於 → 匯出診斷日誌」儲存排查資訊，並在回報時一併提供。
- [提交 Issue](https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues)：回報可以重現的問題或提出功能建議。
- [加入 Discord](https://discord.gg/R48n6GwXzD)：交流使用經驗、取得社群協助。
- [查看 Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases)：下載版本、校驗檔案並閱讀更新內容。

## 🙏 致謝

感謝 [NovelAI](https://novelai.net/)、[法典圖鑑](https://novelai.quicktagcloud.com/)、[AgIzT/NovelAI-Tag](https://github.com/AgIzT/NovelAI-Tag)、[Flutter](https://flutter.dev/)、[Riverpod](https://riverpod.dev/) 以及所有貢獻者和測試使用者。

## 📄 授權條款

本專案依照 [MIT License](LICENSE) 開源。
