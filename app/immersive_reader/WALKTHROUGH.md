# Lesefluss — a walkthrough

This is a plain-language guide to what the app does and how to use it. If you're a developer looking for architecture details, see `PROJECT_OVERVIEW.md` or `../CLAUDE.md` instead — this file is written for someone who just wants to read a book and pick up some German along the way.

## The idea in one paragraph

You open a document you already want to read — a novel, an article, whatever — in English. The app quietly swaps a handful of easy words in that text for their German translations. You keep reading normally; when you hit a German word, you either already know it, or you tap it to flip it back to English and see what it meant. Over time it swaps in more words, and the ones you already know show up in German more often than ones you're still learning. There's no separate flashcard app, no vocabulary drills — the "lesson" is just the book you were already reading.

## Opening something to read

The very first time you open the app, you'll see a short welcome screen explaining each feature, ending with a **"Let's open your first book!"** button. Tapping it first asks you to pick your starting German level (see below) — you can always change it later — then opens the file picker. After that first time, you'll see either a short instruction ("Open a file to start reading") or a **Recent** list of documents you can tap to jump back into.

To open something new at any time, click the folder icon in the top-right corner. You can pick:

- **.txt** — plain text
- **.docx** — Word documents
- **.epub** — ebooks
- **.pdf** — PDFs (as long as the PDF has real, selectable text — a scanned photo of a page with no text layer won't work, and the app will tell you that rather than show a blank screen)
- **.html / .htm** — web pages saved to your computer

The app strips out formatting and lays the text out in a single clean, readable column — no columns, no page images, no clutter.

## The recent list

Every file you open gets remembered (the 8 most recent), so you can close the app and pick up where you left off later — it even scrolls back to roughly the spot you were at, and reopens instantly rather than re-processing the file from scratch. Each entry shows when you last opened it ("2h ago," "3d ago," etc.).

If any of your recent books still has an active bookmark and isn't finished yet, it also shows up in a separate **"Continue reading"** section above the full list, so books you're actively partway through don't get lost among ones you only opened briefly.

- **Tap an entry** to resume reading it.
- **Tap the trash icon** on an entry to remove it from the list. This only forgets that it's "recent" — it does not delete or move the actual file on your computer.
- If a file has been moved or deleted since you last opened it, tapping it will just tell you it couldn't be found and quietly clean it off the list, rather than crashing.

While you're reading, a back arrow appears next to the title in the top bar — click it to return to this list at any time.

## Reading the text

Once a document is open, a toolbar sits above the text with a few controls:

- **Chapters** (list icon) — only shown for ebooks that have chapter markers; tap to jump straight to one.
- **Bookmark this page** (bookmark-plus icon) — drops a bookmark at your current scroll position.
- **Bookmarks** (bookmarks icon) — opens the list of everywhere you've bookmarked in this document. Tap one to jump there — the paragraph you land on flashes with a highlight so it's obvious where to pick up reading; it fades once you scroll away or tap it — or the trash icon next to it to remove it. There's also a toggle here, **"Auto-replace forward bookmarks"**: when it's on, bookmarking further ahead moves your one "current position" marker forward instead of piling up a new bookmark every time — useful if you just want a single "where am I" marker rather than a list of favorite passages. If it accidentally overwrites one you wanted to keep, an "Undo" option appears briefly after.
- A **progress bar** in the middle shows roughly how far through the document you are, as a percentage.
- **+ / −** buttons on the right adjust the text size.
- **Ctrl+G** opens a "Go to page" box where you can type a page number directly and jump there.

## The German replacement, explained

Some words in the text will appear **blue and underlined** — that's the German. Everything else stays in English exactly as it was.

- **Tap** a blue word to flip it back to English temporarily (tap it again to flip it back to German). This is per-occurrence: if the same word appears three times on a page, toggling one doesn't affect the other two.
- **Long-press** a blue word to hear it spoken aloud in German, using your computer's built-in text-to-speech voice — no internet connection needed for this.
- **Right-click any word** (German or still-English) to look up its dictionary definition in a small popup — this uses a bundled offline dictionary, so it works with no internet connection either. The very first right-click in a session takes a moment longer while the dictionary sets itself up; every one after that is instant.

### How many words get replaced, and which ones

Your current level (A1 through C2 — the standard CEFR scale used for language learning, from complete beginner to near-native) is always shown as a small chip in the top bar, next to the settings gear. Tap either one to open Settings and change it. A higher level replaces more words, more often, and draws from a wider vocabulary pool (every level at or below your own — a B1 reader sees A1, A2, and B1 words, never anything above B1). Change it any time; the document you're reading will immediately re-roll which words are shown in German. Once you've learned every word available at your current level, the app bumps you up to the next one automatically.

The app also quietly pays attention to which words you tend to toggle back to English (meaning you probably don't know them yet) versus ones you leave in German (meaning you're comfortable with them). Words you already seem to know will keep showing up in German more consistently; words you're still learning appear more gradually. You don't have to do anything for this to work — it happens in the background as you read and tap.

## Settings

Tap the gear icon in the top bar to open Settings, split into two sections:

**App**
- **Theme** — cycles through light, dark, and system-default brightness.
- **Color palette** — four full-color themes, not just light/dark variants of one look: the original warm palette (cream paper / soft charcoal), two additional soft options (a cool sage green, a soft ocean blue), and a dedicated **High Contrast** theme for low vision — true black/white, bolder text, and a larger minimum font size. Each has its own light and dark version, so it combines with the Theme setting above rather than replacing it.

**Reading & Vocabulary**
- **Font** — five reading fonts to choose from (Georgia, Cambria, Constantia, Calibri, Segoe UI). Only affects the book text itself, not the app's own menus/buttons.
- **German level** — the same A1–C2 selector described above.

## A few things worth knowing

- **Everything stays on your computer.** There's no account to create, no sign-in, and nothing you read or tap is sent anywhere. Your reading history, bookmarks, and word-familiarity data live in a local file on this machine only.
- **The vocabulary is a fixed, hand-curated dataset**, not a live translation engine — so replacements are consistent and dictionary-accurate rather than machine-translated on the fly.
- If a PDF opens but shows no text, it's very likely a scanned image rather than real text — the app can only work with documents that have an actual, selectable text layer.
