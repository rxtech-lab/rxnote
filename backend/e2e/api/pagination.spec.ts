import { test, expect } from "@playwright/test";

/**
 * E2E tests for cursor-based pagination on the Notes API endpoint.
 *
 * Test coverage:
 * - Basic pagination with limit parameter
 * - Next/prev navigation with cursor
 * - Boundary conditions (first/last page)
 * - Empty results
 * - Invalid cursor handling
 * - Backward compatibility (no pagination params)
 */

test.describe.serial("Notes Pagination API", () => {
  const createdNoteIds: number[] = [];
  const PAGE_SIZE = 5;

  test.beforeAll(async ({ request }) => {
    // Create 12 notes for pagination testing
    for (let i = 1; i <= 12; i++) {
      const response = await request.post("/api/v1/notes", {
        data: {
          title: `Pagination Test Note ${i.toString().padStart(2, "0")}`,
          note: `Note ${i} for pagination testing`,
          visibility: "private",
        },
      });
      expect(response.status()).toBe(201);
      const body = await response.json();
      createdNoteIds.push(body.id);
    }
  });

  test.afterAll(async ({ request }) => {
    // Cleanup: delete all created notes
    for (const id of createdNoteIds) {
      await request.delete(`/api/v1/notes/${id}`);
    }
  });

  test("GET /api/v1/notes?limit=5 - returns paginated response with correct structure", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/notes?limit=${PAGE_SIZE}`);
    expect(response.status()).toBe(200);

    const body = await response.json();

    // Should return paginated response structure
    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");
    expect(body.data).toBeInstanceOf(Array);
    expect(body.data.length).toBeLessThanOrEqual(PAGE_SIZE);
    expect(body.pagination).toHaveProperty("nextCursor");
    expect(body.pagination).toHaveProperty("prevCursor");
    expect(body.pagination).toHaveProperty("hasNextPage");
    expect(body.pagination).toHaveProperty("hasPrevPage");
  });

  test("GET /api/v1/notes?limit=5 - first page has hasPrevPage=false", async ({
    request,
  }) => {
    const response = await request.get(`/api/v1/notes?limit=${PAGE_SIZE}`);
    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body.pagination.hasPrevPage).toBe(false);
    expect(body.pagination.prevCursor).toBeNull();
  });

  test("GET /api/v1/notes - navigates to next page correctly", async ({
    request,
  }) => {
    // Get first page
    const firstResponse = await request.get(`/api/v1/notes?limit=${PAGE_SIZE}`);
    expect(firstResponse.status()).toBe(200);
    const firstPage = await firstResponse.json();

    if (!firstPage.pagination.hasNextPage) {
      test.skip();
      return;
    }

    // Get second page using cursor
    const nextCursor = firstPage.pagination.nextCursor;
    const secondResponse = await request.get(
      `/api/v1/notes?limit=${PAGE_SIZE}&cursor=${nextCursor}&direction=next`
    );
    expect(secondResponse.status()).toBe(200);
    const secondPage = await secondResponse.json();

    // Second page should have different notes
    const firstPageIds = firstPage.data.map((note: { id: number }) => note.id);
    const secondPageIds = secondPage.data.map((note: { id: number }) => note.id);

    // No overlap between pages
    const overlap = firstPageIds.filter((id: number) =>
      secondPageIds.includes(id)
    );
    expect(overlap.length).toBe(0);

    // Second page should have hasPrevPage=true
    expect(secondPage.pagination.hasPrevPage).toBe(true);
    expect(secondPage.pagination.prevCursor).not.toBeNull();
  });

  test("GET /api/v1/notes - navigates back to previous page correctly", async ({
    request,
  }) => {
    // Get first page
    const firstResponse = await request.get(`/api/v1/notes?limit=${PAGE_SIZE}`);
    const firstPage = await firstResponse.json();

    if (!firstPage.pagination.hasNextPage) {
      test.skip();
      return;
    }

    // Get second page
    const secondResponse = await request.get(
      `/api/v1/notes?limit=${PAGE_SIZE}&cursor=${firstPage.pagination.nextCursor}&direction=next`
    );
    const secondPage = await secondResponse.json();

    // Go back to first page
    const backResponse = await request.get(
      `/api/v1/notes?limit=${PAGE_SIZE}&cursor=${secondPage.pagination.prevCursor}&direction=prev`
    );
    expect(backResponse.status()).toBe(200);
    const backPage = await backResponse.json();

    // Should have same notes as first page
    const firstPageIds = firstPage.data.map((note: { id: number }) => note.id);
    const backPageIds = backPage.data.map((note: { id: number }) => note.id);

    expect(backPageIds.sort()).toEqual(firstPageIds.sort());
  });

  test("GET /api/v1/notes - without params returns paginated response with all notes", async ({
    request,
  }) => {
    const response = await request.get("/api/v1/notes");
    expect(response.status()).toBe(200);

    const body = await response.json();

    // Should return paginated object format
    expect(body.data).toBeInstanceOf(Array);
    expect(body.pagination).toBeDefined();
    expect(body.data.length).toBeGreaterThan(0);
  });

  test("GET /api/v1/notes - handles invalid cursor gracefully", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/notes?limit=${PAGE_SIZE}&cursor=invalid_cursor_value`
    );
    expect(response.status()).toBe(200);

    const body = await response.json();

    // Should return valid response (treated as first page)
    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");
  });

  test("GET /api/v1/notes - pagination with search filter works correctly", async ({
    request,
  }) => {
    const response = await request.get(
      `/api/v1/notes?limit=${PAGE_SIZE}&search=Pagination`
    );
    expect(response.status()).toBe(200);

    const body = await response.json();

    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");

    // All returned notes should match the search
    for (const note of body.data) {
      const matchesSearch =
        note.title.includes("Pagination") ||
        (note.note && note.note.includes("Pagination"));
      expect(matchesSearch).toBe(true);
    }
  });
});

test.describe("Pagination Edge Cases", () => {
  test("Empty results return correct pagination structure", async ({
    request,
  }) => {
    // Search for something that doesn't exist
    const response = await request.get(
      "/api/v1/notes?limit=10&search=ThisDoesNotExist12345XYZ"
    );
    expect(response.status()).toBe(200);

    const body = await response.json();

    expect(body).toHaveProperty("data");
    expect(body).toHaveProperty("pagination");
    expect(body.data).toEqual([]);
    expect(body.pagination.nextCursor).toBeNull();
    expect(body.pagination.prevCursor).toBeNull();
    expect(body.pagination.hasNextPage).toBe(false);
    expect(body.pagination.hasPrevPage).toBe(false);
  });

  test("Cursor stability - same cursor returns same results", async ({
    request,
  }) => {
    // Get first page
    const firstResponse = await request.get("/api/v1/notes?limit=5");
    const firstPage = await firstResponse.json();

    if (!firstPage.pagination.nextCursor) {
      test.skip();
      return;
    }

    // Get second page twice with same cursor
    const cursor = firstPage.pagination.nextCursor;

    const secondResponse1 = await request.get(
      `/api/v1/notes?limit=5&cursor=${cursor}&direction=next`
    );
    const secondPage1 = await secondResponse1.json();

    const secondResponse2 = await request.get(
      `/api/v1/notes?limit=5&cursor=${cursor}&direction=next`
    );
    const secondPage2 = await secondResponse2.json();

    // Both responses should have same notes
    const ids1 = secondPage1.data.map((note: { id: number }) => note.id);
    const ids2 = secondPage2.data.map((note: { id: number }) => note.id);

    expect(ids1).toEqual(ids2);
  });
});
