package com.aasha.web.service;

import com.aasha.web.dto.ImageStorageReference;
import com.aasha.web.entity.CriticalRecord;
import com.aasha.web.entity.NormalRecord;
import com.aasha.web.repository.CriticalRecordRepository;
import com.aasha.web.repository.NormalRecordRepository;
import io.minio.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;

@Service
public class PhotoService {

    private static final Logger log = LoggerFactory.getLogger(PhotoService.class);

    private final NormalRecordRepository normalRepo;
    private final CriticalRecordRepository criticalRepo;
    private final MinioClient minioClient;

    @Value("${minio.bucket}")
    private String bucket;

    private final Map<String, byte[]> temporaryStore = new ConcurrentHashMap<>();

    public PhotoService(NormalRecordRepository normalRepo,
                        CriticalRecordRepository criticalRepo,
                        MinioClient minioClient) {
        this.normalRepo = normalRepo;
        this.criticalRepo = criticalRepo;
        this.minioClient = minioClient;
    }

    public ImageStorageReference uploadNormalPhoto(String recordId, MultipartFile file) throws Exception {
        String objectName = "normal/" + recordId + "/" + UUID.randomUUID() + getExtension(file);
        uploadToMinio(objectName, file);

        String photoUrl = minioClient.getPresignedObjectUrl(
                GetPresignedObjectUrlArgs.builder()
                        .bucket(bucket)
                        .object(objectName)
                        .method(io.minio.http.Method.GET)
                        .build()
        );

        normalRepo.findById(recordId).ifPresent(record -> {
            record.setPhotoUrl(photoUrl);
            normalRepo.save(record);
        });

        String assetId = UUID.randomUUID().toString();
        temporaryStore.put(assetId, file.getBytes());

        return new ImageStorageReference(
            "minio",
            recordId,
            assetId,
            "image",
            "stored",
            "public",
            file.getContentType() != null ? file.getContentType() : "image/jpeg",
            (int) file.getSize()
        );
    }

    public ImageStorageReference uploadCriticalPhoto(String recordId, MultipartFile file) throws Exception {
        String objectName = "critical/" + recordId + "/" + UUID.randomUUID() + getExtension(file);
        uploadToMinio(objectName, file);

        String photoUrl = minioClient.getPresignedObjectUrl(
                GetPresignedObjectUrlArgs.builder()
                        .bucket(bucket)
                        .object(objectName)
                        .method(io.minio.http.Method.GET)
                        .build()
        );

        criticalRepo.findById(recordId).ifPresent(record -> {
            record.setPhotoUrl(photoUrl);
            criticalRepo.save(record);
        });

        String assetId = UUID.randomUUID().toString();
        temporaryStore.put(assetId, file.getBytes());

        return new ImageStorageReference(
            "minio",
            recordId,
            assetId,
            "image",
            "stored",
            "public",
            file.getContentType() != null ? file.getContentType() : "image/jpeg",
            (int) file.getSize()
        );
    }

    public ImageStorageReference uploadCriticalClothing(String recordId, MultipartFile file) throws Exception {
        String objectName = "critical-clothing/" + recordId + "/" + UUID.randomUUID() + getExtension(file);
        uploadToMinio(objectName, file);

        String photoUrl = minioClient.getPresignedObjectUrl(
                GetPresignedObjectUrlArgs.builder()
                        .bucket(bucket)
                        .object(objectName)
                        .method(io.minio.http.Method.GET)
                        .build()
        );

        criticalRepo.findById(recordId).ifPresent(record -> {
            record.setClothingPhotoUrl(photoUrl);
            criticalRepo.save(record);
        });

        String assetId = UUID.randomUUID().toString();
        temporaryStore.put(assetId, file.getBytes());

        return new ImageStorageReference(
            "minio",
            recordId,
            assetId,
            "image",
            "stored",
            "public",
            file.getContentType() != null ? file.getContentType() : "image/jpeg",
            (int) file.getSize()
        );
    }

    public ImageStorageReference uploadMatchInput(String requestId, MultipartFile file) throws Exception {
        String objectName = "match-input/" + requestId + "/" + UUID.randomUUID() + getExtension(file);
        uploadToMinio(objectName, file);

        String assetId = UUID.randomUUID().toString();
        temporaryStore.put(assetId, file.getBytes());

        return new ImageStorageReference(
            "minio",
            requestId,
            assetId,
            "image",
            "temporary",
            "private",
            file.getContentType() != null ? file.getContentType() : "image/jpeg",
            (int) file.getSize()
        );
    }

    public String getImageUrl(String storageId) {
        NormalRecord normal = normalRepo.findById(storageId).orElse(null);
        if (normal != null && normal.getPhotoUrl() != null) {
            return normal.getPhotoUrl();
        }

        CriticalRecord critical = criticalRepo.findById(storageId).orElse(null);
        if (critical != null && critical.getPhotoUrl() != null) {
            return critical.getPhotoUrl();
        }

        return null;
    }

    public byte[] getImageBytes(String assetId) {
        return temporaryStore.get(assetId);
    }

    public void deleteTemporary(String assetId) {
        temporaryStore.remove(assetId);
    }

    private void uploadToMinio(String objectName, MultipartFile file) throws Exception {
        boolean exists = minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
        if (!exists) {
            minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
        }

        minioClient.putObject(
            PutObjectArgs.builder()
                .bucket(bucket)
                .object(objectName)
                .stream(file.getInputStream(), file.getSize(), -1)
                .contentType(file.getContentType())
                .build()
        );
        log.info("Uploaded to MinIO: {}/{}", bucket, objectName);
    }

    private String getExtension(MultipartFile file) {
        String original = file.getOriginalFilename();
        if (original != null && original.contains(".")) {
            return original.substring(original.lastIndexOf("."));
        }
        return ".jpg";
    }
}
