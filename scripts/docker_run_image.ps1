[CmdletBinding()]
param(
    [string]$ImageName = "plcrex-web",
    [string]$ImageTag = "windows-ltsc2022",
    [string]$ContainerName = "plcrex-web-dev",
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker CLI not found. Install Docker Desktop and switch it to Windows container mode."
}

$dockerServerOs = docker version --format '{{.Server.Os}}' 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "Unable to query Docker server mode. Make sure Docker Desktop is running."
}

if ($dockerServerOs.Trim() -ne "windows") {
    throw "Docker is currently running in '$dockerServerOs' mode. Switch Docker Desktop to Windows containers before running the image."
}

$imageRef = "{0}:{1}" -f $ImageName, $ImageTag

$existingContainerId = docker ps -aq --filter "name=^${ContainerName}$"
if ($LASTEXITCODE -ne 0) {
    throw "Unable to query existing containers."
}
if ($existingContainerId) {
    docker rm -f $ContainerName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to remove existing container $ContainerName"
    }
}

Write-Host "Starting Windows container $ContainerName from $imageRef on port $Port"
$containerId = docker run -d --name $ContainerName -p "${Port}:8000" $imageRef
if ($LASTEXITCODE -ne 0) {
    throw "Docker run failed for $imageRef"
}

Write-Host "Container started:"
Write-Host "  Name: $ContainerName"
Write-Host "  Id:   $containerId"
Write-Host "  URL:  http://127.0.0.1:$Port"
