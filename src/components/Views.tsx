/* eslint-disable react-refresh/only-export-components */
import { useMemo, useState, type ReactNode } from "react";
import {
  DonutChart,
  LineComparisonChart,
  chartColor,
  type ChartPoint,
} from "./Charts";
import { moneyWithSign } from "./Dialogs";
import {
  addDays,
  addMonths,
  addYears,
  eachDay,
  endOfMonth,
  endOfWeek,
  endOfYear,
  formatCalendarDate,
  startOfMonth,
  startOfWeek,
  startOfYear,
  todayCalendarDate,
} from "../domain/date";
import { buildForecast } from "../domain/forecast";
import { formatMoney, moneyInputValue, parseMoneyInput } from "../domain/money";
import { occurrenceDates } from "../domain/recurrence";
import { applyScenario } from "../domain/scenario";
import { buildSummary, type SummaryFilter } from "../domain/summary";
import type {
  AppState,
  CalendarDate,
  Forecast,
  Operation,
  Recurrence,
  ScenarioOverride,
} from "../domain/types";

type SummaryMode = "week" | "month" | "year" | "custom";

export const RECURRENCE_LABEL: Record<Recurrence, string> = {
  none: "Разово",
  daily: "Ежедневно",
  weekly: "Еженедельно",
  monthly: "Ежемесячно",
  yearly: "Ежегодно",
};

