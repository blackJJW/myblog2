+++
title = "20. Designing resilient exchange adapters (rate limits, errors, retries)"
type = "dev-log"
tags = ["trading", "exchange", "resilience", "httpx", "retries", "rate-limits", "fastapi"]
weight = 20
+++

Exchange APIs are noisy and unpredictable. A REST client adapter has to survive timeouts, bursty traffic, bad payloads, and temporary upstream failures without corrupting data or overwhelming the system.

This post outlines the baseline approach in this project and the patterns I'm standardizing for exchange adapters.

## 1. The shape of an adapter in this project

---

In this backend, exchange data is fetched via a Go worker, and the FastAPI service acts as a gateway and ingestor:

`FastAPI router` -> `fetch_go_worker_json` -> `service ingestion` -> `DB`

That means resilience is split into two layers:

- HTTP client behavior (timeouts, retries, connection limits)
- Service ingestion (validation, idempotent writes, error mapping)

## 2. Timeouts and connection limits

---

The HTTP client is centralized so every adapter call shares the same defaults:

```python
# backend/src/infra/http_client.py

DEFAULT_TIMEOUT = httpx.Timeout(connect=1.0, read=5.0, write=3.0, pool=1.0)
DEFAULT_LIMITS = httpx.Limits(max_connections=100, max_keepalive_connections=20)
```

This protects the service from slow upstreams while keeping overall concurrency predictable.

## 3. Retry + backoff for transient failures

---

The helper used by adapters includes retries with exponential backoff:

```python
# backend/src/utils/go_worker.py

async def fetch_go_worker_json(..., retries=1, backoff=0.2):
    for attempt in range(retries + 1):
        try:
            resp = await client.get(url)
        except httpx.HTTPError:
            if attempt < retries:
                await asyncio.sleep(backoff * (2**attempt))
                continue
            raise HTTPException(status_code=502, ...)

        if 500 <= resp.status_code < 600 and attempt < retries:
            await asyncio.sleep(backoff * (2**attempt))
            continue

```

Rules:

- Retry only on network errors or upstream 5xx responses.
- Don't retry on most 4xx (bad request, auth failures).
- Treat rate limits(e.g., 429) as a separate policy (respect `Retry-After` or apply a capped backoff).
- Always bubble up a meaningful HTTP error to the caller.

## 4. Strict payload validation

---

Even if a request succeeds, the payload can still be malformed. This helper enforces basic shape checks:

```python
if expected is not None and not isinstance(payload, expected):
    raise HTTPException(status_code=502, detail="Unexpected payload shape")
```

Then the service layer re-validates and normalizes the payload before inserting it into the database.

This protects the DB from poisoned data, which matters for trade and orderbook ingestion.

## 5. Rate limits: what exists and what's next

---

Rate limiting is mostly handled upstream (the Go worker). On the FastAPI side, I already have:

- a shared HTTP client
- conservative timeouts
- retry backoff

Planned additions for stronger rate limit protection:

- per-exchange throttles (e.g., a token bucket per API key)
- adaptive backoff when receiving 429 (respect `Retry-After` when available)
- cache + de-duplication for high-frequency endpoints (orderbooks, trades)

## 6. Error handling that doesn't leak upstream chaos

---

The adapter layer converts upstream failures into explicit, consistent HTTP errors:

- `502 Bad Gateway` for upstream connectivity failures, timeouts, invalid JSON, or unexpected payload shapes
- Selected upstream status codes are preserved when they carry meaning (e.g., `401/403` for auth, `429` for rate limits); otherwise, errors are normalized to `502/503`

This keeps downstream services predictable and prevents transient upstream issues from turning into silent data corruption.
