# Packaging

Installer scaffolding for TODO.md's "Client distribution" backlog item, one subfolder per OS. None of these are signed yet - see the "Client distribution" section of `../../TODO.md` for the still-open signing/notarization work.

Status as of this pass (built from a Windows dev machine - see each script's own header comment for why the other two couldn't be build-tested here):

| Platform | Format | Build-tested here? | Notes |
|---|---|---|---|
| Windows | `.msix` | **Yes** - built and verified locally | `windows/` - via `dart run msix:create`, config lives in `pubspec.yaml`'s `msix_config` block |
| Linux | `.deb` | No - needs a real Linux host (GTK/glib toolchain) | `linux/build_deb.sh` |
| macOS | `.dmg` | No - needs a real Mac with Xcode | `macos/build_dmg.sh` |

`windows/app_icon.png` is a stopgap: it's upscaled from the existing 48x48 `windows/runner/resources/app_icon.ico` (itself the stock Flutter template icon, not custom branding) rather than a real high-resolution app icon. Reused as-is for the Linux/macOS icons below for consistency. Designing an actual app icon is a separate, still-open task - swap this file out (and rerun the relevant build script) once one exists; nothing else needs to change.
