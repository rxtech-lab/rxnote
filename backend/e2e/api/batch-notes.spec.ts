import { test, expect } from "@playwright/test";

/**
 * Batch fetch notes endpoint tests.
 * Tests POST /api/v1/notes/batch for fetching multiple notes by IDs.
 */
test.describe.serial("Batch Fetch Notes", () => {
  const USER_1 = `batch-user-1-${crypto.randomUUID()}`;
  const USER_1_EMAIL = `batch-u1-${crypto.randomUUID()}@example.com`;
  const USER_2 = `batch-user-2-${crypto.randomUUID()}`;
  const USER_2_EMAIL = `batch-u2-${crypto.randomUUID()}@example.com`;

  let publicNoteId: string;
  let privateNoteId: string;
  let authOnlyNoteId: string;
  let user2PrivateNoteId: string;

  test.describe("Setup - Create test notes", () => {
    test("User 1 creates notes with different visibilities", async ({ request }) => {
      const publicRes = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_1, "X-Test-User-Email": USER_1_EMAIL },
        data: {
          title: "Batch Public Note",
          note: "Public note for batch test",
          visibility: "public",
        },
      });
      expect(publicRes.status()).toBe(201);
      publicNoteId = (await publicRes.json()).id;

      const privateRes = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_1, "X-Test-User-Email": USER_1_EMAIL },
        data: {
          title: "Batch Private Note",
          note: "Private note for batch test",
          visibility: "private",
        },
      });
      expect(privateRes.status()).toBe(201);
      privateNoteId = (await privateRes.json()).id;

      const authOnlyRes = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_1, "X-Test-User-Email": USER_1_EMAIL },
        data: {
          title: "Batch Auth-Only Note",
          note: "Auth-only note for batch test",
          visibility: "auth-only",
        },
      });
      expect(authOnlyRes.status()).toBe(201);
      authOnlyNoteId = (await authOnlyRes.json()).id;
    });

    test("User 2 creates a private note", async ({ request }) => {
      const res = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_2, "X-Test-User-Email": USER_2_EMAIL },
        data: {
          title: "User 2 Private Note",
          note: "Private note owned by user 2",
          visibility: "private",
        },
      });
      expect(res.status()).toBe(201);
      user2PrivateNoteId = (await res.json()).id;
    });
  });

  test.describe("Batch fetch functionality", () => {
    test("should return all accessible notes for the owner", async ({ request }) => {
      const response = await request.post("/api/v1/notes/batch", {
        headers: { "X-Test-User-Id": USER_1, "X-Test-User-Email": USER_1_EMAIL },
        data: { ids: [publicNoteId, privateNoteId, authOnlyNoteId] },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.data).toHaveLength(3);
      const returnedIds = body.data.map((n: any) => n.id);
      expect(returnedIds).toContain(publicNoteId);
      expect(returnedIds).toContain(privateNoteId);
      expect(returnedIds).toContain(authOnlyNoteId);
    });

    test("should return only accessible notes for a different user", async ({ request }) => {
      const response = await request.post("/api/v1/notes/batch", {
        headers: { "X-Test-User-Id": USER_2, "X-Test-User-Email": USER_2_EMAIL },
        data: { ids: [publicNoteId, privateNoteId, authOnlyNoteId] },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      // User 2 should see public + auth-only, but NOT private
      const returnedIds = body.data.map((n: any) => n.id);
      expect(returnedIds).toContain(publicNoteId);
      expect(returnedIds).toContain(authOnlyNoteId);
      expect(returnedIds).not.toContain(privateNoteId);
    });

    test("should skip non-existent note IDs gracefully", async ({ request }) => {
      const response = await request.post("/api/v1/notes/batch", {
        headers: { "X-Test-User-Id": USER_1, "X-Test-User-Email": USER_1_EMAIL },
        data: { ids: [publicNoteId, "nonexistent-id-12345"] },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.data).toHaveLength(1);
      expect(body.data[0].id).toBe(publicNoteId);
    });

    test("should return empty data for all non-existent IDs", async ({ request }) => {
      const response = await request.post("/api/v1/notes/batch", {
        headers: { "X-Test-User-Id": USER_1, "X-Test-User-Email": USER_1_EMAIL },
        data: { ids: ["nonexistent-1", "nonexistent-2"] },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.data).toHaveLength(0);
    });

    test("should include proper note fields in response", async ({ request }) => {
      const response = await request.post("/api/v1/notes/batch", {
        headers: { "X-Test-User-Id": USER_1, "X-Test-User-Email": USER_1_EMAIL },
        data: { ids: [publicNoteId] },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.data).toHaveLength(1);
      const note = body.data[0];
      expect(note.id).toBe(publicNoteId);
      expect(note.title).toBe("Batch Public Note");
      expect(note.visibility).toBe("public");
      expect(note.previewUrl).toBeDefined();
      expect(note.createdAt).toBeDefined();
      expect(note.updatedAt).toBeDefined();
    });

    test("User 1 cannot see User 2 private note via batch", async ({ request }) => {
      const response = await request.post("/api/v1/notes/batch", {
        headers: { "X-Test-User-Id": USER_1, "X-Test-User-Email": USER_1_EMAIL },
        data: { ids: [user2PrivateNoteId, publicNoteId] },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const returnedIds = body.data.map((n: any) => n.id);
      expect(returnedIds).toContain(publicNoteId);
      expect(returnedIds).not.toContain(user2PrivateNoteId);
    });
  });

  test.describe("Validation", () => {
    test("should return 400 for empty ids array", async ({ request }) => {
      const response = await request.post("/api/v1/notes/batch", {
        headers: { "X-Test-User-Id": USER_1 },
        data: { ids: [] },
      });
      expect(response.status()).toBe(400);
    });

    test("should return 400 for missing ids field", async ({ request }) => {
      const response = await request.post("/api/v1/notes/batch", {
        headers: { "X-Test-User-Id": USER_1 },
        data: {},
      });
      expect(response.status()).toBe(400);
    });

    test("should return 400 for invalid body", async ({ request }) => {
      const response = await request.post("/api/v1/notes/batch", {
        headers: { "X-Test-User-Id": USER_1 },
        data: { ids: "not-an-array" },
      });
      expect(response.status()).toBe(400);
    });

    test("should return 400 when exceeding max 50 IDs", async ({ request }) => {
      const ids = Array.from({ length: 51 }, (_, i) => `id-${i}`);
      const response = await request.post("/api/v1/notes/batch", {
        headers: { "X-Test-User-Id": USER_1 },
        data: { ids },
      });
      expect(response.status()).toBe(400);
    });
  });

  test.describe("Cleanup - Delete test notes", () => {
    test("User 1 deletes their notes", async ({ request }) => {
      for (const id of [publicNoteId, privateNoteId, authOnlyNoteId]) {
        const response = await request.delete(`/api/v1/notes/${id}`, {
          headers: { "X-Test-User-Id": USER_1, "X-Test-User-Email": USER_1_EMAIL },
        });
        expect(response.status()).toBe(204);
      }
    });

    test("User 2 deletes their notes", async ({ request }) => {
      const response = await request.delete(`/api/v1/notes/${user2PrivateNoteId}`, {
        headers: { "X-Test-User-Id": USER_2, "X-Test-User-Email": USER_2_EMAIL },
      });
      expect(response.status()).toBe(204);
    });
  });
});
