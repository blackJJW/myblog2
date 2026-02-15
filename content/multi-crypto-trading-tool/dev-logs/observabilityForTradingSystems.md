+++
title = "19. Observability for trading systems: logging, metrics, and tracing basics"
type = "dev-log"
tags = ["observability", "logging", "metrics", "tracing", "fastapi", "prometheus", "grafana"]
weight = 19
+++

Trading systems are noisy and time-sensitive. When something goes wrong—missed ticks, delayed jobs, failed API calls—you need answers fast. Observability is the safety net: logs for context, metrics for trends, and tracing for end-to-end visibility.

This post documents the baseline observability setup in this repo and how it maps to real production concerns.

## 1. Logging: structured, centralized, and consistent

---

The backend uses `Loguru` as the primary logger, with a custom configurator to capture both `Loguru` logs and standard Python logging.

- `backend/src/core/logging_config.py`

Key points:

- Logs go to stdout for container logs.
- Logs are also written to a daily-rotated file under `backend/logs/`.
- Standard logging is intercepted and routed through `Loguru`.

This keeps logging consistent across routers, services, and middleware.

## 2. Metrics: Prometheus + FastAPI Instrumentator

---

Metrics are exposed using `prometheus_fastapi_instrumentator`:

```python
# backend/src/app_factory.py

Instrumentator().instrument(app).expose(app)
```

This automatically adds:

- request counts
- latency histograms
- status code breakdowns

The Docker Compose stack includes `Prometheus` and `Grafana`:

- docker-compose.yml
  - prometheus
  - grafana
  - provisioning config mounted from monitoring

This lets me visualize API throughput, error rates, and latency patterns during development.

## 3. Tracing: baseline today, hooks for later

---

At the moment, there is no distributed tracing. That's a conscious choice while the system is still evolving.

The code is already structured in a way that makes tracing easy to add later:

- HTTP client lives in `app.state` (single client per process)
- services are thin, with clear boundaries
- middleware already touches request lifecycle

When I introduce tracing, the first steps will be:

- OpenTelemetry middleware for FastAPI
- tracing for outbound HTTP calls to the Go worker
- trace IDs propagated through logs

Even before full tracing, I still treat correlation IDs as a must-have for debugging retries and timeouts.

## 4. What matters most in trading systems

---

For trading workflows, the most valuable signals are:

- **Latency**: time from market-data fetch → DB insert (end-to-end ingestion latency)
- **Error rate**: failed fetches, bad payloads, and database errors
- **Event volume**: number of ticks ingested per minute
- **Cache hit ratio**: Redis API key lookups (worker endpoints)

This project already logs many of those events; the next step is to turn the key ones into metrics.
