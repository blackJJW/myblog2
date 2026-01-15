+++
title = "17. Testing Async Services in FastAPI: pytest‑asyncio Fixtures and Mocks"
type = "dev-log"
tags = ["fastapi", "pytest", "pytest-asyncio", "testing", "async", "mocks", "sqlalchemy"]
weight = 17
+++

As the backedn moved to async services, I needed tests that were both fast and reiliable. The goal was simple: validate service logic without spinning up an HTTP server or relying on external dependencies. This post documents the patterns that work well in this codebase: `pytest-asyncio` fixtures for async SQLAlchemy sessions and targeted mocks for service dependencies.

## 1. Enable async tests with pytest-asyncio

---

This repo uses `pytest-asyncio` in auto mode:

```ini
# backend/pytest.ini
[pytest]
asyncio_mode = auto
```

This enables async tests without extra boilerplate. You can use `@pytest.mark.asyncio` when needed, and async fixtures(e.g., `async_db_session`) run naturally.





## 2. Async DB fixture (real schema, isolated session)

For integration-level service tests, I use a real async SQLAlchemy session with a temporary schema setup. The fixture in backend/
src/tests/conftest.py:

- backend/src/tests/conftest.py

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

This gives each test a clean async session while keeping the tests fast.

## 3. Mocking service dependencies for unit‑style tests

Some services depend on other services or external utilities. Instead of pulling in those dependencies, I mock them with AsyncMock
to keep the tests focused.

Example from AuthService:

- backend/src/tests/services/test_auth_service.py

with patch("service.auth_service.UserService") as MockUserService, \
    patch("service.auth_service.UserLoginLogService") as MockLoginLogService, \
    patch("service.auth_service.verify_password", return_value=True):

    mock_user_service = MockUserService.return_value
    mock_user_service.get_user_by_id = AsyncMock(return_value=dummy_user)

    mock_log_service = MockLoginLogService.return_value
    mock_log_service.log_login_attempt = AsyncMock()

    auth_service = AuthService(db=MagicMock(), request=mock_request)
    user = await auth_service.authenticate_user("testuser", "correct_password")

This validates authentication logic without touching the database.

## 4. Mocking AsyncSession for pure unit tests

For service methods that are mostly SQL composition and transaction logic, I use a mocked AsyncSession:

- backend/src/tests/services/test_range_units_service.py

@pytest.fixture
def mock_db():
    db = MagicMock(spec=AsyncSession)
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    return db

This lets me assert:

- how many times execute() was called
- whether commit() happens
- how cancellation is handled (e.g., asyncio.CancelledError)

## 5. Mixing both styles where it makes sense

In this project:

- Async DB fixture is used for tests that validate DB behavior end-to-end.
- Mocked sessions are used for fast unit tests and edge cases (cancelled tasks, invalid payloads, etc).
- Service mocks isolate dependencies in services like AuthService.

This hybrid approach keeps the test suite fast but still trustworthy.

## 6. Practical tips that helped

- Use asyncio_mode = auto so test discovery is simple.
- For async mocks, always use AsyncMock (not MagicMock).
- Keep service logic thin and deterministic so it’s easy to mock dependencies.