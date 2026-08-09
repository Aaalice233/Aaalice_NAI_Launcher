param(
    [switch]$Restart
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'This helper targets the Windows hot-reload session started by dev_hot_reload_window.ps1.'
}

$session = Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq 'pwsh.exe' -and
        $_.CommandLine -like '*scripts*dev_hot_reload.ps1*'
    } |
    Sort-Object CreationDate -Descending |
    Select-Object -First 1

if (-not $session) {
    throw 'Hot-reload session not found. Start it with scripts/dev_hot_reload_window.ps1 first.'
}

$processes = Get-CimInstance Win32_Process
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
    $descendantIds.Contains([int]$_.ProcessId) -and
    $_.CommandLine -like '*flutter_tools.snapshot*run -d windows*'
} | Select-Object -First 1
$app = $processes | Where-Object {
    $descendantIds.Contains([int]$_.ProcessId) -and
    $_.Name -eq 'nai_launcher.exe'
} | Select-Object -First 1

if (-not $flutterRun -or -not $app) {
    throw 'The hot-reload console exists, but Flutter Windows is not ready yet.'
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

$command = if ($Restart) { 'R' } else { 'r' }
[ConsoleInput.NativeMethods]::Send([uint32]$session.ProcessId, $command)
$action = if ($Restart) { 'Hot restart' } else { 'Hot reload' }
Write-Output "$action requested for Flutter session $($session.ProcessId)."
