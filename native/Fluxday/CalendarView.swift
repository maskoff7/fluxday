import CashFlowCore
import SwiftUI

struct CalendarView: View {
  let addAction: (CalendarDate) -> Void
  let editAction: (CashFlowCore.Operation) -> Void

  @EnvironmentObject private var model: AppModel
  @Environment(\.locale) private var locale
  @State private var displayedMonth = Date().calendarDate.startOfMonth
  @State private var selectedDate = Date().calendarDate

  private var dayByDate: [CalendarDate: ForecastDay] {
    Dictionary(uniqueKeysWithValues: (model.forecast?.days ?? []).map { ($0.date, $0) })
  }

  private var selectedDay: ForecastDay? { dayByDate[selectedDate] }

  var body: some View {
    GeometryReader { geometry in
      if geometry.size.width >= 820 {
        HSplitView {
          calendarPanel
            .frame(minWidth: 560)
          dayDetail
            .frame(minWidth: 250, idealWidth: 310)
        }
      } else {
        ScrollView {
          VStack(spacing: 16) {
            calendarPanel
            dayDetail
          }
          .padding()
        }
      }
    }
    .navigationTitle(AppLocalization.string("calendar.title", locale: locale))
    .onAppear(perform: normalizeSelection)
    .onChange(of: model.forecast?.startDate) { _, _ in normalizeSelection() }
    .onChange(of: model.forecast?.endDate) { _, _ in normalizeSelection() }
  }

  private var calendarPanel: some View {
    VStack(spacing: 0) {
      calendarToolbar
        .padding(16)
      Divider()
      weekdayHeader
      monthGrid
    }
    .background(.background)
  }

  private var calendarToolbar: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("calendar.eyebrow")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(monthTitle)
          .font(.title2.bold())
      }
      Spacer()
      ControlGroup {
        Button(action: { changeMonth(by: -1) }) {
          Label("calendar.previous", systemImage: "chevron.left")
        }
        .disabled(!canMoveMonth(by: -1))
        Button("calendar.today", action: selectToday)
          .keyboardShortcut("t", modifiers: .command)
        Button(action: { changeMonth(by: 1) }) {
          Label("calendar.next", systemImage: "chevron.right")
        }
        .disabled(!canMoveMonth(by: 1))
      }
      .labelStyle(.iconOnly)
    }
  }

  private var weekdayHeader: some View {
    HStack(spacing: 1) {
      ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
        Text(symbol.uppercased(with: locale))
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
      }
    }
    .background(.quaternary.opacity(0.35))
  }

  private var monthGrid: some View {
    let days = (try? displayedMonth.monthGridDays()) ?? []
    return LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(minimum: 58), spacing: 1), count: 7),
      spacing: 1
    ) {
      ForEach(days, id: \.self) { date in
        CalendarDayCell(
          date: date,
          day: dayByDate[date],
          isDisplayedMonth: date.month == displayedMonth.month && date.year == displayedMonth.year,
          isSelected: date == selectedDate,
          isToday: date == Date().calendarDate,
          locale: locale,
          selectAction: { selectedDate = date }
        )
        .disabled(!isInForecast(date))
      }
    }
    .background(Color(nsColor: .separatorColor).opacity(0.35))
  }

  private var dayDetail: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 3) {
          Text("calendar.day.eyebrow")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(dayTitle)
            .font(.title3.bold())
        }
        Spacer()
        Button {
          addAction(selectedDate)
        } label: {
          Label("calendar.day.add", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
      }

      if let selectedDay {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
          DayMetric(
            title: "calendar.day.opening", value: selectedDay.openingBalanceMinor, locale: locale)
          DayMetric(
            title: "calendar.day.closing", value: selectedDay.closingBalanceMinor, locale: locale)
          DayMetric(
            title: "calendar.day.income", value: selectedDay.incomeMinor, locale: locale,
            tint: .green)
          DayMetric(
            title: "calendar.day.expenses", value: selectedDay.expenseMinor, locale: locale,
            tint: .orange)
        }

        if selectedDay.occurrences.isEmpty {
          ContentUnavailableView(
            "calendar.day.empty",
            systemImage: "calendar.badge.plus",
            description: Text("calendar.day.empty.message")
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          List(selectedDay.occurrences) { occurrence in
            Button {
              editAction(occurrence.operation)
            } label: {
              CalendarOccurrenceRow(occurrence: occurrence, locale: locale)
            }
            .buttonStyle(.plain)
            .contextMenu {
              Button("operation.edit") { editAction(occurrence.operation) }
            }
          }
          .listStyle(.inset)
        }
      } else {
        ContentUnavailableView(
          "calendar.day.outside",
          systemImage: "calendar",
          description: Text("calendar.day.outside.message")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      Spacer(minLength: 0)
    }
    .padding(16)
    .background(.background)
  }

  private var monthTitle: String {
    displayedMonth.foundationDate.formatted(
      Date.FormatStyle().month(.wide).year().locale(locale)
    )
  }

  private var dayTitle: String {
    selectedDate.foundationDate.formatted(
      Date.FormatStyle().weekday(.wide).day().month(.wide).year().locale(locale)
    )
  }

  private var weekdaySymbols: [String] {
    let formatter = DateFormatter()
    formatter.locale = locale
    let symbols = formatter.shortStandaloneWeekdaySymbols ?? []
    guard symbols.count == 7 else { return [] }
    return Array(symbols.dropFirst()) + [symbols[0]]
  }

  private func normalizeSelection() {
    guard let forecast = model.forecast else { return }
    let today = Date().calendarDate
    selectedDate = min(max(today, forecast.startDate), forecast.endDate)
    displayedMonth = selectedDate.startOfMonth
  }

  private func selectToday() {
    normalizeSelection()
  }

  private func canMoveMonth(by offset: Int) -> Bool {
    guard let forecast = model.forecast,
      let target = try? displayedMonth.adding(months: offset)
    else { return false }
    return target >= forecast.startDate.startOfMonth && target <= forecast.endDate.startOfMonth
  }

  private func changeMonth(by offset: Int) {
    guard canMoveMonth(by: offset), let target = try? displayedMonth.adding(months: offset) else {
      return
    }
    displayedMonth = target.startOfMonth
    if let forecast = model.forecast {
      selectedDate = min(max(target, forecast.startDate), forecast.endDate)
    }
  }

  private func isInForecast(_ date: CalendarDate) -> Bool {
    guard let forecast = model.forecast else { return false }
    return date >= forecast.startDate && date <= forecast.endDate
  }
}

