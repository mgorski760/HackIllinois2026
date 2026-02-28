import os
import json
import httpx
from datetime import datetime, timezone
from typing import Optional
from dotenv import load_dotenv

from llm_models import LLMResponse, CALENDAR_SYSTEM_PROMPT
from user_context import build_user_context

load_dotenv()

# Modal vLLM endpoint URL - set this in .env file
VLLM_URL = os.getenv("VLLM_URL", "http://localhost:8000")
MODEL_NAME = os.getenv("VLLM_MODEL_NAME", "Qwen/Qwen3-Coder-Next")


def format_events_context(events: list[dict]) -> str:
    """Format a list of events into a string for the LLM context."""
    if not events:
        return "No upcoming events found."
    
    lines = ["Existing calendar events (use these event_id values for update/delete):"]
    for event in events:
        event_id = event.get("id", "unknown")
        summary = event.get("summary", "No title")
        start = event.get("start", {})
        start_time = start.get("dateTime", start.get("date", "unknown"))
        end = event.get("end", {})
        end_time = end.get("dateTime", end.get("date", "unknown"))
        
        lines.append(f"  - event_id: \"{event_id}\"")
        lines.append(f"    summary: \"{summary}\"")
        lines.append(f"    start: {start_time}")
        lines.append(f"    end: {end_time}")
    
    return "\n".join(lines)


async def call_vllm(
    prompt: str,
    events_context: Optional[list[dict]] = None,
    *,
    user_email: Optional[str] = None,
    user_datetime: Optional[datetime] = None,
    user_timezone: Optional[str] = None,
    max_tokens: int = 2048,
) -> str:
    """
    Call the vLLM server and get a completion.
    
    Args:
        prompt: The user's prompt
        events_context: Optional list of existing calendar events to include in context
        max_tokens: Maximum tokens to generate
        
    Returns:
        The generated text response
    """
    current_time = datetime.now(timezone.utc).isoformat()
    
    # Build context with events if provided
    context_parts = [f"Current datetime: {current_time}"]

    if user_timezone:
        context_parts.append(f"User timezone: {user_timezone}")
    if user_datetime:
        context_parts.append(f"User local datetime: {user_datetime.isoformat()}")

    if user_email and user_datetime:
        try:
            internal_context = build_user_context(user_email, user_datetime)
        except Exception:
            internal_context = None
        if internal_context:
            context_parts.append("User-specific context:")
            context_parts.append(internal_context)
    
    if events_context:
        context_parts.append(format_events_context(events_context))
    
    context_parts.append(f"User request: {prompt}")
    context_parts.append("Respond with valid JSON only:")
    
    full_prompt = "\n\n".join(context_parts)

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{VLLM_URL}/v1/chat/completions",
            json={
                "model": MODEL_NAME,
                "messages": [
                    {"role": "system", "content": CALENDAR_SYSTEM_PROMPT},
                    {"role": "user", "content": full_prompt}
                ],
                "max_tokens": max_tokens,
                "temperature": 0.1,  # Low temperature for more deterministic JSON output
                "response_format": {"type": "json_object"},  # Force JSON output
            }
        )
        response.raise_for_status()
        
        data = response.json()
        return data["choices"][0]["message"]["content"]


def parse_llm_response(response_text: str) -> LLMResponse:
    """
    Parse the LLM's JSON response into a structured format.
    
    Args:
        response_text: Raw text from the LLM
        
    Returns:
        Parsed LLMResponse object
        
    Raises:
        ValueError: If the response cannot be parsed
    """
    # Try to extract JSON from the response
    text = response_text.strip()
    
    # Remove markdown code blocks if present
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    
    text = text.strip()
    
    try:
        data = json.loads(text)
        return LLMResponse(**data)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse LLM response as JSON: {e}\nResponse: {response_text}")
    except Exception as e:
        raise ValueError(f"Failed to validate LLM response: {e}\nResponse: {response_text}")


async def get_calendar_actions(
    prompt: str,
    events_context: Optional[list[dict]] = None,
    *,
    user_email: Optional[str] = None,
    user_datetime: Optional[datetime] = None,
    user_timezone: Optional[str] = None,
) -> LLMResponse:
    """
    Get calendar actions from the LLM based on user prompt.
    
    Args:
        prompt: User's natural language request
        events_context: Optional list of existing calendar events for context
        
    Returns:
        Parsed LLMResponse with actions to execute
    """
    response_text = await call_vllm(
        prompt,
        events_context=events_context,
        user_email=user_email,
        user_datetime=user_datetime,
        user_timezone=user_timezone,
    )
    return parse_llm_response(response_text)
