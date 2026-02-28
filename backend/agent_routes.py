import uuid
from datetime import datetime, timezone, timedelta
from typing import Any
from zoneinfo import ZoneInfo
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from googleapiclient.errors import HttpError

from auth import GoogleUser, get_access_token, get_google_user
from calendar_service import (
    get_calendar_service,
    list_events,
    get_event,
    create_event,
    update_event,
    delete_event,
)
from models import EventCreate, EventUpdate, EventDateTime, EventResponse
from llm_service import get_calendar_actions
from llm_models import (
    CreateEventAction,
    UpdateEventAction,
    DeleteEventAction,
    ListEventsAction,
    GetEventAction,
)
from action_history import action_history, ActionRecord


router = APIRouter(prefix="/agent", tags=["agent"])


class AgentRequest(BaseModel):
    """Request to the calendar agent."""
    prompt: str
    timezone: str | None = None


class ActionResult(BaseModel):
    """Result of a single action."""
    action: str
    success: bool
    data: Any = None
    error: str = None
    can_undo: bool = False


class AgentResponse(BaseModel):
    """Response from the calendar agent."""
    message: str
    reasoning: str = None
    results: list[ActionResult]


class UndoResponse(BaseModel):
    """Response from undo operation."""
    success: bool
    message: str
    undone_action: str = None
    data: Any = None


def handle_google_error(e: HttpError) -> str:
    """Convert Google API error to string message."""
    if e.resp.status == 401:
        return "Authentication failed. Please re-login."
    elif e.resp.status == 403:
        return "Permission denied. Check calendar permissions."
    elif e.resp.status == 404:
        return "Event not found."
    else:
        return f"Google Calendar error: {e.reason}"

def resolve_user_datetime(request_timezone: str | None) -> tuple[datetime, str]:
    """Return the user's current datetime and the resolved timezone label."""
    tzinfo = timezone.utc
    tz_label = "UTC"

    if request_timezone:
        try:
            tzinfo = ZoneInfo(request_timezone)
            tz_label = request_timezone
        except Exception:
            tzinfo = timezone.utc
    
    return datetime.now(tzinfo), tz_label


@router.post("/chat", response_model=AgentResponse)
async def chat_with_agent(
    request: AgentRequest,
    google_user: GoogleUser = Depends(get_google_user),
):
    """
    Send a natural language request to the calendar agent.
    
    The agent will interpret your request, determine the appropriate
    calendar actions, and execute them.
    
    Example prompts:
    - "Schedule a meeting with John tomorrow at 3pm for 1 hour"
    - "What's on my calendar for next week?"
    - "Move my dentist appointment to Friday"
    - "Cancel my 2pm meeting today"
    """
    access_token = google_user.access_token
    user_datetime, resolved_timezone = resolve_user_datetime(request.timezone)

    # First, fetch existing events to give LLM context for updates/deletes
    service = get_calendar_service(access_token)
    
    try:
        # Get events from past 7 days through next 60 days for context
        # This ensures recently created events are included
        now = datetime.now(timezone.utc)
        time_min = (now - timedelta(days=7)).isoformat()
        time_max = (now + timedelta(days=60)).isoformat()
        events_result = list_events(service, time_min=time_min, time_max=time_max, max_results=100)
        existing_events = events_result.get("items", [])
    except Exception:
        existing_events = []  # Continue without context if fetch fails
    
    try:
        # Get actions from LLM with event context and user metadata
        llm_response = await get_calendar_actions(
            request.prompt,
            events_context=existing_events,
            user_email=google_user.email,
            user_datetime=user_datetime,
            user_timezone=resolved_timezone,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Failed to understand request: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Error communicating with AI: {str(e)}"
        )
    
    # Execute each action
    results = []
    
    for action in llm_response.actions:
        result = ActionResult(action=action.action, success=False, can_undo=False)
        
        try:
            if isinstance(action, CreateEventAction):
                event_data = EventCreate(
                    summary=action.summary,
                    start=EventDateTime(
                        dateTime=action.start_datetime,
                        timeZone=action.timezone
                    ),
                    end=EventDateTime(
                        dateTime=action.end_datetime,
                        timeZone=action.timezone
                    ),
                    description=action.description,
                    location=action.location
                )
                created = create_event(service, event_data)
                result.success = True
                result.can_undo = True
                result.data = EventResponse.from_google_event(created).model_dump()
                
                # Store for rollback: to undo CREATE, we DELETE
                action_history.add(access_token, ActionRecord(
                    id=str(uuid.uuid4()),
                    timestamp=datetime.now(timezone.utc).isoformat(),
                    action_type="create",
                    event_id=created["id"],
                    rollback_data={}
                ))
                
            elif isinstance(action, UpdateEventAction):
                # First, get the original event for rollback
                original_event = get_event(service, action.event_id)
                
                update_data = EventUpdate(
                    summary=action.summary,
                    start=EventDateTime(dateTime=action.start_datetime) if action.start_datetime else None,
                    end=EventDateTime(dateTime=action.end_datetime) if action.end_datetime else None,
                    description=action.description,
                    location=action.location
                )
                updated = update_event(service, action.event_id, update_data)
                result.success = True
                result.can_undo = True
                result.data = EventResponse.from_google_event(updated).model_dump()
                
                # Store original state for rollback
                action_history.add(access_token, ActionRecord(
                    id=str(uuid.uuid4()),
                    timestamp=datetime.now(timezone.utc).isoformat(),
                    action_type="update",
                    event_id=action.event_id,
                    rollback_data={"original_event": original_event}
                ))
                
            elif isinstance(action, DeleteEventAction):
                # Get event data BEFORE deleting for rollback
                event_to_delete = get_event(service, action.event_id)
                
                delete_event(service, action.event_id)
                result.success = True
                result.can_undo = True
                result.data = {"deleted": action.event_id}
                
                # Store full event data for rollback (re-create)
                action_history.add(access_token, ActionRecord(
                    id=str(uuid.uuid4()),
                    timestamp=datetime.now(timezone.utc).isoformat(),
                    action_type="delete",
                    event_id=action.event_id,
                    rollback_data={"deleted_event": event_to_delete}
                ))
                
            elif isinstance(action, ListEventsAction):
                events_result = list_events(
                    service,
                    time_min=action.time_min,
                    time_max=action.time_max,
                    max_results=action.max_results
                )
                events = [
                    EventResponse.from_google_event(e).model_dump()
                    for e in events_result.get("items", [])
                ]
                result.success = True
                result.data = {"events": events, "count": len(events)}
                # READ-ONLY: no rollback needed
                
            elif isinstance(action, GetEventAction):
                event = get_event(service, action.event_id)
                result.success = True
                result.data = EventResponse.from_google_event(event).model_dump()
                # READ-ONLY: no rollback needed
                
        except HttpError as e:
            result.error = handle_google_error(e)
        except Exception as e:
            result.error = str(e)
        
        results.append(result)
    
    return AgentResponse(
        message=llm_response.message,
        reasoning=llm_response.reasoning,
        results=results
    )


