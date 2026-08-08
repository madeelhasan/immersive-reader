# Packaging

Installer scaffolding for TODO.md's "Client distribution" backlog item, one subfolder per OS. None of these are signed yet - see the "Client distribution" section of `../../TODO.md` for the still-open signing/notarization work.

Status as of this pass (built from a Windows dev machine - see each script's own header comment for why the other two couldn't be build-tested here):

| Platform | Format | Build-tested here? | Notes |
|---|---|---|---|
| Windows | `.msix` | **Partially** - builds cleanly (`build\windows\runner\Release\immersive_reader.msix`), but local install verification (`Add-AppPackage`) needs an elevated shell to complete the self-signing step (`0x800B0100, No signature was present in the subject` otherwise) - not yet confirmed to actually install on this machine | `windows/` - via `dart run msix:create`, config lives in `pubspec.yaml`'s `msix_config` block |
| Linux | `.deb` | No - needs a real Linux host (GTK/glib toolchain) | `linux/build_deb.sh` |
| macOS | `.dmg` | No - needs a real Mac with Xcode | `macos/build_dmg.sh` |

`windows/app_icon.png` is the real Lesefluss logo (book + language-accent mark), reused as-is for the Linux/macOS icons above for cross-platform consistency.
