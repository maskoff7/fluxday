import CashFlowCore
import SwiftUI

private enum OperationFilter: CaseIterable, Identifiable {
  case all
  case income
  case expense
  case disabled

  var id: Self { self }

  var titleKey: LocalizedStringKey {
    switch self {
    case .all: "operations.filter.all"
    case .income: "operations.filter.income"
    case .expense: "operations.filter.expense"
    case .disabled: "operations.filter.disabled"
    }
  }
}

struct OperationsView: View {
  let addAction: () -> Void
  let editAction: (CashFlowCore.Operation) -> Void
  let duplicateAction: (CashFlowCore.Operation) -> Void

  @EnvironmentObject private var model: AppModel
  @Environment(\.locale) private var locale
  @State private var searchText = ""
  @State private var filter = OperationFilter.all
  @State private var pendingDeletion: CashFlowCore.Operation?

  private var operations: [CashFlowCore.Operation] {
    model.plan.operations
      .filter { operation in
        switch filter {
        case .all: true
        case .income: operation.type == .income
        case .expense: operation.type == .expense
        case .disabled: !operation.enabled
        }
      }
      .filter {
        searchText.isEmpty
          || $0.name.localizedStandardContains(searchText)
          || $0.note.localizedStandardContains(searchText)
      }
      .sorted {
        $0.firstDate != $1.firstDate ? $0.firstDate < $1.firstDate : $0.name < $1.name
      }
  }

  var body: some View {
    VStack(spacing: 0) {
      Picker("operations.filter.label", selection: $filter) {
        ForEach(OperationFilter.allCases) { value in
          Text(value.titleKey).tag(value)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: 480)
      .padding()

      Divider()

      if operations.isEmpty {
        ContentUnavailableView {
          Label(
            searchText.isEmpty ? "operations.empty.title" : "operations.search.empty",
            systemImage: searchText.isEmpty ? "tray" : "magnifyingglass"
          )
        } description: {
          if searchText.isEmpty { Text("operations.empty.message") }
        } actions: {
          if model.plan.operations.isEmpty {
            Button("operation.add", action: addAction)
              .buttonStyle(.borderedProminent)
          }
        }
      } else {
        List(operations) { operation in
          OperationRow(operation: operation)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { editAction(operation) }
            .contextMenu {
              Button("operation.edit") { editAction(operation) }
              Button("operation.duplicate") { duplicateAction(operation) }
              if operation.enabled {
                Button("operation.disable") { model.toggleOperation(operation) }
              } else {
                Button("operation.enable") { model.toggleOperation(operation) }
              }
              Divider()
              Button("operation.delete", role: .destructive) {
                pendingDeletion = operation
              }
            }
        }
        .listStyle(.inset)
      }
    }
    .navigationTitle(AppLocalization.string("operations.title", locale: locale))
    .searchable(text: $searchText, prompt: "operations.search")
    .alert(
      "operation.delete.title",
      isPresented: Binding(
        get: { pendingDeletion != nil },
        set: { if !$0 { pendingDeletion = nil } }
      ),
      presenting: pendingDeletion
    ) { operation in
      Button("operation.delete", role: .destructive) {
        model.deleteOperation(operation)
        pendingDeletion = nil
      }
      Button("button.cancel", role: .cancel) { pendingDeletion = nil }
    } message: { _ in
      Text("operation.delete.message")
    }
  }
}

private struct OperationRow: View {
  let operation: CashFlowCore.Operation
  @Environment(\.locale) private var locale

  var body: some View {
    HStack(spacing: 12) {
      Image(
        systemName: operation.type == .income
          ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill"
      )
      .font(.title2)
      .foregroundStyle(operation.type == .income ? .green : .orange)
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 7) {
          Text(operation.name)
            .font(.headline)
            .lineLimit(1)
          if operation.certainty == .expected {
            Text("operation.certainty.expected")
              .font(.caption2)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(.yellow.opacity(0.16), in: .capsule)
          }
          if !operation.enabled {
            Text("operation.disabled")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        HStack(spacing: 5) {
          Text(operation.firstDate.formatted(locale: locale))
          if operation.recurrence != .none {
            Text("·")
            Text(operation.recurrence.titleKey)
          }
          if !operation.note.isEmpty {
            Text("·")
            Text(operation.note)
              .lineLimit(1)
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer(minLength: 16)
      Text(
        operation.amountMinor.formatted(
          locale: locale,
          sign: operation.type == .income ? "+" : "−"
        )
      )
      .font(.headline.monospacedDigit())
      .foregroundStyle(operation.type == .income ? .green : .primary)
      .lineLimit(1)
      .minimumScaleFactor(0.75)
    }
    .opacity(operation.enabled ? 1 : 0.5)
    .padding(.vertical, 6)
    .accessibilityElement(children: .combine)
  }
}
