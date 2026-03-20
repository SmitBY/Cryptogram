import Foundation
import SwiftUI

enum RoundStatus {
    case playing
    case won
    case lost
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var iconName: String {
        switch self {
        case .system:
            return "gearshape"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }

    var title: String {
        switch self {
        case .system:
            return "Системная"
        case .light:
            return "Светлая"
        case .dark:
            return "Тёмная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct PhraseEntry {
    let phrase: String
    let author: String
}

struct PhraseTile: Identifiable {
    let index: Int
    let displayCharacter: Character
    let normalizedLetter: Character?
    let code: Int?
    var isOpen: Bool

    var id: Int { index }

    var isLetter: Bool {
        normalizedLetter != nil
    }

    var isHiddenLetter: Bool {
        isLetter && !isOpen
    }

    var isSpace: Bool {
        displayCharacter == " "
    }

    var boardCharacter: Character {
        guard isLetter else {
            return displayCharacter
        }

        return normalizedLetter ?? displayCharacter
    }
}

struct WrongGuess: Hashable {
    let code: Int
    let letter: Character
}

struct PhraseChunk: Identifiable {
    let id: Int
    let tiles: [PhraseTile]
    let separatorAfter: ChunkSeparator
}

enum ChunkSeparator {
    case space
    case hyphen
    case none
}

struct BoardMetrics {
    let tileWidth: CGFloat
    let tileCellHeight: CGFloat
    let tileCodeHeight: CGFloat
    let tileCodeSpacing: CGFloat
    let tileHeight: CGFloat
    let tileSpacing: CGFloat
    let rowSpacing: CGFloat
    let spaceWidth: CGFloat
    let wordSpacing: CGFloat
    let letterFontSize: CGFloat
    let codeFontSize: CGFloat
    let tileCornerRadius: CGFloat

    func scaled(by scale: CGFloat) -> BoardMetrics {
        BoardMetrics(
            tileWidth: max(14, tileWidth * scale),
            tileCellHeight: max(18, tileCellHeight * scale),
            tileCodeHeight: max(8, tileCodeHeight * scale),
            tileCodeSpacing: max(1, tileCodeSpacing * scale),
            tileHeight: max(28, tileHeight * scale),
            tileSpacing: max(1, tileSpacing * scale),
            rowSpacing: max(4, rowSpacing * scale),
            spaceWidth: max(3, spaceWidth * scale),
            wordSpacing: max(4, wordSpacing * scale),
            letterFontSize: max(15, letterFontSize * scale),
            codeFontSize: max(9, codeFontSize * scale),
            tileCornerRadius: max(5, tileCornerRadius * scale)
        )
    }
}

struct KeyboardRow: Identifiable {
    let letters: [Character]

    var id: String {
        String(letters)
    }
}

struct GlobalStatsSnapshot {
    let totalRounds: Int
    let totalPassedRounds: Int
    let totalMistakes: Int
    let totalDuration: TimeInterval
    let totalHints: Int
    let bestPassedDuration: TimeInterval

    static let zero = GlobalStatsSnapshot(
        totalRounds: 0,
        totalPassedRounds: 0,
        totalMistakes: 0,
        totalDuration: 0,
        totalHints: 0,
        bestPassedDuration: 0
    )

    var lostRoundsCount: Int {
        max(totalRounds - totalPassedRounds, 0)
    }

    var winRateText: String {
        guard totalRounds > 0 else {
            return "—"
        }

        let ratio = Double(totalPassedRounds) / Double(totalRounds)
        return "\(Int((ratio * 100).rounded()))%"
    }

    var averageMistakesText: String {
        guard totalRounds > 0 else {
            return "—"
        }

        return formatAverage(Double(totalMistakes) / Double(totalRounds))
    }

    var averageRoundTimeText: String {
        guard totalRounds > 0 else {
            return "—"
        }

        return formatDuration(totalDuration / Double(totalRounds))
    }

    var bestPassedTimeText: String {
        bestPassedDuration > 0 ? formatDuration(bestPassedDuration) : "—"
    }

    var averageHintsText: String {
        guard totalRounds > 0 else {
            return "—"
        }

        return formatAverage(Double(totalHints) / Double(totalRounds))
    }

    private func formatAverage(_ value: Double) -> String {
        let roundedValue = (value * 10).rounded() / 10

        if roundedValue.rounded() == roundedValue {
            return String(Int(roundedValue))
        }

        return String(format: "%.1f", roundedValue).replacingOccurrences(of: ".", with: ",")
    }

    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(timeInterval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}
