# StudyGuard — Claude Code Context

## What is this project?
StudyGuard is an iOS application (SwiftUI) that acts as an AI-powered study companion.
It monitors posture and focus in real-time via the front camera, coaches the user during
study sessions, recommends exercises during breaks, and tracks long-term progress with
gamification (XP, streaks, badges) — like a fitness app but for studying.

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 16+) |
| Camera | AVFoundation — AVCaptureSession |
| Computer Vision | Apple Vision Framework |
| ML Model | CoreML — PostureClassifier.mlmodel |
| ML Training | Create ML — Tabular Classifier |
| Training Dataset | Zenodo MultiPosture (4,800 frames, 13 participants, CSV keypoints) |
| Voice Alerts | AVSpeechSynthesizer (Indonesian + English) |
| Database | Firebase Firestore |
| Auth | Firebase Authentication |
| File Storage | Firebase Storage |
| AI Agents | CrewAI (Python backend, 3 agents — called via HTTP from Swift) |
| LLM | Groq API (llama3-70b) — session summary narasi + break suggestions |
| Exercise API | ExerciseDB API or Ninjas API |
| Notifications | UNUserNotificationCenter |

---

## Folder Structure

```
StudyGuard/
├── App/
│   ├── StudyGuardApp.swift              # @main entry point
│   └── ContentView.swift                # Root navigation
│
├── Core/
│   ├── Models/
│   │   ├── User.swift                   # User profile model
│   │   ├── StudySession.swift           # Session data model
│   │   ├── PostureEvent.swift           # Single posture event log
│   │   ├── FocusEvent.swift             # Single focus event log
│   │   ├── FocusSample.swift            # 30-second focus sample (for Groq timeline)
│   │   └── BreakExercise.swift          # Exercise model from API
│   │
│   ├── Services/
│   │   ├── FirebaseService.swift        # All Firestore read/write
│   │   ├── ExerciseAPIService.swift     # ExerciseDB / Ninjas API calls
│   │   ├── CrewAIService.swift          # HTTP calls to Python CrewAI backend
│   │   ├── GroqService.swift            # Groq API calls (session summary + break tips)
│   │   └── NotificationService.swift   # Local notifications & reminders
│   │
│   └── Managers/
│       ├── SessionManager.swift         # Orchestrates active session state
│       ├── PostureManager.swift         # Posture score calculation & alert logic
│       └── FocusManager.swift           # Focus score, EAR, adaptive timer logic
│
├── Vision/
│   ├── CameraManager.swift              # AVCaptureSession setup & frame output
│   ├── PostureDetector.swift            # VNDetectHumanBodyPoseRequest → CoreML input
│   ├── FocusDetector.swift              # VNDetectFaceLandmarksRequest → eye/gaze logic
│   └── CameraPreviewView.swift          # SwiftUI wrapper for AVCaptureVideoPreviewLayer
│
├── ML/
│   └── PostureClassifier.mlmodel        # Trained CoreML model (Create ML Tabular)
│
├── Agents/
│   ├── AgentService.swift               # Swift-side HTTP wrapper for CrewAI calls
│   └── AgentModels.swift                # Request/response Codable structs for agents
│
├── Features/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   │
│   ├── Home/
│   │   └── HomeView.swift               # Dashboard: streak, stats, start button
│   │
│   ├── PreSession/
│   │   └── PreSessionSetupView.swift    # Subject picker + duration + mode selector
│   │
│   ├── Session/
│   │   ├── SessionView.swift            # Main study screen (camera + scores + timer)
│   │   ├── PostureOverlayView.swift     # Skeleton overlay drawn on camera feed
│   │   ├── FocusScoreView.swift         # Focus score gauge UI
│   │   └── SessionSummaryView.swift     # Post-session results with Groq insight
│   │
│   ├── Break/
│   │   ├── BreakView.swift              # Break screen — camera OFF, chat AI available
│   │   ├── ExerciseCardView.swift       # Single exercise card with timer
│   │   └── BreakChatView.swift          # Quick AI chat during break (Groq)
│   │
│   ├── Dashboard/
│   │   ├── DashboardView.swift          # Weekly/monthly charts
│   │   ├── ProgressChartView.swift      # Focus & posture trend charts
│   │   └── BadgesView.swift             # Achievements collection
│   │
│   └── Settings/
│       └── SettingsView.swift           # Alert sensitivity, voice, timer prefs
│
└── Resources/
    ├── Assets.xcassets
    └── Info.plist                       # NSCameraUsageDescription required
```

