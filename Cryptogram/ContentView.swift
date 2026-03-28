//
//  ContentView.swift
//  Cryptogram
//
//  Created by Dmitriy on 18/03/2026.
//

import Foundation
import SwiftUI

struct ContentView: View {
    private enum FirstGameTutorialStep: Equatable {
        case pickTile
        case enterLetter
        case openHintMode
        case useHint
    }

    private static let maxMistakes = 3
    private static let tileWidth: CGFloat = 24
    private static let tileCellHeight: CGFloat = 30
    private static let tileCodeHeight: CGFloat = 14
    private static let tileCodeSpacing: CGFloat = 2
    private static let tileHeight: CGFloat = 46
    private static let tileSpacing: CGFloat = 3
    private static let rowSpacing: CGFloat = 10
    private static let spaceWidth: CGFloat = 6
    private static let wordSpacing: CGFloat = 18
    private static let easyStartLevelCount = 10
    private static let easyStartRevealFraction = 0.55
    private static let tutorialRevealFraction = 0.5

    @AppStorage(ProgressStorageKey.hasCompletedFirstGameTutorial) private var hasCompletedFirstGameTutorial = false
    @AppStorage(ProgressStorageKey.selectedTheme) private var storedTheme = AppTheme.system.rawValue
    @AppStorage(ProgressStorageKey.selectedLanguage) private var storedLanguage = AppLanguage.system.rawValue
    @StateObject private var purchaseManager = PurchaseManager()

    @State private var currentLanguage: AppLanguage
    @State private var phraseEntries: [PhraseEntry]
    @State private var phraseDatasetSignature: String
    @State private var currentPhraseIndex: Int
    @State private var tiles: [PhraseTile]
    @State private var selectedTileIndex: Int?
    @State private var mistakes: Int
    @State private var flashingWrongGuesses: Set<WrongGuess>
    @State private var roundStatus: RoundStatus
    @State private var isHintMode: Bool
    @State private var completedPhraseIndices: Set<Int>
    @State private var passedPhraseIndices: Set<Int>
    @State private var statsSnapshot: GlobalStatsSnapshot
    @State private var roundStartedAt: Date
    @State private var roundHintsUsed: Int
    @State private var freeHintCredits: Int
    @State private var isShowingSettings = false
    @State private var isShowingResetConfirmation = false
    @State private var isShowingContinueOffer = false
    @State private var hasUsedContinueOffer = false
    @State private var isProcessingContinueOffer = false
    @State private var isProcessingHintAd = false
    @State private var isShowingDailyHintToast = false
    @State private var tutorialStep: FirstGameTutorialStep?
    @State private var tutorialPrimaryTileIndex: Int?
    @State private var tutorialHintTileIndex: Int?
    @State private var isShowingTutorialCompletionToast = false
    @State private var tutorialPulse = false

