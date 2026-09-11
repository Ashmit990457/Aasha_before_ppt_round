import json
from typing import Optional

from fastapi import FastAPI, HTTPException

from .data_sources import DemoRecordDataSource, FirestoreRecordDataSource, initialize_firestore_client
from .models import MatchMoreRequest, MatchRequest, MatchResponse, MatchResult
from .scoring import CandidateRecord, MatchScoringConfig, MatchScoringService, ScoredCandidate

app = FastAPI(title="DisasterConnect AI Matching Engine")

_text_similarity = None
_scoring = None
_image_similarity = None
_image_storage = None

PAGE_SIZE = 3


def _get_services():
    global _text_similarity, _scoring, _image_similarity, _image_storage
    if _scoring is None:
        from .text_similarity import TextSimilarityService
        from .image_similarity import ImageSimilarityService
        from .image_storage import InMemoryImageStorageService
        _text_similarity = TextSimilarityService()
        _scoring = MatchScoringService(_text_similarity)
        _image_similarity = ImageSimilarityService()
        _image_storage = InMemoryImageStorageService()
    return _scoring, _image_similarity, _image_storage


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
    scoring, image_similarity, image_storage = _get_services()
    metadata_scored = [
        scoring.score(query, candidate) for candidate in candidates
    ]

    has_photo = query.get("photo") is not None
    if not has_photo:
        return metadata_scored

    user_embedding = image_similarity.encode(query["photo"])

    metadata_scored.sort(key=lambda s: s.match_score, reverse=True)
    shortlist = metadata_scored[:scoring.config.image_shortlist_size]

    results = []
    for scored in metadata_scored:
        candidate = scored.candidate
        clip_score = None
        if scored in shortlist and candidate.image_storage_id:
            try:
                candidate_embedding = image_similarity.embedding_for_storage(
                    candidate.image_storage_id, image_storage
                )
                clip_score = image_similarity.similarity(user_embedding, candidate_embedding)
            except Exception:
                clip_score = None

        updated = scoring.add_image_scores(query, scored, clip_score=clip_score)
        results.append(updated)

    try:
        image_storage.delete_image(query["photo"])
    except Exception:
        pass

    results.sort(key=lambda s: s.match_score, reverse=True)
    return results


def _page(request_id: str, ranked: list[ScoredCandidate], offset: int) -> MatchResponse:
    page_items = ranked[offset : offset + PAGE_SIZE]
    has_more = offset + PAGE_SIZE < len(ranked)
    return MatchResponse(
        request_id=request_id,
        results=[_public_result(scored) for scored in page_items],
        has_more=has_more,
        next_page_token=str(offset + PAGE_SIZE) if has_more else None,
    )


@app.post("/api/v1/match", response_model=MatchResponse)
@app.post("/match", response_model=MatchResponse, include_in_schema=False)
def match_missing_person(request: MatchRequest):
    query = request.model_dump(exclude_none=True)

    try:
        client = initialize_firestore_client()
        data_source = FirestoreRecordDataSource(client)
        candidates = data_source.fetch_recent(100)
    except Exception:
        data_source = DemoRecordDataSource()
        candidates = data_source.fetch_recent(100)

    ranked = _rank_candidates(query, candidates)
    return _page("initial", ranked, 0)


@app.post("/api/v1/match/more", response_model=MatchResponse)
@app.post("/match/more", response_model=MatchResponse, include_in_schema=False)
def match_more(request: MatchMoreRequest):
    raise HTTPException(status_code=501, detail="Pagination not implemented in demo")


@app.get("/api/v1/health")
@app.get("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
