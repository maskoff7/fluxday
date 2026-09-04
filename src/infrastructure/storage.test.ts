import { beforeEach, expect, it } from "vitest";
import { makeOperation } from "../domain/state";
import { browserStorageKey, loadState, saveState } from "./storage";

beforeEach(() => localStorage.clear());

it("persists an operation and restores a normalized plan", async () => {
  const loaded = await loadState();
  loaded.state.operations.push(
    makeOperation({
      name: "Salary",
      type: "income",
      amountMinor: 100_000_00,
      certainty: "certain",
      firstDate: "2026-01-01",
      recurrence: "none",
      recurrenceEndDate: null,
      note: "",
    }),
  );
  await saveState(loaded.state);
  const restored = await loadState();
  expect(restored.isNew).toBe(false);
  expect(restored.state.operations[0].amountMinor).toBe(100_000_00);
});

it("recovers safely from a corrupt browser snapshot", async () => {
  localStorage.setItem(browserStorageKey, "broken");
  const restored = await loadState();
  expect(restored.isNew).toBe(true);
  expect(restored.warning).toMatch(/не удалось прочитать/);
});
