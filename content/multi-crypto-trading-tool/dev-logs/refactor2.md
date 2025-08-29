+++
title = "12. Refactoring 2: Backend - Applying Async Database Management"
type = "dev-log"
tags = [
  "fastapi", "sqlalchemy", "asyncio", "asyncpg",
  "database", "dependency-injection", "lifespan",
  "connection-pooling", "refactoring", "sqlalchemy", "backend"
]
weight = 12
+++

This refactoring adopts **asynchronous database management** to avoid blocking caused by synchronous I/O.

Previously, database access was implemented synchronously across services and endpoints, which could block under concurrent workloads. Because this program needs to perform multiple tasks simultaneously, I decided to switch to an **async-first** approach for database operations.

## 1. Config

---

- To enable asynchronous PostgreSQL support, install `asyncpg`:

    ```bash
    uv pip install asyncpg
    ```

- In **config.py**, I added the following property to build the async SQLAlchemy URL for PostgreSQL:

    ```python
    class Settings(BaseSettings):
        ...
        
        @property
        def async_db_url(self):
            return f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

        ...

    ```

## 2. Async Database

---

- This section initializes the async engine, configures a session factory, and exposes a single declarative base for ORM models.
- I implemented this class by referencing the sync database class.

    ```python
    import os
    from sqlalchemy import MetaData
    from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
    from sqlalchemy.orm import declarative_base
    from .config import settings

    DEFAULT_SCHEMA = os.getenv("DB_SCHEMA", "public")
    metadata = MetaData(schema=DEFAULT_SCHEMA)
    Base = declarative_base(metadata=metadata)

    class AsyncDatabase:
        """Async database connection and session management."""
        
        Base = declarative_base()
        
        def __init__(self):
            self._engine = create_async_engine(
                settings.async_db_url,
                echo=False,
                pool_pre_ping=True,
                connect_args={"server_settings": {"search_path": os.getenv("DB_SCHEMA", "public")}},
            )
            self._SessionLocal = async_sessionmaker(
                bind=self._engine,
                expire_on_commit=False,
                autoflush=False,
                autocommit=False
            )
        
        def get_engine(self):
            """Returns the async SQLAlchemy engine."""
            return self._engine
        
        def get_session(self) -> AsyncSession:
            """Returns a new async session."""
            return self._SessionLocal()
        
        @classmethod
        def get_base(cls):
            """Returns the declarative base class."""
            return cls.Base

    ```

  - `DEFAULT_SCHEMA` / `MetaData(schema=DEFAULT_SCHEMA)` :
  Defines a default PostgreSQL schema (e.g., `public`). Attaching this  `metadata    to the declarative base makes DDL/Autogenerate target the right schema without qualifying every table name.
  - `Base = declarative_base(metadata=metadata)` :
  Exposes a *single* declarative base for all ORM models. Import this `Base` everywhere you define models so they share the same metadata and schema.
  - `create_async_engine(settings.async_db_url, ...)` :
  Builds an **async** SQLAlchemy engine (driver: `asyncpg`) for event-loop friendly I/O.
    - `echo=False` : Keeps SQL logging off in production  (enable when debugging)
    - `pool_pre_ping=True` : Pings a connection before checkout to avoid stale-connection errors after network hiccups or DB restarts.
    - `connect_args={"server_settings": {"search_path": ...}}` : Sets `search_path` on each connection so queries run against your schema without schema-qualifying identifiers.
  - `async_sessionmaker(bind=_engine, expire_on_commit=False, autoflush=False, autocommit=False)` :
  Creates a factory for `AsyncSession`.
    - `expire_on_commit=False` : Objects remain usable after `COMMIT` (no implicit reload).
    - `autoflush=False` : Prevents surprise flushes; you control `flush()`/`begin()` explicitly.
    - `autocommit=False` : Transactions are explicit (`async with session.begin(): ...`).
  - `get_engine()` : Returns the process-wide async engine. It’s safe to share the engine across coroutines.
  - `get_session() -> AsyncSession` : Returns a *new* async session.

## 3. Async Database Initializer

---

- This method is responsible for initializing the async database.

    ```python
    from core import AsyncDatabase
    from loguru import logger
    from sqlalchemy import text
    import os

    DEFAULT_SCHEMA = os.getenv("DB_SCHEMA", "public")

    async def initialize_async_database():
        logger.info("Starting async database initialization process...")
        
        db = AsyncDatabase()
        Base = db.get_base()
        engine = db.get_engine()

        logger.info("Creating async tables...")
        async with engine.begin() as conn:
            await conn.execute(text(f'CREATE SCHEMA IF NOT EXISTS "{DEFAULT_SCHEMA}"'))
            await conn.run_sync(Base.metadata.create_all)

        logger.info("Async DB initialized.")
    ```

- To run this at startup, I added it to the FastAPI lifespan context manager.

    ```python
    ...

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        logger.info("Starting up the application...")
        try:
            await initialize_async_database()
            logger.info("Async Database initialized successfully.")

            loop = asyncio.get_running_loop()
            await loop.run_in_executor(None, initialize_database)
            logger.info("Sync Database initialized successfully.")
        except Exception as e:
            logger.exception(f"Database initialization failed: {e}")
            raise

    ...
    ```

- To make the async database session easy to use.

    ```python
    from core import Database, AsyncDatabase
    from sqlalchemy.orm import Session
    from sqlalchemy.ext.asyncio import AsyncSession
    from typing import Generator, AsyncGenerator

    ...

    async def get_async_db() -> AsyncGenerator[AsyncSession, None]:
        db = AsyncDatabase().get_session()
        try:
            yield db
        finally:
            await db.close()
    ```

## 4. Changes in Services and APIs

---

### 4.1 Services

- Before

    ```python
    from sqlalchemy.orm import Session
    ...

    class AuthService:
        def __init__(self, db: Session, request: Request):

            ...
    ```

- After

    ```python
    from sqlalchemy.ext.asyncio import AsyncSession
    ...

    class AuthService:
        def __init__(self, db: AsyncSession, request: Request):

            ...
    ```

### 4.2 APIs

- Before

    ```python
    ...

    @auth_router.post("/login", response_model=LoginResponse, summary="User Login")
    def login(request: Request, body: LoginRequest, db: Session = Depends(get_db)):

        ...
    ```

- After

    ```python
    @auth_router.post("/login", response_model=LoginResponse, summary="User Login")
    async def login(request: Request, body: LoginRequest, db: AsyncSession = Depends(get_async_db)):
    ```
