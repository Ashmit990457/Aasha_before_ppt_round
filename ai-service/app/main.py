import json
import logging
import os
import threading
from typing import Optional

from fastapi import FastAPI, HTTPException

from .models import CandidateInput, MatchMoreRequest, MatchRequest, MatchResponse, MatchResult
from .scoring import MatchScoringConfig, MatchScoringService, ScoredCandidate, CandidateRecord

app = FastAPI(title="DisasterConnect AI Matching Engine")
logger = logging.getLogger("aasha.matching")

_scoring = None
_image_similarity = None
_face_similarity = None
_image_storage = None

PAGE_SIZE = 3
MAX_SESSIONS = 100
_ranked_sessions: dict[str, list[ScoredCandidate]] = {}
_services_lock = threading.Lock()
_service_status = {"text": False, "clip": False, "face": False, "minio": False}


def _clean_sessions():
    """Simple LRU-like cleanup to prevent memory leaks."""
    if len(_ranked_sessions) > MAX_SESSIONS:
        # Remove oldest 20% of sessions
        keys_to_remove = list(_ranked_sessions.keys())[:20]
        for key in keys_to_remove:
            _ranked_sessions.pop(key, None)


def _debug_matching_enabled() -> bool:
    """Development-only matching trace; disabled unless explicitly enabled."""
    return os.getenv("MATCHING_DEBUG_LOGS", "false").strip().lower() in {
        "1", "true", "yes", "on"
    }


def _debug_log(message: str, *args) -> None:
    if _debug_matching_enabled():
        logger.warning("[MATCHING-DEBUG] " + message, *args)


def _safe_exception(error: Exception) -> str:
    """Return diagnostic detail without echoing configured credentials."""
    message = str(error)
    for name in ("MINIO_ACCESS_KEY", "MINIO_SECRET_KEY"):
        value = os.getenv(name)
        if value:
            message = message.replace(value, "[redacted]")
    return f"{type(error).__name__}: {message[:300]}"


class _LoggingImageStorage:
    """Per-candidate read wrapper used only to trace the existing storage call."""

    def __init__(self, storage, record_id: str):
        self._storage = storage
        self._record_id = record_id

    def get_private_image(self, storage_id: str) -> bytes:
        try:
            if self._storage is None:
                raise RuntimeError("MinIO storage is unavailable")
            data = self._storage.get_private_image(storage_id)
            _debug_log("record_id=%s MinIO image retrieval=SUCCESS", self._record_id)
            return data
        except Exception as error:
            _debug_log(
                "record_id=%s MinIO image retrieval=FAILED error=%s",
                self._record_id,
                _safe_exception(error),
            )
            raise


def _get_services():
    global _scoring, _image_similarity, _face_similarity, _image_storage
    if _scoring is None:
        with _services_lock:
            if _scoring is None:
                from .text_similarity import TextSimilarityService
                from .image_similarity import ImageSimilarityService
                from .face_similarity import FaceSimilarityService
                from .image_storage import MinioImageStorageService
                _scoring = MatchScoringService(TextSimilarityService(), MatchScoringConfig.from_environment())
                _service_status["text"] = True
                _image_similarity = ImageSimilarityService()
                try:
                    _image_similarity.load()
                    _service_status["clip"] = True
                except Exception:
                    _image_similarity = None
                try:
                    _face_similarity = FaceSimilarityService()
                    _face_similarity.load_model()
                    _service_status["face"] = True
                except Exception:
                    _face_similarity = None
                try:
                    _image_storage = MinioImageStorageService()
                    _service_status["minio"] = True
                except Exception as error:
                    # Metadata-only matching remains available when MinIO is unavailable.
                    _image_storage = None
                    _debug_log(
                        "MinIO client initialization=FAILED error=%s",
                        _safe_exception(error),
                    )
    return _scoring, _image_similarity, _face_similarity, _image_storage


def _normal_photo_url(encoded: Optional[str]) -> Optional[str]:
    if not encoded:
        return None
    try:
        ref = json.loads(encoded)
    except (TypeError, ValueError):
        return None
    if not isinstance(ref, dict):
        return None
    storage_id = ref.get("storageId") or ref.get("storage_id")
    if not storage_id:
        return None
    if _image_storage is None:
        return None
    try:
        return _image_storage.public_image_url(storage_id)
    except Exception:
        return None


