import { randomBytes, scrypt as nodeScrypt, timingSafeEqual } from "node:crypto";
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
