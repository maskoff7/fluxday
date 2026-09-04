import { isCalendarDate, todayCalendarDate } from "./date";
import { isMoneyMinor } from "./money";
import type {
  AppState,
  Certainty,
  Operation,
  OperationType,
  Recurrence,
  Scenario,
  ScenarioOverride,
} from "./types";

export const RECURRENCES: Recurrence[] = [
  "none",
  "daily",
  "weekly",
  "monthly",
  "yearly",
];
export const CERTAINTIES: Certainty[] = ["certain", "expected"];
export const OPERATION_TYPES: OperationType[] = ["income", "expense"];

export function createId(prefix = "id"): string {
  const token =
    globalThis.crypto?.randomUUID?.() ??
    `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  return `${prefix}-${token}`.replace(/[^a-zA-Z0-9_-]/g, "");
}

export function emptyState(today = todayCalendarDate()): AppState {
  return {
    schemaVersion: 1,
    settings: {
      startBalanceMinor: 0,
      startDate: today,
      baseCurrency: "RUB",
      preferences: { onboardingComplete: false },
    },
    operations: [],
    scenarios: [],
  };
}

function record(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function normalizeOverride(value: unknown): ScenarioOverride | null {
  const raw = record(value);
  if (!raw) return null;
  const result: ScenarioOverride = {};
  if (isMoneyMinor(raw.amountMinor, false))
    result.amountMinor = raw.amountMinor;
  if (RECURRENCES.includes(raw.recurrence as Recurrence))
    result.recurrence = raw.recurrence as Recurrence;
  if (isCalendarDate(raw.firstDate)) result.firstDate = raw.firstDate;
  if (raw.recurrenceEndDate === null || isCalendarDate(raw.recurrenceEndDate)) {
    result.recurrenceEndDate = raw.recurrenceEndDate as string | null;
  }
  if (CERTAINTIES.includes(raw.certainty as Certainty))
    result.certainty = raw.certainty as Certainty;
  if (typeof raw.excluded === "boolean") result.excluded = raw.excluded;
  return result;
}

export function normalizeState(
  value: unknown,
  today = todayCalendarDate(),
): AppState {
  const raw = record(value);
  if (!raw) throw new Error("Файл не содержит объект плана.");
  const rawSettings = record(raw.settings) ?? {};
  const state = emptyState(today);
  if (isMoneyMinor(rawSettings.startBalanceMinor))
    state.settings.startBalanceMinor = rawSettings.startBalanceMinor;
  if (isCalendarDate(rawSettings.startDate))
    state.settings.startDate = rawSettings.startDate;
  const preferences = record(rawSettings.preferences);
  if (preferences && typeof preferences.onboardingComplete === "boolean") {
    state.settings.preferences.onboardingComplete =
      preferences.onboardingComplete;
  }

  const ids = new Set<string>();
  if (Array.isArray(raw.operations)) {
    for (const item of raw.operations) {
      const operation = record(item);
      if (!operation) continue;
      const name = String(operation.name ?? "")
        .trim()
        .slice(0, 160);
      const amountMinor = operation.amountMinor;
      if (
        !name ||
        !isMoneyMinor(amountMinor, false) ||
        amountMinor <= 0 ||
        !isCalendarDate(operation.firstDate)
      )
        continue;
      const now = new Date().toISOString();
      let id = /^[a-zA-Z0-9_-]+$/.test(String(operation.id ?? ""))
        ? String(operation.id)
        : createId("op");
      if (ids.has(id)) id = createId("op");
      ids.add(id);
      const recurrence = RECURRENCES.includes(
        operation.recurrence as Recurrence,
      )
        ? (operation.recurrence as Recurrence)
        : "none";
      state.operations.push({
        id,
        name,
        type: OPERATION_TYPES.includes(operation.type as OperationType)
          ? (operation.type as OperationType)
          : "expense",
        amountMinor,
        certainty: CERTAINTIES.includes(operation.certainty as Certainty)
          ? (operation.certainty as Certainty)
          : "certain",
        firstDate: operation.firstDate,
        recurrence,
        recurrenceEndDate:
          recurrence !== "none" && isCalendarDate(operation.recurrenceEndDate)
            ? operation.recurrenceEndDate
            : null,
        note: String(operation.note ?? "").slice(0, 500),
        enabled: operation.enabled !== false,
        createdAt:
          typeof operation.createdAt === "string" ? operation.createdAt : now,
        updatedAt:
          typeof operation.updatedAt === "string" ? operation.updatedAt : now,
      });
    }
  }

  if (Array.isArray(raw.scenarios)) {
    for (const item of raw.scenarios) {
      const scenario = record(item);
      if (!scenario) continue;
      const overrides: Record<string, ScenarioOverride> = {};
      const rawOverrides = record(scenario.overrides);
      if (rawOverrides) {
        for (const [operationId, override] of Object.entries(rawOverrides)) {
          if (!ids.has(operationId)) continue;
          const normalized = normalizeOverride(override);
          if (normalized) overrides[operationId] = normalized;
        }
      }
      state.scenarios.push({
        id: /^[a-zA-Z0-9_-]+$/.test(String(scenario.id ?? ""))
          ? String(scenario.id)
          : createId("scenario"),
        name:
          String(scenario.name ?? "Сценарий")
            .trim()
            .slice(0, 80) || "Сценарий",
        overrides,
      });
    }
  }
  return state;
}

export function makeOperation(
  input: Omit<Operation, "id" | "createdAt" | "updatedAt" | "enabled">,
): Operation {
  const now = new Date().toISOString();
  return {
    ...input,
    id: createId("op"),
    createdAt: now,
    updatedAt: now,
    enabled: true,
  };
}

export function makeScenario(name: string): Scenario {
  return {
    id: createId("scenario"),
    name: name.trim().slice(0, 80) || "Новый сценарий",
    overrides: {},
  };
}
