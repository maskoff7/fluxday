import CashFlowCore
import Charts
import SwiftUI

private enum SummaryPeriod: CaseIterable, Identifiable {
  case week
  case month
  case year
  case custom

  var id: Self { self }

  var titleKey: LocalizedStringKey {
    switch self {
    case .week: "summary.period.week"
    case .month: "summary.period.month"
    case .year: "summary.period.year"
    case .custom: "summary.period.custom"
    }
  }
}

private struct SummaryRequest: Equatable, Sendable {
  let operations: [CashFlowCore.Operation]
  let startDate: CalendarDate
  let endDate: CalendarDate
  let filter: SummaryFilter
}

struct SummaryView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.locale) private var locale
  @State private var period = SummaryPeriod.month
  @State private var anchor = Date().calendarDate
  @State private var customStart = Date().calendarDate.startOfMonth
  @State private var customEnd = Date().calendarDate.endOfMonth
  @State private var filter = SummaryFilter.expense
  @State private var summary: Summary?
  @State private var selectedGroupID: String?

  private var range: (start: CalendarDate, end: CalendarDate) {
    switch period {
    case .week:
      return (
        (try? anchor.startOfWeek()) ?? anchor,
        (try? anchor.endOfWeek()) ?? anchor
      )
    case .month:
      return (anchor.startOfMonth, anchor.endOfMonth)
    case .year:
      return (anchor.startOfYear, anchor.endOfYear)
    case .custom:
      return (min(customStart, customEnd), max(customStart, customEnd))
    }
  }

  private var request: SummaryRequest {
    SummaryRequest(
      operations: model.plan.operations,
      startDate: range.start,
      endDate: range.end,
      filter: filter
    )
  }

  private var selectedGroup: SummaryGroup? {
    guard let summary else { return nil }
    return summary.groups.first { $0.id == selectedGroupID } ?? summary.groups.first
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18) {
        controls
        if let summary {
          metrics(summary)
          composition(summary)
          if let selectedGroup { trend(selectedGroup) }
        } else {
          ProgressView("summary.loading")
            .frame(maxWidth: .infinity, minHeight: 360)
        }
      }
      .padding(24)
    }
    .navigationTitle(AppLocalization.string("summary.title", locale: locale))
    .task(id: request) {
      let request = request
      let result = await Task.detached(priority: .userInitiated) {
        try? SummaryEngine.build(
          operations: request.operations,
          from: request.startDate,
          through: request.endDate,
          filter: request.filter
        )
      }.value
      guard !Task.isCancelled else { return }
      summary = result
      if result?.groups.contains(where: { $0.id == selectedGroupID }) != true {
        selectedGroupID = result?.groups.first?.id
      }
    }
  }

  private var controls: some View {
    GroupBox {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .bottom, spacing: 12) {
          periodControls
          Spacer()
          flowFilter
            .frame(width: 360)
        }
        VStack(alignment: .leading, spacing: 12) {
          periodControls
          flowFilter
            .frame(maxWidth: .infinity)
        }
      }

      Text(rangeTitle)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var periodControls: some View {
    HStack(alignment: .bottom, spacing: 12) {
      Picker("summary.period.label", selection: $period) {
        ForEach(SummaryPeriod.allCases) { value in
          Text(value.titleKey).tag(value)
        }
      }
      .frame(width: 150)

      if period == .custom {
        DatePicker(
          "summary.period.from",
          selection: calendarBinding($customStart),
          displayedComponents: .date
        )
        DatePicker(
          "summary.period.through",
          selection: calendarBinding($customEnd),
          displayedComponents: .date
        )
      } else {
        ControlGroup {
          Button(action: { shiftPeriod(by: -1) }) {
            Label("summary.period.previous", systemImage: "chevron.left")
          }
          Button("summary.period.current", action: { anchor = Date().calendarDate })
          Button(action: { shiftPeriod(by: 1) }) {
            Label("summary.period.next", systemImage: "chevron.right")
          }
        }
        .labelStyle(.iconOnly)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  private var flowFilter: some View {
    Picker("summary.filter.label", selection: $filter) {
      Text("summary.filter.expenses").tag(SummaryFilter.expense)
      Text("summary.filter.income").tag(SummaryFilter.income)
      Text("summary.filter.all").tag(SummaryFilter.all)
    }
    .pickerStyle(.segmented)
    .labelsHidden()
  }

  private func metrics(_ summary: Summary) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
      AnalyticsMetricCard(
        title: "summary.metric.income",
        value: summary.incomeMinor.formatted(locale: locale),
        caption: "summary.metric.period",
        systemImage: "arrow.down.left.circle.fill",
        tint: .green
      )
      AnalyticsMetricCard(
        title: "summary.metric.expenses",
        value: summary.expenseMinor.formatted(locale: locale),
        caption: "summary.metric.period",
        systemImage: "arrow.up.right.circle.fill",
        tint: .orange
      )
      AnalyticsMetricCard(
        title: "summary.metric.net",
        value: summary.netMinor.formatted(
          locale: locale, sign: summary.netMinor.minorUnits > 0 ? "+" : nil),
        caption: "summary.metric.net.help",
        systemImage: "sum",
        tint: summary.netMinor.minorUnits >= 0 ? .blue : .red
      )
      AnalyticsMetricCard(
        title: "summary.metric.occurrences",
        value: summary.occurrenceCount.formatted(.number.locale(locale)),
        caption: "summary.metric.occurrences.help",
        systemImage: "calendar.badge.clock",
        tint: .purple
      )
    }
  }

  private func composition(_ summary: Summary) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 3) {
          Text(compositionEyebrow)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(compositionTitle)
            .font(.title2.bold())
        }

        if summary.groups.isEmpty {
          ContentUnavailableView(
            "summary.empty.title",
            systemImage: "chart.pie",
            description: Text("summary.empty.message")
          )
          .frame(maxWidth: .infinity, minHeight: 220)
        } else {
          ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
              compositionChart(summary.groups)
                .frame(width: 260, height: 260)
              groupList(summary.groups)
            }
            VStack(spacing: 16) {
              compositionChart(summary.groups)
                .frame(height: 240)
              groupList(summary.groups)
            }
          }
        }
      }
      .padding(8)
    }
  }

  private func compositionChart(_ groups: [SummaryGroup]) -> some View {
    Chart(groups) { group in
      SectorMark(
        angle: .value(amountAxisTitle, group.totalMinor.chartValue),
        innerRadius: .ratio(0.62),
        angularInset: 1.5
      )
      .foregroundStyle(by: .value(operationAxisTitle, group.name))
      .opacity(selectedGroupID == nil || selectedGroupID == group.id ? 1 : 0.35)
    }
    .chartLegend(.hidden)
    .accessibilityLabel(compositionTitle)
  }

  private func groupList(_ groups: [SummaryGroup]) -> some View {
    VStack(spacing: 0) {
      ForEach(groups) { group in
        Button {
          selectedGroupID = group.id
        } label: {
          HStack(spacing: 10) {
            Image(systemName: group.type == .income ? "arrow.down.left" : "arrow.up.right")
              .foregroundStyle(group.type == .income ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
              Text(group.name)
                .font(.headline)
                .lineLimit(1)
              Text(groupSubtitle(group))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(
              group.totalMinor.formatted(
                locale: locale,
                sign: group.type == .income ? "+" : "−"
              )
            )
            .font(.headline.monospacedDigit())
            .foregroundStyle(group.type == .income ? .green : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          }
          .padding(10)
          .background(
            selectedGroupID == group.id ? Color.accentColor.opacity(0.1) : .clear,
            in: .rect(cornerRadius: 8)
          )
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func trend(_ group: SummaryGroup) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 3) {
            Text("summary.trend.eyebrow")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(group.name)
              .font(.title2.bold())
              .lineLimit(1)
          }
          Spacer()
          Text(group.totalMinor.formatted(locale: locale))
            .font(.headline.monospacedDigit())
        }

        Chart(trendPoints(for: group)) { point in
          BarMark(
            x: .value(dateAxisTitle, point.date.foundationDate),
            y: .value(dailyAxisTitle, point.daily)
          )
          .foregroundStyle(.teal.opacity(0.45))
          LineMark(
            x: .value(dateAxisTitle, point.date.foundationDate),
            y: .value(cumulativeAxisTitle, point.cumulative)
          )
          .foregroundStyle(.blue)
          .interpolationMethod(.stepEnd)
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
        .frame(minHeight: 240)
      }
      .padding(8)
    }
  }

  private var rangeTitle: String {
    "\(range.start.formatted(locale: locale)) — \(range.end.formatted(locale: locale))"
  }

  private var compositionEyebrow: LocalizedStringKey {
    filter == .all ? "summary.composition.absolute" : "summary.composition.share"
  }

  private var compositionTitle: String {
    switch filter {
    case .expense: AppLocalization.string("summary.composition.expenses", locale: locale)
    case .income: AppLocalization.string("summary.composition.income", locale: locale)
    case .all: AppLocalization.string("summary.composition.turnover", locale: locale)
    }
  }

  private func shiftPeriod(by amount: Int) {
    let next: CalendarDate?
    switch period {
    case .week: next = try? anchor.adding(days: amount * 7)
    case .month: next = try? anchor.adding(months: amount)
    case .year: next = try? anchor.adding(years: amount)
    case .custom: next = nil
    }
    if let next { anchor = next }
  }

  private func calendarBinding(_ value: Binding<CalendarDate>) -> Binding<Date> {
    Binding(
      get: { value.wrappedValue.foundationDate },
      set: { value.wrappedValue = $0.calendarDate }
    )
  }

  private func groupSubtitle(_ group: SummaryGroup) -> String {
    let format = AppLocalization.string("summary.group.detail", locale: locale)
    let count = group.count.formatted(.number.locale(locale))
    let share = group.share.formatted(
      .percent.precision(.fractionLength(0...1)).locale(locale)
    )
    return String(
      format: format,
      locale: locale,
      count,
      share
    )
  }

  private func trendPoints(for group: SummaryGroup) -> [SummaryTrendPoint] {
    let dailyAmounts = Dictionary(grouping: group.occurrences, by: \.date).mapValues {
      $0.reduce(Int64(0)) { $0 + $1.amountMinor.minorUnits }
    }
    guard let dates = try? range.start.eachDay(through: range.end) else { return [] }
    var cumulative: Int64 = 0
    return dates.map { date in
      let daily = dailyAmounts[date] ?? 0
      cumulative += daily
      return SummaryTrendPoint(
        date: date,
        daily: Double(daily) / 100,
        cumulative: Double(cumulative) / 100
      )
    }
  }

  private var amountAxisTitle: String {
    AppLocalization.string("chart.axis.amount", locale: locale)
  }

  private var operationAxisTitle: String {
    AppLocalization.string("chart.axis.operation", locale: locale)
  }

  private var dateAxisTitle: String {
    AppLocalization.string("chart.axis.date", locale: locale)
  }

  private var dailyAxisTitle: String {
    AppLocalization.string("summary.trend.daily", locale: locale)
  }

  private var cumulativeAxisTitle: String {
    AppLocalization.string("summary.trend.cumulative", locale: locale)
  }
}

private struct SummaryTrendPoint: Identifiable {
  let date: CalendarDate
  let daily: Double
  let cumulative: Double

  var id: CalendarDate { date }
}

struct AnalyticsMetricCard: View {
  let title: Text
  let value: String
  let caption: Text
  let systemImage: String
  let tint: Color

  init(
    title: LocalizedStringKey,
    value: String,
    caption: LocalizedStringKey,
    systemImage: String,
    tint: Color
  ) {
    self.title = Text(title)
    self.value = value
    self.caption = Text(caption)
    self.systemImage = systemImage
    self.tint = tint
  }

  init(
    title: LocalizedStringKey,
    value: String,
    dynamicCaption: String,
    systemImage: String,
    tint: Color
  ) {
    self.title = Text(title)
    self.value = value
    self.caption = Text(dynamicCaption)
    self.systemImage = systemImage
    self.tint = tint
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.title2)
        .foregroundStyle(tint)
      VStack(alignment: .leading, spacing: 3) {
        title
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.title3.weight(.semibold).monospacedDigit())
          .lineLimit(1)
          .minimumScaleFactor(0.65)
        caption
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
    .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 12))
  }
}
