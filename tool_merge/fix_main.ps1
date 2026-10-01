$ErrorActionPreference = 'Stop'
$f = 'D:\workspace\pilinara-ohos\PiliNara\lib\main.dart'
$lines = [System.IO.File]::ReadAllLines($f)

# split into hunks
$hunks = @()
$cur = $null
foreach ($l in $lines) {
    if ($l -like '<<<<<<<*') { $cur = [pscustomobject]@{ Ours = @(); Theirs = @(); State = 'o'; Start = $true }; continue }
    if ($l -eq '=======') { $cur.State = 't'; continue }
    if ($l -like '>>>>>>>*') { $hunks += $cur; $cur = $null; continue }
    if ($cur) { if ($cur.State -eq 'o') { $cur.Ours += $l } else { $cur.Theirs += $l } }
}
Write-Output "hunks found: $($hunks.Count)"
if ($hunks.Count -ne 4) { throw "expected 4 hunks, got $($hunks.Count)" }

# ---- HUNK 1: ours (Nara..put(DownloadCollectionService());) + theirs minus its first line
$h1 = @()
$h1 += $hunks[0].Ours
$h1 += $hunks[0].Theirs[1..($hunks[0].Theirs.Count - 1)]

# ---- HUNK 2: theirs
$h2 = $hunks[1].Theirs

# ---- HUNK 3: theirs with ours' HyperOS android padding fix injected after textScaler line
$t3 = $hunks[2].Theirs
$o3 = $hunks[2].Ours
$h3 = @()
$injected = $false
foreach ($l in $t3) {
    $h3 += $l
    if (-not $injected -and $l -like '*final textScaler = TextScaler.linear(Pref.defaultTextScale);*') {
        $h3 += ''
        # ours: everything except the first two lines (uiScale / mediaQuery) already present above
        $h3 += $o3[3..($o3.Count - 1)]
        $injected = $true
    }
}
if (-not $injected) { throw 'hunk3 injection failed' }

# ---- HUNK 4: ours
$h4 = $hunks[3].Ours

$repl = @($h1, $h2, $h3, $h4)

# rebuild
$out = New-Object System.Collections.Generic.List[string]
$hi = 0
$state = 0
foreach ($l in $lines) {
    if ($l -like '<<<<<<<*') { $state = 1; foreach ($x in $repl[$hi]) { $out.Add($x) }; continue }
    if ($state -eq 1) { if ($l -eq '=======') { $state = 2 }; continue }
    if ($state -eq 2) { if ($l -like '>>>>>>>*') { $state = 0; $hi++ }; continue }
    $out.Add($l)
}
[System.IO.File]::WriteAllLines($f, $out)
Write-Output "written; markers left: $((Select-String -LiteralPath $f -Pattern '^(<<<<<<<|=======|>>>>>>>)' | Measure-Object).Count)"