---

## Pre-Session Setup Flow

Before every session, user goes through a quick setup screen (max 2 taps):

```
[Home] → Tap "Start Session"
              ↓
    [PreSessionSetupView]
    ┌─────────────────────────┐
    │  Mau belajar apa?       │
    │                         │
    │  [Mat] [Fisika] [Prog]  │
    │  [Bio] [Bahasa] [+lain] │
    │                         │
    │  ⏱ 25 min  50 min  75  │
    │                         │
    │   [▶ Mulai Sekarang]    │
    └─────────────────────────┘
              ↓
    [SessionView — camera ON]
```

Subject list (hardcoded + "Lainnya"):
```swift
let subjects = [
    "Matematika", "Fisika", "Kimia", "Biologi",
    "Pemrograman", "Desain", "Bahasa Inggris",
    "Ekonomi", "Sejarah", "Lainnya..."
]
```

Subject auto-suggests last used subject. Subject is saved with each session
to enable per-subject analytics in Dashboard and Groq insights.

---

## CoreML Pipeline

```
AVCaptureSession (front camera, 30fps)
        ↓
VNDetectHumanBodyPoseRequest (Apple Vision)
        ↓
19 body keypoints — normalized (x, y, confidence)
Joints used: nose, leftEar, rightEar, leftShoulder, rightShoulder,
             leftElbow, rightElbow, leftWrist, rightWrist,
             leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle
        ↓
24 derived features computed in Swift (MUST match training CSV exactly):
  neck_shoulder_angle_left, neck_shoulder_angle_right,
  ear_shoulder_offset_x_left, ear_shoulder_offset_y_left,
  ear_shoulder_offset_x_right, ear_shoulder_offset_y_right,
  shoulder_level_diff, head_forward_offset, head_vertical_offset,
  spine_curve_upper, spine_curve_lower,
  shoulder_hip_offset_x, shoulder_hip_offset_y, hip_level_diff,
  elbow_angle_left, elbow_angle_right,
  knee_angle_left, knee_angle_right,
  hip_angle_left, hip_angle_right,
  ear_level_diff,
  wrist_shoulder_offset_y_left, wrist_shoulder_offset_y_right,
  body_lean_x
        ↓
PostureClassifier.mlmodel (Create ML Tabular Classifier)
Input: 24 numeric features, target column "posture_label"
        ↓
Output label (String):
  TUP  = good posture (tegak)
  TLF  = slouching forward (bungkuk depan)
  TLB  = leaning back (bersandar belakang)
  TLR  = tilted right (miring kanan)
  TLL  = tilted left (miring kiri)
```

### Dataset & Training Notes

- Source: Zenodo MultiPosture dataset (4,794 rows, 13 subjects, MediaPipe-derived)
- Preprocessed into 3 files: `posture_train.csv` (3,984 rows, subjects 1-10),
  `posture_val.csv` (540 rows, subjects 11-12), `posture_test.csv` (270 rows, subject 13)
- Split is per-subject (no data leakage between train/val/test)
- Angle features in degrees (0-180), offset features are normalized coordinate
  differences (~-0.5 to 0.5) — keep units consistent in Swift implementation
