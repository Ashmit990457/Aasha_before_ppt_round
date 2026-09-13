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
│         │                   │                   │           │
│         ▼                   ▼                   ▼           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   SQLite     │    │   MySQL      │    │  Face/Image  │  │
│  │   (Offline)  │    │   (Server)   │    │  Matching    │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│                                                              │
│         │                   │                   │           │
│         ▼                   ▼                   ▼           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Wi-Fi Direct│    │   MinIO      │    │  OpenStreet  │  │
│  │  (Ad-hoc)    │    │  (Photos)    │    │  Map (API)   │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📱 Flutter App (`flutter-app/`)

### Features

| Feature | Description |
|---------|-------------|
| **Search Missing Persons** | Search by name, age, photo, or district |
| **Photo AI Matching** | Upload a photo to find similar faces |
| **Phonetic Name Search** | Handles name variations across 12 Indian languages |
| **Relief Camp Directory** | Live directory of all active relief camps |
| **Critical Records** | Confidential records for deceased/critically injured |
| **Offline Mode** | Works without internet, syncs when connection returns |
| **Ad-hoc Sync** | Phone-to-phone data transfer when server is unreachable |

### Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter 3.x |
| Language | Dart |
| State Management | Provider |
| Local Database | Drift (SQLite) |
| HTTP Client | http package |
| Image Picker | image_picker |
| Location | geolocator |
| Connectivity | connectivity_plus |

### Project Structure

```
flutter-app/
├── lib/
│   ├── core/
│   │   ├── config/api_config.dart        # API base URLs
│   │   ├── utils/photo_url_helper.dart   # Photo URL handling
│   │   └── theme/app_theme.dart          # App theming
│   ├── data/
│   │   ├── models/                       # Data models
│   │   │   ├── normal_record.dart        # Missing person record
│   │   │   ├── critical_record.dart      # Critical record
│   │   │   ├── camp.dart                 # Relief camp
│   │   │   └── app_user.dart             # User model
│   │   ├── repositories/                 # API calls
│   │   │   ├── official_normal_record_repository.dart
│   │   │   ├── official_critical_record_repository.dart
│   │   │   └── camp_repository.dart
│   │   ├── local/                        # Offline storage
│   │   │   ├── database/app_database.dart
│   │   │   └── repositories/
│   │   └── sync/sync_service.dart        # Offline sync
│   └── features/
│       ├── auth/                         # Login/Register
│       ├── official/                     # Officer dashboard
│       │   └── add_record_screen.dart    # Add missing person
│       ├── user/                         # Public search
│       │   └── search_form_screen.dart   # Search form
│       ├── images/                       # Photo handling
│       │   └── image_upload_api_service.dart
│       └── matching/                     # AI matching
│           └── data/services/match_api_service.dart
├── pubspec.yaml
└── README.md
```

### How It Works

1. **Officer registers** at relief camp → gets JWT token
2. **Officer adds survivor** → record saved to MySQL via API
3. **Officer uploads photo** → stored in MinIO
4. **Family searches** → queries MySQL, shows results with photos
5. **AI matches** → phonetic + photo similarity scoring

---

## ☕ Spring Boot Backend (`spring-boot-backend/`)

### Features

| Feature | Description |
|---------|-------------|
| **REST API** | Full CRUD for records, camps, alerts |
| **JWT Authentication** | Secure API with role-based access |
| **MinIO Integration** | Photo storage in MinIO object storage |
| **MySQL Database** | Persistent data storage |
| **Web Portal** | Public search interface |
| **Match API** | AI-powered search matching |
| **Alert System** | Live disaster alerts |
| **SOS Endpoint** | Emergency SOS handling |

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login and get JWT |
| GET | `/api/normal-records/list` | List all records |
| POST | `/api/normal-records` | Create new record |
| GET | `/api/camps/list` | List all camps |
| POST | `/api/camps` | Create new camp |
| POST | `/api/v1/match` | AI search matching |
| POST | `/api/v1/images/normal` | Upload normal photo |
| POST | `/api/v1/images/critical` | Upload critical photo |
| POST | `/api/v1/alerts/sos` | Send SOS signal |
| GET | `/api/v1/alerts/live` | Get live alerts |

### Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Spring Boot 3.5 |
| Language | Java 25 |
| Database | MySQL 8 |
| Object Storage | MinIO |
| Authentication | JWT |
| Template Engine | Thymeleaf |
| Build Tool | Gradle |

