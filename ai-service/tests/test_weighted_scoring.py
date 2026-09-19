from app.scoring import CandidateRecord, MatchScoringConfig, MatchScoringService
from app.text_similarity import TextSimilarityService


class FakeEncoder:
    def encode(self, text, normalize_embeddings=True):
        return [1.0 if "ganpati" in text.lower() else 0.0]


def service():
    return MatchScoringService(TextSimilarityService(encoder=FakeEncoder()))


def candidate(name="other"):
    return CandidateRecord("id", "normal", name, 20, camp_name="Camp")


def test_metadata_only_keeps_score_in_range_and_uses_metadata():
    result = service().score({"name": "ganpati", "age": 20}, candidate("ganpati"))
    assert 0 <= result.match_score <= 100
    assert result.clip_score is None and result.face_score is None


def test_strong_visual_evidence_substantially_improves_score():
    scorer = service()
    query = {"name": "unrelated", "age": 70, "photo": "provided"}
    metadata = scorer.score(query, candidate("other"))
    visual = scorer.add_image_scores(query, metadata, clip_score=1.0, face_score=1.0)
    assert visual.match_score > metadata.match_score + 20
    assert visual.match_score <= 100


def test_weak_visual_evidence_does_not_override_strong_metadata():
    scorer = service()
    query = {"name": "ganpati", "age": 20, "photo": "provided"}
    metadata = scorer.score(query, candidate("ganpati"))
    weak = scorer.add_image_scores(query, metadata, clip_score=0.0, face_score=0.0)
    assert weak.match_score < metadata.match_score
    assert weak.match_score > 0


def test_missing_visual_evidence_is_not_a_penalty():
    scorer = service()
    query = {"name": "ganpati", "age": 20, "photo": "provided"}
    metadata = scorer.score(query, candidate("ganpati"))
    without_visual = scorer.add_image_scores(query, metadata)
    assert without_visual.match_score == metadata.match_score
