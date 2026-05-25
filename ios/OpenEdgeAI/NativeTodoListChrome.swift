import SwiftUI

extension NativeTodoListView {
  var topBar: some View {
    let i18n = store.i18n

    return HStack(spacing: 12) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: 36, height: 36)
          .background(.ultraThinMaterial, in: Circle())
          .overlay(
            Circle()
              .stroke(Color.oeBorder.opacity(0.18), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoBackToMenu))

      Text(i18n.t(.todoListTitle))
        .font(.system(size: 15, weight: .semibold))
        .lineLimit(1)

      Spacer(minLength: 8)

      Button {
        showingSettings = true
      } label: {
        Image(systemName: "gearshape")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: 36, height: 36)
          .background(.ultraThinMaterial, in: Circle())
          .overlay(
            Circle()
              .stroke(Color.oeBorder.opacity(0.18), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
      .accessibilityLabel(i18n.t(.todoSettings))
    }
    .foregroundColor(.oeText)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 8)
  }

  var header: some View {
    let i18n = store.i18n

    return VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .center) {
        Text(dateTitle)
          .font(.system(size: 31, weight: .bold))
          .foregroundColor(.oeText)
          .lineLimit(1)

        Spacer()
      }

      NativeTodoWeekStrip(
        accentColor: store.accentColor,
        i18n: i18n,
        selectedDate: selectedDate,
        onPreviousWeek: { moveSelectedDate(byDays: -7) },
        onNextWeek: { moveSelectedDate(byDays: 7) },
        onSelectDate: { date in selectedDate = date }
      )

      Picker(i18n.t(.todoViewPicker), selection: $selectedTab) {
        Text(i18n.t(.todoTabList)).tag(NativeTodoTab.all)
        Text(i18n.t(.todoTabCalendar)).tag(NativeTodoTab.calendar)
      }
      .pickerStyle(.segmented)
    }
    .padding(.horizontal, nativeTodoHorizontalPadding)
    .padding(.top, 24)
    .padding(.bottom, 18)
  }

}
