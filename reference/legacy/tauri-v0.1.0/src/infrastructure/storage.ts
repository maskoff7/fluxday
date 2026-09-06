import { invoke, isTauri } from "@tauri-apps/api/core";
import { emptyState, normalizeState } from "../domain/state";
import type { AppState } from "../domain/types";

const BROWSER_KEY = "fluxday_state_v1";

export interface LoadResult {
  state: AppState;
  isNew: boolean;
  warning: string | null;
}

export async function loadState(): Promise<LoadResult> {
  try {
    const payload = isTauri()
      ? await invoke<string | null>("load_snapshot")
      : globalThis.localStorage?.getItem(BROWSER_KEY);
    if (!payload) return { state: emptyState(), isNew: true, warning: null };
    return {
      state: normalizeState(JSON.parse(payload)),
      isNew: false,
      warning: null,
    };
  } catch (error) {
    return {
      state: emptyState(),
      isNew: true,
      warning: `Хранилище не удалось прочитать: ${error instanceof Error ? error.message : String(error)}`,
    };
  }
}

export async function saveState(state: AppState): Promise<void> {
  const payload = JSON.stringify(state);
  if (isTauri()) {
    await invoke("save_snapshot", { payload });
  } else {
    globalThis.localStorage?.setItem(BROWSER_KEY, payload);
  }
}

export const browserStorageKey = BROWSER_KEY;
