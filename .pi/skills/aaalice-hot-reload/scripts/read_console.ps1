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

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '../../../..')

if ($Target -eq 'Android') {
    $androidArguments = @{
        Last = $Last
        Context = $Context
    }
    if (-not [string]::IsNullOrWhiteSpace($Pattern)) {
        $androidArguments.Pattern = $Pattern
    }
    & (Join-Path $scriptDir 'read_android_console.ps1') @androidArguments
    exit $LASTEXITCODE
}

$orcaCommand = Get-Command orca -ErrorAction SilentlyContinue
$orcaTerminal = $null
if ($orcaCommand) {
    try {
        $terminalHandle = $null
        $sessionPath = Join-Path $repoRoot 'tool/.tmp/windows_hot_reload_session.json'
        if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
            $metadata = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $terminalHandle = [string]$metadata.terminalHandle
        }

        $listText = (& $orcaCommand.Source terminal list --worktree active --json 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($listText)) {
            $listResult = $listText | ConvertFrom-Json
            $captureLineCount = [Math]::Min(10000, [Math]::Max(1000, $Last * 5))
            $candidates = @($listResult.result.terminals) |
                Where-Object { $_.connected } |
                Sort-Object `
                    @{ Expression = { if ($terminalHandle -and $_.handle -eq $terminalHandle) { 0 } else { 1 } } },
                    @{ Expression = 'lastOutputAt'; Descending = $true }
            foreach ($candidate in $candidates) {
                if (
                    -not ($terminalHandle -and $candidate.handle -eq $terminalHandle) -and
                    $candidate.title -notlike '*PC热重载*' -and
                    $candidate.title -match '(?i)(Pi|Codex|Claude|Gemini|Grok|OMP)$'
                ) {
                    continue
                }

                $readText = (& $orcaCommand.Source terminal read `
                    --terminal $candidate.handle `
                    --limit $captureLineCount `
                    --json 2>$null | Out-String).Trim()
                if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($readText)) {
                    continue
                }
                $readResult = $readText | ConvertFrom-Json
                $orcaLines = @($readResult.result.terminal.tail)
                $isMatch = ($terminalHandle -and $candidate.handle -eq $terminalHandle) -or
                    $candidate.title -like '*PC热重载*' -or
                    ($orcaLines -join "`n") -match 'Starting Flutter in Windows debug mode|Launching lib[\\/]main\.dart on .*Windows'
                if ($isMatch) {
                    $orcaTerminal = $candidate
                    break
                }
            }
        }

        if ($orcaTerminal) {
            if ([string]::IsNullOrWhiteSpace($Pattern)) {
                $orcaLines | Select-Object -Last $Last
                return
            }

            $selectedIndexes = [System.Collections.Generic.SortedSet[int]]::new()
            for ($index = 0; $index -lt $orcaLines.Count; $index++) {
                if ($orcaLines[$index] -notmatch $Pattern) {
                    continue
                }
                $start = [Math]::Max(0, $index - $Context)
                $end = [Math]::Min($orcaLines.Count - 1, $index + $Context)
                for ($contextIndex = $start; $contextIndex -le $end; $contextIndex++) {
                    [void]$selectedIndexes.Add($contextIndex)
                }
            }
            @($selectedIndexes | ForEach-Object { $orcaLines[$_] }) |
                Select-Object -Last $Last
            return
        }
    }
    catch {
        if ($orcaTerminal) {
            throw
        }
        # External console fallback remains available outside Orca.
    }
}

$processes = Get-CimInstance Win32_Process
$session = $processes |
    Where-Object {
        $_.Name -eq 'pwsh.exe' -and
        $_.CommandLine -like '*aaalice-dev-sessions*windows_runner.ps1*'
    } |
    Sort-Object CreationDate -Descending |
    Select-Object -First 1
if (-not $session) {
    throw 'Windows development console not found. Load the aaalice-dev-sessions skill first.'
}

Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace FlutterConsole
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
                throw new Win32Exception(
                    Marshal.GetLastWin32Error(),
                    "Could not attach to Flutter console"
                );
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
                throw new Win32Exception(
                    Marshal.GetLastWin32Error(),
                    "Could not open Flutter console output"
                );
            }

            try
            {
                if (!GetConsoleScreenBufferInfo(output, out ConsoleScreenBufferInfo info))
                {
                    throw new Win32Exception(
                        Marshal.GetLastWin32Error(),
                        "Could not inspect Flutter console"
                    );
                }

                int lineCount = info.CursorPosition.Y + 1;
                int characterCount = info.Size.X * lineCount;
                StringBuilder buffer = new StringBuilder(characterCount);
                Coord origin = new Coord { X = 0, Y = 0 };
                if (!ReadConsoleOutputCharacter(
                    output,
                    buffer,
                    (uint)characterCount,
                    origin,
                    out uint read
                ))
                {
                    throw new Win32Exception(
                        Marshal.GetLastWin32Error(),
                        "Could not read Flutter console"
                    );
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

$lines = [FlutterConsole.Reader]::Read([uint32]$session.ProcessId) -split "`r?`n"

if ([string]::IsNullOrWhiteSpace($Pattern)) {
    $lines | Select-Object -Last $Last
    exit 0
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

@($selectedIndexes | ForEach-Object { $lines[$_] }) |
    Select-Object -Last $Last
