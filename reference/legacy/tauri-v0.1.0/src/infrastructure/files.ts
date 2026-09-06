import { isTauri } from "@tauri-apps/api/core";
import { open, save } from "@tauri-apps/plugin-dialog";
import { readTextFile, writeTextFile } from "@tauri-apps/plugin-fs";

export async function chooseJsonFile(): Promise<string | null> {
  if (isTauri()) {
    const path = await open({
      multiple: false,
      directory: false,
      title: "Импорт плана Fluxday",
      filters: [{ name: "JSON", extensions: ["json"] }],
    });
    return typeof path === "string" ? readTextFile(path) : null;
  }
  return new Promise((resolve, reject) => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "application/json,.json";
    input.addEventListener("change", () => {
      const file = input.files?.[0];
      if (!file) return resolve(null);
      file.text().then(resolve, reject);
    });
    input.click();
  });
}

export async function saveJsonFile(
  contents: string,
  kind: "export" | "backup" = "export",
): Promise<boolean> {
  const date = new Date().toISOString().slice(0, 10);
  const filename = `fluxday-${kind}-${date}.json`;
  if (isTauri()) {
    const path = await save({
      title:
        kind === "backup" ? "Создать резервную копию" : "Экспортировать план",
      defaultPath: filename,
      filters: [{ name: "JSON", extensions: ["json"] }],
    });
    if (!path) return false;
    await writeTextFile(path, contents);
    return true;
  }
  const url = URL.createObjectURL(
    new Blob([contents], { type: "application/json" }),
  );
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  setTimeout(() => URL.revokeObjectURL(url), 0);
  return true;
}
