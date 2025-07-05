+++
title = "4. Set Configurations"
type = "Projects"
tags = ["python", "BaseSettings", "dotenv", "pydantic_settings", "PostgreSQL"]
+++

I used a .env file to store configuration values. To load them into the application, I’m using BaseSettings from the pydantic_settings package.

- Here's an sample `.env` file used to configure the `PostgreSQL` database connection:

    ```env
    POSTGRES_HOST=localhost
    POSTGRES_PORT=5432
    POSTGRES_USER=myuser
    POSTGRES_PASSWORD=secret
    POSTGRES_DB=cryptobot
    ```

## 1. Settings

- `pydantic_settings.BaseSettings` is an extended version of `Pydantic`'s model designed for managing environment variables.
- It's commonly used in Python backend frameworks like FastAPI to load and validate environment variables.
- First, I created a `Settings` class to handle `PostgreSQL` connection configuration:

    ```python
    from pydantic_settings import BaseSettings

    class Settings(BaseSettings):
        ...
        POSTGRES_HOST: str
        POSTGRES_PORT: int
        POSTGRES_USER: str
        POSTGRES_PASSWORD: str
        POSTGRES_DB: str
        ...
    ```

- Next, I added a property method to easily build the `PostgreSQL` connection URL:

    ```python
    class Settings(BaseSettings):
        ...

        @property
        def db_url(self):
            return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    ```

  - With this method, I can easily access the full PostgreSQL URL wherever it's needed in this application.

- To create an instance of the `Settings` class, I added the following code below the class definition:

    ```python
    class Settings(BaseSettings):
        ...

    settings = Settings()
    ```

- Once initialized, the configuration values can be accessed anywhere in the application like this:

    ```python
    from app.core.config import settings

    settings.db_url
    ```
