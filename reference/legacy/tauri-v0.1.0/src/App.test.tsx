import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, expect, it } from "vitest";
import App from "./App";
import { sampleState } from "./domain/sample";
import { browserStorageKey } from "./infrastructure/storage";

beforeEach(() => localStorage.clear());

it("offers legacy import on first launch", async () => {
  render(<App />);
  expect(await screen.findByText("Добро пожаловать в Fluxday")).toBeTruthy();
  expect(
    screen.getByRole("button", { name: /Импортировать Cash Flow Planner/ }),
  ).toBeTruthy();
});

it("creates and removes an operation with recoverable undo", async () => {
  const user = userEvent.setup();
  localStorage.setItem(
    browserStorageKey,
    JSON.stringify(sampleState("2026-09-04")),
  );
  render(<App />);
  await screen.findAllByText("Зарплата");

  await user.click(screen.getByRole("button", { name: /Новая операция/ }));
  await user.type(screen.getByLabelText("Название"), "Разовый доход");
  await user.selectOptions(screen.getByLabelText("Тип"), "income");
  await user.type(screen.getByLabelText("Сумма, ₽"), "1234.56");
  await user.click(screen.getByRole("button", { name: "Добавить" }));

  const created = await screen.findByText("Разовый доход");
  const row = created.closest("article");
  expect(row).toBeTruthy();
  await user.click(within(row!).getByRole("button", { name: "Удалить" }));
  expect(screen.queryByText("Разовый доход")).toBeNull();
  await user.click(screen.getByRole("button", { name: "Отменить" }));
  expect(await screen.findByText("Разовый доход")).toBeTruthy();
});

it("opens every primary workspace from keyboard-accessible navigation", async () => {
  const user = userEvent.setup();
  localStorage.setItem(
    browserStorageKey,
    JSON.stringify(sampleState("2026-09-04")),
  );
  render(<App />);
  await screen.findAllByText("Зарплата");

  for (const name of [
    "Динамика",
    "Календарь",
    "Повторяющиеся",
    "Свод",
    "Сценарии",
  ]) {
    await user.click(screen.getByRole("button", { name: new RegExp(name) }));
    expect(screen.getByRole("heading", { name, level: 1 })).toBeTruthy();
  }
});

it("edits and temporarily disables a recurring series", async () => {
  const user = userEvent.setup();
  localStorage.setItem(
    browserStorageKey,
    JSON.stringify(sampleState("2026-09-04")),
  );
  render(<App />);
  const salary = (await screen.findAllByText("Зарплата"))[0];
  const row = salary.closest("article");
  expect(row).toBeTruthy();
  await user.click(within(row!).getByRole("button", { name: "Изменить" }));
  const amount = screen.getByLabelText("Сумма, ₽");
  await user.clear(amount);
  await user.type(amount, "200000");
  await user.click(screen.getByRole("button", { name: "Сохранить" }));
  expect((await screen.findAllByText("+200 000 ₽")).length).toBeGreaterThan(0);

  await user.click(screen.getByRole("button", { name: /Повторяющиеся/ }));
  const recurringSalary = screen.getByText("Зарплата").closest("article");
  expect(recurringSalary).toBeTruthy();
  await user.click(
    within(recurringSalary!).getByRole("button", { name: "Отключить" }),
  );
  expect(within(recurringSalary!).getByText("Отключено")).toBeTruthy();
});
