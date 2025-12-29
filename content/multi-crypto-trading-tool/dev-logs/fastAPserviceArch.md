+++
title = "15. FastAPI Service Architecture: Thin Routers, Service Layer, and DTO Patterns"
type = "dev-log"
tags = [
  "fastapi", "backend", "architecture", "layered-architecture",
  "service-layer", "dto", "pydantic", "sqlalchemy", "refactoring",
  "dependency-injection", "dev-log"
]
weight = 15
+++

As the backend grows, the number of endpoints increases as well. I started to worry that the codebase would become harder to navigate and maintain. To keep the structure clear, I adopted a **layered architecture**: a thin router/controller layer on top of a service layer, with DTOs at the API boundary.

This post outlines a simple, scalable pattern: keep routers thin, move business logic into services, and use DTOs to make API contracts explicit.

## 1. Why "thin routers/controllers" matter

---

Routers should do only three things:

  1. Parse and validate input
  2. Call the service layer
  3. Return the response (DTO)

They should not contain business logic (e.g., pricing rules), data-access details. This separation keeps endpoints readable, makes responsibilities clear, and improves testability.

  ———



  ———

  ### The role of the service layer

  The service layer is where your actual business rules live. Think “what the app does” rather than “how HTTP works.”

  Examples:

  - Validate trading constraints
  - Compute order parameters
  - Call exchange clients
  - Coordinate multiple infrastructure calls

  This keeps services reusable beyond HTTP — they can be used by workers, scheduled jobs, or CLI tasks.

  ———

  ### DTOs make contracts explicit

  DTOs (Data Transfer Objects) represent what enters and leaves your system. Using Pydantic models:

  - Enforces strict input/output shapes
  - Documents your API automatically
  - Avoids leaking internal DB models to the client

  DTOs are a contract. They should be stable and versioned if needed.

  ———

  ### A minimal flow

  Router → DTO validation → Service → Repository/Infra → DTO response

  You get:

  - Testable business logic (service tests don’t need HTTP)
  - Clear boundaries between API, core logic, and infrastructure
  - Easier maintenance as teams grow

  ———

  ### Common pitfalls

  - Business logic in routers: hard to reuse, hard to test
  - Leaky DB models: tightly couples API and persistence
  - No service layer: logic spread across random files

  ———

  ### Suggested folder layout

  backend/src/
    api/
    service/
    dto/
    models/
    infra/

  This layout keeps responsibilities obvious and prevents the “everything in endpoints.py” trap.

  ———

  ### Closing thoughts

  FastAPI makes it easy to ship quickly — but structure is what keeps you shipping cleanly six months later. Thin routers, a service
  layer, and explicit DTOs give you the best balance of speed and long‑term clarity.

  If you want, I can adapt this draft to your exact project (e.g., trade execution, market data ingestion, or auth flows).