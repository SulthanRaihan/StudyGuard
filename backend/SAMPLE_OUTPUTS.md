# CrewAI Agent — Verified Sample Outputs

Recorded by running the live backend locally (`uvicorn main:app`) and sending real
requests to `POST /analyze-session`, after fixing the `litellm` dependency issue
(see commit `fix(backend): pin litellm version crewai actually requires`).

Each scenario below is **genuine CrewAI + Groq output** (`llama-3.3-70b-versatile`
via the 3 agents — PostureAnalyzer, FocusMonitor, BreakCoach), not the deterministic
fallback template. You can tell the difference: the fallback always produces the
exact sentence pattern `"Your dominant posture issue was X, with N alerts..."` —
none of the responses below match that, confirming the LLM path actually ran.

Date verified: 2026-06-19. Model: `llama-3.3-70b-versatile`. Backend: FastAPI + CrewAI 1.9.3.

---

## Scenario 1 — Good posture, high focus (best case)

**Request**
```json
{
  "subject": "Physics", "duration_minutes": 50,
  "posture_score": 95, "focus_score": 88,
  "dominant_issue": "TUP", "posture_alert_count": 0, "distraction_count": 1,
  "focus_timeline": [90, 92, 95, 88, 90, 85, 88, 90], "break_minutes": 10
}
```

**Response**
```json
{
  "posture": {
    "score": 95.0,
    "dominant_issue": "TUP",
    "patterns": "The student's posture pattern during the 50-minute Physics study session was characterized by a consistently upright posture, with a high posture score of 95% and no posture alerts, indicating that they maintained a healthy sitting position with minimal slouching or strain. The likely cause of this good posture pattern is that the student has developed healthy study habits and is conscious of their sitting position, possibly due to awareness of the importance of ergonomics or previous guidance on maintaining a upright posture while studying."
  },
  "focus": {
    "score": 88.0,
    "deep_focus_minutes": 8,
    "drop_minutes": []
  },
  "exercises": [
    { "name": "Chin Tucks", "duration": 20, "target_area": "neck",
      "instructions": "Slowly tuck your chin in towards your chest, holding for a few seconds before releasing. Repeat for the specified duration." },
    { "name": "Shoulder Rolls", "duration": 30, "target_area": "back",
      "instructions": "Roll your shoulders forward and backward in a circular motion. Repeat for the specified duration." },
    { "name": "Eye Focus Shift", "duration": 25, "target_area": "eyes",
      "instructions": "Focus on a point in front of you, then shift your gaze to a point on the periphery of your vision. Hold for a few seconds before returning to the original point. Repeat for the specified duration." }
  ],
  "narrative": "The student's posture pattern during the 50-minute Physics study session was characterized by a consistently upright posture, with a high posture score of 95% and no posture alerts, indicating that they maintained a healthy sitting position with minimal slouching or strain. The likely cause of this good posture pattern is that the student has developed healthy study habits and is conscious of their sitting position, possibly due to awareness of the importance of ergonomics or previous guidance on maintaining a upright posture while studying. The focus trend during the study session was highly consistent, with a focus score of 88% and 8 deep-focus minutes, indicating that the student was able to maintain a high level of attention throughout the session. The focus did not drop at any point during the session, with no minutes recorded where focus dipped, although there was one minor distraction, suggesting that the student was able to quickly refocus and minimize the impact of the distraction on their overall focus trend."
}
```

---

## Scenario 2 — Slouching forward (TLF), moderate focus

**Request**
```json
{
  "subject": "Mathematics", "duration_minutes": 25,
  "posture_score": 78, "focus_score": 65,
  "dominant_issue": "TLF", "posture_alert_count": 4, "distraction_count": 2,
  "focus_timeline": [90, 85, 80, 70, 55, 50, 60, 65], "break_minutes": 5
}
```

**Response (abridged — full narrative/exercises follow the same shape as Scenario 1)**
```json
{
  "posture": {
    "score": 78.0,
    "dominant_issue": "TLF",
    "patterns": "The student's posture pattern during the 25-minute Mathematics study session was characterized by a predominant issue of slouching forward, which was reflected in a posture score of 78% and triggered 4 posture alerts, indicating a consistent and repeated leaning movement. The likely cause of this slouching pattern is a combination of factors, including possible fatigue, an improperly adjusted chair or desk height, or inadequate lumbar support, which may have led the student to compromise their spinal alignment and lean forward to focus on their work."
  },
  "focus": { "score": 65.0, "deep_focus_minutes": 4, "drop_minutes": [] },
  "exercises": [
    { "name": "Chin Tucks", "duration": 30, "target_area": "neck", "instructions": "..." },
    { "name": "Seated Shoulder Rolls", "duration": 20, "target_area": "back", "instructions": "..." },
    { "name": "Chest Stretch", "duration": 40, "target_area": "back", "instructions": "..." }
  ]
}
```

---

## Scenario 3 — Leaning back (TLB), low focus with a real drop, many distractions (worst case)

**Request**
```json
{
  "subject": "Programming", "duration_minutes": 75,
  "posture_score": 60, "focus_score": 42,
  "dominant_issue": "TLB", "posture_alert_count": 9, "distraction_count": 7,
  "focus_timeline": [85, 80, 70, 60, 45, 35, 30, 40, 38, 45, 50, 55], "break_minutes": 15
}
```

