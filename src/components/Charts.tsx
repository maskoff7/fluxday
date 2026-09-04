/* eslint-disable react-refresh/only-export-components */
import { useMemo, useState, type PointerEvent } from "react";
import { formatCalendarDate } from "../domain/date";
import { formatCompactMoney, formatMoney } from "../domain/money";
import type { CalendarDate, SummaryGroup } from "../domain/types";

export interface ChartPoint {
  date: CalendarDate;
  primary: number;
  secondary?: number;
}

interface LineComparisonChartProps {
  points: ChartPoint[];
  primaryLabel: string;
  secondaryLabel?: string;
  primaryClass?: string;
  secondaryClass?: string;
  ariaLabel: string;
}

function niceStep(raw: number): number {
  if (!Number.isFinite(raw) || raw <= 0) return 1;
  const power = 10 ** Math.floor(Math.log10(raw));
  const fraction = raw / power;
  const nice =
    fraction <= 1
      ? 1
      : fraction <= 2
        ? 2
        : fraction <= 2.5
          ? 2.5
          : fraction <= 5
            ? 5
            : 10;
  return nice * power;
}

function sample(points: ChartPoint[], limit = 360): ChartPoint[] {
  if (points.length <= limit) return points;
  const indexes = new Set<number>([0, points.length - 1]);
  for (let index = 0; index < limit - 2; index += 1) {
    indexes.add(Math.round((index * (points.length - 1)) / (limit - 3)));
  }
  const values = points.flatMap((point, index) => [
    { index, value: point.primary },
    ...(point.secondary === undefined
      ? []
      : [{ index, value: point.secondary }]),
  ]);
  indexes.add(
    values.reduce((best, item) => (item.value < best.value ? item : best))
      .index,
  );
  indexes.add(
    values.reduce((best, item) => (item.value > best.value ? item : best))
      .index,
  );
  return [...indexes]
    .sort((left, right) => left - right)
    .map((index) => points[index]);
}

