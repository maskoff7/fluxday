import { describe, expect, it } from "vitest";
import { formatMoney, MAX_MONEY_MINOR, parseMoneyInput } from "./money";

describe("money boundaries", () => {
  it("parses cents exactly without floating-point rounding", () => {
    expect(parseMoneyInput("12 345,67")).toBe(1_234_567);
    expect(parseMoneyInput("0.10")).toBe(10);
  });

  it("accepts a very large personal amount and rejects unsafe input", () => {
    expect(parseMoneyInput("100000000")).toBe(MAX_MONEY_MINOR);
    expect(parseMoneyInput("100000000.01")).toBeNull();
    expect(formatMoney(MAX_MONEY_MINOR)).toContain("100");
  });
});
