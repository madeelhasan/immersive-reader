# Packaging

Installer scaffolding for TODO.md's "Client distribution" backlog item, one subfolder per OS. None of these are signed yet - see the "Client distribution" section of `../../TODO.md` for the still-open signing/notarization work.

Status as of this pass (built from a Windows dev machine - see each script's own header comment for why the other two couldn't be build-tested here):

| Platform | Format | Build-tested here? | Notes |
|---|---|---|---|
| Windows | `Setup.exe` (Inno Setup) | **Yes** - built, silently installed, launched, and silently uninstalled end-to-end, verified clean (no leftover install dir, app-data folder, Start Menu entry, or desktop shortcut) | `windows/build_installer.ps1` + `windows/installer.iss` - **recommended path**, no cert/elevation needed at all (per-user install), one SmartScreen click-through on first run since it's unsigned |
| Windows | `.msix` | **Partially** - builds cleanly (`build\windows\runner\Release\immersive_reader.msix`), but local install verification (`Add-AppPackage`) needs an elevated shell to complete the self-signing step (`0x800B0100, No signature was present in the subject` otherwise) - not yet confirmed to actually install on this machine | `windows/build_msix.ps1` - via `dart run msix:create`, config lives in `pubspec.yaml`'s `msix_config` block |
| Linux | `.deb` | No - needs a real Linux host (GTK/glib toolchain) | `linux/build_deb.sh` |
| macOS | `.dmg` | No - needs a real Mac with Xcode | `macos/build_dmg.sh` |

**Why two Windows formats:** the `.msix` path is more "properly Windows-native" (Apps & Features integration, App Installer UI) but needs either a real code-signing certificate or an elevated shell to install locally, since its self-signed test certificate isn't trusted by default. The Inno Setup path trades that for a one-time SmartScreen warning on first run - judged the easier ask for non-technical users. Both remain maintained; `Setup.exe` is the one actually recommended in the root README.

**A real bug found and fixed while verifying the Inno Setup uninstaller "leaves nothing behind":** `sqflite_common_ffi`'s default database directory is relative to the process's *working directory* (`.dart_tool/sqflite_common_ffi/databases`) - correct for a normal shortcut/double-click launch, but not guaranteed for every launch path, and Inno's uninstaller has no way to find files it never knew were created. Fixed at the source (`lib/main.dart`), not just papered over in the installer script: `databaseFactory.setDatabasesPath()` now pins the database to the same stable per-user directory (`getApplicationSupportDirectory()`, via the newly-added `path_provider` dependency) that `shared_preferences` already used - so the app has exactly one on-disk data location regardless of how it's launched, and the installer's `[UninstallDelete]` section only has to know about that one place.

`windows/app_icon.png` is the real Lesefluss logo (book + language-accent mark), reused as-is for the Linux/macOS icons above for cross-platform consistency.
