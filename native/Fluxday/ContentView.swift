import CashFlowCore
import SwiftUI

enum SidebarDestination: Hashable {
  case overview
  case operations
  case calendar
  case recurring
  case summary
  case scenarios
}

private struct NewOperationFocusedValueKey: FocusedValueKey {
  typealias Value = () -> Void
}

private struct NavigationFocusedValueKey: FocusedValueKey {
  typealias Value = (SidebarDestination) -> Void
}

extension FocusedValues {
  var newOperationAction: (() -> Void)? {
    get { self[NewOperationFocusedValueKey.self] }
    set { self[NewOperationFocusedValueKey.self] = newValue }
  }

  var navigationAction: ((SidebarDestination) -> Void)? {
    get { self[NavigationFocusedValueKey.self] }
    set { self[NavigationFocusedValueKey.self] = newValue }
  }
}

struct ContentView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.undoManager) private var undoManager
  @State private var selection: SidebarDestination? = .overview
  @State private var editorIntent: OperationEditorIntent?

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Label("navigation.overview", systemImage: "chart.line.uptrend.xyaxis")
          .tag(SidebarDestination.overview)
        Label("navigation.operations", systemImage: "list.bullet.rectangle")
          .badge(model.plan.operations.count)
          .tag(SidebarDestination.operations)
        Label("navigation.calendar", systemImage: "calendar")
          .tag(SidebarDestination.calendar)
        Label("navigation.recurring", systemImage: "repeat")
          .badge(model.plan.operations.filter { $0.recurrence != .none }.count)
          .tag(SidebarDestination.recurring)
        Label("navigation.summary", systemImage: "chart.pie")
          .tag(SidebarDestination.summary)
        Label("navigation.scenarios", systemImage: "square.stack.3d.up")
          .badge(model.plan.scenarios.count)
          .tag(SidebarDestination.scenarios)
      }
      .navigationTitle("app.name")
      .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    } detail: {
      switch selection ?? .overview {
      case .overview:
        OverviewView(addOperation: createOperation)
      case .operations:
        OperationsView(
          addAction: createOperation,
          editAction: editOperation,
          duplicateAction: duplicateOperation
        )
      case .calendar:
        CalendarView(
          addAction: createOperation(on:),
          editAction: editOperation
        )
      case .recurring:
        RecurringView(
          addAction: createRecurringOperation,
          editAction: editOperation,
          duplicateAction: duplicateOperation
        )
      case .summary:
        SummaryView()
      case .scenarios:
        ScenariosView()
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button(action: createOperation) {
          Label("operation.add", systemImage: "plus")
        }
        .keyboardShortcut("n", modifiers: .command)

        SettingsLink {
          Label("toolbar.settings", systemImage: "gearshape")
        }
      }
    }
    .overlay {
      if model.isLoading {
        ProgressView("persistence.loading")
          .padding()
          .background(.regularMaterial, in: .rect(cornerRadius: 12))
      }
    }
    .sheet(item: $model.migrationPreview) { preview in
      MigrationView(
        preview: preview,
        isImporting: model.isMigrating,
        importAction: { Task { await model.confirmMigration() } },
        laterAction: model.dismissMigration
      )
    }
    .sheet(item: $editorIntent) { intent in
      OperationEditor(intent: intent, saveAction: model.saveOperation)
    }
    .alert("persistence.error.title", isPresented: $model.showsPersistenceError) {
      Button("button.ok", role: .cancel) {}
    } message: {
      Text("persistence.error.message")
    }
    .alert("calculation.error.title", isPresented: $model.showsCalculationError) {
      Button("button.ok", role: .cancel) {}
    } message: {
      Text("calculation.error.message")
    }
    .focusedSceneValue(\.newOperationAction, createOperation)
    .focusedSceneValue(\.navigationAction) { selection = $0 }
    .onAppear { model.configureUndoManager(undoManager) }
    .frame(minWidth: 720, minHeight: 520)
  }

  private func createOperation() {
    editorIntent = .create
  }

  private func editOperation(_ operation: CashFlowCore.Operation) {
    editorIntent = OperationEditorIntent(
      mode: .edit,
      operation: operation,
      preferredDate: nil,
      preferredRecurrence: nil
    )
  }

  private func duplicateOperation(_ operation: CashFlowCore.Operation) {
    editorIntent = OperationEditorIntent(
      mode: .duplicate,
      operation: operation,
      preferredDate: nil,
      preferredRecurrence: nil
    )
  }

  private func createOperation(on date: CalendarDate) {
    editorIntent = .create(on: date)
  }

  private func createRecurringOperation() {
    editorIntent = .recurring
  }
}

struct FluxdayCommands: Commands {
  let locale: Locale

  @FocusedValue(\.newOperationAction) private var newOperationAction
  @FocusedValue(\.navigationAction) private var navigationAction

  var body: some Commands {
    CommandGroup(replacing: .newItem) {
      Button(AppLocalization.string("operation.add", locale: locale)) {
        newOperationAction?()
      }
      .keyboardShortcut("n", modifiers: .command)
      .disabled(newOperationAction == nil)
    }

    CommandMenu(AppLocalization.string("menu.navigate", locale: locale)) {
      navigationButton("navigation.overview", destination: .overview, shortcut: "1")
      navigationButton("navigation.operations", destination: .operations, shortcut: "2")
      navigationButton("navigation.calendar", destination: .calendar, shortcut: "3")
      navigationButton("navigation.recurring", destination: .recurring, shortcut: "4")
      navigationButton("navigation.summary", destination: .summary, shortcut: "5")
      navigationButton("navigation.scenarios", destination: .scenarios, shortcut: "6")
    }
  }

  private func navigationButton(
    _ titleKey: String,
    destination: SidebarDestination,
    shortcut: KeyEquivalent
  ) -> some View {
    Button(AppLocalization.string(titleKey, locale: locale)) {
      navigationAction?(destination)
    }
    .keyboardShortcut(shortcut, modifiers: .command)
    .disabled(navigationAction == nil)
  }
}
