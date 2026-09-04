import { expect, it } from "vitest";
import { applyScenario } from "./scenario";
import type { Operation, Scenario } from "./types";

it("applies sparse recurring overrides without mutating the base plan", () => {
  const base: Operation[] = [
    {
      id: "rent",
      name: "Rent",
      type: "expense",
      amountMinor: 50_000_00,
      certainty: "certain",
      firstDate: "2026-01-10",
      recurrence: "monthly",
      recurrenceEndDate: "2026-12-10",
      note: "",
      enabled: true,
      createdAt: "",
      updatedAt: "",
    },
  ];
  const scenario: Scenario = {
    id: "higher",
    name: "Higher rent",
    overrides: { rent: { amountMinor: 70_000_00 } },
  };
  const result = applyScenario(base, scenario);
  expect(result[0].amountMinor).toBe(70_000_00);
  expect(base[0].amountMinor).toBe(50_000_00);
  expect(result[0]).not.toBe(base[0]);
});
