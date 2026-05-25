import SwiftUI

extension NativeTodoListView {
var calendarContent: some View {
    let i18n = store.i18n

    return VStack(spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
          NativeTodoTimeline(
            accentColor: store.accentColor,
            events: calendarEvents,
            currentTimeHour: currentTimeHour,
            i18n: i18n,
            onEditEvent: { task in
              editingTodo = task
            },
            onDeleteEvent: { task in
              requestDelete(task, occurrenceDate: selectedDate)
            }
          )
            .padding(.bottom, 132)
        }
        .onAppear {
          scrollCalendarToCurrentTime(proxy)
        }
        .onChange(of: selectedDate) { _, _ in
          scrollCalendarToCurrentTime(proxy)
        }
      }
    }
    .padding(.horizontal, nativeTodoHorizontalPadding)
  }

  var bottomControls: some View {
    let i18n = store.i18n

    return HStack {
      Spacer()
      Button {
        showingComposer = true
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 31, weight: .light))
          .foregroundColor(store.accentColor.foregroundColor)
          .frame(width: 56, height: 56)
          .background(
            store.accentColor.color,
            in: Circle()
          )
          .overlay(
            Circle()
              .stroke(Color.oeBorder.opacity(0.18), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoAdd))
    }
    .padding(.horizontal, nativeTodoHorizontalPadding)
    .padding(.bottom, 24)
  }

  func moveSelectedDate(byDays days: Int) {
    selectedDate = calendar.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
  }

  func eventTimeText(for item: NativeTodoItem) -> String {
    let start = item.startHour
    let end = min(24, item.startHour + item.durationHours)
    return "\(hourText(start)) - \(hourText(end))"
  }

  func hourText(_ hour: Double) -> String {
    let boundedHour = min(max(hour, 1), 24)
    var wholeHour = Int(floor(boundedHour))
    var minute = Int(round((boundedHour - Double(wholeHour)) * 60))
    if minute == 60 {
      wholeHour += 1
      minute = 0
    }

    if minute == 0 {
      return store.i18n.timelineHour(wholeHour)
    }
    return String(format: "%02d:%02d", wholeHour, minute)
  }

  func scrollCalendarToCurrentTime(_ proxy: ScrollViewProxy) {
    guard currentTimeHour != nil else {
      return
    }

    DispatchQueue.main.async {
      withAnimation(.easeInOut(duration: 0.2)) {
        proxy.scrollTo(nativeTodoCurrentTimeLineID, anchor: .center)
      }
    }
  }
}
