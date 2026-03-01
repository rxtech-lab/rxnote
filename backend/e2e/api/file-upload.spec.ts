import { test, expect } from "@playwright/test";

test.describe.serial("File Upload API", () => {
  let fileId: number;
  let noteId: number;

  test("POST /api/v1/upload/presigned - should return upload URL and file ID", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/presigned", {
      data: {
        filename: "test-image.jpg",
        contentType: "image/jpeg",
        size: 1024,
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveProperty("fileId");
    expect(body).toHaveProperty("uploadUrl");
    expect(body).toHaveProperty("key");
    expect(body).toHaveProperty("expiresAt");
    expect(body.uploadUrl).toContain("mock-s3.example.com");
    expect(body.key).toContain("mock/");

    fileId = body.fileId;
  });

  test("POST /api/v1/upload/presigned - should reject non-image content types", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/presigned", {
      data: {
        filename: "test-file.pdf",
        contentType: "application/pdf",
        size: 1024,
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContain("image");
  });

  test("POST /api/v1/upload/presigned - should validate required fields", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/upload/presigned", {
      data: {
        filename: "test.jpg",
        // missing contentType
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
  });

  test("POST /api/v1/notes - should create note with file IDs and return signed URLs", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/notes", {
      data: {
        title: "Note with Image",
        note: "Test note with uploaded image",
        visibility: "public",
        images: [`file:${fileId}`],
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body).toHaveProperty("id");
    expect(body.title).toBe("Note with Image");
    // images should be objects with id and url, containing signed URLs
    expect(body.images).toHaveLength(1);
    expect(body.images[0]).toHaveProperty("id");
    expect(body.images[0]).toHaveProperty("url");
    expect(body.images[0].url).toContain("mock-s3.example.com");
    expect(body.images[0].url).not.toContain("file:");

    noteId = body.id;
  });

  test("GET /api/v1/notes/{id} - should return signed URLs in images field", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/notes/${noteId}`);

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.id).toBe(noteId);
    // images should be objects with id and url, containing signed URLs
    expect(body.images).toHaveLength(1);
    expect(body.images[0]).toHaveProperty("id");
    expect(body.images[0]).toHaveProperty("url");
    expect(body.images[0].url).toMatch(/^https:\/\//);
    expect(body.images[0].url).not.toContain("file:");
  });

  test("GET /api/v1/notes - should return signed URLs in images field for list", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/notes");

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.data).toBeInstanceOf(Array);

    // Find our note with images
    const noteWithImages = body.data.find((note: { id: number }) => note.id === noteId);
    expect(noteWithImages).toBeDefined();
    expect(noteWithImages.images).toHaveLength(1);
    expect(noteWithImages.images[0]).toHaveProperty("id");
    expect(noteWithImages.images[0]).toHaveProperty("url");
    expect(noteWithImages.images[0].url).toContain("mock-s3.example.com");
  });

  test("PUT /api/v1/notes/{id} - should handle adding new file IDs", async ({
    request,
  }) => {
    // Upload a second file
    const uploadResponse = await request.post("/api/v1/upload/presigned", {
      data: {
        filename: "second-image.png",
        contentType: "image/png",
        size: 2048,
      },
    });
    expect(uploadResponse.status()).toBe(201);
    const uploadBody = await uploadResponse.json();
    const secondFileId = uploadBody.fileId;

    // Update note with both images
    const response = await request.put(`/api/v1/notes/${noteId}`, {
      data: {
        images: [`file:${fileId}`, `file:${secondFileId}`],
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    // images should be objects with id and url, containing signed URLs
    expect(body.images).toHaveLength(2);
    expect(body.images[0]).toHaveProperty("id");
    expect(body.images[0]).toHaveProperty("url");
    expect(body.images[0].url).toContain("mock-s3.example.com");
    expect(body.images[1]).toHaveProperty("id");
    expect(body.images[1]).toHaveProperty("url");
    expect(body.images[1].url).toContain("mock-s3.example.com");
  });

  test("PUT /api/v1/notes/{id} - should handle removing file IDs", async ({
    request,
  }) => {
    // Update note to keep only the first image
    const response = await request.put(`/api/v1/notes/${noteId}`, {
      data: {
        images: [`file:${fileId}`],
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.images).toHaveLength(1);
  });

  test("POST /api/v1/notes - should reject invalid file IDs", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/notes", {
      data: {
        title: "Note with Invalid File ID",
        visibility: "public",
        images: ["file:999999"], // Non-existent file ID
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body).toHaveProperty("error");
    expect(body.error).toContain("Invalid");
  });

  test("DELETE /api/v1/notes/{id} - should delete associated files", async ({
    request,
  }) => {
    // Delete the note
    const response = await request.delete(`/api/v1/notes/${noteId}`);
    expect(response.status()).toBe(204);

    // Verify note is deleted
    const getResponse = await request.get(`/api/v1/notes/${noteId}`);
    expect(getResponse.status()).toBe(404);

    // File should also be deleted (attempting to use it should fail)
    const createResponse = await request.post("/api/v1/notes", {
      data: {
        title: "Note with Deleted File",
        visibility: "public",
        images: [`file:${fileId}`],
      },
    });
    expect(createResponse.status()).toBe(400);
  });
});
