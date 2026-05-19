import SwiftUI

struct NativeTodoWeekStrip: View {
  var accentColor: NativeAccentColor
  var i18n: NativeI18n
  var selectedDate: Date
  var onPreviousWeek: () -> Void
  var onNextWeek: () -> Void
  var onSelectDate: (Date) -> Void

  private let dayCellWidth: CGFloat = 44
  private let dayCellSpacing: CGFloat = 8
  private let initialLeadingDays = 21
  private let initialDayCount = 43
  private let edgeExtensionDays = 14

  @State private var dayRangeStart = Calendar.current.startOfDay(for: Date())
  @State private var dayRangeCount = 43
  @State private var hasInitializedRange = false
  @State private var scrollPositionID: String?
  @State private var isApplyingScrollSelection = false

  private var days: [Date] {
    let calendar = Calendar.current
    return (0..<dayRangeCount).compactMap {
      calendar.date(byAdding: .day, value: $0, to: dayRangeStart)
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      Button(action: onPreviousWeek) {
        Image(systemName: "chevron.left")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(Color.black.opacity(0.58))
          .frame(width: 24, height: 52)
      }
      .buttonStyle(.plain)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: dayCellSpacing) {
          ForEach(days, id: \.self) { day in
            let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
            let isToday = Calendar.current.isDateInToday(day)

            Button {
              let id = dayID(for: day)
              ensureRangeContains(day)
              withAnimation(.easeInOut(duration: 0.18)) {
                scrollPositionID = id
              }
              onSelectDate(day)
            } label: {
              VStack(spacing: 3) {
                Text(i18n.weekdayLetter(for: day))
                  .font(.system(size: 13, weight: .bold))
                Text(i18n.dayNumber(for: day))
                  .font(.system(size: 12, weight: .semibold))
                Circle()
                  .fill(Color.black)
                  .frame(width: 4, height: 4)
                  .opacity(isToday ? 1 : 0)
              }
              .foregroundColor(isSelected ? accentColor.color : Color.black.opacity(0.60))
              .frame(width: dayCellWidth, height: 52)
              .background(isSelected ? accentColor.subtleColor : Color.clear)
              .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .id(dayID(for: day))
            .onAppear {
              extendRangeIfNeeded(for: day)
            }
          }
        }
        .padding(.horizontal, dayCellSpacing)
        .scrollTargetLayout()
      }
      .scrollTargetBehavior(.viewAligned)
      .scrollPosition(id: $scrollPositionID, anchor: .center)
      .frame(height: 52)
      .onAppear {
        initializeRangeIfNeeded(around: selectedDate)
        scrollPositionID = dayID(for: selectedDate)
      }
      .onChange(of: scrollPositionID) { _, newValue in
        guard let newValue,
              let date = dateFromDayID(newValue),
              !Calendar.current.isDate(date, inSameDayAs: selectedDate) else {
          return
        }
        isApplyingScrollSelection = true
        onSelectDate(date)
      }
      .onChange(of: selectedDate) { _, newValue in
        initializeRangeIfNeeded(around: newValue)
        ensureRangeContains(newValue)
        let id = dayID(for: newValue)

        guard scrollPositionID != id else {
          isApplyingScrollSelection = false
          return
        }

        if isApplyingScrollSelection {
          isApplyingScrollSelection = false
          return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
          scrollPositionID = id
        }
      }

      Button(action: onNextWeek) {
        Image(systemName: "chevron.right")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(Color.black.opacity(0.58))
          .frame(width: 24, height: 52)
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
  }

  private func initializeRangeIfNeeded(around date: Date) {
    guard !hasInitializedRange else {
      return
    }

    resetRange(around: date)
    hasInitializedRange = true
  }

  private func resetRange(around date: Date) {
    let calendar = Calendar.current
    let selectedDay = calendar.startOfDay(for: date)
    dayRangeStart = calendar.date(byAdding: .day, value: -initialLeadingDays, to: selectedDay) ?? selectedDay
    dayRangeCount = initialDayCount
  }

  private func ensureRangeContains(_ date: Date) {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: date)
    let rangeEnd = calendar.date(byAdding: .day, value: max(0, dayRangeCount - 1), to: dayRangeStart) ?? dayRangeStart

    if day < dayRangeStart {
      let missingDays = calendar.dateComponents([.day], from: day, to: dayRangeStart).day ?? 0
      let prependDays = missingDays + edgeExtensionDays
      dayRangeStart = calendar.date(byAdding: .day, value: -prependDays, to: dayRangeStart) ?? dayRangeStart
      dayRangeCount += prependDays
    } else if day > rangeEnd {
      let missingDays = calendar.dateComponents([.day], from: rangeEnd, to: day).day ?? 0
      dayRangeCount += missingDays + edgeExtensionDays
    }
  }

  private func extendRangeIfNeeded(for day: Date) {
    guard let firstDay = days.first, let lastDay = days.last else {
      return
    }

    let calendar = Calendar.current
    if calendar.isDate(day, inSameDayAs: firstDay) {
      prependRange()
    } else if calendar.isDate(day, inSameDayAs: lastDay) {
      dayRangeCount += edgeExtensionDays
    }
  }

  private func prependRange() {
    let currentScrollID = scrollPositionID
    dayRangeStart = Calendar.current.date(
      byAdding: .day,
      value: -edgeExtensionDays,
      to: dayRangeStart
    ) ?? dayRangeStart
    dayRangeCount += edgeExtensionDays

    guard let currentScrollID else {
      return
    }

    DispatchQueue.main.async {
      scrollPositionID = currentScrollID
    }
  }

  private func dayID(for date: Date) -> String {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
  }

  private func dateFromDayID(_ id: String) -> Date? {
    let values = id.split(separator: "-").compactMap { Int($0) }
    guard values.count == 3 else {
      return nil
    }

    return Calendar.current.date(from: DateComponents(
      year: values[0],
      month: values[1],
      day: values[2]
    ))
  }
}
