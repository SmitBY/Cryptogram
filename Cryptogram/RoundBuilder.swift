import Foundation

enum RoundBuilder {
    static func makeTiles(from phrase: String, alphabet: [Character]) -> [PhraseTile] {
        let normalizedPhrase = phrase
            .replacingOccurrences(of: "Ё", with: "Е")
            .replacingOccurrences(of: "ё", with: "е")

        let shuffledCodes = Array(1...alphabet.count).shuffled()
        let codeMap = Dictionary(uniqueKeysWithValues: zip(alphabet, shuffledCodes))

        var tiles = normalizedPhrase.enumerated().map { offset, character in
            let normalizedLetter = normalized(character, alphabet: alphabet)

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

    private static func normalized(_ character: Character, alphabet: [Character]) -> Character? {
        let uppercased = String(character)
            .replacingOccurrences(of: "Ё", with: "Е")
            .replacingOccurrences(of: "ё", with: "е")
            .uppercased()

        guard let letter = uppercased.first, alphabet.contains(letter) else {
            return nil
        }

        return letter
    }
}
