import SwiftUI

struct NativeTodoListView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var store: NativeChatStore

  @State var selectedTab: NativeTodoTab = .all
  @State var isOverdueExpanded = true
  @State var isTodayExpanded = true
  @State var selectedDate = Date()
  @State var currentDate = Date()
  @State var showingComposer = false
  @State var showingSettings = false
  @State var editingTodo: NativeTodoItem?
  @State var expandedTaskIds: Set<String> = []
  @State var recurringDeleteRequest: NativeRecurringTodoDeleteRequest?

  var calendar: Calendar {
    Calendar.current
  }

  var overdueTodos: [NativeTodoItem] {
    store.todoItems.filter { $0.isOverdue() }
  }

  var selectedDateTodos: [NativeTodoItem] {
    store.todoItems.filter { item in
      guard !item.isOverdue(), item.occurs(on: selectedDate, calendar: calendar) else {
        return false
      }
      return !store.todoHideCompletedTasks || !item.isCompleted(on: selectedDate, calendar: calendar)
    }
  }

  var calendarEvents: [NativeCalendarEvent] {
    selectedDateTodos.enumerated().map { index, item in
      NativeCalendarEvent(
        id: item.id,
        task: item,
        title: item.title,
        note: item.note.trimmingCharacters(in: .whitespacesAndNewlines),
        labels: store.todoTagsVisibleOnTaskCards ? labels(for: item) : [],
        startHour: CGFloat(item.startHour),
        duration: CGFloat(max(0.5, item.durationHours)),
        lane: index % 4,
        timeText: eventTimeText(for: item),
        isCompleted: item.isCompleted(on: selectedDate, calendar: calendar)
      )
    }
  }

  var currentTimeHour: CGFloat? {
    guard calendar.isDateInToday(selectedDate) else {
      return nil
    }

    let components = calendar.dateComponents([.hour, .minute], from: currentDate)
    let hour = CGFloat(components.hour ?? 0) + CGFloat(components.minute ?? 0) / 60
    guard hour >= 1 && hour <= 24 else {
      return nil
    }

    return hour
  }

  var dateTitle: String {
    store.i18n.dateTitle(for: selectedDate)
  }

  var selectedTodoSectionTitle: String {
    store.i18n.t(.todoTasks)
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      VStack(spacing: 0) {
        topBar

        header

        Divider()
          .background(Color.oeSeparator)

        if selectedTab == .all {
          allTasksContent
        } else {
          calendarContent
        }
      }
      .background(Color.oeBackground)

      bottomControls
    }
    .background(Color.oeBackground.ignoresSafeArea())
    .sheet(isPresented: $showingComposer) {
      NativeTodoEditorSheet(selectedDate: selectedDate)
        .environmentObject(store)
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
    }
    .sheet(item: $editingTodo) { item in
      NativeTodoEditorSheet(todoItem: item)
        .environmentObject(store)
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $showingSettings) {
      NativeTodoSettingsSheet()
        .environmentObject(store)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    .confirmationDialog(
      store.i18n.t(.todoDeleteRepeatTitle),
      isPresented: isShowingRecurringDeleteDialog,
      titleVisibility: .visible
    ) {
      if let recurringDeleteRequest {
        Button(store.i18n.t(.todoDeleteThisOccurrence)) {
          withAnimation(.easeInOut(duration: 0.18)) {
            store.deleteTodoOccurrence(
              recurringDeleteRequest.task,
              occurrenceDate: recurringDeleteRequest.occurrenceDate
            )
          }
          self.recurringDeleteRequest = nil
        }

        Button(store.i18n.t(.todoDeleteEntireSeries), role: .destructive) {
          withAnimation(.easeInOut(duration: 0.18)) {
            store.deleteTodo(recurringDeleteRequest.task)
          }
          self.recurringDeleteRequest = nil
        }
      }

      Button(store.i18n.t(.commonCancel), role: .cancel) {
        recurringDeleteRequest = nil
      }
    } message: {
      Text(store.i18n.t(.todoDeleteRepeatMessage))
    }
    .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
      currentDate = date
    }
    .toolbar(.hidden, for: .navigationBar)
  }



  private var isShowingRecurringDeleteDialog: Binding<Bool> {
    Binding(
      get: { recurringDeleteRequest != nil },
      set: { isPresented in
        if !isPresented {
          recurringDeleteRequest = nil
        }
      }
    )
  }
}
