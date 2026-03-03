import { expect, test } from "@playwright/test";

test.describe.serial("Business Card Notes API", () => {
  const TEST_USER = `business-card-user-${crypto.randomUUID()}`;
  let noteId: number;

  test("POST /api/v1/notes creates business-card note with add-contact action", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/notes", {
      headers: { "X-Test-User-Id": TEST_USER },
      data: {
        title: "John Doe Card",
        type: "business-card",
        note: "Optional body",
        businessCard: {
          firstName: "John",
          lastName: "Doe",
          email: "john@example.com",
          company: "Acme Inc",
        },
        actions: [
          {
            type: "add-contact",
            firstName: "Jane",
            lastName: "Smith",
            email: "jane@example.com",
          },
        ],
        visibility: "public",
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();

    expect(body.type).toBe("business-card");
    expect(body.businessCard.firstName).toBe("John");
    expect(body.businessCard.lastName).toBe("Doe");
    expect(body.actions).toHaveLength(1);
    expect(body.actions[0].type).toBe("add-contact");
    expect(body.actions[0].firstName).toBe("Jane");
    expect(body.actions[0].lastName).toBe("Smith");

    noteId = body.id;
  });

  test("GET /api/v1/notes/{id} returns businessCard and add-contact action", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/notes/${noteId}`, {
      headers: { "X-Test-User-Id": TEST_USER },
    });
    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body.type).toBe("business-card");
    expect(body.businessCard.firstName).toBe("John");
    expect(body.actions[0].type).toBe("add-contact");
  });

  test("PUT /api/v1/notes/{id} switching to regular-text-note clears businessCard", async ({
    request,
  }) => {
    const response = await request.put(`/api/v1/notes/${noteId}`, {
      headers: { "X-Test-User-Id": TEST_USER },
      data: {
        type: "regular-text-note",
      },
    });
    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body.type).toBe("regular-text-note");
    expect(body.businessCard).toBeNull();
  });

  test("POST /api/v1/notes rejects invalid business-card without required names", async ({
    request,
  }) => {
    const response = await request.post("/api/v1/notes", {
      headers: { "X-Test-User-Id": TEST_USER },
      data: {
        title: "Invalid Card",
        type: "business-card",
        businessCard: {
          firstName: "",
          lastName: "Doe",
        },
        visibility: "public",
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContain("firstName");
  });

  test("Cleanup deletes created note", async ({ request }) => {
    const response = await request.delete(`/api/v1/notes/${noteId}`, {
      headers: { "X-Test-User-Id": TEST_USER },
    });
    expect(response.status()).toBe(204);
  });
});
