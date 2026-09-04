import { useEffect, useRef, useState } from "react";
import {
  DeleteConfirmation,
  ImportPreviewDialog,
  Onboarding,
  OperationEditor,
  SettingsDialog,
  type EditorIntent,
  type OperationInput,
} from "./components/Dialogs";
import {
  BalanceView,
  CalendarView,
  KpiStrip,
  RecurringView,
  ScenarioView,
  SummaryView,
  TimelineView,
} from "./components/Views";
import {
  startOfMonth,
  formatCalendarDate,
  todayCalendarDate,
} from "./domain/date";
import { buildForecast } from "./domain/forecast";
import {
  exportPayload,
  parseImportText,
  type ImportPreview,
} from "./domain/import";
import { sampleState } from "./domain/sample";
import { emptyState, makeOperation, makeScenario } from "./domain/state";
import type {
  AppState,
  CalendarDate,
  Operation,
  ScenarioOverride,
} from "./domain/types";
import { chooseJsonFile, saveJsonFile } from "./infrastructure/files";
import { loadState, saveState } from "./infrastructure/storage";
import "./theme.css";

type View =
  "timeline" | "balance" | "calendar" | "recurring" | "summary" | "scenarios";

const NAVIGATION: { id: View; label: string; symbol: string }[] = [
  { id: "timeline", label: "Таймлайн", symbol: "↕" },
  { id: "balance", label: "Динамика", symbol: "⌁" },
  { id: "calendar", label: "Календарь", symbol: "□" },
  { id: "recurring", label: "Повторяющиеся", symbol: "↻" },
  { id: "summary", label: "Свод", symbol: "◒" },
  { id: "scenarios", label: "Сценарии", symbol: "◇" },
];

function cloneState(state: AppState): AppState {
  return structuredClone(state);
}

