from sqlmodel import SQLModel, create_engine, Session, Field
from typing import Generator

# Database URL - using SQLite for simplicity
DATABASE_URL = "sqlite:///./way2sustain.db"

# Create engine with specific settings for SQLite
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False},
    echo=False
)


def create_db_and_tables():
    """Create all database tables"""
    SQLModel.metadata.create_all(engine)


def get_session() -> Generator[Session, None, None]:
    """Get database session"""
    with Session(engine) as session:
        yield session
