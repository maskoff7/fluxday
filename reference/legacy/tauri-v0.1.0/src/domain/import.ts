import {
  defaultRecurrenceEnd,
  isCalendarDate,
  maxPlanningDate,
  todayCalendarDate,
} from "./date";
import { legacyMoneyToMinor } from "./money";
import {
  CERTAINTIES,
  normalizeState,
  OPERATION_TYPES,
  RECURRENCES,
} from "./state";
import type {
  AppState,
  Certainty,
  Operation,
  OperationType,
  Recurrence,
  Scenario,
  ScenarioOverride,
} from "./types";

export interface ImportPreview {
  state: AppState;
  source: "Fluxday" | "Cash Flow Planner";
  operationCount: number;
  recurringCount: number;
  scenarioCount: number;
  warningCount: number;
  warnings: string[];
}

function record(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function safeId(value: unknown, fallback: string, used: Set<string>): string {
  const candidate = /^[a-zA-Z0-9_-]+$/.test(String(value ?? ""))
    ? String(value)
    : fallback;
  let id = candidate;
  let suffix = 2;
  while (used.has(id)) id = `${candidate}-${suffix++}`;
  used.add(id);
  return id;
}

function preview(
  state: AppState,
  source: ImportPreview["source"],
  warnings: string[],
): ImportPreview {
  return {
    state,
    source,
    operationCount: state.operations.length,
    recurringCount: state.operations.filter(
      (item) => item.recurrence !== "none",
    ).length,
    scenarioCount: state.scenarios.length,
    warningCount: warnings.length,
    warnings,
  };
}

export function parseImportText(
  text: string,
  today = todayCalendarDate(),
): ImportPreview {
  if (!text.trim()) throw new Error("Выбранный файл пуст.");
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new Error("Файл не является корректным JSON.");
  }
  const raw = record(parsed);
  if (!raw) throw new Error("JSON должен содержать объект плана.");

  if (Array.isArray(raw.operations)) {
    const state = normalizeState(raw, today);
    if (state.operations.length !== raw.operations.length) {
      throw new Error(
        "Часть операций Fluxday повреждена. Импорт остановлен без изменения данных.",
      );
    }
    state.settings.preferences.onboardingComplete = true;
    return preview(state, "Fluxday", []);
  }

  if (!Array.isArray(raw.events) || !record(raw.settings)) {
    throw new Error("Не найден экспорт Fluxday или Cash Flow Planner.");
  }

  const warnings: string[] = [];
  const usedIds = new Set<string>();
  const sourceToImported = new Map<string, string>();
  const now = new Date().toISOString();
  const operations: Operation[] = [];

  raw.events.forEach((item, index) => {
    const event = record(item);
    if (!event) {
      warnings.push(`Операция ${index + 1}: пропущена повреждённая запись.`);
      return;
    }
    const name = String(event.name ?? "")
      .trim()
      .slice(0, 160);
    const amountMinor = legacyMoneyToMinor(event.amount);
    const firstDate = event.date;
    if (
      !name ||
      amountMinor === null ||
      amountMinor <= 0 ||
      !isCalendarDate(firstDate)
    ) {
      warnings.push(
        `Операция ${index + 1}: пропущены некорректные название, сумма или дата.`,
      );
      return;
    }
    const originalId = String(event.id ?? `legacy-op-${index + 1}`);
    const id = safeId(event.id, `legacy-op-${index + 1}`, usedIds);
    if (id !== originalId && usedIds.has(originalId))
      warnings.push(`«${name}»: дублирующийся ID заменён.`);
    if (!sourceToImported.has(originalId)) sourceToImported.set(originalId, id);
    const recurrence = RECURRENCES.includes(event.recurrence as Recurrence)
      ? (event.recurrence as Recurrence)
      : "none";
    operations.push({
      id,
      name,
      type: OPERATION_TYPES.includes(event.type as OperationType)
        ? (event.type as OperationType)
        : "expense",
      amountMinor,
      certainty: CERTAINTIES.includes(event.certainty as Certainty)
        ? (event.certainty as Certainty)
        : "certain",
      firstDate,
      recurrence,
      recurrenceEndDate:
        recurrence !== "none" && isCalendarDate(event.repeatUntil)
          ? event.repeatUntil
          : defaultRecurrenceEnd(firstDate, recurrence),
      note: String(event.note ?? "").slice(0, 500),
      enabled: true,
      createdAt: now,
      updatedAt: now,
    });
  });

  const settings = record(raw.settings) ?? {};
  const startBalanceMinor = legacyMoneyToMinor(settings.startBalance, true);
  const scenarios: Scenario[] = [];
  const scenarioIds = new Set<string>();
  if (Array.isArray(raw.scenarios)) {
    raw.scenarios.forEach((item, index) => {
      const legacyScenario = record(item);
      if (!legacyScenario) return;
      const overrides: Record<string, ScenarioOverride> = {};
      const rawOverrides = record(legacyScenario.overrides);
      if (rawOverrides) {
        for (const [sourceId, value] of Object.entries(rawOverrides)) {
          const operationId = sourceToImported.get(sourceId);
          const sourceOverride = record(value);
          if (!operationId || !sourceOverride) continue;
          const enabled = record(sourceOverride.enabled) ?? {};
          const override: ScenarioOverride = {};
          const amountMinor = legacyMoneyToMinor(sourceOverride.amount);
          if (enabled.amount && amountMinor !== null)
            override.amountMinor = amountMinor;
          if (
            enabled.recurrence &&
            RECURRENCES.includes(sourceOverride.recurrence as Recurrence)
          ) {
            override.recurrence = sourceOverride.recurrence as Recurrence;
          }
          if (enabled.date && isCalendarDate(sourceOverride.date))
            override.firstDate = sourceOverride.date;
          if (
            enabled.repeatUntil &&
            isCalendarDate(sourceOverride.repeatUntil)
          ) {
            override.recurrenceEndDate = sourceOverride.repeatUntil;
          }
          if (
            enabled.certainty &&
            CERTAINTIES.includes(sourceOverride.certainty as Certainty)
          ) {
            override.certainty = sourceOverride.certainty as Certainty;
          }
          if (sourceOverride.disabled === true) override.excluded = true;
          overrides[operationId] = override;
        }
      }
      scenarios.push({
        id: safeId(
          legacyScenario.id,
          `legacy-scenario-${index + 1}`,
          scenarioIds,
        ),
        name:
          String(legacyScenario.name ?? "Сценарий")
            .trim()
            .slice(0, 80) || "Сценарий",
        overrides,
      });
    });
  }

  const state: AppState = {
    schemaVersion: 1,
    settings: {
      startBalanceMinor: startBalanceMinor ?? 0,
      startDate: isCalendarDate(settings.startDate)
        ? settings.startDate <= maxPlanningDate(today)
          ? settings.startDate
          : today
        : today,
      baseCurrency: "RUB",
      preferences: { onboardingComplete: true },
    },
    operations,
    scenarios,
  };
  if (startBalanceMinor === null)
    warnings.push("Некорректный стартовый остаток заменён на 0 ₽.");
  return preview(state, "Cash Flow Planner", warnings);
}

export function exportPayload(state: AppState): string {
  return JSON.stringify(
    {
      version: 4,
      product: "Fluxday",
      exportedAt: new Date().toISOString(),
      ...state,
    },
    null,
    2,
  );
}
