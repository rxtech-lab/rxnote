import { test, expect } from "@playwright/test";

/**
 * Permission tests for multi-user scenarios.
 * Uses X-Test-User-Id header to simulate different users.
 */
test.describe.serial("Permission Tests", () => {
  // Use randomized user IDs to avoid conflicts with data from previous test runs
  const USER_1 = `test-user-1-${crypto.randomUUID()}`;
  const USER_2 = `test-user-2-${crypto.randomUUID()}`;

  let user1NoteId: string;

  test.describe("User 1 creates resources", () => {
    test("should create private note", async ({ request }) => {
      const response = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_1 },
        data: {
          title: "User1 Private Note",
          note: "Private note owned by user 1",
          visibility: "private",
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      user1NoteId = body.id;
    });
  });

  test.describe("User 2 cannot access User 1 private resources", () => {
    test("should not see User 1 private note in list", async ({ request }) => {
      const response = await request.get("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const user1Notes = body.data.filter((note: any) => note.id === user1NoteId);
      expect(user1Notes.length).toBe(0);
    });

    test("should get 403 when accessing User 1 private note by ID", async ({ request }) => {
      const response = await request.get(`/api/v1/notes/${user1NoteId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when trying to update User 1 note", async ({ request }) => {
      const response = await request.put(`/api/v1/notes/${user1NoteId}`, {
        headers: { "X-Test-User-Id": USER_2 },
        data: { title: "Hacked Note" },
      });
      expect(response.status()).toBe(403);
    });

    test("should get 403 when trying to delete User 1 note", async ({ request }) => {
      const response = await request.delete(`/api/v1/notes/${user1NoteId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });
  });

  test.describe("User 1 makes note public", () => {
    test("should update note to public", async ({ request }) => {
      const response = await request.put(`/api/v1/notes/${user1NoteId}`, {
        headers: { "X-Test-User-Id": USER_1 },
        data: { visibility: "public" },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.visibility).toBe("public");
    });
  });

  test.describe("User 2 can view but not modify public notes", () => {
    test("should NOT see User 1 public note in list (users only see their own notes)", async ({ request }) => {
      const response = await request.get("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      // List endpoint returns only user's own notes, not other users' public notes
      const user1Notes = body.data.filter((note: any) => note.id === user1NoteId);
      expect(user1Notes.length).toBe(0);
    });

    test("should access User 1 public note by ID (direct access still works)", async ({ request }) => {
      const response = await request.get(`/api/v1/notes/${user1NoteId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.id).toBe(user1NoteId);
      expect(body.visibility).toBe("public");
    });

    test("should still get 403 when trying to update public note", async ({ request }) => {
      const response = await request.put(`/api/v1/notes/${user1NoteId}`, {
        headers: { "X-Test-User-Id": USER_2 },
        data: { title: "Hacked Public Note" },
      });
      expect(response.status()).toBe(403);
    });

    test("should still get 403 when trying to delete public note", async ({ request }) => {
      const response = await request.delete(`/api/v1/notes/${user1NoteId}`, {
        headers: { "X-Test-User-Id": USER_2 },
      });
      expect(response.status()).toBe(403);
    });
  });

  test.describe("Cleanup - User 1 deletes resources", () => {
    test("should delete note", async ({ request }) => {
      const response = await request.delete(`/api/v1/notes/${user1NoteId}`, {
        headers: { "X-Test-User-Id": USER_1 },
      });
      expect(response.status()).toBe(204);
    });
  });
});

/**
 * Multi-user note isolation tests.
 * Verifies that users can only see their own notes in the list,
 * and public notes can be accessed directly by ID.
 */
test.describe.serial("Multi-User Note Isolation", () => {
  // Use randomized user IDs to avoid conflicts with data from previous test runs
  const USER_A = `isolation-user-a-${crypto.randomUUID()}`;
  const USER_A_EMAIL = `user-a-${crypto.randomUUID()}@example.com`;
  const USER_B = `isolation-user-b-${crypto.randomUUID()}`;
  const USER_B_EMAIL = `user-b-${crypto.randomUUID()}@example.com`;
  const USER_C = `isolation-user-c-${crypto.randomUUID()}`;
  const USER_C_EMAIL = `user-c-${crypto.randomUUID()}@example.com`;

  // Track created note IDs
  let userAPrivateNote1Id: string;
  let userAPrivateNote2Id: string;
  let userAPublicNoteId: string;
  let userBPrivateNoteId: string;
  let userBPublicNoteId: string;
  let userCPrivateNoteId: string;

  test.describe("Setup - Create notes for multiple users", () => {
    test("User A creates 2 private notes and 1 public note", async ({ request }) => {
      // Create private note 1
      const response1 = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
        data: {
          title: "User A Private Note 1",
          note: "First private note belonging to User A",
          visibility: "private",
        },
      });
      expect(response1.status()).toBe(201);
      userAPrivateNote1Id = (await response1.json()).id;

      // Create private note 2
      const response2 = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
        data: {
          title: "User A Private Note 2",
          note: "Second private note belonging to User A",
          visibility: "private",
        },
      });
      expect(response2.status()).toBe(201);
      userAPrivateNote2Id = (await response2.json()).id;

      // Create public note
      const response3 = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
        data: {
          title: "User A Public Note",
          note: "Public note belonging to User A",
          visibility: "public",
        },
      });
      expect(response3.status()).toBe(201);
      userAPublicNoteId = (await response3.json()).id;
    });

    test("User B creates 1 private note and 1 public note", async ({ request }) => {
      // Create private note
      const response1 = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
        data: {
          title: "User B Private Note",
          note: "Private note belonging to User B",
          visibility: "private",
        },
      });
      expect(response1.status()).toBe(201);
      userBPrivateNoteId = (await response1.json()).id;

      // Create public note
      const response2 = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
        data: {
          title: "User B Public Note",
          note: "Public note belonging to User B",
          visibility: "public",
        },
      });
      expect(response2.status()).toBe(201);
      userBPublicNoteId = (await response2.json()).id;
    });

    test("User C creates 1 private note", async ({ request }) => {
      const response = await request.post("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
        data: {
          title: "User C Private Note",
          note: "Private note belonging to User C",
          visibility: "private",
        },
      });
      expect(response.status()).toBe(201);
      userCPrivateNoteId = (await response.json()).id;
    });
  });

  test.describe("List isolation verification", () => {
    test("User A sees ONLY their own notes (not other users' public notes)", async ({ request }) => {
      const response = await request.get("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const noteTitles = body.data.map((note: any) => note.title);

      // User A should see their own notes (3 total)
      expect(noteTitles).toContain("User A Private Note 1");
      expect(noteTitles).toContain("User A Private Note 2");
      expect(noteTitles).toContain("User A Public Note");

      // User A should NOT see other users' notes (not even public ones)
      expect(noteTitles).not.toContain("User B Public Note");
      expect(noteTitles).not.toContain("User B Private Note");
      expect(noteTitles).not.toContain("User C Private Note");
    });

    test("User B sees ONLY their own notes (not other users' public notes)", async ({ request }) => {
      const response = await request.get("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const noteTitles = body.data.map((note: any) => note.title);

      // User B should see their own notes (2 total)
      expect(noteTitles).toContain("User B Private Note");
      expect(noteTitles).toContain("User B Public Note");

      // User B should NOT see other users' notes (not even public ones)
      expect(noteTitles).not.toContain("User A Public Note");
      expect(noteTitles).not.toContain("User A Private Note 1");
      expect(noteTitles).not.toContain("User A Private Note 2");
      expect(noteTitles).not.toContain("User C Private Note");
    });

    test("User C sees ONLY their own notes (not other users' public notes)", async ({ request }) => {
      const response = await request.get("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const noteTitles = body.data.map((note: any) => note.title);

      // User C should see their own note (1 total)
      expect(noteTitles).toContain("User C Private Note");

      // User C should NOT see other users' notes (not even public ones)
      expect(noteTitles).not.toContain("User A Public Note");
      expect(noteTitles).not.toContain("User B Public Note");
      expect(noteTitles).not.toContain("User A Private Note 1");
      expect(noteTitles).not.toContain("User A Private Note 2");
      expect(noteTitles).not.toContain("User B Private Note");
    });
  });

  test.describe("Direct access denial verification", () => {
    test("User B cannot access User A's private notes by ID", async ({ request }) => {
      const response1 = await request.get(`/api/v1/notes/${userAPrivateNote1Id}`, {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
      });
      expect(response1.status()).toBe(403);
      const body1 = await response1.json();
      expect(body1.error).toBe("Permission denied");

      const response2 = await request.get(`/api/v1/notes/${userAPrivateNote2Id}`, {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
      });
      expect(response2.status()).toBe(403);
    });

    test("User C cannot access User A's or User B's private notes", async ({ request }) => {
      const responseA1 = await request.get(`/api/v1/notes/${userAPrivateNote1Id}`, {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
      });
      expect(responseA1.status()).toBe(403);

      const responseA2 = await request.get(`/api/v1/notes/${userAPrivateNote2Id}`, {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
      });
      expect(responseA2.status()).toBe(403);

      const responseB = await request.get(`/api/v1/notes/${userBPrivateNoteId}`, {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
      });
      expect(responseB.status()).toBe(403);
    });

    test("User A cannot access User B's or User C's private notes", async ({ request }) => {
      const responseB = await request.get(`/api/v1/notes/${userBPrivateNoteId}`, {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
      });
      expect(responseB.status()).toBe(403);

      const responseC = await request.get(`/api/v1/notes/${userCPrivateNoteId}`, {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
      });
      expect(responseC.status()).toBe(403);
    });
  });

  test.describe("Ownership verification in list response", () => {
    test("All notes in User A's list belong to User A only", async ({ request }) => {
      const response = await request.get("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();

      // Filter to only our test notes by title prefix
      const testNotes = body.data.filter((note: any) =>
        note.title.startsWith("User A ")
      );

      // Verify each note has userId field and belongs to User A
      for (const note of testNotes) {
        expect(note.userId).toBeDefined();
        expect(note.userId).toBe(USER_A);
      }

      // Verify User B's notes are NOT in the list
      const userBNotes = body.data.filter((note: any) =>
        note.title.startsWith("User B ")
      );
      expect(userBNotes.length).toBe(0);
    });

    test("All notes in list always belong to requesting user", async ({ request }) => {
      const response = await request.get("/api/v1/notes", {
        headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();

      // All notes in the list should belong to User B
      for (const note of body.data) {
        expect(note.userId).toBe(USER_B);
      }
    });
  });

  test.describe("Visibility filter verification", () => {
    test("Filtering by visibility=private returns only own private notes", async ({ request }) => {
      const response = await request.get("/api/v1/notes?visibility=private", {
        headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      const noteTitles = body.data.map((note: any) => note.title);

      // Should see User A's private notes
      expect(noteTitles).toContain("User A Private Note 1");
      expect(noteTitles).toContain("User A Private Note 2");

      // Verify none of other users' private notes appear
      expect(noteTitles).not.toContain("User B Private Note");
      expect(noteTitles).not.toContain("User C Private Note");

      // All returned notes should be User A's private notes
      const userAPrivateNotes = body.data.filter((note: any) =>
        note.title.startsWith("User A Private")
      );
      expect(userAPrivateNotes.length).toBe(2);
    });
  });

  test.describe("Cleanup - Delete all test notes", () => {
    test("User A deletes their notes", async ({ request }) => {
      for (const id of [userAPrivateNote1Id, userAPrivateNote2Id, userAPublicNoteId]) {
        const response = await request.delete(`/api/v1/notes/${id}`, {
          headers: { "X-Test-User-Id": USER_A, "X-Test-User-Email": USER_A_EMAIL },
        });
        expect(response.status()).toBe(204);
      }
    });

    test("User B deletes their notes", async ({ request }) => {
      for (const id of [userBPrivateNoteId, userBPublicNoteId]) {
        const response = await request.delete(`/api/v1/notes/${id}`, {
          headers: { "X-Test-User-Id": USER_B, "X-Test-User-Email": USER_B_EMAIL },
        });
        expect(response.status()).toBe(204);
      }
    });

    test("User C deletes their note", async ({ request }) => {
      const response = await request.delete(`/api/v1/notes/${userCPrivateNoteId}`, {
        headers: { "X-Test-User-Id": USER_C, "X-Test-User-Email": USER_C_EMAIL },
      });
      expect(response.status()).toBe(204);
    });
  });
});