### Project Structure

```
spring-boot-backend/
├── src/main/java/com/aasha/web/
│   ├── config/
│   │   ├── SecurityConfig.java           # Security configuration
│   │   ├── JwtAuthFilter.java            # JWT authentication filter
│   │   └── MinioConfig.java              # MinIO client config
│   ├── controller/
│   │   ├── AuthController.java           # Authentication endpoints
│   │   ├── ApiController.java            # CRUD endpoints
│   │   ├── MatchController.java          # AI search matching
│   │   ├── ImageController.java          # Photo upload
│   │   ├── AlertController.java          # Alerts and SOS
│   │   └── SearchController.java         # Web portal
│   ├── entity/
│   │   ├── NormalRecord.java             # Missing person record
│   │   ├── CriticalRecord.java           # Critical record
│   │   ├── Camp.java                     # Relief camp
│   │   ├── Alert.java                    # Disaster alert
│   │   └── AppUser.java                  # User entity
│   ├── repository/                       # Database queries
│   ├── service/
│   │   ├── RecordService.java            # Business logic
│   │   ├── PhotoService.java             # MinIO photo storage
│   │   └── JwtService.java               # JWT token handling
│   └── dto/                              # Data transfer objects
├── src/main/resources/
│   ├── application.properties            # Configuration
│   ├── templates/                        # Web portal HTML
│   ├── static/css/                       # Web portal styles
│   └── db/migration/                     # Flyway migrations
├── build.gradle.kts
└── README.md
```

### Database Schema

```sql
-- Normal Records (Missing Persons)
CREATE TABLE normal_records (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    age INT,
    photo_url TEXT,
    camp_id VARCHAR(36),
    camp_name VARCHAR(255),
    officer_uid VARCHAR(36),
    officer_name VARCHAR(255),
    officer_contact VARCHAR(50),
    status VARCHAR(50) DEFAULT 'AT_CAMP',
    additional_details TEXT,
    found_at TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Critical Records
CREATE TABLE critical_records (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    age INT,
    photo_url TEXT,
    clothing_photo_url TEXT,
    last_known_clothing VARCHAR(500),
    camp_id VARCHAR(36),
    camp_name VARCHAR(255),
    status VARCHAR(50) DEFAULT 'UNIDENTIFIED',
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Relief Camps
CREATE TABLE camps (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    location_name VARCHAR(255),
    contact_number VARCHAR(50),
    officer_name VARCHAR(255),
    officer_uid VARCHAR(36),
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Alerts
CREATE TABLE alerts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    message TEXT,
    type VARCHAR(50),
    severity VARCHAR(50),
    district VARCHAR(100),
    state VARCHAR(100),
    latitude DOUBLE,
    longitude DOUBLE,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP
);
```

---

## 🤖 AI Service (`ai-service/`)

### Features

| Feature | Description |
|---------|-------------|
| **Face Similarity** | Deep learning face matching using DeepFace |
| **Image Similarity** | SSIM and histogram comparison |
| **Text Similarity** | TF-IDF and cosine similarity |
| **Combined Scoring** | Weighted combination of all matchers |
| **Cloudinary Storage** | Cloud photo storage option |

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/match/face` | Face similarity matching |
| POST | `/api/v1/match/image` | Image similarity matching |
| POST | `/api/v1/match/text` | Text similarity matching |
| POST | `/api/v1/match/combined` | Combined scoring |

### Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | FastAPI |
| Language | Python 3.11 |
| Face Detection | DeepFace |
| Image Processing | OpenCV, scikit-image |
| Text Processing | scikit-learn (TF-IDF) |
| Storage | Cloudinary / Local |

### Project Structure

```
ai-service/
├── app/
│   ├── main.py                          # FastAPI application
│   ├── face_similarity.py               # Face matching
│   ├── image_similarity.py              # Image matching
│   ├── text_similarity.py               # Text matching
│   ├── scoring.py                       # Combined scoring
│   ├── models.py                        # Data models
│   ├── data_sources.py                  # Data sources
│   ├── image_storage.py                 # Image storage
│   └── cloudinary_storage.py            # Cloud storage
├── tests/                               # Test suite
├── requirements.txt
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** ≥ 3.x
- **Java JDK** ≥ 17
- **Python** ≥ 3.11
- **MySQL** ≥ 8.0
- **MinIO** (optional, for photo storage)

