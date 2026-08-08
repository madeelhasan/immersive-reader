# Windows installer (.msix)

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
