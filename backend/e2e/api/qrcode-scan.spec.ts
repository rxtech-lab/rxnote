import { test, expect } from "@playwright/test";

/**
 * E2E tests for POST /api/v1/qrcode/scan endpoint
 * Tests QR code scanning with preview URLs,
 * including permission checks for public, private, and auth-only notes.
 */
test.describe.serial("QR Code Scan API", () => {
  const OWNER = "qr-owner-user";
  const OWNER_EMAIL = "qr-owner@example.com";
  const OTHER_USER = "qr-other-user";
  const OTHER_EMAIL = "qr-other@example.com";
  const WHITELISTED_USER = "qr-whitelisted-user";
  const WHITELISTED_EMAIL = "qr-whitelisted@example.com";

  let publicNoteId: string;
  let privateNoteId: string;
  let authOnlyNoteId: string;

  test.describe("Setup - Create test data", () => {
    test("should create public note", async ({ request }) => {
      const response = await request.post("/api/v1/notes", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          title: "QR Test Public Note",
          note: "A public note for QR code testing",
          visibility: "public",
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      publicNoteId = body.id;
      expect(body.visibility).toBe("public");
    });

    test("should create private note", async ({ request }) => {
      const response = await request.post("/api/v1/notes", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          title: "QR Test Private Note",
          note: "A private note for QR code testing",
          visibility: "private",
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      privateNoteId = body.id;
      expect(body.visibility).toBe("private");
    });

    test("should create auth-only note", async ({ request }) => {
      const response = await request.post("/api/v1/notes", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          title: "QR Test Auth-Only Note",
          note: "An auth-only note for QR code testing",
          visibility: "auth-only",
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      authOnlyNoteId = body.id;
      expect(body.visibility).toBe("auth-only");
    });
  });

  test.describe("Preview URL QR codes - Public notes", () => {
    test("should resolve preview URL for public note (any user)", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `preview/note/${publicNoteId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("note");
      expect(body.url).toContain(`/api/v1/notes/${publicNoteId}`);
    });

    test("should resolve full preview URL for public note", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `https://note.rxlab.app/preview/note/${publicNoteId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("note");
      expect(body.url).toContain(`/api/v1/notes/${publicNoteId}`);
    });

    test("should resolve preview URL with leading slash", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `/preview/note/${publicNoteId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("note");
      expect(body.url).toContain(`/api/v1/notes/${publicNoteId}`);
    });

    test("should resolve query param format for public note", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `preview/note?id=${publicNoteId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("note");
      expect(body.url).toContain(`/api/v1/notes/${publicNoteId}`);
    });

    test("should resolve full URL with query param format", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `https://note.rxlab.app/preview/note?id=${publicNoteId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("note");
      expect(body.url).toContain(`/api/v1/notes/${publicNoteId}`);
    });

    test("should resolve query param format with leading slash", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `/preview/note?id=${publicNoteId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("note");
      expect(body.url).toContain(`/api/v1/notes/${publicNoteId}`);
    });
  });

  test.describe("Preview URL QR codes - Private notes", () => {
    test("should resolve preview URL for private note as owner", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: `preview/note/${privateNoteId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("note");
      expect(body.url).toContain(`/api/v1/notes/${privateNoteId}`);
    });

    test("should return 403 for private note as other user", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `preview/note/${privateNoteId}`,
        },
      });
      expect(response.status()).toBe(403);

      const body = await response.json();
      expect(body.error).toBe("Permission denied");
    });
  });

  test.describe("Preview URL QR codes - Auth-only notes", () => {
    test("should resolve preview URL for auth-only note as any authenticated user", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OTHER_USER,
          "X-Test-User-Email": OTHER_EMAIL,
        },
        data: {
          qrcontent: `preview/note/${authOnlyNoteId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("note");
      expect(body.url).toContain(`/api/v1/notes/${authOnlyNoteId}`);
    });
  });

  test.describe("Preview URL QR codes - Whitelist access", () => {
    test("should add user to whitelist", async ({ request }) => {
      const response = await request.post(
        `/api/v1/notes/${privateNoteId}/whitelist`,
        {
          headers: {
            "X-Test-User-Id": OWNER,
            "X-Test-User-Email": OWNER_EMAIL,
          },
          data: {
            email: WHITELISTED_EMAIL,
          },
        },
      );
      expect(response.status()).toBe(201);
    });

    test("should resolve preview URL for private note as whitelisted user", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": WHITELISTED_USER,
          "X-Test-User-Email": WHITELISTED_EMAIL,
        },
        data: {
          qrcontent: `preview/note/${privateNoteId}`,
        },
      });
      expect(response.status()).toBe(200);

      const body = await response.json();
      expect(body.type).toBe("note");
      expect(body.url).toContain(`/api/v1/notes/${privateNoteId}`);
    });
  });

  test.describe("Invalid QR codes", () => {
    test("should return 400 for random string", async ({ request }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: "random-invalid-qr-code-xyz",
        },
      });
      expect(response.status()).toBe(400);

      const body = await response.json();
      expect(body.error).toBe("Invalid QR code");
    });

    test("should return 400 for empty string", async ({ request }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: "",
        },
      });
      expect(response.status()).toBe(400);

      const body = await response.json();
      expect(body.error).toBe("Invalid request body");
    });

    test("should return 400 for non-existent note ID in preview URL", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: "preview/note/nonexistent-id",
        },
      });
      expect(response.status()).toBe(400);

      const body = await response.json();
      expect(body.error).toBe("Invalid QR code");
    });

    test("should return 400 for non-existent note ID in query param format", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {
          qrcontent: "preview/note?id=nonexistent-id",
        },
      });
      expect(response.status()).toBe(400);

      const body = await response.json();
      expect(body.error).toBe("Invalid QR code");
    });

    test("should return 400 for missing qrcontent field", async ({
      request,
    }) => {
      const response = await request.post("/api/v1/qrcode/scan", {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
        data: {},
      });
      expect(response.status()).toBe(400);

      const body = await response.json();
      expect(body.error).toBe("Invalid request body");
    });
  });

  test.describe("Cleanup", () => {
    test("should delete auth-only note", async ({ request }) => {
      const response = await request.delete(
        `/api/v1/notes/${authOnlyNoteId}`,
        {
          headers: {
            "X-Test-User-Id": OWNER,
            "X-Test-User-Email": OWNER_EMAIL,
          },
        },
      );
      expect(response.status()).toBe(204);
    });

    test("should delete private note", async ({ request }) => {
      const response = await request.delete(`/api/v1/notes/${privateNoteId}`, {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
      });
      expect(response.status()).toBe(204);
    });

    test("should delete public note", async ({ request }) => {
      const response = await request.delete(`/api/v1/notes/${publicNoteId}`, {
        headers: {
          "X-Test-User-Id": OWNER,
          "X-Test-User-Email": OWNER_EMAIL,
        },
      });
      expect(response.status()).toBe(204);
    });
  });
});
