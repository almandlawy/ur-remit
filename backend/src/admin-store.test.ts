import { describe, expect, it } from "vitest";
import { rateUpdateRpcArguments } from "./admin-store.js";

describe("rateUpdateRpcArguments", () => {
  it("distinguishes omitted fields from explicit nulls in partial updates", () => {
    expect(rateUpdateRpcArguments({
      sell: "1550.25",
      feeFixed: null,
      validFrom: "2026-09-01T00:00:00Z",
      validUntil: null,
      active: false,
    })).toEqual([
      null, "1550.25", null, null,
      false, true, true, false,
      "2026-09-01T00:00:00Z", null, true, false,
    ]);
  });

  it("marks supplied fee percentages for update while preserving omitted fee percentages", () => {
    expect(rateUpdateRpcArguments({ buy: "1500", feePercent: "1.5" })).toEqual([
      "1500", null, null, "1.5",
      true, false, false, true,
      null, null, false, true,
    ]);
  });
});
