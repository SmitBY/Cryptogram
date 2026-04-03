import SwiftUI

private enum LevelDrawerItemState {
    case current
    case passed
    case completed
    case available
}

private enum LevelDrawerTextKey: String {
    case title = "levelDrawer_title"
    case currentPrefix = "levelDrawer_currentPrefix"
    case completedPrefix = "levelDrawer_completedPrefix"
    case closeLabel = "levelDrawer_closeLabel"
    case currentStatus = "levelDrawer_currentStatus"
    case passedStatus = "levelDrawer_passedStatus"
    case completedStatus = "levelDrawer_completedStatus"
    case availableStatus = "levelDrawer_availableStatus"
}

private struct LevelDrawerCopy {
    let title: String
    let currentPrefix: String
    let completedPrefix: String
    let closeLabel: String
    let currentStatus: String
    let passedStatus: String
    let completedStatus: String
    let availableStatus: String

    func currentLevel(_ levelNumber: Int) -> String {
        "\(currentPrefix) \(levelNumber)"
    }

    func completedProgress(_ completed: Int, _ total: Int) -> String {
        "\(completedPrefix) \(completed)/\(total)"
    }

    func accessibilityLabel(for levelNumber: Int, status: LevelDrawerItemState) -> String {
        let statusText: String

        switch status {
        case .current:
            statusText = currentStatus
        case .passed:
            statusText = passedStatus
        case .completed:
            statusText = completedStatus
        case .available:
            statusText = availableStatus
        }

        return "\(currentPrefix) \(levelNumber), \(statusText)"
    }

    static func forLanguage(_ language: AppLanguage) -> LevelDrawerCopy {
        LevelDrawerCopy(
            title: language.localizedString(LevelDrawerTextKey.title.rawValue),
            currentPrefix: language.localizedString(LevelDrawerTextKey.currentPrefix.rawValue),
            completedPrefix: language.localizedString(LevelDrawerTextKey.completedPrefix.rawValue),
            closeLabel: language.localizedString(LevelDrawerTextKey.closeLabel.rawValue),
            currentStatus: language.localizedString(LevelDrawerTextKey.currentStatus.rawValue),
            passedStatus: language.localizedString(LevelDrawerTextKey.passedStatus.rawValue),
            completedStatus: language.localizedString(LevelDrawerTextKey.completedStatus.rawValue),
            availableStatus: language.localizedString(LevelDrawerTextKey.availableStatus.rawValue)
        )
    }
}

private struct LevelDrawerFeatureModifier: ViewModifier {
    @Binding var isPresented: Bool

    let isEnabled: Bool
    let language: AppLanguage
    let totalLevels: Int
    let currentLevelIndex: Int
    let completedIndices: Set<Int>
    let passedIndices: Set<Int>
    let onSelectLevel: (Int) -> Void

    @GestureState private var openDragTranslation: CGFloat = 0

    private let edgeActivationWidth: CGFloat = 24
    private let minDrawerWidth: CGFloat = 272
    private let maxDrawerWidth: CGFloat = 340

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    let drawerWidth = min(maxDrawerWidth, max(minDrawerWidth, geometry.size.width * 0.82))
                    let revealedWidth = min(max(openDragTranslation, 0), drawerWidth)
                    let isDrawerVisible = isEnabled && (isPresented || revealedWidth > 0)
                    let drawerOffset = isPresented ? 0 : (-drawerWidth + revealedWidth)
                    let openProgress = isPresented ? 1 : (revealedWidth / drawerWidth)

                    ZStack(alignment: .leading) {
                        if isDrawerVisible {
                            Color.black.opacity(0.22 * openProgress)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    closeDrawer()
                                }

                            drawerPanel(drawerWidth: drawerWidth)
                                .offset(x: drawerOffset)
                                .transition(.move(edge: .leading))
                        }