function App() {
  const [state, setState] = useState<AppState | null>(null);
  const [view, setView] = useState<View>("timeline");
  const [query, setQuery] = useState("");
  const [editor, setEditor] = useState<EditorIntent | null>(null);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [importPreview, setImportPreview] = useState<ImportPreview | null>(
    null,
  );
  const [resetOpen, setResetOpen] = useState(false);
  const [saveStatus, setSaveStatus] = useState<
    "loading" | "saving" | "saved" | "error"
  >("loading");
  const [toast, setToast] = useState<{
    message: string;
    undo?: boolean;
  } | null>(null);
  const [calendarMonth, setCalendarMonth] = useState(
    startOfMonth(todayCalendarDate()),
  );
  const [selectedDate, setSelectedDate] = useState(todayCalendarDate());
  const [selectedScenarioId, setSelectedScenarioId] = useState<string | null>(
    null,
  );
  const searchRef = useRef<HTMLInputElement>(null);
  const undoRef = useRef<AppState | null>(null);
  const hydrated = useRef(false);

  useEffect(() => {
    void loadState().then((result) => {
      setState(result.state);
      setSelectedScenarioId(result.state.scenarios[0]?.id ?? null);
      setSaveStatus(result.warning ? "error" : "saved");
      if (result.warning) setToast({ message: result.warning });
    });
  }, []);

  useEffect(() => {
    if (!state) return;
    if (!hydrated.current) {
      hydrated.current = true;
      return;
    }
    setSaveStatus("saving");
    const timer = window.setTimeout(() => {
      void saveState(state).then(
        () => setSaveStatus("saved"),
        () => setSaveStatus("error"),
      );
    }, 250);
    return () => window.clearTimeout(timer);
  }, [state]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 4_500);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    function shortcut(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setEditor(null);
        setSettingsOpen(false);
        setImportPreview(null);
      }
      if (!(event.metaKey || event.ctrlKey)) return;
      if (event.key.toLowerCase() === "n") {
        event.preventDefault();
        setEditor({ mode: "create" });
      }
      if (event.key.toLowerCase() === "f") {
        event.preventDefault();
        searchRef.current?.focus();
      }
      if (event.key.toLowerCase() === "s" && state) {
        event.preventDefault();
        void saveJsonFile(exportPayload(state), "backup").then(
          (saved) =>
            saved && setToast({ message: "Резервная копия сохранена." }),
        );
      }
      if (event.key.toLowerCase() === "z" && undoRef.current) {
        event.preventDefault();
        setState(undoRef.current);
        undoRef.current = null;
        setToast({ message: "Изменение отменено." });
      }
    }
    window.addEventListener("keydown", shortcut);
    return () => window.removeEventListener("keydown", shortcut);
  }, [state]);

  function mutate(recipe: (draft: AppState) => void, undoable = true) {
    setState((current) => {
      if (!current) return current;
      if (undoable) undoRef.current = cloneState(current);
      const next = cloneState(current);
      recipe(next);
      return next;
    });
  }

  async function beginImport() {
    try {
      const text = await chooseJsonFile();
      if (text) setImportPreview(parseImportText(text));
    } catch (error) {
      setToast({
        message: error instanceof Error ? error.message : String(error),
      });
    }
  }

  function saveOperation(input: OperationInput) {
    mutate((draft) => {
      if (editor?.mode === "edit" && editor.operation) {
        const index = draft.operations.findIndex(
          (item) => item.id === editor.operation?.id,
        );
        if (index >= 0) {
          draft.operations[index] = {
            ...draft.operations[index],
            ...input,
            updatedAt: new Date().toISOString(),
          };
        }
      } else {
        draft.operations.unshift(makeOperation(input));
      }
      draft.settings.preferences.onboardingComplete = true;
    });
    setEditor(null);
    setToast({
      message:
        editor?.mode === "edit" ? "Операция обновлена." : "Операция добавлена.",
      undo: true,
    });
  }

  function deleteOperation(operation: Operation) {
    mutate((draft) => {
      draft.operations = draft.operations.filter(
        (item) => item.id !== operation.id,
      );
      draft.scenarios.forEach(
        (scenario) => delete scenario.overrides[operation.id],
      );
    });
    setToast({ message: `«${operation.name}» удалена.`, undo: true });
  }

  function undo() {
    if (!undoRef.current) return;
    setState(undoRef.current);
    undoRef.current = null;
    setToast({ message: "Изменение отменено." });
  }

  if (!state) {
    return (
      <div className="loading-screen">
        <div className="brand-mark">F</div>
        <strong>Fluxday</strong>
        <span>Открываем локальный план…</span>
      </div>
    );
  }

  const forecast = buildForecast(
    state.settings.startBalanceMinor,
    state.settings.startDate,
    state.operations,
  );
  const activeScenario =
    state.scenarios.find((item) => item.id === selectedScenarioId) ?? null;
  const pageTitle =
    NAVIGATION.find((item) => item.id === view)?.label ?? "Fluxday";

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">F</div>
          <div>
            <strong>Fluxday</strong>
            <span>Cash flow, день за днём</span>
          </div>
        </div>
        <button
          className="button primary new-operation"
          onClick={() => setEditor({ mode: "create" })}
        >
          <span>＋</span> Новая операция <kbd>⌘N</kbd>
        </button>
        <nav aria-label="Основные разделы">
          {NAVIGATION.map((item) => (
            <button
              className={view === item.id ? "active" : ""}
              key={item.id}
              onClick={() => setView(item.id)}
            >
              <span className="nav-symbol">{item.symbol}</span>
              {item.label}
              {item.id === "recurring" && (
                <em>
                  {
                    state.operations.filter(
                      (operation) => operation.recurrence !== "none",
                    ).length
                  }
                </em>
              )}
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="privacy-note">
            <span>●</span>
            <div>
              <strong>Только на этом Mac</strong>
              <small>SQLite · без облака и аналитики</small>
            </div>
          </div>
          <button
            className="settings-button"
            onClick={() => setSettingsOpen(true)}
          >
            ⚙ Настройки
          </button>
        </div>
      </aside>
      <main className="workspace">
        <header className="topbar">
          <div>
            <span className="eyebrow">
              План с {formatCalendarDate(state.settings.startDate)}
            </span>
            <h1>{pageTitle}</h1>
          </div>
          <div className="top-actions">
            <label className="search-box">
              <span>⌕</span>
              <input
                ref={searchRef}
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Поиск операций"
                aria-label="Поиск операций"
              />
              <kbd>⌘F</kbd>
            </label>
            <span className={`save-status ${saveStatus}`}>
              <i />
              {saveStatus === "loading"
                ? "Загрузка"
                : saveStatus === "saving"
                  ? "Сохраняем"
                  : saveStatus === "saved"
                    ? "Сохранено"
                    : "Ошибка сохранения"}
            </span>
            <button
              className="button secondary"
              onClick={() =>
                void saveJsonFile(exportPayload(state), "backup").then(
                  (saved) =>
                    saved &&
                    setToast({ message: "Резервная копия сохранена." }),
                )
              }
            >
              Backup
            </button>
            <button
              className="icon-button more-button"
              onClick={() => setSettingsOpen(true)}
              aria-label="Открыть настройки"
            >
              •••
            </button>
          </div>
        </header>
        <KpiStrip forecast={forecast} />
        <div className="view-content">
          {view === "timeline" && (
            <TimelineView
              forecast={forecast}
              query={query}
              onEdit={(operation) => setEditor({ mode: "edit", operation })}
              onDuplicate={(operation) =>
                setEditor({ mode: "duplicate", operation })
              }
              onDelete={deleteOperation}
              onOpenScenarios={() => {
                setView("scenarios");
                if (!activeScenario && state.scenarios[0])
                  setSelectedScenarioId(state.scenarios[0].id);
              }}
            />
          )}
          {view === "balance" && <BalanceView forecast={forecast} />}
          {view === "calendar" && (
            <CalendarView
              forecast={forecast}
              month={calendarMonth}
              selectedDate={selectedDate}
              onMonth={(date: CalendarDate) => {
                setCalendarMonth(startOfMonth(date));
                setSelectedDate(startOfMonth(date));
              }}
              onSelect={setSelectedDate}
              onEdit={(operation) => setEditor({ mode: "edit", operation })}
            />
          )}
          {view === "recurring" && (
            <RecurringView
              operations={state.operations}
              onEdit={(operation) => setEditor({ mode: "edit", operation })}
              onDuplicate={(operation) =>
                setEditor({ mode: "duplicate", operation })
              }
              onDelete={deleteOperation}
              onToggle={(operation) => {
                mutate((draft) => {
                  const item = draft.operations.find(
                    (candidate) => candidate.id === operation.id,
                  );
                  if (item) item.enabled = !item.enabled;
                });
                setToast({
                  message: operation.enabled
                    ? "Серия временно отключена."
                    : "Серия включена.",
                  undo: true,
                });
              }}
            />
          )}
          {view === "summary" && <SummaryView operations={state.operations} />}
          {view === "scenarios" && (
            <ScenarioView
              state={state}
              selectedId={selectedScenarioId}
              onSelect={setSelectedScenarioId}
              onCreate={(name) => {
                const scenario = makeScenario(name);
                mutate((draft) => draft.scenarios.push(scenario));
                setSelectedScenarioId(scenario.id);
              }}
              onRemove={() => {
                if (!activeScenario) return;
                mutate((draft) => {
                  draft.scenarios = draft.scenarios.filter(
                    (item) => item.id !== activeScenario.id,
                  );
                });
                setSelectedScenarioId(
                  state.scenarios.find((item) => item.id !== activeScenario.id)
                    ?.id ?? null,
                );
                setToast({ message: "Сценарий удалён.", undo: true });
              }}
              onRename={(name) =>
                mutate((draft) => {
                  const scenario = draft.scenarios.find(
                    (item) => item.id === selectedScenarioId,
                  );
                  if (scenario) scenario.name = name.trim().slice(0, 80);
                })
              }
              onOverride={(
                operationId: string,
                override: ScenarioOverride | null,
              ) =>
                mutate((draft) => {
                  const scenario = draft.scenarios.find(
                    (item) => item.id === selectedScenarioId,
                  );
                  if (!scenario) return;
                  if (override) scenario.overrides[operationId] = override;
                  else delete scenario.overrides[operationId];
                })
              }
              onOpenOperation={(operation) =>
                setEditor({ mode: "edit", operation })
              }
            />
          )}
        </div>
      </main>
      {editor && (
        <OperationEditor
          key={`${editor.mode}-${editor.operation?.id ?? "new"}`}
          intent={editor}
          onClose={() => setEditor(null)}
          onSave={saveOperation}
        />
      )}
      {settingsOpen && (
        <SettingsDialog
          settings={state.settings}
          onClose={() => setSettingsOpen(false)}
          onSave={(balance, date) => {
            mutate((draft) => {
              draft.settings.startBalanceMinor = balance;
              draft.settings.startDate = date;
            });
            setSettingsOpen(false);
            setToast({ message: "Настройки сохранены.", undo: true });
          }}
          onReset={() => setResetOpen(true)}
        />
      )}
      {resetOpen && (
        <DeleteConfirmation
          name="операции, сценарии и настройки"
          onClose={() => setResetOpen(false)}
          onConfirm={() => {
            const fresh = emptyState();
            fresh.settings.preferences.onboardingComplete = true;
            undoRef.current = cloneState(state);
            setState(fresh);
            setResetOpen(false);
            setSettingsOpen(false);
            setToast({ message: "План очищен.", undo: true });
          }}
        />
      )}
      {!state.settings.preferences.onboardingComplete && (
        <Onboarding
          onImport={() => void beginImport()}
          onFresh={() => {
            mutate((draft) => {
              draft.settings.preferences.onboardingComplete = true;
            }, false);
            setSettingsOpen(true);
          }}
          onDemo={() => {
            undoRef.current = cloneState(state);
            const demo = sampleState();
            setState(demo);
            setSelectedScenarioId(demo.scenarios[0].id);
            setToast({
              message: "Добавлен демонстрационный план.",
              undo: true,
            });
          }}
        />
      )}
      {importPreview && (
        <ImportPreviewDialog
          preview={importPreview}
          hasExistingData={state.operations.length > 0}
          onClose={() => setImportPreview(null)}
          onConfirm={() => {
            undoRef.current = cloneState(state);
            setState(importPreview.state);
            setSelectedScenarioId(importPreview.state.scenarios[0]?.id ?? null);
            setImportPreview(null);
            setToast({
              message: `Импортировано ${importPreview.operationCount} операций.`,
              undo: true,
            });
          }}
        />
      )}
      <div className="floating-tools">
        <button onClick={() => void beginImport()}>Импорт</button>
        <button
          onClick={() =>
            void saveJsonFile(exportPayload(state), "export").then(
              (saved) => saved && setToast({ message: "Экспорт сохранён." }),
            )
          }
        >
          Экспорт
        </button>
      </div>
      {toast && (
        <div className="toast" role="status">
          <span>{toast.message}</span>
          {toast.undo && <button onClick={undo}>Отменить</button>}
          <button
            className="toast-close"
            onClick={() => setToast(null)}
            aria-label="Закрыть"
          >
            ×
          </button>
        </div>
      )}
    </div>
  );
}

export default App;
