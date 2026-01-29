+++
title = "17. Testing Async Services in FastAPI: pytest‑asyncio Fixtures and Mocks"
type = "dev-log"
tags = ["fastapi", "pytest", "pytest-asyncio", "testing", "async", "mocking", "sqlalchemy"]
weight = 17
+++

As the backend moved to async services, I needed tests that were both fast and reliable. The goal was simple: validate service logic without spinning up an HTTP server or relying on external dependencies. This post documents the patterns that work well in this codebase: `pytest-asyncio` fixtures for async SQLAlchemy sessions and targeted mocks for service dependencies.

## 1. Enable async tests with pytest-asyncio

---

This repo uses `pytest-asyncio` in auto mode:

```ini
# backend/pytest.ini
[pytest]
asyncio_mode = auto
```

This enables async tests without extra boilerplate. You can use `@pytest.mark.asyncio` when needed, and async fixtures (e.g., `async_db_session`) run naturally.

## 2. Async DB fixture (real schema, isolated session)

---

For integration-level service tests, I use a real async SQLAlchemy session and create the schema before running tests. The fixture lives in `backend/src/tests/conftest.py`:

```python
@pytest.fixture
async def async_db_session() -> AsyncGenerator[AsyncSession, None]:
    engine = create_async_engine(settings.async_db_url, echo=False, future=True)
    async_session = async_sessionmaker(bind=engine, expire_on_commit=False)

    async with engine.begin() as conn:
        await conn.run_sync(AsyncDatabase.get_base().metadata.create_all)

    async with async_session() as session:
        yield session
        await session.rollback()

    await engine.dispose()
```

This gives each test a clean async session while keeping the tests fast.

If a test commits data, I either run it inside an explicit transaction per test or reset the schema between tests.

## 3. Mocking service dependencies for unit-style tests

---

Some services depend on other services or external utilities. Instead of pulling those dependencies into the test, I mock them with `AsyncMock` so the test stays focused on the service logic.

Example from `AuthService`:

```python
# backend/src/tests/services/test_auth_service.py

with patch("services.auth_service.UserService") as MockUserService, \
    patch("services.auth_service.UserLoginLogService") as MockLoginLogService, \
    patch("services.auth_service.verify_password", return_value=True):

    mock_user_service = MockUserService.return_value
    mock_user_service.get_user_by_id = AsyncMock(return_value=dummy_user)

    mock_log_service = MockLoginLogService.return_value
    mock_log_service.log_login_attempt = AsyncMock()

    auth_service = AuthService(db=MagicMock(), request=mock_request)
    user = await auth_service.authenticate_user("testuser", "correct_password")

```

This validates authentication flow without touching the database.
The key idea is to `mock boundaries` (other services, crypto helpers, external clients) rather than mocking the unit under test itself.

## 4. Mocking `AsyncSession` for pure unit tests

---

For service methods that mostly build SQL statements and manage transactions, I use a mocked `AsyncSession`:

```python
# backend/src/tests/services/test_range_units_service.py

@pytest.fixture
def mock_db():
    db = MagicMock(spec=AsyncSession)
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    return db
```

This lets me assert:

- how many times `execute()` was called
- whether `commit()` was called
- how cancellation is handled (e.g., raising `asyncio.CancelledError`)

This is useful for unit tests, but it does not validate real SQL behavior-use the real async DB fixture for integration-level coverage.
