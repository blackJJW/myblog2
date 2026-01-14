+++
title = "16. Idempotency and Replay Safety for Trade Execution Endpoints"
type = "dev-log"
tags = [
  "trading", "execution", "idempotency", "reliability",
  "fastapi", "sqlalchemy", "postgresql",
  "distributed-systems", "retry"
]
weight = 16
+++

Retries are inevitable in a multi-service system. HTTP timeouts, worker restarts, and upstream retries can cause the same trade ingestion payload to arrive more than once. Without idempotency, I risk double-writing trades and corrupting downstream analytics.

## 1. Where idempotency lives in the backend

---

Below is simplified pseudocode that reflects my current flow:

```python
# router: /internal-api/coinone-worker/public/trades
@router.get("/trades")
async def fetch_trades(quote, target, db, http_client):
    payload = await fetch_go_worker_trades(http_client, quote, target)
    summary = await TradesService(db).ingest_payload(
        exchange_name="coinone",
        quote_currency=quote,
        target_currency=target,
        payload=payload,
        on_conflict="nothing",
    )
    return summary

# service: TradesService.ingest_payload
async def ingest_payload(exchange_name, quote_currency, target_currency, payload, on_conflict):
    exchange_id = ExchangesService(db).get_exchange_id(exchange_name)
    pair_no = CurrencyPairService(db).get_or_create_pair_no(quote_currency, target_currency)

    rows = normalize_transactions(payload, exchange_id, pair_no)  # map & validate
    inserted = bulk_upsert_trades(rows, on_conflict)              # idempotent insert

    return {
        "exchange_id": exchange_id,
        "currency_pair_no": pair_no,
        "inserted": inserted,
        "attempted": len(rows),
        "skipped": len(rows) - inserted,
    }
```

At the database level, a unique constraint provides replay safety.

```sql
INSERT INTO tb_trades (...) VALUES (...)
ON CONFLICT (exchange_id, currency_pair_no, trade_id) DO NOTHING;
```

This makes the endpoint effectively idempotent at the data layer: the same `trade_id` for the same exchange/pair will be inserted at most once.

In this setup, the router explicitly calls the service with `on_conflict="nothing"`, so duplicate trades are safely ignored.

## 2. Data-layer idempotency with a unique trade key

---

The `tb_trades` table enforces a unique constraint on a natural key:

- `exchange_id`
- `currency_pair_no`
- `trade_id`

This guarantees that the same trade cannot be inserted twice.

Conceptually:

```sql
UNIQUE (exchange_id, currency_pair_no, trade_id)
```

When the service ingests trades, it uses a PostgreSQL upsert with `ON CONFLICT DO NOTHING`. This makes replays safe without adding extra duplicate checks in the application layer.

This approach works well as long as `trade_id` is stable and unique per exchange/pair. If an exchange reuses IDs or changes semantics, the idempotency key should be adjusted (e.g., include timestamp or use a canonical hash).

## 3. Service-level replay handling

---

`TradesService` normalizes and validates each payload, then inserts trades in batches. If the payload is replayed:
  
- Duplicates are skipped by the unique constraint.
- The response reports how many rows were inserted vs. skipped.

```python
async def ingest_payload(..., on_conflict="nothing"):
    rows = normalize(payload)            # parse, validate, map to insert rows
    if not rows:
        return {"inserted": 0, "attempted": 0, "skipped": 0}

    inserted = bulk_upsert(rows, on_conflict="nothing")  # ON CONFLICT DO NOTHING
    return {
        "inserted": inserted,
        "attempted": len(rows),
        "skipped": len(rows) - inserted,  # duplicates skipped on replay
    }
```

This produces a clean, deterministic response even under retries because the insert is idempotent and repeated requests return consistent counts without creating duplicate rows.

## 4. Orderbook snapshots use the same pattern

---

Orderbook ingestion follows the same design:

- Snapshot uniqueness is based on (`exchange_id`, `currency_pair_no`, `server_time_ms`, `sequence_id`).
- `ON CONFLICT DO NOTHING` prevents duplicate snapshots.
- Price levels are inserted with a unique key: (`snapshot_id`, `side`, `level_index`).

```python
# Service-level orderbook replay handling (idempotent snapshots + levels)
async def ingest_orderbook(exchange_id, currency_pair_no, payload):
    snapshot = parse_snapshot(payload)

    # 1) idempotent snapshot insert
    snapshot_id = insert_snapshot(
        exchange_id=exchange_id,
        currency_pair_no=currency_pair_no,
        server_time_ms=snapshot.server_time_ms,
        sequence_id=snapshot.sequence_id,
        on_conflict="nothing",
    ) or fetch_existing_snapshot_id(...)

    # 2) idempotent level insert
    level_rows = build_levels(snapshot_id, payload.bids, payload.asks)
    insert_levels(level_rows, on_conflict="nothing")  # (snapshot_id, side, level_index)

    commit()
    return summary(snapshot_id, level_rows)
```

```sql
-- snapshot uniqueness
INSERT INTO tb_orderbook_snapshot (...) VALUES (...)
ON CONFLICT (exchange_id, currency_pair_no, server_time_ms, sequence_id) DO NOTHING;

-- level uniqueness
INSERT INTO tb_orderbook_level (...) VALUES (...)
ON CONFLICT (snapshot_id, side, level_index) DO NOTHING;
```

This approach assumes the exchange provides a stable `(server_time_ms, sequence_id)` pair for snapshots; if not, a different idempotency key (e.g., a payload hash) may be required. Even if the same orderbook payload is replayed, the database remains consistent because duplicates are ignored at both the snapshot and level layers.

## 5. Why this works well for replay safety

---

This pattern works well because it enforces idempotency at the most reliable layer: the database.

- **The unique key is the source of truth.** Even if the application retries, restarts, or runs concurrently, the database guarantees that the same record is inserted at most once.
- **`ON CONFLICT DO NOTHING` removes race conditions.** The insert becomes an atomic operation, so you don’t need a separate “check-then-insert” step in application code.
- **Services stay deterministic.** The service can safely return a consistent summary (`attempted`, `inserted`, `skipped`) under retries without special-case logic.
- **The same idea scales to other datasets.** Trades and orderbook snapshots follow the same replay-safe ingestion design, which keeps the system consistent as more exchanges and endpoints are added.

The key requirement is choosing a stable idempotency key. If an exchange does not provide a reliable natural key (e.g., `trade_id` or `(server_time_ms, sequence_id)`), you should derive one (for example, a canonical hash of the payload).
