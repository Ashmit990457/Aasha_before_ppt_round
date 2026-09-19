# Aasha AI Matching Service

This service provides multi-modal ranking for missing person searches. It combines semantic text similarity, face recognition, and broad visual descriptors to rank candidates retrieved from the primary database.

## 🏗️ Architecture

The AI service operates as a pure-function ranking engine in the production matching flow:
1. **Input**: A search query and a bounded list of candidates (from Spring Boot).
2. **Processing**: Compares query fields with each candidate using specialized models.
3. **Output**: A ranked list of candidates with similarity scores and explanations.

**Important**: This service does not query Firebase, Firestore, MongoDB, or any other database in production. It relies entirely on the candidate pool provided by Spring Boot.

## 🧠 Models

- **Text**: `all-MiniLM-L6-v2` for semantic name and detail overlap.
- **Vision (Face)**: `DeepFace` for high-precision facial identity anchors.
- **Vision (Broad)**: `openai/clip-vit-base-patch32` for general visual similarity (clothing, environment).

## 🚀 Running the Service

```bash
# Setup environment
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run with Uvicorn
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## ⚙️ Configuration

Candidate images are read from the same MinIO bucket used by Spring Boot. Uploads remain owned by Spring Boot.

- `MINIO_ENDPOINT` (for example `http://127.0.0.1:9000`)
- `MINIO_ACCESS_KEY`
- `MINIO_SECRET_KEY`
- `MINIO_BUCKET` (default: `aasha-photos`)
- `MEDIA_BASE_URL` (for example `http://192.168.0.111:8080`; the Spring Boot URL reachable by the phone)

For a local physical-phone demo, set `MEDIA_BASE_URL` to the laptop LAN URL before starting the AI service. The AI service uses it only to return Spring Boot media endpoints; it never returns a MinIO `127.0.0.1` URL to the phone.

Default weights are: name `0.15`, age `0.10`, location `0.05`, details `0.10`, CLIP `0.25`, and face `0.35`. Set `MATCH_WEIGHT_NAME`, `MATCH_WEIGHT_AGE`, `MATCH_WEIGHT_LOCATION`, `MATCH_WEIGHT_DETAILS`, `MATCH_WEIGHT_CLIP`, `MATCH_WEIGHT_FACE`, and `MATCH_IMAGE_SHORTLIST_SIZE` to tune them without code changes.

## 🔐 Security & Privacy

- **Sanitization**: Critical record photos are never exposed through this API.
- **Session Bounding**: The service maintains a bounded cache of ranked sessions (`MAX_SESSIONS=100`) to prevent memory leaks.
- **No Probability Claims**: Scores are "Match Scores" (similarity), not identity probabilities or guarantees.
