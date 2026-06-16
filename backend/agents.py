"""
StudyGuard CrewAI agents.

Three agents per the project spec:
  - PostureAnalyzerAgent  -> posture patterns
  - FocusMonitorAgent     -> focus trend
  - BreakCoachAgent       -> matched break exercises

Deterministic metrics (deep-focus minutes, drop minutes) are computed in Python;
the qualitative analysis + exercise suggestions come from the crew (Groq LLM).
If CrewAI/the LLM is unavailable, every endpoint still returns a sensible
templated fallback so the API never hard-fails.
"""

import json
import os
import re
from typing import List, Tuple

from models import (
    SessionPayload, AnalysisResponse, PostureAnalysis, FocusAnalysis, Exercise,
)

POSTURE_LABELS = {
    "TUP": "upright posture",
    "TLF": "slouching forward",
    "TLB": "leaning back",
    "TLR": "tilting right",
    "TLL": "tilting left",
}

DEEP_FOCUS_THRESHOLD = 70
FOCUS_DROP_THRESHOLD = 50


# ─────────────────────────────────────────────────────────────────────────────
# Deterministic metrics
# ─────────────────────────────────────────────────────────────────────────────

def compute_focus(timeline: List[int]) -> Tuple[int, List[int]]:
    """Returns (deep_focus_minutes, drop_minutes)."""
    if not timeline:
        return 0, []
    deep = sum(1 for v in timeline if v >= DEEP_FOCUS_THRESHOLD)
    drops = [i + 1 for i, v in enumerate(timeline) if v < FOCUS_DROP_THRESHOLD]
    return deep, drops


# ─────────────────────────────────────────────────────────────────────────────
# Public entry point
# ─────────────────────────────────────────────────────────────────────────────

def run_agents(payload: SessionPayload) -> AnalysisResponse:
    deep, drops = compute_focus(payload.focus_timeline)
    narrative, patterns, focus_text, exercises = _crew_analysis(payload, deep, drops)

    return AnalysisResponse(
        posture=PostureAnalysis(
            score=payload.posture_score,
            dominant_issue=payload.dominant_issue,
            patterns=patterns,
        ),
        focus=FocusAnalysis(
            score=payload.focus_score,
            deep_focus_minutes=deep,
            drop_minutes=drops,
        ),
        exercises=exercises,
        narrative=narrative,
    )


# ─────────────────────────────────────────────────────────────────────────────
# CrewAI
# ─────────────────────────────────────────────────────────────────────────────

