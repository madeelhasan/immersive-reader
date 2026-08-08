/// Fonts the reader can pick for document text (Settings, alongside the
/// theme palette). All five ship with Windows out of the box - no new font
/// asset or runtime download, same offline-first reasoning that picked
/// Georgia as the original single default (see ImmersiveReaderApp's
/// _readingFontFamily). Only affects reading content (ReaderView's token
/// text), not the app's own UI chrome, which stays on Georgia regardless.
enum ReaderFont {
  georgia('Georgia', 'Georgia'),
  cambria('Cambria', 'Cambria'),
  constantia('Constantia', 'Constantia'),
  calibri('Calibri', 'Calibri'),
  segoeUi('Segoe UI', 'Segoe UI');

  const ReaderFont(this.label, this.fontFamily);

  final String label;
  final String fontFamily;
}