                        if isEnabled && !isPresented {
                            Color.clear
                                .frame(width: edgeActivationWidth)
                                .frame(maxHeight: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .gesture(openGesture(drawerWidth: drawerWidth))
                        }
                    }
                }
            }
            .animation(.spring(response: 0.26, dampingFraction: 0.88), value: isPresented)
            .onChange(of: isEnabled) { _, enabled in
                guard !enabled, isPresented else {
                    return
                }

                closeDrawer()
            }
    }

    private func drawerPanel(drawerWidth: CGFloat) -> some View {
        let copy = LevelDrawerCopy.forLanguage(language)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    statusBadge(
                        text: copy.currentLevel(currentLevelIndex + 1),
                        systemImage: "scope",
                        color: .blue
                    )

                    statusBadge(
                        text: copy.completedProgress(completedIndices.count, totalLevels),
                        systemImage: "checkmark.circle.fill",
                        color: .green
                    )
                }

                Spacer(minLength: 0)

                Button(action: closeDrawer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copy.closeLabel)
            }

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                    ForEach(Array(0..<totalLevels), id: \.self) { index in
                        levelButton(index: index, copy: copy)
                    }
                }
                .padding(.bottom, 18)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .frame(width: drawerWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 18, x: 8)
    }

    private func statusBadge(text: String, systemImage: String, color: Color) -> some View {
        Label {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }

    private func levelButton(index: Int, copy: LevelDrawerCopy) -> some View {
        let state = state(for: index)
        let color = accentColor(for: state)
        let iconName = iconName(for: state)

        return Button {
            closeDrawer()

            guard index != currentLevelIndex else {
                return
            }

            onSelectLevel(index)
        } label: {
            VStack(spacing: 7) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)

                Text("\(index + 1)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .padding(.vertical, 6)
            .background(backgroundColor(for: state), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor(for: state), lineWidth: state == .current ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copy.accessibilityLabel(for: index + 1, status: state))
    }

    private func state(for index: Int) -> LevelDrawerItemState {
        if index == currentLevelIndex {
            return .current
        }

        if passedIndices.contains(index) {
            return .passed
        }

        if completedIndices.contains(index) {
            return .completed
        }

        return .available
    }

    private func iconName(for state: LevelDrawerItemState) -> String {
        switch state {
        case .current:
            return "play.circle.fill"
        case .passed:
            return "checkmark.circle.fill"
        case .completed:
            return "exclamationmark.circle.fill"
        case .available:
            return "circle"
        }
    }

    private func accentColor(for state: LevelDrawerItemState) -> Color {
        switch state {
        case .current:
            return .blue
        case .passed:
            return .green
        case .completed:
            return .orange
        case .available:
            return .secondary
        }
    }

    private func backgroundColor(for state: LevelDrawerItemState) -> Color {
        switch state {
        case .current:
            return Color.blue.opacity(0.16)
        case .passed:
            return Color.green.opacity(0.16)
        case .completed:
            return Color.orange.opacity(0.16)
        case .available:
            return Color.secondary.opacity(0.08)
        }
    }

    private func borderColor(for state: LevelDrawerItemState) -> Color {
        switch state {
        case .current:
            return Color.blue.opacity(0.85)
        case .passed:
            return Color.green.opacity(0.45)
        case .completed:
            return Color.orange.opacity(0.45)
        case .available:
            return Color.primary.opacity(0.12)
        }
    }

    private func openGesture(drawerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($openDragTranslation) { value, state, _ in
                guard value.startLocation.x <= edgeActivationWidth, value.translation.width > 0 else {
                    return
                }

                state = min(value.translation.width, drawerWidth)
            }
            .onEnded { value in
                guard value.startLocation.x <= edgeActivationWidth else {
                    return
                }

                let shouldOpen = value.translation.width > drawerWidth * 0.32
                    || value.predictedEndTranslation.width > drawerWidth * 0.5

                if shouldOpen {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                        isPresented = true
                    }
                }
            }
    }

    private func closeDrawer() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            isPresented = false
        }
    }
}

extension View {
    func levelDrawerFeature(
        isPresented: Binding<Bool>,
        isEnabled: Bool,
        language: AppLanguage,
        totalLevels: Int,
        currentLevelIndex: Int,
        completedIndices: Set<Int>,
        passedIndices: Set<Int>,
        onSelectLevel: @escaping (Int) -> Void
    ) -> some View {
        modifier(
            LevelDrawerFeatureModifier(
                isPresented: isPresented,
                isEnabled: isEnabled,
                language: language,
                totalLevels: totalLevels,
                currentLevelIndex: currentLevelIndex,
                completedIndices: completedIndices,
                passedIndices: passedIndices,
                onSelectLevel: onSelectLevel
            )
        )
    }
}
