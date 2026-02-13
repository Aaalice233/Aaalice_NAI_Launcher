$f = 'lib\presentation\providers\image_generation_provider.dart'
$lines = Get-Content $f
$kept = $lines[0..38] + @('') + $lines[175..1100]
Set-Content -Path $f -Value $kept -Encoding UTF8
Write-Host "Done. Kept $($kept.Count) lines."
