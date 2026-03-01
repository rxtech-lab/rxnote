import { test, expect } from "@playwright/test";

test.describe.serial("Account Deletion API", () => {
  // Use a unique user ID to avoid interfering with other tests
  const TEST_USER_ID = `deletion-test-user-${crypto.randomUUID()}`;
  const headers = { "X-Test-User-Id": TEST_USER_ID };

  // First create some data to delete
  let createdNoteId: number;

  test("Setup: Create test data", async ({ request }) => {
    // Create a note
    const noteResponse = await request.post("/api/v1/notes", {
      headers,
      data: {
        title: "Deletion Test Note",
        note: "Will be deleted",
        visibility: "private",
      },
    });
    expect(noteResponse.status()).toBe(201);
    const note = await noteResponse.json();
    createdNoteId = note.id;
  });

  test("GET /api/v1/account/delete - should return no pending deletion", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/account/delete", { headers });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.pending).toBe(false);
    expect(body.deletion).toBeNull();
  });

  test("POST /api/v1/account/delete - should request account deletion", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/account/delete", { headers });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.message).toContain("Account deletion scheduled");
    expect(body.deletion).toBeDefined();
    expect(body.deletion.status).toBe("pending");
    expect(body.deletion.userId).toBeDefined();
    expect(body.deletion.scheduledAt).toBeDefined();
  });

  test("POST /api/v1/account/delete - should reject duplicate deletion request", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/account/delete", { headers });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContain("already requested");
  });

  test("GET /api/v1/account/delete - should return pending deletion", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/account/delete", { headers });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.pending).toBe(true);
    expect(body.deletion).toBeDefined();
    expect(body.deletion.status).toBe("pending");
  });

  test("DELETE /api/v1/account/delete - should cancel deletion", async ({
    request,
  }) => {
    const response = await request.delete("/api/v1/account/delete", {
      headers,
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.message).toContain("cancelled");
  });

  test("GET /api/v1/account/delete - should return no pending after cancellation", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/account/delete", { headers });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.pending).toBe(false);
  });

  test("DELETE /api/v1/account/delete - should fail when no pending deletion", async ({
    request,
  }) => {
    const response = await request.delete("/api/v1/account/delete", {
      headers,
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContain("No pending account deletion");
  });

  test("Full flow: Request and execute deletion", async ({ request }) => {
    // Request deletion again
    const requestResponse = await request.post("/api/v1/account/delete", {
      headers,
    });
    expect(requestResponse.status()).toBe(201);

    // Execute the deletion via callback (simulating QStash)
    const callbackResponse = await request.post(
      "/api/v1/account/delete/callback",
      {
        data: { userId: TEST_USER_ID },
      }
    );
    expect(callbackResponse.status()).toBe(200);
    const callbackBody = await callbackResponse.json();
    expect(callbackBody.message).toContain("Account deleted");

    // Verify all data was deleted
    const notesResponse = await request.get("/api/v1/notes", { headers });
    expect(notesResponse.status()).toBe(200);
    const notesBody = await notesResponse.json();
    expect(notesBody.data).toEqual([]);
  });
});
