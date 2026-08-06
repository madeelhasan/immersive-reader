from pydantic import BaseModel, ConfigDict, EmailStr, Field


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
    # user_id used to be a client-supplied opaque string (the deferred-auth
    # first pass); now that real auth exists, it's derived from the bearer
    # token server-side (see security.get_current_user_id) and not part of
    # the request body at all.
    entries: list[WordProgressIn] = Field(default_factory=list)


class ProgressSyncResponse(BaseModel):
    user_id: str
    synced: int


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