    init() {
        let selectedLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: ProgressStorageKey.selectedLanguage) ?? "") ?? .system
        let effectiveLanguage = AppLanguage.resolved(from: selectedLanguage)
        let loadedEntries = PhraseStore.load(language: effectiveLanguage)
        let snapshot = ProgressStore.load(for: effectiveLanguage, entries: loadedEntries)
        let hasCompletedTutorial = UserDefaults.standard.bool(forKey: ProgressStorageKey.hasCompletedFirstGameTutorial)
        let shouldBoostTutorialStartLevel = Self.shouldBoostTutorialStartLevel(
            hasCompletedTutorial: hasCompletedTutorial,
            currentPhraseIndex: snapshot.currentPhraseIndex,
            completedIndices: snapshot.completedIndices,
            passedIndices: snapshot.passedIndices,
            stats: snapshot.stats
        )
        let initialTiles = Self.makeRoundTiles(
            from: loadedEntries[snapshot.currentPhraseIndex].phrase,
            alphabet: effectiveLanguage.alphabet,
            currentPhraseIndex: snapshot.currentPhraseIndex,
            shouldBoostTutorialStartLevel: shouldBoostTutorialStartLevel
        )

        _currentLanguage = State(initialValue: effectiveLanguage)
        _phraseEntries = State(initialValue: loadedEntries)
        _phraseDatasetSignature = State(initialValue: snapshot.datasetSignature)
        _currentPhraseIndex = State(initialValue: snapshot.currentPhraseIndex)
        _tiles = State(initialValue: initialTiles)
        _selectedTileIndex = State(initialValue: nil)
        _mistakes = State(initialValue: 0)
        _flashingWrongGuesses = State(initialValue: [])
        _roundStatus = State(initialValue: .playing)
        _isHintMode = State(initialValue: false)
        _completedPhraseIndices = State(initialValue: snapshot.completedIndices)
        _passedPhraseIndices = State(initialValue: snapshot.passedIndices)
        _statsSnapshot = State(initialValue: snapshot.stats)
        _roundStartedAt = State(initialValue: Date())
        _roundHintsUsed = State(initialValue: 0)
        _freeHintCredits = State(initialValue: ProgressStore.refreshFreeHintCredits().credits)
        _isShowingContinueOffer = State(initialValue: false)
        _hasUsedContinueOffer = State(initialValue: false)
        _isProcessingContinueOffer = State(initialValue: false)
        _isProcessingHintAd = State(initialValue: false)
        _isShowingDailyHintToast = State(initialValue: false)
        _tutorialStep = State(initialValue: nil)
        _tutorialPrimaryTileIndex = State(initialValue: nil)
        _tutorialHintTileIndex = State(initialValue: nil)
        _isShowingTutorialCompletionToast = State(initialValue: false)
        _tutorialPulse = State(initialValue: false)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                topHud
                    .padding(.horizontal, 10)
                    .padding(.top, 2)

                if isFirstGameTutorialActive {
                    tutorialCallout
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if roundStatus == .lost {
                    roundStatusBanner
                        .padding(.horizontal, 10)
                }

                ScrollView {
                    boardCard(maxWidth: max(geometry.size.width - 20, 220))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: geometry.size.width, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemGroupedBackground),
                        Color(uiColor: .secondarySystemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                keyboardDock
            }
            .onAppear {
                refreshFreeHintCredits()
                persistProgress()
                configureTutorialIfNeeded()
                startTutorialPulseIfNeeded()
            }
            .overlay {
                ZStack {
                    if isShowingSettings {
                        SettingsOverlayView(
                            language: currentLanguage,
                            selectedLanguage: selectedLanguageOption,
                            theme: selectedTheme,
                            stats: globalStatsSnapshot,
                            purchaseManager: purchaseManager,
                            onSelectLanguage: selectLanguage,
                            onSelectTheme: { storedTheme = $0.rawValue },
                            onPurchase: { await purchaseManager.purchaseRemoveAds() },
                            onRestore: { await purchaseManager.restorePurchases() },
                            onReset: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isShowingResetConfirmation = true
                                }
                            },
                            onClose: closeSettings
                        )
                    } else if isShowingContinueOffer {
                        continueOfferOverlay
                    } else if roundStatus == .won {
                        solvedPhraseOverlay
                    }

                    if isShowingResetConfirmation {
                        resetConfirmationOverlay
                    }
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 10) {
                    if isShowingDailyHintToast {
                        dailyHintToast
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if isShowingTutorialCompletionToast {
                        tutorialCompletionToast
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.top, 12)
            }
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .onChange(of: storedLanguage) { _, _ in
            applySelectedLanguage()
        }
    }

    private var topHud: some View {
        HStack(spacing: 8) {
            statBadge(title: currentLanguage.text(.completedTitle), value: completedPhrasesProgress, color: .blue)
            statBadge(title: currentLanguage.text(.openedTitle), value: openedLettersProgress, color: .green)
            statBadge(
                title: currentLanguage.text(.mistakesTitle),
                value: "\(mistakes)/\(Self.maxMistakes)",
                color: mistakes == 0 ? .blue : .orange
            )

            Spacer(minLength: 0)

            settingsButton
        }
    }

    private var dailyHintToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
            Text(currentLanguage.text(.dailyHintRewardToast))
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 14, y: 6)
    }

    private var tutorialCompletionToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(currentLanguage.text(.tutorialCompleted))
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 14, y: 6)
        .padding(.horizontal, 12)
    }

    private var tutorialCallout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(currentLanguage.text(.tutorialTitle), systemImage: "hand.tap.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.orange)

            Text(tutorialMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 360, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.orange.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
        .padding(.horizontal, 12)
        .allowsHitTesting(false)
    }

    private var settingsButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingSettings = true
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isFirstGameTutorialActive)
        .opacity(isFirstGameTutorialActive ? 0.45 : 1)
        .accessibilityLabel(currentLanguage.text(.settingsAccessibilityLabel))
    }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: storedTheme) ?? .system
    }

    private static func shouldBoostTutorialStartLevel(
        hasCompletedTutorial: Bool,
        currentPhraseIndex: Int,
        completedIndices: Set<Int>,
        passedIndices: Set<Int>,
        stats: GlobalStatsSnapshot
    ) -> Bool {
        !hasCompletedTutorial
            && currentPhraseIndex == 0
            && completedIndices.isEmpty
            && passedIndices.isEmpty
            && stats.totalRounds == 0
    }

    private static func makeRoundTiles(
        from phrase: String,
        alphabet: [Character],
        currentPhraseIndex: Int,
        shouldBoostTutorialStartLevel: Bool
    ) -> [PhraseTile] {
        let baseTiles = RoundBuilder.makeTiles(from: phrase, alphabet: alphabet)
        let revealFraction = max(
            currentPhraseIndex < easyStartLevelCount ? easyStartRevealFraction : 0,
            shouldBoostTutorialStartLevel ? tutorialRevealFraction : 0
        )

        guard revealFraction > 0 else {
            return baseTiles
        }

        return boostOpenLetters(in: baseTiles, targetRevealFraction: revealFraction)
    }

    private static func boostOpenLetters(in tiles: [PhraseTile], targetRevealFraction: Double) -> [PhraseTile] {
        var boostedTiles = tiles
        let letterIndices = boostedTiles.indices.filter { boostedTiles[$0].isLetter }

        guard letterIndices.count > 3 else {
            return boostedTiles
        }

        let groupedIndices = Dictionary(grouping: letterIndices) { boostedTiles[$0].normalizedLetter! }
        let preservedHiddenIndices = Set(
            groupedIndices.values
                .filter { $0.count >= 2 }
                .sorted { lhs, rhs in
                    if lhs.count != rhs.count {
                        return lhs.count > rhs.count
                    }

                    return (lhs.first ?? 0) < (rhs.first ?? 0)
                }
                .first?
                .prefix(2)
                ?? letterIndices.prefix(2)
        )

        for index in preservedHiddenIndices {
            boostedTiles[index].isOpen = false
        }

        let currentlyOpenCount = letterIndices.filter { boostedTiles[$0].isOpen }.count
        let desiredOpenCount = min(
            letterIndices.count - 2,
            max(currentlyOpenCount, Int((Double(letterIndices.count) * targetRevealFraction).rounded(.up)))
        )

        guard currentlyOpenCount < desiredOpenCount else {
            return boostedTiles
        }

        var openCount = currentlyOpenCount

        for index in letterIndices where !preservedHiddenIndices.contains(index) && !boostedTiles[index].isOpen {
            boostedTiles[index].isOpen = true
            openCount += 1

            if openCount >= desiredOpenCount {
                break
            }
        }

        return boostedTiles
    }

    private var selectedLanguageOption: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .system
    }

    private var globalStatsSnapshot: GlobalStatsSnapshot {
        statsSnapshot
    }

    private func closeSettings() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingResetConfirmation = false
            isShowingSettings = false
        }
    }

    private func selectLanguage(_ language: AppLanguage) {
        storedLanguage = language.rawValue
    }

    private func applySelectedLanguage(animated: Bool = true) {
        let resolvedLanguage = AppLanguage.resolved(from: selectedLanguageOption)

        guard resolvedLanguage != currentLanguage else {
            return
        }

        let loadedEntries = PhraseStore.load(language: resolvedLanguage)
        let snapshot = ProgressStore.load(for: resolvedLanguage, entries: loadedEntries)
        let nextTiles = Self.makeRoundTiles(
            from: loadedEntries[snapshot.currentPhraseIndex].phrase,
            alphabet: resolvedLanguage.alphabet,
            currentPhraseIndex: snapshot.currentPhraseIndex,
            shouldBoostTutorialStartLevel: Self.shouldBoostTutorialStartLevel(
                hasCompletedTutorial: hasCompletedFirstGameTutorial,
                currentPhraseIndex: snapshot.currentPhraseIndex,
                completedIndices: snapshot.completedIndices,
                passedIndices: snapshot.passedIndices,
                stats: snapshot.stats
            )
        )

        let updates = {
            currentLanguage = resolvedLanguage
            phraseEntries = loadedEntries
            phraseDatasetSignature = snapshot.datasetSignature
            currentPhraseIndex = snapshot.currentPhraseIndex
            tiles = nextTiles
            selectedTileIndex = nil
            mistakes = 0
            flashingWrongGuesses = []
            roundStatus = .playing
            isHintMode = false
            isShowingContinueOffer = false
            hasUsedContinueOffer = false
            isProcessingContinueOffer = false
            isProcessingHintAd = false
            completedPhraseIndices = snapshot.completedIndices
            passedPhraseIndices = snapshot.passedIndices
            statsSnapshot = snapshot.stats
            roundStartedAt = Date()
            roundHintsUsed = 0
            freeHintCredits = ProgressStore.refreshFreeHintCredits().credits
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                updates()
            }
        } else {
            updates()
        }

        configureTutorialIfNeeded(restart: true)
    }

    private var currentAuthor: String {
        guard phraseEntries.indices.contains(currentPhraseIndex) else {
            return ""
        }
        return phraseEntries[currentPhraseIndex].author
    }

    private var currentPhraseText: String {
        guard phraseEntries.indices.contains(currentPhraseIndex) else {
            return ""
        }

        return phraseEntries[currentPhraseIndex].phrase
    }

    private var roundStatusBanner: some View {
        HStack(spacing: 10) {
            Text(currentLanguage.text(.roundLost))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.red)

            Spacer(minLength: 0)

            Button(action: loadNextRound) {
                Text(currentLanguage.text(.nextButton))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var solvedPhraseOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(currentLanguage.text(.roundSolved))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.green)

                Text("“\(currentPhraseText)”")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if !currentAuthor.isEmpty {
                    Text(currentAuthor)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: loadNextRound) {
                    Text(currentLanguage.text(.nextButton))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 22, y: 10)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var continueOfferOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(currentLanguage.text(.continueOfferTitle))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.orange)

                Text(currentLanguage.text(.continueOfferMessage))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Button {
                    handleContinueOfferAccept()
                } label: {
                    Text(
                        purchaseManager.isAdsRemoved
                            ? currentLanguage.text(.continueOfferContinue)
                            : (isProcessingContinueOffer ? currentLanguage.text(.purchaseLoadingShort) : currentLanguage.text(.continueOfferWatchAd))
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isProcessingContinueOffer)

                Button {
                    finishRoundAsLoss()
                } label: {
                    Text(currentLanguage.text(.continueOfferDecline))
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(isProcessingContinueOffer)
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 22, y: 10)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var resetConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingResetConfirmation = false
                    }
                }

            VStack(spacing: 16) {
                Text(currentLanguage.text(.resetDialogTitle))
                    .font(.headline.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(currentLanguage.text(.resetDialogMessage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(role: .destructive) {
                    resetProgressAndSettings()
                } label: {
                    Text(currentLanguage.text(.resetDialogButton))
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingResetConfirmation = false
                    }
                } label: {
                    Text(currentLanguage.text(.cancelButton))
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 22, y: 10)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(20)
    }

    private func boardCard(maxWidth: CGFloat) -> some View {
        let contentWidth = max(maxWidth - 20, 120)
        let metrics = boardMetrics(for: contentWidth)
        let rows = makeRows(maxWidth: contentWidth, metrics: metrics)

        return VStack(alignment: .center, spacing: 0) {
            VStack(alignment: .center, spacing: metrics.rowSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: metrics.wordSpacing) {
                        ForEach(row) { chunk in
                            chunkView(chunk, metrics: metrics)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(14)
        .frame(width: maxWidth, alignment: .center)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var keyboardDock: some View {
        VStack(spacing: 6) {
            HStack {
                hintButton
                Spacer(minLength: 0)
            }

            ForEach(currentLanguage.keyboardRows) { row in
                keyboardRow(row)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }

    private var hintButton: some View {
        let isTutorialHighlighted = tutorialStep == .openHintMode

        return Button {
            toggleHintMode()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isHintMode ? "lightbulb.fill" : (needsAdForHint ? "play.rectangle.fill" : "lightbulb"))
                Text(isProcessingHintAd ? currentLanguage.text(.purchaseLoadingShort) : currentLanguage.text(.hintButton))
                    .font(.caption2.weight(.semibold))

                if !isProcessingHintAd {
                    if freeHintCredits > 0 {
                        Text("\(freeHintCredits)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.18), in: Capsule())
                    } else if needsAdForHint {
                        Image(systemName: "play.tv.fill")
                            .font(.caption2)
                    }
                }
            }
            .foregroundStyle(isHintMode ? Color.black : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        isHintMode
                            ? Color.yellow
                            : (needsAdForHint ? Color.orange.opacity(0.14) : Color.primary.opacity(0.08))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        needsAdForHint && !isHintMode
                            ? Color.orange.opacity(0.35)
                            : Color.primary.opacity(isHintMode ? 0 : 0.08),
                        lineWidth: 1
                    )
            )
            .overlay {
                if isTutorialHighlighted {
                    Capsule()
                        .stroke(Color.yellow, lineWidth: 2)
                        .shadow(color: Color.yellow.opacity(tutorialPulse ? 0.65 : 0.35), radius: tutorialPulse ? 16 : 8)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isTutorialHighlighted {
                    tutorialPointer
                        .offset(x: tutorialPulse ? 12 : 8, y: tutorialPulse ? 18 : 14)
                }
            }
            .scaleEffect(isTutorialHighlighted ? (tutorialPulse ? 1.04 : 1.0) : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isHintMode)
        .animation(.easeInOut(duration: 0.15), value: freeHintCredits)
        .animation(.easeInOut(duration: 0.9), value: tutorialPulse)
        .disabled(!canUseHintButton || isProcessingHintAd)
        .opacity(canUseHintButton || isHintMode ? 1 : 0.45)
    }

    private func keyboardRow(_ row: KeyboardRow) -> some View {
        HStack(spacing: 5) {
            ForEach(row.letters, id: \.self) { letter in
                keyboardKey(letter)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedTile: PhraseTile? {
        guard let selectedTileIndex, tiles.indices.contains(selectedTileIndex) else {
            return nil
        }

        return tiles[selectedTileIndex]
    }

    private var selectedCode: Int? {
        selectedTile?.code
    }

    private var isFirstGameTutorialActive: Bool {
        tutorialStep != nil && !hasCompletedFirstGameTutorial
    }

    private var tutorialPointer: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.orange)
            .padding(6)
            .background(Color(uiColor: .systemBackground), in: Circle())
            .overlay(
                Circle()
                    .stroke(Color.orange.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            .allowsHitTesting(false)
    }

    private var tutorialMessage: String {
        switch tutorialStep {
        case .pickTile:
            return currentLanguage.text(.tutorialPickTile)
        case .enterLetter:
            return currentLanguage.text(.tutorialEnterLetter)
        case .openHintMode:
            return currentLanguage.text(.tutorialHintButton)
        case .useHint:
            return currentLanguage.text(.tutorialHintTile)
        case .none:
            return ""
        }
    }

    private var tutorialHintIsFree: Bool {
        isFirstGameTutorialActive && (tutorialStep == .openHintMode || tutorialStep == .useHint)
    }

    private var tutorialTargetLetter: Character? {
        guard let tutorialPrimaryTileIndex, tiles.indices.contains(tutorialPrimaryTileIndex) else {
            return nil
        }

        return tiles[tutorialPrimaryTileIndex].normalizedLetter
    }

    private var canUseHintButton: Bool {
        if !isFirstGameTutorialActive {
            return isHintAvailable
        }

        return tutorialStep == .openHintMode
    }

    private var isHintAvailable: Bool {
        roundStatus == .playing && tiles.contains { $0.isHiddenLetter }
    }

    private var needsAdForHint: Bool {
        !tutorialHintIsFree && freeHintCredits == 0 && !purchaseManager.isAdsRemoved
    }

    private var completedPhrasesProgress: String {
        "\(completedPhraseIndices.count)/\(phraseEntries.count)"
    }

    private var openedLettersProgress: String {
        let totalLetters = tiles.filter(\.isLetter).count
        let openedLetters = tiles.filter { $0.isLetter && $0.isOpen }.count
        return "\(openedLetters)/\(totalLetters)"
    }

    private func statBadge(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }

    private func chunkView(_ chunk: PhraseChunk, metrics: BoardMetrics) -> some View {
        HStack(alignment: .top, spacing: metrics.tileSpacing) {
            ForEach(chunk.tiles) { tile in
                tileView(tile, metrics: metrics)
            }
        }
    }

    @ViewBuilder
    private func tileView(_ tile: PhraseTile, metrics: BoardMetrics) -> some View {
        if tile.isSpace {
            Color.clear
                .frame(width: metrics.spaceWidth, height: metrics.tileHeight)
        } else if !tile.isLetter {
            VStack(spacing: metrics.tileCodeSpacing) {
                Text(String(tile.displayCharacter))
                    .font(.system(size: metrics.letterFontSize, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(width: metrics.tileWidth, height: metrics.tileCellHeight)

                Color.clear
                    .frame(height: metrics.tileCodeHeight)
            }
            .frame(width: metrics.tileWidth, height: metrics.tileHeight, alignment: .top)
        } else {
            let isSelected = selectedTileIndex == tile.index
            let showCode = shouldShowCode(for: tile)
            let isTutorialHighlighted = isTutorialHighlightedTile(tile)

            VStack(spacing: metrics.tileCodeSpacing) {
                Button {
                    handleTileTap(tile)
                } label: {
                    Text(tile.isOpen ? String(tile.boardCharacter) : " ")
                        .font(.system(size: metrics.letterFontSize, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .frame(width: metrics.tileWidth, height: metrics.tileCellHeight)
                        .background(tileBackgroundColor(for: tile, isSelected: isSelected), in: RoundedRectangle(cornerRadius: metrics.tileCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: metrics.tileCornerRadius, style: .continuous)
                                .stroke(tileBorderColor(for: tile, isSelected: isSelected), lineWidth: isSelected ? 1.5 : 1)
                        )
                        .overlay {
                            if isTutorialHighlighted {
                                RoundedRectangle(cornerRadius: metrics.tileCornerRadius, style: .continuous)
                                    .stroke(Color.yellow, lineWidth: 2)
                                    .shadow(color: Color.yellow.opacity(tutorialPulse ? 0.65 : 0.35), radius: tutorialPulse ? 16 : 8)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if isTutorialHighlighted {
                                tutorialPointer
                                    .offset(x: tutorialPulse ? 12 : 8, y: tutorialPulse ? 16 : 12)
                            }
                        }
                        .scaleEffect(isTutorialHighlighted ? (tutorialPulse ? 1.08 : 1.02) : 1)
                }
                .buttonStyle(.plain)
                .disabled(!canSelect(tile))
                .animation(.easeInOut(duration: 0.9), value: tutorialPulse)

                if showCode, let code = tile.code {
                    Text("\(code)")
                        .font(.system(size: metrics.codeFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(height: metrics.tileCodeHeight)
                } else {
                    Color.clear
                        .frame(height: metrics.tileCodeHeight)
                }
            }
            .frame(width: metrics.tileWidth, height: metrics.tileHeight, alignment: .top)
        }
    }

    private func tileBackgroundColor(for tile: PhraseTile, isSelected: Bool) -> Color {
        if tile.isOpen {
            return .green.opacity(0.16)
        }

        if isTutorialHighlightedTile(tile) {
            return Color.yellow.opacity(isHintMode ? 0.28 : 0.18)
        }

        if isHintMode && tile.isHiddenLetter {
            return Color.yellow.opacity(0.24)
        }

        if isSelected {
            return .accentColor.opacity(0.18)
        }

        return Color.secondary.opacity(0.08)
    }

    private func tileBorderColor(for tile: PhraseTile, isSelected: Bool) -> Color {
        if isTutorialHighlightedTile(tile) {
            return Color.yellow
        }

        if isHintMode && tile.isHiddenLetter {
            return Color.yellow.opacity(0.8)
        }

        if isSelected {
            return .accentColor
        }

        if tile.isOpen {
            return .green.opacity(0.45)
        }

        return Color.secondary.opacity(0.25)
    }

    private func canSelect(_ tile: PhraseTile) -> Bool {
        guard roundStatus == .playing && tile.isHiddenLetter else {
            return false
        }

        guard isFirstGameTutorialActive else {
            return true
        }

        switch tutorialStep {
        case .pickTile:
            return tile.index == tutorialPrimaryTileIndex
        case .useHint:
            return isHintMode && tile.index == tutorialHintTileIndex
        case .enterLetter, .openHintMode, .none:
            return false
        }
    }

    private func shouldShowCode(for tile: PhraseTile) -> Bool {
        guard let letter = tile.normalizedLetter, tile.code != nil else {
            return false
        }

        return !isLetterSolved(letter)
    }

    private func handleTileTap(_ tile: PhraseTile) {
        guard canSelect(tile) else {
            return
        }

        if isHintMode {
            revealHint(at: tile.index)
            return
        }

        if tutorialStep == .pickTile {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTileIndex = tile.index
                tutorialStep = .enterLetter
            }
            return
        }

        selectedTileIndex = tile.index
    }

    private func keyboardKey(_ letter: Character) -> some View {
        let isVisible = keyboardVisibility(for: letter)
        let isWrong = isFlashingWrong(letter)
        let isTutorialHighlighted = isTutorialHighlightedKey(letter)

        return Button {
            handleLetterTap(letter)
        } label: {
            Text(String(letter))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)
                .foregroundStyle(isWrong ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isWrong
                                ? Color.red
                                : (isTutorialHighlighted ? Color.yellow.opacity(0.22) : Color.accentColor.opacity(isVisible ? 0.12 : 0))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isWrong
                                ? Color.red
                                : (isTutorialHighlighted ? Color.yellow : Color.accentColor.opacity(isVisible ? 0.35 : 0)),
                            lineWidth: isTutorialHighlighted ? 2 : 1
                        )
                )
                .overlay(alignment: .bottomTrailing) {
                    if isTutorialHighlighted {
                        tutorialPointer
                            .offset(x: tutorialPulse ? 12 : 8, y: tutorialPulse ? 14 : 10)
                    }
                }
                .shadow(color: isTutorialHighlighted ? Color.yellow.opacity(tutorialPulse ? 0.55 : 0.25) : .clear, radius: tutorialPulse ? 14 : 8)
                .scaleEffect(isTutorialHighlighted ? (tutorialPulse ? 1.06 : 1.0) : 1)
        }
        .buttonStyle(.plain)
        .disabled(!canTapKey(letter))
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible && canTapKey(letter))
        .animation(.easeInOut(duration: 0.9), value: tutorialPulse)
    }

    private func keyboardVisibility(for letter: Character) -> Bool {
        if isLetterSolved(letter) {
            return false
        }

        if isFirstGameTutorialActive {
            return isLetterStillNeeded(letter)
        }

        return true
    }

    private func isTutorialHighlightedTile(_ tile: PhraseTile) -> Bool {
        guard isFirstGameTutorialActive else {
            return false
        }

        switch tutorialStep {
        case .pickTile, .enterLetter:
            return tile.index == tutorialPrimaryTileIndex
        case .useHint:
            return tile.index == tutorialHintTileIndex
        case .openHintMode, .none:
            return false
        }
    }

    private func isTutorialHighlightedKey(_ letter: Character) -> Bool {
        isFirstGameTutorialActive && tutorialStep == .enterLetter && tutorialTargetLetter == letter
    }

    private func isFlashingWrong(_ letter: Character) -> Bool {
        guard let selectedCode else {
            return false
        }

        return flashingWrongGuesses.contains(WrongGuess(code: selectedCode, letter: letter))
    }

    private func isLetterStillNeeded(_ letter: Character) -> Bool {
        tiles.contains { $0.normalizedLetter == letter && $0.isHiddenLetter }
    }

    private func canTapKey(_ letter: Character) -> Bool {
        guard roundStatus == .playing,
              !isHintMode,
              selectedCode != nil,
              keyboardVisibility(for: letter) else {
            return false
        }

        guard isFirstGameTutorialActive else {
            return true
        }

        return tutorialStep == .enterLetter && tutorialTargetLetter == letter
    }

    private func handleLetterTap(_ letter: Character) {
        guard roundStatus == .playing,
              let selectedTileIndex,
              tiles.indices.contains(selectedTileIndex),
              let selectedCode = tiles[selectedTileIndex].code,
              canTapKey(letter) else {
            return
        }

        if tiles[selectedTileIndex].normalizedLetter == letter {
            let isTutorialEntry = tutorialStep == .enterLetter
            let nextTileIndex = isTutorialEntry ? nil : nextHiddenTileIndex(after: selectedTileIndex)

            withAnimation(.easeInOut(duration: 0.2)) {
                tiles[selectedTileIndex].isOpen = true
                self.selectedTileIndex = nextTileIndex
            }

            if isTutorialEntry {
                advanceTutorialAfterCorrectLetter()
            }

            if allLettersOpen {
                roundStatus = .won
                completeCurrentPhrase(didPass: true)
            }

            return
        }

        let wrongGuess = WrongGuess(code: selectedCode, letter: letter)

        withAnimation(.easeInOut(duration: 0.2)) {
            _ = flashingWrongGuesses.insert(wrongGuess)
        }

        mistakes += 1

        if mistakes >= Self.maxMistakes {
            if canOfferContinueAfterMistake {
                isShowingContinueOffer = true
            } else {
                finishRoundAsLoss()
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)

            withAnimation(.easeInOut(duration: 0.2)) {
                _ = flashingWrongGuesses.remove(wrongGuess)
            }
        }
    }

    private func nextHiddenTileIndex(after currentIndex: Int) -> Int? {
        guard !tiles.isEmpty else {
            return nil
        }

        let trailingIndices = tiles.indices.dropFirst(currentIndex + 1)
        if let nextIndex = trailingIndices.first(where: { tiles[$0].isHiddenLetter }) {
            return nextIndex
        }

        return tiles.indices.prefix(currentIndex).first(where: { tiles[$0].isHiddenLetter })
    }

    private var allLettersOpen: Bool {
        tiles.allSatisfy { !$0.isLetter || $0.isOpen }
    }

    private func isLetterSolved(_ letter: Character) -> Bool {
        let matchingTiles = tiles.filter { $0.normalizedLetter == letter }
        guard !matchingTiles.isEmpty else {
            return false
        }

        return matchingTiles.allSatisfy(\.isOpen)
    }

    private func revealAllLetters() {
        withAnimation(.easeInOut(duration: 0.25)) {
            for index in tiles.indices where tiles[index].isLetter {
                tiles[index].isOpen = true
            }
        }
    }

    private var canOfferContinueAfterMistake: Bool {
        roundStatus == .playing && !hasUsedContinueOffer && !isShowingContinueOffer
    }

    private func handleContinueOfferAccept() {
        guard !isProcessingContinueOffer else {
            return
        }

        isProcessingContinueOffer = true

        Task { @MainActor in
            if !purchaseManager.isAdsRemoved {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                mistakes = max(0, Self.maxMistakes - 1)
                hasUsedContinueOffer = true
                isShowingContinueOffer = false
                isProcessingContinueOffer = false
            }
        }
    }

    private func finishRoundAsLoss() {
        revealAllLetters()
        roundStatus = .lost
        selectedTileIndex = nil
        isShowingContinueOffer = false
        isProcessingContinueOffer = false
        clearTutorialState()
        completeCurrentPhrase(didPass: false)
    }

    private func toggleHintMode() {
        if isFirstGameTutorialActive {
            guard tutorialStep == .openHintMode, isHintAvailable else {
                return
            }

            let nextHintTileIndex = preferredTutorialHintTileIndex()

            withAnimation(.easeInOut(duration: 0.2)) {
                isHintMode = nextHintTileIndex != nil
                selectedTileIndex = nil
                tutorialHintTileIndex = nextHintTileIndex
                tutorialStep = nextHintTileIndex == nil ? nil : .useHint
            }

            if nextHintTileIndex == nil {
                completeFirstGameTutorial()
            }
            return
        }

        guard isHintAvailable else {
            return
        }

        if isHintMode {
            isHintMode = false
            selectedTileIndex = nil
            return
        }

        if needsAdForHint {
            requestAdHint()
            return
        }

        isHintMode = true
        selectedTileIndex = nil
    }

    private func revealHint(at index: Int) {
        guard roundStatus == .playing,
              isHintMode,
              tiles.indices.contains(index),
              tiles[index].isHiddenLetter else {
            return
        }

        let isTutorialHint = tutorialStep == .useHint

        if isTutorialHint && index != tutorialHintTileIndex {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            tiles[index].isOpen = true
            selectedTileIndex = nil
            isHintMode = false

            if !isTutorialHint {
                roundHintsUsed += 1
            }
        }

        if !isTutorialHint && freeHintCredits > 0 {
            freeHintCredits = ProgressStore.consumeFreeHint()
        }

        if isTutorialHint {
            completeFirstGameTutorial()
        }

        if allLettersOpen {
            roundStatus = .won
            completeCurrentPhrase(didPass: true)
        }
    }

    private func requestAdHint() {
        guard !isProcessingHintAd else {
            return
        }

        isProcessingHintAd = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            withAnimation(.easeInOut(duration: 0.2)) {
                isProcessingHintAd = false
                isHintMode = true
                selectedTileIndex = nil
            }
        }
    }

    private func refreshFreeHintCredits() {
        let refreshResult = ProgressStore.refreshFreeHintCredits()
        freeHintCredits = refreshResult.credits

        guard refreshResult.didGrantDailyReward else {
            return
        }

        showDailyHintToast()
    }

    private func showDailyHintToast() {
        guard !isShowingDailyHintToast else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingDailyHintToast = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)

            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingDailyHintToast = false
            }
        }
    }

    private func startTutorialPulseIfNeeded() {
        guard !tutorialPulse else {
            return
        }

        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            tutorialPulse = true
        }
    }

    private func configureTutorialIfNeeded(restart: Bool = false) {
        if restart {
            clearTutorialState()
        }

        guard Self.shouldBoostTutorialStartLevel(
                hasCompletedTutorial: hasCompletedFirstGameTutorial,
                currentPhraseIndex: currentPhraseIndex,
                completedIndices: completedPhraseIndices,
                passedIndices: passedPhraseIndices,
                stats: statsSnapshot
              ),
              tutorialStep == nil,
              roundStatus == .playing,
              !phraseEntries.isEmpty,
              let targetTileIndex = preferredTutorialPrimaryTileIndex() else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            tutorialPrimaryTileIndex = targetTileIndex
            tutorialHintTileIndex = nil
            selectedTileIndex = nil
            isHintMode = false
            tutorialStep = .pickTile
        }
    }

    private func clearTutorialState() {
        tutorialStep = nil
        tutorialPrimaryTileIndex = nil
        tutorialHintTileIndex = nil
    }

    private func preferredTutorialPrimaryTileIndex() -> Int? {
        let hiddenLetterIndices = tiles.indices.filter { tiles[$0].isHiddenLetter }
        guard !hiddenLetterIndices.isEmpty else {
            return nil
        }

        return hiddenLetterIndices.first(where: { index in
            guard let code = tiles[index].code else {
                return false
            }

            return hiddenLetterIndices.contains { otherIndex in
                otherIndex != index && tiles[otherIndex].code == code
            }
        }) ?? hiddenLetterIndices.first
    }

    private func preferredTutorialHintTileIndex() -> Int? {
        let hiddenLetterIndices = tiles.indices.filter { tiles[$0].isHiddenLetter }
        guard !hiddenLetterIndices.isEmpty else {
            return nil
        }

        if let tutorialPrimaryTileIndex {
            return hiddenLetterIndices.first(where: { $0 != tutorialPrimaryTileIndex }) ?? hiddenLetterIndices.first
        }

        return hiddenLetterIndices.first
    }

    private func advanceTutorialAfterCorrectLetter() {
        guard tutorialStep == .enterLetter else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTileIndex = nil
            tutorialStep = .openHintMode
        }
    }

    private func completeFirstGameTutorial() {
        guard !hasCompletedFirstGameTutorial else {
            clearTutorialState()
            return
        }

        hasCompletedFirstGameTutorial = true
        clearTutorialState()
        showTutorialCompletionToast()
    }

    private func showTutorialCompletionToast() {
        guard !isShowingTutorialCompletionToast else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingTutorialCompletionToast = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)

            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingTutorialCompletionToast = false
            }
        }
    }

    private func loadNextRound() {
        let nextIndex = nextPhraseIndex(after: currentPhraseIndex)
        let nextTiles = Self.makeRoundTiles(
            from: phraseEntries[nextIndex].phrase,
            alphabet: currentLanguage.alphabet,
            currentPhraseIndex: nextIndex,
            shouldBoostTutorialStartLevel: Self.shouldBoostTutorialStartLevel(
                hasCompletedTutorial: hasCompletedFirstGameTutorial,
                currentPhraseIndex: nextIndex,
                completedIndices: completedPhraseIndices,
                passedIndices: passedPhraseIndices,
                stats: statsSnapshot
            )
        )

        withAnimation(.easeInOut(duration: 0.25)) {
            currentPhraseIndex = nextIndex
            tiles = nextTiles
            selectedTileIndex = nil
            mistakes = 0
            flashingWrongGuesses = []
            roundStatus = .playing
            isHintMode = false
            isShowingContinueOffer = false
            hasUsedContinueOffer = false
            isProcessingContinueOffer = false
            isProcessingHintAd = false
            roundStartedAt = Date()
            roundHintsUsed = 0
        }

        refreshFreeHintCredits()
        persistProgress()
        configureTutorialIfNeeded(restart: true)
    }

    private func completeCurrentPhrase(didPass: Bool) {
        guard phraseEntries.indices.contains(currentPhraseIndex) else {
            return
        }

        completedPhraseIndices.insert(currentPhraseIndex)

        if didPass {
            passedPhraseIndices.insert(currentPhraseIndex)
        }

        storeRoundStatistics(didPass: didPass)
        persistProgress()
    }

    private func nextPhraseIndex(after index: Int) -> Int {
        let allIndices = Array(phraseEntries.indices)
        guard !allIndices.isEmpty else {
            return 0
        }

        let candidateIndices: [Int]

        if completedPhraseIndices.count < phraseEntries.count {
            candidateIndices = allIndices.filter { !completedPhraseIndices.contains($0) }
        } else {
            let retryIndices = allIndices.filter { !passedPhraseIndices.contains($0) }
            candidateIndices = retryIndices.isEmpty ? allIndices : retryIndices
        }

        let sortedCandidates = candidateIndices.sorted()

        if let nextIndex = sortedCandidates.first(where: { $0 > index }) {
            return nextIndex
        }

        return sortedCandidates.first ?? 0
    }

    private func persistProgress() {
        ProgressStore.persist(
            language: currentLanguage,
            currentPhraseIndex: phraseEntries.indices.contains(currentPhraseIndex) ? currentPhraseIndex : 0,
            completedIndices: completedPhraseIndices,
            passedIndices: passedPhraseIndices,
            datasetSignature: phraseDatasetSignature,
            stats: statsSnapshot
        )
    }

    private func storeRoundStatistics(didPass: Bool) {
        let duration = max(0, Date().timeIntervalSince(roundStartedAt))
        var updatedStats = statsSnapshot

        updatedStats = GlobalStatsSnapshot(
            totalRounds: updatedStats.totalRounds + 1,
            totalPassedRounds: updatedStats.totalPassedRounds + (didPass ? 1 : 0),
            totalMistakes: updatedStats.totalMistakes + mistakes,
            totalDuration: updatedStats.totalDuration + duration,
            totalHints: updatedStats.totalHints + roundHintsUsed,
            bestPassedDuration: bestPassedDuration(from: updatedStats, currentDuration: duration, didPass: didPass)
        )

        statsSnapshot = updatedStats
    }

    private func resetProgressAndSettings() {
        guard !phraseEntries.isEmpty else {
            return
        }

        let firstIndex = 0
        hasCompletedFirstGameTutorial = false
        let firstTiles = Self.makeRoundTiles(
            from: phraseEntries[firstIndex].phrase,
            alphabet: currentLanguage.alphabet,
            currentPhraseIndex: firstIndex,
            shouldBoostTutorialStartLevel: Self.shouldBoostTutorialStartLevel(
                hasCompletedTutorial: false,
                currentPhraseIndex: firstIndex,
                completedIndices: [],
                passedIndices: [],
                stats: .zero
            )
        )

        storedTheme = AppTheme.system.rawValue
        ProgressStore.reset(for: currentLanguage)

        withAnimation(.easeInOut(duration: 0.25)) {
            currentPhraseIndex = firstIndex
            tiles = firstTiles
            selectedTileIndex = nil
            mistakes = 0
            flashingWrongGuesses = []
            roundStatus = .playing
            isHintMode = false
            isShowingContinueOffer = false
            hasUsedContinueOffer = false
            isProcessingContinueOffer = false
            isProcessingHintAd = false
            completedPhraseIndices = []
            passedPhraseIndices = []
            statsSnapshot = .zero
            roundStartedAt = Date()
            roundHintsUsed = 0
        }

        refreshFreeHintCredits()
        persistProgress()
        configureTutorialIfNeeded(restart: true)
        isShowingResetConfirmation = false
        isShowingSettings = false
    }

    private func bestPassedDuration(from stats: GlobalStatsSnapshot, currentDuration: TimeInterval, didPass: Bool) -> TimeInterval {
        guard didPass else {
            return stats.bestPassedDuration
        }

        if stats.bestPassedDuration == 0 || currentDuration < stats.bestPassedDuration {
            return currentDuration
        }

        return stats.bestPassedDuration
    }

    private func makeRows(maxWidth: CGFloat, metrics: BoardMetrics) -> [[PhraseChunk]] {
        let chunks = makeChunks()
        var rows: [[PhraseChunk]] = []
        var currentRow: [PhraseChunk] = []
        var currentWidth: CGFloat = 0

        for chunk in chunks {
            let width = chunkWidth(for: chunk, metrics: metrics)
            let spacingBeforeChunk = currentRow.last.map { spacing(after: $0, metrics: metrics) } ?? 0
            let nextWidth = currentRow.isEmpty ? width : currentWidth + spacingBeforeChunk + width

            if !currentRow.isEmpty && nextWidth > maxWidth {
                rows.append(currentRow)
                currentRow = [chunk]
                currentWidth = width
            } else {
                currentRow.append(chunk)
                currentWidth = nextWidth
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private func makeChunks() -> [PhraseChunk] {
        var chunks: [PhraseChunk] = []
        var currentTiles: [PhraseTile] = []

        for (index, tile) in tiles.enumerated() {
            if tile.isSpace {
                if let firstTile = currentTiles.first {
                    chunks.append(
                        PhraseChunk(
                            id: firstTile.index,
                            tiles: currentTiles,
                            separatorAfter: .space
                        )
                    )
                    currentTiles = []
                }
            } else {
                currentTiles.append(tile)

                let hasJoinedHyphenBreak = tile.displayCharacter == "-"
                    && currentTiles.count > 1
                    && hasNextNonSpaceTile(after: index)

                if hasJoinedHyphenBreak, let firstTile = currentTiles.first {
                    chunks.append(
                        PhraseChunk(
                            id: firstTile.index,
                            tiles: currentTiles,
                            separatorAfter: .hyphen
                        )
                    )
                    currentTiles = []
                }
            }
        }

        if let firstTile = currentTiles.first {
            chunks.append(
                PhraseChunk(
                    id: firstTile.index,
                    tiles: currentTiles,
                    separatorAfter: .none
                )
            )
        }

        return chunks
    }

    private func hasNextNonSpaceTile(after index: Int) -> Bool {
        guard tiles.indices.contains(index + 1) else {
            return false
        }

        return !tiles[index + 1].isSpace
    }

    private func chunkWidth(for chunk: PhraseChunk, metrics: BoardMetrics) -> CGFloat {
        let tileCount = CGFloat(chunk.tiles.count)
        let spacingCount = CGFloat(max(chunk.tiles.count - 1, 0))
        return (tileCount * metrics.tileWidth) + (spacingCount * metrics.tileSpacing)
    }

    private func spacing(after chunk: PhraseChunk, metrics: BoardMetrics) -> CGFloat {
        switch chunk.separatorAfter {
        case .space:
            return metrics.wordSpacing
        case .hyphen:
            return metrics.tileSpacing
        case .none:
            return 0
        }
    }

    private func boardMetrics(for maxWidth: CGFloat) -> BoardMetrics {
        let baseMetrics = BoardMetrics(
            tileWidth: Self.tileWidth,
            tileCellHeight: Self.tileCellHeight,
            tileCodeHeight: Self.tileCodeHeight,
            tileCodeSpacing: Self.tileCodeSpacing,
            tileHeight: Self.tileHeight,
            tileSpacing: Self.tileSpacing,
            rowSpacing: Self.rowSpacing,
            spaceWidth: Self.spaceWidth,
            wordSpacing: Self.wordSpacing,
            letterFontSize: 26,
            codeFontSize: 16,
            tileCornerRadius: 8
        )

        let widestChunk = makeChunks()
            .map { chunkWidth(for: $0, metrics: baseMetrics) }
            .max() ?? 0

        guard widestChunk > maxWidth else {
            return baseMetrics
        }

        let scale = max(0.58, min(1, maxWidth / widestChunk))
        return baseMetrics.scaled(by: scale)
    }
}

#Preview {
    ContentView()
}
