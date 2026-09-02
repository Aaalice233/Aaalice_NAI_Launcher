param(
    [string]$Pattern,
    [ValidateRange(1, 10000)]
    [int]$Last = 200,
    [ValidateRange(0, 100)]
    [int]$Context = 2,
    [ValidateSet('Windows', 'Android')]
    [string]$Target = 'Windows'
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'Development console capture currently requires Windows.'
}

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '../../../..')
$sessionFile = if ($Target -eq 'Windows') {
    'windows_hot_reload_session.json'
}
else {
    'android_hot_reload_session.json'
}
$runnerName = if ($Target -eq 'Windows') { 'windows_runner.ps1' } else { 'android_runner.ps1' }
$runnerPath = Join-Path $repoRoot ".agents/skills/aaalice-dev-sessions/scripts/$runnerName"
$sessionPath = Join-Path $repoRoot "tool/.tmp/$sessionFile"
$processes = @(Get-CimInstance Win32_Process)
$metadata = $null
$session = $null
if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
    $metadata = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $session = $processes |
        Where-Object { [int]$_.ProcessId -eq [int]$metadata.processId } |
        Select-Object -First 1
}
if (-not $session) {
    $session = $processes |
        Where-Object {
            $_.Name -eq 'pwsh.exe' -and
            -not [string]::IsNullOrWhiteSpace($_.CommandLine) -and
            $_.CommandLine.Contains([string]$runnerPath, [StringComparison]::OrdinalIgnoreCase)
        } |
        Sort-Object CreationDate -Descending |
        Select-Object -First 1
    $metadata = $null
}
if (-not $session -or $session.Name -ne 'pwsh.exe') {
    throw "$Target development console not found. Load the aaalice-dev-sessions skill first."
}

if ($metadata) {
    if (
        [string]$metadata.repoRoot -ne [string]$repoRoot -or
        -not $session.CommandLine.Contains([string]$runnerPath, [StringComparison]::OrdinalIgnoreCase)
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
}

if (-not ('AaaliceConsole.Reader' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace AaaliceConsole
{
    public static class Reader
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct Coord
        {
            public short X;
            public short Y;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct SmallRect
        {
            public short Left;
            public short Top;
            public short Right;
            public short Bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct ConsoleScreenBufferInfo
        {
            public Coord Size;
            public Coord CursorPosition;
            public ushort Attributes;
            public SmallRect Window;
            public Coord MaximumWindowSize;
        }

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
        private static extern bool GetConsoleScreenBufferInfo(
            IntPtr output,
            out ConsoleScreenBufferInfo info
        );

        [DllImport("kernel32.dll", EntryPoint = "ReadConsoleOutputCharacterW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool ReadConsoleOutputCharacter(
            IntPtr output,
            StringBuilder buffer,
            uint length,
            Coord readCoordinate,
            out uint read
        );

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);

        public static string Read(uint processId)
        {
            const uint GenericRead = 0x80000000;
            const uint ShareRead = 0x00000001;
            const uint ShareWrite = 0x00000002;
            const uint OpenExisting = 3;

            FreeConsole();
            if (!AttachConsole(processId))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not attach to the Flutter console");
            }

            IntPtr output = CreateFile(
                "CONOUT$",
                GenericRead,
                ShareRead | ShareWrite,
                IntPtr.Zero,
                OpenExisting,
                0,
                IntPtr.Zero
            );
            if (output == new IntPtr(-1))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not open Flutter console output");
            }

            try
            {
                if (!GetConsoleScreenBufferInfo(output, out ConsoleScreenBufferInfo info))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not inspect Flutter console");
                }

                int lineCount = info.CursorPosition.Y + 1;
                int characterCount = info.Size.X * lineCount;
                StringBuilder buffer = new StringBuilder(characterCount);
                Coord origin = new Coord { X = 0, Y = 0 };
                if (!ReadConsoleOutputCharacter(output, buffer, (uint)characterCount, origin, out uint read))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read Flutter console");
                }

                string raw = buffer.ToString(0, (int)read);
                StringBuilder text = new StringBuilder(raw.Length + lineCount);
                for (int offset = 0; offset < raw.Length; offset += info.Size.X)
                {
                    int length = Math.Min(info.Size.X, raw.Length - offset);
                    text.AppendLine(raw.Substring(offset, length).TrimEnd());
                }
                return text.ToString();
            }
            finally
            {
                CloseHandle(output);
                FreeConsole();
            }
        }
    }
}
'@
}

$lines = [AaaliceConsole.Reader]::Read([uint32]$session.ProcessId) -split "`r?`n"
if ([string]::IsNullOrWhiteSpace($Pattern)) {
    $lines | Select-Object -Last $Last
    return
}

$selectedIndexes = [System.Collections.Generic.SortedSet[int]]::new()
for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -notmatch $Pattern) {
        continue
    }

    $start = [Math]::Max(0, $index - $Context)
    $end = [Math]::Min($lines.Count - 1, $index + $Context)
    for ($contextIndex = $start; $contextIndex -le $end; $contextIndex++) {
        [void]$selectedIndexes.Add($contextIndex)
    }
}

@($selectedIndexes | ForEach-Object { $lines[$_] }) | Select-Object -Last $Last
