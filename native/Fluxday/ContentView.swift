import SwiftUI

private enum SidebarDestination: Hashable {
  case overview
}

struct ContentView: View {
  @EnvironmentObject private var model: AppModel
  @State private var selection: SidebarDestination? = .overview

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Label("navigation.overview", systemImage: "chart.line.uptrend.xyaxis")
          .tag(SidebarDestination.overview)
      }
      .navigationTitle("app.name")
      .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    } detail: {
      OverviewView()
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
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
    .alert("persistence.error.title", isPresented: $model.showsPersistenceError) {
      Button("button.ok", role: .cancel) {}
    } message: {
      Text("persistence.error.message")
    }
  }
}

private struct OverviewView: View {
  @Environment(\.locale) private var locale

  var body: some View {
    ContentUnavailableView {
      Label("overview.empty.title", systemImage: "calendar.badge.clock")
    } description: {
      Text("overview.empty.message")
    }
    .navigationTitle(AppLocalization.string("overview.title", locale: locale))
  }
}
