import SwiftUI

struct NativeTodoTimeline: View {
  var accentColor: NativeAccentColor
  var events: [NativeCalendarEvent]
  var currentTimeHour: CGFloat?
  var i18n: NativeI18n

  private let timelineStart: CGFloat = 1
  private let timelineEnd: CGFloat = 24
  private let hourHeight: CGFloat = 58
  private let hourLineOffset: CGFloat = 9
  private let eventLaneStart: CGFloat = 60
  private let eventLaneCount: CGFloat = 4
  private let eventLaneGap: CGFloat = 8
  private let hours = Array(1...24)

  private var timelineHeight: CGFloat {
    hourLineOffset + CGFloat(hours.count - 1) * hourHeight + 80
  }

  var body: some View {
    GeometryReader { proxy in
      let laneWidth = eventWidth(containerWidth: proxy.size.width)

      ZStack(alignment: .topLeading) {
        VStack(spacing: 0) {
          ForEach(hours, id: \.self) { hour in
            NativeTodoTimelineHourRow(hour: hour, height: hourHeight, i18n: i18n)
          }
        }

        ForEach(events) { event in
          NativeTodoCalendarEventCard(accentColor: accentColor, event: event)
            .frame(width: laneWidth, height: eventHeight(for: event))
            .offset(
              x: eventXOffset(for: event, laneWidth: laneWidth),
              y: eventOffset(for: event)
            )
        }

        if let currentTimeHour {
          NativeTodoCurrentTimeLine(timeText: currentTimeText(for: currentTimeHour))
            .id(nativeTodoCurrentTimeLineID)
            .frame(width: proxy.size.width, alignment: .leading)
            .offset(x: 0, y: currentTimeOffset(for: currentTimeHour))
            .zIndex(10)
        }
      }
    }
    .frame(height: timelineHeight, alignment: .topLeading)
  }

  private func eventWidth(containerWidth: CGFloat) -> CGFloat {
    let availableWidth = max(0, containerWidth - eventLaneStart - eventLaneGap * (eventLaneCount - 1))
    return max(44, floor(availableWidth / eventLaneCount))
  }

  private func eventXOffset(for event: NativeCalendarEvent, laneWidth: CGFloat) -> CGFloat {
    eventLaneStart + CGFloat(event.lane) * (laneWidth + eventLaneGap)
  }

  private func eventOffset(for event: NativeCalendarEvent) -> CGFloat {
    let startHour = min(max(event.startHour, timelineStart), timelineEnd - 0.5)
    return hourLineOffset + (startHour - timelineStart) * hourHeight
  }

  private func eventHeight(for event: NativeCalendarEvent) -> CGFloat {
    let startHour = min(max(event.startHour, timelineStart), timelineEnd - 0.5)
    let availableHours = max(0.5, timelineEnd - startHour)
    return min(max(0.5, event.duration), availableHours) * hourHeight
  }

  private func currentTimeOffset(for hour: CGFloat) -> CGFloat {
    let boundedHour = min(max(hour, timelineStart), timelineEnd)
    return hourLineOffset + (boundedHour - timelineStart) * hourHeight
  }

  private func currentTimeText(for hour: CGFloat) -> String {
    let boundedHour = min(max(hour, timelineStart), timelineEnd)
    var wholeHour = Int(floor(boundedHour))
    var minute = Int(round((boundedHour - CGFloat(wholeHour)) * 60))
    if minute == 60 {
      wholeHour += 1
      minute = 0
    }

    return String(format: "%02d:%02d", min(wholeHour, 24), minute)
  }
}

struct NativeTodoCurrentTimeLine: View {
  var timeText: String

  private let indicatorColor = Color(red: 1, green: 0.23, blue: 0.18)

  var body: some View {
    HStack(spacing: 5) {
      Text(timeText)
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.white)
        .lineLimit(1)
        .frame(width: 48, height: 18)
        .background(indicatorColor)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .stroke(Color.white, lineWidth: 1.5)
        )

      Circle()
        .fill(indicatorColor)
        .frame(width: 9, height: 9)
        .overlay(
          Circle()
            .stroke(Color.white, lineWidth: 1.5)
        )

      ZStack {
        Rectangle()
          .fill(Color.white)
          .frame(height: 4)

        Rectangle()
          .fill(indicatorColor)
          .frame(height: 2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .offset(y: -9)
  }
}

struct NativeTodoTimelineHourRow: View {
  var hour: Int
  var height: CGFloat
  var i18n: NativeI18n

  private let hourLineOffset: CGFloat = 9

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      Text(i18n.timelineHour(hour))
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(Color.black.opacity(0.36))
        .frame(width: 44, alignment: .leading)
        .padding(.top, 2)

      ZStack(alignment: .topLeading) {
        Rectangle()
          .fill(Color.black.opacity(0.13))
          .frame(height: 1)
          .offset(y: hourLineOffset)

        if hour < 24 {
          Rectangle()
            .fill(Color.black.opacity(0.16))
            .frame(width: 18, height: 1)
            .offset(y: hourLineOffset + height / 2)
        }
      }
      .frame(height: height, alignment: .top)
    }
    .frame(height: height, alignment: .top)
  }
}

struct NativeTodoCalendarEventCard: View {
  var accentColor: NativeAccentColor
  var event: NativeCalendarEvent

  private var isCompact: Bool {
    event.duration <= 0.5
  }

  var body: some View {
    VStack(alignment: .leading, spacing: isCompact ? 2 : 10) {
      Text(event.title)
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(accentColor.foregroundColor)
        .lineLimit(isCompact ? 1 : 3)

      if !isCompact {
        Text(event.accent)
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(accentColor.foregroundColor.opacity(0.72))
          .lineLimit(2)

        Spacer()

        Text(event.timeText)
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(accentColor.foregroundColor.opacity(0.82))
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, isCompact ? 5 : 11)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(accentColor.color)
    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
  }
}
