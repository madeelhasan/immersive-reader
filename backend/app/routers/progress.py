from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..security import get_current_user_id

router = APIRouter(prefix="/progress", tags=["progress"])


@router.post("", response_model=schemas.ProgressSyncResponse)
def sync_progress(
    payload: schemas.ProgressSyncRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """Upserts word_progress rows for the authenticated user. Client sends
    its full local state for the words it's touched since the last sync;
    last write wins per (user_id, en_word) - no conflict resolution beyond
    that yet."""
    for entry in payload.entries:
        existing = db.get(models.WordProgress, (user_id, entry.en_word))
        if existing is None:
            db.add(models.WordProgress(user_id=user_id, **entry.model_dump()))
        else:
            for field, value in entry.model_dump().items():
                setattr(existing, field, value)
    db.commit()
    return schemas.ProgressSyncResponse(user_id=user_id, synced=len(payload.entries))


@router.get("", response_model=list[schemas.WordProgressOut])
def get_progress(user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)):
    """Fetches all word_progress rows for the authenticated user - e.g. to
    restore state on a new device once Phase 4 wires this up client-side."""
    return (
        db.query(models.WordProgress)
        .filter(models.WordProgress.user_id == user_id)
        .order_by(models.WordProgress.en_word)
        .all()
    )
