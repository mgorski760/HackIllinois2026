from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import httpx
from pydantic import BaseModel
from typing import Optional

# This creates the "Authorize" button in Swagger UI
security = HTTPBearer()

USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"


class GoogleUser(BaseModel):
    """Represents Google account details tied to the Bearer token."""

    access_token: str
    email: str
    email_verified: Optional[bool] = None
    sub: Optional[str] = None
    name: Optional[str] = None
    picture: Optional[str] = None


async def get_access_token(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> str:
    """
    Extract the Bearer token from the Authorization header.
    
    Uses FastAPI's HTTPBearer security scheme which:
    - Adds "Authorize" button to Swagger UI
    - Automatically validates Bearer token format
    
    Returns:
        The access token string
        
    Raises:
        HTTPException: If header is missing or malformed
    """
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header is required"
        )
    
    return credentials.credentials


async def fetch_google_userinfo(access_token: str) -> dict:
    """Fetch the OpenID Connect userinfo payload for the provided token."""

    headers = {"Authorization": f"Bearer {access_token}"}
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(USERINFO_URL, headers=headers)

    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Failed to fetch Google profile"
        )

    return response.json()


async def get_google_user(
    access_token: str = Depends(get_access_token)
) -> GoogleUser:
    """FastAPI dependency that returns the caller's Google account details."""

    profile = await fetch_google_userinfo(access_token)
    email = profile.get("email")

    if not email:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Google account email is unavailable"
        )

    return GoogleUser(
        access_token=access_token,
        email=email,
        email_verified=profile.get("email_verified"),
        sub=profile.get("sub"),
        name=profile.get("name"),
        picture=profile.get("picture"),
    )