- Baseline simulation (Random Forest, 100 trees): ~70% test accuracy
  - TLL, TLR: ~100% precision/recall — very reliable
  - TLF: ~62-79% recall — acceptable, most important class for this app
  - TUP vs TLB: frequently confused (similar upper-body geometry from frontal camera)
  - Class imbalance: TLB/TLR/TLL have ~300 train samples vs ~1,300-1,660 for TUP/TLF
- For Create ML: use default Tabular Classifier settings, no manual iteration tuning needed
  (more trees/iterations did not improve accuracy in simulation — bottleneck is feature overlap, not model capacity)
- Known limitation (mention in report): TUP/TLB overlap can be addressed in future work
  by merging into one "relaxed good posture" class, or adding new distinguishing features

---

## Focus Detection Pipeline

```
AVCaptureSession (same session, front camera)
        ↓
VNDetectFaceLandmarksRequest (Apple Vision)
        ↓
Facial landmarks: eye contours, pupils
        ↓
Computed in Swift:
  - Eye Aspect Ratio (EAR) — detects drowsiness if EAR < threshold
  - Gaze direction estimate — detects looking away
  - Head pose (roll/pitch/yaw) from face bounding box
        ↓
Focus state:
  focused    = eyes open, looking at screen
  drowsy     = EAR below threshold for 3+ seconds
  distracted = gaze/head turned away
```

Note: unlike posture, focus detection uses ONLY built-in Apple Vision —
no custom CoreML model, no dataset, no training required. EAR formula:

```swift
func calculateEAR(eyeLandmarks: [CGPoint]) -> Double {
    let verticalDist1 = distance(eyeLandmarks[1], eyeLandmarks[5])
    let verticalDist2 = distance(eyeLandmarks[2], eyeLandmarks[4])
    let horizontalDist = distance(eyeLandmarks[0], eyeLandmarks[3])
    return (verticalDist1 + verticalDist2) / (2.0 * horizontalDist)
}
// EAR ~0.25-0.35 = eyes open (focused)
// EAR < 0.15 = eyes closing (drowsy)
```

---

## Focus Sampling for Groq Timeline

Every 30 seconds during a session, a FocusSample is saved to Firebase:

```swift
struct FocusSample: Codable {
    let minuteMark: Int        // e.g. 0, 1, 2 ... 50
    let focusScore: Double     // 0.0 - 100.0
    let state: String          // "focused" | "drowsy" | "distracted"
    let sessionId: String
    let timestamp: Date
}
```

At session end, these samples are compressed into a timeline string and sent to Groq:

```
"0-5min: 90,88,85,89,92 | 5-10min: 87,84,86,83,80 | 
 10-15min: 79,81,78,75,77 | 15-20min: 73,70,68,65,60 |
 20-25min: 45,38,42,40,44 | 25-30min: 55,58,60,62,65 ..."
```

Groq receives this as part of the prompt — it does NOT run during the session,
only called ONCE at the end. Total input ~300-500 tokens. Response in 1-2 seconds.

---

## Scoring System

```swift
// Posture score: percentage of good posture frames in last 60s
postureScore = (goodFrameCount / totalFrameCount) * 100

// Focus score: percentage of focused frames in last 60s
focusScore = (focusedFrameCount / totalFrameCount) * 100
```

---

## Adaptive Timer Logic

```swift
// Checked every 60 seconds during session
func checkAdaptiveTimer() {
    let recentFocusAvg = getLast3MinutesFocusAverage()
    let timeElapsed = sessionDuration // in minutes

    if recentFocusAvg > 85 && timeElapsed >= targetDuration {
        // Extend session
        extendSession(by: 5)
        speak("Kamu lagi fokus banget, perpanjang 5 menit ya!")

    } else if recentFocusAvg < 40 && timeElapsed > 15 {
        // Early break
        triggerBreak(reason: "focus_drop")
        speak("Fokus kamu mulai turun, waktunya istirahat sebentar")

    } else if timeElapsed >= targetDuration {
        // Normal break on time
        triggerBreak(reason: "timer_complete")
        speak("Waktunya istirahat!")
    }
}

// Default Pomodoro intervals:
// 25 min study → 5 min break
// 50 min study → 10 min break
// 75 min study → 15 min break
```

