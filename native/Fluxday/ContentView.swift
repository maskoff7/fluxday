import CashFlowCore
import SwiftUI

private enum SidebarDestination: Hashable {
  case overview
  case operations
}

struct ContentView: View {
  @EnvironmentObject private var model: AppModel
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
    .frame(minWidth: 720, minHeight: 520)
  }

  private func createOperation() {
    editorIntent = .create
  }

  private func editOperation(_ operation: CashFlowCore.Operation) {
    editorIntent = OperationEditorIntent(mode: .edit, operation: operation)
  }

  private func duplicateOperation(_ operation: CashFlowCore.Operation) {
    editorIntent = OperationEditorIntent(mode: .duplicate, operation: operation)
  }
}
