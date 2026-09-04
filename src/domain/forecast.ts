import { addMonths, eachDay } from "./date";
import { expandOccurrences } from "./recurrence";
import type {
  CalendarDate,
  Forecast,
  ForecastDay,
  MoneyMinor,
  Operation,
} from "./types";

export function forecastHorizon(
  startDate: CalendarDate,
  operations: Operation[],
): CalendarDate {
  let horizon = addMonths(startDate, 6);
  for (const operation of operations) {
    const end =
      operation.recurrence === "none"
        ? operation.firstDate
        : operation.recurrenceEndDate;
    if (operation.enabled && end && end > horizon) horizon = end;
  }
  return horizon;
}

export function buildForecast(
  startBalanceMinor: MoneyMinor,
  startDate: CalendarDate,
  operations: Operation[],
  endDate = forecastHorizon(startDate, operations),
): Forecast {
  const occurrences = expandOccurrences(operations, startDate, endDate);
  const byDate = new Map<CalendarDate, typeof occurrences>();
  for (const occurrence of occurrences) {
    const current = byDate.get(occurrence.date) ?? [];
    current.push(occurrence);
    byDate.set(occurrence.date, current);
  }

  let balance = startBalanceMinor;
  let stressBalance = startBalanceMinor;
  let minimumBalanceMinor = startBalanceMinor;
  let minimumBalanceDate = startDate;
  let maximumBalanceMinor = startBalanceMinor;
  let stressMinimumBalanceMinor = startBalanceMinor;
  let firstNegativeDate: CalendarDate | null =
    startBalanceMinor < 0 ? startDate : null;
  let stressFirstNegativeDate: CalendarDate | null =
    startBalanceMinor < 0 ? startDate : null;
  let incomeMinor = 0;
  let expenseMinor = 0;

  const days: ForecastDay[] = eachDay(startDate, endDate).map((date) => {
    const dayOccurrences = byDate.get(date) ?? [];
    const openingBalanceMinor = balance;
    const dayIncome = dayOccurrences
      .filter((item) => item.type === "income")
      .reduce((total, item) => total + item.amountMinor, 0);
    const dayExpense = dayOccurrences
      .filter((item) => item.type === "expense")
      .reduce((total, item) => total + item.amountMinor, 0);
    const expectedIncome = dayOccurrences
      .filter((item) => item.type === "income" && item.certainty === "expected")
      .reduce((total, item) => total + item.amountMinor, 0);
    const netMinor = dayIncome - dayExpense;
    balance += netMinor;
    stressBalance += netMinor - expectedIncome;
    incomeMinor += dayIncome;
    expenseMinor += dayExpense;
    if (balance < minimumBalanceMinor) {
      minimumBalanceMinor = balance;
      minimumBalanceDate = date;
    }
    maximumBalanceMinor = Math.max(maximumBalanceMinor, balance);
    stressMinimumBalanceMinor = Math.min(
      stressMinimumBalanceMinor,
      stressBalance,
    );
    if (balance < 0 && firstNegativeDate === null) firstNegativeDate = date;
    if (stressBalance < 0 && stressFirstNegativeDate === null)
      stressFirstNegativeDate = date;
    return {
      date,
      openingBalanceMinor,
      incomeMinor: dayIncome,
      expenseMinor: dayExpense,
      netMinor,
      closingBalanceMinor: balance,
      stressClosingBalanceMinor: stressBalance,
      occurrences: dayOccurrences,
    };
  });

  return {
    startDate,
    endDate,
    days,
    occurrences,
    incomeMinor,
    expenseMinor,
    endingBalanceMinor: balance,
    minimumBalanceMinor,
    minimumBalanceDate,
    maximumBalanceMinor,
    firstNegativeDate,
    maximumDeficitMinor: Math.max(0, -minimumBalanceMinor),
    stressEndingBalanceMinor: stressBalance,
    stressMinimumBalanceMinor,
    stressFirstNegativeDate,
  };
}
