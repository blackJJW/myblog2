+++
title = "2. Setting Up the Backend"
type = "Projects"
tags = ["python", "uv", "FastAPI"]
+++

## 1. Installing FastAPI

---

- We will use ***FastAPI*** as the backend server framework due to its performance and asynchronous capabilities - it's a better fit than the Flask for real-time and modular systems. Install it along with the ASGI server ***uvicorn*** using `uv`:

    ```bash
    uv pip install "fastapi[all]" uvicorn
    ```

  - `fastapi[all]` : Installs optional dependencies such as:
  - `pydantic`, `httpx`, `python-multipart`, `jinja2`, `email-validator`
  - `uvicorn` : Lightweight ASGI server used to run FastAPI applications

## 2. Setting the Lifespan in FastAPI

---

- To manage startup and shutdown tasks (e.g., initializing connections, cleaning resources), FastAPI provides a ***lifespan*** context manager.

    ```python
    from fastapi import FastAPI
    from contextlib import asynccontextmanager

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        # startup
        print("Starting up")

        yield
        # shutdown
        print("Shutting down")
    
    app = FastAPI(lifespan=lifespan)
    ```

  - This function is called once during the application's lifecycle:
    - Before the first request is processed (startup)
    - After the server shuts down (cleanup)
  - Using ***lifespan()*** is useful for:
    - Performance optimization
    - Test stability (isolated setup/teardown)
    - Clean resource management (DB, queues, sockets)
  - `@asynccontextmanager`: This decorator from the `contextlib` module allows defining an asynchronous context manager using `async def`. It enables setup and cleanup logic around the `yield` statement, and is used here to control the FastAPI application's lifespan events (startup and shutdown).

### 2.1 Execution Output

When running the application with `uv run main.py`, you can see the startup and shutdown messages handled by the `lifespan()` function:

![FastAPI Lifespan Output](/images/projects/mcttool/fastapi_lifespan_output.png)
