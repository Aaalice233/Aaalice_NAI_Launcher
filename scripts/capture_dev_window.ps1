param(
    [string]$OutputPath = 'tool/.tmp/nai_launcher_window.png',
    [switch]$NoActivate,
    [ValidateRange(0, 10000)]
    [int]$DelayMilliseconds = 700
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'This helper captures the Windows desktop development build.'
}

Add-Type -AssemblyName System.Drawing
if (-not ('DevWindowCapture.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace DevWindowCapture
{
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static class NativeMethods
    {
        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr handle, out Rect rect);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindowAsync(IntPtr handle, int command);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr handle);

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool PrintWindow(IntPtr handle, IntPtr deviceContext, uint flags);
    }
}
'@
}

$processInfo = Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq 'nai_launcher.exe' -and
        $_.ExecutablePath -like '*build*windows*runner*Debug*nai_launcher.exe'
    } |
    Sort-Object CreationDate -Descending |
    Select-Object -First 1
if (-not $processInfo) {
    throw 'Debug launcher window not found. Start scripts/dev_hot_reload_window.ps1 first.'
}

$process = Get-Process -Id $processInfo.ProcessId
$handle = $process.MainWindowHandle
if ($handle -eq [IntPtr]::Zero) {
    throw 'The debug launcher process has no visible main window.'
}

$activated = $false
if (-not $NoActivate) {
    # Restoring before activation avoids silently capturing the window behind a
    # minimized launcher. AppActivate is retained as a fallback for Windows'
    # foreground-lock policy.
    [void][DevWindowCapture.NativeMethods]::ShowWindowAsync($handle, 9)
    [void][DevWindowCapture.NativeMethods]::SetForegroundWindow($handle)
    $shell = New-Object -ComObject WScript.Shell
    [void]$shell.AppActivate([int]$process.Id)

    $deadline = [DateTime]::UtcNow.AddSeconds(3)
    do {
        if ([DevWindowCapture.NativeMethods]::GetForegroundWindow() -eq $handle) {
            $activated = $true
            break
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
}

if ($DelayMilliseconds -gt 0) {
    Start-Sleep -Milliseconds $DelayMilliseconds
}

$rect = [DevWindowCapture.Rect]::new()
if (-not [DevWindowCapture.NativeMethods]::GetWindowRect($handle, [ref]$rect)) {
    throw 'Could not read launcher window bounds.'
}
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -le 0 -or $height -le 0) {
    throw "Launcher window has invalid bounds: ${width}x${height}."
}

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$bitmap = [System.Drawing.Bitmap]::new($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
    if ($activated) {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
    } else {
        $deviceContext = $graphics.GetHdc()
        try {
            if (-not [DevWindowCapture.NativeMethods]::PrintWindow($handle, $deviceContext, 2)) {
                throw 'Could not activate or directly render the launcher window.'
            }
        } finally {
            $graphics.ReleaseHdc($deviceContext)
        }
    }
    $bitmap.Save($resolvedOutput, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}

$mode = if ($activated) { 'foreground' } else { 'direct-render fallback' }
Write-Output "Captured launcher window ($mode): $resolvedOutput"
