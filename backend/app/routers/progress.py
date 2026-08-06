from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db

router = APIRouter(prefix="/progress", tags=["progress"])


@router.post("", response_model=schemas.ProgressSyncResponse)
def sync_progress(payload: schemas.ProgressSyncRequest, db: Session = Depends(get_db)):
    """Upserts word_progress rows for payload.user_id. Client sends its full
    local state for the words it's touched since the last sync; last write
    wins per (user_id, en_word) - no conflict resolution beyond that yet."""
    for entry in payload.entries:
        existing = db.get(models.WordProgress, (payload.user_id, entry.en_word))
        if existing is None:
            db.add(models.WordProgress(user_id=payload.user_id, **entry.model_dump()))
        else:
            for field, value in entry.model_dump().items():
                setattr(existing, field, value)
    db.commit()
    return schemas.ProgressSyncResponse(user_id=payload.user_id, synced=len(payload.entries))


@router.get("/{user_id}", response_model=list[schemas.WordProgressOut])
def get_progress(user_id: str, db: Session = Depends(get_db)):
    """Fetches all word_progress rows for user_id - e.g. to restore state on
    a new device once Phase 4 wires this up client-side."""
    return (
        db.query(models.WordProgress)
        .filter(models.WordProgress.user_id == user_id)
        .order_by(models.WordProgress.en_word)
        .all()
    )
