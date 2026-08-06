from pydantic import BaseModel, ConfigDict, Field


class VocabularyEntryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    en: str
    de: str
    cefr_level: str
    part_of_speech: str


class WordProgressIn(BaseModel):
    en_word: str
    exposures: int = 0
    times_toggled_back: int = 0
    times_toggled_forward: int = 0
    last_seen_at: str | None = None
    ease_factor: float = 2.5
    interval_days: float = 1.0
    status: str = "new"


class WordProgressOut(WordProgressIn):
    model_config = ConfigDict(from_attributes=True)


class ProgressSyncRequest(BaseModel):
    # user_id is a client-generated opaque identifier (e.g. a UUID persisted
    # locally on first launch) - there is no login yet, per the deferred-auth
    # decision for this first Phase 3 pass. Real auth will replace this with
    # a token-derived identity without changing the request shape below.
    user_id: str
    entries: list[WordProgressIn] = Field(default_factory=list)


class ProgressSyncResponse(BaseModel):
    user_id: str
    synced: int
