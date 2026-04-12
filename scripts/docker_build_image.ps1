[CmdletBinding()]
param(
    [string]$ImageName = "plcrex-web",
    [string]$ImageTag = "windows-ltsc2022",
    [string]$OutputDir = "image_output",
    [string]$DockerfilePath = "Dockerfile"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoRoot = Split-Path -Parent $PSScriptRoot
$vendorPath = Join-Path $repoRoot "vendor\PLCreX"
$plcrexVenvPath = Join-Path $repoRoot ".venv-plcrex"
$pyedaBinaryPath = Join-Path $plcrexVenvPath "Lib\site-packages\pyeda\boolalg\espresso.cp39-win_amd64.pyd"
$resolvedDockerfile = Join-Path $repoRoot $DockerfilePath
$resolvedOutputDir = Join-Path $repoRoot $OutputDir
$imageRef = "{0}:{1}" -f $ImageName, $ImageTag
$archiveName = "{0}-{1}.tar" -f $ImageName, $ImageTag
$archivePath = Join-Path $resolvedOutputDir $archiveName
$sbomName = "{0}-{1}.sbom.json" -f $ImageName, $ImageTag
$sbomPath = Join-Path $resolvedOutputDir $sbomName

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI not found. Install Docker Desktop and switch it to Windows container mode."
}

if (-not (Test-Path $vendorPath)) {
    throw "vendor\PLCreX is missing. Run 'just pull-plcrex' before building the Docker image."
}

if (-not (Test-Path $pyedaBinaryPath)) {
    throw ".venv-plcrex is missing compiled PLCreX dependencies at $pyedaBinaryPath. Run 'just pull-plcrex' on the host before building the Docker image."
}

if (-not (Test-Path $resolvedDockerfile)) {
    throw "Dockerfile not found at $resolvedDockerfile"
}

$dockerServerOs = docker version --format '{{.Server.Os}}' 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "Unable to query Docker server mode. Make sure Docker Desktop is running."
}

if ($dockerServerOs.Trim() -ne "windows") {
    throw "Docker is currently running in '$dockerServerOs' mode. Switch Docker Desktop to Windows containers before building."
}

New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null

$plcrexPyprojectPath = Join-Path $vendorPath "pyproject.toml"
if (-not (Test-Path $plcrexPyprojectPath)) {
    throw "PLCreX pyproject.toml not found at $plcrexPyprojectPath"
}

$plcrexPyprojectContent = Get-Content $plcrexPyprojectPath -Raw
$versionMatch = [regex]::Match($plcrexPyprojectContent, '(?m)^version\s*=\s*"([^"]+)"')
if (-not $versionMatch.Success) {
    throw "Unable to determine PLCreX version from $plcrexPyprojectPath"
}
$plcrexVersion = $versionMatch.Groups[1].Value

$plcrexCommit = (& git -C $vendorPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($plcrexCommit)) {
    throw "Unable to determine PLCreX git commit."
}

$plcrexCommitDate = (& git -C $vendorPath log -1 --format=%cI).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to determine PLCreX git commit date."
}

$plcrexCommitSubject = (& git -C $vendorPath log -1 --format=%s).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to determine PLCreX git commit subject."
}

$repoCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoCommit)) {
    throw "Unable to determine repository git commit."
}

$repoCommitDate = (& git -C $repoRoot log -1 --format=%cI).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to determine repository git commit date."
}

$repoCommitSubject = (& git -C $repoRoot log -1 --format=%s).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to determine repository git commit subject."
}

function Get-RelativeRepoPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $repoUri = [System.Uri]((Resolve-Path $repoRoot).Path + [System.IO.Path]::DirectorySeparatorChar)
    $targetUri = [System.Uri](Resolve-Path $Path).Path
    return [System.Uri]::UnescapeDataString($repoUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

function Get-VersionStringFromText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $match = [regex]::Match($Text, '(?im)\b(v?\d+(?:\.\d+){1,3}(?:[-+._a-zA-Z0-9]*)?)\b')
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}

