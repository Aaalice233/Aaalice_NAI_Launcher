# NAI Launcher Bridge for Krita

This folder contains the Krita-side Python plugin for the NAI Launcher Krita Bridge.

## Manual Install

1. Enable the Krita Bridge in NAI Launcher settings.
2. Copy both entries below into `%APPDATA%/krita/pykrita/`:
   - `nai_launcher_bridge.desktop`
   - `nai_launcher_bridge/`
3. Start Krita, open `Settings > Configure Krita > Python Plugin Manager`, enable `NAI Launcher Bridge`, then restart Krita.
4. Open the docker from `Settings > Dockers > NAI Launcher Bridge`.

The plugin reads `%APPDATA%/nai-launcher/krita-bridge.json`, connects to `ws://127.0.0.1:{port}/krita`, and authenticates with the session secret from that discovery file. It prefers Krita's bundled `PyQt5.QtWebSockets.QWebSocket`; if that module is unavailable, it uses the bundled stdlib WebSocket fallback client. It never reads or stores NovelAI credentials.

## Profile Installer

From the repository root, preview the exact profile paths and actions without
writing anything:

```powershell
python krita_plugin/install_plugin.py
```

Check whether the profile already has the full plugin runtime file set,
required `.desktop` manifest entries, and Krita enable flag:

```powershell
python krita_plugin/install_plugin.py --check
```

Summarize the real-profile and Krita docker diagnostics gates:

```powershell
python krita_plugin/acceptance_report.py
```

For a safe repeatable preflight that runs plugin tests, refreshes the plugin
zip, applies and verifies an isolated temporary profile layout, checks the real
profile without writing it, and regenerates the acceptance report with
automation evidence, run:

```powershell
python krita_plugin/preflight.py
```

On Windows, you can run the same safe preflight through:

```bat
scripts\krita_bridge_preflight.bat
```

The isolated install uses a temporary directory only; the preflight
intentionally does not install or enable the plugin in the real Krita profile.
Add `--require-acceptance` only after real GUI evidence has been recorded and
you want the command to fail while any gate remains open.

If `dist` or `build/krita_acceptance` is not writable, direct the package and
report outputs to a writable temporary path:

```bash
python3 krita_plugin/preflight.py --skip-tests --package-output /tmp/krita_preflight_plugin.zip --report-json /tmp/krita_preflight_acceptance.json --report-markdown /tmp/krita_preflight_acceptance.md
```

Save the same acceptance summary as artifacts:

```powershell
python krita_plugin/acceptance_report.py --output-json build/krita_acceptance/acceptance.json --output-markdown build/krita_acceptance/acceptance.md
```

For a quick local summary after real GUI validation, add only the manual
evidence flags that were actually confirmed:

```powershell
python krita_plugin/acceptance_report.py --evidence-plugin-manager-visible --evidence-docker-visible --evidence-launcher-settings-toggle --evidence-auto-discovery-connect --evidence-auth-failure-safe --evidence-img2img-e2e --evidence-inpaint-e2e --evidence-focused-inpaint-e2e --evidence-krita-cancel-e2e --evidence-no-selection-behavior --evidence-large-canvas-rejected --evidence-disconnect-generation-safe --evidence-preview-throttle --evidence-result-layer-aligned --evidence-launcher-history-recorded --evidence-novelai-token-launcher-only --evidence-bridge-rejects-unauthenticated --evidence-gallery-send-e2e --evidence-disabled-bridge-existing-flows --output-json build/krita_acceptance/acceptance.json --output-markdown build/krita_acceptance/acceptance.md
```

When using the report as a hard release gate, copy
`krita_plugin/acceptance_evidence.example.json`, set only confirmed items to
`"passed": true`, add a non-empty `"note"` to each passed gate, and pass it
with `--require-ok`:

```powershell
python krita_plugin/acceptance_report.py --evidence-file build/krita_acceptance/evidence.json --output-json build/krita_acceptance/acceptance.json --output-markdown build/krita_acceptance/acceptance.md --require-ok
```

Evidence files are strict. Unknown gate names are rejected instead of ignored,
and passed manual gates require notes. `--require-ok` also rejects bare
`--evidence-*` flags when the report would otherwise pass, so typoed or
context-free entries cannot silently become release evidence.

Attach supporting automation evidence separately when you want the report to
show the exact test commands already run. Automation evidence is informational
only and does not turn manual GUI gates into passing gates:

```powershell
python krita_plugin/acceptance_report.py --automation-evidence-file build/krita_acceptance/automation_evidence.json --output-json build/krita_acceptance/acceptance.json --output-markdown build/krita_acceptance/acceptance.md
```

After closing Krita and confirming the profile change, apply the installation:

```powershell
python krita_plugin/install_plugin.py --apply
```

On Windows, the same real-profile update can be run from the repository root
with:

```bat
scripts\update_krita_bridge_plugin.bat
```

The batch script runs a read-only check before and after installation. Treat
`profile_ok=true` as the success signal; stale installed modules make the script
exit non-zero. It also refuses to update while `krita.exe` is running, so close
Krita before rerunning it.

