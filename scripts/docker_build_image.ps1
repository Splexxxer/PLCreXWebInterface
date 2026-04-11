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
}

$sbom | ConvertTo-Json -Depth 6 | Set-Content $sbomPath

Write-Host "Windows image ready:"
Write-Host "  Image:   $imageRef"
Write-Host "  Archive: $archivePath"
Write-Host "  SBOM:    $sbomPath"
