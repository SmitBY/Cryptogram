import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case ru
    case en
    case es
    case de
    case fr
    case it
    case pt

    static let contentLanguages: [AppLanguage] = [.ru, .en, .es, .de, .fr, .it, .pt]

    var id: Self { self }

    var localeIdentifier: String {
        switch self {
        case .system:
            return Locale.preferredLanguages.first ?? "en"
        case .ru:
            return "ru"
        case .en:
            return "en"
        case .es:
            return "es"
        case .de:
            return "de"
        case .fr:
            return "fr"
        case .it:
            return "it"
        case .pt:
            return "pt"
        }
    }

    var localizationLocale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        default:
            return Locale(identifier: localeIdentifier)
        }
    }

    var contentCode: String {
        switch self {
        case .system:
            return "system"
        case .ru:
            return "ru"
        case .en:
            return "en"
        case .es:
            return "es"
        case .de:
            return "de"
        case .fr:
            return "fr"
        case .it:
            return "it"
        case .pt:
            return "pt"
        }
    }

    var phraseFileName: String {
        switch self {
        case .ru:
            return "phrases"
        case .en:
            return "phrases_en"
        case .es:
            return "phrases_es"
        case .de:
            return "phrases_de"
        case .fr:
            return "phrases_fr"
        case .it:
            return "phrases_it"
        case .pt:
            return "phrases_pt"
        case .system:
            return AppLanguage.resolved(from: .system).phraseFileName
        }
    }

    var alphabet: [Character] {
        switch self {
        case .ru:
            return Array("АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
        case .en, .es, .de, .fr, .it, .pt:
            return Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        case .system:
            return AppLanguage.resolved(from: .system).alphabet
        }
    }

    var keyboardRows: [KeyboardRow] {
        switch self {
        case .ru:
            return [
                KeyboardRow(letters: Array("ЙЦУКЕНГШЩЗХЪ")),
                KeyboardRow(letters: Array("ФЫВАПРОЛДЖЭ")),
                KeyboardRow(letters: Array("ЯЧСМИТЬБЮ"))
            ]
        case .en, .es, .de, .fr, .it, .pt:
            return [
                KeyboardRow(letters: Array("QWERTYUIOP")),
                KeyboardRow(letters: Array("ASDFGHJKL")),
                KeyboardRow(letters: Array("ZXCVBNM"))
            ]
        case .system:
            return AppLanguage.resolved(from: .system).keyboardRows
        }
    }

    var nativeTitle: String {
        switch self {
        case .system:
            return "System"
        case .ru:
            return "Русский"
        case .en:
            return "English"
        case .es:
            return "Español"
        case .de:
            return "Deutsch"
        case .fr:
            return "Français"
        case .it:
            return "Italiano"
        case .pt:
            return "Português"
        }
    }

    func localizedTitle(in language: AppLanguage) -> String {
        switch self {
        case .system:
            return language.text(.languageSystem)
        default:
            return nativeTitle
        }
    }

    func text(_ key: AppText) -> String {
        localizedString(key.rawValue)
    }

    func localizedString(_ key: String) -> String {
        String(
            localized: String.LocalizationValue(key),
            bundle: .main,
            locale: localizationLocale
        )
    }

    static func resolved(from selection: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard selection == .system else {
            return selection
        }

        guard let identifier = preferredLanguages.first?.lowercased() else {
            return .en
        }

        if identifier.hasPrefix("ru") { return .ru }
        if identifier.hasPrefix("es") { return .es }
        if identifier.hasPrefix("de") { return .de }
        if identifier.hasPrefix("fr") { return .fr }
        if identifier.hasPrefix("it") { return .it }
        if identifier.hasPrefix("pt") { return .pt }
        return .en
    }
}

enum AppText: String, Hashable {
    case settingsTitle
    case languageTitle
    case themeTitle
    case purchasesTitle
    case globalStatsTitle
    case removeAdsTitle
    case purchaseOwnedDescription
    case purchaseLoadingDescription
    case purchaseUnavailableDescription
    case purchaseMainDescription
    case purchaseActiveButton
    case purchaseBuyButton
    case purchaseRestoreButton
    case roundsCompleted
    case wins
    case losses
    case winRate
    case avgMistakes
    case avgRoundTime
    case bestWin
    case avgHints
    case resetButton
    case resetHint
    case resetDialogTitle
    case resetDialogButton
    case cancelButton
    case resetDialogMessage
    case completedTitle
    case openedTitle
    case mistakesTitle
    case settingsAccessibilityLabel
    case authorTitle
    case roundSolved
    case roundLost
    case nextButton
    case hintButton
    case continueOfferTitle
    case continueOfferMessage
    case continueOfferWatchAd
    case continueOfferContinue
    case continueOfferDecline
    case dailyHintRewardToast
    case tutorialTitle
    case tutorialPickTile
    case tutorialEnterLetter
    case tutorialHintButton
    case tutorialHintTile
    case tutorialCompleted
    case languageSystem
    case themeSystem
    case themeLight
    case themeDark
    case purchaseUnavailableStatus
    case purchaseVerificationFailedStatus
    case purchaseAdsRemovedStatus
    case purchaseCompletedStatus
    case purchasePendingStatus
    case purchaseCancelledStatus
    case purchaseUnknownStatus
    case purchaseFailedStatus
    case purchaseRestoredStatus
    case purchaseNotFoundStatus
    case purchaseRestoreFailedStatus
    case purchaseLoadFailedStatus
    case purchaseBoughtShort
    case purchaseLoadingShort
    case purchaseUnavailableShort
}

extension AppTheme {
    func localizedTitle(in language: AppLanguage) -> String {
        switch self {
        case .system:
            return language.text(.themeSystem)
        case .light:
            return language.text(.themeLight)
        case .dark:
            return language.text(.themeDark)
        }
    }
}