The installer copies `nai_launcher_bridge.desktop` and the
`nai_launcher_bridge/` folder into `%APPDATA%/krita/pykrita/`, writes
`enable_nai_launcher_bridge=true` under `[python]` in `%LOCALAPPDATA%/kritarc`,
and stores backups plus `install_manifest.json` under
`build/krita_real_profile_backup/<timestamp>/`.
The `--check` and acceptance-report profile gate also verify that the installed
runtime modules are present and that the `.desktop` file still declares
`ServiceTypes=Krita/PythonPlugin`, `X-KDE-Library=nai_launcher_bridge`, and
`Name=NAI Launcher Bridge`.
When `--apply` or `--restore --apply` is used, the installer checks for a
running `krita.exe` process and refuses to write profile files until Krita is
closed. Use `--allow-running-krita` only after manually confirming there is no
unsaved Krita work at risk.
Use `--pykrita-dir`, `--kritarc`, or `--backup-dir` to target an isolated test
profile instead of the real Windows profile.

To restore the profile from a backup directory, preview first:

```powershell
python krita_plugin/install_plugin.py --restore --backup-dir build/krita_real_profile_backup/<timestamp>
```

Then apply the restore after confirming the backup:

```powershell
python krita_plugin/install_plugin.py --restore --apply --backup-dir build/krita_real_profile_backup/<timestamp>
```

## Usage

1. Open a Krita document up to `4096x4096`.
2. Click `Connect` if the docker has not connected automatically.
3. Use `Get Params` to copy the current Launcher prompt/settings into Krita.
4. Click `Img2Img` to send the visible document projection to Launcher.
5. For inpaint, create a non-empty Krita selection; the docker always uses that selection as the repaint mask.
6. If `Focused Inpaint` is enabled, keep the active Krita selection on the inner repaint area. The selected inner frame is also the actual repaint mask. `Minimum Context` automatically derives the outer focus/context frame. The docker updates the frame text immediately as the active selection or `Minimum Context` changes, then debounces the temporary `NAI Focus Preview` layer write so Krita selection dragging stays responsive. Disabling `Focused Inpaint` removes that double-frame preview.
7. Before exporting a new request, bridge-owned preview layers are removed from the visible projection so temporary `NAI Preview` or `NAI Focus Preview` overlays are not sent back into Launcher as source pixels. Focused Inpaint restores the live focus frame after the clean canvas export.
8. Progress previews update the `NAI Preview` layer at most every 350 ms when NovelAI streaming returns preview frames; the last progress preview is kept visible when the final result arrives. Final images appear in the Docker result area; single-click a result to preview it, double-click it to insert it as a new layer when dimensions match the active document, otherwise it opens as a new document. Use `Delete` to remove selected results or `Clear` to empty the result area.

The V1 bridge rejects very small canvases and canvases larger than `4096x4096` instead of silently rescaling the image or mask.
If Launcher disconnects during a request, the docker clears the preview layer,
unblocks the controls, and retries the bridge connection automatically. Launcher
errors are shown in red and clear after a short delay.

Click `Diagnostics` after installation to write
`%APPDATA%/nai-launcher/krita-bridge-diagnostics.json`. The report checks the
plugin layout, QtWebSockets availability, Launcher discovery file, active
document, PNG export/writeback, and active Krita selection input. Open a
Krita document before running diagnostics when validating canvas round trips.
Acceptance reports require this Diagnostics file to include `schema_version: 1`,
`plugin: "nai_launcher_bridge"`, and a passing `plugin_layout` check before any
Diagnostics gate can pass.

For runtime supporting evidence inside the real Krita process, open Krita's
Scripter, run `tool/krita_bridge_runtime_probe.py`, and inspect
`%APPDATA%/nai-launcher/krita-bridge-runtime-probe.json`. The probe creates a
small document and verifies the live Focused Inpaint frame behavior, including
the absent manual preview button, `Minimum Context` updates, selection changes,
clean source export without baking in `NAI Focus Preview`, and removal of the
double-frame layer when Focused Inpaint is disabled.

## Troubleshooting

- Plugin does not appear: confirm `nai_launcher_bridge.desktop` and the `nai_launcher_bridge/` folder are direct children of `%APPDATA%/krita/pykrita/`, then restart Krita.
- Cannot connect: enable the Krita Bridge in Launcher settings and confirm `%APPDATA%/nai-launcher/krita-bridge.json` exists.
- Stale discovery file: restart Launcher; the plugin ignores discovery files whose `pid` no longer belongs to a running process.
- Wrong secret or authentication error: click `重生成会话` in Launcher settings, then reconnect from Krita.
- Large canvas rejected: resize the document to `4096x4096` or smaller for V1.
- Empty inpaint mask: create a non-empty Krita selection before pressing `Inpaint`. If Launcher still reports an empty mask for an existing selection, the selection is too thin or too small to survive NovelAI's 8-pixel mask grid; thicken or enlarge it.
- QtWebSockets import error: the plugin falls back to the bundled stdlib WebSocket client. If connection still fails, regenerate the Launcher bridge session and reconnect.
- Generation stream interrupted: retry after checking Launcher logs; the bridge reports this when NovelAI streaming ends without a final image.

## Package

From the repository root:

```powershell
python krita_plugin/package_plugin.py
```

The script writes `dist/nai_launcher_bridge_krita_plugin.zip`. If `dist` is not
writable in the current environment, pass `--output` to write the same zip
layout elsewhere:

```bash
python3 krita_plugin/package_plugin.py --output /tmp/nai_launcher_bridge_krita_plugin.zip
```

The zip root contains the `.desktop` file and `nai_launcher_bridge/` folder, matching Krita's importer layout.

## License

The Krita-side plugin is distributed under GPL-3.0-or-later. The Launcher
application is a separate process and communicates with the plugin only through
the local WebSocket bridge.
