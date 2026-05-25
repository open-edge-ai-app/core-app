import SwiftUI

enum NativeOnboardingScene {
  case workspace
  case todo
  case document
  case progress
}

struct NativeOnboardingIllustration: View {
  var scene: NativeOnboardingScene
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .fill(Color.oeSurface.opacity(0.74))
        .nativeLiquidGlass(cornerRadius: 30)
        .nativeGlassStroke(cornerRadius: 30, color: Color.oeBorder.opacity(0.18))

      switch scene {
      case .workspace:
        NativeOnboardingWorkspaceScene(accentColor: accentColor)
      case .todo:
        NativeOnboardingTodoScene(accentColor: accentColor)
      case .document:
        NativeOnboardingDocumentScene(accentColor: accentColor)
      case .progress:
        NativeOnboardingProgressScene(accentColor: accentColor)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
  }
}

private struct NativeOnboardingWorkspaceScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 9) {
        Image("OpenEdgeLogo")
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(Color.oeText)
          .frame(width: 24, height: 24)

        Text("open edge ai")
          .font(.system(size: 15, weight: .heavy))
          .foregroundColor(.oeText)

        Spacer()

        NativeOnboardingIconPill(systemName: "magnifyingglass")
        NativeOnboardingIconPill(systemName: "gearshape")
      }

      NativeOnboardingMenuRow(systemName: "checklist", title: "Todo List")

      NativeOnboardingSectionTitle("PROJECTS")
      NativeOnboardingMenuRow(systemName: "chart.bar", title: "Customer Data Analysis")
      NativeOnboardingMenuRow(systemName: "folder", title: "Security Compliance Center")
      NativeOnboardingMenuRow(systemName: "doc.text", title: "Legal Document Review")

      NativeOnboardingSectionTitle("RECENT")
      NativeOnboardingRecentLine("New business strategy recap")
      NativeOnboardingRecentLine("Private investor meeting notes")

      Spacer(minLength: 0)
    }
    .padding(22)
    .overlay(alignment: .bottomTrailing) {
      NativeOnboardingPetCluster(pet: .orbit, motion: .resting, label: "Noa", accentColor: accentColor)
        .padding(.trailing, 16)
        .padding(.bottom, 12)
    }
  }
}

private struct NativeOnboardingDocumentScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      NativeOnboardingMiniTopBar(title: "Legal Document Review", trailing: "ellipsis")

      VStack(alignment: .leading, spacing: 9) {
        NativeOnboardingDocumentListRow(title: "NDA contract review", preview: "David Han shared NDA_Agree...pdf")
        NativeOnboardingDocumentListRow(title: "Supplier risk analysis", preview: "Review risk clauses and obligations...")
        NativeOnboardingDocumentListRow(title: "Privacy clause check", preview: "Find sensitive data terms...")
      }
      .padding(.top, 4)

      Spacer(minLength: 0)

      HStack {
        Spacer()
        HStack(spacing: 7) {
          Image(systemName: "doc")
          Text("NDA_Agree...pdf")
            .lineLimit(1)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(.oeText)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color.oeMutedText.opacity(0.13), in: Capsule(style: .continuous))
      }

      Text("Find risky terms and summarize only what needs review.")
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(.white)
        .lineLimit(2)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Color.oeText, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

      HStack(spacing: 10) {
        NativeOnboardingPetCluster(pet: .nullSignal, motion: .resting, label: "Sia", accentColor: accentColor)
        NativeOnboardingPetCluster(pet: .luma, motion: .running, label: "Lumi", accentColor: accentColor)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(22)
  }
}

