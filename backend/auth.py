from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

# This creates the "Authorize" button in Swagger UI
security = HTTPBearer()


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
