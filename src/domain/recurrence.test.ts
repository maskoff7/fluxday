import { describe, expect, it } from "vitest";
import type { Operation } from "./types";
import { occurrenceDates } from "./recurrence";

function operation(input: Partial<Operation> = {}): Operation {
  return {
    id: "rent",
    name: "Rent",
    type: "expense",
    amountMinor: 100_00,
    certainty: "certain",
    firstDate: "2025-01-31",
    recurrence: "monthly",
    recurrenceEndDate: "2025-05-31",
    note: "",
    enabled: true,
    createdAt: "2025-01-01T00:00:00Z",
    updatedAt: "2025-01-01T00:00:00Z",
    ...input,
  };
}

describe("recurrence expansion", () => {
  it("anchors 30/31 monthly dates instead of drifting", () => {
    expect(occurrenceDates(operation(), "2025-01-01", "2025-05-31")).toEqual([
      "2025-01-31",
      "2025-02-28",
      "2025-03-31",
      "2025-04-30",
      "2025-05-31",
    ]);
  });

  it("jumps to an old daily anchor without truncating the visible range", () => {
    const item = operation({
      firstDate: "1900-01-01",
      recurrence: "daily",
      recurrenceEndDate: "2026-01-03",
    });
    expect(occurrenceDates(item, "2026-01-01", "2026-01-03")).toEqual([
      "2026-01-01",
      "2026-01-02",
      "2026-01-03",
    ]);
  });

  it("maps leap-day yearly recurrence to valid dates", () => {
    expect(
      occurrenceDates(
        operation({
          firstDate: "2024-02-29",
          recurrence: "yearly",
          recurrenceEndDate: "2028-02-29",
        }),
        "2024-01-01",
        "2028-12-31",
      ),
    ).toEqual([
      "2024-02-29",
      "2025-02-28",
      "2026-02-28",
      "2027-02-28",
      "2028-02-29",
    ]);
  });

  it("supports a long daily series", () => {
    const dates = occurrenceDates(
      operation({
        firstDate: "2020-01-01",
        recurrence: "daily",
        recurrenceEndDate: "2029-12-31",
      }),
      "2020-01-01",
      "2029-12-31",
    );
    expect(dates).toHaveLength(3653);
    expect(dates.at(-1)).toBe("2029-12-31");
  });
});
