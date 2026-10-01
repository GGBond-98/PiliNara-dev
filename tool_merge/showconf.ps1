# Dump only the conflicted regions of a file, compactly.
# Usage: showconf.ps1 <path> [maxLinesPerSide]
param(
  [Parameter(Mandatory=$true)][string]$Path,
  [int]$Max = 0
)
if(-not (Test-Path -LiteralPath $Path)){ Write-Output "MISSING: $Path"; exit 1 }
$c = Get-Content -LiteralPath $Path -Encoding utf8
$state = 0  # 0=ctx 1=ours 2=theirs
$bufO=@(); $bufT=@(); $start=0; $hunk=0
for($i=0;$i -lt $c.Count;$i++){
  $l = $c[$i]
  if($l -like '<<<<<<<*'){ $state=1; $start=$i+1; $hunk++; $bufO=@(); $bufT=@(); continue }
  if($l -like '|||||||*'){ $state=1; continue }
  if($l -like '=======*' -and $state -eq 1){ $state=2; continue }
  if($l -like '>>>>>>>*'){
    Write-Output "----- HUNK #$hunk  (lines $start-$($i+1)) -----"
    Write-Output "== OURS (HEAD/pilinara) =="
    if($Max -gt 0){ $bufO | Select-Object -First $Max } else { $bufO }
    Write-Output "== THEIRS (ohos) =="
    if($Max -gt 0){ $bufT | Select-Object -First $Max } else { $bufT }
    $state=0; continue
  }
  if($state -eq 1){ $bufO += $l }
  elseif($state -eq 2){ $bufT += $l }
}
if($hunk -eq 0){ Write-Output "(no conflict markers)" }