export function LineComparisonChart({
  points,
  primaryLabel,
  secondaryLabel,
  primaryClass = "chart-primary",
  secondaryClass = "chart-secondary",
  ariaLabel,
}: LineComparisonChartProps) {
  const [hovered, setHovered] = useState<number | null>(null);
  const sampled = useMemo(() => sample(points), [points]);
  if (sampled.length === 0)
    return <div className="empty-state">Нет данных для графика.</div>;

  const width = 1_080;
  const height = 310;
  const padding = { left: 82, right: 24, top: 22, bottom: 40 };
  const values = sampled.flatMap((point) => [
    point.primary,
    ...(point.secondary === undefined ? [] : [point.secondary]),
  ]);
  const rawMin = Math.min(0, ...values);
  const rawMax = Math.max(0, ...values);
  const step = niceStep(Math.max(1, rawMax - rawMin) / 5);
  const min = Math.floor(rawMin / step) * step;
  const max = Math.ceil(rawMax / step) * step || step;
  const x = (index: number) =>
    padding.left +
    (index / Math.max(1, sampled.length - 1)) *
      (width - padding.left - padding.right);
  const y = (value: number) =>
    padding.top +
    ((max - value) / Math.max(1, max - min)) *
      (height - padding.top - padding.bottom);
  const path = (key: "primary" | "secondary") =>
    sampled
      .filter((point) => key === "primary" || point.secondary !== undefined)
      .map(
        (point, index) =>
          `${index === 0 ? "M" : "L"}${x(index).toFixed(1)} ${y(point[key] ?? 0).toFixed(1)}`,
      )
      .join(" ");
  const ticks: number[] = [];
  for (let value = min; value <= max + step / 100; value += step)
    ticks.push(value);
  const active = hovered === null ? null : sampled[hovered];

  function onPointerMove(event: PointerEvent<SVGSVGElement>) {
    const rect = event.currentTarget.getBoundingClientRect();
    const cursor = ((event.clientX - rect.left) / rect.width) * width;
    const ratio = Math.max(
      0,
      Math.min(
        1,
        (cursor - padding.left) / (width - padding.left - padding.right),
      ),
    );
    setHovered(Math.round(ratio * (sampled.length - 1)));
  }

  return (
    <figure className="chart-figure" aria-label={ariaLabel}>
      <div className="chart-legend" aria-hidden="true">
        <span>
          <i className={primaryClass} />
          {primaryLabel}
        </span>
        {secondaryLabel && (
          <span>
            <i className={secondaryClass} />
            {secondaryLabel}
          </span>
        )}
      </div>
      <div className="chart-shell">
        <svg
          className="line-chart"
          viewBox={`0 0 ${width} ${height}`}
          preserveAspectRatio="none"
          onPointerMove={onPointerMove}
          onPointerLeave={() => setHovered(null)}
          role="img"
        >
          {min < 0 && (
            <rect
              className="negative-zone"
              x={padding.left}
              y={y(0)}
              width={width - padding.left - padding.right}
              height={height - padding.bottom - y(0)}
            />
          )}
          {ticks.map((tick) => (
            <g key={tick}>
              <line
                className={tick === 0 ? "zero-line" : "grid-line"}
                x1={padding.left}
                x2={width - padding.right}
                y1={y(tick)}
                y2={y(tick)}
              />
              <text
                className="axis-label"
                x={padding.left - 10}
                y={y(tick) + 4}
                textAnchor="end"
              >
                {formatCompactMoney(tick)}
              </text>
            </g>
          ))}
          <path className={`chart-path ${primaryClass}`} d={path("primary")} />
          {secondaryLabel && (
            <path
              className={`chart-path ${secondaryClass}`}
              d={path("secondary")}
            />
          )}
          {active && hovered !== null && (
            <>
              <line
                className="crosshair"
                x1={x(hovered)}
                x2={x(hovered)}
                y1={padding.top}
                y2={height - padding.bottom}
              />
              <circle
                className={`chart-point ${primaryClass}`}
                cx={x(hovered)}
                cy={y(active.primary)}
                r="5"
              />
              {active.secondary !== undefined && (
                <circle
                  className={`chart-point ${secondaryClass}`}
                  cx={x(hovered)}
                  cy={y(active.secondary)}
                  r="5"
                />
              )}
            </>
          )}
          {[0, Math.floor((sampled.length - 1) / 2), sampled.length - 1].map(
            (index) => (
              <text
                className="axis-label"
                key={index}
                x={x(index)}
                y={height - 10}
                textAnchor="middle"
              >
                {formatCalendarDate(sampled[index].date, {
                  day: "2-digit",
                  month: "short",
                })}
              </text>
            ),
          )}
        </svg>
        {active && hovered !== null && (
          <div
            className="chart-tooltip"
            style={{
              left: `${(x(hovered) / width) * 100}%`,
              top: `${Math.max(8, (y(active.primary) / height) * 100 - 4)}%`,
            }}
          >
            <strong>{formatCalendarDate(active.date)}</strong>
            <span>
              {primaryLabel}: {formatMoney(active.primary)}
            </span>
            {secondaryLabel && active.secondary !== undefined && (
              <span>
                {secondaryLabel}: {formatMoney(active.secondary)}
              </span>
            )}
            {active.secondary !== undefined && secondaryLabel && (
              <span>
                Разница:{" "}
                {formatMoney(active.secondary - active.primary, "RUB", true)}
              </span>
            )}
          </div>
        )}
      </div>
    </figure>
  );
}

const COLORS = [
  "#5b7cfa",
  "#31b48d",
  "#e5707c",
  "#d4a340",
  "#9b7bed",
  "#4fa7bd",
  "#ed8d55",
  "#6fa76e",
];

export function DonutChart({
  groups,
  selectedId,
  onSelect,
}: {
  groups: SummaryGroup[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  const radius = 74;
  const circumference = 2 * Math.PI * radius;
  if (!groups.length)
    return <div className="empty-state">В выбранном периоде нет операций.</div>;
  return (
    <div className="donut-shell">
      <svg
        className="donut"
        viewBox="0 0 200 200"
        role="img"
        aria-label="Структура выбранных операций"
      >
        <circle className="donut-track" cx="100" cy="100" r={radius} />
        {groups.map((group, index) => {
          const length = group.share * circumference;
          const currentOffset = groups
            .slice(0, index)
            .reduce((total, item) => total + item.share * circumference, 0);
          return (
            <circle
              key={group.id}
              className={`donut-segment ${selectedId === group.id ? "active" : ""}`}
              cx="100"
              cy="100"
              r={radius}
              stroke={COLORS[index % COLORS.length]}
              strokeDasharray={`${length} ${circumference - length}`}
              strokeDashoffset={-currentOffset}
              transform="rotate(-90 100 100)"
              tabIndex={0}
              role="button"
              aria-label={`${group.name}: ${formatMoney(group.totalMinor)}`}
              onClick={() => onSelect(group.id)}
              onKeyDown={(event) => {
                if (event.key === "Enter" || event.key === " ")
                  onSelect(group.id);
              }}
            />
          );
        })}
      </svg>
      <div className="donut-center" aria-hidden="true">
        <span>Структура</span>
        <strong>{groups.length}</strong>
        <span>операций</span>
      </div>
    </div>
  );
}

export function chartColor(index: number): string {
  return COLORS[index % COLORS.length];
}
