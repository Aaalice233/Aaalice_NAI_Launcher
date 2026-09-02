param(
    [switch]$Restart,
    [ValidateSet('Windows', 'Android')]
    [string]$Target = 'Windows'
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'Console hot-reload injection currently requires Windows.'
}

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '../../../..')
$processes = Get-CimInstance Win32_Process
$deviceId = $null
$packageName = $null
$terminalHandle = $null

function Send-OrcaTerminalInput {
    param(
        [Parameter(Mandatory = $true)][string]$TerminalTitle,
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$TerminalHandle
    )

    $orcaCommand = Get-Command orca -ErrorAction SilentlyContinue
    if (-not $orcaCommand) {
        return $false
    }

    try {
        $listText = (& $orcaCommand.Source terminal list --worktree active --json 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($listText)) {
            return $false
        }
        $listResult = $listText | ConvertFrom-Json
        $terminal = $null
        $terminalMarker = if ($TerminalTitle -eq '安卓热重载') {
            'Starting Flutter in Android debug mode|Launching lib[\\/]main\.dart on .*Android|I/flutter\s+\(\s*\d+\)|EGL_emulation'
        }
        else {
            'Starting Flutter in Windows debug mode|Launching lib[\\/]main\.dart on .*Windows'
        }
        $candidates = @($listResult.result.terminals) |
            Where-Object { $_.connected -and $_.writable } |
            Sort-Object `
                @{ Expression = { if ($TerminalHandle -and $_.handle -eq $TerminalHandle) { 0 } else { 1 } } },
                @{ Expression = 'lastOutputAt'; Descending = $true }
        foreach ($candidate in $candidates) {
            $titleMatches = $candidate.title -like "*$TerminalTitle*"
            if (-not $titleMatches -and $candidate.title -match '(?i)(Pi|Codex|Claude|Gemini|Grok|OMP)$') {
                continue
            }

            $readText = (& $orcaCommand.Source terminal read `
                --terminal $candidate.handle `
                --limit 1000 `
                --json 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($readText)) {
                continue
            }
            $readResult = $readText | ConvertFrom-Json
            if ($readResult.result.terminal.status -ne 'running') {
                continue
            }
            $lines = @($readResult.result.terminal.tail)
            if (
                ($TerminalHandle -and $candidate.handle -eq $TerminalHandle) -or
                $titleMatches -or
                ($lines -join "`n") -match $terminalMarker
            ) {
                $terminal = $candidate
                break
            }
        }
        if (-not $terminal) {
            return $false
        }

        $sendText = (& $orcaCommand.Source terminal send `
            --terminal $terminal.handle `
            --text $Text `
            --json 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "Could not send input to Orca terminal '$($terminal.title)': $sendText"
        }
        return $true
    }
    catch {
        throw
    }
}

if ($Target -eq 'Android') {
    $sessionPath = Join-Path $repoRoot 'tool/.tmp/android_hot_reload_session.json'
    if (-not (Test-Path -LiteralPath $sessionPath -PathType Leaf)) {
        throw 'Android hot-reload session not found. Load the aaalice-dev-sessions skill first.'
    }

    $metadata = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $session = $processes |
        Where-Object { [int]$_.ProcessId -eq [int]$metadata.processId } |
        Select-Object -First 1
    $deviceId = [string]$metadata.deviceId
    $packageName = [string]$metadata.packageName
    $terminalHandle = [string]$metadata.terminalHandle
    if (-not $session -or $session.CommandLine -notlike '*aaalice-dev-sessions*android_runner.ps1*') {
        throw 'The recorded Android hot-reload console is no longer running. Start a new session.'
    }
}
else {
    $sessionPath = Join-Path $repoRoot 'tool/.tmp/windows_hot_reload_session.json'
    if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
        $metadata = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $session = $processes |
            Where-Object { [int]$_.ProcessId -eq [int]$metadata.processId } |
            Select-Object -First 1
        $terminalHandle = [string]$metadata.terminalHandle
    }
    else {
        $session = $processes |
            Where-Object {
                $_.Name -eq 'pwsh.exe' -and
                $_.CommandLine -like '*aaalice-dev-sessions*windows_runner.ps1*'
            } |
            Sort-Object CreationDate -Descending |
            Select-Object -First 1
    }
    if (-not $session -or $session.CommandLine -notlike '*aaalice-dev-sessions*windows_runner.ps1*') {
        throw 'Windows hot-reload session not found. Load the aaalice-dev-sessions skill first.'
    }
}

$descendantIds = [System.Collections.Generic.HashSet[int]]::new()
[void]$descendantIds.Add([int]$session.ProcessId)
do {
    $added = $false
    foreach ($process in $processes) {
        if (
            $descendantIds.Contains([int]$process.ParentProcessId) -and
            -not $descendantIds.Contains([int]$process.ProcessId)
        ) {
            [void]$descendantIds.Add([int]$process.ProcessId)
            $added = $true
        }
    }
} while ($added)

$flutterRun = $processes | Where-Object {
    if (-not $descendantIds.Contains([int]$_.ProcessId)) {
        return $false
    }
    if ($_.CommandLine -notlike '*flutter_tools.snapshot*run*') {
        return $false
    }
    if ($Target -eq 'Android') {
        return $_.CommandLine -like "* -d $deviceId*"
    }
    return $_.CommandLine -like '*run -d windows*'
} | Select-Object -First 1

if (-not $flutterRun) {
    throw "The $Target hot-reload console exists, but flutter run is not ready yet."
}

if ($Target -eq 'Windows') {
    $app = $processes | Where-Object {
        $descendantIds.Contains([int]$_.ProcessId) -and
        $_.Name -eq 'nai_launcher.exe'
    } | Select-Object -First 1
    if (-not $app) {
        throw 'The hot-reload console exists, but Flutter Windows is not ready yet.'
    }
}
else {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    $adbPath = if ($adbCommand) { $adbCommand.Source } else { $null }
    if (-not $adbPath) {
        foreach ($sdkRoot in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)) {
            if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
                continue
            }
            $candidate = Join-Path $sdkRoot 'platform-tools/adb.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $adbPath = $candidate
                break
            }
        }
    }
    if (-not $adbPath) {
        throw 'adb command not found. Add Android SDK platform-tools to PATH.'
    }

    $appProcessId = (& $adbPath -s $deviceId shell pidof $packageName | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($appProcessId)) {
        throw "Flutter Android is not ready on '$deviceId' yet."
    }
}

$command = if ($Restart) { 'R' } else { 'r' }
$terminalTitle = if ($Target -eq 'Android') { '安卓热重载' } else { 'PC热重载' }
if (Send-OrcaTerminalInput `
    -TerminalTitle $terminalTitle `
    -Text $command `
    -TerminalHandle $terminalHandle) {
    $action = if ($Restart) { 'Hot restart' } else { 'Hot reload' }
    Write-Output "$action requested through Orca terminal '$terminalTitle'."
    return
}

