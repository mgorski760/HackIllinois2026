from typing import Literal, Optional, Union
from pydantic import BaseModel, Field


class CalendarAction(BaseModel):
    """Base model for calendar actions returned by the LLM."""
    action: Literal["create", "update", "delete", "list", "get"]


class CreateEventAction(CalendarAction):
    """Action to create a new calendar event."""
    action: Literal["create"] = "create"
    summary: str = Field(..., description="Event title")
    start_datetime: str = Field(..., description="Start time in ISO format")
    end_datetime: str = Field(..., description="End time in ISO format")
    description: Optional[str] = None
    location: Optional[str] = None
    timezone: str = Field(default="America/Chicago")


class UpdateEventAction(CalendarAction):
    """Action to update an existing calendar event."""
    action: Literal["update"] = "update"
    event_id: str = Field(..., description="ID of the event to update")
    summary: Optional[str] = None
    start_datetime: Optional[str] = None
    end_datetime: Optional[str] = None
    description: Optional[str] = None
    location: Optional[str] = None


class DeleteEventAction(CalendarAction):
    """Action to delete a calendar event."""
    action: Literal["delete"] = "delete"
    event_id: str = Field(..., description="ID of the event to delete")


class ListEventsAction(CalendarAction):
    """Action to list calendar events."""
    action: Literal["list"] = "list"
    time_min: Optional[str] = Field(None, description="Start of time range (ISO format)")
    time_max: Optional[str] = Field(None, description="End of time range (ISO format)")
    max_results: int = Field(default=10, description="Maximum number of events to return")


class GetEventAction(CalendarAction):
    """Action to get a specific event by ID."""
    action: Literal["get"] = "get"
    event_id: str = Field(..., description="ID of the event to retrieve")


class LLMResponse(BaseModel):
    """Response format from the LLM."""
    reasoning: Optional[str] = Field(None, description="LLM's reasoning about the request")
    actions: list[Union[CreateEventAction, UpdateEventAction, DeleteEventAction, ListEventsAction, GetEventAction]]
    message: str = Field(..., description="Human-friendly message to show the user")


CALENDAR_SYSTEM_PROMPT = """You are a calendar assistant. Output ONLY valid JSON, nothing else. No thinking, no explanations before the JSON.

CRITICAL: Your entire response must be a single JSON object. Do not write any text before or after the JSON.

Response format:
{
  "reasoning": "Brief explanation",
  "actions": [...],
  "message": "Friendly message"
}

Available actions:

1. CREATE an event:
{
  "action": "create",
  "summary": "Event title",
  "start_datetime": "2026-03-01T10:00:00-06:00",
  "end_datetime": "2026-03-01T11:00:00-06:00",
  "description": "Optional description",
  "location": "Optional location",
  "timezone": "America/Chicago"
}

2. UPDATE an event (requires event_id):
{
  "action": "update",
  "event_id": "abc123",
  "summary": "New title",
  "start_datetime": "...",
  "end_datetime": "..."
}

3. DELETE an event:
{
  "action": "delete",
  "event_id": "abc123"
}

4. LIST events:
{
  "action": "list",
  "time_min": "2026-03-01T00:00:00Z",
  "time_max": "2026-03-31T23:59:59Z",
  "max_results": 10
}

5. GET a specific event:
{
  "action": "get",
  "event_id": "abc123"
}

Rules:
- Always use ISO 8601 datetime format with timezone
- The current date is provided in the user message
- Default timezone is America/Chicago unless specified
- For relative times like "tomorrow at 3pm", calculate the actual datetime
- You can include multiple actions in the actions array
- If the user's request is unclear, use the "list" action to help them see their events
- ONLY output valid JSON, no markdown code blocks or other text
- IMPORTANT: When updating or deleting events, you MUST use the exact event_id from the provided calendar events list
- Match events by their summary/title when the user refers to them by name
- If no matching event is found for an update/delete request, explain this in the message"""
