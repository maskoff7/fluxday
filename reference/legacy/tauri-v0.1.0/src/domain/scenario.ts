import type { Operation, Scenario } from "./types";

export function applyScenario(
  operations: Operation[],
  scenario: Scenario | null,
): Operation[] {
  if (!scenario) return operations.map((operation) => ({ ...operation }));
  return operations.map((operation) => {
    const override =
      operation.recurrence === "none"
        ? undefined
        : scenario.overrides[operation.id];
    if (!override) return { ...operation };
    return {
      ...operation,
      ...(override.amountMinor !== undefined
        ? { amountMinor: override.amountMinor }
        : {}),
      ...(override.recurrence !== undefined
        ? { recurrence: override.recurrence }
        : {}),
      ...(override.firstDate !== undefined
        ? { firstDate: override.firstDate }
        : {}),
      ...(override.recurrenceEndDate !== undefined
        ? { recurrenceEndDate: override.recurrenceEndDate }
        : {}),
      ...(override.certainty !== undefined
        ? { certainty: override.certainty }
        : {}),
      enabled: override.excluded ? false : operation.enabled,
    };
  });
}
