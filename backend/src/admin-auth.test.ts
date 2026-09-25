import { describe, expect, it } from "vitest";
import { decryptMFASecret, encryptMFASecret, hashPassword, verifyPassword, verifyTOTP } from "./admin-auth.js";

describe("admin authentication primitives", () => {
  it("hashes passwords with scrypt and rejects a different password", async () => {
    const hash = await hashPassword("a-long-and-unique-password");
    expect(await verifyPassword("a-long-and-unique-password", hash)).toBe(true);
    expect(await verifyPassword("wrong-password", hash)).toBe(false);
  });

  it("encrypts MFA secrets with authenticated encryption", () => {
    const key = Buffer.alloc(32, 7).toString("base64");
    const encrypted = encryptMFASecret("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", key);
    expect(encrypted.toString("utf8")).not.toContain("GEZD");
    expect(decryptMFASecret(encrypted, key)).toBe("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ");
  });

  it("verifies RFC-compatible six digit TOTP codes", () => {
    expect(verifyTOTP("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", "287082", 59_000)).toBe(true);
    expect(verifyTOTP("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", "000000", 59_000)).toBe(false);
  });
});