def _public_result(scored: ScoredCandidate) -> MatchResult:
    candidate = scored.candidate
    return MatchResult(
        incident_id=getattr(candidate, "incident_id", None),
        record_id=candidate.record_id,
        name=candidate.name,
        age=candidate.age,
        camp_name=candidate.camp_name,
        officer_name=candidate.officer_name,
        officer_contact=candidate.officer_contact,
        status=candidate.status,
        match_score=scored.match_score,
        record_type=candidate.record_type,
        photo_url=(
            _normal_photo_url(candidate.photo_url)
            if candidate.record_type == "normal"
            else None
        ),
        last_known_clothing=candidate.last_known_clothing,
        match_label=scored.match_label,
        explanation=scored.explanation,
    )


def _rank_candidates(query: dict, candidates: list) -> list[ScoredCandidate]:
    scoring, image_similarity, face_similarity, image_storage = _get_services()
    metadata_scored = [
        scoring.score(query, candidate) for candidate in candidates
    ]

    has_photo = query.get("photo") is not None
    _debug_log(
        "request has_search_photo=%s candidates=%d image_shortlist_size=%d",
        has_photo,
        len(candidates),
        scoring.config.image_shortlist_size,
    )
    if not has_photo:
        if _debug_matching_enabled():
            for scored in metadata_scored[:scoring.config.image_shortlist_size]:
                _debug_log(
                    "record_id=%s record_type=%s image_storage_id_present=%s "
                    "metadata_score=%.2f final_match_score=%.2f",
                    scored.candidate.record_id,
                    scored.candidate.record_type,
                    bool(scored.candidate.image_storage_id),
                    scored.match_score,
                    scored.match_score,
                )
        return metadata_scored

    photo_raw = query["photo"]
    if isinstance(photo_raw, str):
        import base64 as _b64
        try:
            decoded = _b64.b64decode(photo_raw, validate=True)
            _JPEG = b'\xff\xd8\xff'
            _PNG = b'\x89PNG'
            _WEBP = b'RIFF'
            if len(decoded) > 100 and (decoded[:3] == _JPEG or decoded[:4] == _PNG or decoded[:4] == _WEBP):
                photo_bytes = decoded
            else:
                photo_bytes = photo_raw.encode("utf-8")
        except Exception:
            photo_bytes = photo_raw.encode("utf-8")
    else:
        photo_bytes = photo_raw

    user_clip_embedding = None
    user_face_embedding = None

    if image_similarity is not None:
        try:
            user_clip_embedding = image_similarity.encode(photo_bytes)
        except Exception:
            user_clip_embedding = None

    if face_similarity is not None:
        try:
            user_face_embedding = face_similarity.get_embedding(photo_bytes)
        except Exception:
            user_face_embedding = None

    metadata_scored.sort(key=lambda s: s.match_score, reverse=True)
    shortlist = metadata_scored[:scoring.config.image_shortlist_size]

    results = []
    for scored in metadata_scored:
        candidate = scored.candidate
        clip_score = None
        face_score = None

        in_shortlist = scored in shortlist
        if in_shortlist and _debug_matching_enabled():
            _debug_log(
                "record_id=%s record_type=%s image_storage_id_present=%s "
                "metadata_score=%.2f",
                candidate.record_id,
                candidate.record_type,
                bool(candidate.image_storage_id),
                scored.match_score,
            )

        if in_shortlist and candidate.image_storage_id:
            logging_storage = _LoggingImageStorage(image_storage, candidate.record_id)
            if user_clip_embedding is not None:
                try:
                    candidate_embedding = image_similarity.embedding_for_storage(
                        candidate.image_storage_id, logging_storage
                    )
                    clip_score = image_similarity.similarity(user_clip_embedding, candidate_embedding)
                    _debug_log(
                        "record_id=%s CLIP/image embedding=SUCCESS clip_score=%.6f",
                        candidate.record_id,
                        clip_score,
                    )
                except Exception as error:
                    clip_score = None
                    _debug_log(
                        "record_id=%s CLIP/image embedding=FAILED error=%s",
                        candidate.record_id,
                        _safe_exception(error),
                    )

            if user_face_embedding is not None and face_similarity is not None:
                try:
                    candidate_face_embedding = face_similarity.embedding_for_storage(
                        candidate.image_storage_id, logging_storage
                    )
                    face_score = face_similarity.similarity(user_face_embedding, candidate_face_embedding)
                    _debug_log(
                        "record_id=%s face embedding=SUCCESS face_score=%.6f",
                        candidate.record_id,
                        face_score,
                    )
                except Exception as error:
                    face_score = None
                    _debug_log(
                        "record_id=%s face embedding=FAILED error=%s",
                        candidate.record_id,
                        _safe_exception(error),
                    )
            elif _debug_matching_enabled():
                _debug_log(
                    "record_id=%s face embedding=FAILED (query face embedding unavailable)",
                    candidate.record_id,
                )

            if user_clip_embedding is None and _debug_matching_enabled():
                _debug_log(
                    "record_id=%s CLIP/image embedding=FAILED (query image embedding unavailable)",
                    candidate.record_id,
                )

        elif in_shortlist and _debug_matching_enabled():
            _debug_log(
                "record_id=%s image work skipped: image_storage_id absent",
                candidate.record_id,
            )

        updated = scoring.add_image_scores(query, scored, clip_score=clip_score, face_score=face_score)
        if in_shortlist and _debug_matching_enabled():
            _debug_log(
                "record_id=%s metadata_score=%.2f final_match_score=%.2f "
                "clip_score=%s face_score=%s",
                candidate.record_id,
                scored.match_score,
                updated.match_score,
                "%.6f" % clip_score if clip_score is not None else "unavailable",
                "%.6f" % face_score if face_score is not None else "unavailable",
            )
        results.append(updated)

    results.sort(key=lambda s: s.match_score, reverse=True)
    return results


