import CashFlowCore
import Charts
import SwiftUI

struct OverviewView: View {
  let addOperation: () -> Void

  @EnvironmentObject private var model: AppModel
  @Environment(\.locale) private var locale
  @State private var showsStartingPoint = false
  @State private var showsStress = false

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 20) {
        header

        if model.plan.operations.isEmpty {
          emptyState
        } else if let forecast = model.forecast {
          metrics(forecast)
          BalanceChart(forecast: forecast, showsStress: $showsStress)
          gapSection(forecast)
          upcomingSection(forecast)
        }
      }
      .padding(24)
    }
    .navigationTitle(AppLocalization.string("overview.title", locale: locale))
    .sheet(isPresented: $showsStartingPoint) {
      StartingPointEditor(
        currentBalance: model.plan.settings.startBalanceMinor,
        currentDate: model.plan.settings.startDate,
        saveAction: model.updateStartingPoint
      )
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text("overview.heading")
          .font(.largeTitle.bold())
        Text("overview.subtitle")
          .foregroundStyle(.secondary)
      }
      Spacer()
      if model.isCalculating {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel("calculation.progress")
      }
      Button {
        showsStartingPoint = true
      } label: {
        VStack(alignment: .trailing, spacing: 3) {
          Text("startingPoint.label")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(model.plan.settings.startBalanceMinor.formatted(locale: locale))
            .font(.headline.monospacedDigit())
          Text(model.plan.settings.startDate.formatted(locale: locale))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: .rect(cornerRadius: 10))
      }
      .buttonStyle(.plain)
      .help("startingPoint.edit")
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("overview.empty.title", systemImage: "calendar.badge.clock")
    } description: {
      Text("overview.empty.message")
    } actions: {
      Button("operation.add", action: addOperation)
        .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, minHeight: 420)
  }

  private func metrics(_ forecast: Forecast) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 12)], spacing: 12) {
      MetricCard(
        title: "metric.endingBalance",
        value: forecast.endingBalanceMinor.formatted(locale: locale),
        systemImage: "equal.circle.fill",
        tint: forecast.endingBalanceMinor.minorUnits >= 0 ? .blue : .red
      )
      MetricCard(
        title: "metric.income",
        value: forecast.incomeMinor.formatted(locale: locale),
        systemImage: "arrow.down.left.circle.fill",
        tint: .green
      )
      MetricCard(
        title: "metric.expenses",
        value: forecast.expenseMinor.formatted(locale: locale),
        systemImage: "arrow.up.right.circle.fill",
        tint: .orange
      )
      MetricCard(
        title: "metric.minimumBalance",
        value: forecast.minimumBalanceMinor.formatted(locale: locale),
        caption: forecast.minimumBalanceDate.formatted(locale: locale),
        systemImage: "arrow.down.to.line.circle.fill",
        tint: forecast.minimumBalanceMinor.minorUnits >= 0 ? .teal : .red
      )
    }
  }

  @ViewBuilder
  private func gapSection(_ forecast: Forecast) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("gaps.title", systemImage: "exclamationmark.triangle")
        .font(.title2.bold())
      if forecast.cashGaps.isEmpty {
        Label("gaps.none", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.green.opacity(0.08), in: .rect(cornerRadius: 12))
      } else {
        ForEach(forecast.cashGaps.prefix(3)) { gap in
          CashGapRow(gap: gap)
        }
      }
    }
  }

  private func upcomingSection(_ forecast: Forecast) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("overview.upcoming")
        .font(.title2.bold())
      GroupBox {
        if forecast.occurrences.isEmpty {
          Text("overview.noUpcoming")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(forecast.occurrences.prefix(8).enumerated()), id: \.element.id) {
              index, occurrence in
              OccurrenceRow(occurrence: occurrence)
              if index < min(forecast.occurrences.count, 8) - 1 { Divider() }
            }
          }
        }
      }
    }
  }
}

private struct MetricCard: View {
  let title: LocalizedStringKey
  let value: String
  var caption: String?
  let systemImage: String
  let tint: Color

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.title2)
        .foregroundStyle(tint)
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.title3.weight(.semibold).monospacedDigit())
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        if let caption {
          Text(caption)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
    .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 12))
  }
}

private struct BalanceChart: View {
  let forecast: Forecast
  @Binding var showsStress: Bool

  @Environment(\.locale) private var locale
  @State private var selectedDate: Date?

