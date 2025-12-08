+++
title = "14. Makefile Setup"
type = "dev-log"
tags = [
  "makefile", "automation", "tooling", "developer-experience",
  "python", "uv", "fastapi", "react", "npm", "monorepo"
]
weight = 14
+++

This project consists of multiple languages, so each one has its own set of commands. I often mix them up. To address this, I decided to add a `Makefile` for each language. Using Makefiles helps keep command execution consistent across languages.

## 1. Makefile in the Backend

---

- This `Makefile` is for Python with `uv`.

    ```Makefile
    # basic target
    .PHONY: run freeze test

    # Start FastAPI server
    run:
        uv run src/main.py

    # Update requirements.txt
    freeze:
        uv pip freeze > requirements.txt
    
    test:
        PYTHONPATH=./src uv run -m pytest
    ```

## 2. Makefile in the Frontend

---

- This `Makefile` is for React with `npm`.

    ```Makefile
    .PHONY: run install build

    install:
        npm ci
    
    build:
        npm run build
    
    run:
        npm run dev
    ```

## 3. Usage Examples

---

### 3.1 Backend (Python + uv)

- Start the API server:

    ```bash
    cd backend
    make run
    ```

- Update requirements.txt from the current environment.

    ```bash
    cd backend
    make freeze
    ```

### 3.2 Frontend (React + npm)

- Start the dev server:

    ```bash
    cd frontend
    make run
    ```
