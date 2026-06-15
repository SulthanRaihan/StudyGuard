"""
StudyGuard agents API (FastAPI).

Run:
    cd backend
    python -m venv .venv && source .venv/bin/activate
    pip install -r requirements.txt
    cp .env.example .env   # then add your GROQ_API_KEY
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""

from dotenv import load_dotenv
from fastapi import FastAPI

from agents import run_agents
from models import AnalysisResponse, SessionPayload

load_dotenv()

app = FastAPI(title="StudyGuard Agents", version="1.0")


@app.get("/")
def health():
    return {"status": "ok", "service": "studyguard-agents"}


@app.post("/analyze-session", response_model=AnalysisResponse)
def analyze_session(payload: SessionPayload):
    """Runs the 3 agents over a finished session and returns combined insights."""
    return run_agents(payload)
