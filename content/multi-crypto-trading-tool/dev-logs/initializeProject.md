+++
title = "1. Project Initialization"
type = "dev-log"
tags = [
  "Docker", "Docker-compose", "Dockerfile",
  "bash", "python", "uv", "FastAPI", "RQ",
  "node", "vite", "react",
  "PostgreSQL", "Redis", "dotenv",
  "project-setup", "fullstack", "monorepo"
]
+++

In fact, I had been working on a similar project for some time. Although I tried to complete it, I eventually gave up because it was too complex and inefficient to move forward with. So I decided to restart the project from scratch.

## 1. Project Tech Stack

---

|Area|Tech|
|---|---|
|Backend|Python(FastAPI), Redis, Redis Queue(RQ), PostgreSQL|
|Frontend|React + Vite|
|Infra|Docker, Docker Compose, .env, .yml|

## 2. Backend Settings

---

### 2.1 backend.DockerFile

- This DockerFile installs backend system dependencies and Python packaging tool(uv) for the Python 3.12.11 environment.

    ```DockerFile
    # Docker Base Image
    FROM python:3.12.11-bookworm

    # Set environment variables
    ENV DEBIAN_FRONTEND=noninteractive
    ENV TZ=Asia/Seoul

    WORKDIR /backend

    # Install system dependencies
    RUN apt-get update && \
        apt-get upgrade -y && \
        apt-get install -y --no-install-recommends \
            tzdata \
            software-properties-common \
            zlib1g-dev build-essential \
            git vim wget tmux \
            libncurses5-dev libgdbm-dev libnss3-dev libssl-dev \
            libreadline-dev libffi-dev libsqlite3-dev libbz2-dev \
            libpq-dev postgresql-client \
            libcairo2-dev pkg-config \
            libdbus-1-dev \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

    # Install uv (Python packaging and dependency resolver)
    RUN curl -Ls https://astral.sh/uv/install.sh | sh
    ```

- **System & Build Packages**
  - `tzdata`: Sets timezone inside the container (important for logs and scheduling).
  - `software-properties-common`: Provides `add-apt-repository` command for managing PPAs.
  - `zlib1g-dev`: Required for compression modules like `zlib` in Python.
  - `build-essential`: Includes core development tools like `gcc`, `g++`, and `make`.

- **Development Tools & Utilities**
  - `git`: Version control system used to manage source code.
  - `vim`, `tmux`: CLI-based text editor and terminal multiplexer for development.
  - `wget`: Command-line tool for downloading files from the internet.

- **Python Build Dependencies**
  - `libncurses5-dev`: Enables terminal interface features used in Python (`curses`).
  - `libgdbm-dev`: Supports GNU DBM (key-value store used by `dbm` module).
  - `libnss3-dev`: Provides cryptographic services via NSS.
  - `libssl-dev`: Required for SSL/TLS support (`ssl` and `hashlib` modules).
  - `libreadline-dev`: Enables command-line editing in interactive shells like Python REPL.
  - `libffi-dev`: Supports calling compiled C code (used in `ctypes`, `cffi`).
  - `libsqlite3-dev`: Provides SQLite support used by Python's built-in `sqlite3`.
  - `libbz2-dev`: Enables `bz2` compression module.

- **PostgreSQL Integration**
  - `libpq-dev`: C client library for PostgreSQL, required for `psycopg2`, etc.
  - `postgresql-client`: Provides `psql` CLI tool to interact with PostgreSQL servers.

- **Cairo & DBus Integration**
  - `libcairo2-dev`: 2D graphics rendering library.
  - `pkg-config`: Manages compile and link flags for libraries.
  - `libdbus-1-dev`: Header files for building applications using D-Bus IPC.

### 2.2 Initialze Backend Project

- Initialize the backend project using `uv`, which creates a modern Python prject layout with `pyproject.toml`:

    ```bash
    uv init backend
    ```

## 3. Frontend

---

### 3.1 frontend.DockerFile

- This DockerFile installs frontend system dependencies and essential tools required to build and debug a Vite + React application in a containerized environment.

    ```DockerFile
    FROM node:24.2.0-bookworm

    # Set environment variables
    ENV DEBIAN_FRONTEND=noninteractive
    ENV TZ=Asia/Seoul

    WORKDIR /frontend

    # Install system dependencies
    RUN apt-get update && \
        apt-get install -y --no-install-recommends \
            tzdata \
            git \
            curl \
            vim \
            bash \
            build-essential \
            python3 \
            libpq-dev \
        && apt-get clean && \
        rm -rf /var/lib/apt/lists/*

    ```

