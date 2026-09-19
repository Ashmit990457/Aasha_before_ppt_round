package com.aasha.web.controller;

import com.aasha.web.service.PhotoService;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ImageControllerTest {
    @Test
    void servesNormalObjectKeysContainingRecordAndFilenameSegments() throws Exception {
        PhotoService photos = mock(PhotoService.class);
        ImageController controller = new ImageController(photos);
        String path = "normal/eae42c9c-703a-474c-9b23-0269ded2ff83/photo.webp";
        byte[] image = new byte[] {1, 2, 3};
        when(photos.getImageBytes(path)).thenReturn(image);

        MockHttpServletRequest request = new MockHttpServletRequest(
                "GET", "/api/v1/images/file/" + path);

        var response = controller.serveFile(request);

        assertEquals(200, response.getStatusCode().value());
        assertArrayEquals(image, response.getBody());
        assertEquals("image/webp", response.getHeaders().getFirst("Content-Type"));
    }
}