private struct NativeOnboardingTodoScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      NativeOnboardingMiniTopBar(title: "Todo List", trailing: "gearshape")

      Text("May 20 (Wed)")
        .font(.system(size: 24, weight: .heavy))
        .foregroundColor(.oeText)

      HStack(spacing: 8) {
        ForEach(["Sun", "Mon", "Tue", "Wed", "Thu"], id: \.self) { day in
          VStack(spacing: 4) {
            Text(day)
              .font(.system(size: 8, weight: .bold))
            Text(day == "Wed" ? "20" : day == "Thu" ? "21" : day == "Tue" ? "19" : day == "Mon" ? "18" : "17")
              .font(.system(size: 10, weight: .semibold))
            if day == "Wed" {
              Circle()
                .fill(Color.oeText)
                .frame(width: 4, height: 4)
            }
          }
          .foregroundColor(day == "Wed" ? .oeText : .oeSecondaryText)
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(day == "Wed" ? Color.oeMutedText.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
      }

      HStack(spacing: 0) {
        Text("List")
          .frame(maxWidth: .infinity)
          .frame(height: 30)
          .background(Color.oeSurface, in: Capsule(style: .continuous))
        Text("Calendar")
          .frame(maxWidth: .infinity)
          .foregroundColor(.oeSecondaryText)
      }
      .font(.system(size: 11, weight: .bold))
      .padding(3)
      .background(Color.oeMutedText.opacity(0.12), in: Capsule(style: .continuous))

      VStack(spacing: 9) {
        NativeOnboardingTaskRow(title: "Customer requirements tags", isDone: true)
        NativeOnboardingTaskRow(title: "Monthly infra report", isDone: false)
        NativeOnboardingTaskRow(title: "Security audit packet", isDone: false)
      }

      Spacer(minLength: 0)
    }
    .padding(22)
    .overlay(alignment: .bottomTrailing) {
      NativeOnboardingWandPet(accentColor: accentColor)
        .padding(.trailing, 18)
        .padding(.bottom, 12)
    }
  }
}

private struct NativeOnboardingProgressScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      NativeOnboardingMiniTopBar(title: "Today priority", trailing: "Gemma 4")

      HStack {
        Spacer()
        Text("Prioritize today's tasks")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(.white)
          .padding(.horizontal, 16)
          .frame(height: 38)
          .background(Color.oeText, in: Capsule(style: .continuous))
      }

      VStack(alignment: .leading, spacing: 9) {
        Text("Live answer")
          .font(.system(size: 11, weight: .heavy))
          .foregroundColor(.oeSecondaryText)
        NativeOnboardingPriorityLine(number: "1", title: "Security audit packet")
        NativeOnboardingPriorityLine(number: "2", title: "Monthly infra report")
        NativeOnboardingPriorityLine(number: "3", title: "NDA risk review")
      }
      .padding(14)
      .background(Color.oeBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

      Spacer(minLength: 0)

      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(Color.oeText)
        .frame(height: 58)
        .overlay {
          HStack(spacing: 12) {
            NativeDynamicIslandPetView(pet: .flux, motion: .running, size: 34)
              .frame(width: 40, height: 38)

            VStack(alignment: .leading, spacing: 5) {
              Text("Generating")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
              ProgressView(value: 0.68)
                .tint(.white)
            }

            NativeOnboardingSpinner()
              .frame(width: 22, height: 22)
          }
          .padding(.horizontal, 18)
        }
    }
    .padding(22)
  }
}

private struct NativeOnboardingPetCluster: View {
  var pet: NativeDynamicIslandPet
  var motion: NativeDynamicIslandPetMotion
  var label: String
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(spacing: 3) {
      NativeDynamicIslandPetView(pet: pet, motion: motion, size: 54)
        .frame(width: 66, height: 62)
      Text(label)
        .font(.system(size: 9, weight: .black))
        .foregroundColor(.oeSecondaryText)
    }
    .padding(9)
    .background(Color.oeBackground.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .nativeGlassStroke(cornerRadius: 18, color: accentColor.color.opacity(0.12))
  }
}

