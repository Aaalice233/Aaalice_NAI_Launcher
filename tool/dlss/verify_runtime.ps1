<#
.SYNOPSIS
诊断第三方 video2dlssnr CLI 的静态图像参数；不验证应用的原生 FP16 多层管线，见 docs/dlss_processing.md。
.DESCRIPTION
仅运行 --nr-run，不调用包含驱动内存补丁的 --probe-nr。不会下载、安装或
重新分发运行库，也不会更改驱动。结果与日志写入 tool/.tmp/ 下的新目录。
签名和像素差异只作为验证证据，不能替代运行库授权或人工图像验收。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RuntimeDirectory,
    [Parameter(Mandatory)][string]$InputImage,
    [int]$Adapter = 0,
    [ValidateRange(1, 60)][int]$TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $IsWindows) { throw '此验证仅支持 Windows。' }

$runtime = (Resolve-Path -LiteralPath $RuntimeDirectory).Path
$source = (Resolve-Path -LiteralPath $InputImage).Path
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$outputRoot = Join-Path $projectRoot ('tool/.tmp/dlss-verify-' + [guid]::NewGuid().ToString('N'))
$required = @('video2dlssnr.exe', 'nvngx.dll_dlssnr.dll', 'nvngx_dlss.dll', 'nvngx_dlssnr.dll')
foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $runtime $name) -PathType Leaf)) {
        throw "缺少运行文件：$name"
    }
}
New-Item -ItemType Directory -Path $outputRoot | Out-Null
Write-Host "证据目录：$outputRoot"

