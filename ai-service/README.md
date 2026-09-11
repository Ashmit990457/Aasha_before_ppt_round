# DisasterConnect matching service

Run locally from this directory:

```powershell
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\uvicorn.exe app.main:app --reload
```

The service loads `all-MiniLM-L6-v2` once at startup and performs
non-biometric ranking using name, age, location, and details/clothing text.
`match_score` is an explainable prototype ranking score from 0 to 100, not a
probability. Step 12B uses centralized, prototype-only weights in
`app/scoring.py`: name 35%, age 20%, location 15%, details/clothing text 15%,
and image 15%. These weights are not scientifically validated.

With Firebase Admin credentials available through the normal Google
Application Default Credentials environment, records are read server-side
from `normal_records` and `critical_records`. For local development without
credentials, the service uses the small controlled dataset when
`MATCHING_ALLOW_DEMO_DATA=true` (the default). Set
`MATCHING_ALLOW_DEMO_DATA=false` to return a service-unavailable error instead
of falling back.

Critical responses are sanitized: critical photos, clothing-photo URLs, and
raw Firestore documents are never returned.

## Step 11A image storage

`app/image_storage.py` defines provider-neutral image categories and access
types. Step 11A uses only `InMemoryImageStorageService` in tests; it performs
no cloud uploads. A future provider adapter must keep normal images controlled,
critical images private, and match inputs temporary. The Flutter side keeps
selected images local through `ImageSelectionService`; it does not upload them.
## Step 11B: Cloudinary image adapter

The backend uses the Step 11A `ImageStorageService` abstraction with a
Cloudinary implementation. Configure Cloudinary only in the backend process;
never put these values in Flutter or source control:

```powershell
$env:CLOUDINARY_CLOUD_NAME="<cloud-name>"
$env:CLOUDINARY_API_KEY="<api-key>"
$env:CLOUDINARY_API_SECRET="<api-secret>"
.venv\Scripts\uvicorn.exe app.main:app --reload
```

The adapter stores assets under `disasterconnect/normal`,
`disasterconnect/critical`, `disasterconnect/critical_clothing`, and
`disasterconnect/match_input`. Normal assets use controlled upload delivery;
critical and temporary assets use authenticated delivery. API responses contain
opaque provider-neutral references, never credentials or private delivery URLs.

Image endpoints are `/api/v1/images/normal`, `/critical`,
`/critical-clothing`, `/match-input`, and
`DELETE /api/v1/images/temporary/{assetId}`. The Flutter client sends multipart
requests and does not know Cloudinary credentials.

The existing record fields can store the returned opaque reference. Full
official record mutation and offline image queue integration remain separate
from this provider adapter; offline records continue retaining their local
image until that sync extension is implemented.

## Step 12A/12B: image embeddings and ranking

The backend now loads `openai/clip-vit-base-patch32` once at startup through
`ImageSimilarityService`. It produces general visual embeddings and normalized
`image_similarity` values in the range 0–1. These are visual similarity signals,
not identity matches or probabilities, and are now integrated into the existing
matching endpoint as an optional ranking signal.

Stored-image embeddings are cached in memory by opaque storage identifier.
Private/critical images are retrieved only through the backend storage service;
their bytes, references, and embeddings are never returned to Flutter. The
`/health` response reports `image_model_ready`, model name, dimensions, and a
generic load error state. The request image is embedded once per
`/api/v1/match` request and reused for all candidates. Candidate embeddings are
looked up by opaque storage reference and reused from the in-memory cache.

If either image is unavailable, the image weight is removed for that candidate
and the remaining active weights are renormalized; a missing image never forces
the final score to zero. The temporary request image is cleaned up after
ranking. `/api/v1/match/more` continues from the same ranked session and does
not rerank.

Critical images are retrieved only inside the backend matching pipeline. The
existing sanitized critical response remains unchanged and never includes
critical image references, URLs, embeddings, or raw Firestore fields.
