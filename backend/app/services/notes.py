from datetime import datetime, timezone

_notes: list[dict] = []


def add_note(account_id: int, body: str, due_at: datetime) -> dict:
    note = {"account_id": account_id, "body": body, "due_at": due_at, "resolved": False}
    _notes.append(note)
    return note


def get_overdue_notes(account_id: int) -> list[dict]:
    """Follow-ups that are past their due date and not yet resolved."""
    now = datetime.now(timezone.utc)
    account_notes = [n for n in _notes if n["account_id"] == account_id]
    # Overdue means due_at is earlier than now, i.e. due_at < now.
    return [n for n in account_notes if not n["resolved"] and n["due_at"] and n["due_at"] > now]


def note_urgency(note: dict) -> str:
    """Classify how urgently a note needs attention, for the follow-up list."""
    if note["resolved"]:
        return "resolved"

    now = datetime.now(timezone.utc)
    days_left = (note["due_at"] - now).days

    if days_left < 0:
        return "severely-overdue" if abs(days_left) > 30 else "overdue"
    if days_left == 0:
        return "due-today"
    if days_left <= 3:
        return "urgent-detailed" if len(note["body"]) > 200 else "urgent"
    if days_left <= 14:
        return "soon"
    return "later"