---

## Break Screen Behavior

```
Timer fires → triggerBreak()
      ↓
Camera PAUSES (AVCaptureSession suspended)
      ↓
BreakView appears:
  - Exercise list from BreakCoachAgent (CrewAI)
  - Break timer countdown
  - "Ask AI" button → opens BreakChatView (Groq)
      ↓
BreakChatView (during break only):
  - User can ask study-related questions
  - Groq answers quickly
  - Camera remains OFF
  - When break timer ends → camera RESUMES automatically
```

This design keeps camera + chat completely separate — no conflict.

---

## Voice Alert System

```swift
import AVFoundation
// Language: "id-ID" Indonesian (default), "en-US" English

// Trigger conditions:
// TLF > 10s  → "Punggung kamu membungkuk ke depan, perbaiki posisi duduk"
// TLB > 10s  → "Kamu bersandar terlalu jauh ke belakang"
// TLR > 10s  → "Kamu miring ke kanan, duduk tegak ya"
// TLL > 10s  → "Kamu miring ke kiri, duduk tegak ya"
// drowsy > 5s → "Kamu terlihat mengantuk, ambil nafas dalam"
// distracted > 30s → "Fokus kembali ke materi kamu"
// break trigger → "Waktunya istirahat! Lakukan peregangan sebentar"
// 20-20-20 rule → "Saatnya istirahat mata, lihat jauh selama 20 detik"
// water reminder → "Jangan lupa minum air ya!"
```

---

## Groq API Integration

Base URL: `https://api.groq.com/openai/v1/chat/completions`
Model: `llama3-70b-8192`
Called from: `GroqService.swift`

### Use Case 1 — Session Summary (called once at session end)

```swift
// Input to Groq:
let prompt = """
Analisis sesi belajar ini dan buat summary yang personal dan conversational.

Subject: \(subject)
Durasi: \(duration) menit
Posture score: \(postureScore)%
Focus score: \(focusScore)%
Dominant posture issue: \(dominantPostureIssue)
Alert count: \(alertCount) kali

Focus timeline (skor per menit):
\(focusTimeline)

Buat summary personal max 150 kata bahasa Indonesia.
Sebutkan kapan fokus drop (jika ada) dan berikan 2 saran konkret untuk sesi berikutnya.
"""

// Example Groq output:
// "Sesi Matematika kamu hari ini cukup solid! Fokus kamu drop
//  di menit ke-20, kemungkinan karena topiknya mulai berat.
//  Postur kamu juga sering bungkuk ke depan — coba atur jarak
//  layar lebih jauh. Besok coba pecah jadi 2 sesi 25 menit
//  instead of 1 sesi 50 menit, dan ingat duduk tegak ya!"
```

### Use Case 2 — Break Chat (during break only)

```swift
// System prompt:
let system = """
Kamu adalah asisten belajar yang membantu mahasiswa memahami materi kuliah.
User sedang break dari sesi belajar \(subject).
Jawab pertanyaan dengan singkat, jelas, dan mudah dipahami.
Gunakan bahasa Indonesia. Max 100 kata per jawaban.
"""
// User sends any study question → Groq answers
```

### Use Case 3 — Break Suggestion (replaces StudyPlannerAgent)

```swift
// Called after session ends, parallel with agents
let prompt = """
User baru selesai belajar \(subject) selama \(duration) menit.
Dominant posture issue: \(dominantIssue)
Focus dropped significantly at: \(dropMinutes) menit

Berikan 1 saran singkat untuk jadwal belajar berikutnya.
Max 50 kata, bahasa Indonesia.
"""
```

---

## Firebase Schema