def _page(request_id: str, ranked: list[ScoredCandidate], offset: int, incident_id: str | None = None) -> MatchResponse:
    page_items = ranked[offset : offset + PAGE_SIZE]
    has_more = offset + PAGE_SIZE < len(ranked)
    return MatchResponse(
        request_id=request_id,
        results=[_public_result(scored) for scored in page_items],
        has_more=has_more,
        next_page_token=str(offset + PAGE_SIZE) if has_more else None,
        incident_id=incident_id or "",
    )


@app.post("/api/v1/match", response_model=MatchResponse)
@app.post("/match", response_model=MatchResponse, include_in_schema=False)
def match_missing_person(request: MatchRequest):
    _clean_sessions()
    query = request.model_dump(exclude_none=True)
    candidates = [_candidate_from_input(candidate) for candidate in request.candidates]
    ranked = _rank_candidates(query, candidates)
    request_id = __import__("uuid").uuid4().hex
    _ranked_sessions[request_id] = ranked
    response = _page(request_id, ranked, 0, request.incident_id)

    # Validate that all results belong to the requested incident
    if request.incident_id is not None:
        for result in response.results:
            if result.incident_id is not None and result.incident_id != request.incident_id:
                raise HTTPException(
                    status_code=500,
                    detail=f"Result incident_id mismatch: expected {request.incident_id}, got {result.incident_id}"
                )
        response.incident_id = request.incident_id

    return response


@app.post("/api/v1/match/more", response_model=MatchResponse)
@app.post("/match/more", response_model=MatchResponse, include_in_schema=False)
def match_more(request: MatchMoreRequest):
    try:
        offset = int(request.page_token)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid page token") from error
    ranked = _ranked_sessions.get(request.request_id)
    if ranked is None:
        raise HTTPException(status_code=404, detail="Matching request not found")

    # Get incident_id from the first candidate in the session (if available)
    incident_id = None
    if ranked and ranked[0].candidate.incident_id is not None:
        incident_id = ranked[0].candidate.incident_id

    response = _page(request.request_id, ranked, offset, incident_id)

    # The incident_id validation was done on the initial request
    # For pagination, we trust the session was already validated
    return response


def _candidate_from_input(candidate: CandidateInput) -> CandidateRecord:
    import json

    # Extract image_storage_id if available in photo_url JSON
    image_storage_id = None
    if candidate.photo_url:
        try:
            decoded = json.loads(candidate.photo_url)
            if isinstance(decoded, dict):
                image_storage_id = decoded.get("storageId") or decoded.get("storage_id")
        except (TypeError, ValueError):
            if candidate.photo_url.startswith(("normal/", "critical/", "critical-clothing/")):
                image_storage_id = candidate.photo_url
    if not image_storage_id:
        image_storage_id = candidate.image_storage_id

    return CandidateRecord(
        record_id=candidate.record_id,
        record_type=candidate.record_type,
        name=candidate.name,
        age=candidate.age or 0,
        camp_name=candidate.camp_name,
        status=candidate.status,
        officer_name=candidate.officer_name,
        officer_contact=candidate.officer_contact,
        photo_url=candidate.photo_url,
        image_storage_id=image_storage_id,
        last_known_clothing=candidate.last_known_clothing,
        found_location=candidate.found_location,
        additional_details=candidate.additional_details,
        incident_id=candidate.incident_id,
    )


@app.get("/api/v1/health")
@app.get("/health")
def health():
    return {"status": "ok", "models": dict(_service_status)}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
