# vendor/

Locally patched copies of third-party packages, wired in via `dependency_overrides:` in `../pubspec.yaml`.

## msix

Vendored from `msix` 2.7.3 (pub.dev). The only change from upstream is removing the `pluginClass: none`
line from `pubspec.yaml`'s `flutter: plugin: platforms: windows:` block.

Every published msix version (checked up to 3.18.0) declares `pluginClass: none` there as a legacy
placeholder meaning "dart-only, no native code" - older Flutter tooling special-cased that string, but
current Flutter (`NativeOrDartPlugin.hasMethodChannel()` in `flutter_tools/lib/src/platform_plugins.dart`)
only checks `pluginClass != null`. Since `"none"` isn't null, msix gets misclassified as a native plugin,
and `flutter run`/`build windows` fails at the CMake step looking for a `windows/` native-build directory
that doesn't exist inside the msix package (it's a pure Dart CLI tool, invoked via `dart run msix:create`).

Upgrading msix doesn't help - the declaration is unchanged across versions - and it isn't safe to blanket
-upgrade anyway: msix >=3.17.0 pulls in `image` >=4.0.0, which forces `archive ^4.0.9`, conflicting with
the `archive ^3.6.1` pin the DOCX/EPUB parsers depend on (see the root CLAUDE.md).

If a future msix release fixes this upstream, drop this vendor copy and the `dependency_overrides` entry.