  private var selectedDay: ForecastDay? {
    guard let selectedDate else { return nil }
    return forecast.days.min {
      abs($0.date.foundationDate.timeIntervalSince(selectedDate))
        < abs($1.date.foundationDate.timeIntervalSince(selectedDate))
    }
  }

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("chart.balance.title")
              .font(.title2.bold())
            Text("chart.balance.subtitle")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Toggle("chart.stress", isOn: $showsStress)
            .toggleStyle(.switch)
            .controlSize(.small)
        }

        Chart {
          RuleMark(y: .value(balanceAxisTitle, 0))
            .foregroundStyle(.secondary.opacity(0.4))
          ForEach(forecast.days) { day in
            LineMark(
              x: .value(dateAxisTitle, day.date.foundationDate),
              y: .value(balanceAxisTitle, day.closingBalanceMinor.chartValue)
            )
            .foregroundStyle(.blue)
            .interpolationMethod(.stepEnd)
            if showsStress {
              LineMark(
                x: .value(dateAxisTitle, day.date.foundationDate),
                y: .value(stressAxisTitle, day.stressClosingBalanceMinor.chartValue)
              )
              .foregroundStyle(.orange)
              .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
              .interpolationMethod(.stepEnd)
            }
          }
          if let selectedDay {
            RuleMark(x: .value(dateAxisTitle, selectedDay.date.foundationDate))
              .foregroundStyle(.secondary)
              .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                VStack(alignment: .leading, spacing: 2) {
                  Text(selectedDay.date.formatted(locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Text(selectedDay.closingBalanceMinor.formatted(locale: locale))
                    .font(.caption.bold().monospacedDigit())
                }
                .padding(7)
                .background(.regularMaterial, in: .rect(cornerRadius: 7))
              }
          }
        }
        .chartXAxis {
          AxisMarks(values: .automatic(desiredCount: 6)) { value in
            AxisGridLine()
            AxisValueLabel {
              if let date = value.as(Date.self) {
                Text(
                  date,
                  format: Date.FormatStyle()
                    .month(.abbreviated)
                    .locale(locale)
                )
              }
            }
          }
        }
        .chartYAxis {
          AxisMarks(position: .leading)
        }
        .chartXSelection(value: $selectedDate)
        .chartOverlay { proxy in
          GeometryReader { geometry in
            Color.clear
              .contentShape(Rectangle())
              .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                  guard let plotFrame = proxy.plotFrame else { return }
                  let frame = geometry[plotFrame]
                  guard frame.contains(location) else {
                    selectedDate = nil
                    return
                  }
                  selectedDate = proxy.value(atX: location.x - frame.origin.x)
                case .ended:
                  selectedDate = nil
                }
              }
          }
        }
        .frame(minHeight: 260)
      }
      .padding(8)
    }
  }

  private var dateAxisTitle: String {
    AppLocalization.string("chart.axis.date", locale: locale)
  }

  private var balanceAxisTitle: String {
    AppLocalization.string("chart.axis.balance", locale: locale)
  }

  private var stressAxisTitle: String {
    AppLocalization.string("chart.axis.stress", locale: locale)
  }
}

private struct CashGapRow: View {
  let gap: CashGap
  @Environment(\.locale) private var locale

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)
      VStack(alignment: .leading, spacing: 3) {
        Text(gap.maximumDeficitMinor.formatted(locale: locale))
          .font(.headline.monospacedDigit())
        HStack(spacing: 4) {
          Text(gap.startDate.formatted(locale: locale))
          Image(systemName: "arrow.right")
          if let recoveryDate = gap.recoveryDate {
            Text(recoveryDate.formatted(locale: locale))
          } else {
            Text("gaps.noRecovery")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text("gaps.lowest")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text(gap.lowestDate.formatted(locale: locale))
          .font(.caption)
      }
    }
    .padding(14)
    .background(.red.opacity(0.08), in: .rect(cornerRadius: 12))
  }
}

private struct OccurrenceRow: View {
  let occurrence: Occurrence
  @Environment(\.locale) private var locale

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: occurrence.type == .income ? "arrow.down.left" : "arrow.up.right")
        .foregroundStyle(occurrence.type == .income ? .green : .orange)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 2) {
        Text(occurrence.name)
          .lineLimit(1)
        Text(occurrence.date.formatted(locale: locale))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text(
        occurrence.amountMinor.formatted(
          locale: locale,
          sign: occurrence.type == .income ? "+" : "−"
        )
      )
      .font(.body.monospacedDigit())
      .foregroundStyle(occurrence.type == .income ? .green : .primary)
    }
    .padding(.vertical, 9)
  }
}
