import Foundation

enum ProgressStorageKey {
    static let currentPhraseIndex = "progress.currentPhraseIndex"
    static let completedPhraseIndices = "progress.completedPhraseIndices"
    static let passedPhraseIndices = "progress.passedPhraseIndices"
    static let datasetSignature = "progress.datasetSignature"
    static let currentRoundState = "progress.currentRoundState"
    static let hasCompletedFirstGameTutorial = "tutorial.hasCompletedFirstGameTutorial"
    static let selectedTheme = "settings.selectedTheme"
    static let selectedLanguage = "settings.selectedLanguage"
    static let totalRounds = "stats.totalRounds"
    static let totalPassedRounds = "stats.totalPassedRounds"
    static let totalMistakes = "stats.totalMistakes"
    static let totalDuration = "stats.totalDuration"
    static let totalHints = "stats.totalHints"
    static let bestPassedDuration = "stats.bestPassedDuration"
    static let freeHintCredits = "economy.freeHintCredits"
    static let lastFreeHintRewardDate = "economy.lastFreeHintRewardDate"
}

enum ProgressCodec {
    static func decode(_ rawValue: String, upperBound: Int) -> Set<Int> {
        guard upperBound > 0, !rawValue.isEmpty else {
            return []
        }

        return Set(
            rawValue
                .split(separator: ",")
                .compactMap { Int($0) }
                .filter { $0 >= 0 && $0 < upperBound }
        )
    }

    static func encode(_ indices: Set<Int>) -> String {
        indices
            .sorted()
            .map(String.init)
            .joined(separator: ",")
    }

    static func datasetSignature(for entries: [PhraseEntry]) -> String {
        var hash: UInt64 = 1469598103934665603
        let text = entries
            .map { "\($0.phrase)||\($0.author)" }
            .joined(separator: "\n")

        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }

        return String(hash, radix: 16)
    }
}

struct LanguageProgressSnapshot {
    let datasetSignature: String
    let currentPhraseIndex: Int
    let completedIndices: Set<Int>
    let passedIndices: Set<Int>
    let stats: GlobalStatsSnapshot
    let currentRoundState: PersistedRoundState?
}

struct FreeHintRefreshResult {
    let credits: Int
    let didGrantDailyReward: Bool
}

struct PersistedRoundTile: Codable {
    let index: Int
    let displayCharacter: String
    let normalizedLetter: String?
    let code: Int?
    let isOpen: Bool

    init(tile: PhraseTile) {
        index = tile.index
        displayCharacter = String(tile.displayCharacter)
        normalizedLetter = tile.normalizedLetter.map(String.init)
        code = tile.code
        isOpen = tile.isOpen
    }

    var phraseTile: PhraseTile? {
        guard displayCharacter.count == 1,
              let displayCharacter = displayCharacter.first else {
            return nil
        }

        let restoredNormalizedLetter: Character?
        if let normalizedLetterValue = normalizedLetter {
            guard normalizedLetterValue.count == 1,
                  let restoredLetter = normalizedLetterValue.first else {
                return nil
            }
            restoredNormalizedLetter = restoredLetter
        } else {
            restoredNormalizedLetter = nil
        }

        return PhraseTile(
            index: index,
            displayCharacter: displayCharacter,
            normalizedLetter: restoredNormalizedLetter,
            code: code,
            isOpen: isOpen
        )
    }
}

struct PersistedRoundState: Codable {
    let phraseIndex: Int
    let mistakes: Int
    let tiles: [PersistedRoundTile]

    init(phraseIndex: Int, mistakes: Int, tiles: [PhraseTile]) {
        self.phraseIndex = phraseIndex
        self.mistakes = mistakes
        self.tiles = tiles.map(PersistedRoundTile.init)
    }

    func restoredTiles() -> [PhraseTile]? {
        let restoredTiles = tiles.compactMap(\.phraseTile)
        guard restoredTiles.count == tiles.count else {
            return nil
        }

        let expectedIndices = Array(restoredTiles.indices)
        guard zip(restoredTiles, expectedIndices).allSatisfy({ pair in
            pair.0.index == pair.1
        }) else {
            return nil
        }

        return restoredTiles
    }
}

enum ProgressStore {
    private static let initialFreeHintCredits = 3

