from pydantic import BaseModel


class LoginIn(BaseModel):
    username: str
    password: str


class RefreshIn(BaseModel):
    refresh_token: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    refresh_token: str | None = None
