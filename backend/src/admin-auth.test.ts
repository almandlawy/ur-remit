import { describe, expect, it } from "vitest";
import { hashPassword, verifyPassword } from "./admin-auth.js";

describe("admin authentication primitives", () => {
  it("hashes passwords with scrypt and rejects a different password", async () => {
    const hash = await hashPassword("a-long-and-unique-password");
    expect(await verifyPassword("a-long-and-unique-password", hash)).toBe(true);
    expect(await verifyPassword("wrong-password", hash)).toBe(false);
  });
});