private struct CalendarDayCell: View {
  let date: CalendarDate
  let day: ForecastDay?
  let isDisplayedMonth: Bool
  let isSelected: Bool
  let isToday: Bool
  let locale: Locale
  let selectAction: () -> Void

  var body: some View {
    Button(action: selectAction) {
      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Text(String(date.day))
            .font(.caption.weight(isToday ? .bold : .regular))
            .foregroundStyle(isToday ? Color.accentColor : .primary)
          Spacer()
          if let count = day?.occurrences.count, count > 0 {
            Text(String(count))
              .font(.caption2.monospacedDigit())
              .foregroundStyle(.secondary)
          }
        }
        ForEach(Array((day?.occurrences ?? []).prefix(2))) { occurrence in
          HStack(spacing: 4) {
            Circle()
              .fill(occurrence.type == .income ? .green : .orange)
              .frame(width: 5, height: 5)
            Text(occurrence.name)
              .font(.caption2)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 0)
        if let day {
          Text(day.closingBalanceMinor.formatted(locale: locale))
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundStyle(day.closingBalanceMinor.minorUnits < 0 ? .red : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
        }
      }
      .padding(7)
      .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
      .background(cellBackground)
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: 7)
            .stroke(Color.accentColor, lineWidth: 2)
            .padding(2)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .opacity(isDisplayedMonth ? 1 : 0.48)
    .accessibilityLabel(date.formatted(locale: locale))
  }

  private var cellBackground: Color {
    if day?.closingBalanceMinor.minorUnits ?? 0 < 0 { return .red.opacity(0.1) }
    if isSelected { return .accentColor.opacity(0.1) }
    return Color(nsColor: .controlBackgroundColor)
  }
}

private struct DayMetric: View {
  let title: LocalizedStringKey
  let value: Money
  let locale: Locale
  var tint: Color = .primary

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value.formatted(locale: locale))
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .padding(9)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
  }
}

private struct CalendarOccurrenceRow: View {
  let occurrence: Occurrence
  let locale: Locale

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: occurrence.type == .income ? "arrow.down.left" : "arrow.up.right")
        .foregroundStyle(occurrence.type == .income ? .green : .orange)
      VStack(alignment: .leading, spacing: 2) {
        Text(occurrence.name)
          .lineLimit(1)
        if !occurrence.operation.note.isEmpty {
          Text(occurrence.operation.note)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      Spacer()
      Text(
        occurrence.amountMinor.formatted(
          locale: locale,
          sign: occurrence.type == .income ? "+" : "−"
        )
      )
      .font(.caption.weight(.semibold).monospacedDigit())
      .foregroundStyle(occurrence.type == .income ? .green : .primary)
      .lineLimit(1)
    }
    .padding(.vertical, 5)
  }
}