export function Metric({
  label,
  value,
  hint,
  tone = "neutral",
}: {
  label: string;
  value: string;
  hint: string;
  tone?: "neutral" | "good" | "bad";
}) {
  return (
    <article className={`metric-card ${tone}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{hint}</small>
    </article>
  );
}

function Empty({
  title,
  copy,
  action,
}: {
  title: string;
  copy: string;
  action?: ReactNode;
}) {
  return (
    <div className="empty-state roomy">
      <div className="empty-symbol">◇</div>
      <h3>{title}</h3>
      <p>{copy}</p>
      {action}
    </div>
  );
}

function OperationBadges({ operation }: { operation: Operation }) {
  return (
    <div className="badges">
      <span className={`badge ${operation.type}`}>
        {operation.type === "income" ? "Доход" : "Расход"}
      </span>
      <span className={`badge ${operation.certainty}`}>
        {operation.certainty === "certain" ? "100% точно" : "Предполагается"}
      </span>
      {operation.recurrence !== "none" && (
        <span className="badge recurring">
          ↻ {RECURRENCE_LABEL[operation.recurrence].toLowerCase()}
        </span>
      )}
      {!operation.enabled && <span className="badge disabled">Отключено</span>}
    </div>
  );
}

export function KpiStrip({ forecast }: { forecast: Forecast }) {
  return (
    <div className="metrics-grid">
      <Metric
        label="Сейчас"
        value={formatMoney(forecast.days[0]?.openingBalanceMinor ?? 0)}
        hint={formatCalendarDate(forecast.startDate)}
      />
      <Metric
        label="Минимум"
        value={formatMoney(forecast.minimumBalanceMinor)}
        hint={formatCalendarDate(forecast.minimumBalanceDate)}
        tone={forecast.minimumBalanceMinor < 0 ? "bad" : "good"}
      />
      <Metric
        label="В конце"
        value={formatMoney(forecast.endingBalanceMinor)}
        hint={`до ${formatCalendarDate(forecast.endDate)}`}
        tone={forecast.endingBalanceMinor < 0 ? "bad" : "neutral"}
      />
      <Metric
        label="Первый разрыв"
        value={
          forecast.firstNegativeDate
            ? formatCalendarDate(forecast.firstNegativeDate, {
                day: "2-digit",
                month: "short",
              })
            : "Нет"
        }
        hint={
          forecast.firstNegativeDate
            ? `Дефицит до ${formatMoney(forecast.maximumDeficitMinor)}`
            : "Баланс остаётся положительным"
        }
        tone={forecast.firstNegativeDate ? "bad" : "good"}
      />
    </div>
  );
}

export function TimelineView({
  forecast,
  query,
  onEdit,
  onDuplicate,
  onDelete,
  onOpenScenarios,
}: {
  forecast: Forecast;
  query: string;
  onEdit: (operation: Operation) => void;
  onDuplicate: (operation: Operation) => void;
  onDelete: (operation: Operation) => void;
  onOpenScenarios: () => void;
}) {
  const normalizedQuery = query.trim().toLocaleLowerCase("ru");
  const days = forecast.days
    .map((day) => ({
      ...day,
      visible: day.occurrences.filter(
        (item) =>
          !normalizedQuery ||
          `${item.name} ${item.note}`
            .toLocaleLowerCase("ru")
            .includes(normalizedQuery),
      ),
    }))
    .filter((day) => day.visible.length > 0);
  const gapDay = forecast.firstNegativeDate
    ? forecast.days.find((day) => day.date === forecast.firstNegativeDate)
    : null;
  return (
    <div className="view-stack">
      {gapDay && (
        <section className="gap-card">
          <div>
            <span className="eyebrow">Кассовый разрыв</span>
            <h3>
              {formatCalendarDate(gapDay.date)} не хватит{" "}
              {formatMoney(-gapDay.closingBalanceMinor)}
            </h3>
            <p>
              До операций: {formatMoney(gapDay.openingBalanceMinor)} · изменение
              за день: {formatMoney(gapDay.netMinor, "RUB", true)} · после всех
              операций: {formatMoney(gapDay.closingBalanceMinor)}.
            </p>
            <div className="gap-causes">
              {gapDay.occurrences.map((item) => (
                <span key={item.occurrenceId}>
                  {item.name} {item.type === "income" ? "+" : "−"}
                  {formatMoney(item.amountMinor)}
                </span>
              ))}
            </div>
          </div>
          <button className="button danger-quiet" onClick={onOpenScenarios}>
            Проверить варианты
          </button>
        </section>
      )}
      {days.length === 0 ? (
        <Empty
          title={query ? "Ничего не найдено" : "Операций пока нет"}
          copy={
            query
              ? "Измените поисковый запрос."
              : "Добавьте доход или расход — прогноз появится сразу."
          }
        />
      ) : (
        <div className="timeline">
          {days.map((day) => (
            <section
              className={`day-group ${day.closingBalanceMinor < 0 ? "negative" : ""}`}
              key={day.date}
            >
              <header className="day-head">
                <div>
                  <strong>
                    {formatCalendarDate(day.date, {
                      weekday: "long",
                      day: "2-digit",
                      month: "long",
                    })}
                  </strong>
                  <span>
                    {day.visible.length}{" "}
                    {day.visible.length === 1 ? "операция" : "операции"}
                  </span>
                </div>
                <div className="day-totals">
                  <span className="income">
                    +{formatMoney(day.incomeMinor)}
                  </span>
                  <span className="expense">
                    −{formatMoney(day.expenseMinor)}
                  </span>
                  <strong>{formatMoney(day.closingBalanceMinor)}</strong>
                  <small>остаток</small>
                </div>
              </header>
              <div className="operation-list">
                {day.visible.map((operation) => (
                  <article
                    className="operation-row"
                    key={operation.occurrenceId}
                  >
                    <div className={`type-mark ${operation.type}`}>
                      {operation.type === "income" ? "+" : "−"}
                    </div>
                    <div className="operation-main">
                      <strong>{operation.name}</strong>
                      {operation.note && <p>{operation.note}</p>}
                      <OperationBadges operation={operation} />
                    </div>
                    <div className={`operation-amount ${operation.type}`}>
                      {moneyWithSign(operation)}
                    </div>
                    <div className="row-menu">
                      <button onClick={() => onEdit(operation)}>
                        Изменить
                      </button>
                      <button onClick={() => onDuplicate(operation)}>
                        Копия
                      </button>
                      <button
                        className="danger-text"
                        onClick={() => onDelete(operation)}
                      >
                        Удалить
                      </button>
                    </div>
                  </article>
                ))}
              </div>
              <footer className="day-net">
                <span>
                  Изменение за день {formatMoney(day.netMinor, "RUB", true)}
                </span>
                <span>
                  Открытие {formatMoney(day.openingBalanceMinor)} → Закрытие{" "}
                  <strong>{formatMoney(day.closingBalanceMinor)}</strong>
                </span>
              </footer>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}

export function BalanceView({ forecast }: { forecast: Forecast }) {
  const points = forecast.days.map((day) => ({
    date: day.date,
    primary: day.closingBalanceMinor,
    secondary: day.stressClosingBalanceMinor,
  }));
  return (
    <div className="view-stack">
      <section className="stress-explainer">
        <div>
          <span className="eyebrow">
            Stress test · Без предполагаемых доходов
          </span>
          <h3>
            {forecast.stressFirstNegativeDate
              ? `Разрыв ${formatCalendarDate(forecast.stressFirstNegativeDate)}`
              : "Кассового разрыва нет"}
          </h3>
          <p>
            Все расходы происходят. Доходы «Предполагается» считаются равными
            нулю; гарантированные доходы остаются.
          </p>
        </div>
        <strong
          className={
            forecast.stressMinimumBalanceMinor < 0
              ? "negative-text"
              : "positive-text"
          }
        >
          min {formatMoney(forecast.stressMinimumBalanceMinor)}
        </strong>
      </section>
      <section className="panel chart-panel">
        <header className="section-head">
          <div>
            <span className="eyebrow">Closing balance по дням</span>
            <h2>Динамика остатка</h2>
          </div>
          <div className="mini-kpis">
            <span>
              max <b>{formatMoney(forecast.maximumBalanceMinor)}</b>
            </span>
            <span>
              end <b>{formatMoney(forecast.endingBalanceMinor)}</b>
            </span>
          </div>
        </header>
        <LineComparisonChart
          points={points}
          primaryLabel="Основной план"
          secondaryLabel="Без предполагаемых доходов"
          ariaLabel="Сравнение ежедневного остатка основного плана и stress test"
        />
      </section>
      <section className="panel daily-table-panel">
        <header className="section-head">
          <div>
            <span className="eyebrow">Точная арифметика</span>
            <h2>Баланс по дням</h2>
          </div>
        </header>
        <div className="daily-table">
          <div className="daily-row table-head">
            <span>Дата</span>
            <span>Открытие</span>
            <span>Доход</span>
            <span>Расход</span>
            <span>Изменение</span>
            <span>Закрытие</span>
          </div>
          {forecast.days
            .filter(
              (day) =>
                day.occurrences.length > 0 || day.closingBalanceMinor < 0,
            )
            .map((day) => (
              <div
                className={`daily-row ${day.closingBalanceMinor < 0 ? "negative" : ""}`}
                key={day.date}
              >
                <span>
                  {formatCalendarDate(day.date, {
                    day: "2-digit",
                    month: "short",
                  })}
                </span>
                <span>{formatMoney(day.openingBalanceMinor)}</span>
                <span className="income">+{formatMoney(day.incomeMinor)}</span>
                <span className="expense">
                  −{formatMoney(day.expenseMinor)}
                </span>
                <span>{formatMoney(day.netMinor, "RUB", true)}</span>
                <strong>{formatMoney(day.closingBalanceMinor)}</strong>
              </div>
            ))}
        </div>
      </section>
    </div>
  );
}

export function CalendarView({
  forecast,
  month,
  selectedDate,
  onMonth,
  onSelect,
  onEdit,
}: {
  forecast: Forecast;
  month: CalendarDate;
  selectedDate: CalendarDate;
  onMonth: (date: CalendarDate) => void;
  onSelect: (date: CalendarDate) => void;
  onEdit: (operation: Operation) => void;
}) {
  const gridStart = startOfWeek(startOfMonth(month));
  const dates = eachDay(gridStart, addDays(gridStart, 41));
  const dayMap = new Map(forecast.days.map((day) => [day.date, day]));
  const selected = dayMap.get(selectedDate);
  return (
    <div className="view-stack">
      <section className="panel calendar-panel">
        <header className="calendar-toolbar">
          <div>
            <span className="eyebrow">Финансовый календарь</span>
            <h2>
              {formatCalendarDate(month, { month: "long", year: "numeric" })}
            </h2>
          </div>
          <div>
            <button
              className="button secondary icon-only"
              onClick={() => onMonth(addMonths(month, -1))}
            >
              ←
            </button>
            <button
              className="button secondary"
              onClick={() => onMonth(startOfMonth(todayCalendarDate()))}
            >
              Сегодня
            </button>
            <button
              className="button secondary icon-only"
              onClick={() => onMonth(addMonths(month, 1))}
            >
              →
            </button>
          </div>
        </header>
        <div className="calendar-weekdays">
          {["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"].map((day) => (
            <span key={day}>{day}</span>
          ))}
        </div>
        <div className="calendar-grid">
          {dates.map((date) => {
            const day = dayMap.get(date);
            const outside = date.slice(0, 7) !== month.slice(0, 7);
            return (
              <button
                className={`calendar-day ${outside ? "outside" : ""} ${date === selectedDate ? "selected" : ""} ${day && day.closingBalanceMinor < 0 ? "negative" : ""}`}
                key={date}
                onClick={() => onSelect(date)}
              >
                <span className="day-number">{Number(date.slice(8))}</span>
                <div className="calendar-events">
                  {day?.occurrences.slice(0, 3).map((item) => (
                    <span className={item.type} key={item.occurrenceId}>
                      <b>{item.name}</b>
                      <em>
                        {item.type === "income" ? "+" : "−"}
                        {formatMoney(item.amountMinor)}
                      </em>
                    </span>
                  ))}
                  {day && day.occurrences.length > 3 && (
                    <span className="more">
                      Ещё {day.occurrences.length - 3}
                    </span>
                  )}
                </div>
                {day && (
                  <span
                    className={`calendar-balance ${day.closingBalanceMinor < 0 ? "negative-text" : ""}`}
                  >
                    {formatMoney(day.closingBalanceMinor)}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </section>
      <section className="panel day-detail">
        <header className="section-head">
          <div>
            <span className="eyebrow">Детали дня</span>
            <h2>
              {formatCalendarDate(selectedDate, {
                weekday: "long",
                day: "2-digit",
                month: "long",
                year: "numeric",
              })}
            </h2>
          </div>
          {selected && (
            <strong
              className={
                selected.closingBalanceMinor < 0 ? "negative-text" : ""
              }
            >
              {formatMoney(selected.closingBalanceMinor)} после дня
            </strong>
          )}
        </header>
        {!selected || selected.occurrences.length === 0 ? (
          <p className="muted-copy">На этот день операций нет.</p>
        ) : (
          <div className="detail-list">
            {selected.occurrences.map((item) => (
              <button key={item.occurrenceId} onClick={() => onEdit(item)}>
                <span>
                  <strong>{item.name}</strong>
                  <small>
                    {item.note ||
                      (item.certainty === "certain"
                        ? "100% точно"
                        : "Предполагается")}
                  </small>
                </span>
                <b className={item.type}>{moneyWithSign(item)}</b>
              </button>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

export function RecurringView({
  operations,
  onEdit,
  onDuplicate,
  onDelete,
  onToggle,
}: {
  operations: Operation[];
  onEdit: (operation: Operation) => void;
  onDuplicate: (operation: Operation) => void;
  onDelete: (operation: Operation) => void;
  onToggle: (operation: Operation) => void;
}) {
  const recurring = operations.filter((item) => item.recurrence !== "none");
  const groups = [
    { title: "Регулярные расходы", type: "expense" },
    { title: "Регулярные доходы", type: "income" },
  ] as const;
  if (!recurring.length)
    return (
      <Empty
        title="Повторяющихся операций нет"
        copy="Создайте операцию и выберите частоту повторения."
      />
    );
  return (
    <div className="view-stack">
      {groups.map((group) => {
        const items = recurring.filter((item) => item.type === group.type);
        return (
          <section className="panel recurring-panel" key={group.type}>
            <header className="section-head">
              <div>
                <span className="eyebrow">
                  {group.type === "income" ? "Входящий поток" : "Обязательства"}
                </span>
                <h2>{group.title}</h2>
              </div>
              <span className="count-pill">{items.length}</span>
            </header>
            {items.length === 0 ? (
              <p className="muted-copy">Пока пусто.</p>
            ) : (
              <div className="series-list">
                {items.map((operation) => {
                  const from =
                    operation.firstDate > todayCalendarDate()
                      ? operation.firstDate
                      : todayCalendarDate();
                  const next = operation.enabled
                    ? occurrenceDates(
                        operation,
                        from,
                        operation.recurrenceEndDate ?? from,
                      )[0]
                    : null;
                  return (
                    <article
                      className={`series-card ${!operation.enabled ? "disabled" : ""}`}
                      key={operation.id}
                    >
                      <div className={`series-icon ${operation.type}`}>↻</div>
                      <div className="series-main">
                        <strong>{operation.name}</strong>
                        <OperationBadges operation={operation} />
                        <p>{operation.note || "Без комментария"}</p>
                        <div className="series-meta">
                          <span>{RECURRENCE_LABEL[operation.recurrence]}</span>
                          <span>
                            {formatCalendarDate(operation.firstDate)} →{" "}
                            {operation.recurrenceEndDate
                              ? formatCalendarDate(operation.recurrenceEndDate)
                              : "—"}
                          </span>
                          <span>
                            Следующая: {next ? formatCalendarDate(next) : "нет"}
                          </span>
                        </div>
                      </div>
                      <div className={`series-amount ${operation.type}`}>
                        {moneyWithSign(operation)}
                      </div>
                      <div className="series-actions">
                        <button onClick={() => onEdit(operation)}>
                          Изменить
                        </button>
                        <button onClick={() => onDuplicate(operation)}>
                          Копия
                        </button>
                        <button onClick={() => onToggle(operation)}>
                          {operation.enabled ? "Отключить" : "Включить"}
                        </button>
                        <button
                          className="danger-text"
                          onClick={() => onDelete(operation)}
                        >
                          Удалить
                        </button>
                      </div>
                    </article>
                  );
                })}
              </div>
            )}
          </section>
        );
      })}
    </div>
  );
}

function summaryRange(
  mode: SummaryMode,
  anchor: CalendarDate,
  customStart: CalendarDate,
  customEnd: CalendarDate,
) {
  if (mode === "week")
    return { start: startOfWeek(anchor), end: endOfWeek(anchor) };
  if (mode === "year")
    return { start: startOfYear(anchor), end: endOfYear(anchor) };
  if (mode === "custom")
    return customStart <= customEnd
      ? { start: customStart, end: customEnd }
      : { start: customEnd, end: customStart };
  return { start: startOfMonth(anchor), end: endOfMonth(anchor) };
}

export function SummaryView({ operations }: { operations: Operation[] }) {
  const today = todayCalendarDate();
  const [mode, setMode] = useState<SummaryMode>("month");
  const [anchor, setAnchor] = useState(today);
  const [customStart, setCustomStart] = useState(startOfMonth(today));
  const [customEnd, setCustomEnd] = useState(endOfMonth(today));
  const [filter, setFilter] = useState<SummaryFilter>("expense");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const range = summaryRange(mode, anchor, customStart, customEnd);
  const summary = useMemo(
    () => buildSummary(operations, range.start, range.end, filter),
    [operations, range.start, range.end, filter],
  );
  const selected =
    summary.groups.find((group) => group.id === selectedId) ??
    summary.groups[0] ??
    null;
  function shift(amount: number) {
    setSelectedId(null);
    setAnchor(
      mode === "week"
        ? addDays(anchor, amount * 7)
        : mode === "year"
          ? addYears(anchor, amount)
          : addMonths(anchor, amount),
    );
  }
  const trend: ChartPoint[] = selected
    ? (() => {
        let cumulative = 0;
        const byDate = new Map<string, number>();
        selected.occurrences.forEach((item) =>
          byDate.set(
            item.date,
            (byDate.get(item.date) ?? 0) + item.amountMinor,
          ),
        );
        return eachDay(range.start, range.end).map((date) => {
          const day = byDate.get(date) ?? 0;
          cumulative += day;
          return { date, primary: cumulative, secondary: day };
        });
      })()
    : [];
  return (
    <div className="view-stack">
      <section className="panel summary-controls">
        <div className="period-controls">
          <label>
            <span>Период</span>
            <select
              value={mode}
              onChange={(event) => {
                setMode(event.target.value as SummaryMode);
                setSelectedId(null);
              }}
            >
              <option value="week">Неделя</option>
              <option value="month">Месяц</option>
              <option value="year">Год</option>
              <option value="custom">Свой диапазон</option>
            </select>
          </label>
          {mode === "custom" ? (
            <>
              <label>
                <span>С даты</span>
                <input
                  type="date"
                  value={customStart}
                  onChange={(event) => setCustomStart(event.target.value)}
                />
              </label>
              <label>
                <span>По дату</span>
                <input
                  type="date"
                  value={customEnd}
                  onChange={(event) => setCustomEnd(event.target.value)}
                />
              </label>
            </>
          ) : (
            <div className="period-nav">
              <button
                className="button secondary icon-only"
                onClick={() => shift(-1)}
              >
                ←
              </button>
              <button
                className="button secondary"
                onClick={() => setAnchor(today)}
              >
                Текущий
              </button>
              <button
                className="button secondary icon-only"
                onClick={() => shift(1)}
              >
                →
              </button>
            </div>
          )}
          <strong>
            {formatCalendarDate(range.start)} — {formatCalendarDate(range.end)}
          </strong>
        </div>
        <div className="segmented">
          {(["expense", "income", "all"] as SummaryFilter[]).map((item) => (
            <button
              className={filter === item ? "active" : ""}
              key={item}
              onClick={() => {
                setFilter(item);
                setSelectedId(null);
              }}
            >
              {item === "expense"
                ? "Расходы"
                : item === "income"
                  ? "Доходы"
                  : "Все операции"}
            </button>
          ))}
        </div>
      </section>
      <div className="summary-kpis">
        <Metric
          label="Доходы"
          value={formatMoney(summary.incomeMinor)}
          hint="За выбранный период"
          tone="good"
        />
        <Metric
          label="Расходы"
          value={formatMoney(summary.expenseMinor)}
          hint="За выбранный период"
          tone="bad"
        />
        <Metric
          label="Чистый поток"
          value={formatMoney(summary.netMinor, "RUB", true)}
          hint="Доходы минус расходы"
          tone={summary.netMinor < 0 ? "bad" : "good"}
        />
        <Metric
          label="Фактических появлений"
          value={String(summary.occurrenceCount)}
          hint="С учётом повторений"
        />
      </div>
      <section className="panel composition">
        <header className="section-head">
          <div>
            <span className="eyebrow">
              {filter === "all" ? "Абсолютные суммы" : "Доля выбранного потока"}
            </span>
            <h2>
              {filter === "all"
                ? "Структура оборота"
                : filter === "expense"
                  ? "Структура расходов"
                  : "Структура доходов"}
            </h2>
          </div>
        </header>
        <div className="composition-grid">
          <DonutChart
            groups={summary.groups}
            selectedId={selected?.id ?? null}
            onSelect={setSelectedId}
          />
          <div className="summary-list">
            {summary.groups.map((group, index) => (
              <button
                className={selected?.id === group.id ? "active" : ""}
                key={group.id}
                onClick={() => setSelectedId(group.id)}
              >
                <i style={{ background: chartColor(index) }} />
                <span>
                  <strong>{group.name}</strong>
                  <small>
                    {group.type === "income" ? "Доход" : "Расход"} ·{" "}
                    {group.count} шт. ·{" "}
                    {(group.share * 100).toLocaleString("ru-RU", {
                      maximumFractionDigits: 1,
                    })}
                    %
                  </small>
                </span>
                <b className={group.type}>
                  {group.type === "income" ? "+" : "−"}
                  {formatMoney(group.totalMinor)}
                </b>
              </button>
            ))}
          </div>
        </div>
      </section>
      {selected && (
        <section className="panel chart-panel">
          <header className="section-head">
            <div>
              <span className="eyebrow">Динамика конкретной операции</span>
              <h2>{selected.name}</h2>
            </div>
            <strong>{formatMoney(selected.totalMinor)}</strong>
          </header>
          <LineComparisonChart
            points={trend}
            primaryLabel="Накопительно"
            secondaryLabel="Сумма в день"
            primaryClass="chart-primary"
            secondaryClass="chart-tertiary"
            ariaLabel={`Динамика операции ${selected.name}`}
          />
        </section>
      )}
    </div>
  );
}

export function ScenarioView({
  state,
  selectedId,
  onSelect,
  onCreate,
  onRemove,
  onRename,
  onOverride,
  onOpenOperation,
}: {
  state: AppState;
  selectedId: string | null;
  onSelect: (id: string) => void;
  onCreate: (name: string) => void;
  onRemove: () => void;
  onRename: (name: string) => void;
  onOverride: (operationId: string, override: ScenarioOverride | null) => void;
  onOpenOperation: (operation: Operation) => void;
}) {
  const [newName, setNewName] = useState("");
  const scenario =
    state.scenarios.find((item) => item.id === selectedId) ?? null;
  const base = buildForecast(
    state.settings.startBalanceMinor,
    state.settings.startDate,
    state.operations,
  );
  const scenarioForecast = scenario
    ? buildForecast(
        state.settings.startBalanceMinor,
        state.settings.startDate,
        applyScenario(state.operations, scenario),
        base.endDate,
      )
    : null;
  const recurring = state.operations.filter(
    (item) => item.recurrence !== "none",
  );
  if (!scenario)
    return (
      <Empty
        title="Создайте первый сценарий"
        copy="Сценарий меняет только выбранные повторяющиеся операции; базовый план остаётся нетронутым."
        action={
          <form
            className="inline-create"
            onSubmit={(event) => {
              event.preventDefault();
              if (newName.trim()) {
                onCreate(newName);
                setNewName("");
              }
            }}
          >
            <input
              value={newName}
              onChange={(event) => setNewName(event.target.value)}
              placeholder="Например, аренда дороже"
            />
            <button className="button primary">Создать сценарий</button>
          </form>
        }
      />
    );
  const points = base.days.map((day, index) => ({
    date: day.date,
    primary: day.closingBalanceMinor,
    secondary:
      scenarioForecast?.days[index]?.closingBalanceMinor ??
      day.closingBalanceMinor,
  }));
  return (
    <div className="view-stack">
      <section className="panel scenario-toolbar">
        <div>
          <label>
            <span>Сценарий</span>
            <select
              value={scenario.id}
              onChange={(event) => onSelect(event.target.value)}
            >
              {state.scenarios.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}
                </option>
              ))}
            </select>
          </label>
          <button
            className="button secondary"
            onClick={() => {
              const name = window.prompt("Новое название", scenario.name);
              if (name?.trim()) onRename(name);
            }}
          >
            Переименовать
          </button>
          <button className="button danger-quiet" onClick={onRemove}>
            Удалить
          </button>
        </div>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            if (newName.trim()) {
              onCreate(newName);
              setNewName("");
            }
          }}
        >
          <input
            value={newName}
            onChange={(event) => setNewName(event.target.value)}
            placeholder="Новый сценарий"
          />
          <button className="button secondary">+ Создать</button>
        </form>
      </section>
      <div className="scenario-kpis">
        <Metric
          label="Base · в конце"
          value={formatMoney(base.endingBalanceMinor)}
          hint={`min ${formatMoney(base.minimumBalanceMinor)}`}
        />
        <Metric
          label={`${scenario.name} · в конце`}
          value={formatMoney(scenarioForecast!.endingBalanceMinor)}
          hint={`Δ ${formatMoney(scenarioForecast!.endingBalanceMinor - base.endingBalanceMinor, "RUB", true)}`}
          tone={scenarioForecast!.endingBalanceMinor < 0 ? "bad" : "good"}
        />
        <Metric
          label="Первый разрыв"
          value={
            scenarioForecast!.firstNegativeDate
              ? formatCalendarDate(scenarioForecast!.firstNegativeDate, {
                  day: "2-digit",
                  month: "short",
                })
              : "Нет"
          }
          hint={`Дефицит ${formatMoney(scenarioForecast!.maximumDeficitMinor)}`}
          tone={scenarioForecast!.firstNegativeDate ? "bad" : "good"}
        />
        <Metric
          label="Минимум"
          value={formatMoney(scenarioForecast!.minimumBalanceMinor)}
          hint={`Δ ${formatMoney(scenarioForecast!.minimumBalanceMinor - base.minimumBalanceMinor, "RUB", true)}`}
          tone={scenarioForecast!.minimumBalanceMinor < 0 ? "bad" : "neutral"}
        />
      </div>
      <section className="panel chart-panel">
        <header className="section-head">
          <div>
            <span className="eyebrow">Base vs Scenario</span>
            <h2>Как изменится остаток</h2>
          </div>
        </header>
        <LineComparisonChart
          points={points}
          primaryLabel="Базовый план"
          secondaryLabel={scenario.name}
          primaryClass="chart-muted"
          secondaryClass="chart-primary"
          ariaLabel={`Сравнение базового плана и сценария ${scenario.name}`}
        />
      </section>
      <section className="panel">
        <header className="section-head">
          <div>
            <span className="eyebrow">Sparse overrides</span>
            <h2>Изменения повторяющихся операций</h2>
          </div>
          <span className="count-pill">
            {Object.keys(scenario.overrides).length}
          </span>
        </header>
        {recurring.length === 0 ? (
          <p className="muted-copy">Сначала добавьте повторяющуюся операцию.</p>
        ) : (
          <div className="override-list">
            {recurring.map((operation) => (
              <ScenarioOperation
                key={operation.id}
                operation={operation}
                override={scenario.overrides[operation.id] ?? null}
                onChange={(override) => onOverride(operation.id, override)}
                onOpen={() => onOpenOperation(operation)}
              />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

function ScenarioOperation({
  operation,
  override,
  onChange,
  onOpen,
}: {
  operation: Operation;
  override: ScenarioOverride | null;
  onChange: (override: ScenarioOverride | null) => void;
  onOpen: () => void;
}) {
  const active = override !== null;
  function patch(value: Partial<ScenarioOverride>) {
    onChange({ ...(override ?? {}), ...value });
  }
  return (
    <article className={`override-card ${active ? "active" : ""}`}>
      <header>
        <button className="operation-link" onClick={onOpen}>
          <strong>{operation.name}</strong>
          <span>
            {moneyWithSign(operation)} ·{" "}
            {RECURRENCE_LABEL[operation.recurrence]}
          </span>
        </button>
        <label className="switch-label">
          <input
            type="checkbox"
            checked={active}
            onChange={(event) => onChange(event.target.checked ? {} : null)}
          />
          <span>Изменять</span>
        </label>
      </header>
      {active && (
        <div className="override-grid">
          <label>
            <span>Сумма, ₽</span>
            <input
              value={
                override.amountMinor === undefined
                  ? ""
                  : moneyInputValue(override.amountMinor)
              }
              placeholder={moneyInputValue(operation.amountMinor)}
              onChange={(event) => {
                const value = parseMoneyInput(event.target.value);
                const next = { ...override };
                if (value === null) delete next.amountMinor;
                else next.amountMinor = value;
                onChange(next);
              }}
            />
          </label>
          <label>
            <span>Частота</span>
            <select
              value={override.recurrence ?? operation.recurrence}
              onChange={(event) =>
                patch({ recurrence: event.target.value as Recurrence })
              }
            >
              <option value="daily">Ежедневно</option>
              <option value="weekly">Еженедельно</option>
              <option value="monthly">Ежемесячно</option>
              <option value="yearly">Ежегодно</option>
            </select>
          </label>
          <label>
            <span>Первая дата</span>
            <input
              type="date"
              value={override.firstDate ?? operation.firstDate}
              onChange={(event) => patch({ firstDate: event.target.value })}
            />
          </label>
          <label>
            <span>Повторять до</span>
            <input
              type="date"
              value={
                override.recurrenceEndDate ?? operation.recurrenceEndDate ?? ""
              }
              onChange={(event) =>
                patch({ recurrenceEndDate: event.target.value })
              }
            />
          </label>
          <label>
            <span>Точность</span>
            <select
              value={override.certainty ?? operation.certainty}
              onChange={(event) =>
                patch({
                  certainty: event.target.value as "certain" | "expected",
                })
              }
            >
              <option value="certain">100% точно</option>
              <option value="expected">Предполагается</option>
            </select>
          </label>
          <label className="exclude-check">
            <input
              type="checkbox"
              checked={override.excluded ?? false}
              onChange={(event) => patch({ excluded: event.target.checked })}
            />
            <span>Исключить серию из сценария</span>
          </label>
        </div>
      )}
    </article>
  );
}
