import CashFlowCore
import Charts
import Foundation
import SwiftUI

private struct ScenarioRequest: Equatable, Sendable {
  let settings: PlanSettings
  let operations: [CashFlowCore.Operation]
  let scenario: Scenario
}

private enum ScenarioNameMode {
  case create
  case rename(Scenario)
  case duplicate(Scenario)

  var scenario: Scenario? {
    switch self {
    case .create: nil
    case .rename(let scenario), .duplicate(let scenario): scenario
    }
  }
}

private struct ScenarioNameIntent: Identifiable {
  let id = UUID()
  let mode: ScenarioNameMode
}

struct ScenariosView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.locale) private var locale
  @State private var selectedScenarioID: String?
  @State private var comparison: ScenarioComparison?
  @State private var nameIntent: ScenarioNameIntent?
  @State private var overrideOperation: CashFlowCore.Operation?
  @State private var pendingDeletion: Scenario?

  private var selectedScenario: Scenario? {
    model.plan.scenarios.first { $0.id == selectedScenarioID } ?? model.plan.scenarios.first
  }

  private var recurringOperations: [CashFlowCore.Operation] {
    model.plan.operations
      .filter { $0.recurrence != .none }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private var request: ScenarioRequest? {
    selectedScenario.map {
      ScenarioRequest(
        settings: model.plan.settings,
        operations: model.plan.operations,
        scenario: $0
      )
    }
  }

  var body: some View {
    Group {
      if let selectedScenario {
        scenarioContent(selectedScenario)
      } else {
        emptyState
      }
    }
    .navigationTitle(AppLocalization.string("scenarios.title", locale: locale))
    .onAppear(perform: normalizeSelection)
    .onChange(of: model.plan.scenarios) { _, _ in normalizeSelection() }
    .task(id: request) {
      guard let request else {
        comparison = nil
        return
      }
      let result = await Task.detached(priority: .userInitiated) {
        try? ForecastEngine.compare(
          startingBalance: request.settings.startBalanceMinor,
          startDate: request.settings.startDate,
          operations: request.operations,
          scenario: request.scenario
        )
      }.value
      guard !Task.isCancelled else { return }
      comparison = result
    }
    .sheet(item: $nameIntent) { intent in
      ScenarioNameEditor(
        mode: intent.mode,
        locale: locale,
        saveAction: saveName
      )
    }
    .sheet(item: $overrideOperation) { operation in
      ScenarioOverrideEditor(
        operation: operation,
        override: selectedScenario?.overrides[operation.id],
        saveAction: { override in
          guard let scenarioID = selectedScenario?.id else { return }
          model.updateScenarioOverride(
            scenarioID: scenarioID,
            operationID: operation.id,
            override: override
          )
        }
      )
    }
    .alert(
      "scenarios.delete.title",
      isPresented: Binding(
        get: { pendingDeletion != nil },
        set: { if !$0 { pendingDeletion = nil } }
      ),
      presenting: pendingDeletion
    ) { scenario in
      Button("scenarios.delete", role: .destructive) {
        model.deleteScenario(id: scenario.id)
        pendingDeletion = nil
      }
      Button("button.cancel", role: .cancel) { pendingDeletion = nil }
    } message: { scenario in
      Text(
        String(
          format: AppLocalization.string("scenarios.delete.message", locale: locale),
          locale: locale,
          scenario.name
        )
      )
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("scenarios.empty.title", systemImage: "square.stack.3d.up")
    } description: {
      Text("scenarios.empty.message")
    } actions: {
      Button("scenarios.create") {
        nameIntent = ScenarioNameIntent(mode: .create)
      }
      .buttonStyle(.borderedProminent)
    }
  }

  private func scenarioContent(_ scenario: Scenario) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18) {
        scenarioToolbar(scenario)
        if let comparison {
          metrics(scenario, comparison: comparison)
          comparisonChart(scenario, comparison: comparison)
        } else {
          ProgressView("scenarios.loading")
            .frame(maxWidth: .infinity, minHeight: 280)
        }
        overrideSection(scenario)
      }
      .padding(24)
    }
  }

  private func scenarioToolbar(_ scenario: Scenario) -> some View {
    GroupBox {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          scenarioPicker
            .frame(width: 280)
          scenarioActions(scenario, labelStyle: .titleAndIcon)
          Spacer()
          newScenarioButton(labelStyle: .titleAndIcon)
        }
        HStack(spacing: 10) {
          scenarioPicker
          Spacer()
          scenarioActions(scenario, labelStyle: .iconOnly)
          newScenarioButton(labelStyle: .iconOnly)
        }
      }
      .padding(4)
    }
  }

  private var scenarioPicker: some View {
    Picker("scenarios.picker", selection: scenarioSelection) {
      ForEach(model.plan.scenarios) { item in
        Text(item.name).tag(item.id)
      }
    }
    .frame(minWidth: 180, maxWidth: 360)
  }

  private func scenarioActions<Style: LabelStyle>(
    _ scenario: Scenario,
    labelStyle: Style
  ) -> some View {
    Menu {
      Button("scenarios.rename") {
        nameIntent = ScenarioNameIntent(mode: .rename(scenario))
      }
      Button("scenarios.duplicate") {
        nameIntent = ScenarioNameIntent(mode: .duplicate(scenario))
      }
      Divider()
      Button("scenarios.delete", role: .destructive) {
        pendingDeletion = scenario
      }
    } label: {
      Label("scenarios.actions", systemImage: "ellipsis.circle")
        .labelStyle(labelStyle)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .help("scenarios.actions")
  }

  private func newScenarioButton<Style: LabelStyle>(labelStyle: Style) -> some View {
    Button {
      nameIntent = ScenarioNameIntent(mode: .create)
    } label: {
      Label("scenarios.create", systemImage: "plus")
        .labelStyle(labelStyle)
    }
    .buttonStyle(.borderedProminent)
    .fixedSize()
    .help("scenarios.create")
  }

  private func metrics(_ scenario: Scenario, comparison: ScenarioComparison) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
      AnalyticsMetricCard(
        title: "scenarios.metric.baseEnding",
        value: comparison.base.endingBalanceMinor.formatted(locale: locale),
        dynamicCaption: AppLocalization.string("scenarios.metric.baseMinimum", locale: locale)
          + " " + comparison.base.minimumBalanceMinor.formatted(locale: locale),
        systemImage: "equal.circle.fill",
        tint: .secondary
      )
      AnalyticsMetricCard(
        title: "scenarios.metric.scenarioEnding",
        value: comparison.scenario.endingBalanceMinor.formatted(locale: locale),
        dynamicCaption: deltaCaption(comparison.endingBalanceDelta),
        systemImage: "arrow.triangle.branch",
        tint: comparison.scenario.endingBalanceMinor.minorUnits >= 0 ? .blue : .red
      )
      AnalyticsMetricCard(
        title: "scenarios.metric.firstGap",
        value: comparison.scenario.firstNegativeDate?.formatted(locale: locale)
          ?? AppLocalization.string("scenarios.metric.noGap", locale: locale),
        dynamicCaption: AppLocalization.string("scenarios.metric.deficit", locale: locale)
          + " " + comparison.scenario.maximumDeficitMinor.formatted(locale: locale),
        systemImage: "exclamationmark.triangle.fill",
        tint: comparison.scenario.firstNegativeDate == nil ? .green : .red
      )
      AnalyticsMetricCard(
        title: "scenarios.metric.minimum",
        value: comparison.scenario.minimumBalanceMinor.formatted(locale: locale),
        dynamicCaption: deltaCaption(comparison.minimumBalanceDelta),
        systemImage: "arrow.down.to.line.circle.fill",
        tint: comparison.scenario.minimumBalanceMinor.minorUnits >= 0 ? .teal : .red
      )
    }
    .accessibilityLabel(scenario.name)
  }

  private func comparisonChart(_ scenario: Scenario, comparison: ScenarioComparison) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text("scenarios.chart.eyebrow")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("scenarios.chart.title")
            .font(.title2.bold())
        }

        HStack(spacing: 16) {
          Label("scenarios.base", systemImage: "minus")
            .foregroundStyle(.secondary)
          Label(scenario.name, systemImage: "minus")
            .foregroundStyle(.blue)
        }
        .font(.caption)

        Chart {
          RuleMark(y: .value(balanceAxisTitle, 0))
            .foregroundStyle(.secondary.opacity(0.35))
          ForEach(comparison.base.days) { day in
            LineMark(
              x: .value(dateAxisTitle, day.date.foundationDate),
              y: .value(balanceAxisTitle, day.closingBalanceMinor.chartValue),
              series: .value(seriesAxisTitle, baseSeriesTitle)
            )
            .foregroundStyle(.secondary)
            .interpolationMethod(.stepEnd)
          }
          ForEach(comparison.scenario.days) { day in
            LineMark(
              x: .value(dateAxisTitle, day.date.foundationDate),
              y: .value(balanceAxisTitle, day.closingBalanceMinor.chartValue),
              series: .value(seriesAxisTitle, scenario.name)
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.stepEnd)
          }
        }
        .chartLegend(.hidden)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(minHeight: 280)
        .accessibilityLabel(
          Text(
            "\(AppLocalization.string("scenarios.chart.accessibility", locale: locale)) \(scenario.name)"
          )
        )
      }
      .padding(8)
    }
  }

  private func overrideSection(_ scenario: Scenario) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 3) {
            Text("scenarios.overrides.eyebrow")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text("scenarios.overrides.title")
              .font(.title2.bold())
          }
          Spacer()
          Text(scenario.overrides.count.formatted(.number.locale(locale)))
            .font(.caption.bold().monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: .capsule)
        }

        if recurringOperations.isEmpty {
          ContentUnavailableView(
            "scenarios.overrides.empty",
            systemImage: "repeat",
            description: Text("scenarios.overrides.empty.message")
          )
          .frame(maxWidth: .infinity, minHeight: 180)
        } else {
          VStack(spacing: 0) {
            ForEach(recurringOperations) { operation in
              Button {
                overrideOperation = operation
              } label: {
                ScenarioOperationRow(
                  operation: operation,
                  override: scenario.overrides[operation.id],
                  locale: locale
                )
              }
              .buttonStyle(.plain)
              if operation.id != recurringOperations.last?.id { Divider() }
            }
          }
        }
      }
      .padding(8)
    }
  }

  private var scenarioSelection: Binding<String> {
    Binding(
      get: { selectedScenario?.id ?? "" },
      set: { selectedScenarioID = $0 }
    )
  }

  private func normalizeSelection() {
    if model.plan.scenarios.contains(where: { $0.id == selectedScenarioID }) { return }
    selectedScenarioID = model.plan.scenarios.first?.id
  }

  private func saveName(_ mode: ScenarioNameMode, name: String) {
    switch mode {
    case .create:
      let scenario = Scenario(id: newScenarioIdentifier(), name: name)
      model.saveScenario(scenario)
      selectedScenarioID = scenario.id
    case .rename(var scenario):
      scenario.name = name
      model.saveScenario(scenario)
      selectedScenarioID = scenario.id
    case .duplicate(let source):
      let scenario = Scenario(
        id: newScenarioIdentifier(),
        name: name,
        overrides: source.overrides
      )
      model.saveScenario(scenario)
      selectedScenarioID = scenario.id
    }
  }

  private func newScenarioIdentifier() -> String {
    "scenario-\(UUID().uuidString.lowercased())"
  }

  private func deltaCaption(_ delta: Money) -> String {
    let prefix = AppLocalization.string("scenarios.metric.delta", locale: locale)
    let sign = delta.minorUnits > 0 ? "+" : nil
    return "\(prefix) \(delta.formatted(locale: locale, sign: sign))"
  }

  private var dateAxisTitle: String {
    AppLocalization.string("chart.axis.date", locale: locale)
  }

  private var balanceAxisTitle: String {
    AppLocalization.string("chart.axis.balance", locale: locale)
  }

  private var seriesAxisTitle: String {
    AppLocalization.string("chart.axis.series", locale: locale)
  }

  private var baseSeriesTitle: String {
    AppLocalization.string("scenarios.base", locale: locale)
  }
}

