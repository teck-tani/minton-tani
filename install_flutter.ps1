$ErrorActionPreference = "Stop"

$installDir = "C:\src"
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir
}

Write-Host "Downloading Flutter SDK..."
# Using a specific recent stable release.
$downloadUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.0-stable.zip"
$zipPath = "$installDir\flutter.zip"

Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

Write-Host "Extracting Flutter SDK (this may take a few minutes)..."
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

Write-Host "Updating PATH environment variable..."
$flutterBin = "$installDir\flutter\bin"

# Get current user PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notmatch [regex]::Escape($flutterBin)) {
    $newPath = $userPath + ";" + $flutterBin
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added $flutterBin to User PATH."
}
else {
    Write-Host "$flutterBin is already in User PATH."
}

# Update current session PATH so we can use it immediately
$env:PATH += ";$flutterBin"

Write-Host "Cleaning up..."
Remove-Item -Path $zipPath -Force

Write-Host "Flutter installation complete! Running flutter doctor..."
flutter doctor