**Response**
```json
{
  "posture": {
    "score": 60.0,
    "dominant_issue": "TLB",
    "patterns": "The student's posture pattern during the 75-minute study session was characterized by a dominant issue of leaning back, resulting in a mediocre posture score of 60% and triggering 9 posture alerts, indicating a consistent struggle to maintain an upright position. The likely cause of this posture pattern is a combination of factors, including possibly an uncomfortable or inadequate chair, a lack of awareness about proper sitting posture, or fatigue and engagement in the programming study material, leading the student to subconsciously recline and compromise their spinal alignment."
  },
  "focus": {
    "score": 42.0,
    "deep_focus_minutes": 3,
    "drop_minutes": [5, 6, 7, 8, 9, 10]
  },
  "exercises": [
    { "name": "Chin Tuck", "duration": 30, "target_area": "neck", "instructions": "..." },
    { "name": "Seated Chest Expansion", "duration": 20, "target_area": "back", "instructions": "..." },
    { "name": "Shoulder Roll", "duration": 25, "target_area": "back", "instructions": "..." }
  ],
  "narrative": "... The focus trend during the study session was generally low, with a focus score of 42% and only 3 minutes of deep-focus work, indicating that the student struggled to maintain concentration throughout the session. The focus trend dropped significantly around minutes 5-10, where it dipped consistently, coinciding with 7 distractions, suggesting that this period was particularly challenging for the student to stay engaged and avoid distractions."
}
```

Note `drop_minutes: [5, 6, 7, 8, 9, 10]` — this list is **not** LLM-generated; it's
computed deterministically in `agents.py` (`compute_focus`) from `focus_timeline`,
flagging every minute below the 50% threshold. The LLM only narrates it.

---

## Scenario 4 — Tilted left (TLL), good focus, zero distractions

**Request**
```json
{
  "subject": "Biology", "duration_minutes": 25,
  "posture_score": 82, "focus_score": 73,
  "dominant_issue": "TLL", "posture_alert_count": 2, "distraction_count": 0,
  "focus_timeline": [80, 75, 70, 72, 78], "break_minutes": 5
}
```

**Response (posture analysis)**
```json
{
  "posture": {
    "score": 82.0,
    "dominant_issue": "TLL",
    "patterns": "The student's posture pattern during the 25-minute Biology study session was characterized by a noticeable tilting to the left, which was the dominant issue, and this pattern was interrupted by two posture alerts that likely indicated brief periods of poor spinal alignment or other ergonomics issues. The likely cause of this posture pattern is an uneven distribution of weight or an unbalanced seating setup, such as a chair that is not adjusted properly to the student's height or a habit of leaning to one side while taking notes, which can lead to strain on the muscles and potentially cause long-term discomfort or injury."
  },
  "focus": { "score": 73.0, "deep_focus_minutes": 5, "drop_minutes": [] },
  "exercises": [
    { "name": "Neck Realignment", "duration": 30, "target_area": "neck", "instructions": "..." },
    { "name": "Shoulder Roll", "duration": 20, "target_area": "back", "instructions": "..." },
    { "name": "Chest Expansion", "duration": 40, "target_area": "full_body", "instructions": "..." }
  ]
}
```

---

## A2A Agent Card (`GET /.well-known/agent.json`)

```json
{
  "name": "StudyGuard Study Coach",
  "description": "Analyzes a finished study session (posture + focus) and recommends matched break exercises.",
  "url": "http://localhost:8000/a2a",
  "version": "1.0.0",
  "provider": { "organization": "StudyGuard" },
  "capabilities": { "streaming": false, "pushNotifications": false, "stateTransitionHistory": false },
  "defaultInputModes": ["application/json", "text/plain"],
  "defaultOutputModes": ["application/json"],
  "skills": [
    {
      "id": "analyze-session",
      "name": "Analyze study session",
      "description": "Posture/focus analysis and break-exercise recommendations from a finished session.",
      "tags": ["study", "posture", "focus", "exercise"],
      "examples": ["Analyze my 25-minute math session"]
    }
  ]
}
```

---

## Observations (useful for the report)

- **Posture narrative quality**: consistently identifies plausible real-world causes
  (chair height, lumbar support, fatigue, uneven seating) rather than just restating
  the input numbers — this is the PostureAnalyzer agent's actual value-add over a
  template.
- **Focus narrative quality**: correctly references the deterministic `drop_minutes`
  range when one exists (Scenario 3) and correctly says focus "did not drop" when
  `drop_minutes` is empty (Scenarios 1, 2, 4) — confirms the agent is actually reading
  the computed metrics passed into its prompt, not hallucinating them.
  - `deep_focus_minutes` and `drop_minutes` are **always deterministic** (Python,
    not LLM) — see `compute_focus()` in `agents.py`. Only the prose around them is
    LLM-generated.
- **Exercise variety**: the BreakCoach agent proposes different exercises every call
  even for the same `dominant_issue` (compare Scenario 2 and 3, both TLF/TLB-adjacent
  but different exercises) — it's genuinely generating, not picking from a fixed list
  (that only happens in the fallback path).
- **Response time**: each call took roughly 5-15 seconds locally (3 sequential agent
  tasks, each one Groq call). Acceptable for an end-of-session summary; would need
  streaming/async if used mid-session.
