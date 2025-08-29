+++
title = "9. Refactoring 1: Backend - Separate AuthService and Move Login API"
type = "dev-log"
tags = [
  "refactoring", "fastapi", "sqlalchemy", "auth-service",
  "user-service", "jwt", "token-authentication", "user-authentication",
  "clean-architecture", "api-design", "exception-handling", "backend"
]
weight = 9
+++

This refactoring was performed to improve **separation of concerns** and make authentication logic more **modular and testable**.

Previously, authentication logic (`authenticate_user`) was part of the `UserService`, tightly coupling user management and auth logic.  
Now, that logic has been moved into a dedicated `AuthService`, and the login route has been migrated from `user_router` to a new `auth_router`.

### 1. AuthService

- I extracted a new service class for authentication. The `authenticate_user()` method, previously in `UserService`, is now moved to `AuthService`.

    ```python
    from sqlalchemy.orm import Session
    from models import User
    from core import (
        create_jwt_token, verify_password, verify_jwt_token, 
        InvalidCredentialsException, LoginFailReason, ErrorCode, TokenGenerationException
    )
    from .user_service import UserService
    from .user_login_log_service import UserLoginLogService
    from fastapi import Request
    from loguru import logger

    class AuthService:
        """Service class for user-related operations."""

        def __init__(self, db: Session, request: Request):
            self.db = db
            self.request = request
            self.user_service = UserService(db)
            self.login_log_service = UserLoginLogService(db)
            logger.info("AuthService initialized with new request.")
        
        def authenticate_user(self, user_id: str, user_pw: str) -> User:
            """Authenticate a user by ID and password."""
            try:
                user = self.user_service.get_user_by_id(user_id)
            except Exception as e:
                logger.exception(f"Database error while retrieving user_id='{user_id}': {e}")
                raise

            if not user or not verify_password(user_pw, user.user_pw):
                logger.warning(f"Authentication failed for user_id='{user_id}'")
                user_no = user.user_no if user else None

                self.login_log_service.log_login_attempt(
                    request=self.request,
                    user_no=user_no,
                    login_success=False,
                    fail_reason=LoginFailReason.INVALID_CREDENTIALS,
                    error_code=ErrorCode.UNAUTHORIZED
                )
                raise InvalidCredentialsException()
            
            self.login_log_service.log_login_attempt(
                request=self.request,
                user_no=user.user_no,
                login_success=True
            )
            logger.info(f"Authentication successful for user_id='{user.user_id}'")
            
            return user
    ```

- In this service, I also added methods about authenticating JWT.

    ```python
    class AuthService:
        ...

        def generate_token(self, user: User) -> str:
            """Generate a JWT token for the authenticated user."""
            try:
                payload = {"user_id": user.user_id, "user_no": user.user_no, "sub": user.user_id}
                token = create_jwt_token(payload)
                logger.info(f"JWT generated for user_id='{user.user_id}'")
                return token
            except Exception as e:
                logger.exception(f"Token generation failed for user_id='{user.user_id}': {e}")
                raise TokenGenerationException()
        
        def verify_token(self, token: str) -> dict | None:
            """Verify a JWT token and return the payload if valid."""
            try:
                logger.info(f"JWT verification succeeded for token='{token}'")
                return verify_jwt_token(token)
            except Exception as e:
                logger.warning(f"Token verification failed: {e}")
                return None
    ```

### 2. Custom Exceptions

- To separate specific exceptions, I wrote some custom exception classes.

    ```python
    from fastapi import HTTPException, status

    # custom exceptions for the application

    # Custom exceptions for Login and User operations
    class InvalidCredentialsException(HTTPException):
        def __init__(self):
            super().__init__(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user ID or password."
            )

    class TokenGenerationException(HTTPException):
        def __init__(self, detail="Failed to generate access token."):
            super().__init__(status_code=500, detail=detail)
            
    class LogRetrievalException(HTTPException):
        def __init__(self, detail="Failed to retrieve user login logs"):
            super().__init__(status_code=500, detail=detail)

    ```

### 3. Login API

- Originally, this login api's router was in `user_router`. But I changed this router into `auth_router`
- So I replaced the previous inline logic with calls to the newly created `AuthService`.

    ```python
    auth_router = APIRouter(prefix="/api/auth", tags=["auth"])

    @auth_router.post("/login", response_model=LoginResponse, summary="User Login")
    def login(request: Request, body: LoginRequest, db: Session = Depends(get_db)):
        logger.info(f"Login attempt for user_id: {body.user_id}")
        
        try:
            auth_service = AuthService(db=db, request=request)
            user = auth_service.authenticate_user(body.user_id, body.user_pw)
            token = auth_service.generate_token(user)
            logger.info(f"Token issued for user_id: {user.user_id}")
            return LoginResponse(access_token=token)
        except Exception as e:
            logger.exception("Unexpected error during login")
            raise HTTPException(status_code=500, detail="Internal server error")
        ...
    ```
