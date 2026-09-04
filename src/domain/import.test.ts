import { describe, expect, it } from "vitest";
import { buildForecast } from "./forecast";
import { exportPayload, parseImportText } from "./import";

const legacy = {
  version: 3,
  settings: { startBalance: 1234.56, startDate: "2026-01-01" },
  events: [
    {
      id: "rent",
      name: "Rent",
      amount: 500.25,
      date: "2026-01-31",
      type: "expense",
      certainty: "certain",
      recurrence: "monthly",
      repeatUntil: "2026-03-31",
      note: "legacy",
    },
  ],
  scenarios: [
    {
      id: "high",
      name: "Higher",
      overrides: {
        rent: {
          enabled: {
            amount: true,
            recurrence: false,
            date: false,
            repeatUntil: false,
            certainty: false,
          },
          amount: 700.5,
          disabled: false,
        },
      },
    },
  ],
};

describe("legacy import", () => {
  it("previews and converts decimals into integer minor units", () => {
    const result = parseImportText(JSON.stringify(legacy), "2026-01-01");
    expect(result.source).toBe("Cash Flow Planner");
    expect(result.operationCount).toBe(1);
    expect(result.state.settings.startBalanceMinor).toBe(123_456);
    expect(result.state.operations[0].amountMinor).toBe(50_025);
    expect(result.state.scenarios[0].overrides.rent.amountMinor).toBe(70_050);
    const forecast = buildForecast(
      result.state.settings.startBalanceMinor,
      result.state.settings.startDate,
      result.state.operations,
    );
    expect(forecast.endingBalanceMinor).toBe(-26_619);
    expect(forecast.firstNegativeDate).toBe("2026-03-31");
  });

  it("is idempotent because confirmation replaces the plan", () => {
    const first = parseImportText(JSON.stringify(legacy), "2026-01-01");
    const second = parseImportText(JSON.stringify(legacy), "2026-01-01");
    expect(second.state.operations.map((item) => item.id)).toEqual(
      first.state.operations.map((item) => item.id),
    );
  });

  it("supplies the legacy default end date when a recurring series omitted it", () => {
    const missingEnd = structuredClone(legacy);
    delete (missingEnd.events[0] as { repeatUntil?: string }).repeatUntil;
    const result = parseImportText(JSON.stringify(missingEnd), "2026-01-01");
    expect(result.state.operations[0].recurrenceEndDate).toBe("2026-02-28");
  });

  it("round-trips the current format", () => {
    const original = parseImportText(
      JSON.stringify(legacy),
      "2026-01-01",
    ).state;
    expect(
      parseImportText(exportPayload(original), "2026-01-01").state.operations,
    ).toEqual(original.operations);
  });

  it("rejects corrupt imports before changing state", () => {
    expect(() => parseImportText("{}")).toThrow(/Не найден экспорт/);
    expect(() => parseImportText("not json")).toThrow(/корректным JSON/);
  });

  it("recovers from an unsupported far-future start date", () => {
    const farFuture = structuredClone(legacy);
    farFuture.settings.startDate = "9999-12-31";
    expect(
      parseImportText(JSON.stringify(farFuture), "2026-01-01").state.settings
        .startDate,
    ).toBe("2026-01-01");
  });
});