private struct NativeOnboardingWandPet: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack(alignment: .topTrailing) {
      NativeOnboardingPetCluster(pet: .stacky, motion: .running, label: "Mino", accentColor: accentColor)
      Rectangle()
        .fill(Color.oeText)
        .frame(width: 2, height: 30)
        .rotationEffect(.degrees(46))
        .offset(x: 10, y: 4)
      ForEach(0..<4, id: \.self) { index in
        Image(systemName: "sparkle")
          .font(.system(size: index == 0 ? 9 : 7, weight: .bold))
          .foregroundColor(accentColor.color)
          .offset(x: CGFloat(index * 11 - 12), y: CGFloat(index.isMultiple(of: 2) ? -11 : 1))
      }
    }
  }
}

private struct NativeOnboardingMiniTopBar: View {
  var title: String
  var trailing: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "line.3.horizontal")
        .font(.system(size: 15, weight: .bold))
      Text(title)
        .font(.system(size: 15, weight: .heavy))
        .lineLimit(1)
      Spacer()
      if trailing == "Gemma 4" {
        Text(trailing)
          .font(.system(size: 11, weight: .heavy))
          .padding(.horizontal, 11)
          .frame(height: 28)
          .background(Color.oeSurface, in: Capsule(style: .continuous))
      } else {
        Image(systemName: trailing)
          .font(.system(size: 15, weight: .bold))
      }
    }
    .foregroundColor(.oeText)
  }
}

private struct NativeOnboardingIconPill: View {
  var systemName: String

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 13, weight: .bold))
      .foregroundColor(.oeText)
      .frame(width: 30, height: 30)
      .background(Color.oeBackground.opacity(0.82), in: Circle())
  }
}

private struct NativeOnboardingMenuRow: View {
  var systemName: String
  var title: String

  var body: some View {
    HStack(spacing: 13) {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .bold))
        .frame(width: 20)
      Text(title)
        .font(.system(size: 13, weight: .bold))
        .lineLimit(1)
      Spacer()
    }
    .foregroundColor(.oeText)
  }
}

private struct NativeOnboardingSectionTitle: View {
  var title: String

  init(_ title: String) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .font(.system(size: 10, weight: .heavy))
      .foregroundColor(.oeSecondaryText)
      .padding(.top, 3)
  }
}

private struct NativeOnboardingRecentLine: View {
  var title: String

  init(_ title: String) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .font(.system(size: 12, weight: .semibold))
      .foregroundColor(.oeText)
      .lineLimit(1)
  }
}

private struct NativeOnboardingDocumentListRow: View {
  var title: String
  var preview: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.system(size: 13, weight: .heavy))
        .foregroundColor(.oeText)
      Text(preview)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.oeMutedText)
        .lineLimit(1)
    }
  }
}

private struct NativeOnboardingTaskRow: View {
  var title: String
  var isDone: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
        .foregroundColor(isDone ? .red.opacity(0.72) : .oeMutedText)
      VStack(alignment: .leading, spacing: 5) {
        Text(title)
          .font(.system(size: 12, weight: .heavy))
          .foregroundColor(.oeText)
          .lineLimit(1)
        Text("Today · Todo")
          .font(.system(size: 9, weight: .bold))
          .foregroundColor(.oeMutedText)
      }
      Spacer()
      Image(systemName: "star")
        .foregroundColor(.oeSecondaryText)
    }
    .padding(.horizontal, 12)
    .frame(height: 52)
    .background(Color.oeBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .nativeGlassStroke(cornerRadius: 16, color: Color.oeBorder.opacity(0.18))
  }
}

private struct NativeOnboardingPriorityLine: View {
  var number: String
  var title: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Text(number)
        .font(.system(size: 14, weight: .heavy))
        .foregroundColor(.oeMutedText)
      Text(title)
        .font(.system(size: 13, weight: .heavy))
        .foregroundColor(.oeText)
        .lineLimit(1)
    }
  }
}

private struct NativeOnboardingSpinner: View {
  var body: some View {
    Circle()
      .trim(from: 0.08, to: 0.72)
      .stroke(.white.opacity(0.82), style: StrokeStyle(lineWidth: 3, lineCap: .round))
      .rotationEffect(.degrees(32))
  }
}
