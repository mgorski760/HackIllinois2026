from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from googleapiclient.errors import HttpError

from auth import get_access_token
from calendar_service import (
    get_calendar_service,
    list_events,
    get_event,
    create_event,
    update_event,
    delete_event,
)
from models import (
    EventCreate,
    EventUpdate,
    EventResponse,
    EventListResponse,
)


router = APIRouter(prefix="/calendar", tags=["calendar"])


def handle_google_api_error(e: HttpError) -> HTTPException:
    """Convert Google API errors to FastAPI HTTPExceptions."""
    error_code = e.resp.status
    
    if error_code == 401:
        return HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token. Please re-authenticate."
        )
    elif error_code == 403:
        return HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions. Ensure the token has calendar scope."
        )
    elif error_code == 404:
        return HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found."
        )
    else:
        return HTTPException(
            status_code=error_code,
            detail=f"Google Calendar API error: {e.reason}"
        )


@router.get("/debug/raw")
async def list_calendar_events_raw(
    access_token: str = Depends(get_access_token),
    time_min: Optional[str] = Query(None),
    time_max: Optional[str] = Query(None),
    max_results: int = Query(10),
):
    """Debug endpoint - returns raw Google Calendar API response."""
    try:
        service = get_calendar_service(access_token)
        result = list_events(service, time_min=time_min, time_max=time_max, max_results=max_results)
        return result
    except HttpError as e:
        raise handle_google_api_error(e)


@router.get("/events", response_model=EventListResponse)
async def list_calendar_events(
    access_token: str = Depends(get_access_token),
    time_min: Optional[str] = Query(None, description="Start time filter (RFC3339, e.g., 2026-02-28T00:00:00Z)"),
    time_max: Optional[str] = Query(None, description="End time filter (RFC3339, e.g., 2026-03-01T00:00:00Z)"),
    max_results: int = Query(100, ge=1, le=2500, description="Maximum number of events to return"),
    page_token: Optional[str] = Query(None, description="Token for pagination"),
):
    """
    List events from the user's primary Google Calendar.
    
    Pass the Google OAuth access token in the Authorization header:
    `Authorization: Bearer <access_token>`
    """
    try:
        service = get_calendar_service(access_token)
        result = list_events(
            service,
            time_min=time_min,
            time_max=time_max,
            max_results=max_results,
            page_token=page_token
        )
        
        events = [
            EventResponse.from_google_event(event)
            for event in result.get("items", [])
        ]
        
        return EventListResponse(
            events=events,
            nextPageToken=result.get("nextPageToken")
        )
    except HttpError as e:
        raise handle_google_api_error(e)


@router.get("/events/{event_id}", response_model=EventResponse)
async def get_calendar_event(
    event_id: str,
    access_token: str = Depends(get_access_token),
):
    """
    Get a single event by ID from the user's primary Google Calendar.
    """
    try:
        service = get_calendar_service(access_token)
        event = get_event(service, event_id)
        return EventResponse.from_google_event(event)
    except HttpError as e:
        raise handle_google_api_error(e)


@router.post("/events", response_model=EventResponse, status_code=status.HTTP_201_CREATED)
async def create_calendar_event(
    event_data: EventCreate,
    access_token: str = Depends(get_access_token),
):
    """
    Create a new event in the user's primary Google Calendar.
    
    Request body example:
    ```json
    {
        "summary": "Team Meeting",
        "start": {
            "dateTime": "2026-02-28T10:00:00-06:00",
            "timeZone": "America/Chicago"
        },
        "end": {
            "dateTime": "2026-02-28T11:00:00-06:00",
            "timeZone": "America/Chicago"
        },
        "description": "Weekly sync",
        "location": "Conference Room A"
    }
    ```
    """
    try:
        service = get_calendar_service(access_token)
        created_event = create_event(service, event_data)
        return EventResponse.from_google_event(created_event)
    except HttpError as e:
        raise handle_google_api_error(e)
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating event: {str(e)}"
        )


@router.put("/events/{event_id}", response_model=EventResponse)
async def update_calendar_event(
    event_id: str,
    event_data: EventUpdate,
    access_token: str = Depends(get_access_token),
):
    """
    Update an existing event. Only include the fields you want to change.
    
    Request body example (partial update):
    ```json
    {
        "summary": "Updated Meeting Title",
        "location": "Room B"
    }
    ```
    """
    try:
        service = get_calendar_service(access_token)
        updated_event = update_event(service, event_id, event_data)
        return EventResponse.from_google_event(updated_event)
    except HttpError as e:
        raise handle_google_api_error(e)


@router.delete("/events/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_calendar_event(
    event_id: str,
    access_token: str = Depends(get_access_token),
):
    """
    Delete an event from the user's primary Google Calendar.
    """
    try:
        service = get_calendar_service(access_token)
        delete_event(service, event_id)
    except HttpError as e:
        raise handle_google_api_error(e)
