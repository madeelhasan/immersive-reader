import json
from pathlib import Path

from sqlalchemy.orm import Session

from . import models

# The Flutter app's bundled asset is the single source of truth for the
# vocabulary dataset (SPEC.md 3.2) - the backend seeds itself from the same
# file rather than maintaining a second copy that could drift out of sync.
VOCAB_JSON_PATH = (
    Path(__file__).resolve().parents[2]
    / "app"
    / "immersive_reader"
    / "assets"
    / "vocab"
    / "en_de_starter.json"
)


def seed_vocabulary_if_empty(db: Session, path: Path = VOCAB_JSON_PATH) -> int:
    """Populates the vocabulary table from path on first run. Returns the
    number of entries inserted (0 if the table was already populated)."""
    if db.query(models.VocabularyEntry).first() is not None:
        return 0

    entries = json.loads(path.read_text(encoding="utf-8"))
    db.bulk_insert_mappings(models.VocabularyEntry, entries)
    db.commit()
    return len(entries)
