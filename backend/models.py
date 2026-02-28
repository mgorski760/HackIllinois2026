from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class EventDateTime(BaseModel):
    """DateTime object for Google Calendar events."""
    dateTime: str  # ISO format: 2026-02-28T10:00:00-06:00
    timeZone: Optional[str] = None


class EventCreate(BaseModel):
    """Request model for creating a calendar event."""
    summary: str = Field(..., description="Event title")
    start: EventDateTime
    end: EventDateTime
    description: Optional[str] = None
    location: Optional[str] = None


class EventUpdate(BaseModel):
    """Request model for updating a calendar event. All fields optional."""
    summary: Optional[str] = None
    start: Optional[EventDateTime] = None
    end: Optional[EventDateTime] = None
    description: Optional[str] = None
    location: Optional[str] = None


class EventResponse(BaseModel):
    """Response model for a calendar event."""
    id: str
    summary: Optional[str] = None
    start: Optional[EventDateTime] = None
    end: Optional[EventDateTime] = None
    description: Optional[str] = None
    location: Optional[str] = None
    htmlLink: Optional[str] = None
    status: Optional[str] = None

    @classmethod
    def from_google_event(cls, event: dict) -> "EventResponse":
        """Convert Google Calendar API event to EventResponse."""
        start = event.get("start", {})
        end = event.get("end", {})
        
        return cls(
            id=event["id"],
            summary=event.get("summary"),
            start=EventDateTime(
                dateTime=start.get("dateTime", start.get("date", "")),
                timeZone=start.get("timeZone")
            ) if start else None,
            end=EventDateTime(
                dateTime=end.get("dateTime", end.get("date", "")),
                timeZone=end.get("timeZone")
            ) if end else None,
            description=event.get("description"),
            location=event.get("location"),
            htmlLink=event.get("htmlLink"),
            status=event.get("status")
        )


class EventListResponse(BaseModel):
    """Response model for listing calendar events."""
    events: list[EventResponse]
    nextPageToken: Optional[str] = None
