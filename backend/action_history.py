from datetime import datetime, timezone
from typing import Optional
from pydantic import BaseModel
from collections import deque


class ActionRecord(BaseModel):
    """Record of an executed action with rollback data."""
    id: str  # unique action ID
    timestamp: str
    action_type: str  # create, update, delete
    event_id: Optional[str] = None  # the affected event
    rollback_data: dict = {}  # data needed to undo
    rolled_back: bool = False


class ActionHistory:
    """In-memory action history per session/user token."""
    
    def __init__(self, max_history: int = 50):
        self._history: dict[str, deque[ActionRecord]] = {}
        self.max_history = max_history
    
    def _get_key(self, access_token: str) -> str:
        # Use last 20 chars of token as key (enough for uniqueness)
        return access_token[-20:]
    
    def add(self, access_token: str, record: ActionRecord):
        """Add an action record to history."""
        key = self._get_key(access_token)
        if key not in self._history:
            self._history[key] = deque(maxlen=self.max_history)
        self._history[key].appendleft(record)
    
    def get_last(self, access_token: str) -> Optional[ActionRecord]:
        """Get the most recent undoable action."""
        key = self._get_key(access_token)
        if key not in self._history:
            return None
        for record in self._history[key]:
            if not record.rolled_back and record.action_type in ("create", "update", "delete"):
                return record
        return None
    
    def mark_rolled_back(self, access_token: str, action_id: str):
        """Mark an action as rolled back."""
        key = self._get_key(access_token)
        if key in self._history:
            for record in self._history[key]:
                if record.id == action_id:
                    record.rolled_back = True
                    break
    
    def get_history(self, access_token: str, limit: int = 10) -> list[ActionRecord]:
        """Get recent action history."""
        key = self._get_key(access_token)
        if key not in self._history:
            return []
        return list(self._history[key])[:limit]


# Global history instance
action_history = ActionHistory()
