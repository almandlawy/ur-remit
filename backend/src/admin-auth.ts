import { createCipheriv, createDecipheriv, createHmac, randomBytes, scrypt as nodeScrypt, timingSafeEqual } from "node:crypto";
function scrypt(password: string, salt: Buffer, length: number, options: { N: number; r: number; p: number; maxmem: number }): Promise<Buffer> {
  return new Promise((resolve, reject) => nodeScrypt(password, salt, length, options, (error, result) =>
    error ? reject(error) : resolve(result as Buffer)));
}

export async function verifyPassword(password: string, encoded: string): Promise<boolean> {
  const [algorithm, costText, blockText, parallelText, saltText, expectedText] = encoded.split("$");
  if (algorithm !== "scrypt" || !costText || !blockText || !parallelText || !saltText || !expectedText) return false;
  const cost = Number(costText); const blockSize = Number(blockText); const parallelization = Number(parallelText);
  if (cost !== 32768 || blockSize !== 8 || parallelization !== 1) return false;
  const expected = Buffer.from(expectedText, "base64url");
  const actual = await scrypt(password, Buffer.from(saltText, "base64url"), expected.length,
    { N: cost, r: blockSize, p: parallelization, maxmem: 64 * 1024 * 1024 });
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16); const cost = 32768; const blockSize = 8; const parallelization = 1;
  const derived = await scrypt(password, salt, 32,
    { N: cost, r: blockSize, p: parallelization, maxmem: 64 * 1024 * 1024 });
  return `scrypt$${cost}$${blockSize}$${parallelization}$${salt.toString("base64url")}$${derived.toString("base64url")}`;
}

function decodeBase32(value: string): Buffer {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"; let bits = "";
  for (const character of value.replace(/=+$/g, "").toUpperCase()) {
    const index = alphabet.indexOf(character); if (index < 0) throw new Error("Invalid base32");
    bits += index.toString(2).padStart(5, "0");
  }
  const bytes: number[] = [];
  for (let index = 0; index + 8 <= bits.length; index += 8) bytes.push(Number.parseInt(bits.slice(index, index + 8), 2));
  return Buffer.from(bytes);
}

export function verifyTOTP(secret: string, code: string, now = Date.now()): boolean {
  if (!/^\d{6}$/.test(code)) return false;
  const key = decodeBase32(secret);
  for (const offset of [-1, 0, 1]) {
    const counter = Math.floor(now / 30_000) + offset;
    const message = Buffer.alloc(8); message.writeBigUInt64BE(BigInt(counter));
    const digest = createHmac("sha1", key).update(message).digest(); const position = digest[digest.length - 1]! & 0x0f;
    const binary = ((digest[position]! & 0x7f) << 24) | ((digest[position + 1]! & 0xff) << 16)
      | ((digest[position + 2]! & 0xff) << 8) | (digest[position + 3]! & 0xff);
    const expected = String(binary % 1_000_000).padStart(6, "0");
    if (timingSafeEqual(Buffer.from(expected), Buffer.from(code))) return true;
  }
  return false;
}

export function decryptMFASecret(payload: Buffer, base64Key: string): string {
  const key = Buffer.from(base64Key, "base64"); if (key.length !== 32 || payload.length < 29) throw new Error("Invalid MFA key material");
  const iv = payload.subarray(0, 12); const tag = payload.subarray(12, 28); const ciphertext = payload.subarray(28);
  const decipher = createDecipheriv("aes-256-gcm", key, iv); decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString("utf8");
}

export function encryptMFASecret(secret: string, base64Key: string): Buffer {
  const key = Buffer.from(base64Key, "base64"); if (key.length !== 32) throw new Error("Invalid MFA key material");
  const iv = randomBytes(12); const cipher = createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([cipher.update(secret, "utf8"), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]);
}
