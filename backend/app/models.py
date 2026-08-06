from sqlalchemy import Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class VocabularyEntry(Base):
    """SPEC.md section 3.2 - static curated CEFR-tagged EN->DE dataset."""

    __tablename__ = "vocabulary"

    en: Mapped[str] = mapped_column(String, primary_key=True)
    de: Mapped[str] = mapped_column(String, nullable=False)
    cefr_level: Mapped[str] = mapped_column(String, nullable=False)
    part_of_speech: Mapped[str] = mapped_column(String, nullable=False)


class WordProgress(Base):
    """SPEC.md section 3.3 - per-user, per-word SM-2-style progress."""

    __tablename__ = "word_progress"

    user_id: Mapped[str] = mapped_column(String, primary_key=True)
    en_word: Mapped[str] = mapped_column(String, primary_key=True)
    exposures: Mapped[int] = mapped_column(Integer, default=0)
    times_toggled_back: Mapped[int] = mapped_column(Integer, default=0)
    times_toggled_forward: Mapped[int] = mapped_column(Integer, default=0)
    last_seen_at: Mapped[str | None] = mapped_column(String, nullable=True)
    ease_factor: Mapped[float] = mapped_column(Float, default=2.5)
    interval_days: Mapped[float] = mapped_column(Float, default=1.0)
    status: Mapped[str] = mapped_column(String, default="new")
