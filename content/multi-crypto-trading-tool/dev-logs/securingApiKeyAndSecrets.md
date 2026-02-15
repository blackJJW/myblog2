+++
title = "18. Securing API keys and secrets with Pydantic settings + .env"
type = "dev-log"
tags = ["fastapi", "pydantic", "settings", "dotenv", "security", "jwt", "encryption"]
weight = 18
+++

Secrets are easy to leak when the project grows. In this backend, I keep configuration and credentials centralized in a Pydantic `Settings` class and load them from `.env`. API keys are encrypted at rest, and JWT secrets never live in code.

This post documents the exact pattern used in this repo.

## 1. Centralized config with Pydantic settings

---

All secrets are defined once in `Settings` and imported through a single `settings` instance:

```python
# backend/src/core/config.py

from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    REDIS_HOST: str
    REDIS_PORT: int
    POSTGRES_HOST: str
    POSTGRES_PORT: int
    POSTGRES_USER: str
    POSTGRES_PASSWORD: str
    POSTGRES_DB: str
    SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    FRONTEND_HOST: str
    FRONTEND_DEV_PORT: int
    SYMMETRIC_KEY: str
    REDIS_API_KEY_TTL: int

    model_config = SettingsConfigDict(env_file=".env")

settings = Settings()
```

This gives a single source of truth for runtime secrets and avoids sprinkling `os.getenv()` reads across the codebase.

## 2. `.env` holds only secrets and runtime config

---

The `.env` file stores credentials and private keys and is not committed.

Typical values:

```dotenv
POSTGRES_USER=postgres
POSTGRES_PASSWORD=...
POSTGRES_DB=trading_tool_db
SECRET_KEY=...
SYMMETRIC_KEY=... # base64
```

Pydantic loads these at startup, so secrets stay out of code and out of Git history.

## 3. JWT and auth secrets are injected from settings

---

JWT signing uses `settings.SECRET_KEY`:

```python
# backend/src/core/security.py

encoded_jwt = jwt.encode(
    to_encode, 
    settings.SECRET_KEY, 
    algorithm=settings.JWT_ALGORITHM
)
```

TThis keeps token signing keys out of the codebase and allows rotation by updating environment variables (and redeploying) without changing application code.

## 4. API keys are encrypted at rest

---

API keys submitted by users are encrypted before they are stored:

```python
# backend/src/services/exchange_api_key_service.py

public_key_enc = encrypt_data(public_key, settings.symmetric_key_bytes)
private_key_enc = encrypt_data(private_key, settings.symmetric_key_bytes)
```

`SYMMETRIC_KEY` is stored as a base64-encoded value in `.env` and decoded at runtime:

```python
# backend/src/core/config.py

@property
def symmetric_key_bytes(self) -> bytes:
    return base64.b64decode(self.SYMMETRIC_KEY)
```

Encryption uses AES-GCM, so the stored values remain protected even if the database is compromised.
