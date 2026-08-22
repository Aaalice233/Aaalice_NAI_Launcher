param(
    [string]$Pattern,
    [ValidateRange(1, 10000)]
    [int]$Last = 200,
    [ValidateRange(0, 100)]
    [int]$Context = 2
)

$ErrorActionPreference = 'Stop'

$session = Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq 'pwsh.exe' -and
        $_.CommandLine -like '*scripts*dev_hot_reload.ps1*'
    } |
    Sort-Object CreationDate -Descending |
    Select-Object -First 1

if (-not $session) {
    throw 'Flutter development console not found. Start it with scripts/dev_hot_reload_window.ps1 first.'
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
