import { addDays, addMonths, addYears, todayCalendarDate } from "./date";
import { makeOperation, makeScenario } from "./state";
import type { AppState, Operation } from "./types";

export function sampleState(today = todayCalendarDate()): AppState {
  const operations: Operation[] = [
    makeOperation({
      name: "Зарплата",
      type: "income",
      amountMinor: 185_000_00,
      certainty: "certain",
      firstDate: addDays(today, 3),
      recurrence: "monthly",
      recurrenceEndDate: addMonths(addDays(today, 3), 6),
      note: "Основная работа",
    }),
    makeOperation({
      name: "Аренда квартиры",
      type: "expense",
      amountMinor: 78_000_00,
      certainty: "certain",
      firstDate: addDays(today, 7),
      recurrence: "monthly",
      recurrenceEndDate: addMonths(addDays(today, 7), 6),
      note: "Платёж владельцу",
    }),
    makeOperation({
      name: "Продукты и бытовые расходы",
      type: "expense",
      amountMinor: 12_500_00,
      certainty: "certain",
      firstDate: addDays(today, 2),
      recurrence: "weekly",
      recurrenceEndDate: addMonths(today, 6),
      note: "Недельный лимит",
    }),
    makeOperation({
      name: "Годовая страховка",
      type: "expense",
      amountMinor: 42_000_00,
      certainty: "certain",
      firstDate: addDays(today, 35),
      recurrence: "yearly",
      recurrenceEndDate: addYears(addDays(today, 35), 1),
      note: "Автомобиль",
    }),
    makeOperation({
      name: "Перелёт и отель для большой осенней поездки",
      type: "expense",
      amountMinor: 350_000_00,
      certainty: "certain",
      firstDate: addDays(today, 50),
      recurrence: "none",
      recurrenceEndDate: null,
      note: "Разовый крупный расход",
    }),
    makeOperation({
      name: "Ожидаемый гонорар",
      type: "income",
      amountMinor: 90_000_00,
      certainty: "expected",
      firstDate: addDays(today, 22),
      recurrence: "none",
      recurrenceEndDate: null,
      note: "Договор ещё не подписан",
    }),
  ];
  const higherRent = makeScenario("Аренда дороже");
  higherRent.overrides[operations[1].id] = { amountMinor: 92_000_00 };
  const delayedSalary = makeScenario("Зарплата позже");
  delayedSalary.overrides[operations[0].id] = {
    firstDate: addDays(operations[0].firstDate, 10),
  };
  return {
    schemaVersion: 1,
    settings: {
      startBalanceMinor: 130_000_00,
      startDate: today,
      baseCurrency: "RUB",
      preferences: { onboardingComplete: true },
    },
    operations,
    scenarios: [higherRent, delayedSalary],
  };
}
