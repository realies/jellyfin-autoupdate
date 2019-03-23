if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
Push-Location $PSScriptRoot
$releasesUrl = "https://api.github.com/repos/jellyfin/jellyfin/releases"
$installationPath = "$env:APPDATA\jellyfin"
$architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture.replace("-bit", "")
$serviceName = "Jellyfin"
$service = Get-Service $serviceName -ErrorAction SilentlyContinue
if (!$service) {
    Write-Host "$serviceName service not found, exiting..."
    exit 1
} else {
    $currentVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$installationPath\jellyfin.dll").FileVersion
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $releases = Invoke-WebRequest -Uri $releasesUrl -UseBasicParsing | ConvertFrom-Json
    $latestVersion = $releases[0].tag_name.Replace("v", "")
    if ($currentVersion -eq $latestVersion) {
        Write-Host "Up to date, exiting..."
        exit 0
    }
    Write-Host "Updating Jellyfin from $currentVersion to $latestVersion..."
    $latestVersionUrl = $($releases[0].assets | where { $_.browser_download_url -like "*$latestVersion*$architecture.zip" } | Select -ExpandProperty browser_download_url)
    $fileName = "jellyfin-latest.zip"
    Write-Host "Downloading latest package..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest $latestVersionUrl -Out $filename
    if ($service.Status -eq "Running") {
        Write-Host "Stopping $serviceName service..."
        Stop-Service $serviceName -Force
    }
    Write-Host "Preparing to update..."
    Get-ChildItem $installationPath -Exclude cache, config, data, logs, root | Remove-Item -Recurse -Force
    Write-Host "Unpacking..."
    Expand-Archive $fileName $installationPath -Force
    Write-Host "Cleaning up..."
    Remove-Item $fileName -Force
    Write-Host "Starting $serviceName service..."
    Start-Service $serviceName
    Write-Host "Done"
    exit 0
}
