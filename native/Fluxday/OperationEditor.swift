import CashFlowCore
import SwiftUI

struct OperationEditorIntent: Identifiable {
  enum Mode {
    case create
    case edit
    case duplicate
  }

  let id = UUID()
  let mode: Mode
  let operation: CashFlowCore.Operation?
  let preferredDate: CalendarDate?
  let preferredRecurrence: Recurrence?

  static var create: Self {
    Self(mode: .create, operation: nil, preferredDate: nil, preferredRecurrence: nil)
  }

  static func create(on date: CalendarDate) -> Self {
    Self(mode: .create, operation: nil, preferredDate: date, preferredRecurrence: nil)
  }

  static var recurring: Self {
    Self(mode: .create, operation: nil, preferredDate: nil, preferredRecurrence: .monthly)
  }
}

struct OperationEditor: View {
  let intent: OperationEditorIntent
  let saveAction: (CashFlowCore.Operation) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var name: String
  @State private var type: OperationType
  @State private var amount: String
  @State private var certainty: Certainty
  @State private var firstDate: Date
  @State private var recurrence: Recurrence
  @State private var recurrenceEndDate: Date
  @State private var note: String
  @State private var validationKey: LocalizedStringKey?

  init(
    intent: OperationEditorIntent,
    saveAction: @escaping (CashFlowCore.Operation) -> Void
  ) {
    self.intent = intent
    self.saveAction = saveAction
    let source = intent.operation
    let start = source?.firstDate.foundationDate ?? intent.preferredDate?.foundationDate ?? Date()
    let recurrence = source?.recurrence ?? intent.preferredRecurrence ?? .none
    let fallbackEnd =
      (try? RecurrenceEngine.defaultEndDate(
        from: start.calendarDate,
        recurrence: recurrence
      )) ?? nil
    _name = State(initialValue: source?.name ?? "")
    _type = State(initialValue: source?.type ?? .expense)
    _amount = State(initialValue: source?.amountMinor.inputValue ?? "")
    _certainty = State(initialValue: source?.certainty ?? .certain)
    _firstDate = State(initialValue: start)
    _recurrence = State(initialValue: recurrence)
    _recurrenceEndDate = State(
      initialValue: source?.recurrenceEndDate?.foundationDate
        ?? fallbackEnd?.foundationDate ?? start
    )
    _note = State(initialValue: source?.note ?? "")
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(editorTitle)
          .font(.title2.bold())
        Spacer()
      }
      .padding([.horizontal, .top], 20)

      Form {
        Section("operation.editor.details") {
          TextField("operation.name", text: $name)
          Picker("operation.type", selection: $type) {
            ForEach(OperationType.allCases, id: \.self) { value in
              Text(value.titleKey).tag(value)
            }
          }
          .pickerStyle(.segmented)
          TextField("operation.amount", text: $amount)
          Picker("operation.certainty", selection: $certainty) {
            ForEach(Certainty.allCases, id: \.self) { value in
              Text(value.titleKey).tag(value)
            }
          }
        }

        Section("operation.editor.schedule") {
          DatePicker(
            "operation.firstDate",
            selection: $firstDate,
            in: ...Date().calendarDate.maximumPlanningDate.foundationDate,
            displayedComponents: .date
          )
          Picker("operation.recurrence", selection: $recurrence) {
            ForEach(Recurrence.allCases, id: \.self) { value in
              Text(value.titleKey).tag(value)
            }
          }
          if recurrence != .none {
            DatePicker(
              "operation.endDate",
              selection: $recurrenceEndDate,
              in: firstDate...firstDate.calendarDate.maximumPlanningDate.foundationDate,
              displayedComponents: .date
            )
            Text("operation.endDate.help")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Section("operation.editor.notes") {
          TextField("operation.note", text: $note, axis: .vertical)
            .lineLimit(3...6)
        }

        if let validationKey {
          Text(validationKey)
            .foregroundStyle(.red)
        }
      }
      .formStyle(.grouped)

      Divider()
      HStack {
        Spacer()
        Button("button.cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("button.save", action: save)
          .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 520, height: 590)
    .onChange(of: firstDate) { _, newValue in resetRecurrenceEnd(from: newValue) }
    .onChange(of: recurrence) { _, _ in resetRecurrenceEnd(from: firstDate) }
  }

  private var editorTitle: LocalizedStringKey {
    switch intent.mode {
    case .create:
      intent.preferredRecurrence == nil
        ? "operation.editor.create" : "operation.editor.createRecurring"
    case .edit: "operation.editor.edit"
    case .duplicate: "operation.editor.duplicate"
    }
  }

  private func save() {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanName.isEmpty, cleanName.count <= 160 else {
      validationKey = "validation.operation.name"
      return
    }
    guard let parsedAmount = Money.parse(amount), parsedAmount.minorUnits > 0 else {
      validationKey = "validation.operation.amount"
      return
    }
    let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleanNote.count <= 500 else {
      validationKey = "validation.operation.note"
      return
    }

    let source = intent.operation
    let now = ISO8601DateFormatter().string(from: Date())
    let preservesIdentity = intent.mode == .edit
    let operation = CashFlowCore.Operation(
      id: preservesIdentity ? source?.id ?? newIdentifier() : newIdentifier(),
      name: cleanName,
      type: type,
      amountMinor: parsedAmount,
      certainty: certainty,
      firstDate: firstDate.calendarDate,
      recurrence: recurrence,
      recurrenceEndDate: recurrence != .none ? recurrenceEndDate.calendarDate : nil,
      note: cleanNote,
      enabled: preservesIdentity ? source?.enabled ?? true : true,
      createdAt: preservesIdentity ? source?.createdAt ?? now : now,
      updatedAt: now
    )
    saveAction(operation)
    dismiss()
  }

  private func newIdentifier() -> String {
    "op-\(UUID().uuidString.lowercased())"
  }

  private func resetRecurrenceEnd(from date: Date) {
    guard
      let endDate = try? RecurrenceEngine.defaultEndDate(
        from: date.calendarDate,
        recurrence: recurrence
      )
    else { return }
    recurrenceEndDate = endDate.foundationDate
  }
}

struct StartingPointEditor: View {
  let currentBalance: Money
  let currentDate: CalendarDate
  let saveAction: (Money, CalendarDate) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var balance: String
  @State private var date: Date
  @State private var validationKey: LocalizedStringKey?

  init(
    currentBalance: Money,
    currentDate: CalendarDate,
    saveAction: @escaping (Money, CalendarDate) -> Void
  ) {
    self.currentBalance = currentBalance
    self.currentDate = currentDate
    self.saveAction = saveAction
    _balance = State(initialValue: currentBalance.inputValue)
    _date = State(initialValue: currentDate.foundationDate)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("startingPoint.edit")
          .font(.title2.bold())
        Spacer()
      }
      .padding([.horizontal, .top], 20)

      Form {
        TextField("startingPoint.balance", text: $balance)
        DatePicker("startingPoint.date", selection: $date, displayedComponents: .date)
        if let validationKey {
          Text(validationKey)
            .foregroundStyle(.red)
        }
      }
      .formStyle(.grouped)
      Divider()
      HStack {
        Spacer()
        Button("button.cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("button.save", action: save)
          .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 440, height: 230)
  }

  private func save() {
    guard let parsed = Money.parse(balance, allowNegative: true) else {
      validationKey = "validation.startingPoint.balance"
      return
    }
    saveAction(parsed, date.calendarDate)
    dismiss()
  }
}
