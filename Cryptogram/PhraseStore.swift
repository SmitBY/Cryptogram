import Foundation

enum PhraseStore {
    private static let wikiLinkRegex = try! NSRegularExpression(
        pattern: "\\[([^\\]]+)\\]\\([^\\)]*\\)",
        options: []
    )
    private static let wikiRefRegex = try! NSRegularExpression(
        pattern: "\\[\\d+\\]",
        options: []
    )
    static func load(language: AppLanguage) -> [PhraseEntry] {
        guard let url = Bundle.main.url(forResource: language.phraseFileName, withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return fallbackEntries(for: language)
        }

        let entries: [PhraseEntry] = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { line -> PhraseEntry? in
                guard !line.isEmpty else { return nil }

                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                if let range = trimmedLine.range(of: "||") {
                    let rawPhrase = String(trimmedLine[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let rawAuthor = String(trimmedLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    let phrase = normalizePhraseCase(cleanForPuzzle(rawPhrase))
                    let author = normalizeAuthorCase(rawAuthor)
                    return phrase.isEmpty ? nil : PhraseEntry(phrase: phrase, author: author)
                } else {
                    let phrase = normalizePhraseCase(cleanForPuzzle(trimmedLine))
                    return phrase.isEmpty ? nil : PhraseEntry(phrase: phrase, author: "")
                }
            }

        return entries.isEmpty ? fallbackEntries(for: language) : entries
    }

    private static func fallbackEntries(for language: AppLanguage) -> [PhraseEntry] {
        switch language {
        case .ru:
            return [
                PhraseEntry(phrase: "Делу время — потехе час.", author: ""),
                PhraseEntry(phrase: "Без труда не выловишь и рыбку из пруда.", author: ""),
                PhraseEntry(phrase: "В гостях хорошо, а дома лучше.", author: "")
            ]
        case .en:
            return [
                PhraseEntry(phrase: "Time is money.", author: ""),
                PhraseEntry(phrase: "Better late than never.", author: ""),
                PhraseEntry(phrase: "Knowledge is power.", author: "")
            ]
        case .es:
            return [
                PhraseEntry(phrase: "El tiempo es oro.", author: ""),
                PhraseEntry(phrase: "Más vale tarde que nunca.", author: ""),
                PhraseEntry(phrase: "La unión hace la fuerza.", author: "")
            ]
        case .de:
            return [
                PhraseEntry(phrase: "Zeit ist Geld.", author: ""),
                PhraseEntry(phrase: "Ende gut, alles gut.", author: ""),
                PhraseEntry(phrase: "Ohne Fleiß kein Preis.", author: "")
            ]
        case .fr:
            return [
                PhraseEntry(phrase: "Je pense, donc je suis.", author: "René Descartes"),
                PhraseEntry(phrase: "Qui vivra verra.", author: ""),
                PhraseEntry(phrase: "Mieux vaut tard que jamais.", author: "")
            ]
        case .it:
            return [
                PhraseEntry(phrase: "Il tempo è denaro.", author: ""),
                PhraseEntry(phrase: "Volere è potere.", author: ""),
                PhraseEntry(phrase: "Tutte le strade portano a Roma.", author: "")
            ]
        case .pt:
            return [
                PhraseEntry(phrase: "O tempo é ouro.", author: ""),
                PhraseEntry(phrase: "A união faz a força.", author: ""),
                PhraseEntry(phrase: "Antes tarde do que nunca.", author: "")
            ]
        case .system:
            return fallbackEntries(for: AppLanguage.resolved(from: .system))
        }
    }

    private static func cleanForPuzzle(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "&amp;", with: "&")

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        text = wikiLinkRegex.stringByReplacingMatches(
            in: text,
            options: [],
            range: fullRange,
            withTemplate: "$1"
        )

        let refRange = NSRange(text.startIndex..<text.endIndex, in: text)
        text = wikiRefRegex.stringByReplacingMatches(in: text, options: [], range: refRange, withTemplate: "")

        text = text.precomposedStringWithCanonicalMapping
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizePhraseCase(_ text: String) -> String {
        guard isFullyUppercased(text) else {
            return text
        }

        let lowercasedText = text.lowercased()
        var result = ""
        var shouldCapitalizeNextLetter = true

        for character in lowercasedText {
            if shouldCapitalizeNextLetter,
               String(character).rangeOfCharacter(from: .letters) != nil {
                result.append(contentsOf: String(character).uppercased())
                shouldCapitalizeNextLetter = false
            } else {
                result.append(character)
            }

            if ".!?…".contains(character) {
                shouldCapitalizeNextLetter = true
            }
        }

        return result
    }

    private static func normalizeAuthorCase(_ text: String) -> String {
        guard !text.isEmpty else {
            return ""
        }

        guard isFullyUppercased(text) else {
            return text
        }

        return text.capitalized
    }

    private static func isFullyUppercased(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return false
        }

        return trimmedText == trimmedText.uppercased() && trimmedText != trimmedText.lowercased()
    }
}
