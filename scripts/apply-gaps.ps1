$ErrorActionPreference = 'Stop'
$detailDir = 'c:\hl-mods\workspace\detailed-textures\maps'
$mapsDir   = 'c:\hl-mods\workspace\maps'

function Parse-DetailFile($path) {
    $h = [ordered]@{}
    foreach ($line in Get-Content -LiteralPath $path) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('//')) { continue }
        $parts = $t -split '\s+'
        if ($parts.Count -ge 2) { $h[$parts[0].ToLower()] = $parts[1] }
    }
    return $h
}

function Get-MapTextures($mapPath) {
    $set = New-Object System.Collections.Generic.HashSet[string]
    $skip = @('null','origin','aaatrigger','contentwater','clip','hint','skip','bevel')
    foreach ($line in Get-Content -LiteralPath $mapPath) {
        if (-not $line.StartsWith('( ')) { continue }
        $closes = 0; $idx = 0
        for ($i = 0; $i -lt $line.Length; $i++) {
            if ($line[$i] -eq ')') { $closes++; if ($closes -eq 3) { $idx = $i + 1; break } }
        }
        if ($closes -eq 3) {
            $rest = $line.Substring($idx).Trim()
            $tex = ($rest -split '\s+')[0]
            if ($tex) { $tl = $tex.ToLower(); if ($skip -notcontains $tl) { [void]$set.Add($tl) } }
        }
    }
    return $set
}

# Build global mapping
$global = @{}
$mapDetails = @{}
$mapFiles = @{}
foreach ($f in Get-ChildItem $detailDir -Filter '*_detail.txt') {
    $name = $f.BaseName -replace '_detail$',''
    $h = Parse-DetailFile $f.FullName
    $mapDetails[$name] = $h
    $mapFiles[$name] = $f.FullName
    foreach ($k in $h.Keys) {
        if (-not $global.ContainsKey($k)) { $global[$k] = @{} }
        $v = $h[$k]
        if (-not $global[$k].ContainsKey($v)) { $global[$k][$v] = 0 }
        $global[$k][$v]++
    }
}

$totalAdded = 0
$summary = @()

foreach ($name in ($mapDetails.Keys | Sort-Object)) {
    $mapFile = Join-Path $mapsDir "$name\$name.map"
    if (-not (Test-Path $mapFile)) { continue }
    $textures = Get-MapTextures $mapFile
    $defined  = $mapDetails[$name]

    $additions = New-Object System.Collections.Generic.List[object]
    foreach ($t in ($textures | Sort-Object)) {
        if ($defined.Contains($t)) { continue }
        if (-not $global.ContainsKey($t)) { continue }
        if ($global[$t].Count -ne 1) { continue }   # Variants==1 (unanimous)
        $entry = $global[$t].GetEnumerator() | Select-Object -First 1
        $detail = $entry.Key
        $freq   = $entry.Value
        if ($freq -lt 3) { continue }                 # Frequency>=3
        if ($detail -ieq 'detail/dt_metal1') { continue }  # exclude generic filler
        $additions.Add([pscustomobject]@{ Tex = $t; Detail = $detail; Freq = $freq }) | Out-Null
    }

    if ($additions.Count -eq 0) { continue }

    # Build new lines
    $newLines = foreach ($a in $additions) {
        # Format: tex<tabs>detail<tabs>1.0<tab>1.0   - use tabs to match style; pick width 24 for tex
        $texCol = $a.Tex.PadRight(24)
        $detCol = $a.Detail.PadRight(28)
        "$texCol$detCol 1.0			1.0"
    }

    $path = $mapFiles[$name]
    $content = Get-Content -LiteralPath $path -Raw
    # Detect line ending
    $nl = if ($content -match "`r`n") { "`r`n" } else { "`n" }

    $marker = '// End detail texture file.'
    if ($content.Contains($marker)) {
        $insertBlock = "// Auto-filled high-confidence mappings$nl" + ($newLines -join $nl) + "$nl$nl"
        $newContent = $content -replace [regex]::Escape($marker), ($insertBlock + $marker)
    } else {
        # Trim trailing whitespace and append
        $newContent = $content.TrimEnd() + $nl + $nl + "// Auto-filled high-confidence mappings$nl" + ($newLines -join $nl) + $nl
    }

    Set-Content -LiteralPath $path -Value $newContent -NoNewline -Encoding UTF8
    $totalAdded += $additions.Count
    $summary += [pscustomobject]@{ Map = $name; Added = $additions.Count }
}

$summary | Sort-Object Added -Descending | Format-Table -AutoSize | Out-String -Width 160
"Total entries added: $totalAdded"
