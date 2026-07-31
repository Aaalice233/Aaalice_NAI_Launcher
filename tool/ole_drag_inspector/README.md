# Windows OLE drag inspector

This tool is the cross-process release gate for launcher image drags. It is not
an ordinary drop demo. The WinForms target casts the incoming object to COM
`IDataObject`, calls `EnumFormatEtc(DATADIR_GET)`, calls `GetData` for every
advertised `FORMATETC`, and releases every returned `STGMEDIUM`.

The inspector has readers for `TYMED_HGLOBAL`, `TYMED_ISTREAM`, `TYMED_FILE`,
`TYMED_GDI`, and `TYMED_ENHMF`. It copies referenced files, records raw SHA-256
hashes, converts DIB/GDI/encoded image data to PNG plus canonical RGBA while
preserving 32-bit alpha bytes, and
marks the capture failed when a format is unreadable, unclassified, or looks
like an image but cannot be decoded. Unknown formats never pass silently.

The implementation follows the Windows `IDataObject::GetData` and Shell drag
image contracts:

- <https://learn.microsoft.com/windows/win32/api/objidl/nf-objidl-idataobject-getdata>
- <https://learn.microsoft.com/windows/win32/api/shobjidl_core/nf-shobjidl_core-idragsourcehelper-initializefrombitmap>
- <https://learn.microsoft.com/windows/win32/api/shobjidl_core/ns-shobjidl_core-shdragimage>

## Prerequisites

- Windows x64
- Visual Studio 2022 Community, Professional, Enterprise, or Build Tools with
  the Roslyn C# compiler
- The .NET Framework runtime assemblies shipped with Windows
- The repository Flutter/Dart dependencies from `flutter pub get`

No separate .NET SDK or developer pack is required. `build_inspector.ps1`
compiles directly with the installed Visual Studio Roslyn compiler and Windows
.NET Framework assemblies.

## Build and self-test

```powershell
$ErrorActionPreference = 'Stop'
pwsh -NoProfile -ExecutionPolicy Bypass -File tool/ole_drag_inspector/build_inspector.ps1

$exe = Resolve-Path tool/ole_drag_inspector/windows/bin/OleDragInspector.exe
$output = Join-Path ([System.IO.Path]::GetTempPath()) "nai_launcher_ole_drag_inspector\self_test_$([Guid]::NewGuid().ToString('N'))"
$process = Start-Process -FilePath $exe -ArgumentList @('--self-test', '--output', $output) -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Self-test failed: $($process.ExitCode)" }
```

The self-test exercises DIB wrapping/decoding, normalized PNG/RGBA output,
artifact hashing, and manifest serialization. It does not replace a real OLE
drag from the launcher.

## Generate sentinels

Generate a fresh pair for every release-gate run. Do not use user images.

```powershell
$ErrorActionPreference = 'Stop'
$sentinelManifest = dart run tool/ole_drag_inspector/generate_sentinels.dart
$sentinelManifest
```

The generated directory contains:

- `nai_ole_text.png`: unique valid NovelAI text metadata and no stealth payload.
- `nai_ole_stealth.png`: unique `stealth_pngcomp` payload with all PNG text
  chunks removed without decoding or re-encoding pixels.
- `sentinels.json`: source paths, expected parser sources, unique tokens,
  palettes, lengths, and SHA-256 hashes.

Generation fails unless `UnifiedMetadataParser` recovers the expected unique
metadata from both files before the matrix starts.

## Capture the 16-cell matrix

Start a new inspector session:

```powershell
$ErrorActionPreference = 'Stop'
pwsh -NoProfile -ExecutionPolicy Bypass -File tool/ole_drag_inspector/run_inspector.ps1
```

For every drop, select the exact mode, production path, and sentinel payload in
the inspector before dragging. Capture each combination exactly once:

| Mode | Production path | Payloads |
| --- | --- | --- |
| `protected` | `history_prepared_file` | `text`, `stealth` |
| `protected` | `preview_memory_only` | `text`, `stealth` |
| `protected` | `preview_source_file` | `text`, `stealth` |
| `protected` | `gallery_drag_wrapper` | `text`, `stealth` |
| `unprotected` | `history_prepared_file` | `text`, `stealth` |
| `unprotected` | `preview_memory_only` | `text`, `stealth` |
| `unprotected` | `preview_source_file` | `text`, `stealth` |
| `unprotected` | `gallery_drag_wrapper` | `text`, `stealth` |

`protected` means both protection mode and copy/drag metadata stripping are
enabled. `unprotected` is the positive control and must use protection mode
disabled while the copy/drag stripping setting remains enabled. The equivalent
`protectionMode=true && stripMetadataForCopyAndDrag=false` state is covered by
automated widget tests rather than another manual matrix dimension.

Use the actual production source for each row:

1. Put the sentinel in history and wait until the history drag preparation is
   ready, then drag the history card.
2. Load an unsaved sentinel into central preview and drag it through the memory
   plus temporary-file path.
3. Load the sentinel into central preview with its generated source file path
   retained and drag it.
4. Add the sentinel to the local gallery and drag the real gallery card, which
   exercises the private `_DragWrapper` production implementation.

If a drop is mislabeled or fails, discard the whole session directory and start
a new session. The validator rejects missing cells, duplicate cells, and extra
cells so that a retry cannot hide an earlier failure.

## Validate and clean

The inspector window displays the session directory. Validate it against the
sentinel manifest:

```powershell
$ErrorActionPreference = 'Stop'
dart run tool/ole_drag_inspector/validate_ole_dump.dart `
  --session '<session-directory>' `
  --sentinels '<sentinel-directory>\sentinels.json'
if ($LASTEXITCODE -ne 0) { throw 'OLE release gate failed' }
```

After reviewing `validation_report.json`, rerun with `--cleanup` to delete the
session. Cleanup is refused unless the session is below the operating system
temporary directory and contains the `nai_launcher_ole_drag_inspector` path
segment.

The validator fails unless all 16 cells satisfy the following conditions:

- Every enumerated format was fully read, classified, hashed, released, and
  covered by the validator; every image-like format was decoded.
- `DragImageBits` was enumerated, read, and decoded in every cell.
- Protected cells contain no original SHA, original PNG subsequence, original
  path, unique metadata token, or metadata recoverable by
  `UnifiedMetadataParser`.
- Protected Shell feedback contains the fixed three-color safe-drag marker and
  does not contain either sentinel's visible pattern.
- Unprotected cells expose the original SHA and recover the correct text or
  stealth metadata, proving that the negative checks have a working positive
  control.
- Unprotected source-file and gallery cells expose the normalized source path
  specifically through `CF_HDROP`.
- Unprotected Shell feedback contains the current sentinel's four-color pattern
  and does not contain the protected marker.
- No OLE format name or payload exposes `localData`, `history_internal`, or
  `imageId`.

Raw dumps, copied files, and generated sentinels are temporary security-test
artifacts. Do not commit them or run this workflow with real user images.