### 1. Clone the Repository

```bash
git clone https://github.com/udayps10/Asha---Disaster-Reunification-Network.git
cd Asha---Disaster-Reunification-Network
```

### 2. Start MySQL

```bash
# Create database
mysql -u root -p
CREATE DATABASE aasha;
```

### 3. Start MinIO (Optional)

```bash
# Download MinIO from https://min.io
minio.exe server C:\minio-data --console-address ":9001"

# Open http://localhost:9001
# Login: minioadmin / minioadmin
# Create bucket: aasha-photos
```

### 4. Start Spring Boot Backend

```bash
cd spring-boot-backend

# Update application.properties with your MySQL password
# spring.datasource.password=your_password

# Build and run
./gradlew bootRun

# Backend runs on http://localhost:8080
```

### 5. Start AI Service

```bash
cd ai-service

# Create virtual environment
python -m venv venv
venv\Scripts\activate  # Windows
source venv/bin/activate  # Mac/Linux

# Install dependencies
pip install -r requirements.txt

# Run the service
python -m uvicorn app.main:app --reload --port 5000

# AI service runs on http://localhost:5000
```

### 6. Start Flutter App

```bash
cd flutter-app

# Install dependencies
flutter pub get

# Run on emulator or device
flutter run

# Or build APK
flutter build apk
```

---

## 📸 Screenshots

### Mobile App
- Search form with name, age, and photo upload
- Search results with photos and officer contacts
- Officer dashboard for adding records
- Relief camps directory

### Web Portal
- Public search interface
- Live disaster alerts
- Emergency contacts

### API Documentation
- Available at http://localhost:8080/swagger-ui.html

---

## 🔐 Security

| Feature | Implementation |
|---------|---------------|
| Authentication | JWT tokens with role-based access |
| Password Hashing | BCrypt |
| API Protection | Spring Security filter chain |
| Photo Storage | MinIO with presigned URLs |
| Data Validation | Server-side validation on all inputs |

---

## 🌐 Deployment

### Backend (Railway/Render)
```bash
# Build JAR
./gradlew bootJar

# Deploy to Railway
railway login
railway init
railway up
```

### Frontend (Vercel/Netlify)
```bash
# Build web version
flutter build web

# Deploy to Vercel
vercel --prod
```

### AI Service (Render/Fly.io)
```bash
# Build Docker image
docker build -t aasha-ai .

# Deploy to Render
# Connect GitHub repo and auto-deploy
```

---

## 📊 Database Tables

| Table | Purpose |
|-------|---------|
| `normal_records` | Missing persons records |
| `critical_records` | Deceased/critically injured |
| `camps` | Relief camps |
| `alerts` | Disaster alerts |
| `app_users` | Registered users |

---

## 🔗 API Integration

### Flutter ↔ Spring Boot

```dart
// Example: Create a record
final response = await http.post(
  Uri.parse('$baseUrl/api/normal-records'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  },
  body: jsonEncode({
    'name': 'Priya Sharma',
    'age': 28,
    'campId': 'camp-123',
    'campName': 'Delhi Relief Camp',
    'officerUid': 'officer-456',
    'officerName': 'Officer Singh',
    'officerContact': '1234567890',
    'status': 'AT_CAMP',
  }),
);
```

### Spring Boot ↔ MinIO

```java
// Example: Upload photo
minioClient.putObject(
    PutObjectArgs.builder()
        .bucket("aasha-photos")
        .object("normal/" + recordId + "/" + filename)
        .stream(file.getInputStream(), file.getSize(), -1)
        .contentType(file.getContentType())
        .build()
);
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🙏 Acknowledgments

- **Smart India Hackathon 2026** — Problem Statement 26206
- **AICTE** — For organizing the hackathon
- **NDMA** — National Disaster Management Authority
- **OpenStreetMap** — For geographic data
- **DeepFace** — For face recognition
- **Spring Boot** — For backend framework
- **Flutter** — For mobile app framework

---

## 📞 Contact

**Udaypratap Singh**
- GitHub: [@udayps10](https://github.com/udayps10)
- Email: udayps10@users.noreply.github.com

**Project Link:** https://github.com/udayps10/Asha---Disaster-Reunification-Network

---

## 🇮🇳 Made with ❤️ for India

> *"Technology should serve humanity, especially in times of crisis."*