```
users/{userId}/
  profile:
    name: String
    email: String
    createdAt: Timestamp
    studyLevel: String          // "Beginner" | "Scholar" | "Elite Scholar"
    totalXP: Int
    currentStreak: Int
    longestStreak: Int
    lastStudyDate: Timestamp
  settings:
    pomodoroDuration: Int       // minutes, default 25
    breakDuration: Int          // minutes, default 5
    postureAlertEnabled: Bool
    focusAlertEnabled: Bool
    waterReminderInterval: Int  // minutes, default 30
    voiceLanguage: String       // "id-ID" | "en-US"
    alertSensitivity: String    // "low" | "medium" | "high"

sessions/{sessionId}/
  userId: String
  subject: String               // "Matematika" | "Fisika" | etc
  startTime: Timestamp
  endTime: Timestamp
  targetDuration: Int           // minutes (user's chosen duration)
  totalDuration: Int            // seconds (actual)
  focusScore: Double            // 0.0 - 100.0
  postureScore: Double          // 0.0 - 100.0
  distractionCount: Int
  postureAlertCount: Int
  xpEarned: Int
  groqSummary: String           // Groq-generated narrative summary
  status: String                // "completed" | "cancelled"

postureEvents/{eventId}/
  sessionId: String
  userId: String
  timestamp: Timestamp
  type: String                  // "TUP" | "TLF" | "TLB" | "TLR" | "TLL"
  severity: String              // "mild" | "moderate" | "severe"
  duration: Int                 // seconds

focusEvents/{eventId}/
  sessionId: String
  userId: String
  timestamp: Timestamp
  type: String                  // "focused" | "drowsy" | "distracted"
  duration: Int                 // seconds

focusSamples/{sampleId}/
  sessionId: String
  userId: String
  minuteMark: Int               // 0, 1, 2 ... N
  focusScore: Double            // sampled every 30 seconds
  state: String                 // "focused" | "drowsy" | "distracted"
  timestamp: Timestamp

breakSessions/{breakId}/
  sessionId: String
  userId: String
  timestamp: Timestamp
  reason: String                // "timer_complete" | "focus_drop"
  exercises: Array
    - name: String
    - duration: Int             // seconds
    - targetArea: String        // "neck" | "back" | "eyes" | "full_body"
    - completed: Bool
  chatMessages: Array           // Groq break chat log
    - role: String              // "user" | "assistant"
    - content: String
    - timestamp: Timestamp
  completed: Bool

achievements/{userId}/{badgeId}/
  name: String
  description: String
  unlockedAt: Timestamp
  type: String                  // "streak" | "focus" | "posture" | "milestone"
```

---

## CrewAI Agents (3 agents — Python backend)

Base URL: `http://localhost:8000` (local dev) or deployed endpoint.
ProgressReportAgent and StudyPlannerAgent replaced by Groq (simpler, faster).

### Agent 1 — PostureAnalyzerAgent
- **Trigger:** session ends
- **Input:** array of PostureEvent from Firebase for this session
- **Skills:** analyze_posture_events, calculate_posture_score, identify_problem_patterns
- **Output:** postureScore (Double), dominantIssue (String), patterns (String)

### Agent 2 — FocusMonitorAgent
- **Trigger:** session ends (parallel with PostureAnalyzerAgent)
- **Input:** array of FocusEvent + FocusSamples from Firebase
- **Skills:** analyze_focus_patterns, calculate_deep_focus_time, find_drop_minutes
- **Output:** focusScore (Double), deepFocusMinutes (Int), dropMinutes (Array<Int>)

### Agent 3 — BreakCoachAgent
- **Trigger:** after PostureAnalyzerAgent completes
- **Input:** dominantIssue from PostureAnalyzerAgent, breakDuration from settings
- **Skills:** fetch_exercises (ExerciseDB/Ninjas API), match_exercise_to_posture, create_break_routine
- **Output:** array of BreakExercise (name, duration, targetArea, instructions)

