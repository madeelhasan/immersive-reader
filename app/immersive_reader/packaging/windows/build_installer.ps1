# Builds the Windows .exe installer (Inno Setup) - the double-click-to-
# install path, as opposed to build_msix.ps1's .msix (which needs either a
# real code-signing certificate or an elevated shell to trust its
# self-signed test certificate before Windows will install it at all).
#
# Requires Inno Setup 6's compiler (ISCC.exe) - not bundled here, install
# once per build machine: winget install --id JRSoftware.InnoSetup -e
#
# Usage: packaging\windows\build_installer.ps1
# Output: packaging\windows\dist\LesefflussSetup-<version>.exe
$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\..\.."  # -> app\immersive_reader\

$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) { $flutter = "C:\src\flutter\bin\flutter.bat" }

& $flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }

$iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if (-not $iscc) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    )
    $found = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $found) {
        throw "ISCC.exe (Inno Setup compiler) not found. Install it: winget install --id JRSoftware.InnoSetup -e"
    }
    $iscc = $found
} else {
    $iscc = $iscc.Source
}

& $iscc "packaging\windows\installer.iss"
if ($LASTEXITCODE -ne 0) { throw "ISCC.exe failed" }

$output = Get-ChildItem "packaging\windows\dist\LesefflussSetup-*.exe" | Select-Object -First 1 -ExpandProperty FullName
Write-Host "Output: $output"
exit 0
