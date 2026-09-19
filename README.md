# Aasha — Disaster Reunification Network

> **आशा** (Aasha) means "Hope" in Hindi — an AI-powered platform reuniting families separated by natural disasters across India.

## 🎯 Problem Statement

> *"Student Innovation — Disaster management includes ideas related to risk mitigation, planning and management before, after or during a disaster."*
> — Smart India Hackathon 2026, Problem Statement ID: 26206

When natural disasters strike India — floods, earthquakes, cyclones, landslides — families get separated. Children lose parents. Elderly lose their children. The current system relies on paper records, phone calls, and word of mouth. By the time someone finds their loved one, days have passed.

**Aasha changes that.** Our AI-powered platform matches missing persons reports with relief camp records across India, cutting reunion time from days to hours.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AASHA SYSTEM ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   Flutter     │    │  Spring Boot │    │  Python AI   │  │
│  │   Mobile App  │◄──►│   Backend    │◄──►│   Service    │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                   │                   │           │
│         ▼                   ▼                   ▼           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ SQLite/Drift │    │   MySQL 8    │    │ Face + CLIP  │  │
│  │ (Offline)    │    │   (Server)   │    │ Matching     │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│                                                              │
│         │                   │                   │           │
│         ▼                   ▼                   ▼           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ SyncQueue    │    │   MinIO      │    │  Similarity  │  │
│  │ (Reliability) │    │  (Photos)    │    │  Ranking     │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📱 Flutter App (`flutter-app/`)

### Features

| Feature | Description |
|---------|-------------|
| **Search Missing Persons** | High-recall search by name, age, or location |
| **Multi-Modal AI Ranking** | Combines text, metadata, and visual similarity |
| **Emergency Center** | Live alerts, safety status, and nearby camps |
| **SOS System** | Immediate emergency signal with GPS tracking |
| **Critical Records** | Sensitive records for deceased/injured (Private) |
| **Offline-First** | Local SQLite storage with background sync |

### Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter 3.x |
| Language | Dart |
| State Management | Provider |
| Local Database | Drift (SQLite) |
| Sync Engine | SyncQueue + connectivity_plus |

---

## ☕ Spring Boot Backend (`spring-boot-backend/`)

### Features

| Feature | Description |
|---------|-------------|
| **REST API** | Secure endpoints for mobile and web |
| **Candidate Retrieval** | High-recall MySQL queries for AI pool |
| **MinIO Integration** | On-premise secure object storage |
| **JWT Security** | Role-based authorization (Official/User) |
| **Emergency Alerts** | Management of live disaster warnings |
| **SOS Handling** | Dashboard for official responders |

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/login` | Secure JWT authentication |
| POST | `/api/v1/match` | Multi-modal AI search matching |
| GET | `/api/alerts/active` | Public emergency alerts |
| POST | `/api/sos` | Submit emergency SOS signal |
| POST | `/api/normal-records` | Create missing person record |

---

## 🤖 AI Service (`ai-service/`)

### Features

| Feature | Description |
|---------|-------------|
| **Text Similarity** | Semantic name and detail matching |
| **Visual Similarity** | Face matching and CLIP visual anchors |
| **Renormalized Scoring** | Handles missing data without penalty |
| **Session Bounding** | Memory-safe ranking for many requests |

### Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | FastAPI |
| NLP | Sentence-Transformers |
| Vision | DeepFace, CLIP |
| Image Storage | MinIO/Local abstraction |

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** ≥ 3.x
- **Java JDK** ≥ 17
- **Python** ≥ 3.11
- **MySQL** ≥ 8.0
- **MinIO AIStor Free** with the `aasha-photos` bucket

### 1. Setup Backend

```bash
cd spring-boot-backend
$env:DB_PASSWORD = "<your-local-mysql-password>"
$env:JWT_SECRET = "<a-local-secret-at-least-32-bytes>"
$env:MINIO_ENDPOINT = "http://127.0.0.1:9000"
$env:MINIO_ACCESS_KEY = "<your-minio-access-key>"
$env:MINIO_SECRET_KEY = "<your-minio-secret-key>"
$env:MINIO_BUCKET = "aasha-photos"
$env:MATCHING_AI_URL = "http://localhost:8000/api/v1/match"
$env:MEDIA_BASE_URL = "http://192.168.0.111:8080"
$env:FIREBASE_NOTIFICATIONS_ENABLED = "false"
# When FCM is configured, set these without committing credentials:
# $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\\private\\firebase-service-account.json"
# $env:FIREBASE_PROJECT_ID = "<firebase-project-id>"
.\gradlew.bat bootRun
```

### 2. Setup AI Service

```bash
cd ai-service
python -m venv venv
venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

`MEDIA_BASE_URL` is the Spring Boot LAN URL used in normal match-result photo links. It must be reachable from the physical phone; do not use the laptop-only MinIO address there.

### 3. Setup Flutter

```bash
cd flutter-app
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
```

Start order: MySQL, MinIO, Python AI, Spring Boot, then Flutter. Spring Boot writes image bytes to MinIO and stores the JSON image reference in MySQL; Python receives candidates from Spring Boot and reads shortlisted objects from MinIO.

For local Windows startup, persist the required USER-level environment variables
once, then open a new PowerShell and run:

```powershell
.\start-asha.ps1
```

The script validates MySQL, MinIO, AI reachability, Firebase credentials, and
required configuration before starting Spring Boot. It never contains or prints
secret values. The database password and MinIO secret key must be supplied from
the existing local installation if they are not already present in the USER
environment.

Production storage and candidate sources are MySQL and MinIO. Firebase/Firestore, Cloudinary, and MongoDB are not part of the production matching or storage flow.

### Government alert push notifications

The Flutter Android app registers authenticated normal-user FCM tokens at
`POST /api/notifications/device-token`. When a Head Official activates an
alert, Spring Boot sends a high-priority FCM message to active registered
normal-user devices. The Android emergency channel uses a roughly 10-second
vibration pattern and opens the Emergency Alerts screen when tapped.

To enable delivery locally, add the Firebase Android app configuration as the
uncommitted `flutter-app/android/app/google-services.json`, set
`FIREBASE_NOTIFICATIONS_ENABLED=true`, and provide Firebase Admin credentials
through Google Application Default Credentials (`GOOGLE_APPLICATION_CREDENTIALS`)
plus `FIREBASE_PROJECT_ID` if needed. Without those values, the application
still builds and logs `notification_dispatch=NOT_CONFIGURED`; no notification
is sent. Firebase is used only for push delivery, not for Asha storage,
matching, SOS, or alert authorization.

---

## 🔐 Security & Privacy

- **No Public Photos**: Critical records are never displayed to normal users.
- **On-Premise Storage**: Photos stay in MinIO, not public clouds.
- **JWT Protection**: All sensitive endpoints require signed tokens.
- **Domain Separation**: AI matching is separate from SOS/Emergency systems.

---

## 🙏 Acknowledgments

- **Smart India Hackathon 2026** — Problem Statement 26206
- **NDMA** — National Disaster Management Authority
- **DeepFace & OpenAI CLIP** — For visual similarity models

---

## 🇮🇳 Made with ❤️ for India