### Agent Collaboration Flow
```
Session ends
      ↓
PostureAnalyzerAgent ──────────────────→ dominantIssue
FocusMonitorAgent ──────────────────── → dropMinutes + focusScore
      ↓ (both done)
BreakCoachAgent ← receives dominantIssue → exercise list
Groq ← receives all data → narrative summary (parallel)
      ↓
SessionSummaryView shows everything
```

---

## Gamification Rules

```
XP per session:
  base XP = totalFocusMinutes * 10
  posture bonus = postureScore > 80 ? +50 : 0
  focus bonus = focusScore > 80 ? +50 : 0
  streak bonus = currentStreak * 10

Study levels:
  0 - 500 XP    → Beginner
  500 - 2000 XP → Scholar
  2000+ XP      → Elite Scholar

Badges:
  "First Session"      → complete first session
  "Posture Perfect"    → postureScore >= 95 in a session
  "Deep Focus"         → 60+ min deep focus in one session
  "7-Day Streak"       → 7 consecutive study days
  "Early Bird"         → start session before 8am
  "Night Owl"          → start session after 10pm
  "Math Wizard"        → 10 sessions of Matematika
  "Study Marathon"     → single session >= 90 minutes
```

---

## Firebase Billing Estimate (for reference)

```
1 session (50 min) writes:
  - focusSamples: ~100 docs (every 30s)
  - postureEvents: ~50 docs
  - 1 session doc
  - 1 breakSession doc
  = ~152 writes per session

2 sessions/day = ~304 writes/day

Firebase Spark free tier:
  - 20,000 writes/day limit
  - 304 writes/day = 1.5% of free limit ✅
  - Safe for up to ~65 active users/day on free tier
```

---

## Build Order (Recommended)

```
Week 1 — Foundation
  1. Xcode project setup + Firebase config (GoogleService-Info.plist)
  2. Firebase Auth — LoginView, RegisterView
  3. CameraManager.swift — AVCaptureSession front camera setup
  4. PostureDetector.swift — Vision body pose + CoreML inference
  5. Basic SessionView — live camera + posture label overlay

Week 2 — Core Features
  6. FocusDetector.swift — face landmarks + EAR + gaze
  7. FocusManager.swift — scoring, sampling every 30s, adaptive timer
  8. SessionManager.swift — orchestrate everything, voice alerts
  9. FirebaseService.swift — save session, events, samples
  10. PreSessionSetupView.swift — subject picker + duration
  11. BreakView.swift + ExerciseAPIService.swift
  12. BreakChatView.swift + GroqService.swift

Week 3 — Polish & Agents
  13. DashboardView.swift — charts per subject, streak, XP
  14. BadgesView.swift — achievements
  15. CrewAI Python backend — 3 agents
  16. AgentService.swift — Swift HTTP calls
  17. SessionSummaryView.swift — Groq summary + agent data
  18. NotificationService.swift — water, eye rest reminders
  19. SettingsView.swift
  20. Bug fixes + demo video
```

---

## Important Notes

- `NSCameraUsageDescription` must be set in Info.plist
- `NSMicrophoneUsageDescription` not needed (no mic recording)
- Camera runs on background `DispatchQueue` — UI updates must be on `DispatchQueue.main`
- Vision requests on a serial queue to avoid frame drops
- PostureClassifier.mlmodel input feature names must exactly match training CSV column names
- Firebase rules: users can only read/write their own documents (`request.auth.uid == userId`)
- Minimum iOS deployment target: iOS 16.0
- iPhone only (no iPad layout needed)
- Camera MUST be suspended during break (AVCaptureSession.stopRunning())
  and resumed when break ends (AVCaptureSession.startRunning())
- Groq API key stored in Secrets.plist (never commit to git)
- All Groq calls are async/await — handle loading states in UI

---

## Posture Alert Thresholds

```
sensitivity = "low"    → alert after 20 seconds of bad posture
sensitivity = "medium" → alert after 10 seconds (default)
sensitivity = "high"   → alert after 5 seconds
```
