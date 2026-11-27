param(
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$isMac = $IsMacOS -eq $true
$binaryName = if ($isMac) { 'nai_launcher_mcp' } else { 'nai_launcher_mcp.exe' }

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = if ($isMac) {
    'build/macos/Build/Products/Release/Aaalice NAI Launcher.app/Contents/MacOS/nai_launcher_mcp'
  } else {
    'build/windows/x64/runner/Release/nai_launcher_mcp.exe'
  }
}
if (-not [IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath = Join-Path $root $OutputPath
}

$stagingPath = Join-Path $root 'tool/.tmp/mcp_cli'
$isWindowsHost = $env:OS -eq 'Windows_NT'

function Find-RealVswhere {
  $command = Get-Command 'vswhere.exe' -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($command) {
    return $command.Source
  }

  $candidates = @()
  if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
    $candidates += Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  }
  if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
    $candidates += Join-Path $env:ProgramFiles 'Microsoft Visual Studio\Installer\vswhere.exe'
  }
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }

  return $null
}

function Test-VswhereJsonContainsNonAscii {
  param(
    [Parameter(Mandatory = $true)]
    [string]$VswherePath
  )

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $VswherePath
  $psi.Arguments = '-format json -utf8 -latest -products *'
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
  $psi.StandardErrorEncoding = New-Object System.Text.UTF8Encoding($false)
  $psi.CreateNoWindow = $true

  $process = [System.Diagnostics.Process]::Start($psi)
  try {
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $stdout = $process.StandardOutput.ReadToEnd()
    [void]$stderrTask.GetAwaiter().GetResult()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
      return $false
    }
    return $stdout -match '[^\x00-\x7F]'
  } finally {
    $process.Dispose()
  }
}

function New-AsciiVswhereShim {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ShimDirectory,
    [Parameter(Mandatory = $true)]
    [string]$RealVswhere
  )

  $csc = $null
  if (-not [string]::IsNullOrWhiteSpace($env:WINDIR)) {
    foreach ($relativeCsc in @(
      'Microsoft.NET\Framework64\v4.0.30319\csc.exe',
      'Microsoft.NET\Framework\v4.0.30319\csc.exe'
    )) {
      $candidate = Join-Path $env:WINDIR $relativeCsc
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $csc = $candidate
        break
      }
    }
  }
  if (-not $csc) {
    return $null
  }

  New-Item -ItemType Directory -Force -Path $ShimDirectory | Out-Null
  $sourcePath = Join-Path $ShimDirectory 'vswhere_shim.cs'
  $exePath = Join-Path $ShimDirectory 'vswhere.exe'
  $realVswhereB64 = [Convert]::ToBase64String(
    [System.Text.Encoding]::UTF8.GetBytes($RealVswhere)
  )
  $csharpTemplate = @'
using System;
using System.Diagnostics;
using System.Text;
using System.Threading;

internal static class Program
{
    private static readonly string RealVswhere =
        Encoding.UTF8.GetString(Convert.FromBase64String("@REAL_VSWHERE_B64@"));

    private static string QuoteArg(string arg)
    {
        if (arg.Length == 0)
        {
            return "\"\"";
        }

        bool needsQuotes = false;
        foreach (char c in arg)
        {
            if (char.IsWhiteSpace(c) || c == '"')
            {
                needsQuotes = true;
                break;
            }
        }
        if (!needsQuotes)
        {
            return arg;
        }

        var sb = new StringBuilder();
        sb.Append('"');
        int backslashes = 0;
        foreach (char c in arg)
        {
            if (c == '\\')
            {
                backslashes++;
            }
            else if (c == '"')
            {
                sb.Append('\\', backslashes * 2 + 1);
                sb.Append('"');
                backslashes = 0;
            }
            else
            {
                if (backslashes > 0)
                {
                    sb.Append('\\', backslashes);
                    backslashes = 0;
                }
                sb.Append(c);
            }
        }
        if (backslashes > 0)
        {
            sb.Append('\\', backslashes * 2);
        }
        sb.Append('"');
        return sb.ToString();
    }

    private static string EscapeNonAscii(string input)
    {
        var sb = new StringBuilder(input.Length + 64);
        foreach (char c in input)
        {
            if (c <= 127)
            {
                sb.Append(c);
            }
            else
            {
                sb.Append("\\u");
                sb.Append(((int)c).ToString("x4"));
            }
        }
        return sb.ToString();
    }