def _crew_analysis(payload: SessionPayload, deep: int, drops: List[int]):
    issue = POSTURE_LABELS.get(payload.dominant_issue or "", "no major issue")
    try:
        from crewai import Agent, Task, Crew, Process, LLM

        llm = LLM(model="groq/llama-3.3-70b-versatile",
                  api_key=os.environ["GROQ_API_KEY"])

        posture_analyst = Agent(
            role="Posture Analyst",
            goal="Identify posture problems and their likely cause from a study session",
            backstory="An ergonomics expert who helps students sit healthily.",
            llm=llm, verbose=False, allow_delegation=False,
        )
        focus_monitor = Agent(
            role="Focus Monitor",
            goal="Interpret attention trends across a study session",
            backstory="A learning-science coach who reads focus data.",
            llm=llm, verbose=False, allow_delegation=False,
        )
        break_coach = Agent(
            role="Break Coach",
            goal="Recommend short desk-friendly stretches matched to the posture problem",
            backstory="A physiotherapist who designs effective micro-breaks.",
            llm=llm, verbose=False, allow_delegation=False,
        )

        posture_task = Task(
            description=(
                f"A student studied {payload.subject} for {payload.duration_minutes} minutes. "
                f"Posture score {payload.posture_score:.0f}%. Dominant issue: {issue}. "
                f"Posture alerts: {payload.posture_alert_count}. "
                "In 2 sentences, describe the posture pattern and its likely cause."
            ),
            agent=posture_analyst,
            expected_output="Two sentences describing posture patterns.",
        )
        focus_task = Task(
            description=(
                f"Focus score {payload.focus_score:.0f}%. Deep-focus minutes: {deep}. "
                f"Focus dipped around minutes: {drops or 'none'}. "
                f"Distractions: {payload.distraction_count}. "
                "In 2 sentences, summarize the focus trend and when it dropped."
            ),
            agent=focus_monitor,
            expected_output="Two sentences describing the focus trend.",
        )
        coach_task = Task(
            description=(
                f"Given the dominant posture issue '{issue}' and a {payload.break_minutes}-minute break, "
                "recommend exactly 3 short stretches. Respond ONLY with a JSON array of objects with keys: "
                "name, duration (seconds), target_area (one of neck, back, eyes, full_body), instructions."
            ),
            agent=break_coach,
            expected_output="A JSON array of exactly 3 exercise objects.",
        )

        crew = Crew(
            agents=[posture_analyst, focus_monitor, break_coach],
            tasks=[posture_task, focus_task, coach_task],
            process=Process.sequential,
            verbose=False,
        )
        crew.kickoff()

        patterns = str(posture_task.output).strip()
        focus_text = str(focus_task.output).strip()
        exercises = _parse_exercises(str(coach_task.output), payload.dominant_issue)
        narrative = f"{patterns} {focus_text}".strip()
        return narrative, patterns, focus_text, exercises

    except Exception as exc:  # noqa: BLE001 — any failure -> deterministic fallback
        print(f"[agents] crew unavailable, using fallback: {exc}")
        patterns = (
            f"Your dominant posture issue was {issue}, "
            f"with {payload.posture_alert_count} alerts during the session."
        )
        if drops:
            focus_text = (
                f"You had about {deep} minutes of deep focus, "
                f"with dips around minute(s) {', '.join(map(str, drops[:5]))}."
            )
        else:
            focus_text = f"You held steady focus for about {deep} minutes."
        narrative = f"{patterns} {focus_text}"
        return narrative, patterns, focus_text, _fallback_exercises(payload.dominant_issue)


def _parse_exercises(text: str, issue: str | None) -> List[Exercise]:
    try:
        match = re.search(r"\[.*\]", text, re.S)
        data = json.loads(match.group(0)) if match else []
        out: List[Exercise] = []
        for e in data[:3]:
            out.append(Exercise(
                name=str(e.get("name", "Stretch")),
                duration=int(e.get("duration", 30)),
                target_area=str(e.get("target_area", "full_body")),
                instructions=str(e.get("instructions", "")),
            ))
        if out:
            return out
    except Exception:  # noqa: BLE001
        pass
    return _fallback_exercises(issue)


def _fallback_exercises(issue: str | None) -> List[Exercise]:
    eye = Exercise(name="Eye rest (20-20-20)", duration=20, target_area="eyes",
                   instructions="Look at something ~6 meters away for 20 seconds.")
    if issue in ("TLF", "TLB"):
        return [
            Exercise(name="Upper back stretch", duration=30, target_area="back",
                     instructions="Clasp hands in front, push forward, round your upper back."),
            Exercise(name="Shoulder rolls", duration=20, target_area="back",
                     instructions="Roll both shoulders backward 10 times."),
            eye,
        ]
    if issue in ("TLR", "TLL"):
        return [
            Exercise(name="Side neck stretch", duration=20, target_area="neck",
                     instructions="Tilt your head right then left, 10 seconds each side."),
            Exercise(name="Shoulder shrugs", duration=20, target_area="neck",
                     instructions="Raise shoulders to ears, hold, release. 10 times."),
            eye,
        ]
    return [
        Exercise(name="Stand & stretch", duration=30, target_area="full_body",
                 instructions="Stand, reach overhead, and stretch your whole body."),
        Exercise(name="Slow neck rolls", duration=20, target_area="neck",
                 instructions="Roll your head slowly clockwise and counter-clockwise."),
        eye,
    ]
