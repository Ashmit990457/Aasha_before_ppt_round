import os

import pytest

from app.image_storage import MinioImageStorageService


REAL_NORMAL_OBJECT = (
    "normal/eae42c9c-703a-474c-9b23-0269ded2ff83/"
    "5e16ac22-b211-488f-98b6-e339aa07245d.webp"
)


def test_production_minio_adapter_reads_real_ganpati_object():
    required = ("MINIO_ENDPOINT", "MINIO_ACCESS_KEY", "MINIO_SECRET_KEY")
    if not all(os.getenv(name) for name in required):
        pytest.skip("MinIO integration credentials are not configured in this shell")

    service = MinioImageStorageService()
    image_bytes = service.get_private_image(REAL_NORMAL_OBJECT)

    assert image_bytes
    assert len(image_bytes) > 0
