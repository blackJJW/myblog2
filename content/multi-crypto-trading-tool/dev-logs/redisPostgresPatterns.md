+++
title = "22. Redis + Postgres patterns for market data caching and persistence"
type = "dev-log"
tags = ["redis", "postgres", "caching", "persistence", "market-data", "fastapi"]
weight = 22
+++

Market data is high-volume and time-sensitive. In this project, I separate concerns:

- `Redis`: short-lived, fast access (API key cache, hot lookups)
- `Postgres`: durable storage for trades, orderbooks, and metadata

This post documents the current patterns with concrete code from the repo.

## 1. Caching: Redis for hot paths

---

The internal worker endpoint caches exchange API keys so the worker doesn’t hit `Postgres` repeatedly:

```python
# backend/src/internal_api/coinone_worker_router.py

@coinone_worker_router.get("/api-keys/{user_id}")
async def get_api_keys(user_id: str, db: AsyncSession = Depends(get_async_db)):
    redis_manager = RedisClientManager()
    cache_key = f"api_keys:{user_id}"

    cached = await redis_manager.get_api_keys(cache_key)
    if cached:
        logger.info(f"Cache hit for user_id={user_id}")
        return cached

    logger.info(f"Cache miss for user_id={user_id}, fetching from DB")
    keys = await ExchangeAPIKeyService(db).get_api_key_for_worker(...)
    await redis_manager.set_api_keys(cache_key, keys, ttl=settings.REDIS_API_KEY_TTL)
    return keys
```

That gives low-latency reads with a bounded TTL.

The Redis cache service logs failures but doesn’t block the request.

```python
# backend/src/services/redis_cache_service.py

async def get_api_keys(self, key: str):
    try:
        return await self.client.get(key)
    except Exception as e:
        logger.error(f"Redis get_api_keys failed for key={key}: {e}")
        return None
```

## 2. Persistence: Postgres for trades and orderbooks

---

Trades are stored in `Postgres` with a natural unique key for replay safety:

```python
# backend/src/models/trades.py

UniqueConstraint(
    "exchange_id", "currency_pair_no", "trade_id", name="uq_trade_unique"
)
```

The ingestion service uses a bulk upsert with `ON CONFLICT DO NOTHING`:

```python
# backend/src/services/trades_service.py

upsert_stmt = insert_stmt.on_conflict_do_nothing(
    index_elements=[
        Trades.exchange_id,
        Trades.currency_pair_no,
        Trades.trade_id,
    ]
).returning(Trades.trade_id)
```

This means:

- Duplicates are skipped.
- Replays are safe.
- Inserts stay fast even under retries.

## 3. Orderbook snapshots: idempotency + compact storage

---

Orderbook ingestion uses a two-table layout (snapshot header + price levels), and both inserts are replay-safe via `ON CONFLICT DO NOTHING`.

Snapshot insert:

```python
# backend/src/services/orderbook_service.py

pg_insert(OrderBookSnapshot).on_conflict_do_nothing(
    index_elements=["exchange_id", "currency_pair_no", "server_time_ms", "sequence_id"]
)
```

Level insert (unique within a snapshot):

```python
pg_insert(OrderBookLevel).on_conflict_do_nothing(
    index_elements=["snapshot_id", "side", "level_index"]
)
```

This design is replay-safe and keeps historical snapshots intact for analysis, while storing levels efficiently as rows instead of duplicating full snapshots per update.
