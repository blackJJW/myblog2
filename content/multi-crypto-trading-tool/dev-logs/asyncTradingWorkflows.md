+++
title = "23. Async trading workflows: handling long‑running tasks and retries"
type = "dev-log"
tags = ["async", "fastapi", "trading", "retries", "long-running", "workflow"]
weight = 23
+++

Trading backends rarely run only "fast" requests. Market data ingestion, reconciliation jobs, and downstream calls can all be long-running or flaky. In this project, I lean on async workflows, explicit retries, and idempotent writes to keep things safe and responsive.

This post documents the current patterns and the direction for larger async jobs.

## 1. Async everywhere, with clean lifecycle management

---

The FastAPI app uses an async lifespan to initialize and shut down shared dependencies:

```python
# backend/src/app_factory.py

@asynccontextmanager
async def lifespan(app: FastAPI):
    await initialize_async_database()
    app.state.http_client = build_http_client()
    await RedisClientManager().init()
    yield
    await app.state.http_client.aclose()
    await app.state.redis.close()
```

This ensures shared async resources are initialized once and reused across requests.

## 2. Long-running ingestion is split into small chunks

---

Market data ingestion is processed in bulk, but chunked to avoid long transactions and memory spikes.

```python
# backend/src/services/trades_service.py

async def ingest_payload(..., chunk_size: int = 1000, on_conflict: str = "nothing"):
    inserted = await self._bulk_upsert(..., chunk_size=chunk_size)
```

Chunking keeps the workflow predictable even when payloads get large, and it reduces the blast radius of failures (only the current chunk is affected).

## 3. Retry logic is explicit and bounded

---

For upstream calls (Go worker), retries are bounded and exponential backoff:

```python
# backend/src/utils/go_worker.py

async def fetch_go_worker_json(..., retries=1, backoff=0.2):
    for attempt in range(retries + 1):
        try:
            resp = await client.get(url)
        except httpx.HTTPError:
            if attempt < retries:
                await asyncio.sleep(backoff * (2 ** attempt))
                continue
            raise HTTPException(status_code=502, ...)
```

Key rules:

- Retry only on network errors and upstream 5xx responses.
- Don’t retry on 4xx (bad requests, auth failures) or invalid payloads (decode/shape errors).
- Never allow infinite retries: retries are bounded and failures surface clearly.

## 4. Idempotency protects retries and replays

---

Retries are safe because writes are idempotent:

- Trades use `ON CONFLICT DO NOTHING` on a natural unique key (e.g., `exchange_id + currency_pair_no + trade_id`).
- Orderbook snapshots use conflict keys (e.g., `(exchange_id, currency_pair_no, server_time_ms, sequence_id)`), and levels are also conflict-safe per snapshot.
- Services return deterministic summaries (`attempted / inserted / skipped`) so retries remain observable.

That means even if the same batch is processed twice (or two workers race), the database state stays consistent.
