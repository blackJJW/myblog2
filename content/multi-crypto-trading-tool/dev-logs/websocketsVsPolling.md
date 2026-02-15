+++
title = "21. WebSockets vs polling for live price updates in crypto apps"
type = "dev-log"
tags = ["crypto", "websocket", "polling", "real-time", "trading", "architecture"]
weight = 21
+++

Live price updates are the heartbeat of a crypto app. The question isn't "real-time or not," but how to deliver updates reliably: WebSockets, polling, or a hybrid.

This post compares both approaches and frames the choice using the current stack in this project.

## 1. The two delivery models

---

### 1.1 Polling

- The client requests price data every *N* seconds.
- Simple to implement and easy to cache.
- Scales well with stateless HTTP.

### 1.2 WebSockets

- The server pushes updates continuously.
- Lower latency and smoother UI.
- Requires persistent connections and additional infrastructure.

## 2. What polling looks like in this repo

---

In this repo, the backend exposes polling-style endpoints that fetch data from the Go worker and persist it.

```python
# backend/src/internal_api/coinone_worker_public_api_router.py

@coinone_worker_public_api_router.get("/trades")
async def fetch_trades(
    db: AsyncSession = Depends(get_async_db),
    client: httpx.AsyncClient = Depends(get_http_client),
    quote: str = Query(...),
    target: str = Query(...),
):
    q, t = norm(quote), norm(target)
    url = f"{GO_WORKER_BASE}/api/public/trades/{urlquote(q)}/{urlquote(t)}"
    payload = await fetch_go_worker_json(client, url, expected=dict, retries=1)

    svc = TradesService(db)
    summary = await svc.ingest_payload(
        exchange_name=DEFAULT_EXCHANGE,
        quote_currency=q,
        target_currency=t,
        payload=payload,
        chunk_size=1000,
        on_conflict="nothing",
    )

    return JSONResponse(content={**summary, "persisted": True})
```

This is a classic polling workflow: HTTP request -> fetch -> validate -> store.

## 3. Reliability features baked into polling

---

The HTTP client is configured with explicit timeouts and connection limits:

```python
# backend/src/infra/http_client.py

DEFAULT_TIMEOUT = httpx.Timeout(connect=1.0, read=5.0, write=3.0, pool=1.0)
DEFAULT_LIMITS = httpx.Limits(max_connections=100, max_keepalive_connections=20)

def build_http_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        http2=True,
        timeout=DEFAULT_TIMEOUT,
        headers={"Accept": "application/json"},
        limits=DEFAULT_LIMITS,
    )
```

Retries and backoff are handled in the fetch helper:

```python
# backend/src/utils/go_worker.py

async def fetch_go_worker_json(..., retries=1, backoff=0.2):
    for attempt in range(retries + 1):
        try:
            resp = await client.get(url)
        except httpx.HTTPError as e:
            if attempt < retries:
                await asyncio.sleep(backoff * (2 ** attempt))
                continue
            raise HTTPException(status_code=502, detail=f"go-worker http error: {e}")

        if 500 <= resp.status_code < 600 and attempt < retries:
            await asyncio.sleep(backoff * (2 ** attempt))
            continue
```

This makes polling resilient without requiring special logic on the client side.

## 4. What WebSockets would change

---

If I add WebSockets later, the data flow shifts from request/response to server push:

- Exchange stream -> server -> client
- The backend must manage connection state, replay, and incremental updates (deltas).

At that point, the ingestion logic above still matters, but the delivery pipeline changes:

- pushing deltas (not full snapshots)
- tracking sequence IDs for replay
- handling reconnects using a "since" cursor (or a last-seen sequence ID)

## 5. When polling is still the right choice

---

Polling is a great baseline when:

- you want a simple, reliable UI
- you don’t have streaming infrastructure yet
- you want to reuse existing REST endpoints (and benefit from caching)

In this repo, polling already fits the ingestion model, so it's the natural starting point.
