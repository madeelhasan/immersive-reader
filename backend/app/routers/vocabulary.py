from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db

router = APIRouter(prefix="/vocabulary", tags=["vocabulary"])


@router.get("", response_model=list[schemas.VocabularyEntryOut])
def list_vocabulary(cefr_level: str | None = None, db: Session = Depends(get_db)):
    """Returns the full dataset, or just one CEFR level if cefr_level is
    given. Level-eligibility filtering (SPEC.md 4.1, cumulative by reader
    level) stays a client-side concern in ReplacementEngine - this endpoint
    is a plain data source, not the replacement algorithm."""
    query = db.query(models.VocabularyEntry)
    if cefr_level is not None:
        query = query.filter(models.VocabularyEntry.cefr_level == cefr_level)
    return query.order_by(models.VocabularyEntry.en).all()
