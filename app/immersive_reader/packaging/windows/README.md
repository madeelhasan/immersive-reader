# Windows installers

Two independent packaging paths live here: `installer.iss` (Inno Setup, produces `Setup.exe`) and the `.msix` path documented below. **`Setup.exe` is the recommended one** - no certificate or elevated shell needed to install, just a double-click and one SmartScreen click-through. See the root README's Installation section for the user-facing pitch.

## Setup.exe (Inno Setup)

```
packaging\windows\build_installer.ps1
```

Produces `packaging\windows\dist\LesefflussSetup-<version>.exe`. Requires Inno Setup 6's compiler (`ISCC.exe`) on the build machine - not bundled, install once via `winget install --id JRSoftware.InnoSetup -e`.

Installs per-user (`{userpf}\Lesefluss`, i.e. `%LOCALAPPDATA%\Programs\Lesefluss` - same convention as VS Code/Discord) via `PrivilegesRequired=lowest` in `installer.iss`, so neither install nor uninstall ever needs an admin prompt.

**Uninstall cleans up everything, not just what Setup put down.** This took a real fix, not just an `[UninstallDelete]` glob: `sqflite_common_ffi`'s default database path is relative to the process's *working directory*, which isn't guaranteed to always be the install directory depending on how the exe gets launched - so `lib/main.dart` now pins it explicitly via `databaseFactory.setDatabasesPath()` to the same stable per-user folder (`getApplicationSupportDirectory()`, from the `path_provider` package) that `shared_preferences` already used for app settings. That means there's exactly one on-disk location (`%APPDATA%\com.example\Lesefluss\`) this app ever writes to, and `[UninstallDelete]` only needs to know about that one place plus the install directory itself. Verified for real: built, silently installed, launched, confirmed both `immersive_reader.db` and `shared_preferences.json` landed in that one folder, then silently uninstalled and confirmed the install directory, the app-data folder, the Start Menu entry, and the desktop shortcut were all gone.

Not code-signed - unsigned `.exe`s get a one-time Windows SmartScreen "Windows protected your PC" warning on first run (`More info` → `Run anyway`), the same tradeoff as any unsigned installer from a small/indie publisher.

## .msix

Config lives in `pubspec.yaml`'s `msix_config` block, not here - the `msix` package (a dev dependency) reads it directly.

## Build

```
flutter build windows --release
dart run msix:create
```

Produces `build/windows/x64/runner/Release/immersive_reader.msix`.

## Signing status

**Not code-signed with a real certificate.** With no `certificate_path`/`certificate_password` configured, `msix:create` self-signs the package with a throwaway test certificate it generates on the fly. That's enough to produce a real, installable `.msix` for local testing on this machine, but:

- On a different machine, Windows will refuse to install it until that machine's cert store explicitly trusts the (untrusted, self-signed) signing certificate - `Add-AppxPackage` will fail with a trust error.
- This is *not* the same problem as the plain unsigned `.exe`/SmartScreen issue tracked elsewhere in `../../TODO.md`'s "Client distribution" section, but it's in the same family: a real release needs either an EV code-signing certificate (traditional, works everywhere immediately) or Microsoft Store submission (Store-signs it for you, but subjects the app to Store review). Neither is set up yet - that's the next step here, not something this pass could complete without a purchased certificate or a Store developer account.

## Testing an install locally

```
Add-AppPackage -Path .\build\windows\x64\runner\Release\immersive_reader.msix
```

(PowerShell, may need `-AllowUnsigned` or an explicit `Import-Certificate` step into `Cert:\LocalMachine\Root` first, depending on Windows' current trust settings for self-signed test certs.)

## Icon

`app_icon.png` here is a stopgap - see `../README.md`.
