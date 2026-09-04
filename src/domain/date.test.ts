import { describe, expect, it } from "vitest";
import {
  addDays,
  addMonths,
  addYears,
  isCalendarDate,
  startOfWeek,
} from "./date";

describe("calendar dates", () => {
  it("validates real Gregorian dates", () => {
    expect(isCalendarDate("2024-02-29")).toBe(true);
    expect(isCalendarDate("2025-02-29")).toBe(false);
    expect(isCalendarDate("2026-09-31")).toBe(false);
  });

  it("keeps the original monthly anchor day", () => {
    expect(addMonths("2025-01-31", 1)).toBe("2025-02-28");
    expect(addMonths("2025-01-31", 2)).toBe("2025-03-31");
    expect(addMonths("2024-01-30", 1)).toBe("2024-02-29");
  });

  it("handles leap years and year boundaries", () => {
    expect(addYears("2024-02-29", 1)).toBe("2025-02-28");
    expect(addDays("2025-12-31", 1)).toBe("2026-01-01");
    expect(startOfWeek("2026-09-04")).toBe("2026-08-31");
  });
});
