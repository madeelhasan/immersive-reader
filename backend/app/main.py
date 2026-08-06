from contextlib import asynccontextmanager

from fastapi import FastAPI

from .database import Base, SessionLocal, engine
from .routers import progress, vocabulary
from .seed import seed_vocabulary_if_empty


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_vocabulary_if_empty(db)
    finally:
        db.close()
    yield


app = FastAPI(title="Immersive Reader API", lifespan=lifespan)
app.include_router(vocabulary.router)
app.include_router(progress.router)


@app.get("/health")
def health():
    return {"status": "ok"}
