+++
title = "5. Database Connection Management"
type = "Projects"
tags = ["python", "SQLAlchemy"]
+++

In this section, I'll explain how I configured `SQLAlchemy` for managing database connections and sessions in a reusable and scalable way.

## 1. Purposes of this Management

- Use `SQLAlchemy` for ORM-based database interaction
- Create a reusable engine and session maker

### Why SQLAlchemy?

I chose SQLAlchemy because it is one of the most powerful and flexible ORM libraries in Python. It allows me to:

- Interact with the database using Python classes instead of raw SQL
- Write reusable, composable queries using the SQL Expression Language
- Manage sessions, transactions, and connection pooling efficiently
- Support multiple database backends (e.g., PostgreSQL, SQLite, MySQL)

This flexibility makes it ideal for a project like this where maintainability and scalability are important.

## 2. Class: Database

- The `Database` class is responsible for initializing the SQLAlchemy engine, createing a session factory, and exposing a centralized declarative base for defining ORM models.

    ```python
    from sqlalchemy import create_engine
    from sqlalchemy.ext.declarative import declarative_base
    from sqlalchemy.orm import sessionmaker
    from .config import settings

    class Database:
        """Database connection and session management."""
        
        Base = declarative_base()
        
        def __init__(self):
            self._engine = create_engine(settings.db_url, pool_pre_ping=True)
            self._SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self._engine)
        
        def get_engine(self):
            """Returns the SQLAlchemy engine."""
            return self._engine
        
        def get_session(self):
            """Returns a new session."""
            return self._SessionLocal()
        
        @classmethod
        def get_base(cls):
            """Returns the declarative base class."""
            return cls.Base
    ```

  - `create_engine()` : Initializes the DB engine the URL from `BaseSettings`(settings.db_url)
  - `sessionmaker()` : Builds a session factory with common options
  - `pool_pre_ping=True` : Ensures connections are alive before use (avoids DB timeout errors)

## 3. Usage Example

- To create a new session inside a service or route handler, simply do:

    ```python
    db = Database()
    session = db.get_session()
    ```

- The `Base` attribute is exposed via `get_base()` so that model classes can inherit from a centralized declarative base:

    ```python
    Base = Database.get_base()

    class User(Base):
    ```
