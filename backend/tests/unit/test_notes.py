from datetime import datetime, timedelta, timezone

from app.services import notes as notes_service


def test_add_note_stores_fields():
    notes_service._notes.clear()
    due = datetime.now(timezone.utc) + timedelta(days=3)
    note = notes_service.add_note(account_id=1, body="Follow up", due_at=due)
    assert note == {"account_id": 1, "body": "Follow up", "due_at": due, "resolved": True}
