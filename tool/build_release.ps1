[CmdletBinding()]
param(
    [string]$OutputDirectory = 'dist'
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputRoot = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    [IO.Path]::GetFullPath($OutputDirectory)
} else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
}
$stageParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stageRoot = Join-Path $stageParent (
    'pve_manager_build_' + [guid]::NewGuid().ToString('N')
)
if ($stageRoot -match '[^\x00-\x7F]') {
    throw 'The temporary build path must contain only ASCII characters. Set TEMP and TMP to an ASCII path.'
}
if (($repoRoot.TrimEnd('\') + '\').StartsWith(
    $outputRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase
)) {
    throw 'The release output directory must not be the repository or one of its ancestors.'
}
$versionSync = Join-Path $repoRoot 'tool\sync_app_version.dart'
Push-Location $repoRoot
try {
    & dart run $versionSync
    if ($LASTEXITCODE -ne 0) { throw 'Synchronizing application version metadata failed.' }
} finally {
    Pop-Location
}
$pubspec = Get-Content -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') -Raw
$versionMatches = [regex]::Matches(
    $pubspec,
    '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9]+)?)\s*(?:#.*)?$'
)
if ($versionMatches.Count -ne 1) {
    throw 'pubspec.yaml must contain one valid top-level version.'
}
$apkName = 'PVE-Manager-' + $versionMatches[0].Groups[1].Value + '-release.apk'

# Never stage inside the checkout: robocopy would recurse into its own output.
if ($stageRoot.StartsWith($repoRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The temporary build directory must be outside the repository.'
}
if ($outputRoot -eq $stageRoot -or
    $outputRoot.StartsWith($stageRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The release output directory must be outside the temporary build directory.'
}

New-Item -ItemType Directory -Path $stageRoot | Out-Null

try {
    $excluded = @(
        (Join-Path $repoRoot '.git'),
        (Join-Path $repoRoot '.codegraph'),
        (Join-Path $repoRoot '.codex'),
        (Join-Path $repoRoot '.dart_tool'),
        (Join-Path $repoRoot '.idea'),
        (Join-Path $repoRoot '.vscode'),
        (Join-Path $repoRoot '.pub'),
        (Join-Path $repoRoot '.pub-cache'),
        (Join-Path $repoRoot 'build'),
        (Join-Path $repoRoot 'coverage'),
        (Join-Path $repoRoot 'dist'),
        (Join-Path $repoRoot 'android\.gradle')
    )
    # A custom output directory under the checkout can also contain old APKs.
    if ($outputRoot.StartsWith($repoRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        $excluded += $outputRoot
    }
    & robocopy $repoRoot $stageRoot /E /XD $excluded /XF `
        '*.iml' '*.log' '.metadata' '.flutter-plugins' '.flutter-plugins-dependencies' 'local.properties' `
        /NFL /NDL /NJH /NJS /NP | Out-Host
    if ($LASTEXITCODE -ge 8) {
        throw "Robocopy failed with exit code $LASTEXITCODE."
    }

    Push-Location $stageRoot
    try {
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

        & flutter build apk --release
        if ($LASTEXITCODE -ne 0) { throw 'Release APK build failed.' }
    } finally {
        Pop-Location
    }

    $builtApk = Join-Path $stageRoot 'build\app\outputs\flutter-apk\app-release.apk'
    if (-not (Test-Path -LiteralPath $builtApk -PathType Leaf)) {
        throw 'Flutter completed without producing app-release.apk.'
    }

    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
    $outputApk = Join-Path $outputRoot $apkName
    Copy-Item -LiteralPath $builtApk -Destination $outputApk -Force
    # Keep only the current release in the output directory.
    Get-ChildItem -LiteralPath $outputRoot -Filter 'PVE-Manager-*-release.apk' -File |
        Where-Object { $_.FullName -ne $outputApk } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    $hash = (Get-FileHash -LiteralPath $outputApk -Algorithm SHA256).Hash
    Set-Content -LiteralPath (Join-Path $outputRoot 'SHA256SUMS.txt') `
        -Value "$hash  $apkName" -Encoding ascii

    [pscustomobject]@{
        Apk = $outputApk
        SHA256 = $hash
        Bytes = (Get-Item -LiteralPath $outputApk).Length
    } | Format-List
} finally {
    $resolvedStage = [IO.Path]::GetFullPath($stageRoot)
    $resolvedParent = [IO.Path]::GetFullPath((Split-Path $resolvedStage -Parent))
    if ($resolvedParent.TrimEnd('\') -eq $stageParent.TrimEnd('\') -and
        (Split-Path $resolvedStage -Leaf) -match '^pve_manager_build_[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force -ErrorAction SilentlyContinue
    }
}
