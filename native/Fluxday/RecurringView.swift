import CashFlowCore
import SwiftUI

private enum RecurringFilter: CaseIterable, Identifiable {
  case all
  case income
  case expense
  case disabled

  var id: Self { self }

  var titleKey: LocalizedStringKey {
    switch self {
    case .all: "recurring.filter.all"
    case .income: "recurring.filter.income"
    case .expense: "recurring.filter.expense"
    case .disabled: "recurring.filter.disabled"
    }
  }
}

struct RecurringView: View {
  let addAction: () -> Void
  let editAction: (CashFlowCore.Operation) -> Void
  let duplicateAction: (CashFlowCore.Operation) -> Void

  @EnvironmentObject private var model: AppModel
  @Environment(\.locale) private var locale
  @State private var searchText = ""
  @State private var filter = RecurringFilter.all
  @State private var pendingDeletion: CashFlowCore.Operation?

  private var operations: [CashFlowCore.Operation] {
    model.plan.operations
      .filter { $0.recurrence != .none }
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
        $0.type != $1.type ? $0.type == .expense : $0.name < $1.name
      }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Picker("recurring.filter.label", selection: $filter) {
          ForEach(RecurringFilter.allCases) { value in
            Text(value.titleKey).tag(value)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 480)
        Spacer()
        ViewThatFits(in: .horizontal) {
          addButton(labelStyle: .titleAndIcon)
          addButton(labelStyle: .iconOnly)
        }
      }
      .padding()

      Divider()

      if operations.isEmpty {
        ContentUnavailableView {
          Label(
            searchText.isEmpty ? "recurring.empty.title" : "recurring.search.empty",
            systemImage: searchText.isEmpty ? "repeat" : "magnifyingglass"
          )
        } description: {
          if searchText.isEmpty { Text("recurring.empty.message") }
        } actions: {
          if model.plan.operations.allSatisfy({ $0.recurrence == .none }) {
            Button("recurring.add", action: addAction)
              .buttonStyle(.borderedProminent)
          }
        }
      } else {
        List {
          recurringSection(type: .expense, title: "recurring.expenses")
          recurringSection(type: .income, title: "recurring.income")
        }
        .listStyle(.inset)
      }
    }
    .navigationTitle(AppLocalization.string("recurring.title", locale: locale))
    .searchable(text: $searchText, prompt: "recurring.search")
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

  private func addButton<Style: LabelStyle>(labelStyle: Style) -> some View {
    Button(action: addAction) {
      Label("recurring.add", systemImage: "plus")
        .labelStyle(labelStyle)
    }
    .buttonStyle(.borderedProminent)
    .fixedSize()
    .help("recurring.add")
  }

  @ViewBuilder
  private func recurringSection(
    type: OperationType,
    title: LocalizedStringKey
  ) -> some View {
    let items = operations.filter { $0.type == type }
    if !items.isEmpty {
      Section(title) {
        ForEach(items) { operation in
          RecurringRow(
            operation: operation,
            nextDate: try? RecurrenceEngine.nextOccurrenceDate(
              for: operation,
              onOrAfter: Date().calendarDate
            ),
            locale: locale,
            editAction: { editAction(operation) },
            duplicateAction: { duplicateAction(operation) },
            toggleAction: { model.toggleOperation(operation) },
            deleteAction: { pendingDeletion = operation }
          )
          .contentShape(Rectangle())
          .onTapGesture(count: 2) { editAction(operation) }
        }
      }
    }
  }
}

private struct RecurringRow: View {
  let operation: CashFlowCore.Operation
  let nextDate: CalendarDate?
  let locale: Locale
  let editAction: () -> Void
  let duplicateAction: () -> Void
  let toggleAction: () -> Void
  let deleteAction: () -> Void

  var body: some View {
    HStack(spacing: 13) {
      Image(
        systemName: operation.type == .income
          ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill"
      )
      .font(.title2)
      .foregroundStyle(operation.type == .income ? .green : .orange)

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 7) {
          Text(operation.name)
            .font(.headline)
            .lineLimit(1)
          Text(operation.recurrence.titleKey)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.blue.opacity(0.12), in: .capsule)
          if !operation.enabled {
            Text("operation.disabled")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }

        HStack(spacing: 5) {
          Text(operation.firstDate.formatted(locale: locale))
          Image(systemName: "arrow.right")
          Text(operation.recurrenceEndDate?.formatted(locale: locale) ?? "—")
          Text("·")
          if let nextDate {
            Text("recurring.next")
            Text(nextDate.formatted(locale: locale))
          } else {
            Text("recurring.finished")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)

        if !operation.note.isEmpty {
          Text(operation.note)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 12)

      Text(
        operation.amountMinor.formatted(
          locale: locale,
          sign: operation.type == .income ? "+" : "−"
        )
      )
      .font(.headline.monospacedDigit())
      .foregroundStyle(operation.type == .income ? .green : .primary)
      .lineLimit(1)
      .minimumScaleFactor(0.7)

      Menu {
        Button("operation.edit", action: editAction)
        Button("operation.duplicate", action: duplicateAction)
        if operation.enabled {
          Button("operation.disable", action: toggleAction)
        } else {
          Button("operation.enable", action: toggleAction)
        }
        Divider()
        Button("operation.delete", role: .destructive, action: deleteAction)
      } label: {
        Label("recurring.actions", systemImage: "ellipsis.circle")
          .labelStyle(.iconOnly)
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
    }
    .opacity(operation.enabled ? 1 : 0.5)
    .padding(.vertical, 8)
    .contextMenu {
      Button("operation.edit", action: editAction)
      Button("operation.duplicate", action: duplicateAction)
      if operation.enabled {
        Button("operation.disable", action: toggleAction)
      } else {
        Button("operation.enable", action: toggleAction)
      }
      Divider()
      Button("operation.delete", role: .destructive, action: deleteAction)
    }
    .accessibilityElement(children: .combine)
  }
}
