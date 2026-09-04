import { describe, expect, it } from "vitest";
import { buildForecast } from "./forecast";
import type { Operation } from "./types";

function operation(
  id: string,
  type: "income" | "expense",
  amountMinor: number,
  certainty: "certain" | "expected",
): Operation {
  return {
    id,
    name: id,
    type,
    amountMinor,
    certainty,
    firstDate: "2026-01-02",
    recurrence: "none",
    recurrenceEndDate: null,
    note: "",
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
    updatedAt: "2026-01-01T00:00:00Z",
  };
}

describe("cash-flow forecast", () => {
  it("uses the closing balance after every operation in a day", () => {
    const forecast = buildForecast(
      100_00,
      "2026-01-01",
      [
        operation("large expense", "expense", 200_00, "certain"),
        operation("income", "income", 150_00, "certain"),
      ],
      "2026-01-03",
    );
    expect(forecast.days[1].closingBalanceMinor).toBe(50_00);
    expect(forecast.firstNegativeDate).toBeNull();
  });

  it("removes only expected income in the explained stress test", () => {
    const forecast = buildForecast(
      20_00,
      "2026-01-01",
      [
        operation("expected salary", "income", 100_00, "expected"),
        operation("expected bill", "expense", 60_00, "expected"),
      ],
      "2026-01-03",
    );
    expect(forecast.endingBalanceMinor).toBe(60_00);
    expect(forecast.stressEndingBalanceMinor).toBe(-40_00);
    expect(forecast.stressFirstNegativeDate).toBe("2026-01-02");
    expect(forecast.minimumBalanceMinor).toBe(20_00);
  });
});