- **Frontend-Specific Packages**
  - `bash`: Provides a standard shell environment, used by various CLI scripts and build tools.
  - `python3`: Required by some native module build tools such as `node-gyp`.

- **Development Tools & Utilities**
  - `git`: Version control system used to clone repositories or manage code.
  - `curl`: Command-line tool to fetch remote scripts or API resources.
  - `vim`: Lightweight text editor for quick edits inside the container.

- **Build Tools**
  - `build-essential`: Includes compilers and tools needed to build native Node.js addons.

- **PostgreSQL Integration (Shared)**
  - `libpq-dev`: Enables PostgreSQL support if needed for frontend database testing or shared libraries.

- **System & Environment**
  - `tzdata`: Ensures correct timezone is set in container (for consistent logging and date operations).

### 3.2 Initialize Frontend Project

- Use Vite to scaffold a React + TypeScript frontend project:

    ```bash
    npm create vite@latest frontend -- --template react-ts
    cd frontend
    npm install
    npm run dev
    ```

## 4. Docker Compose

---

### 4.1 Docker-compose.yml

- The following `docker-compose.yml` configures a multi-service development environment. It includes:
  - FastAPI backend with PostgreSQL
  - Vite + React frontend
  - Redis for caching and background job support

- All services run on a shared Docker bridge network to facilitate internal communication.

```yml
version: '3.9'

services:
  backend:
    image: multi-crypto-trading-tool_backend:0.0.1
    build:
      context: .
      dockerfile: backend.Dockerfile
    container_name: multi-crypto-trading-tool_backend
    ports:
      - "18080:8080"
    depends_on:
      - postgres-db
    networks:
      - trading_tool_network

  frontend:
    image: multi-crypto-trading-tool_frontend:0.0.1
    build:
      context: .
      dockerfile: frontend.Dockerfile
    container_name: multi-crypto-trading-tool_frontend
    ports:
      - "28080:8080" 
    depends_on:
      - backend
    networks:
      - trading_tool_network

  postgres-db:
    image: postgres:15.13-alpine3.22
    container_name: multi-crypto-trading-tool_postgre_db
    restart: always
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    ports:
      - "15432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - trading_tool_network
  
  redis:
    image: redis:7.2.9-alpine
    container_name: multi-crypto-trading-tool_redis
    restart: always
    ports:
      - "16379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      -  trading_tool_network

volumes:
  postgres_data:
  redis_data:

networks:
  trading_tool_network:
    driver: bridge
```

### 4.2 docker-compose.override.yml

- This override file is used during development to enable features like source code mounting, interactive shell access, and hot-reloading for both backend and frontend services.

```yml
version: "3.9"

services:
  backend:
    stdin_open: true
    tty: true
    privileged: false
    volumes:
      - ./backend:/backend
    # command: uvicorn main:app --reload --host 0.0.0.0 --port 8080
    working_dir: /backend 
    environment:
      - ENV=development
    command: bash

  frontend:
    stdin_open: true
    tty: true
    privileged: false
    volumes:
      - ./frontend:/frontend
    working_dir: /frontend
    command: npm run dev
    ports:
      - "25173:5173"
    environment:
      - NODE_ENV=development
```

### 4.3 .env

- This environment file provides PostgreSQL credentials and database name used by the `postgres-db` service in the Docker Compose setup.

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_DB=trading_tool_db
```

### 4.4 Development & Production Modes

- This project supports two different Docker Compose run modes: **development** and **production**.

- **Development Mode**
  - Run with:  

      ```bash
      docker compose up
      ```
  
  - Uses `docker-compose.override.yml` to:
    - Mount source code into containers
    - Enable hot-reload for both backend (`bash` entry) and frontend (`npm run dev`)
    - Expose React dev server at `localhost:25173`

- **Production Mode**
  - Run with:

      ```bash
      docker compose -f docker-compose.yml up
      ```

  - Ignores the override file, so:
    - Uses Docker image builds only (no source mounts)
    - Serves the frontend as a built static app on port `28080`
    - Backend runs as a Uvicorn service at port `18080`