function Get-RuntimeToolEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string[]]$Candidates
    )

    $resolvedPath = $null
    foreach ($candidate in $Candidates) {
        $candidatePath = Join-Path $repoRoot $candidate
        if (Test-Path $candidatePath -PathType Leaf) {
            $resolvedPath = $candidatePath
            break
        }
    }

    if (-not $resolvedPath) {
        return [ordered]@{
            name = $Name
            included = $false
        }
    }

    $item = Get-Item $resolvedPath
    $entry = [ordered]@{
        name = $Name
        included = $true
        path = Get-RelativeRepoPath -Path $resolvedPath
        size_bytes = $item.Length
        sha256 = (Get-FileHash -Algorithm SHA256 -Path $resolvedPath).Hash.ToLowerInvariant()
    }

    if ($item.Extension -ieq ".exe") {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($resolvedPath)
        if (-not [string]::IsNullOrWhiteSpace($versionInfo.ProductVersion)) {
            $entry.product_version = $versionInfo.ProductVersion
        }
        if (-not [string]::IsNullOrWhiteSpace($versionInfo.FileVersion)) {
            $entry.file_version = $versionInfo.FileVersion
        }
    }

    if ($item.Extension -ieq ".bat" -or $item.Extension -ieq ".cmd") {
        $scriptContent = Get-Content $resolvedPath -Raw
        $detectedVersion = Get-VersionStringFromText -Text $scriptContent
        if ($detectedVersion) {
            $entry.detected_version = $detectedVersion
        }
    }

    if ($Name -eq "nusmv" -and -not $entry.Contains("detected_version")) {
        $detectedVersion = Get-VersionStringFromText -Text $entry.path
        if ($detectedVersion) {
            $entry.detected_version = $detectedVersion
        }
    }

    return $entry
}

$runtimeTools = @(
    Get-RuntimeToolEntry -Name "nusmv" -Candidates @(
        "vendor\runtime-tools\nusmv\NuSMV.exe",
        "vendor\runtime-tools\nusmv\bin\NuSMV.exe",
        "vendor\runtime-tools\NuSMV-2.7.1-win64\bin\NuSMV.exe",
        "vendor\runtime-tools\NuSMV.exe"
    )
    Get-RuntimeToolEntry -Name "iec_checker" -Candidates @(
        "vendor\runtime-tools\iec-checker\iec_checker_Windows_x86_64_v0.4.exe",
        "vendor\runtime-tools\iec-checker\iec_checker.exe",
        "vendor\runtime-tools\iec_checker_Windows_x86_64.exe",
        "vendor\runtime-tools\iec_checker.exe"
    )
    Get-RuntimeToolEntry -Name "kicodia" -Candidates @(
        "vendor\runtime-tools\kicodia\kicodia-win.bat",
        "vendor\runtime-tools\kicodia-win.bat"
    )
)

Write-Host "Building Windows container image $imageRef"
docker build --file $resolvedDockerfile --tag $imageRef $repoRoot
if ($LASTEXITCODE -ne 0) {
    throw "Docker build failed for $imageRef"
}

if (Test-Path $archivePath) {
    Remove-Item -Force $archivePath
}

Write-Host "Saving image archive to $archivePath"
docker save --output $archivePath $imageRef
if ($LASTEXITCODE -ne 0) {
    throw "Docker save failed for $imageRef"
}

$sbom = [ordered]@{
    schema_version = "1.0"
    artifact = [ordered]@{
        type = "docker-image-archive"
        image = $imageRef
        archive = [System.IO.Path]::GetFileName($archivePath)
        created_at = (Get-Date).ToUniversalTime().ToString("o")
    }
    plcrex = [ordered]@{
        version = $plcrexVersion
        commit = $plcrexCommit
        commit_date = $plcrexCommitDate
        commit_subject = $plcrexCommitSubject
    }
    source_repo = [ordered]@{
        commit = $repoCommit
        commit_date = $repoCommitDate
        commit_subject = $repoCommitSubject
    }
    runtime_tools = $runtimeTools
}

$sbom | ConvertTo-Json -Depth 6 | Set-Content $sbomPath

Write-Host "Windows image ready:"
Write-Host "  Image:   $imageRef"
Write-Host "  Archive: $archivePath"
Write-Host "  SBOM:    $sbomPath"
