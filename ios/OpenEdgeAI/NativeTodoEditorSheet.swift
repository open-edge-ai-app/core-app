import SwiftUI

struct NativeTodoEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: NativeChatStore

  var todoItem: NativeTodoItem?
  var selectedDate: Date

  @State private var title = ""
  @State private var note = ""
  @State private var startDate: Date
  @State private var endDate: Date
  @State private var repeatRule: NativeTodoRepeatRule
  @State private var selectedLabelIds: Set<String>

  init(selectedDate: Date) {
    self.todoItem = nil
    self.selectedDate = selectedDate
    let defaultStartDate = NativeTodoEditorSheet.defaultStartDate(for: selectedDate)
    _startDate = State(initialValue: defaultStartDate)
    _endDate = State(initialValue: NativeTodoEditorSheet.defaultEndDate(for: defaultStartDate))
    _repeatRule = State(initialValue: .none)
    _selectedLabelIds = State(initialValue: [])
  }

  init(todoItem: NativeTodoItem) {
    self.todoItem = todoItem
    self.selectedDate = todoItem.dueDate
    let startDate = NativeTodoEditorSheet.startDate(for: todoItem)
    _title = State(initialValue: todoItem.title)
    _note = State(initialValue: todoItem.note)
    _startDate = State(initialValue: startDate)
    _endDate = State(initialValue: NativeTodoEditorSheet.endDate(for: todoItem, startDate: startDate))
    _repeatRule = State(initialValue: todoItem.recurrenceRule)
    _selectedLabelIds = State(initialValue: Set(todoItem.labelIds))
  }

  private var isEditing: Bool {
    todoItem != nil
  }

  var body: some View {
    let i18n = store.i18n

    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 8) {
            Text(i18n.t(.todoTitleField))
              .font(.system(size: 13, weight: .bold))
              .foregroundColor(Color.black.opacity(0.48))
            TextField(i18n.t(.todoNewTaskPlaceholder), text: $title)
              .font(.system(size: 18, weight: .semibold))
              .textInputAutocapitalization(.sentences)
              .padding(.horizontal, 14)
              .frame(height: 50)
              .background(Color.black.opacity(0.055))
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }

          VStack(alignment: .leading, spacing: 8) {
            Text(i18n.t(.todoNoteField))
              .font(.system(size: 13, weight: .bold))
              .foregroundColor(Color.black.opacity(0.48))
            TextField(i18n.t(.todoOptionalDetails), text: $note, axis: .vertical)
              .font(.system(size: 16, weight: .medium))
              .lineLimit(3...6)
              .padding(14)
              .frame(minHeight: 94, alignment: .topLeading)
              .background(Color.black.opacity(0.055))
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }

          NativeTodoLabelPicker(
            i18n: i18n,
            labels: store.todoLabels,
            selectedLabelIds: $selectedLabelIds
          )

          VStack(alignment: .leading, spacing: 8) {
            Text(i18n.t(.todoSchedule))
              .font(.system(size: 13, weight: .bold))
              .foregroundColor(Color.black.opacity(0.48))

            VStack(spacing: 10) {
              NativeTodoDateTimeField(
                title: i18n.t(.todoStart),
                systemImage: "clock",
                date: $startDate,
                tintColor: store.accentColor.color
              )

              NativeTodoDateTimeField(
                title: i18n.t(.todoEnd),
                systemImage: "clock.badge.checkmark",
                date: $endDate,
                tintColor: store.accentColor.color
              )
            }
          }

          HStack(spacing: 12) {
            Text(i18n.t(.todoRepeat))
              .font(.system(size: 13, weight: .bold))
              .foregroundColor(Color.black.opacity(0.48))

            Spacer()

            Picker(i18n.t(.todoRepeat), selection: $repeatRule) {
              ForEach(NativeTodoRepeatRule.allCases) { rule in
                Text(rule.localizedTitle(i18n)).tag(rule)
              }
            }
            .pickerStyle(.menu)
            .tint(store.accentColor.color)
          }
          .padding(.horizontal, 14)
          .frame(height: 50)
          .background(Color.black.opacity(0.055))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 30)
      }
      .background(Color.white)
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(isEditing ? i18n.t(.todoEditTitle) : i18n.t(.todoAddTitle))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(i18n.t(.commonCancel)) {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(i18n.t(.commonSave)) {
            if let todoItem {
              store.updateTodo(
                todoItem,
                title: title,
                note: note,
                startDate: startDate,
                endDate: endDate,
                repeatRule: repeatRule,
                labelIds: Array(selectedLabelIds)
              )
            } else {
              store.createTodo(
                title: title,
                note: note,
                startDate: startDate,
                endDate: endDate,
                repeatRule: repeatRule,
                labelIds: Array(selectedLabelIds)
              )
            }
            dismiss()
          }
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onChange(of: startDate) { _, newValue in
        let minimumEndDate = Calendar.current.date(byAdding: .minute, value: 30, to: newValue) ?? newValue
        if endDate < minimumEndDate {
          endDate = NativeTodoEditorSheet.defaultEndDate(for: newValue)
        }
      }
      .onChange(of: endDate) { _, newValue in
        let minimumEndDate = Calendar.current.date(byAdding: .minute, value: 30, to: startDate) ?? startDate
        if newValue < minimumEndDate {
          endDate = minimumEndDate
        }
      }
    }
  }

  private static func defaultStartDate(for selectedDate: Date) -> Date {
    Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: selectedDate) ?? selectedDate
  }

  private static func defaultEndDate(for startDate: Date) -> Date {
    Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
  }

  private static func startDate(for item: NativeTodoItem) -> Date {
    date(on: item.dueDate, timelineHour: item.startHour)
  }

  private static func endDate(for item: NativeTodoItem, startDate: Date) -> Date {
    let durationMinutes = Int((max(0.5, item.durationHours) * 60).rounded())
    return Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startDate) ?? defaultEndDate(for: startDate)
  }

  private static func date(on baseDate: Date, timelineHour: Double) -> Date {
    let boundedHour = min(max(timelineHour, 1), 23.5)
    let hour = Int(floor(boundedHour))
    let minute = Int(round((boundedHour - Double(hour)) * 60))
    return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) ?? baseDate
  }
}

