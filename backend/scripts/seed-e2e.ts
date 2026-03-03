import { db } from "../lib/db";
import { notes } from "../lib/db/schema/notes";

async function seed() {
  console.log("Seeding test data...");

  const now = new Date();
  const seededNotes = await db
    .insert(notes)
    .values([
      {
        id: "seed-public",
        userId: "test-user-id", // default test user
        title: "Public Test Note",
        note: "This is a public test note for E2E testing",
        visibility: "public",
        createdAt: now,
        updatedAt: now,
      },
      {
        id: "seed-private",
        userId: "b8da73c7-eb56-46a2-a20a-385d298dfa97", // different user for access control testing
        title: "Private Test Note",
        note: "This is a private test note for E2E testing",
        visibility: "private",
        createdAt: now,
        updatedAt: now,
      },
      {
        id: "seed-other-user",
        userId: "different-id", // different user for access control testing
        title: "Another User's Note",
        note: "This note belongs to another user",
        visibility: "private",
        createdAt: now,
        updatedAt: now,
      },
    ])
    .returning();

  console.log("========================================");
  console.log("Database seeded successfully!");
  console.log("========================================");
  console.log("Seeded notes:");
  seededNotes.forEach((note) => {
    console.log(`  - ID ${note.id}: "${note.title}" (${note.visibility})`);
  });
  console.log("========================================");
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Seed failed:", error);
    process.exit(1);
  });
