function Git-Hash {
    param (
        $withDate
    )

    $commitHash = "unknown"

    try {
        $commitHash = (git rev-parse HEAD).Substring(0,7)
    } catch {
        Write-Error "git is unavailable"
    }

    if ($withDate) {
        $versionDate = [System.DateTime]::Now.ToString('yyyy-MM-dd.HH:mm:ss') + "-"
    }
    $version = "${versionDate}git-$commitHash"

    return $version
}

function Detailed-Textures-Pack-Release {
    param (
        $rootDir,
        $gameFolder
    )

    Install-Module 7Zip4PowerShell -MinimumVersion 2.2.0 -Scope AllUsers -Force -Verbose

    try {
        $gitHash = $(Git-Hash)
        echo "Creating version: $gitHash`r`n..."
        $zipFile = "${rootDir}\detailed-textures-pack-${gitHash}.7z"
        $detailedTexturesDir = "$rootDir"

        if (Test-Path $env:TEMP\release) {
            Remove-Item $env:TEMP\release -Recurse -Force -ErrorAction Ignore
        }

        [void](New-Item -Force -ItemType Directory $env:TEMP\release)
        [void](New-Item -ItemType directory -Path $env:TEMP\release\redist)
        [void](New-Item -ItemType directory -Path $env:TEMP\release\redist\maps)
        Copy-Item -Recurse -Force $detailedTexturesDir\maps $env:TEMP\release\redist 
        [void](New-Item -ItemType directory -Path $env:TEMP\release\redist\gfx)
        [void](New-Item -ItemType directory -Path $env:TEMP\release\redist\gfx\detail)
        Copy-Item -Recurse -Force $detailedTexturesDir\gfx\detail $env:TEMP\release\redist\gfx
        Copy-Item -Recurse -Force $detailedTexturesDir\detailed_textures_readme.txt $env:TEMP\release\redist

        "`r`nPackage version: $(Git-Hash 1)`r`n" | Add-Content $env:TEMP\release\redist\detailed_textures_readme.txt

        Rename-Item $env:TEMP\release\redist $env:TEMP\release\$gameFolder
        Compress-7Zip -Path $env:TEMP\release\$gameFolder -ArchiveFileName $zipFile
    } catch {
        Throw "Could not create detailed textures pack file.`nReason: $($_.Exception.Message)"
    }
}
