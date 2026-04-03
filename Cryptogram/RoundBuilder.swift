import Foundation

enum RoundBuilder {
    static func makeTiles(from phrase: String, language: AppLanguage) -> [PhraseTile] {
        let alphabet = language.alphabet
        let locale = language.localizationLocale
        let shuffledCodes = Array(1...alphabet.count).shuffled()
        let codeMap = Dictionary(uniqueKeysWithValues: zip(alphabet, shuffledCodes))

        var tiles = phrase.enumerated().map { offset, character in
            let normalizedLetter = normalized(character, alphabet: alphabet, locale: locale)

            return PhraseTile(
                index: offset,
                displayCharacter: character,
                normalizedLetter: normalizedLetter,
                code: normalizedLetter.flatMap { codeMap[$0] },
                isOpen: normalizedLetter == nil
            )
        }

        let letterIndices = tiles.indices.filter { tiles[$0].isLetter }

        let revealCount: Int
        switch letterIndices.count {
        case 0, 1:
            revealCount = 0
        default:
            let suggestedCount = Int((Double(letterIndices.count) * 0.18).rounded(.up))
            revealCount = min(letterIndices.count - 1, max(1, suggestedCount))
        }

        for index in letterIndices.shuffled().prefix(revealCount) {
            tiles[index].isOpen = true
        }

        return tiles
    }

    private static func normalized(_ character: Character, alphabet: [Character], locale: Locale) -> Character? {
        let folded = String(character)
            .replacingOccurrences(of: "Ё", with: "Е")
            .replacingOccurrences(of: "ё", with: "е")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
            .uppercased()

        guard let letter = folded.first, alphabet.contains(letter) else {
            return nil
        }

        return letter
    }
}