private struct ScenarioOperationRow: View {
  let operation: CashFlowCore.Operation
  let override: ScenarioOverride?
  let locale: Locale

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: override == nil ? "circle" : "checkmark.circle.fill")
        .font(.title3)
        .foregroundStyle(override == nil ? Color(nsColor: .secondaryLabelColor) : .blue)
      VStack(alignment: .leading, spacing: 3) {
        Text(operation.name)
          .font(.headline)
          .lineLimit(1)
        HStack(spacing: 5) {
          Text(operation.amountMinor.formatted(locale: locale))
          Text("·")
          Text(operation.recurrence.titleKey)
          if let override {
            Text("·")
            Text(
              override.excluded == true
                ? "scenarios.override.excluded" : "scenarios.override.changed")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer()
      Text(override == nil ? "scenarios.override.configure" : "scenarios.override.edit")
        .font(.caption)
        .foregroundStyle(.blue)
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 10)
    .contentShape(Rectangle())
  }
}

private struct ScenarioNameEditor: View {
  let mode: ScenarioNameMode
  let locale: Locale
  let saveAction: (ScenarioNameMode, String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var name: String
  @State private var showsValidation = false

  init(
    mode: ScenarioNameMode,
    locale: Locale,
    saveAction: @escaping (ScenarioNameMode, String) -> Void
  ) {
    self.mode = mode
    self.locale = locale
    self.saveAction = saveAction
    let initialName: String
    switch mode {
    case .create:
      initialName = ""
    case .rename(let scenario):
      initialName = scenario.name
    case .duplicate(let scenario):
      initialName = String(
        format: AppLocalization.string("scenarios.copyName", locale: locale),
        locale: locale,
        scenario.name
      )
    }
    _name = State(initialValue: initialName)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title)
        .font(.title2.bold())
      TextField("scenarios.name", text: $name)
        .textFieldStyle(.roundedBorder)
      if showsValidation {
        Text("validation.scenario.name")
          .font(.caption)
          .foregroundStyle(.red)
      }
      HStack {
        Spacer()
        Button("button.cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("button.save", action: save)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(22)
    .frame(width: 420)
  }

  private var title: LocalizedStringKey {
    switch mode {
    case .create: "scenarios.create.title"
    case .rename: "scenarios.rename.title"
    case .duplicate: "scenarios.duplicate.title"
    }
  }

  private func save() {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanName.isEmpty, cleanName.count <= 80 else {
      showsValidation = true
      return
    }
    saveAction(mode, cleanName)
    dismiss()
  }
}

private struct ScenarioOverrideEditor: View {
  let operation: CashFlowCore.Operation
  let saveAction: (ScenarioOverride?) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var usesAmount: Bool
  @State private var amount: String
  @State private var usesRecurrence: Bool
  @State private var recurrence: Recurrence
  @State private var usesFirstDate: Bool
  @State private var firstDate: Date
  @State private var usesEndDate: Bool
  @State private var hasEndDate: Bool
  @State private var endDate: Date
  @State private var usesCertainty: Bool
  @State private var certainty: Certainty
  @State private var excluded: Bool
  @State private var validationKey: LocalizedStringKey?

  init(
    operation: CashFlowCore.Operation,
    override: ScenarioOverride?,
    saveAction: @escaping (ScenarioOverride?) -> Void
  ) {
    self.operation = operation
    self.saveAction = saveAction
    let storedEnd: CalendarDate?? = override?.recurrenceEndDate ?? nil
    let resolvedEnd = storedEnd ?? operation.recurrenceEndDate
    _usesAmount = State(initialValue: override?.amountMinor != nil)
    _amount = State(
      initialValue: override?.amountMinor?.inputValue ?? operation.amountMinor.inputValue)
    _usesRecurrence = State(initialValue: override?.recurrence != nil)
    _recurrence = State(initialValue: override?.recurrence ?? operation.recurrence)
    _usesFirstDate = State(initialValue: override?.firstDate != nil)
    _firstDate = State(initialValue: (override?.firstDate ?? operation.firstDate).foundationDate)
    _usesEndDate = State(initialValue: storedEnd != nil)
    _hasEndDate = State(initialValue: resolvedEnd != nil)
    _endDate = State(
      initialValue: resolvedEnd?.foundationDate
        ?? operation.recurrenceEndDate?.foundationDate
        ?? operation.firstDate.foundationDate
    )
    _usesCertainty = State(initialValue: override?.certainty != nil)
    _certainty = State(initialValue: override?.certainty ?? operation.certainty)
    _excluded = State(initialValue: override?.excluded == true)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("scenarios.override.title")
            .font(.title2.bold())
          Text(operation.name)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
      }
      .padding([.horizontal, .top], 20)

      Form {
        Section("scenarios.override.values") {
          Toggle("scenarios.override.amount", isOn: $usesAmount)
          if usesAmount {
            TextField("operation.amount", text: $amount)
          }

          Toggle("scenarios.override.recurrence", isOn: $usesRecurrence)
          if usesRecurrence {
            Picker("operation.recurrence", selection: $recurrence) {
              ForEach([Recurrence.daily, .weekly, .monthly, .yearly], id: \.self) { value in
                Text(value.titleKey).tag(value)
              }
            }
          }

          Toggle("scenarios.override.firstDate", isOn: $usesFirstDate)
          if usesFirstDate {
            DatePicker("operation.firstDate", selection: $firstDate, displayedComponents: .date)
          }

          Toggle("scenarios.override.endDate", isOn: $usesEndDate)
          if usesEndDate {
            Toggle("scenarios.override.hasEndDate", isOn: $hasEndDate)
            if hasEndDate {
              DatePicker("operation.endDate", selection: $endDate, displayedComponents: .date)
            }
          }

          Toggle("scenarios.override.certainty", isOn: $usesCertainty)
          if usesCertainty {
            Picker("operation.certainty", selection: $certainty) {
              ForEach(Certainty.allCases, id: \.self) { value in
                Text(value.titleKey).tag(value)
              }
            }
          }
        }

        Section {
          Toggle("scenarios.override.exclude", isOn: $excluded)
        } footer: {
          Text("scenarios.override.help")
        }

        if let validationKey {
          Text(validationKey)
            .foregroundStyle(.red)
        }
      }
      .formStyle(.grouped)

      Divider()
      HStack {
        Button("scenarios.override.reset", role: .destructive) {
          saveAction(nil)
          dismiss()
        }
        Spacer()
        Button("button.cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("button.save", action: save)
          .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 520, height: 650)
  }

  private func save() {
    let parsedAmount = usesAmount ? Money.parse(amount) : nil
    if usesAmount, parsedAmount?.minorUnits ?? 0 <= 0 {
      validationKey = "validation.operation.amount"
      return
    }
    let effectiveStart = usesFirstDate ? firstDate.calendarDate : operation.firstDate
    if usesEndDate, hasEndDate, endDate.calendarDate < effectiveStart {
      validationKey = "validation.scenario.endDate"
      return
    }

    let endOverride: CalendarDate?? =
      usesEndDate ? .some(hasEndDate ? endDate.calendarDate : nil) : nil
    let result = ScenarioOverride(
      amountMinor: parsedAmount,
      recurrence: usesRecurrence ? recurrence : nil,
      firstDate: usesFirstDate ? firstDate.calendarDate : nil,
      recurrenceEndDate: endOverride,
      certainty: usesCertainty ? certainty : nil,
      excluded: excluded ? true : nil
    )
    let isEmpty =
      result.amountMinor == nil
      && result.recurrence == nil
      && result.firstDate == nil
      && result.recurrenceEndDate == nil
      && result.certainty == nil
      && result.excluded == nil
    saveAction(isEmpty ? nil : result)
    dismiss()
  }
}
