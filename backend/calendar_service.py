from typing import Optional
from datetime import datetime, timezone
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build, Resource
from googleapiclient.errors import HttpError

from models import EventCreate, EventUpdate


def get_calendar_service(access_token: str) -> Resource:
    """
    Build a Google Calendar API service using the provided access token.
    
    Args:
        access_token: OAuth 2.0 access token from Google Sign-In
        
    Returns:
        Google Calendar API service resource
    """
    credentials = Credentials(token=access_token)
    service = build("calendar", "v3", credentials=credentials)
    return service


def list_events(
    service: Resource,
    calendar_id: str = "primary",
    time_min: Optional[str] = None,
    time_max: Optional[str] = None,
    max_results: int = 100,
    page_token: Optional[str] = None
) -> dict:
    """
    List events from a Google Calendar.
    
    Args:
        service: Google Calendar API service
        calendar_id: Calendar ID (default: "primary" for user's main calendar)
        time_min: Lower bound (exclusive) for event start time (RFC3339 timestamp)
        time_max: Upper bound (exclusive) for event start time (RFC3339 timestamp)
        max_results: Maximum number of events to return
        page_token: Token for pagination
        
    Returns:
        Dictionary containing events list and pagination info
    """
    # timeMin is required when using singleEvents=True and orderBy=startTime
    # Default to current time if not provided
    if time_min is None:
        time_min = datetime.now(timezone.utc).isoformat()
    
    events_result = service.events().list(
        calendarId=calendar_id,
        timeMin=time_min,
        timeMax=time_max,
        maxResults=max_results,
        pageToken=page_token,
        singleEvents=True,
        orderBy="startTime"
    ).execute()
    
    return events_result


def get_event(
    service: Resource,
    event_id: str,
    calendar_id: str = "primary"
) -> dict:
    """
    Get a single event by ID.
    
    Args:
        service: Google Calendar API service
        event_id: The event ID
        calendar_id: Calendar ID (default: "primary")
        
    Returns:
        Event dictionary from Google Calendar API
    """
    event = service.events().get(
        calendarId=calendar_id,
        eventId=event_id
    ).execute()
    
    return event


def create_event(
    service: Resource,
    event_data: EventCreate,
    calendar_id: str = "primary"
) -> dict:
    """
    Create a new calendar event.
    
    Args:
        service: Google Calendar API service
        event_data: Event creation data
        calendar_id: Calendar ID (default: "primary")
        
    Returns:
        Created event dictionary from Google Calendar API
    """
    event_body = {
        "summary": event_data.summary,
        "start": event_data.start.model_dump(exclude_none=True),
        "end": event_data.end.model_dump(exclude_none=True),
    }
    
    if event_data.description:
        event_body["description"] = event_data.description
    if event_data.location:
        event_body["location"] = event_data.location
    
    created_event = service.events().insert(
        calendarId=calendar_id,
        body=event_body
    ).execute()
    
    return created_event


def update_event(
    service: Resource,
    event_id: str,
    event_data: EventUpdate,
    calendar_id: str = "primary"
) -> dict:
    """
    Update an existing calendar event.
    
    Args:
        service: Google Calendar API service
        event_id: The event ID to update
        event_data: Event update data (only non-None fields will be updated)
        calendar_id: Calendar ID (default: "primary")
        
    Returns:
        Updated event dictionary from Google Calendar API
    """
    # First, get the existing event
    existing_event = get_event(service, event_id, calendar_id)
    
    # Update only the fields that are provided
    if event_data.summary is not None:
        existing_event["summary"] = event_data.summary
    if event_data.start is not None:
        existing_event["start"] = event_data.start.model_dump(exclude_none=True)
    if event_data.end is not None:
        existing_event["end"] = event_data.end.model_dump(exclude_none=True)
    if event_data.description is not None:
        existing_event["description"] = event_data.description
    if event_data.location is not None:
        existing_event["location"] = event_data.location
    
    updated_event = service.events().update(
        calendarId=calendar_id,
        eventId=event_id,
        body=existing_event
    ).execute()
    
    return updated_event


def delete_event(
    service: Resource,
    event_id: str,
    calendar_id: str = "primary"
) -> None:
    """
    Delete a calendar event.
    
    Args:
        service: Google Calendar API service
        event_id: The event ID to delete
        calendar_id: Calendar ID (default: "primary")
    """
    service.events().delete(
        calendarId=calendar_id,
        eventId=event_id
    ).execute()
