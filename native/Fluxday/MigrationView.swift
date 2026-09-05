import FluxdayPersistence
import SwiftUI

struct MigrationView: View {
  let preview: LegacyMigrationPreview
  let isImporting: Bool
  let importAction: () -> Void
  let laterAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Label("migration.title", systemImage: "externaldrive.badge.checkmark")
        .font(.title2.weight(.semibold))

      Text("migration.message")
        .foregroundStyle(.secondary)

      Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
        row("migration.operations", value: preview.operationCount)
        row("migration.recurring", value: preview.recurringCount)
        row("migration.scenarios", value: preview.scenarioCount)
      }

      Text("migration.safety")
        .font(.callout)
        .foregroundStyle(.secondary)

      HStack {
        Spacer()
        Button("migration.later", action: laterAction)
          .keyboardShortcut(.cancelAction)
        Button(action: importAction) {
          if isImporting {
            ProgressView()
              .controlSize(.small)
          } else {
            Text("migration.import")
          }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(isImporting)
      }
    }
    .padding(24)
    .frame(width: 460)
    .interactiveDismissDisabled(isImporting)
  }

  private func row(_ title: LocalizedStringKey, value: Int) -> some View {
    GridRow {
      Text(title)
      Text(value, format: .number)
        .monospacedDigit()
    }
  }
}
