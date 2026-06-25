# StudyGuard — Full Application Documentation

> An AI-powered iOS study companion that watches your posture and focus through the
> front camera, coaches you in real time, recommends breaks, and tracks long-term
> progress with gamification — like a fitness app, but for studying.

This document describes the application **exactly as implemented** in this
repository (not just the original design spec) — every threshold, formula, data
model, and flow below is taken directly from the current source code.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Tech Stack](#2-tech-stack)
3. [Project Structure](#3-project-structure)
4. [High-Level Architecture](#4-high-level-architecture)
5. [Data Models](#5-data-models)
6. [Complete User Flow](#6-complete-user-flow)
7. [Computer Vision / ML Pipeline](#7-computer-vision--ml-pipeline)
8. [AI Integrations](#8-ai-integrations)
9. [CrewAI Backend (Python)](#9-crewai-backend-python)
10. [Firebase / Data Persistence](#10-firebase--data-persistence)
11. [Gamification System](#11-gamification-system)
12. [Design System ("Guri Warm")](#12-design-system-guri-warm)
13. [Settings & Configuration](#13-settings--configuration)
14. [Known Limitations & Accuracy Notes](#14-known-limitations--accuracy-notes)
15. [Setup & Running Instructions](#15-setup--running-instructions)
16. [Notable Engineering Fixes (History)](#16-notable-engineering-fixes-history)

---

## 1. Overview

**StudyGuard** is a native SwiftUI iOS app (iOS 16+) built around one core loop:

```
Sit down to study → app watches posture & focus via the front camera
   → coaches you in real time (voice, stickers, sound, alerts)
   → on break, helps you stretch and answer questions
   → after the session, an AI summarizes how it went
   → over time, a dashboard shows trends, streaks, and badges
```

It combines:
- **On-device computer vision** (Apple Vision + a custom-trained CoreML model) for
  posture and focus detection — no video ever leaves the device.
- **Cloud AI** (Groq's `llama-3.3-70b-versatile`) for natural-language coaching,
  problem-solving, flashcards, and study planning.
- **An optional CrewAI multi-agent Python backend** exposed both as a normal REST
  API and as an **A2A (Agent2Agent)** endpoint, for a deeper structured analysis
  of each session.
- **Firebase** (Auth + Firestore) for accounts, persistence, and analytics.
- A custom mascot, **Guri** 🐱, used throughout the UI (logo, onboarding, session
  calibration, celebrations, break companion, and reactive "mood" stickers).

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI, iOS 16.4+ deployment target |
| Camera | AVFoundation (`AVCaptureSession`, front camera, 30 fps, portrait) |
| Computer Vision | Apple Vision (`VNDetectHumanBodyPoseRequest`, `VNDetectFaceLandmarksRequest`, `VNRecognizeTextRequest`) |
| Posture ML model | CoreML — `PostureClassifier.mlmodel` (Create ML Tabular / Boosted Tree Classifier, 5 iterations, max depth 3) |
| Focus detection | Apple Vision only — no custom model (eye openness + head pose) |
| OCR (Scan & Solve) | Apple Vision `VNRecognizeTextRequest`, fully on-device |
| Charts | Swift Charts (`Chart`, `BarMark`, `ChartProxy`) |
| Voice | `AVSpeechSynthesizer` (English by default, Indonesian selectable) |
| Ambient sound | `AVAudioEngine` (procedurally generated brown noise) |
| Sound effects | `AVAudioPlayer` (bundled `.mp3` files) |
| Auth | Firebase Authentication (email/password + Google Sign-In) |
| Database | Firebase Firestore |
| Photo picking | `UIImagePickerController` (camera) + `PHPickerViewController` (library) |
| LLM (cloud) | Groq API, model `llama-3.3-70b-versatile` |
| Multi-agent backend | CrewAI (Python), FastAPI, optional, calls Groq under the hood via LiteLLM |
| Agent interoperability | A2A (Agent2Agent) protocol — Agent Card + JSON-RPC `message/send` |
| Exercise data | ExerciseDB API (RapidAPI) — animated GIF demos, with local fallback |
| Notifications | `UNUserNotificationCenter` (local notifications) |
| Persistence (local) | `UserDefaults` (`AppSettingsStore`) |

---

## 3. Project Structure

```
StudyGuard/
├── App/
│   ├── StudyGuardApp.swift          # @main; configures Firebase, handles Google Sign-In URL callback
│   └── ContentView.swift            # Root router: Auth (Onboarding/Login/Register) vs MainView
│
├── Core/
│   ├── Models/
│   │   ├── User.swift                # User, StudyLevel, UserSettings, AlertSensitivity
│   │   ├── StudySession.swift
│   │   ├── PostureEvent.swift        # PostureType (TUP/TLF/TLB/TLR/TLL), PostureSeverity
│   │   ├── FocusEvent.swift          # FocusState (focused/drowsy/distracted)
│   │   ├── FocusSample.swift
│   │   ├── SessionResult.swift       # Snapshot of a finished session (summary/break/persistence)
│   │   ├── BreakExercise.swift       # TargetArea (neck/back/eyes/full_body)
│   │   ├── Flashcard.swift
│   │   └── StudyPlan.swift           # StudyPlanDay, StudyPlanTask
│   │
│   ├── Services/
│   │   ├── AuthService.swift         # Firebase Auth + Google Sign-In
│   │   ├── FirebaseService.swift     # All Firestore reads/writes
│   │   ├── GroqService.swift         # All 6 Groq LLM use cases
│   │   ├── ExerciseAPIService.swift  # ExerciseDB API + local fallback
│   │   ├── VoiceAlertService.swift   # AVSpeechSynthesizer wrapper, per-message cooldown
│   │   ├── FocusSoundService.swift   # Procedural brown-noise ambience
│   │   ├── SoundEffectService.swift  # One-shot bundled sound effects
│   │   └── NotificationService.swift # Local "break's over" notification
│   │
│   ├── Managers/
│   │   ├── SessionManager.swift      # Orchestrates an active session end-to-end
│   │   ├── PostureManager.swift      # Posture inference, smoothing, calibration, alerts
│   │   └── FocusManager.swift        # Focus inference, debounced state machine
│   │
│   └── DesignSystem/
│       ├── Theme.swift               # "Guri Warm" color palette
│       ├── BrandKit.swift            # BrandImage, card/button styles
│       └── AppSettings.swift         # UserDefaults-backed settings store
│
├── Vision/
│   ├── CameraManager.swift           # AVCaptureSession: front camera, un-mirrored data, 30fps
│   ├── CameraPreviewView.swift       # SwiftUI wrapper around AVCaptureVideoPreviewLayer (mirrored)
│   ├── PostureDetector.swift         # VNDetectHumanBodyPoseRequest → 24 features → CoreML
│   ├── FocusDetector.swift           # VNDetectFaceLandmarksRequest → eye/gaze/distance signals
│   ├── DataScannerView.swift         # (Unused fallback path — see TextScanner.swift)
│   └── TextScanner.swift             # CameraPhotoPicker, PhotoLibraryPicker, TextRecognizer (OCR)
│
├── ML/
│   └── PostureClassifier.mlmodel     # Trained CoreML model (Create ML Tabular Classifier)
│
├── Agents/
│   ├── AgentService.swift            # HTTP client for the optional CrewAI backend
│   └── AgentModels.swift             # AgentSessionPayload, AgentAnalysis (snake_case wire format)
│
├── Features/
│   ├── Auth/
│   │   ├── OnboardingView.swift      # "Start Your Journey" — logo, Sign Up / Sign In / Google
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   │
│   ├── Home/
│   │   └── HomeView.swift            # Greeting, Guri growth card (level + XP bar), stats, CTA
│   │
│   ├── PreSession/
│   │   └── PreSessionSetupView.swift # Subject chips + duration (25/50/75 min)
│   │
│   ├── Session/
│   │   ├── SessionView.swift         # Live camera + postur/focus overlay, the whole session UI
│   │   ├── PostureOverlayView.swift  # Skeleton overlay (built, currently disabled in SessionView)
│   │   ├── FocusScoreView.swift      # Circular score gauge (reused for Focus + Posture)
│   │   └── SessionSummaryView.swift  # Post-session stats + Groq insight + optional Coach Analysis
│   │
│   ├── Break/
│   │   ├── BreakView.swift           # Break screen — camera off, stretches, chat, scan
│   │   ├── ExerciseCardView.swift    # Tappable exercise row (GIF thumbnail)
│   │   ├── ExerciseDetailView.swift  # Full-size GIF + instructions
│   │   ├── BreakChatView.swift       # "Ask Guri" — Groq Q&A during break
│   │   └── AnimatedGIFView.swift     # Native ImageIO GIF player (UIKit-backed)
│   │
│   ├── Scan/
│   │   ├── ScanView.swift            # Camera/library photo → OCR → Solve or Flashcards
│   │   └── FlashcardsView.swift      # Tap-to-flip flashcard viewer
│   │
│   ├── Planner/
│   │   └── PlannerView.swift         # AI study planner (subjects/days/hours → Groq plan)
│   │
│   ├── Dashboard/
│   │   ├── DashboardView.swift       # Streak heatmap, charts, weekly report, history, badges link
│   │   ├── SessionDetailView.swift   # One session's full stats + per-minute focus chart
│   │   └── BadgesView.swift          # Achievement grid
│   │
│   ├── Settings/
│   │   └── SettingsView.swift        # Sensitivity, voice, alert toggles (synced to Firestore)
│   │
│   └── Main/
│       └── MainView.swift            # Authenticated root: floating pill tab bar + session flow
│
└── Resources/
    ├── Assets.xcassets               # Guri art (GuriLogo/GuriHi/GuriBreak/GuriCelebrate) +
    │                                  # state stickers (BUNGKUK/Leaning/drowsy/distract/Good Form)
    ├── Sounds/                       # bungkuk.mp3, leaning.mp3 (sound effects)
    └── Info.plist                    # Camera usage, Google Sign-In URL scheme, local-network ATS

backend/                              # Optional Python CrewAI service (separate from the iOS app)
├── main.py                           # FastAPI app: /, /analyze-session, mounts the A2A router
├── agents.py                         # The 3 CrewAI agents + deterministic fallback
├── a2a.py                            # A2A Agent Card + JSON-RPC message/send endpoint
├── models.py                         # Pydantic request/response schemas
├── requirements.txt
├── .env.example                      # GROQ_API_KEY template
└── README.md                         # Setup + A2A usage examples
```

---

## 4. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              iOS APP (SwiftUI)                          │
│                                                                          │
│  ContentView (root router)                                             │
│   ├─ Not authenticated → OnboardingView → LoginView / RegisterView      │
│   └─ Authenticated     → MainView                                      │
│         ├─ floating pill tabs: Home · Plan · Stats · Settings          │
│         └─ full-screen session flow:                                   │
│              PreSessionSetupView                                       │
│                → SessionView (camera + live ML overlay)                │
│                     → SessionSummaryView                               │
│                                                                          │
│  SessionView is driven by SessionManager, which owns:                  │
│   - CameraManager  (AVCaptureSession, un-mirrored frames)               │
│   - PostureManager (CoreML inference, smoothing, calibration, alerts)  │
│   - FocusManager   (Vision face inference, debounced state machine)    │
│   - VoiceAlertService (coaching speech)                                │
│                                                                          │
└───────────────┬───────────────────────────┬────────────────────────────┘
                │                            │
   ┌────────────▼────────────┐   ┌───────────▼────────────────┐
   │   Firebase (cloud)      │   │   Groq API (cloud)         │
   │  - Auth                 │   │  llama-3.3-70b-versatile   │
   │  - Firestore            │   │  - session summary         │
   │    (users/sessions/     │   │  - solve problem (OCR)     │
   │     events/settings)    │   │  - flashcards              │
   └──────────────────────────┘   │  - study plan              │
                                   │  - weekly report            │
                                   │  - break chat                │
                                   └───────────┬───────────────┘
                                               │ (same model, called
                                               │  server-side via LiteLLM)
                                   ┌───────────▼───────────────────────┐
                                   │  CrewAI Backend (Python, optional)│
                                   │  FastAPI on :8000                 │
                                   │  - POST /analyze-session (REST)   │
                                   │  - POST /a2a (A2A JSON-RPC)       │
                                   │  - GET /.well-known/agent.json    │
                                   │  3 agents: PostureAnalyst,        │
                                   │  FocusMonitor, BreakCoach          │
                                   └────────────────────────────────────┘
```

The CrewAI backend is **entirely optional** — `AgentService.isConfigured` is only
`true` if `AgentBackendURL` is set in `Secrets.plist`. If unset, unreachable, or it
errors, the app simply doesn't show the "Coach Analysis" card; nothing else is
affected (Groq calls and everything else work independently).

---

## 5. Data Models

### `PostureType` (`PostureEvent.swift`)
```swift
enum PostureType: String, Codable {
    case tup = "TUP"  // upright / good posture
    case tlf = "TLF"  // slouching forward
    case tlb = "TLB"  // leaning back
    case tlr = "TLR"  // tilted right
    case tll = "TLL"  // tilted left
}
```
Each case has a shared `coachingMessage` (used by both the voice coach and the
on-screen alert banner, so they stay in sync) and `isGood` (`true` only for `.tup`).

### `FocusState` (`FocusEvent.swift`)
```swift
enum FocusState: String, Codable { case focused, drowsy, distracted }
```

### `SessionResult` (`SessionResult.swift`)
The single source of truth passed between `SessionManager` → `SessionView` →
`SessionSummaryView` / `BreakView` → Firestore. Carries: `sessionId`, `subject`,
`totalSeconds`, `targetMinutes`, `avgPosture`, `avgFocus`, `postureAlertCount`,
`distractionCount`, `dominantIssue`, `focusTimeline: [Int]` (per-minute focus
score), `startedAt`. Computed: `durationMinutes`, `breakMinutes` (Pomodoro-style:
<50 min → 5 min break, 50–75 → 10 min, else 15 min), `focusTimelineString` (for
Groq prompts).

### `User` / `UserSettings` / `AlertSensitivity` (`User.swift`)
```swift
enum StudyLevel: String, Codable {
    case beginner = "Beginner", scholar = "Scholar", eliteScholar = "Elite Scholar"
    // 0–500 XP -> Beginner, 500–2000 -> Scholar, 2000+ -> Elite Scholar
}

enum AlertSensitivity: String, Codable {
    case low, medium, high
    // thresholdSeconds: low=20s, medium=10s, high=5s
    // (seconds of sustained bad posture before a voice/visual alert fires)
}
```

### `BreakExercise` / `TargetArea`
```swift
struct BreakExercise: Codable, Identifiable {
    var id, name: String
    var duration: Int            // seconds
    var targetArea: TargetArea   // .neck / .back / .eyes / .fullBody
    var instructions: String?
    var gifUrl: String?          // ExerciseDB animated demo
    var completed: Bool = false
}
```

### `Flashcard`, `StudyPlanDay` / `StudyPlanTask`
Simple `question`/`answer` pairs, and `{ day: String, tasks: [{subject, activity, minutes}] }`
— both are parsed out of Groq's JSON-only responses (see §8).

---

## 6. Complete User Flow

### 6.1 Onboarding → Auth
```
App launch → FirebaseApp.configure()
   ↓
ContentView checks AuthService.isAuthenticated
   ↓ (not signed in)
OnboardingView — Guri logo, "Start Your Journey"
   ↓
Sign Up → RegisterView (name/email/password, or "Continue with Google")
Sign In → LoginView (email/password, or "Continue with Google")
   ↓
On success → AuthService.currentUserId set (via Firebase Auth state listener)
   → on first sign-in, FirebaseService.createUserProfile() seeds the user doc
   (totalXP: 0, currentStreak: 0, studyLevel: "Beginner", …)
```
Google Sign-In flow: `GIDSignIn` presents over the top-most view controller,
exchanges the Google ID token for a Firebase credential, and signs in. New Google
users also get a freshly-created Firestore profile.

### 6.2 MainView — the authenticated shell
A `ZStack` with a **floating dark pill nav** (Home · Plan · Stats · Settings) over
cream background. On first appearance, `loadCloudSettings()` pulls the user's
saved settings from Firestore into local `UserDefaults` (so a fresh install on a
new device picks up prior preferences).

The pill nav **disappears** whenever a session, summary, or pre-session setup is
active — those are full-screen flows layered on top of the tab content.

### 6.3 Starting a session
```
HomeView "Start Study Session" → showSetup = true
   ↓
PreSessionSetupView: pick a subject (chip grid: Mathematics, Physics, Chemistry,
Biology, Programming, Design, English, Economics, History, Other...) and a
duration (25 / 50 / 75 minutes)
   ↓
SessionManager created (subject, duration, userId, current AlertSensitivity/
voice settings from AppSettingsStore) → activeSession set → SessionView shown
```

### 6.4 Inside a session — phase machine
`SessionManager.Phase`: `.calibrating → .studying ⇄ .paused → .finished(reason)`

**1. Calibration (4 seconds, before the clock starts)**
- Camera starts; `PostureManager.calibrate(seconds: 4)` begins tallying the raw
  CoreML predictions while the UI shows "Sit up straight... this helps Guri learn
  your good posture" + a tip to keep the camera at eye level.
- The most frequent prediction during this window becomes `baselineClass`. From
  then on, whenever the model predicts that exact class, it's remapped to `.tup`
  (upright) — this corrects for the model's well-known TUP/TLB confusion on a
  per-user basis (see §14).
- `baselineFaceWidth` (face bounding-box width) is also captured here as the
  "comfortable distance" reference, used later to detect leaning in too close.

**2. Studying (`.studying`)**
Every second, `SessionManager.tick()`:
- Accumulates running averages `avgPosture` / `avgFocus` from the two managers'
  rolling 60-second scores.
- Every 30s: writes a `focusSamples` Firestore document (fire-and-forget).
- Every 60s: appends to `focusTimeline`, runs `checkAdaptiveTimer()`.
- If the live face width exceeds `baselineFaceWidth × 1.25`: speaks "You're
  leaning in too close — sit back a little" (25s cooldown).
- Every 20 minutes: "Time to rest your eyes — look at something far away for 20
  seconds."
- Every 30 minutes: "Don't forget to drink some water!"
- At 0 remaining seconds: ends the session (`.timerComplete`) and announces
  completion.

**Adaptive timer** (`checkAdaptiveTimer`, checked once a minute):
| Condition | Effect |
|---|---|
| Recent focus > 85% **and** at/past target time | Extends the session by 5 minutes; "You're in deep focus — let's add 5 more minutes!" |
| Recent focus < 40% **and** more than 15 min elapsed | Ends early (`.focusDrop`); "Your focus is dropping — let's wrap up this session." |
| Otherwise, time's up | Normal on-time completion |

**Live overlay (`SessionView`)** while studying shows:
- Header: subject name, countdown timer, ambient-sound toggle, pause button.
- A posture label card (e.g. "Slouching forward", confidence %), or "Looking for
  you…" if no body is detected.
- A red alert banner whenever `posture.activeAlert` is non-nil (sustained bad
  posture past the sensitivity threshold) — paired with a haptic
  (`UINotificationFeedbackGenerator`), a **sound effect** (`bungkuk.mp3` for TLF,
  `leaning.mp3` for TLB/TLR/TLL), and the voice coaching message.
- Two circular gauges (Focus, Posture) from `FocusScoreView`, each with a small
  animated **sticker badge** in the top-right corner reflecting the current state:

  | Condition | Sticker asset |
  |---|---|
  | Posture = upright (TUP) | `Good Form` |
  | Posture = slouching forward (TLF) | `BUNGKUK` |
  | Posture = leaning back / tilted (TLB, TLR, TLL) | `Leaning` |
  | Focus = drowsy | `drowsy` |
  | Focus = distracted | `distract` |
  | Focus = focused | *(no sticker)* |

  (The skeleton-overlay feature, `PostureOverlayView`, was built — joint points
  mapped through the mirrored/aspect-filled camera coordinate space — but is
  **currently disabled** in `SessionView`; it's left in the project unused.)

**Voice coaching** (`SessionManager.observeAlerts`, via Combine on
`posture.$activeAlert` / `focus.$currentState`):
- Sustained bad posture → speaks `PostureType.coachingMessage`, increments
  `postureAlertCount`, and starts a **posture episode** for event logging.
- Drowsy → "You look drowsy — take a deep breath." (20s cooldown)
- Distracted → "Let's get back to your study material." (45s cooldown),
  increments `distractionCount`.
- When an episode (posture or focus) ends, its **duration** is written to
  Firestore (`postureEvents` / `focusEvents`) with a severity derived from how
  long it lasted (`mild` <15s, `moderate` <30s, `severe` ≥30s for posture).

**3. Pause / Resume (`.paused`)**
Tapping pause stops the camera, detectors, and timer (but keeps elapsed state).
The pause overlay offers:
- **Resume** — camera and detectors reconnect, timer restarts.
- **Take a break** — opens `BreakView` mid-session (`isMidSession: true`,
  button reads "Resume Studying"); on close, the session resumes automatically.
- **End session** — ends immediately (`.userEnded`).

**4. Finished (`.finished(reason)`)**
A celebratory overlay (Guri celebrating 🎉) with duration/posture/focus stats and
a **"View Summary"** button — there's no automatic break offer here: *"done means
done."* The only way to reach `BreakView` is through the in-session pause menu.

### 6.5 Break (`BreakView`)
Opened either mid-session (from pause) or — in earlier flows — after a session.
Camera is off. Shows:
- Guri (`GuriBreak`) + a live countdown (Pomodoro-derived break length).
- A list of stretches (`ExerciseAPIService`, matched to the dominant posture
  issue) — tap a card for instructions + an animated GIF; tap the checkmark to
  mark it done.
- **"Ask Guri"** → `BreakChatView`, a Groq-backed Q&A chat about the subject.
- **"Scan & Solve"** → opens `ScanView` *from inside the break* (camera/library
  photo → OCR → AI answer/flashcards) — so a study question doesn't require a
  full chat conversation.
- A local notification ("Break's over 🐱") is scheduled so the user is nudged
  even if they background the app.
- On finishing, the break (with each exercise's completed state) is logged to
  the `breakSessions` Firestore collection.

### 6.6 Session Summary
`SessionSummaryView` shows duration/posture/focus stats, then **in parallel**:
1. **AI Insight** (always attempted) — `GroqService.sessionSummary(for:)`, a
   ~150-word personal narrative mentioning focus drops and 2 concrete tips.
2. **Coach Analysis** (only if `AgentBackendURL` is configured) —
   `AgentService.analyze(result)` calls the CrewAI backend; if it succeeds, a
   second card shows the agents' posture patterns, focus-drop minutes, and
   AI-suggested stretches.

Tapping **Done** persists the session (`FirebaseService.recordSession` — see
§10/§11 for the XP/streak math) and returns to `HomeView`.

### 6.7 Scan & Solve (also reachable from Home directly)
```
ScanView → "Take Photo" (UIImagePickerController, camera) or
           "Choose Photo" (PHPickerViewController, library)
   ↓
TextRecognizer.recognize(in:) — on-device VNRecognizeTextRequest (.accurate,
language correction on) — the captured image NEVER leaves the device; only the
recognized text is sent anywhere.
   ↓
Editable text field (manual correction/typing also supported)
   ↓
"Solve with AI" → GroqService.solveProblem() → shown in a sheet
"Flashcards"    → GroqService.generateFlashcards() → FlashcardsView (tap to flip)
```

### 6.8 AI Study Planner (`PlannerView`, "Plan" tab)
User multi-selects subjects, sets days (1–14) and hours/day (1–8). On generate,
`SessionStats.bestFocusHour(_:)` computes the user's historically-best-focus hour
from past sessions and feeds it into the Groq prompt, so the plan schedules
demanding subjects around when the user actually focuses best. The resulting
plan (JSON-parsed day/task list) is shown and persisted to the user's Firestore
document (`studyPlan` field, JSON-encoded).

### 6.9 Dashboard ("Stats" tab)
- **Hero card**: streak / total XP / level (gradient orange card).
- **Streak calendar**: a GitHub-style 35-day heatmap, color intensity by minutes
  studied that day.
- **Stat tiles**: session count, average focus %, average posture % — each with a
  **week-over-week delta** badge (e.g. "+12%") comparing the last 7 days to the
  7 days before that.
- **Focus chart** and **Posture chart**: 7-day bar charts (`Swift Charts`),
  highlighting "today" in navy and the best day with a trophy label. **Tappable**
  — a `SpatialTapGesture` + `ChartProxy.value(atX:)` maps the tap to a day and
  opens a sheet listing that day's sessions.
- **Weekly Report**: on-demand Groq-generated narrative summarizing the week with
  2 suggestions for next week.
- **Recent Sessions**: tappable list → `SessionDetailView` (full stats + a
  per-minute focus line chart for that one session).
- **By Subject**: proportional bars showing session count per subject.
- **Badges** link → `BadgesView`.
- If the user has zero sessions, all of the above collapses into a single
  friendly Guri empty-state card instead of several half-empty widgets.

### 6.10 Settings
Sensitivity (segmented low/medium/high), voice on/off + language (en-US/id-ID),
posture/focus alert toggles. Every change immediately pushes to Firestore
(`FirebaseService.saveSettings`) via `.onChange`, so settings follow the user
across devices/reinstalls.

---

## 7. Computer Vision / ML Pipeline

### 7.1 Camera capture
`CameraManager` configures a **front-camera** `AVCaptureSession` at 30 fps,
portrait orientation, `kCVPixelFormatType_32BGRA`. Critically, the **data output
connection is explicitly un-mirrored** (`isVideoMirrored = false`) — mirroring the
pixel data would swap the subject's anatomical left/right and silently flip TLR
↔ TLL classifications. The **preview layer** (what the user sees) is mirrored
separately in `CameraPreviewView`, so the on-screen experience still feels like a
normal selfie camera while the ML pipeline sees true (un-mirrored) geometry.

Frames are published via a Combine `PassthroughSubject<CMSampleBuffer, Never>`,
consumed independently by `PostureManager` and `FocusManager`.

### 7.2 Posture pipeline (`PostureDetector.swift`)

```
CMSampleBuffer
   → VNDetectHumanBodyPoseRequest (Apple Vision)
   → 15 joints required: nose, leftEar, rightEar, leftShoulder, rightShoulder,
     leftElbow, rightElbow, leftWrist, rightWrist, leftHip, rightHip,
     leftKnee, rightKnee, leftAnkle, rightAnkle
   → only the UPPER BODY (nose, ears, shoulders) is strictly required —
     a desk webcam often can't see hips/knees/ankles, so those are
     ESTIMATED by walking down from the torso at fixed proportional
     offsets (mirrors how MediaPipe, used for training, always emits a
     full skeleton even with occlusion)
   → 24 derived features computed (angles in degrees via dot-product/arccos,
     offsets as normalized coordinate differences) — see exact list below
   → PostureClassifier.mlmodel (CoreML, Boosted Tree, 5 iterations, max depth 3)
   → output label: TUP | TLF | TLB | TLR | TLL + per-class probability
```

**The 24 features** (exact names, must match the training CSV columns):
`neck_shoulder_angle_left/right`, `ear_shoulder_offset_x/y_left/right`,
`shoulder_level_diff`, `head_forward_offset`, `head_vertical_offset`,
`spine_curve_upper/lower`, `shoulder_hip_offset_x/y`, `hip_level_diff`,
`elbow_angle_left/right`, `knee_angle_left/right`, `hip_angle_left/right`,
`ear_level_diff`, `wrist_shoulder_offset_y_left/right`, `body_lean_x`.

A subtlety: Vision's points use a **bottom-left origin, y-up** coordinate space,
while the model was trained on MediaPipe data (**top-left origin, y-down**).
Every keypoint is flipped (`y' = 1 - y`) immediately after extraction so the
ported feature formulas match the training pipeline exactly. (Angle features are
mathematically invariant to this flip; offset/level-diff features are *not* and
would have the wrong sign without it.)

**Confidence thresholds** (two separate ones, for two separate purposes):
- `minJointConfidence = 0.1` for **classification** — deliberately loose, because
  Vision reports low confidence for occluded-but-inferred joints, and the model
  was trained expecting always-estimated joints (mirroring MediaPipe behavior).
- `minDisplayConfidence = 0.45` for the **skeleton overlay** (when re-enabled) —
  much stricter, since drawing a low-confidence guessed joint position looks
  messy/jittery on screen.

**Temporal smoothing** (`PostureManager`) — because raw per-frame predictions
jitter:
- Frames below `minConfidence = 0.30` are ignored entirely.
- A 1.2-second rolling window (`smoothingWindow`) of recent predictions is kept.
- The reported "stable" posture only **switches** to a new class when that class
  holds `switchThreshold = 0.60` (60%) majority share of the window — otherwise
  the previous stable label sticks (hysteresis prevents flicker).
- **Exception**: switching *into* `TLF` (slouch forward) uses a lower
  `slouchSwitchThreshold = 0.40` — the underlying model's documented weak spot is
  TLF recall (~62–79%, see §14), so the standard 60% bar was under-detecting real
  slouching.

**Per-user calibration** (also in `PostureManager`): during the 4-second
calibration window, the most frequent raw prediction is stored as
`baselineClass`. From then on, any prediction matching that exact class is
remapped to `.tup` — this directly compensates for the model's TUP/TLB confusion
on a per-user, per-camera-angle basis without needing to retrain.

**Alerting**: `updateAlert(for:now:)` tracks how long the *current* stable bad
posture has persisted; once it exceeds `AlertSensitivity.thresholdSeconds`
(5/10/20s for high/medium/low), `activeAlert` is set, which is the single trigger
point for the on-screen banner, haptic, sound effect, and voice coaching.

### 7.3 Focus pipeline (`FocusDetector.swift` + `FocusManager.swift`)

No custom ML model — pure Apple Vision face landmarks:
```
VNDetectFaceLandmarksRequest
   → eye openness  = average(height/width of left+right eye landmark bounding box)
                     (robust to point-ordering, unlike a fixed-index EAR formula)
   → eyesClosed    = openness < 0.23
   → yaw / pitch   = face.yaw / face.pitch (head pose, radians)
   → lookingAway   = |yaw| > 0.50 rad (~29°) OR |pitch| > 0.65 rad (~37°)
   → faceWidth     = face.boundingBox.width (a distance proxy — bigger = closer)
```

**Debounced sustained-state tracking** — the same "single noisy frame shouldn't
reset everything" lesson learned from posture smoothing was applied here too:
a momentary "eyes open" frame doesn't immediately cancel a closed-eyes streak;
the eyes must stay open continuously for `reopenDebounce = 0.4s` before the
streak resets (similarly `lookBackDebounce = 0.3s` for sustained look-away).
Without this, single-frame jitter around the threshold made `drowsy`
effectively undetectable in practice — this was a real bug found and fixed
during development (see §16).

**State resolution** (priority: distraction > drowsiness > focused):
- Looking away ≥ 1.5s (`distractedSeconds`) → `.distracted`
- Eyes closed ≥ 3.0s (`drowsySeconds`) → `.drowsy`
- Otherwise → `.focused`

Face width is smoothed with an exponential moving average (`0.7×old + 0.3×new`)
and exposed to `SessionManager` for the "leaning in too close" voice nudge
described in §6.4.

### 7.4 OCR pipeline (`TextScanner.swift`)
`VNRecognizeTextRequest` with `.accurate` recognition level and language
correction enabled, run against a UIImage captured via either
`UIImagePickerController` (camera) or `PHPickerViewController` (library — chosen
specifically because it needs **no photo-library permission** and avoids the
legacy "Limited Library" selection UI bug encountered with
`UIImagePickerController(sourceType: .photoLibrary)`). The image is processed
entirely on-device; only the resulting text string is ever sent to Groq.

---

## 8. AI Integrations

All Groq calls go through `GroqService`, hitting
`https://api.groq.com/openai/v1/chat/completions` with model
**`llama-3.3-70b-versatile`**. The API key is read from the gitignored
`Secrets.plist` (`GroqAPIKey`), never committed.

| # | Use case | Trigger | Output |
|---|---|---|---|
| 1 | **Session summary** | Once, when `SessionSummaryView` appears | ~150-word personal narrative (focus drops + 2 tips) |
| 2 | **Solve problem** | Scan & Solve → "Solve with AI" | Step-by-step answer to the OCR'd/typed problem |
| 3 | **Flashcards** | Scan & Solve → "Flashcards" | JSON array of `{question, answer}`, parsed into `Flashcard` |
| 4 | **Study plan** | Planner → "Generate Plan" | JSON array of `{day, tasks: [{subject, activity, minutes}]}` |
| 5 | **Weekly report** | Dashboard → "Generate report" | ~120-word encouraging weekly summary + 2 suggestions |
| 6 | **Break chat** | Break → "Ask Guri" | Conversational Q&A about the studied subject (max 100 words/answer) |

JSON-returning use cases (3, 4) extract the JSON array via a regex
(`\[[\s\S]*\]`) before decoding, since the model sometimes wraps JSON in prose
despite being asked not to — a defensive parsing step rather than trusting strict
output format.

Errors surface a `GroqError` with the actual HTTP status + response body (printed
to console as `⚠️ Groq HTTP <code>: <body>`), which proved essential for
diagnosing real issues during development (wrong model name, VPN blocking, etc.
— see §16).

---

## 9. CrewAI Backend (Python)

A small, **optional** FastAPI service (`backend/`) that wraps a 3-agent CrewAI
crew for a more structured analysis than a single Groq prompt:

| Agent | Role | Output |
|---|---|---|
| **Posture Analyst** | Ergonomics expert | 2 sentences on posture pattern + likely cause |
| **Focus Monitor** | Learning-science coach | 2 sentences on focus trend + when it dropped |
| **Break Coach** | Physiotherapist | Exactly 3 stretches matched to the posture issue (JSON) |

`Process.sequential` — the three agents run one after another (no delegation
between them; `allow_delegation=False`). Two metrics are computed
**deterministically in Python** (not by the LLM) for consistency:
`deep_focus_minutes` (count of per-minute focus scores ≥ 70) and `drop_minutes`
(minutes where focus fell below 50).

**Endpoints** (`main.py`):
- `GET /` — health check (`{"status":"ok", ...}`)
- `POST /analyze-session` — REST endpoint, `SessionPayload` in → `AnalysisResponse` out
- `GET /.well-known/agent.json` — **A2A Agent Card** (capabilities + skills, for
  agent discovery by other A2A-compliant systems)
- `POST /a2a` — **A2A JSON-RPC `message/send`** — the same `run_agents()` logic,
  but speaking the A2A protocol (message parts containing a `data` payload, the
  response wrapped in a JSON-RPC envelope)

**Resilience**: if CrewAI/Groq fails for *any* reason (network, missing key,
rate limit, dependency issue), `_crew_analysis()` catches the exception, logs it
(`[agents] crew unavailable, using fallback: ...`), and returns a deterministic
templated response built straight from the raw numbers — the endpoint **never
hard-fails**.

**iOS integration** (`AgentService.swift`) is intentionally decoupled: it reads
`AgentBackendURL` from `Secrets.plist`; if absent, `isConfigured` is `false` and
the call is never attempted. If the backend is unreachable or errors, `analyze()`
returns `nil` and the "Coach Analysis" card simply doesn't render — no crash, no
blocking the rest of the summary screen.

---

## 10. Firebase / Data Persistence

### Collections actually written by the app

```
users/{userId}
  name, email, createdAt
  studyLevel: "Beginner" | "Scholar" | "Elite Scholar"
  totalXP, currentStreak, longestStreak, lastStudyDate
  settings: { alertSensitivity, voiceLanguage, voiceEnabled,
              postureAlertEnabled, focusAlertEnabled }      ← from SettingsView
  studyPlan: <JSON string of [StudyPlanDay]>                ← from PlannerView
  achievements: { <badgeKey>: { name, type, unlockedAt } }   ← from BadgesView

sessions/{sessionId}                                          ← one per completed session
  userId, subject, startTime, endTime, targetDuration, totalDuration
  focusScore, postureScore, distractionCount, postureAlertCount
  focusTimeline: [Int]   (per-minute focus, used by SessionDetailView's chart)
  xpEarned, status: "completed"

focusSamples/{auto-id}        ← written every 30s during a session
  userId, sessionId, minuteMark, focusScore, state, timestamp

postureEvents/{auto-id}       ← written once a sustained bad-posture episode ends
  userId, sessionId, type ("TLF"/"TLB"/"TLR"/"TLL"), severity ("mild"/"moderate"/"severe"), duration, timestamp

focusEvents/{auto-id}         ← written once a sustained drowsy/distracted episode ends
  userId, sessionId, type ("drowsy"/"distracted"), duration, timestamp

breakSessions/{auto-id}       ← written when a break finishes
  userId, sessionId, reason ("pause"), exercises: [{name, duration, targetArea, completed}], completed, timestamp
```

`sessionId` is generated once by `SessionManager` and shared by the session
document *and* all of its events/break, so everything for one study session can
be joined by that ID.

`fetchRecentSessions` filters by `userId` only (no `orderBy`) and sorts
client-side — this deliberately avoids needing a Firestore composite index.

### Security
`firestore.rules` (repo root) restricts every collection so a user can only read/
write documents where `userId == request.auth.uid` (or, for `users/{userId}`,
where the document ID matches their own UID).

---

## 11. Gamification System

### XP formula (`FirebaseService.recordSession`)
```
focusMinutes = (totalSeconds / 60) × (focusScore / 100)      // effective focused minutes
baseXP       = focusMinutes × 10
postureBonus = postureScore > 80 ? 50 : 0
focusBonus   = focusScore   > 80 ? 50 : 0
streakBonus  = currentStreak × 10
xpEarned     = baseXP + postureBonus + focusBonus + streakBonus
```

### Streak logic
- Last studied **today** → streak unchanged (already counted).
- Last studied **yesterday** → streak **+1**.
- Last studied earlier, or never → streak **resets to 1**.
- `longestStreak = max(longestStreak, currentStreak)`.

### Levels
`StudyLevel.level(forXP:)`: 0–500 → **Beginner**, 500–2000 → **Scholar**,
2000+ → **Elite Scholar**. Shown on Home (with a Guri image + progress bar to
the next tier) and on the Dashboard hero card.

### Badges (`BadgesView`, 8 total)
| Badge | Condition |
|---|---|
| First Session | ≥1 completed session |
| Posture Perfect | Any session with posture score ≥ 95% |
| Deep Focus | Any session ≥ 60 min with focus score ≥ 80% |
| 7-Day Streak | `currentStreak` ≥ 7 |
| Early Bird | Any session ending before 8 AM |
| Night Owl | Any session ending at/after 10 PM |
| Math Wizard | ≥ 10 sessions with subject = "Mathematics" |
| Study Marathon | Any single session ≥ 90 minutes |

Unlock state is **computed client-side** from the session history each time
`BadgesView` loads, then **persisted** (`syncAchievements`) into the user's
`achievements` map — first-unlock only, stamping `unlockedAt` once.

---

## 12. Design System ("Guri Warm")

`Theme.swift`:
| Token | Hex | Use |
|---|---|---|
| `Theme.orange` | `#F58220` | Primary accent, buttons, focus chart |
| `Theme.navy` | `#16294A` | Primary text, "today" chart bars, pill nav background |
| `Theme.cream` | `#FBF4E9` | App background |
| `Theme.green` | `#5C8C3D` | Success/good states, posture chart |
| `Theme.muted` | `navy @ 55%` | Secondary text |

`BrandKit.swift` provides:
- **`BrandImage(name:fallbackSystemName:)`** — shows a named asset if present in
  `Assets.xcassets`, otherwise gracefully falls back to an SF Symbol. Used for
  every piece of Guri art and every state sticker, so the app never crashes or
  shows a blank image if an asset is renamed/missing.
- **`.sgCard(padding:)`** — the standard white rounded card with a soft shadow,
  used by virtually every screen.
- **`.sgPrimary` / `.sgSecondary`** button styles (filled orange / tinted navy).

**Guri art assets** (must exist in `Assets.xcassets` with these exact names):
`GuriLogo`, `GuriHi`, `GuriBreak`, `GuriCelebrate` — plus the reactive state
stickers: `Good Form`, `BUNGKUK`, `Leaning`, `drowsy`, `distract`.

**Sound assets** (`Sounds/`, bundled as app resources, not asset-catalog images):
`bungkuk.mp3`, `leaning.mp3`.

---

## 13. Settings & Configuration

### `AppSettingsStore` (local, `UserDefaults`)
Keys: `alertSensitivity`, `voiceLanguage` (default `en-US`), `voiceEnabled`,
`postureAlertEnabled`, `focusAlertEnabled`. `SettingsView` binds directly to
these via `@AppStorage`; `SessionManager`/`MainView.makeSession` read them when
starting a new session.

### `Secrets.plist` (gitignored — never committed)
```xml
<key>GroqAPIKey</key>          <string>...</string>
<key>ExerciseDBAPIKey</key>    <string>...</string>
<key>AgentBackendURL</key>     <string>http://<mac-lan-ip>:8000</string>  <!-- optional -->
```

### `backend/.env` (gitignored)
```
GROQ_API_KEY=...
```

### Info.plist
- `NSCameraUsageDescription` — required for posture/focus detection.
- Google Sign-In URL scheme (`CFBundleURLTypes`, the reversed client ID).
- `NSAppTransportSecurity` → `NSAllowsLocalNetworking: true` — scoped exception
  that allows plain-HTTP calls to local-network/IP-literal hosts (needed to reach
  the CrewAI dev backend over LAN) **without** weakening ATS for any public/
  internet host — Firebase, Groq, and ExerciseDB all still require HTTPS as
  normal.

---

## 14. Known Limitations & Accuracy Notes

- **`PostureClassifier.mlmodel` accuracy** (Boosted Tree, test set = subject 13,
  270 rows): TUP precision 46% / recall 76%; TLR & TLL precision/recall 100%;
  TLF precision 68% / recall 61%; TLB precision 87% / recall 54%. Train/val/test
  accuracy: 96% / 68% / 71%. **TUP vs TLB confusion** is the model's main weak
  spot (similar upper-body geometry from a frontal camera) — mitigated, not
  eliminated, by per-user calibration (§7.2). **TLF recall** is mitigated by the
  asymmetric, lower switch threshold (§7.2).
- **Camera angle matters**: the model was trained on frontal images. The app
  explicitly tells the user (during calibration) to face the camera directly at
  eye level — an angled/side camera will *reduce* accuracy, not improve it.
- **Lower-body keypoints are estimated, not observed**, in any desk setup where
  hips/knees/ankles are off-frame or occluded — this is intentional (mirrors how
  the training data was built) but means those specific features are
  approximations.
- **Sound effect files**: as of the last check, `bungkuk.mp3` and `leaning.mp3`
  are byte-identical (same MD5) — both posture alert categories currently sound
  the same. Replace one file if distinct cues are wanted.
- **CrewAI backend dependency footguns** (now fixed, documented for future
  reference): `litellm` is an *optional* CrewAI extra not pulled in by a plain
  `pip install crewai`, and the latest `litellm` pulls an `openai` version that
  conflicts with CrewAI's own pin. `requirements.txt` now pins
  `litellm~=1.74.9` to match CrewAI's exact expectation.
- **DHCP / VPN sensitivity for the optional backend**: `AgentBackendURL` is a raw
  IP address that changes if the Mac reconnects to Wi-Fi; and a VPN on either the
  phone *or* the Mac can silently block Groq's API ("Access denied. Please check
  your network settings.") — this has been the root cause of several "nothing
  happens" debugging sessions during development.

---

## 15. Setup & Running Instructions

### iOS app
1. Open `StudyGuard.xcodeproj` in Xcode (14.3+; deployment target iOS 16.4).
2. Add `GoogleService-Info.plist` (from your Firebase project) to the project root.
3. Create `StudyGuard/Secrets.plist` with `GroqAPIKey` and `ExerciseDBAPIKey`
   (and optionally `AgentBackendURL` if running the backend).
4. Enable **Email/Password** and **Google** sign-in providers in the Firebase
   console, and publish `firestore.rules`.
5. Build & run on a **physical device** (camera required — the Simulator has none).

### CrewAI backend (optional)
```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # then add your GROQ_API_KEY
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Find your Mac's LAN IP (`ipconfig getifaddr en0`) and set
`AgentBackendURL = "http://<that-ip>:8000"` in `Secrets.plist`, then rebuild the
iOS app. Verify independently with:
```bash
curl http://localhost:8000/                          # health check
curl http://localhost:8000/.well-known/agent.json     # A2A Agent Card
```

---

## 16. Notable Engineering Fixes (History)

A record of real bugs found and fixed during development — useful context for
anyone extending this codebase:

1. **Mirrored camera data flipped TLR/TLL.** Originally both the data output and
   the preview were mirrored. Fixed by un-mirroring only the data output (Vision
   sees true geometry) while keeping the preview mirrored (natural selfie view).
2. **Desk webcams can't see knees/ankles** → posture detection returned "no body"
   constantly. Fixed by requiring only upper-body joints and estimating the rest.
3. **Posture label flicker** → added the 1.2s majority-vote smoothing window with
   hysteresis (§7.2), then later an asymmetric lower threshold for TLF
   specifically once real-world testing showed slouching was under-detected.
4. **Drowsiness almost never triggered** despite eyes visibly closed — root cause
   was a single noisy "open" frame instantly resetting the 3-second sustained-
   closure timer at ~5 inferences/second. Fixed with a 0.4s reopen-debounce
   (same pattern applied to look-away detection).
5. **`PHPickerViewController` vs `UIImagePickerController(sourceType: .photoLibrary)`**
   — the latter, combined with "Limited Photo Library" access, presented a
   confusing checkmark/"Add" selection screen that never returned a picked image
   and had no way back. Switched to `PHPickerViewController` (no permission
   needed at all) for library picks; kept `UIImagePickerController` for camera-only.
6. **Picker "stuck" screens** — neither picker originally called back on
   *cancel*, so SwiftUI's `fullScreenCover`/`sheet` binding never flipped back to
   `false`, leaving a dead screen. Added explicit `onCancel` closures to both.
7. **`@FocusState` name collision** — the app's own domain `enum FocusState`
   (focused/drowsy/distracted) shadowed SwiftUI's `@FocusState` property wrapper
   at the module level. Fixed by qualifying as `@SwiftUI.FocusState` at each use site.
8. **iOS 16 vs newer SDK APIs** — several iOS 17+-only APIs (`.rect(cornerRadius:)`,
   `.topBarTrailing`, the `#Preview` macro) don't compile against this project's
   Xcode 14.3/iOS 16.4 toolchain; replaced with `RoundedRectangle`,
   `.navigationBarTrailing`, and `PreviewProvider` respectively.
9. **Groq "Access denied" errors** traced — twice, independently — to a VPN
   blocking DNS/network access to `api.groq.com`: once from the iPhone's
   perspective, once from the Mac (when the Mac itself runs the CrewAI backend
   and calls Groq directly). Same fix both times: disable the VPN.
10. **CrewAI silently always falling back to the template response** — traced to
    `litellm` (an optional CrewAI extra) not being installed at all by a plain
    `pip install -r requirements.txt`. Pinned the exact compatible version
    (§14) and verified a real Groq-generated response end-to-end via direct
    `curl` testing of the running backend.
11. **DHCP IP drift** — `AgentBackendURL` is a literal IP; reconnecting Wi-Fi
    handed the Mac a new address, silently breaking the iOS→backend connection
    with zero error (the request never reached the new IP). No code fix
    possible — documented as an operational gotcha (§14).

---

*This document reflects the implementation as of the latest commit on
`feat/scan-camera-fixes`. If you change a threshold, formula, or flow described
here, please update this file alongside the code.*