    static func load(for language: AppLanguage, entries: [PhraseEntry], userDefaults: UserDefaults = .standard) -> LanguageProgressSnapshot {
        let datasetSignature = ProgressCodec.datasetSignature(for: entries)
        let storedSignature = userDefaults.string(forKey: key(ProgressStorageKey.datasetSignature, language: language))
        let shouldResetProgress = storedSignature != datasetSignature

        if shouldResetProgress {
            resetProgress(for: language, userDefaults: userDefaults)
        }

        let storedIndex = shouldResetProgress
            ? 0
            : userDefaults.integer(forKey: key(ProgressStorageKey.currentPhraseIndex, language: language))
        let initialIndex = entries.indices.contains(storedIndex) ? storedIndex : 0

        let completedIndices = shouldResetProgress
            ? []
            : ProgressCodec.decode(
                userDefaults.string(forKey: key(ProgressStorageKey.completedPhraseIndices, language: language)) ?? "",
                upperBound: entries.count
            )

        let passedIndices = shouldResetProgress
            ? []
            : ProgressCodec.decode(
                userDefaults.string(forKey: key(ProgressStorageKey.passedPhraseIndices, language: language)) ?? "",
                upperBound: entries.count
            ).intersection(completedIndices)

        let stats = GlobalStatsSnapshot(
            totalRounds: shouldResetProgress ? 0 : userDefaults.integer(forKey: key(ProgressStorageKey.totalRounds, language: language)),
            totalPassedRounds: shouldResetProgress ? 0 : userDefaults.integer(forKey: key(ProgressStorageKey.totalPassedRounds, language: language)),
            totalMistakes: shouldResetProgress ? 0 : userDefaults.integer(forKey: key(ProgressStorageKey.totalMistakes, language: language)),
            totalDuration: shouldResetProgress ? 0 : userDefaults.double(forKey: key(ProgressStorageKey.totalDuration, language: language)),
            totalHints: shouldResetProgress ? 0 : userDefaults.integer(forKey: key(ProgressStorageKey.totalHints, language: language)),
            bestPassedDuration: shouldResetProgress ? 0 : userDefaults.double(forKey: key(ProgressStorageKey.bestPassedDuration, language: language))
        )

        let currentRoundState = shouldResetProgress
            ? nil
            : loadCurrentRoundState(
                for: language,
                currentPhraseIndex: initialIndex,
                userDefaults: userDefaults
            )

        return LanguageProgressSnapshot(
            datasetSignature: datasetSignature,
            currentPhraseIndex: initialIndex,
            completedIndices: completedIndices,
            passedIndices: passedIndices,
            stats: stats,
            currentRoundState: currentRoundState
        )
    }

    static func persist(
        language: AppLanguage,
        currentPhraseIndex: Int,
        completedIndices: Set<Int>,
        passedIndices: Set<Int>,
        datasetSignature: String,
        stats: GlobalStatsSnapshot,
        currentRoundState: PersistedRoundState?,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(currentPhraseIndex, forKey: key(ProgressStorageKey.currentPhraseIndex, language: language))
        userDefaults.set(ProgressCodec.encode(completedIndices), forKey: key(ProgressStorageKey.completedPhraseIndices, language: language))
        userDefaults.set(ProgressCodec.encode(passedIndices), forKey: key(ProgressStorageKey.passedPhraseIndices, language: language))
        userDefaults.set(datasetSignature, forKey: key(ProgressStorageKey.datasetSignature, language: language))
        userDefaults.set(stats.totalRounds, forKey: key(ProgressStorageKey.totalRounds, language: language))
        userDefaults.set(stats.totalPassedRounds, forKey: key(ProgressStorageKey.totalPassedRounds, language: language))
        userDefaults.set(stats.totalMistakes, forKey: key(ProgressStorageKey.totalMistakes, language: language))
        userDefaults.set(stats.totalDuration, forKey: key(ProgressStorageKey.totalDuration, language: language))
        userDefaults.set(stats.totalHints, forKey: key(ProgressStorageKey.totalHints, language: language))
        userDefaults.set(stats.bestPassedDuration, forKey: key(ProgressStorageKey.bestPassedDuration, language: language))

        let currentRoundStateKey = key(ProgressStorageKey.currentRoundState, language: language)
        if let currentRoundState,
           let encodedRoundState = try? JSONEncoder().encode(currentRoundState) {
            userDefaults.set(encodedRoundState, forKey: currentRoundStateKey)
        } else {
            userDefaults.removeObject(forKey: currentRoundStateKey)
        }
    }

