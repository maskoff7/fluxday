import type { MoneyMinor } from "./types";

const MAX_MINOR = Number.MAX_SAFE_INTEGER;

export function isMoneyMinor(
  value: unknown,
  allowNegative = true,
): value is MoneyMinor {
  return Number.isSafeInteger(value) && (allowNegative || Number(value) >= 0);
}

export function parseMoneyInput(
  value: string,
  allowNegative = false,
): MoneyMinor | null {
  const normalized = value
    .trim()
    .replace(/[\s\u00a0]/g, "")
    .replace(",", ".");
  const match = normalized.match(
    allowNegative ? /^(-?)(\d+)(?:\.(\d{0,2}))?$/ : /^(\d+)(?:\.(\d{0,2}))?$/,
  );
  if (!match) return null;
  const negative = allowNegative && match[1] === "-";
  const wholeIndex = allowNegative ? 2 : 1;
  const fractionIndex = allowNegative ? 3 : 2;
  const whole = Number(match[wholeIndex]);
  const fraction = Number((match[fractionIndex] ?? "").padEnd(2, "0"));
  const result = whole * 100 + fraction;
  if (!Number.isSafeInteger(result) || result > MAX_MINOR) return null;
  return negative ? -result : result;
}

export function legacyMoneyToMinor(
  value: unknown,
  allowNegative = false,
): MoneyMinor | null {
  if (typeof value !== "number" && typeof value !== "string") return null;
  const numeric =
    typeof value === "number" ? value : Number(String(value).replace(",", "."));
  if (!Number.isFinite(numeric) || (!allowNegative && numeric < 0)) return null;
  const minor = Math.round(numeric * 100);
  return isMoneyMinor(minor, allowNegative) ? minor : null;
}

export function moneyInputValue(value: MoneyMinor): string {
  return (value / 100).toFixed(2);
}

export function formatMoney(
  value: MoneyMinor,
  currency = "RUB",
  sign = false,
): string {
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
    signDisplay: sign ? "exceptZero" : "auto",
  }).format(value / 100);
}

export function formatCompactMoney(value: MoneyMinor): string {
  return new Intl.NumberFormat("ru-RU", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(value / 100);
}
