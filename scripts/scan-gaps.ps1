$ErrorActionPreference = 'Stop'
$detailDir = 'c:\hl-mods\workspace\detailed-textures\maps'
$mapsDir   = 'c:\hl-mods\workspace\maps'

function Parse-DetailFile($path) {
    $h = [ordered]@{}
    foreach ($line in Get-Content -LiteralPath $path) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('//')) { continue }
        $parts = $t -split '\s+'
        if ($parts.Count -ge 2) {
            $h[$parts[0].ToLower()] = $parts[1]
        }
    }
    return $h
}

function Get-MapTextures($mapPath) {
    $set = New-Object System.Collections.Generic.HashSet[string]
    $skip = @('null','origin','aaatrigger','contentwater','clip','sky','hint','skip','bevel')
    # Brush face line: ( x y z ) ( x y z ) ( x y z ) TEXNAME [ ... ] [ ... ] rot sx sy
    $rx = [regex]'\)\s+\)\s+\(\s+[-\d\.eE\s]+\)\s+(\S+)\s+\['
    foreach ($line in Get-Content -LiteralPath $mapPath) {
        if ($line.StartsWith('( ')) {
            # Format: ( a b c ) ( d e f ) ( g h i ) TEX [ ...
            $idx = 0
            $depth = 0
            $closes = 0
            for ($i = 0; $i -lt $line.Length; $i++) {
                if ($line[$i] -eq ')') {
                    $closes++
                    if ($closes -eq 3) { $idx = $i + 1; break }
                }
            }
            if ($closes -eq 3) {
                $rest = $line.Substring($idx).Trim()
                $tex = ($rest -split '\s+')[0]
                if ($tex) {
                    $tl = $tex.ToLower()
                    if ($skip -notcontains $tl) {
                        [void]$set.Add($tl)
                    }
                }
            }
        }
    }
    return $set
}

# Build global mapping: tex_lower -> @{ detail -> count }
$global = @{}
$mapDetails = @{}
foreach ($f in Get-ChildItem $detailDir -Filter '*_detail.txt') {
    $name = $f.BaseName -replace '_detail$',''
    $h = Parse-DetailFile $f.FullName
    $mapDetails[$name] = $h
    foreach ($k in $h.Keys) {
        if (-not $global.ContainsKey($k)) { $global[$k] = @{} }
        $v = $h[$k]
        if (-not $global[$k].ContainsKey($v)) { $global[$k][$v] = 0 }
        $global[$k][$v]++
    }
}

# For each map, find gaps
$report = @()
foreach ($name in ($mapDetails.Keys | Sort-Object)) {
    $mapFile = Join-Path $mapsDir "$name\$name.map"
    if (-not (Test-Path $mapFile)) { continue }
    $textures = Get-MapTextures $mapFile
    $defined  = $mapDetails[$name]
    foreach ($t in ($textures | Sort-Object)) {
        if ($defined.Contains($t)) { continue }
        if ($global.ContainsKey($t)) {
            # pick most common detail mapping
            $best = $global[$t].GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
            $report += [pscustomobject]@{
                Map       = $name
                Texture   = $t
                Detail    = $best.Key
                Frequency = $best.Value
                Variants  = $global[$t].Count
            }
        }
    }
}

$report | Format-Table -AutoSize | Out-String -Width 200
"`nTotal gaps: $($report.Count)"
$report | Group-Object Map | Sort-Object Count -Descending | Select-Object Count,Name | Format-Table -AutoSize | Out-String -Width 200
