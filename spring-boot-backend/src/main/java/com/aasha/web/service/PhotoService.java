package com.aasha.web.service;

import com.aasha.web.dto.ImageStorageReference;
import com.aasha.web.entity.NormalRecord;
import com.aasha.web.entity.CriticalRecord;
import com.aasha.web.repository.CriticalRecordRepository;
import com.aasha.web.repository.NormalRecordRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.minio.GetObjectArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import io.minio.BucketExistsArgs;
import io.minio.MakeBucketArgs;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.UUID;

@Service
public class PhotoService {

    private static final Logger log = LoggerFactory.getLogger(PhotoService.class);

    private final NormalRecordRepository normalRepo;
    private final CriticalRecordRepository criticalRepo;
    private final MinioClient minioClient;
    private final String bucket;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public PhotoService(NormalRecordRepository normalRepo, CriticalRecordRepository criticalRepo,
                        MinioClient minioClient, @Value("${minio.bucket}") String bucket) {
        this.normalRepo = normalRepo;
        this.criticalRepo = criticalRepo;
        this.minioClient = minioClient;
        this.bucket = bucket;
    }

    public ImageStorageReference uploadNormalPhoto(String recordId, MultipartFile file) throws Exception {
        String key = "normal/" + recordId + "/" + UUID.randomUUID() + getExtension(file);
        ImageStorageReference ref = put(key, file, "public_normal_result");
        normalRepo.findById(recordId).ifPresent(record -> {
            record.setPhotoUrl(referenceJson(ref));
            normalRepo.save(record);
        });
        return ref;
    }

    public ImageStorageReference uploadCriticalPhoto(String recordId, MultipartFile file) throws Exception {
        String key = "critical/" + recordId + "/" + UUID.randomUUID() + getExtension(file);
        ImageStorageReference ref = put(key, file, "private_critical");
        criticalRepo.findById(recordId).ifPresent(record -> {
            record.setPhotoUrl(referenceJson(ref));
            criticalRepo.save(record);
        });
        return ref;
    }

    public ImageStorageReference uploadCriticalClothing(String recordId, MultipartFile file) throws Exception {
        String key = "critical-clothing/" + recordId + "/" + UUID.randomUUID() + getExtension(file);
        ImageStorageReference ref = put(key, file, "private_critical");
        criticalRepo.findById(recordId).ifPresent(record -> {
            record.setClothingPhotoUrl(referenceJson(ref));
            criticalRepo.save(record);
        });
        return ref;
    }

    public ImageStorageReference uploadMatchInput(String requestId, MultipartFile file) throws Exception {
        String key = "match-input/" + requestId + "/" + UUID.randomUUID() + getExtension(file);
        return put(key, file, "temporary_match_input");
    }

    public byte[] getImageBytes(String storageId) throws Exception {
        String key = storageKey(storageId);
        try (InputStream stream = minioClient.getObject(GetObjectArgs.builder().bucket(bucket).object(key).build())) {
            return stream.readAllBytes();
        }
    }

    public String getImageUrl(String storageId) {
        try {
            String key = storageKey(storageId);
            String endpoint = key.startsWith("normal/") ? "file" : "secure-file";
            return "/api/v1/images/" + endpoint + "/" + key;
        } catch (Exception ignored) {
            return null;
        }
    }

    public boolean isNormalImage(String storageId) {
        try { return storageKey(storageId).startsWith("normal/"); }
        catch (Exception ignored) { return false; }
    }

    public void deleteTemporary(String assetId) {
        try {
            minioClient.removeObject(RemoveObjectArgs.builder().bucket(bucket).object(storageKey(assetId)).build());
        } catch (Exception e) {
            log.warn("Temporary image cleanup failed");
        }
    }

    private ImageStorageReference put(String key, MultipartFile file, String accessType) throws Exception {
        ensureBucket();
        byte[] data = file.getBytes();
        String contentType = file.getContentType() != null ? file.getContentType() : "image/jpeg";
        minioClient.putObject(PutObjectArgs.builder().bucket(bucket).object(key)
                .stream(new ByteArrayInputStream(data), data.length, -1)
                .contentType(contentType).build());
        return new ImageStorageReference("minio", key, UUID.randomUUID().toString(), "image", "stored",
                accessType, contentType, data.length);
    }

    private void ensureBucket() throws Exception {
        if (!minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucket).build())) {
            minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
        }
    }

    private String storageKey(String value) throws JsonProcessingException {
        if (value == null || value.isBlank()) throw new IllegalArgumentException("Missing storage reference");
        if (value.trim().startsWith("{")) {
            var node = objectMapper.readTree(value);
            value = node.path("storageId").asText(node.path("storage_id").asText(""));
        }
        if (value.isBlank() || value.startsWith("/") || value.contains("..") || value.contains("\\")) {
            throw new IllegalArgumentException("Invalid storage reference");
        }
        return value;
    }

    private String referenceJson(ImageStorageReference ref) {
        try { return objectMapper.writeValueAsString(ref.toJson()); }
        catch (JsonProcessingException e) { throw new IllegalStateException("Could not serialize image reference", e); }
    }

    private String getExtension(MultipartFile file) {
        String original = file.getOriginalFilename();
        if (original != null && original.contains(".")) {
            return original.substring(original.lastIndexOf("."));
        }
        return ".jpg";
    }
}
