$ErrorActionPreference = "Stop"

$installDir = "C:\src"
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir
}

Write-Host "Downloading Flutter SDK using curl.exe..."
$downloadUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.0-stable.zip"
$zipPath = "$installDir\flutter.zip"

curl.exe -L -o $zipPath $downloadUrl

Write-Host "Extracting Flutter SDK using tar.exe (this will be much faster)..."
tar.exe -xf $zipPath -C $installDir

Write-Host "Updating PATH environment variable..."
$flutterBin = "$installDir\flutter\bin"

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notmatch [regex]::Escape($flutterBin)) {
    $newPath = $userPath + ";" + $flutterBin
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added $flutterBin to User PATH."
}
else {
    Write-Host "$flutterBin is already in User PATH."
}

# Add directory explicitly to session path for subsequent commands to see it immediately
$env:Path += ";$flutterBin"

Write-Host "Cleaning up..."
Remove-Item -Path $zipPath -Force

Write-Host "Flutter installation complete! Running flutter doctor..."
# Try to run it locally inside the script to initialize
flutter doctor
