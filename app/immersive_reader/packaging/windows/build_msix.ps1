# Builds the Windows .msix installer.
#
# Wraps a real quirk in msix 2.7.3 (the version this project is pinned to -
# see the comment above the msix_config block in ../../pubspec.yaml for
# why): it hardcodes its expected build output at
# build\windows\runner\Release, but current Flutter versions build to the
# architecture-specific build\windows\x64\runner\Release instead. This
# script builds normally, then mirrors the x64 output to the legacy path
# msix looks for before invoking it.
#
# Usage: packaging\windows\build_msix.ps1
# Output: build\windows\runner\Release\immersive_reader.msix
$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\..\.."  # -> app\immersive_reader\

flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }

$legacyRelease = "build\windows\runner\Release"
if (Test-Path $legacyRelease) { Remove-Item -Recurse -Force $legacyRelease }
New-Item -ItemType Directory -Force -Path "build\windows\runner" | Out-Null
Copy-Item -Recurse "build\windows\x64\runner\Release" $legacyRelease

dart run msix:create
$msixExitCode = $LASTEXITCODE

$outputMsix = "$legacyRelease\immersive_reader.msix"
if (-not (Test-Path $outputMsix)) {
    throw "msix:create failed before producing $outputMsix (exit code $msixExitCode)"
}

if ($msixExitCode -ne 0) {
    # The one known non-fatal case: msix:create's packing step (which
    # produces the .msix) runs before its later, separate "install this
    # self-signed test certificate into your trust store for convenience"
    # step - the latter needs an elevated shell and fails harmlessly
    # without one. The file above already existing is what actually proves
    # this run succeeded, not dart's own exit code.
    Write-Warning ("msix:create reported a non-zero exit, but $outputMsix was still " +
        "produced - if the only failure shown above was about installing the test " +
        "certificate, that step needs 'Run as administrator' and is optional. See " +
        "README.md.")
}

Write-Host "Output: $outputMsix"
exit 0
