+++
title = "3. Logger Configuration"
type = "Projects"
tags = [
  "python", "uv", "loguru", "logger", "logging",
  "FastAPI", "Uvicorn", "singleton", "log-rotation", "backend"
]
+++

For operating this project reliably, I need a robust logging system. So I decided the `Loguru` library for its simplicity and powerful features. The configuration was customized to meet the following requirements:

1. Custom Log Formatting
    Example:

    ```text
    2025-06-26 23:09:24 | INFO     | main                :lifespan       :16   - Starting up the application...
    ```

2. Persistent Log Files
    - Save logs using filenames that include the current date.
    - Retain logs for 7 days only.
3. Integration with FastAPI and Uvicorn Logs
    - Ensure logs from `FastAPI`, `Uvicorn`, and `Starlette` are captured uniformly

## 1. Pseudocode Summary

---

```text
IF LogConfigurator not configured:
    - Create log directory
    - Remove default handlers
    - Add colored console logger
    - Add rotating file logger
    - Setup InterceptHandler for uvicorn/starlette/fastapi loggers
    - Mark as configured
```

## 2. How I Configured the Logger

---

- To satisfy the logging requirements mentioned above, I built a singleton `LogConfigurator` using `Loguru`, which includes:

### 2.1 Installing loguru

- First, install `Loguru` using `uv`:

    ```bash
    uv pip install loguru
    ```

### 2.2 Singleton Pattern

- I wanted to ensure that the logger is configured only **once**, even if multiple modules try to initialize it. The class uses a standard `__new__` pattern to maintain a single instance.

    ```python
    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    ```

### 2.3 Log File Management

- Each log file is automatically named using the current date and saved under `/backend/logs`. I use Loguru's built-in **rotation** and **retention** to:
  - Create a new file every day at midnight
  - Retain logs only for 7 days
  - Avoid manual cleanup

    ```python
    logger.add(
        str(self.log_file),
        rotation="00:00",       # Daily rotation
        retention="7 days",     # Keep logs for 7 days
        encoding="utf-8",
        level="INFO",
        ...
    )
    ```

### 2.4 Console Output with Colors

- Loguru's `colorize=True` option lets me apply colors to console logs, improving readability during development.

    ```python
    logger.add(
        sys.stdout,
        level="INFO",
        colorize=True,
        format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name: <20}</cyan>:<cyan>{function: <15}</cyan>:<cyan>{line: <4}</cyan> - <level>{message}</level>",
    )
    ```

### 2.5 Intercepting FastAPI/Uvicorn Logs

- By default, FastAPI and Uvicorn use the built-in logging module. To unify all logs under Loguru, I wrote a custom `InterceptHandler` which:
  - Captures standard logging logs
  - Redirects them to Loguru with correct context (function name, line number, etc.)

    ```python
    logging.basicConfig(
        handlers=[InterceptHandler()],
        level=logging.INFO,
        force=True
    )
    ```

- I explicitly intercept common loggers:

    ```python
    loggers_to_intercept = [
        "uvicorn", "uvicorn.access", "uvicorn.error",
        "fastapi", "starlette", "starlette.routing",
    ]
    ```

### 2.6 Execution Outputs

![log file Output](/images/projects/mcttool/3-1.png)
![log file content Output](/images/projects/mcttool/3-2.png)

---

This setup ensures that all logs—whether they come from my own modules or external frameworks—are managed consistently, well-formatted, and stored efficiently.