struct NativeTodoLabelPicker: View {
  var i18n: NativeI18n
  var labels: [NativeTodoLabel]
  @Binding var selectedLabelIds: Set<String>

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: 96), spacing: 8)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(i18n.t(.todoLabels))
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(Color.black.opacity(0.48))

      if labels.isEmpty {
        Text(i18n.t(.todoNoLabels))
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(Color.black.opacity(0.42))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 14)
          .padding(.vertical, 13)
          .background(Color.black.opacity(0.035))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      } else {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
          ForEach(labels) { label in
            NativeTodoTagChip(
              label: label,
              isSelected: selectedLabelIds.contains(label.id)
            ) {
              toggle(label)
            }
          }
        }
      }
    }
  }

  private func toggle(_ label: NativeTodoLabel) {
    if selectedLabelIds.contains(label.id) {
      selectedLabelIds.remove(label.id)
    } else {
      selectedLabelIds.insert(label.id)
    }
  }
}

struct NativeTodoTagChip: View {
  var label: NativeTodoLabel
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Circle()
          .fill(Color(todoLabelHex: label.colorHex))
          .frame(width: 9, height: 9)

        Text(label.title)
          .font(.system(size: 13, weight: .bold))
          .lineLimit(1)

        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
        }
      }
      .foregroundColor(.black)
      .padding(.horizontal, 11)
      .frame(height: 34)
      .frame(maxWidth: .infinity)
      .background(isSelected ? Color.black.opacity(0.10) : Color.black.opacity(0.045))
      .overlay(
        Capsule()
          .stroke(isSelected ? Color.black.opacity(0.34) : Color.black.opacity(0.08), lineWidth: 1)
      )
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

struct NativeTodoDateTimeField: View {
  var title: String
  var systemImage: String
  @Binding var date: Date
  var tintColor: Color

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(Color.black.opacity(0.48))
        .frame(width: 22)

      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.black)

      Spacer(minLength: 12)

      DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(tintColor)
    }
    .padding(.horizontal, 14)
    .frame(height: 54)
    .background(Color.black.opacity(0.055))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

extension Color {
  init(todoLabelHex hex: String) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&value)

    let red = Double((value >> 16) & 0xFF) / 255
    let green = Double((value >> 8) & 0xFF) / 255
    let blue = Double(value & 0xFF) / 255

    self.init(red: red, green: green, blue: blue)
  }
}