    static func reset(for language: AppLanguage, userDefaults: UserDefaults = .standard) {
        resetProgress(for: language, userDefaults: userDefaults)
        resetHintEconomy(userDefaults: userDefaults)
    }

    static func refreshFreeHintCredits(userDefaults: UserDefaults = .standard, now: Date = Date(), calendar: Calendar = .current) -> FreeHintRefreshResult {
        let creditsKey = ProgressStorageKey.freeHintCredits
        let rewardDateKey = ProgressStorageKey.lastFreeHintRewardDate
        let todayStamp = dayStamp(for: now, calendar: calendar)

        let hasStoredCredits = userDefaults.object(forKey: creditsKey) != nil
        var credits = hasStoredCredits ? userDefaults.integer(forKey: creditsKey) : initialFreeHintCredits
        let storedRewardDate = userDefaults.string(forKey: rewardDateKey)

        if storedRewardDate == nil {
            userDefaults.set(credits, forKey: creditsKey)
            userDefaults.set(todayStamp, forKey: rewardDateKey)
            return FreeHintRefreshResult(credits: credits, didGrantDailyReward: false)
        }

        if storedRewardDate != todayStamp {
            credits += 1
            userDefaults.set(credits, forKey: creditsKey)
            userDefaults.set(todayStamp, forKey: rewardDateKey)
            return FreeHintRefreshResult(credits: credits, didGrantDailyReward: true)
        }

        return FreeHintRefreshResult(credits: credits, didGrantDailyReward: false)
    }

    static func consumeFreeHint(userDefaults: UserDefaults = .standard) -> Int {
        let availableCredits = refreshFreeHintCredits(userDefaults: userDefaults).credits
        guard availableCredits > 0 else {
            return 0
        }

        let updatedCredits = availableCredits - 1
        userDefaults.set(updatedCredits, forKey: ProgressStorageKey.freeHintCredits)
        return updatedCredits
    }

    private static func resetProgress(for language: AppLanguage, userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: key(ProgressStorageKey.currentPhraseIndex, language: language))
        userDefaults.removeObject(forKey: key(ProgressStorageKey.completedPhraseIndices, language: language))
        userDefaults.removeObject(forKey: key(ProgressStorageKey.passedPhraseIndices, language: language))
        userDefaults.removeObject(forKey: key(ProgressStorageKey.datasetSignature, language: language))
        userDefaults.removeObject(forKey: key(ProgressStorageKey.currentRoundState, language: language))
        userDefaults.removeObject(forKey: key(ProgressStorageKey.totalRounds, language: language))
        userDefaults.removeObject(forKey: key(ProgressStorageKey.totalPassedRounds, language: language))
        userDefaults.removeObject(forKey: key(ProgressStorageKey.totalMistakes, language: language))
        userDefaults.removeObject(forKey: key(ProgressStorageKey.totalDuration, language: language))
        userDefaults.removeObject(forKey: key(ProgressStorageKey.totalHints, language: language))
        userDefaults.removeObject(forKey: key(ProgressStorageKey.bestPassedDuration, language: language))
    }

    private static func resetHintEconomy(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: ProgressStorageKey.freeHintCredits)
        userDefaults.removeObject(forKey: ProgressStorageKey.lastFreeHintRewardDate)
    }

    private static func dayStamp(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func loadCurrentRoundState(
        for language: AppLanguage,
        currentPhraseIndex: Int,
        userDefaults: UserDefaults = .standard
    ) -> PersistedRoundState? {
        let roundStateKey = key(ProgressStorageKey.currentRoundState, language: language)
        guard let roundStateData = userDefaults.data(forKey: roundStateKey),
              let roundState = try? JSONDecoder().decode(PersistedRoundState.self, from: roundStateData),
              roundState.phraseIndex == currentPhraseIndex,
              roundState.mistakes >= 0,
              roundState.restoredTiles() != nil else {
            userDefaults.removeObject(forKey: roundStateKey)
            return nil
        }

        return roundState
    }

    private static func key(_ baseKey: String, language: AppLanguage) -> String {
        "\(baseKey).\(language.contentCode)"
    }
}