@router.post("/undo", response_model=UndoResponse)
async def undo_last_action(access_token: str = Depends(get_access_token)):
    """
    Undo the last calendar action.
    
    - CREATE → deletes the created event
    - UPDATE → restores the original event data
    - DELETE → re-creates the deleted event (with new ID)
    """
    last_action = action_history.get_last(access_token)
    
    if not last_action:
        return UndoResponse(success=False, message="No actions to undo")
    
    service = get_calendar_service(access_token)
    
    try:
        if last_action.action_type == "create":
            # Undo CREATE by deleting the event
            delete_event(service, last_action.event_id)
            action_history.mark_rolled_back(access_token, last_action.id)
            return UndoResponse(
                success=True,
                message="Undone: deleted the created event",
                undone_action="create",
                data={"deleted_event_id": last_action.event_id}
            )
            
        elif last_action.action_type == "update":
            # Undo UPDATE by restoring original
            original = last_action.rollback_data["original_event"]
            service.events().update(
                calendarId="primary",
                eventId=last_action.event_id,
                body=original
            ).execute()
            action_history.mark_rolled_back(access_token, last_action.id)
            return UndoResponse(
                success=True,
                message="Undone: restored event to original state",
                undone_action="update",
                data={"event_id": last_action.event_id}
            )
            
        elif last_action.action_type == "delete":
            # Undo DELETE by re-creating (will get new ID)
            deleted_event = last_action.rollback_data["deleted_event"]
            # Remove fields that can't be set on create
            for field in ["id", "etag", "created", "updated", "creator", "organizer", "htmlLink", "iCalUID"]:
                deleted_event.pop(field, None)
            
            recreated = service.events().insert(
                calendarId="primary",
                body=deleted_event
            ).execute()
            action_history.mark_rolled_back(access_token, last_action.id)
            return UndoResponse(
                success=True,
                message="Undone: re-created the deleted event",
                undone_action="delete",
                data={"new_event_id": recreated["id"]}
            )
            
    except HttpError as e:
        return UndoResponse(success=False, message=f"Failed to undo: {e.reason}")
    except Exception as e:
        return UndoResponse(success=False, message=f"Failed to undo: {str(e)}")
    
    return UndoResponse(success=False, message="Unknown action type")


@router.get("/history")
async def get_action_history(
    access_token: str = Depends(get_access_token),
    limit: int = 10
):
    """Get recent action history for the current session."""
    history = action_history.get_history(access_token, limit)
    return {
        "actions": [
            {
                "id": h.id,
                "timestamp": h.timestamp,
                "action_type": h.action_type,
                "event_id": h.event_id,
                "rolled_back": h.rolled_back
            }
            for h in history
        ]
    }
