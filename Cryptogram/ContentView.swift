//
//  ContentView.swift
//  Cryptogram
//
//  Created by Dmitriy on 18/03/2026.
//

import Foundation
import SwiftUI

struct ContentView: View {
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
    // Неверные буквы храним по числовому коду, иначе можно случайно заблокировать
    // букву, которая нужна для другой ячейки, и сделать раунд непроходимым.
    @State private var rejectedLettersByCode: [Int: Set<Character>]
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

    init() {
        let selectedLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: ProgressStorageKey.selectedLanguage) ?? "") ?? .system
        let effectiveLanguage = AppLanguage.resolved(from: selectedLanguage)
        let loadedEntries = PhraseStore.load(language: effectiveLanguage)
        let snapshot = ProgressStore.load(for: effectiveLanguage, entries: loadedEntries)
        let initialTiles = RoundBuilder.makeTiles(from: loadedEntries[snapshot.currentPhraseIndex].phrase, alphabet: effectiveLanguage.alphabet)

        _currentLanguage = State(initialValue: effectiveLanguage)
        _phraseEntries = State(initialValue: loadedEntries)
        _phraseDatasetSignature = State(initialValue: snapshot.datasetSignature)
        _currentPhraseIndex = State(initialValue: snapshot.currentPhraseIndex)
        _tiles = State(initialValue: initialTiles)
        _selectedTileIndex = State(initialValue: nil)
        _mistakes = State(initialValue: 0)
        _rejectedLettersByCode = State(initialValue: [:])
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
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                topHud
                    .padding(.horizontal, 10)
                    .padding(.top, 2)

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
            }
            .overlay {
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
                        onReset: { isShowingResetConfirmation = true },
                        onClose: closeSettings
                    )
                } else if isShowingContinueOffer {
                    continueOfferOverlay
                } else if roundStatus == .won {
                    solvedPhraseOverlay
                }
            }
            .overlay(alignment: .top) {
                if isShowingDailyHintToast {
                    dailyHintToast
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .onChange(of: storedLanguage) { _, _ in
            applySelectedLanguage()
        }
        .confirmationDialog(
            currentLanguage.text(.resetDialogTitle),
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(currentLanguage.text(.resetDialogButton), role: .destructive) {
                resetProgressAndSettings()
            }
            Button(currentLanguage.text(.cancelButton), role: .cancel) {}
        } message: {
            Text(currentLanguage.text(.resetDialogMessage))
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
        .accessibilityLabel(currentLanguage.text(.settingsAccessibilityLabel))
    }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: storedTheme) ?? .system
    }

    private var selectedLanguageOption: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .system
    }

    private var globalStatsSnapshot: GlobalStatsSnapshot {
        statsSnapshot
    }

    private func closeSettings() {
        withAnimation(.easeInOut(duration: 0.2)) {
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
        let nextTiles = RoundBuilder.makeTiles(
            from: loadedEntries[snapshot.currentPhraseIndex].phrase,
            alphabet: resolvedLanguage.alphabet
        )

        let updates = {
            currentLanguage = resolvedLanguage
            phraseEntries = loadedEntries
            phraseDatasetSignature = snapshot.datasetSignature
            currentPhraseIndex = snapshot.currentPhraseIndex
            tiles = nextTiles
            selectedTileIndex = nil
            mistakes = 0
            rejectedLettersByCode = [:]
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
        Button {
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
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isHintMode)
        .animation(.easeInOut(duration: 0.15), value: freeHintCredits)
        .disabled(!isHintAvailable || isProcessingHintAd)
        .opacity(isHintAvailable || isHintMode ? 1 : 0.45)
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

    private var isHintAvailable: Bool {
        roundStatus == .playing && tiles.contains { $0.isHiddenLetter }
    }

    private var needsAdForHint: Bool {
        freeHintCredits == 0 && !purchaseManager.isAdsRemoved
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
                }
                .buttonStyle(.plain)
                .disabled(!canSelect(tile))

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

        if isHintMode && tile.isHiddenLetter {
            return Color.yellow.opacity(0.24)
        }

        if isSelected {
            return .accentColor.opacity(0.18)
        }

        return Color.secondary.opacity(0.08)
    }

    private func tileBorderColor(for tile: PhraseTile, isSelected: Bool) -> Color {
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
        roundStatus == .playing && tile.isHiddenLetter
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

        selectedTileIndex = tile.index
    }

    private func keyboardKey(_ letter: Character) -> some View {
        let isVisible = keyboardVisibility(for: letter)
        let isWrong = isFlashingWrong(letter)

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
                        .fill(isWrong ? Color.red : Color.accentColor.opacity(isVisible ? 0.12 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isWrong ? Color.red : Color.accentColor.opacity(isVisible ? 0.35 : 0), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canTapKey(letter))
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible && canTapKey(letter))
    }

    private func keyboardVisibility(for letter: Character) -> Bool {
        if isLetterSolved(letter) {
            return false
        }

        guard let selectedCode else {
            return true
        }

        let wrongGuess = WrongGuess(code: selectedCode, letter: letter)
        if flashingWrongGuesses.contains(wrongGuess) {
            return true
        }

        return !rejectedLettersByCode[selectedCode, default: []].contains(letter)
    }

    private func isFlashingWrong(_ letter: Character) -> Bool {
        guard let selectedCode else {
            return false
        }

        return flashingWrongGuesses.contains(WrongGuess(code: selectedCode, letter: letter))
    }

    private func canTapKey(_ letter: Character) -> Bool {
        roundStatus == .playing && !isHintMode && selectedCode != nil && keyboardVisibility(for: letter)
    }

    private func handleLetterTap(_ letter: Character) {
        guard roundStatus == .playing,
              let selectedTileIndex,
              tiles.indices.contains(selectedTileIndex),
              let selectedCode = tiles[selectedTileIndex].code,
              keyboardVisibility(for: letter) else {
            return
        }

        if tiles[selectedTileIndex].normalizedLetter == letter {
            let nextTileIndex = nextHiddenTileIndex(after: selectedTileIndex)

            withAnimation(.easeInOut(duration: 0.2)) {
                tiles[selectedTileIndex].isOpen = true
                self.selectedTileIndex = nextTileIndex
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
                _ = rejectedLettersByCode[selectedCode, default: []].insert(letter)
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
        completeCurrentPhrase(didPass: false)
    }

    private func toggleHintMode() {
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

        withAnimation(.easeInOut(duration: 0.2)) {
            tiles[index].isOpen = true
            selectedTileIndex = nil
            isHintMode = false
            roundHintsUsed += 1
        }

        if freeHintCredits > 0 {
            freeHintCredits = ProgressStore.consumeFreeHint()
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

    private func loadNextRound() {
        let nextIndex = nextPhraseIndex(after: currentPhraseIndex)
        let nextTiles = RoundBuilder.makeTiles(from: phraseEntries[nextIndex].phrase, alphabet: currentLanguage.alphabet)

        withAnimation(.easeInOut(duration: 0.25)) {
            currentPhraseIndex = nextIndex
            tiles = nextTiles
            selectedTileIndex = nil
            mistakes = 0
            rejectedLettersByCode = [:]
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
        let candidateIndices: [Int]

        if completedPhraseIndices.count < phraseEntries.count {
            candidateIndices = allIndices.filter { !completedPhraseIndices.contains($0) }
        } else {
            let retryIndices = allIndices.filter { !passedPhraseIndices.contains($0) }
            candidateIndices = retryIndices.isEmpty ? allIndices : retryIndices
        }

        let nonCurrentIndices = candidateIndices.filter { $0 != index }
        let basePool = nonCurrentIndices.isEmpty ? candidateIndices : nonCurrentIndices
        let currentAuthor = phraseEntries.indices.contains(index) ? phraseEntries[index].author : ""

        let differentAuthorPool = currentAuthor.isEmpty
            ? []
            : basePool.filter { phraseEntries[$0].author != currentAuthor }
        let finalPool = differentAuthorPool.isEmpty ? basePool : differentAuthorPool

        return finalPool.randomElement() ?? 0
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
        let firstTiles = RoundBuilder.makeTiles(from: phraseEntries[firstIndex].phrase, alphabet: currentLanguage.alphabet)

        storedTheme = AppTheme.system.rawValue
        ProgressStore.reset(for: currentLanguage)

        withAnimation(.easeInOut(duration: 0.25)) {
            currentPhraseIndex = firstIndex
            tiles = firstTiles
            selectedTileIndex = nil
            mistakes = 0
            rejectedLettersByCode = [:]
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
