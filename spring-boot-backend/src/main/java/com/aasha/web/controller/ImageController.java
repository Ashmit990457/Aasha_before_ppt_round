package com.aasha.web.controller;

import com.aasha.web.dto.ImageStorageReference;
import com.aasha.web.service.PhotoService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.multipart.MultipartFile;
import jakarta.servlet.http.HttpServletRequest;

import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/images")
public class ImageController {

    private static final Logger log = LoggerFactory.getLogger(ImageController.class);
    private final PhotoService photoService;

    public ImageController(PhotoService photoService) {
        this.photoService = photoService;
    }

    @PostMapping("/normal")
    public ResponseEntity<?> uploadNormalPhoto(
            @RequestParam("record_id") String recordId,
            @RequestParam("file") MultipartFile file) {
        try {
            log.info("Uploading normal photo for record: {}", recordId);
            ImageStorageReference ref = photoService.uploadNormalPhoto(recordId, file);
            return ResponseEntity.ok(ref.toJson());
        } catch (Exception e) {
            log.error("Failed to upload normal photo", e);
            return ResponseEntity.badRequest().body(Map.of("detail", "Image upload failed: " + e.getMessage()));
        }
    }

    @PostMapping("/critical")
    public ResponseEntity<?> uploadCriticalPhoto(
            @RequestParam("record_id") String recordId,
            @RequestParam("file") MultipartFile file) {
        try {
            log.info("Uploading critical photo for record: {}", recordId);
            ImageStorageReference ref = photoService.uploadCriticalPhoto(recordId, file);
            return ResponseEntity.ok(ref.toJson());
        } catch (Exception e) {
            log.error("Failed to upload critical photo", e);
            return ResponseEntity.badRequest().body(Map.of("detail", "Image upload failed: " + e.getMessage()));
        }
    }

    @PostMapping("/critical-clothing")
    public ResponseEntity<?> uploadCriticalClothing(
            @RequestParam("record_id") String recordId,
            @RequestParam("file") MultipartFile file) {
        try {
            log.info("Uploading critical clothing photo for record: {}", recordId);
            ImageStorageReference ref = photoService.uploadCriticalClothing(recordId, file);
            return ResponseEntity.ok(ref.toJson());
        } catch (Exception e) {
            log.error("Failed to upload critical clothing photo", e);
            return ResponseEntity.badRequest().body(Map.of("detail", "Image upload failed: " + e.getMessage()));
        }
    }

    @PostMapping("/match-input")
    public ResponseEntity<?> uploadMatchInput(
            @RequestParam("request_id") String requestId,
            @RequestParam("file") MultipartFile file) {
        try {
            log.info("Uploading match input photo for request: {}", requestId);
            ImageStorageReference ref = photoService.uploadMatchInput(requestId, file);
            return ResponseEntity.ok(ref.toJson());
        } catch (Exception e) {
            log.error("Failed to upload match input photo", e);
            return ResponseEntity.badRequest().body(Map.of("detail", "Image upload failed: " + e.getMessage()));
        }
    }

    @GetMapping("/url")
    public ResponseEntity<?> getImageUrl(@RequestParam("storage_id") String storageId) {
        String url = photoService.getImageUrl(storageId);
        if (url != null) {
            return ResponseEntity.ok(Map.of("url", url));
        }
        return ResponseEntity.notFound().build();
    }

    @GetMapping("/bytes/{assetId}")
    public ResponseEntity<byte[]> getImageBytes(@PathVariable String assetId) {
        try {
            byte[] bytes = photoService.getImageBytes(assetId);
            if (bytes != null) {
                return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.IMAGE_JPEG_VALUE)
                    .body(bytes);
            }
        } catch (Exception e) {
            log.error("Failed to get image bytes", e);
        }
        return ResponseEntity.notFound().build();
    }

    @DeleteMapping("/temporary/{assetId}")
    public ResponseEntity<?> deleteTemporary(@PathVariable String assetId) {
        photoService.deleteTemporary(assetId);
        return ResponseEntity.ok(Map.of("status", "deleted"));
    }

    @GetMapping("/file/**")
    public ResponseEntity<byte[]> serveFile(HttpServletRequest request) {
        String path = pathAfter(request, "/api/v1/images/file/");
        String recordId = recordId(path);
        log.debug("[IMAGE-DELIVERY-DEBUG] record_id={} storage_reference={}", recordId, path);
        try {
            if (!path.startsWith("normal/")) {
                log.debug("[IMAGE-DELIVERY-DEBUG] record_id={} status=404", recordId);
                return ResponseEntity.notFound().build();
            }
            byte[] bytes = photoService.getImageBytes(path);
            String contentType = path.endsWith(".png") ? "image/png"
                    : path.endsWith(".webp") ? "image/webp" : "image/jpeg";
            log.debug("[IMAGE-DELIVERY-DEBUG] record_id={} status=200", recordId);
            return ResponseEntity.ok().header(HttpHeaders.CONTENT_TYPE, contentType).body(bytes);
        } catch (Exception e) {
            log.warn("[IMAGE-DELIVERY-DEBUG] record_id={} status=404 error_type={} error={}",
                    recordId, e.getClass().getSimpleName(), e.getMessage());
        }
        return ResponseEntity.notFound().build();
    }

    @PreAuthorize("isAuthenticated()")
    @GetMapping("/secure-file/**")
    public ResponseEntity<byte[]> serveSecureFile(HttpServletRequest request) {
        String path = pathAfter(request, "/api/v1/images/secure-file/");
        String recordId = recordId(path);
        try {
            if (path.startsWith("normal/")) return ResponseEntity.notFound().build();
            byte[] bytes = photoService.getImageBytes(path);
            String contentType = path.endsWith(".png") ? "image/png"
                    : path.endsWith(".webp") ? "image/webp" : "image/jpeg";
            log.debug("[IMAGE-DELIVERY-DEBUG] record_id={} status=200", recordId);
            return ResponseEntity.ok().header(HttpHeaders.CONTENT_TYPE, contentType).body(bytes);
        } catch (Exception e) {
            log.warn("[IMAGE-DELIVERY-DEBUG] record_id={} status=404 error_type={} error={}",
                    recordId, e.getClass().getSimpleName(), e.getMessage());
            return ResponseEntity.notFound().build();
        }
    }

    private String pathAfter(HttpServletRequest request, String prefix) {
        String uri = request.getRequestURI();
        return uri.startsWith(prefix) ? uri.substring(prefix.length()) : "";
    }

    private String recordId(String path) {
        String[] parts = path.split("/");
        return parts.length > 1 ? parts[1] : "unknown";
    }
}
