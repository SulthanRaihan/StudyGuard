"""
A2A (Agent2Agent) interface for the StudyGuard agents.

Exposes the standard A2A discovery + messaging surface so other agents/frameworks
can call our study-coach agent:

  GET  /.well-known/agent.json   -> the Agent Card (capabilities + skills)
  POST /a2a                      -> JSON-RPC 2.0 `message/send`

This is a minimal, self-contained A2A server (no SDK) for demonstration. The same
`run_agents` logic powers both the REST endpoint and this A2A endpoint.
"""

import json
from typing import Any, Optional

from fastapi import APIRouter, Request

from agents import run_agents
from models import SessionPayload

router = APIRouter()

AGENT_CARD: dict[str, Any] = {
    "name": "StudyGuard Study Coach",
    "description": "Analyzes a finished study session (posture + focus) and recommends "
                   "matched break exercises.",
    "url": "http://localhost:8000/a2a",
    "version": "1.0.0",
    "provider": {"organization": "StudyGuard"},
    "capabilities": {
        "streaming": False,
        "pushNotifications": False,
        "stateTransitionHistory": False,
    },
    "defaultInputModes": ["application/json", "text/plain"],
    "defaultOutputModes": ["application/json"],
    "skills": [
        {
            "id": "analyze-session",
            "name": "Analyze study session",
            "description": "Posture/focus analysis and break-exercise recommendations "
                           "from a finished session.",
            "tags": ["study", "posture", "focus", "exercise"],
            "examples": ["Analyze my 25-minute math session"],
        }
    ],
}


@router.get("/.well-known/agent.json")
def agent_card() -> dict[str, Any]:
    return AGENT_CARD


def _extract_payload(parts: list[dict[str, Any]]) -> Optional[dict[str, Any]]:
    """Pull the session payload from A2A message parts (DataPart or JSON TextPart)."""
    for part in parts:
        if part.get("kind") == "data" and isinstance(part.get("data"), dict):
            return part["data"]
    for part in parts:
        if part.get("kind") == "text":
            try:
                return json.loads(part.get("text", ""))
            except json.JSONDecodeError:
                continue
    return None


@router.post("/a2a")
async def a2a(request: Request) -> dict[str, Any]:
    body = await request.json()
    req_id = body.get("id")

    if body.get("method") != "message/send":
        return {"jsonrpc": "2.0", "id": req_id,
                "error": {"code": -32601, "message": "Method not found"}}

    message = body.get("params", {}).get("message", {})
    payload = _extract_payload(message.get("parts", []))
    if payload is None:
        return {"jsonrpc": "2.0", "id": req_id,
                "error": {"code": -32602, "message": "No session data in message parts"}}

    try:
        result = run_agents(SessionPayload(**payload))
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "role": "agent",
                "kind": "message",
                "messageId": str(req_id or "response"),
                "parts": [{"kind": "data", "data": result.model_dump()}],
            },
        }
    except Exception as exc:  # noqa: BLE001
        return {"jsonrpc": "2.0", "id": req_id,
                "error": {"code": -32000, "message": str(exc)}}
