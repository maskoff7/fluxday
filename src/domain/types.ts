export type CalendarDate = string;
export type MoneyMinor = number;
export type OperationType = "income" | "expense";
export type Certainty = "certain" | "expected";
export type Recurrence = "none" | "daily" | "weekly" | "monthly" | "yearly";

export interface Settings {
  startBalanceMinor: MoneyMinor;
  startDate: CalendarDate;
  baseCurrency: "RUB";
  preferences: {
    onboardingComplete: boolean;
  };
}

export interface Operation {
  id: string;
  name: string;
  type: OperationType;
  amountMinor: MoneyMinor;
  certainty: Certainty;
  firstDate: CalendarDate;
  recurrence: Recurrence;
  recurrenceEndDate: CalendarDate | null;
  note: string;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ScenarioOverride {
  amountMinor?: MoneyMinor;
  recurrence?: Recurrence;
  firstDate?: CalendarDate;
  recurrenceEndDate?: CalendarDate | null;
  certainty?: Certainty;
  excluded?: boolean;
}

export interface Scenario {
  id: string;
  name: string;
  overrides: Record<string, ScenarioOverride>;
}

export interface AppState {
  schemaVersion: 1;
  settings: Settings;
  operations: Operation[];
  scenarios: Scenario[];
}

export interface Occurrence extends Operation {
  sourceId: string;
  date: CalendarDate;
  occurrenceId: string;
  recurring: boolean;
}

export interface ForecastDay {
  date: CalendarDate;
  openingBalanceMinor: MoneyMinor;
  incomeMinor: MoneyMinor;
  expenseMinor: MoneyMinor;
  netMinor: MoneyMinor;
  closingBalanceMinor: MoneyMinor;
  stressClosingBalanceMinor: MoneyMinor;
  occurrences: Occurrence[];
}

export interface Forecast {
  startDate: CalendarDate;
  endDate: CalendarDate;
  days: ForecastDay[];
  occurrences: Occurrence[];
  incomeMinor: MoneyMinor;
  expenseMinor: MoneyMinor;
  endingBalanceMinor: MoneyMinor;
  minimumBalanceMinor: MoneyMinor;
  minimumBalanceDate: CalendarDate;
  maximumBalanceMinor: MoneyMinor;
  firstNegativeDate: CalendarDate | null;
  maximumDeficitMinor: MoneyMinor;
  stressEndingBalanceMinor: MoneyMinor;
  stressMinimumBalanceMinor: MoneyMinor;
  stressFirstNegativeDate: CalendarDate | null;
}

export interface SummaryGroup {
  id: string;
  name: string;
  type: OperationType;
  certainty: Certainty;
  recurrence: Recurrence;
  totalMinor: MoneyMinor;
  count: number;
  share: number;
  occurrences: Occurrence[];
}

export interface Summary {
  incomeMinor: MoneyMinor;
  expenseMinor: MoneyMinor;
  netMinor: MoneyMinor;
  turnoverMinor: MoneyMinor;
  occurrenceCount: number;
  groups: SummaryGroup[];
}
