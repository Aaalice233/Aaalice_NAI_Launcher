param(
    [ValidateSet('Reload', 'Restart', 'Quit')]
    [string]$Action = 'Reload',
    [ValidateSet('Windows', 'Android')]
    [string]$Target = 'Windows'
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'Development console input currently requires Windows.'
}

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '../../../..')

function Resolve-AdbCommand {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)
    $localProperties = Join-Path $repoRoot 'android/local.properties'
    if (Test-Path -LiteralPath $localProperties -PathType Leaf) {
        $sdkLine = Get-Content -LiteralPath $localProperties -Encoding UTF8 |
            Where-Object { $_ -like 'sdk.dir=*' } |
            Select-Object -First 1
        if ($sdkLine) {
            $sdkRoots += $sdkLine.Substring('sdk.dir='.Length).Replace('\\', '\').Replace('\:', ':')
        }
    }

    foreach ($sdkRoot in $sdkRoots) {
        if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
            continue
        }
        $candidate = Join-Path $sdkRoot 'platform-tools/adb.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw 'adb command not found. Add Android SDK platform-tools to PATH.'
}

$sessionFile = if ($Target -eq 'Windows') {
    'windows_hot_reload_session.json'
}
else {
    'android_hot_reload_session.json'
}
$sessionPath = Join-Path $repoRoot "tool/.tmp/$sessionFile"
if (-not (Test-Path -LiteralPath $sessionPath -PathType Leaf)) {
    throw "$Target development session not found. Load the aaalice-dev-sessions skill first."
}

$metadata = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
$processes = @(Get-CimInstance Win32_Process)
$session = $processes |
    Where-Object { [int]$_.ProcessId -eq [int]$metadata.processId } |
    Select-Object -First 1
$runnerName = if ($Target -eq 'Windows') { 'windows_runner.ps1' } else { 'android_runner.ps1' }
if (
    -not $session -or
    $session.Name -ne 'pwsh.exe' -or
    $session.CommandLine -notlike "*aaalice-dev-sessions*$runnerName*" -or
    [string]$metadata.repoRoot -ne [string]$repoRoot
) {
    throw "The recorded $Target development console is stale or belongs to another worktree."
}

$process = Get-Process -Id ([int]$session.ProcessId) -ErrorAction Stop
$processStartedAtUnixMs = [DateTimeOffset]::new(
    $process.StartTime.ToUniversalTime()
).ToUnixTimeMilliseconds()
if ([Math]::Abs($processStartedAtUnixMs - [int64]$metadata.processStartedAtUnixMs) -ge 1000) {
    throw "The recorded $Target development console PID has been reused."
}

$descendantIds = [System.Collections.Generic.HashSet[int]]::new()
[void]$descendantIds.Add([int]$session.ProcessId)
do {
    $added = $false
    foreach ($candidate in $processes) {
        if (
            $descendantIds.Contains([int]$candidate.ParentProcessId) -and
            -not $descendantIds.Contains([int]$candidate.ProcessId)
        ) {
            [void]$descendantIds.Add([int]$candidate.ProcessId)
            $added = $true
        }
    }
} while ($added)

$flutterRun = $processes | Where-Object {
    $descendantIds.Contains([int]$_.ProcessId) -and
    $_.CommandLine -like '*flutter_tools.snapshot*run*'
} | Select-Object -First 1
if (-not $flutterRun) {
    throw "The $Target development console exists, but flutter run is not ready."
}

if ($Action -ne 'Quit') {
    if ($Target -eq 'Windows') {
        $app = $processes | Where-Object {
            $descendantIds.Contains([int]$_.ProcessId) -and $_.Name -eq 'nai_launcher.exe'
        } | Select-Object -First 1
        if (-not $app) {
            throw 'Flutter Windows has not started the application process.'
        }
    }
    else {
        $adbCommand = Resolve-AdbCommand
        $appProcessId = (& $adbCommand -s $metadata.deviceId shell pidof $metadata.packageName | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($appProcessId)) {
            throw "Flutter Android is not ready on '$($metadata.deviceId)'."
        }
    }
}

if (-not ('AaaliceConsole.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace AaaliceConsole
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
                        throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not send Flutter console input");
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

$command = switch ($Action) {
    'Restart' { 'R' }
    'Quit' { 'q' }
    default { 'r' }
}
[AaaliceConsole.NativeMethods]::Send([uint32]$session.ProcessId, $command)
Write-Output "$Action requested for Flutter $Target session $($session.ProcessId)."
