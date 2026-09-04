/* eslint-disable react-refresh/only-export-components */
import {
  useEffect,
  useRef,
  useState,
  type FormEvent,
  type ReactNode,
} from "react";
import {
  defaultRecurrenceEnd,
  isCalendarDate,
  maxPlanningDate,
  todayCalendarDate,
} from "../domain/date";
import type { ImportPreview } from "../domain/import";
import { formatMoney, moneyInputValue, parseMoneyInput } from "../domain/money";
import type {
  Certainty,
  Operation,
  OperationType,
  Recurrence,
  Settings,
} from "../domain/types";

export function Modal({
  title,
  children,
  onClose,
  wide = false,
}: {
  title: string;
  children: ReactNode;
  onClose?: () => void;
  wide?: boolean;
}) {
  return (
    <div
      className="modal-backdrop"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose?.();
      }}
    >
      <section
        className={`modal-card ${wide ? "wide" : ""}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
      >
        <header className="modal-head">
          <h2 id="modal-title">{title}</h2>
          {onClose && (
            <button
              className="icon-button"
              onClick={onClose}
              aria-label="Закрыть"
            >
              ×
            </button>
          )}
        </header>
        {children}
      </section>
    </div>
  );
}

export interface EditorIntent {
  mode: "create" | "edit" | "duplicate";
  operation?: Operation;
}

export interface OperationInput {
  name: string;
  type: OperationType;
  amountMinor: number;
  certainty: Certainty;
  firstDate: string;
  recurrence: Recurrence;
  recurrenceEndDate: string | null;
  note: string;
}

function initialDraft(intent: EditorIntent) {
  const operation = intent.operation;
  return {
    name: operation
      ? `${operation.name}${intent.mode === "duplicate" ? " — копия" : ""}`
      : "",
    type: operation?.type ?? ("expense" as OperationType),
    amount: operation ? moneyInputValue(operation.amountMinor) : "",
    certainty: operation?.certainty ?? ("certain" as Certainty),
    firstDate: operation?.firstDate ?? todayCalendarDate(),
    recurrence: operation?.recurrence ?? ("none" as Recurrence),
    recurrenceEndDate: operation?.recurrenceEndDate ?? "",
    note: operation?.note ?? "",
  };
}

export function OperationEditor({
  intent,
  onClose,
  onSave,
}: {
  intent: EditorIntent;
  onClose: () => void;
  onSave: (input: OperationInput) => void;
}) {
  const [draft, setDraft] = useState(() => initialDraft(intent));
  const [error, setError] = useState("");
  const nameRef = useRef<HTMLInputElement>(null);
  useEffect(() => nameRef.current?.focus(), []);

  function submit(event: FormEvent) {
    event.preventDefault();
    const amountMinor = parseMoneyInput(draft.amount);
    if (!draft.name.trim())
      return setError("Добавьте понятное название операции.");
    if (amountMinor === null || amountMinor <= 0)
      return setError(
        "Введите положительную сумму, не более двух знаков после запятой.",
      );
    if (!isCalendarDate(draft.firstDate))
      return setError("Укажите существующую календарную дату.");
    if (draft.firstDate > maxPlanningDate(todayCalendarDate()))
      return setError(
        "Дата операции должна быть в пределах ближайших 100 лет.",
      );
    if (
      draft.recurrence !== "none" &&
      (!isCalendarDate(draft.recurrenceEndDate) ||
        draft.recurrenceEndDate < draft.firstDate)
    ) {
      return setError(
        "Конечная дата повторения должна быть не раньше первой даты.",
      );
    }
    if (
      draft.recurrence !== "none" &&
      draft.recurrenceEndDate > maxPlanningDate(draft.firstDate)
    ) {
      return setError("Серия не может планироваться более чем на 100 лет.");
    }
    onSave({
      name: draft.name.trim(),
      type: draft.type,
      amountMinor,
      certainty: draft.certainty,
      firstDate: draft.firstDate,
      recurrence: draft.recurrence,
      recurrenceEndDate:
        draft.recurrence === "none" ? null : draft.recurrenceEndDate,
      note: draft.note.trim(),
    });
  }

  return (
    <Modal
      title={
        intent.mode === "edit"
          ? "Редактировать операцию"
          : intent.mode === "duplicate"
            ? "Дублировать операцию"
            : "Новая операция"
      }
      onClose={onClose}
    >
      <form className="dialog-form" onSubmit={submit}>
        <label className="field full">
          <span>Название</span>
          <input
            ref={nameRef}
            value={draft.name}
            onChange={(event) =>
              setDraft({ ...draft, name: event.target.value })
            }
            placeholder="Зарплата, аренда, поездка…"
            maxLength={160}
          />
        </label>
        <label className="field">
          <span>Тип</span>
          <select
            value={draft.type}
            onChange={(event) =>
              setDraft({ ...draft, type: event.target.value as OperationType })
            }
          >
            <option value="expense">Расход</option>
            <option value="income">Доход</option>
          </select>
        </label>
        <label className="field">
          <span>Точность</span>
          <select
            value={draft.certainty}
            onChange={(event) =>
              setDraft({ ...draft, certainty: event.target.value as Certainty })
            }
          >
            <option value="certain">100% точно</option>
            <option value="expected">Предполагается</option>
          </select>
        </label>
        <label className="field">
          <span>Сумма, ₽</span>
          <input
            value={draft.amount}
            onChange={(event) =>
              setDraft({ ...draft, amount: event.target.value })
            }
            inputMode="decimal"
            placeholder="0,00"
          />
        </label>
        <label className="field">
          <span>Первая дата</span>
          <input
            type="date"
            value={draft.firstDate}
            onChange={(event) => {
              const firstDate = event.target.value;
              setDraft({
                ...draft,
                firstDate,
                recurrenceEndDate:
                  draft.recurrence === "none" || !isCalendarDate(firstDate)
                    ? draft.recurrenceEndDate
                    : (defaultRecurrenceEnd(firstDate, draft.recurrence) ?? ""),
              });
            }}
          />
        </label>
        <label className="field full">
          <span>Повторение</span>
          <select
            value={draft.recurrence}
            onChange={(event) => {
              const recurrence = event.target.value as Recurrence;
              setDraft({
                ...draft,
                recurrence,
                recurrenceEndDate:
                  defaultRecurrenceEnd(draft.firstDate, recurrence) ?? "",
              });
            }}
          >
            <option value="none">Не повторяется</option>
            <option value="daily">Ежедневно</option>
            <option value="weekly">Еженедельно</option>
            <option value="monthly">Ежемесячно</option>
            <option value="yearly">Ежегодно</option>
          </select>
        </label>
        {draft.recurrence !== "none" && (
          <label className="field full">
            <span>Повторять до (включительно)</span>
            <input
              type="date"
              value={draft.recurrenceEndDate}
              onChange={(event) =>
                setDraft({ ...draft, recurrenceEndDate: event.target.value })
              }
            />
            <small>
              Автоматически предложен разумный период; дату можно изменить.
            </small>
          </label>
        )}
        <label className="field full">
          <span>Комментарий</span>
          <textarea
            value={draft.note}
            onChange={(event) =>
              setDraft({ ...draft, note: event.target.value })
            }
            placeholder="Необязательно"
            maxLength={500}
            rows={3}
          />
        </label>
        {error && (
          <p className="form-error" role="alert">
            {error}
          </p>
        )}
        <footer className="dialog-actions">
          <button type="button" className="button secondary" onClick={onClose}>
            Отмена
          </button>
          <button className="button primary" type="submit">
            {intent.mode === "edit" ? "Сохранить" : "Добавить"}
          </button>
        </footer>
      </form>
    </Modal>
  );
}

export function SettingsDialog({
  settings,
  onClose,
  onSave,
  onReset,
}: {
  settings: Settings;
  onClose: () => void;
  onSave: (balance: number, date: string) => void;
  onReset: () => void;
}) {
  const [balance, setBalance] = useState(
    moneyInputValue(settings.startBalanceMinor),
  );
  const [date, setDate] = useState(settings.startDate);
  const [error, setError] = useState("");
  return (
    <Modal title="Настройки плана" onClose={onClose}>
      <form
        className="dialog-form"
        onSubmit={(event) => {
          event.preventDefault();
          const parsed = parseMoneyInput(balance, true);
          if (
            parsed === null ||
            !isCalendarDate(date) ||
            date > maxPlanningDate(todayCalendarDate())
          )
            return setError("Проверьте стартовый остаток и дату.");
          onSave(parsed, date);
        }}
      >
        <label className="field full">
          <span>Текущий остаток, ₽</span>
          <input
            autoFocus
            value={balance}
            onChange={(event) => setBalance(event.target.value)}
            inputMode="decimal"
          />
        </label>
        <label className="field full">
          <span>Дата старта расчёта</span>
          <input
            type="date"
            value={date}
            onChange={(event) => setDate(event.target.value)}
          />
        </label>
        <div className="setting-note">
          Базовая валюта — RUB. Все суммы хранятся в целых копейках.
        </div>
        {error && (
          <p className="form-error" role="alert">
            {error}
          </p>
        )}
        <footer className="dialog-actions split">
          <button
            type="button"
            className="button danger-quiet"
            onClick={onReset}
          >
            Очистить все данные…
          </button>
          <span />
          <button type="button" className="button secondary" onClick={onClose}>
            Отмена
          </button>
          <button className="button primary" type="submit">
            Сохранить
          </button>
        </footer>
      </form>
    </Modal>
  );
}

export function ImportPreviewDialog({
  preview,
  hasExistingData,
  onClose,
  onConfirm,
}: {
  preview: ImportPreview;
  hasExistingData: boolean;
  onClose: () => void;
  onConfirm: () => void;
}) {
  return (
    <Modal title="Предпросмотр импорта" onClose={onClose}>
      <div className="import-preview">
        <div className="import-source">
          <span>Источник</span>
          <strong>{preview.source}</strong>
        </div>
        <div className="preview-grid">
          <div>
            <strong>{preview.operationCount}</strong>
            <span>операций</span>
          </div>
          <div>
            <strong>{preview.recurringCount}</strong>
            <span>повторяющихся</span>
          </div>
          <div>
            <strong>{preview.scenarioCount}</strong>
            <span>сценариев</span>
          </div>
        </div>
        {preview.warnings.length > 0 && (
          <div className="warning-box">
            <strong>Нужна проверка</strong>
            {preview.warnings.slice(0, 5).map((warning) => (
              <span key={warning}>{warning}</span>
            ))}
          </div>
        )}
        {hasExistingData && (
          <p className="replace-warning">
            Подтверждение заменит текущий план. Сначала создайте резервную
            копию, если он нужен.
          </p>
        )}
        <p className="muted-copy">
          Повторный импорт того же файла безопасен: план заменяется целиком,
          дубликаты не накапливаются.
        </p>
        <footer className="dialog-actions">
          <button className="button secondary" onClick={onClose}>
            Отмена
          </button>
          <button className="button primary" onClick={onConfirm}>
            Импортировать и заменить
          </button>
        </footer>
      </div>
    </Modal>
  );
}

export function Onboarding({
  onImport,
  onFresh,
  onDemo,
}: {
  onImport: () => void;
  onFresh: () => void;
  onDemo: () => void;
}) {
  return (
    <Modal title="Добро пожаловать в Fluxday" wide>
      <div className="onboarding">
        <div className="onboarding-mark">
          <span>F</span>
        </div>
        <h3>Увидьте будущий остаток до того, как он станет проблемой.</h3>
        <p>
          Fluxday работает полностью на этом Mac: без аккаунта, облака и
          аналитики.
        </p>
        <div className="onboarding-actions">
          <button
            className="onboarding-choice primary-choice"
            onClick={onImport}
          >
            <strong>Импортировать Cash Flow Planner</strong>
            <span>
              Выберите JSON из старого HTML и сначала проверьте предпросмотр.
            </span>
          </button>
          <button className="onboarding-choice" onClick={onFresh}>
            <strong>Начать с чистого плана</strong>
            <span>Укажите остаток и добавьте первую операцию.</span>
          </button>
          <button className="onboarding-choice" onClick={onDemo}>
            <strong>Посмотреть пример</strong>
            <span>
              Готовый набор с зарплатой, арендой, кассовым разрывом и
              сценариями.
            </span>
          </button>
        </div>
      </div>
    </Modal>
  );
}

export function DeleteConfirmation({
  name,
  onClose,
  onConfirm,
}: {
  name: string;
  onClose: () => void;
  onConfirm: () => void;
}) {
  return (
    <Modal title="Очистить все данные?" onClose={onClose}>
      <div className="import-preview">
        <p>
          Будут удалены {name}. Это действие нельзя отменить после перезапуска
          приложения.
        </p>
        <footer className="dialog-actions">
          <button className="button secondary" onClick={onClose}>
            Отмена
          </button>
          <button className="button danger" onClick={onConfirm}>
            Удалить всё
          </button>
        </footer>
      </div>
    </Modal>
  );
}

export function moneyWithSign(operation: Operation): string {
  return `${operation.type === "income" ? "+" : "−"}${formatMoney(operation.amountMinor)}`;
}
