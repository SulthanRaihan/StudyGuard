# StudyGuard Agents Backend

FastAPI + CrewAI backend exposing the 3 study agents (PostureAnalyzer, FocusMonitor,
BreakCoach). The agents use **Groq** (`llama-3.3-70b-versatile`) as their LLM.

It's optional: the iOS app only calls it if you set `AgentBackendURL` in `Secrets.plist`.
If the LLM is unavailable, the API still returns sensible deterministic results.

## Run

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # then put your GROQ_API_KEY in .env
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Health check: open http://localhost:8000 → `{"status":"ok"}`.

## API

`POST /analyze-session`

```json
{
  "subject": "Mathematics",
  "duration_minutes": 25,
  "posture_score": 82,
  "focus_score": 74,
  "dominant_issue": "TLF",
  "posture_alert_count": 3,
  "distraction_count": 2,
  "focus_timeline": [90, 85, 80, 70, 60],
  "break_minutes": 5
}
```

Response: `{ posture, focus, exercises[], narrative }`.

## A2A (Agent2Agent) interface

The agent is also exposed over A2A so other agents/frameworks can discover and call it:

- `GET /.well-known/agent.json` — the Agent Card (capabilities + skills)
- `POST /a2a` — JSON-RPC 2.0 `message/send` (pass the session payload as a `data` part)

Example:
```bash
curl http://localhost:8000/.well-known/agent.json

curl -X POST http://localhost:8000/a2a -H 'Content-Type: application/json' -d '{
  "jsonrpc":"2.0","id":"1","method":"message/send",
  "params":{"message":{"role":"user","parts":[{"kind":"data","data":{
    "subject":"Mathematics","duration_minutes":25,"posture_score":82,"focus_score":74,
    "dominant_issue":"TLF","focus_timeline":[90,80,60],"break_minutes":5}}]}}}'
```

## Point the iOS app at it

The iOS app reads `AgentBackendURL` from `Secrets.plist` (gitignored). Add:

```xml
<key>AgentBackendURL</key>
<string>https://YOUR-NGROK-SUBDOMAIN.ngrok-free.app</string>
```

- **iOS Simulator** can reach `http://localhost:8000` directly *(needs an ATS exception
  for plain HTTP — easiest is to use HTTPS via ngrok instead).*
- **Physical device**: localhost won't work. Expose the server over HTTPS, e.g.:
  ```bash
  ngrok http 8000
  ```
  and use the `https://…ngrok…` URL. HTTPS also avoids App Transport Security issues.

If `AgentBackendURL` is not set, the app simply doesn't show the agent "Coach Analysis"
card — everything else (Groq summary, ExerciseDB) works unchanged.
