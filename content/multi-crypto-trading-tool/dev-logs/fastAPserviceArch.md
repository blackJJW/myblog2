+++
title = "15. FastAPI Service Architecture: Thin Routers, Service Layer, and DTO Patterns"
type = "dev-log"
tags = [
  "fastapi", "backend", "architecture", "layered-architecture",
  "service-layer", "dto", "pydantic", "sqlalchemy",
  "refactoring", "api-design"
]
weight = 15
+++

Compared to previous dev logs, this post is more of a short guideline summarizing the architecture decisions I’m applying across the backend.

As the backend grows, the number of endpoints increases as well. I started to worry that the codebase would become harder to navigate and maintain. To keep the structure clear, I adopted a **layered architecture**: a thin router/controller layer on top of a service layer, with DTOs at the API boundary.

This post outlines a simple, scalable pattern: keep routers thin, move business logic into services, and use DTOs to make API contracts explicit.

## 1. Why thin routers/controllers matter

---

Routers should do only three things:

1. Parse and validate input
2. Call the service layer
3. Return the response (DTO)

They should not contain business logic (e.g., pricing rules) **or** data-access details. This separation keeps endpoints readable, makes responsibilities clear, and improves testability.

## 2. The role of the service layer

---

The service layer is where the actual business logic lives.

A service typically:

- Implements business rules (e.g., validation beyond schema checks, pricing rules, risk limits)
- Orchestrates multiple dependencies (repositories/DAO layer, external APIs, caches)
- Manages transaction boundaries (commit/rollback) and consistency
- Translates low-level errors into domain-level errors
- Returns domain objects or DTO-ready data (without FastAPI-specific concerns)

### 2.1 Service layer boundaries

- Keep services framework-agnostic so they are easy to unit-test.
- Prefer small services with clear responsibilities over a single "god service".

## 3. DTOs make contracts explicit

---

DTOs (Data Transfer Objects) define what enters and leaves the system. In FastAPI, they are typically implemented as Pydantic models.

Using DTOs:

- Enforces strict input/output shapes
- Generates API documentation automatically (OpenAPI/Swagger UI)
- Prevents internal DB models from leaking to the client

DTOs are an API contract. They should remain stable, and you should version them when breaking changes are unavoidable.

### 3.1 Input vs. Output DTOs

- **Input DTOs** validate and normalize user input (e.g., required fields, formats, bounds).
- **Output DTOs** shape the response and hide sensitive/internal fields (e.g., `private_key`, internal IDs).

### 3.2 Mapping layer (DTO ↔ Domain/ORM)

Keep mapping explicit so you can change internal models without breaking the API contract:

- DTO → Domain/Command (service input)
- Domain/ORM → DTO (router response)

This small extra step pays off when you refactor the database schema or introduce new providers/exchanges.

## 4. A minimal flow

---

Router → DTO validation → Service → Repository/Infrastructure → DTO response

This structure provides:

- Testable business logic (service tests don't need HTTP)
- Clear boundaries between the API layer, business logic, and infrastructure
- Easier maintenance and refactoring as the codebase grows

It also makes it easier to manage transactions and swap infrastructure components (e.g., database, cache, external exchange clients) without touching routers.

Below is simplified pseudocode that reflects my current backend flow.

```python
# Note: This is simplified pseudocode to illustrate the layering and data flow.

# Router: validates DTO and delegates to service
# Service: applies business rules and orchestrates dependencies
# DTO: defines API contract (request/response shape)

# backend/src/api/settings_router.py
from fastapi import APIRouter, Depends
from dto.exchanges_dto import ApiKeyCreateRequest, ApiKeyResponse
from services.exchanges_service import register_exchange_api_key

router = APIRouter(prefix="/api/settings", tags=["settings"])

@router.post("/exchange-api-key", response_model=ApiKeyResponse)
async def create_api_key(payload: ApiKeyCreateRequest):
    # 1) validate input (DTO)
    # 2) call service
    result = await register_exchange_api_key(payload)
    # 3) return response DTO
    return ApiKeyResponse.from_domain(result)


# backend/src/services/exchanges_service.py
from infra.exchange_client import ExchangeClient
from models.api_key import ApiKey
from dto.exchanges_dto import ApiKeyCreateRequest

async def register_exchange_api_key(dto: ApiKeyCreateRequest):
    # business rules / orchestration
    client = ExchangeClient()
    if not await client.validate_keys(dto.api_key, dto.secret_key):
        raise ValueError("Invalid API keys")

    api_key = ApiKey.from_dto(dto)
    await api_key.save()
    return api_key


# backend/src/dto/exchanges_dto.py
from pydantic import BaseModel

class ApiKeyCreateRequest(BaseModel):
    exchange: str
    api_key: str
    secret_key: str

class ApiKeyResponse(BaseModel):
    exchange: str
    masked_api_key: str
```

## 5. Common pitfalls

---

- **Business logic in routers**: hard to reuse, hard to test
- **Leaky ORM/DB models**: tightly couples the API to persistence
- **No service layer**: business rules get scattered across unrelated files
- **Async/session misuse**: sharing a session across concurrent tasks, or mixing sync and async sessions
- **DTO drift**: response shapes change unintentionally without versioning or clear contracts

## 6. Suggested folder layout

---

```text
backend/src/
  api/        # routers (FastAPI)
  services/   # business logic
  dto/        # Pydantic request/response models
  models/     # SQLAlchemy ORM models
  infra/      # external clients, adapters, cache, etc.
```

## 7. Takeaways

---

- Keep routers thin and focused on I/O
- Put decisions in services, not in endpoints
- Use DTOs to keep API contracts explicit and stable.