    private static int Main(string[] args)
    {
        bool useUtf8 = false;
        bool jsonFormat = false;
        for (int i = 0; i < args.Length; i++)
        {
            if (string.Equals(args[i], "-utf8", StringComparison.OrdinalIgnoreCase))
            {
                useUtf8 = true;
            }
            if (string.Equals(args[i], "-format", StringComparison.OrdinalIgnoreCase) &&
                i + 1 < args.Length &&
                string.Equals(args[i + 1], "json", StringComparison.OrdinalIgnoreCase))
            {
                jsonFormat = true;
            }
        }

        var quotedArgs = new string[args.Length];
        for (int i = 0; i < args.Length; i++)
        {
            quotedArgs[i] = QuoteArg(args[i]);
        }

        var enc = useUtf8 ? (Encoding)new UTF8Encoding(false) : Encoding.Default;
        var psi = new ProcessStartInfo
        {
            FileName = RealVswhere,
            Arguments = string.Join(" ", quotedArgs),
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = enc,
            StandardErrorEncoding = enc,
            CreateNoWindow = true,
        };

        using (var proc = Process.Start(psi))
        {
            string stderrText = string.Empty;
            var errThread = new Thread(() =>
            {
                stderrText = proc.StandardError.ReadToEnd();
            });
            errThread.Start();

            string stdoutText = proc.StandardOutput.ReadToEnd();
            errThread.Join();
            proc.WaitForExit();

            if (jsonFormat && stdoutText.Length > 0)
            {
                stdoutText = EscapeNonAscii(stdoutText);
            }

            if (stdoutText.Length > 0)
            {
                Console.Out.Write(stdoutText);
            }
            if (stderrText.Length > 0)
            {
                Console.Error.Write(stderrText);
            }

            return proc.ExitCode;
        }
    }
}
'@
  $csharpSource = $csharpTemplate.Replace('@REAL_VSWHERE_B64@', $realVswhereB64)

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($sourcePath, $csharpSource, $utf8NoBom)
  $compileOutput = @(& $csc /nologo /optimize+ "/out:$exePath" $sourcePath 2>&1)
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
    throw "Failed to compile ASCII vswhere shim: $($compileOutput -join [Environment]::NewLine)"
  }
  return $exePath
}

$originalPath = $env:Path
$shimDir = $null

Push-Location $root
try {
  if (Test-Path -LiteralPath $stagingPath) {
    Remove-Item -LiteralPath $stagingPath -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $stagingPath | Out-Null

  # native_toolchain_c parses `vswhere -utf8` using the Windows ANSI code page,
  # which fails on localized VS installations (e.g. zh-CN under CP936).
  # Compile outside the repo root so low-integrity workspace ACLs don't block .NET startup.
  if ($isWindowsHost) {
    $realVswhere = Find-RealVswhere
    if ($realVswhere -and (Test-VswhereJsonContainsNonAscii -VswherePath $realVswhere)) {
      $candidateShimDir = Join-Path ([IO.Path]::GetTempPath()) "aaalice_mcp_cli_vswhere_$PID"
      $shimExe = New-AsciiVswhereShim -ShimDirectory $candidateShimDir -RealVswhere $realVswhere
      if ($shimExe) {
        $shimDir = $candidateShimDir
        $env:Path = "$shimDir;$originalPath"
      }
    }
  }

  # dart compile exe refuses packages whose dependency graph declares build
  # hooks, so the proxy is produced with the bundle builder and lifted out.
  $global:LASTEXITCODE = 0
  dart build cli --target bin/nai_launcher_mcp.dart --output $stagingPath
  if ($LASTEXITCODE -ne 0) {
    throw "dart build cli failed with exit code $LASTEXITCODE"
  }

  $builtBinary = Join-Path $stagingPath "bundle/bin/$binaryName"
  if (-not (Test-Path -LiteralPath $builtBinary -PathType Leaf)) {
    throw "dart build cli did not produce the MCP CLI executable: $builtBinary"
  }

  $outputDirectory = Split-Path -Parent $OutputPath
  if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
  }
  Copy-Item -LiteralPath $builtBinary -Destination $OutputPath -Force
  if ($isMac) {
    chmod +x $OutputPath
  }

  $outputFile = Get-Item -LiteralPath $OutputPath
  if ($outputFile.Length -le 0) {
    throw "MCP CLI executable is empty: $OutputPath"
  }

  Remove-Item -LiteralPath $stagingPath -Recurse -Force
  $sizeMb = [math]::Round($outputFile.Length / 1MB, 1)
  Write-Host "Built MCP stdio proxy: $OutputPath ($sizeMb MB)"
} finally {
  $env:Path = $originalPath
  if ($shimDir -and (Test-Path -LiteralPath $shimDir)) {
    Remove-Item -LiteralPath $shimDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  Pop-Location
}
