"""Hooks for injecting user-specific context into LLM prompts.

This module handles:
  1. Storing user scheduling preferences to Supermemory
  2. Querying Supermemory for context to inject into Modal LLM prompts

Fill in the TODO sections below with your Supermemory logic.

Set SUPERMEMORY_ENABLED=false in .env to disable Supermemory integration.
"""

from __future__ import annotations

import os
from datetime import datetime
from typing import Optional

from dotenv import load_dotenv

load_dotenv()

_SUPERMEMORY_API_KEY = os.getenv("SUPERMEMORY_API_KEY")
_SUPERMEMORY_ENABLED = os.getenv("SUPERMEMORY_ENABLED", "true").lower() in ("true", "1", "yes")

# Conditionally import and create client
client = None
if _SUPERMEMORY_ENABLED:
    try:
        from supermemory import Supermemory
        if _SUPERMEMORY_API_KEY:
            client = Supermemory(api_key=_SUPERMEMORY_API_KEY)
        else:
            client = Supermemory()
    except ImportError:
        _SUPERMEMORY_ENABLED = False


def _container_tag(user_email: str, user_datetime: datetime) -> str:
    """Generate a unique container tag for the user + month."""
    month_key = user_datetime.strftime("%Y-%m")
    return f"{user_email}:{month_key}"


# =============================================================================
# SUPERMEMORY STORAGE LOGIC
# =============================================================================
# Called by POST /agent/preferences when user submits scheduling preferences.
# Your job: check if memory exists → update it; otherwise → create new one.
# =============================================================================

def store_user_preferences(
    user_email: str,
    preference_text: str,
    user_datetime: datetime,
) -> None:
    """Persist scheduling preferences to Supermemory."""

    if not _SUPERMEMORY_ENABLED or client is None:
        # Supermemory disabled — skip storage
        return

    text = preference_text.strip()
    if not text:
        raise ValueError("Preference text must not be empty")

    container_tag = _container_tag(user_email, user_datetime)

    # TODO: YOUR SUPERMEMORY STORAGE LOGIC HERE
    response = client.search.documents(
        q="planning notes",
        container_tags=["user_123"]
    ) 
    

# =============================================================================
# SUPERMEMORY RETRIEVAL LOGIC
# =============================================================================
# Called during /agent/chat to fetch stored context for the LLM prompt.
# =============================================================================

def query_supermemory_context(
    user_email: str,
    user_datetime: datetime,
) -> Optional[str]:
    """Query Supermemory for user context to inject into the LLM prompt.

    Args:
        user_email: The user's Google email.
        user_datetime: Current datetime in user's local timezone.

    Returns:
        A prompt string from Supermemory to add to the LLM context,
        or None if no relevant context is found.

    TODO: Implement your Supermemory query logic below.
    """

    container_tag = _container_tag(user_email, user_datetime)

    # -------------------------------------------------------------------------
    # TODO: YOUR SUPERMEMORY QUERY LOGIC HERE
    # -------------------------------------------------------------------------
    # Example pseudocode:
    #
    #   result = client.search(
    #       container_tag=container_tag,
    #       query=f"scheduling preferences for {user_datetime.strftime('%B')}"
    #   )
    #   if result and result.content:
    #       return result.content
    #   return None
    #
    # Skip if Supermemory is disabled
    if not _SUPERMEMORY_ENABLED or client is None:
        return None

    # Current placeholder just calls .profile():
    return client.profile(container_tag=container_tag)
    # -------------------------------------------------------------------------


# =============================================================================
# BUILD FINAL USER CONTEXT FOR LLM
# =============================================================================
# This function assembles metadata + Supermemory prompt into a single string
# that gets injected into the Modal LLM request.
# =============================================================================

def build_user_context(
    user_email: str,
    user_datetime: datetime,
) -> Optional[str]:
    """Assemble user context string for the Modal LLM prompt.

    Args:
        user_email: Email address from Google OAuth.
        user_datetime: Current datetime in the user's local timezone.

    Returns:
        A formatted string to append to the LLM prompt, or None to skip.

    Flow:
        1. Include basic user metadata (email, current month)
        2. Query Supermemory for stored preferences/context
        3. If Supermemory returns a prompt, append it
    """

    current_month = user_datetime.strftime("%B")

    # Query Supermemory for any stored context/preferences
    try:
        supermemory_prompt = query_supermemory_context(user_email, user_datetime)
    except Exception:
        supermemory_prompt = None

    # Assemble the context block
    lines = [
        "User profile context:",
        f"  email: {user_email}",
        f"  current_month: {current_month}",
    ]

    # Append the Supermemory prompt if available
    if supermemory_prompt:
        lines.append("")
        lines.append("User scheduling preferences (from memory):")
        lines.append(supermemory_prompt)

    return "\n".join(lines)
