# lost.ps1 -- find lines that BOTH HEAD and ohos agree on but the merge result dropped.
# Such a line is a genuine merge loss (neither side intended to delete it).
param([switch]$All)
$ErrorActionPreference = 'Continue'
Set-Location 'D:\workspace\pilinara-ohos\PiliNara'

function Get-Lines([string]$content) {
  $set = New-Object 'System.Collections.Generic.HashSet[string]'
  if ($content) {
    foreach ($l in ($content -split "`n")) {
      $t = $l.TrimEnd("`r").Trim()
      if ($t.Length -le 6) { continue }                        # skip braces / punctuation / short ids
      if ($t -match '^[\[\]\{\}\(\)\;\,\.\<\>\+\-\*/=&|!:?\s]+$') { continue }
      [void]$set.Add($t)
    }
  }
  return $set
}

# default: every Dart file the merge changed relative to HEAD (the only ones that can have lost lines).
# -All: scan every Dart file in the repo (slow).
$files = if ($All) { @(git ls-files 'lib/*.dart') } else { @(git diff --name-only HEAD -- 'lib/*.dart') }
$totalLost = 0
$report = @()

foreach ($f in $files) {
  $hs = git show "HEAD:$f" 2>$null
  if (-not $hs) { continue }
  $ts = git show "ohosref/ohos:$f" 2>$null
  if (-not $ts) { continue }
  $wtPath = $f -replace '/', '\'
  if (-not (Test-Path -LiteralPath $wtPath)) { continue }

  $H = Get-Lines ($hs -join "`n")
  $T = Get-Lines ($ts -join "`n")
  $W = Get-Lines ([System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $wtPath)))

  $lost = @()
  foreach ($l in $H) { if ($T.Contains($l) -and -not $W.Contains($l)) { $lost += $l } }
  if ($lost.Count -gt 0) {
    $totalLost += $lost.Count
    $report += [pscustomobject]@{ File = $f; Lost = $lost.Count; Samples = $lost }
  }
}

Write-Output "=== files where a line present in BOTH HEAD and ohos is MISSING from the merge result ==="
foreach ($r in ($report | Sort-Object -Property Lost -Descending)) {
  Write-Output ("{0,4}  {1}" -f $r.Lost, $r.File)
  $n = [Math]::Min(3, $r.Samples.Count)
  for ($i = 0; $i -lt $n; $i++) { Write-Output ("        | " + $r.Samples[$i]) }
}
Write-Output ""
Write-Output ("TOTAL lost lines: {0} across {1} files" -f $totalLost, $report.Count)