Add-Type -AssemblyName System.Drawing
if (-not ('DlssPixelEvidence' -as [type])) {
    $drawingReferences = @(
        [Drawing.Bitmap].Assembly.Location,
        [Drawing.Rectangle].Assembly.Location,
        [Runtime.InteropServices.Marshal].Assembly.Location
    )
    # .NET 10 将 GDI+ 类型拆到独立程序集；较早的 PowerShell 不需要这些引用。
    foreach ($assembly in @('System.Private.Windows.GdiPlus.dll', 'System.Private.Windows.Core.dll')) {
        $assemblyPath = Join-Path $PSHOME $assembly
        if (Test-Path -LiteralPath $assemblyPath) { $drawingReferences += $assemblyPath }
    }
    Add-Type -ReferencedAssemblies $drawingReferences -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class DlssPixelEvidence {
    private static byte[] Pixels(Bitmap bitmap) {
        using (var normalized = new Bitmap(bitmap.Width, bitmap.Height, PixelFormat.Format32bppArgb)) {
            using (var graphics = Graphics.FromImage(normalized)) {
                graphics.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
                graphics.DrawImageUnscaled(bitmap, 0, 0);
            }
            var data = normalized.LockBits(new Rectangle(0, 0, bitmap.Width, bitmap.Height),
                ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try {
                var pixels = new byte[checked(bitmap.Width * bitmap.Height * 4)];
                for (int y = 0; y < bitmap.Height; y++) {
                    Marshal.Copy(IntPtr.Add(data.Scan0, y * data.Stride), pixels,
                        y * bitmap.Width * 4, bitmap.Width * 4);
                }
                return pixels;
            } finally { normalized.UnlockBits(data); }
        }
    }

    public static double[] Compare(string source, string output) {
        using (var first = new Bitmap(source))
        using (var second = new Bitmap(output)) {
            if (first.Width != second.Width || first.Height != second.Height)
                throw new InvalidOperationException("NR 输出改变了图像尺寸。");
            var a = Pixels(first);
            var b = Pixels(second);
            long changed = 0, alphaChanged = 0, visible = 0, sum = 0;
            for (int i = 0; i < a.Length; i += 4) {
                if (a[i + 3] != b[i + 3]) alphaChanged++;
                // 完全透明区域的 RGB 不构成用户可见的模型效果。
                if (a[i + 3] == 0) continue;
                visible++;
                int delta = Math.Abs(a[i] - b[i]) + Math.Abs(a[i + 1] - b[i + 1])
                    + Math.Abs(a[i + 2] - b[i + 2]);
                if (delta != 0) changed++;
                sum += delta;
            }
            return new double[] { first.Width, first.Height, visible, changed,
                visible == 0 ? 0 : (double)sum / (visible * 3), alphaChanged };
        }
    }
}
'@
}

function Get-PixelDifference([string]$Reference, [string]$Candidate) {
    $values = [DlssPixelEvidence]::Compare($Reference, $Candidate)
    return [ordered]@{
        width = [int]$values[0]
        height = [int]$values[1]
        visiblePixels = [long]$values[2]
        changedVisiblePixels = [long]$values[3]
        meanAbsoluteRgbDifference = $values[4]
        changedAlphaPixels = [long]$values[5]
    }
}

$report = [ordered]@{
    createdAtUtc = [DateTime]::UtcNow.ToString('o')
    inputPath = $source
    inputSha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    adapter = $Adapter
    runtime = @()
    cases = @()
    completed = $false
    failure = $null
}
foreach ($name in $required) {
    $file = Get-Item -LiteralPath (Join-Path $runtime $name)
    $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
    $report.runtime += [ordered]@{
        name = $name
        bytes = $file.Length
        version = $file.VersionInfo.FileVersion
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        signatureStatus = $signature.Status.ToString()
    }
}

$cases = @(
    @{ name = 'default'; options = @() },
    @{ name = 'natural'; options = @('--nr-style', '1') },
    @{ name = 'cinematic'; options = @('--nr-style', '2') },
    @{ name = 'intensity-half'; options = @('--nr-intensity', '0.5') },
    @{ name = 'local-tone-zero'; options = @('--nr-local-tone', '0') },
    @{ name = 'local-structure-zero'; options = @('--nr-local-structure', '0') },
    @{ name = 'skin-zero'; options = @('--nr-skin', '0') },
    @{ name = 'global-tone-zero'; options = @('--nr-global-tone', '0') }
)
$baseline = $null
try {
    foreach ($case in $cases) {
        $caseDirectory = Join-Path $outputRoot $case.name
        New-Item -ItemType Directory -Path $caseDirectory | Out-Null
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = Join-Path $runtime 'video2dlssnr.exe'
        $startInfo.WorkingDirectory = $runtime
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $arguments = @('--nr-run', '--in', $source, '--out', $caseDirectory,
            '--adapter', $Adapter.ToString(), '--verbose') + $case.options
        foreach ($argument in $arguments) { $startInfo.ArgumentList.Add($argument) }
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $process = [Diagnostics.Process]::Start($startInfo)
        try {
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
            if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
            $stdout.Result | Set-Content -LiteralPath (Join-Path $caseDirectory 'stdout.log') -Encoding UTF8
            $stderr.Result | Set-Content -LiteralPath (Join-Path $caseDirectory 'stderr.log') -Encoding UTF8
            if ($timedOut) { throw "测试 $($case.name) 超时，已终止进程树。" }
            if ($process.ExitCode -ne 0) { throw "测试 $($case.name) 退出码 $($process.ExitCode)。" }
            if ($stdout.Result -notmatch 'Neural Rendering done: 1 ok, 0 failed') {
                throw "测试 $($case.name) 没有报告 NR 成功。"
            }
            $outputs = @(Get-ChildItem -LiteralPath $caseDirectory -Filter '*_nr.png' -File)
            if ($outputs.Count -ne 1) { throw "测试 $($case.name) 必须输出且仅输出一张 NR 图片。" }
            $resultPath = $outputs[0].FullName
            $sourceDifference = Get-PixelDifference $source $resultPath
            if ($sourceDifference.changedAlphaPixels -ne 0) { throw "测试 $($case.name) 改变了 Alpha。" }
            if ($sourceDifference.changedVisiblePixels -eq 0) { throw "测试 $($case.name) 仅返回了原图。" }
            if ($null -eq $baseline) { $baseline = $resultPath }
            $report.cases += [ordered]@{
                name = $case.name
                options = $case.options
                elapsedMs = $watch.ElapsedMilliseconds
                output = $resultPath
                sourceDifference = $sourceDifference
                baselineDifference = Get-PixelDifference $baseline $resultPath
                timing = @($stdout.Result -split "`n" | Where-Object { $_ -match 'NR evaluate|NR feature build|init/load-once' })
            }
            Write-Host "$($case.name): NR 输出有效，耗时 $($watch.ElapsedMilliseconds) ms。"
        } finally {
            if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
            $process.Dispose()
            $watch.Stop()
        }
    }
    $report.completed = $true
} catch {
    $report.failure = $_.ToString()
    throw
} finally {
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputRoot 'report.json') -Encoding UTF8
}
