"""Hooks for injecting user-specific context into LLM prompts.

Replace the body of `build_user_context` with calls into your
key-value system or any other internal service that needs both the
Google account email and the user's current local date/time.
"""

from __future__ import annotations

import os

from datetime import datetime
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

# Check if Supermemory is enabled
SUPERMEMORY_ENABLED = os.getenv("SUPERMEMORY_ENABLED", "false").lower() == "true"

# Lazy client initialization
_client = None

def _get_client():
    global _client
    if _client is None and SUPERMEMORY_ENABLED:
        from supermemory import Supermemory
        _client = Supermemory(api_key=os.getenv("SUPERMEMORY_API_KEY"))
    return _client


def build_user_context(user_email: str, user_datetime: datetime) -> Optional[str]:
    """Return proprietary context for the LLM.

    Args:
        user_email: Email address from Google OAuth.
        user_datetime: Current datetime in the user's local timezone.

    Returns:
        A string to append to the LLM prompt, or None to skip.

    Notes:
        - This is the integration point for your internal systems.
        - Example usage once you implement your store:
              return TODO.add(user_email=user_email,
                               current_date=user_datetime.date())
        - The current stub simply exposes the two values for validation.
    """

    # Return None if Supermemory is disabled
    if not SUPERMEMORY_ENABLED:
        return None
    
    client = _get_client()
    if client is None:
        return None

    current_month = user_datetime.strftime("%B")
    
    try:
        profile = client.profile(container_tag=f'{user_email}_{current_month}')
        
        if profile is None:
            client.add()
        return (
            "User profile context:\n"
            f"  email: {user_email}\n"
            f"  current_month: {current_month}"
        )
    except Exception:
        return None
