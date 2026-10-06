from typing import Annotated

from dateutil.parser import parse as parse_date
from fastapi import APIRouter, Body
import httpx
from app.services import notes as notes_service

router = APIRouter()

NOTIFY_WEBHOOK_URL = "https://hooks.example.com/notes-overdue"


@router.get("/account/{account_id}/overdue")
def list_overdue_notes(account_id: int):
    return notes_service.get_overdue_notes(account_id)


@router.post("/account/{account_id}")
def create_note(
    account_id: int,
    body: Annotated[str, Body()],
    due_at: Annotated[str, Body()],
):
    note = notes_service.add_note(account_id, body, parse_date(due_at))
    httpx.post(NOTIFY_WEBHOOK_URL, json={"account_id": account_id, "body": body})
    return note