if (-not ('ConsoleInput.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace ConsoleInput
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct KeyEventRecord
    {
        [MarshalAs(UnmanagedType.Bool)] public bool KeyDown;
        public ushort RepeatCount;
        public ushort VirtualKeyCode;
        public ushort VirtualScanCode;
        public char UnicodeChar;
        public uint ControlKeyState;
    }

    [StructLayout(LayoutKind.Explicit, CharSet = CharSet.Unicode)]
    public struct InputRecord
    {
        [FieldOffset(0)] public ushort EventType;
        [FieldOffset(4)] public KeyEventRecord KeyEvent;
    }

    public static class NativeMethods
    {
        private const ushort KeyEvent = 0x0001;
        private const uint GenericRead = 0x80000000;
        private const uint GenericWrite = 0x40000000;
        private const uint ShareRead = 0x00000001;
        private const uint ShareWrite = 0x00000002;
        private const uint OpenExisting = 3;

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool FreeConsole();

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AttachConsole(uint processId);

        [DllImport("kernel32.dll", EntryPoint = "CreateFileW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateFile(
            string fileName,
            uint desiredAccess,
            uint shareMode,
            IntPtr securityAttributes,
            uint creationDisposition,
            uint flagsAndAttributes,
            IntPtr templateFile
        );

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);

        [DllImport("kernel32.dll", EntryPoint = "WriteConsoleInputW", SetLastError = true)]
        private static extern bool WriteConsoleInput(
            IntPtr input,
            InputRecord[] buffer,
            uint length,
            out uint written
        );

        public static void Send(uint processId, char character)
        {
            FreeConsole();
            if (!AttachConsole(processId))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not attach to the Flutter console");
            }

            try
            {
                IntPtr input = CreateFile(
                    "CONIN$",
                    GenericRead | GenericWrite,
                    ShareRead | ShareWrite,
                    IntPtr.Zero,
                    OpenExisting,
                    0,
                    IntPtr.Zero
                );
                if (input == new IntPtr(-1))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not open Flutter console input");
                }

                try
                {
                    ushort virtualKey = (ushort)Char.ToUpperInvariant(character);
                    InputRecord[] records = new InputRecord[]
                    {
                        new InputRecord
                        {
                            EventType = KeyEvent,
                            KeyEvent = new KeyEventRecord
                            {
                                KeyDown = true,
                                RepeatCount = 1,
                                VirtualKeyCode = virtualKey,
                                UnicodeChar = character
                            }
                        },
                        new InputRecord
                        {
                            EventType = KeyEvent,
                            KeyEvent = new KeyEventRecord
                            {
                                KeyDown = false,
                                RepeatCount = 1,
                                VirtualKeyCode = virtualKey,
                                UnicodeChar = character
                            }
                        }
                    };

                    if (!WriteConsoleInput(input, records, (uint)records.Length, out uint written) || written != records.Length)
                    {
                        throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not send the Flutter reload command");
                    }
                }
                finally
                {
                    CloseHandle(input);
                }
            }
            finally
            {
                FreeConsole();
            }
        }
    }
}
'@
}

[ConsoleInput.NativeMethods]::Send([uint32]$session.ProcessId, $command)
$action = if ($Restart) { 'Hot restart' } else { 'Hot reload' }
Write-Output "$action requested for Flutter $Target session $($session.ProcessId)."
