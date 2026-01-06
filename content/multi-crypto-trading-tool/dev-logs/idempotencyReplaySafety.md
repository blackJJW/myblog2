+++
title = "16. Idempotency and Replay Safety for Trade Execution Endpoints"
type = "dev-log"
tags = [
  "trading", "execution", "idempotency", "reliability",
  "fastapi", "sqlalchemy", "postgresql", "distributed-systems",
  "retry", "outbox"
]
weight = 16
+++

Retries are inevitable in a multi-serivce system. HTTP timeouts, worker restarts, and upstream retries can cause the same trade request to arrive more than once. Without idempotency, I risk double-writing trades and corrupting downstream analytics.

## 1. Where idemptency lives in the backend

---

This is pseudo code sample of my currenct project.

```python
# router: /internal-api/conione-worker/public/trades
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

-- db: unique constraint ensures replay safety
INSERT INTO tb_trades (...) VALUES (...)
ON CONFLICT (exchange_id, currency_pair_no, trade_id) DO NOTHING;
```

On above case, the router explicitly calls the service with `on_conflict="nothing"` so duplicate