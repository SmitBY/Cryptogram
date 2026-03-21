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
        let language = self == .system ? AppLanguage.resolved(from: .system) : self
        let dictionary = AppLocalizer.translations[language] ?? AppLocalizer.translations[.en]!
        return dictionary[key] ?? AppLocalizer.translations[.en]![key]!
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

private enum AppLocalizer {
    static let translations: [AppLanguage: [AppText: String]] = [
        .ru: [
            .settingsTitle: "Настройки",
            .languageTitle: "Язык",
            .themeTitle: "Тема",
            .purchasesTitle: "Покупки",
            .globalStatsTitle: "Глобальная статистика",
            .removeAdsTitle: "Отключить рекламу навсегда",
            .purchaseOwnedDescription: "Покупка активна на этом Apple ID.",
            .purchaseLoadingDescription: "Загружаем информацию о покупке.",
            .purchaseUnavailableDescription: "Покупка пока недоступна.",
            .purchaseMainDescription: "После покупки реклама больше не будет показываться.",
            .purchaseActiveButton: "Активно",
            .purchaseBuyButton: "Купить",
            .purchaseRestoreButton: "Восстановить",
            .roundsCompleted: "Раундов завершено",
            .wins: "Побед",
            .losses: "Поражений",
            .winRate: "Процент побед",
            .avgMistakes: "Средние ошибки за раунд",
            .avgRoundTime: "Среднее время раунда",
            .bestWin: "Лучшая победа",
            .avgHints: "Средние подсказки за раунд",
            .resetButton: "Начать заново",
            .resetHint: "Сбросит прогресс, тему и всю статистику. Покупка отключения рекламы сохранится.",
            .resetDialogTitle: "Начать заново?",
            .resetDialogButton: "Сбросить прогресс, тему и статистику",
            .cancelButton: "Отмена",
            .resetDialogMessage: "Игра начнётся с первой фразы, тема вернётся к системной, а статистика обнулится.",
            .completedTitle: "Завершено",
            .openedTitle: "Открыто",
            .mistakesTitle: "Ошибки",
            .settingsAccessibilityLabel: "Настройки",
            .authorTitle: "Автор",
            .roundSolved: "Фраза разгадана",
            .roundLost: "Три ошибки",
            .nextButton: "Следующая",
            .hintButton: "Подсказка",
            .continueOfferTitle: "Последний шанс",
            .continueOfferMessage: "Вы допустили последнюю ошибку. Можно посмотреть короткую рекламу и продолжить эту фразу.",
            .continueOfferWatchAd: "Смотреть рекламу",
            .continueOfferContinue: "Продолжить",
            .continueOfferDecline: "Завершить уровень",
            .dailyHintRewardToast: "+1 подсказка за новый день",
            .tutorialTitle: "Как играть",
            .tutorialPickTile: "Сравнивай буквы с цифрами под ними: одинаковые цифры обозначают одну и ту же букву. Нажми на подсвеченную клетку.",
            .tutorialEnterLetter: "Теперь выбери на клавиатуре букву для этой цифры.",
            .tutorialHintButton: "Если не получается найти букву, нажми «Подсказка».",
            .tutorialHintTile: "Подсказка включена. Нажми на подсвеченную клетку, чтобы открыть букву.",
            .tutorialCompleted: "Отлично. Дальше разгадывай фразу самостоятельно.",
            .languageSystem: "Системный",
            .themeSystem: "Системная",
            .themeLight: "Светлая",
            .themeDark: "Тёмная",
            .purchaseUnavailableStatus: "Покупка пока недоступна.",
            .purchaseVerificationFailedStatus: "Не удалось подтвердить покупку.",
            .purchaseAdsRemovedStatus: "Реклама отключена.",
            .purchaseCompletedStatus: "Покупка завершена.",
            .purchasePendingStatus: "Покупка ожидает подтверждения.",
            .purchaseCancelledStatus: "Покупка отменена.",
            .purchaseUnknownStatus: "Неизвестный результат покупки.",
            .purchaseFailedStatus: "Не удалось завершить покупку.",
            .purchaseRestoredStatus: "Покупка восстановлена.",
            .purchaseNotFoundStatus: "Покупки не найдены.",
            .purchaseRestoreFailedStatus: "Не удалось восстановить покупки.",
            .purchaseLoadFailedStatus: "Не удалось загрузить информацию о покупке.",
            .purchaseBoughtShort: "Куплено",
            .purchaseLoadingShort: "Загрузка...",
            .purchaseUnavailableShort: "Недоступно"
        ],
        .en: [
            .settingsTitle: "Settings",
            .languageTitle: "Language",
            .themeTitle: "Theme",
            .purchasesTitle: "Purchases",
            .globalStatsTitle: "Global Stats",
            .removeAdsTitle: "Remove ads forever",
            .purchaseOwnedDescription: "This purchase is active for this Apple ID.",
            .purchaseLoadingDescription: "Loading purchase information.",
            .purchaseUnavailableDescription: "Purchase is currently unavailable.",
            .purchaseMainDescription: "Ads will stop showing after purchase.",
            .purchaseActiveButton: "Active",
            .purchaseBuyButton: "Buy",
            .purchaseRestoreButton: "Restore",
            .roundsCompleted: "Rounds completed",
            .wins: "Wins",
            .losses: "Losses",
            .winRate: "Win rate",
            .avgMistakes: "Average mistakes per round",
            .avgRoundTime: "Average round time",
            .bestWin: "Best win",
            .avgHints: "Average hints per round",
            .resetButton: "Start over",
            .resetHint: "Resets progress, theme and all stats. Ad removal purchase is kept.",
            .resetDialogTitle: "Start over?",
            .resetDialogButton: "Reset progress, theme and stats",
            .cancelButton: "Cancel",
            .resetDialogMessage: "The game will start from the first phrase, the theme will return to system, and stats will be reset.",
            .completedTitle: "Completed",
            .openedTitle: "Opened",
            .mistakesTitle: "Mistakes",
            .settingsAccessibilityLabel: "Settings",
            .authorTitle: "Author",
            .roundSolved: "Phrase solved",
            .roundLost: "Three mistakes",
            .nextButton: "Next",
            .hintButton: "Hint",
            .continueOfferTitle: "Last chance",
            .continueOfferMessage: "You made the final mistake. You can watch a short ad and continue this phrase.",
            .continueOfferWatchAd: "Watch ad",
            .continueOfferContinue: "Continue",
            .continueOfferDecline: "End round",
            .dailyHintRewardToast: "+1 hint for a new day",
            .tutorialTitle: "How to play",
            .tutorialPickTile: "Match letters to the numbers below them: the same number always stands for the same letter. Tap the highlighted tile.",
            .tutorialEnterLetter: "Now choose the letter for this number on the keyboard.",
            .tutorialHintButton: "If you cannot find the letter, tap Hint.",
            .tutorialHintTile: "Hint mode is on. Tap the highlighted tile to reveal a letter.",
            .tutorialCompleted: "Great. Now finish the phrase on your own.",
            .languageSystem: "System",
            .themeSystem: "System",
            .themeLight: "Light",
            .themeDark: "Dark",
            .purchaseUnavailableStatus: "Purchase is currently unavailable.",
            .purchaseVerificationFailedStatus: "Could not verify the purchase.",
            .purchaseAdsRemovedStatus: "Ads removed.",
            .purchaseCompletedStatus: "Purchase completed.",
            .purchasePendingStatus: "Purchase is pending confirmation.",
            .purchaseCancelledStatus: "Purchase cancelled.",
            .purchaseUnknownStatus: "Unknown purchase result.",
            .purchaseFailedStatus: "Could not complete the purchase.",
            .purchaseRestoredStatus: "Purchase restored.",
            .purchaseNotFoundStatus: "No purchases were found.",
            .purchaseRestoreFailedStatus: "Could not restore purchases.",
            .purchaseLoadFailedStatus: "Could not load purchase information.",
            .purchaseBoughtShort: "Bought",
            .purchaseLoadingShort: "Loading...",
            .purchaseUnavailableShort: "Unavailable"
        ],
        .es: [
            .settingsTitle: "Ajustes",
            .languageTitle: "Idioma",
            .themeTitle: "Tema",
            .purchasesTitle: "Compras",
            .globalStatsTitle: "Estadisticas globales",
            .removeAdsTitle: "Quitar anuncios para siempre",
            .purchaseOwnedDescription: "Esta compra esta activa para este Apple ID.",
            .purchaseLoadingDescription: "Cargando informacion de compra.",
            .purchaseUnavailableDescription: "La compra no esta disponible por ahora.",
            .purchaseMainDescription: "Los anuncios dejaran de mostrarse despues de la compra.",
            .purchaseActiveButton: "Activo",
            .purchaseBuyButton: "Comprar",
            .purchaseRestoreButton: "Restaurar",
            .roundsCompleted: "Rondas completadas",
            .wins: "Victorias",
            .losses: "Derrotas",
            .winRate: "Porcentaje de victorias",
            .avgMistakes: "Errores medios por ronda",
            .avgRoundTime: "Tiempo medio por ronda",
            .bestWin: "Mejor victoria",
            .avgHints: "Pistas medias por ronda",
            .resetButton: "Empezar de nuevo",
            .resetHint: "Restablece el progreso, el tema y todas las estadisticas. La compra para quitar anuncios se conserva.",
            .resetDialogTitle: "Empezar de nuevo?",
            .resetDialogButton: "Restablecer progreso, tema y estadisticas",
            .cancelButton: "Cancelar",
            .resetDialogMessage: "El juego comenzara desde la primera frase, el tema volvera al sistema y las estadisticas se reiniciaran.",
            .completedTitle: "Completado",
            .openedTitle: "Abierto",
            .mistakesTitle: "Errores",
            .settingsAccessibilityLabel: "Ajustes",
            .authorTitle: "Autor",
            .roundSolved: "Frase resuelta",
            .roundLost: "Tres errores",
            .nextButton: "Siguiente",
            .hintButton: "Pista",
            .continueOfferTitle: "Ultima oportunidad",
            .continueOfferMessage: "Has cometido el ultimo error. Puedes ver un anuncio corto y continuar esta frase.",
            .continueOfferWatchAd: "Ver anuncio",
            .continueOfferContinue: "Continuar",
            .continueOfferDecline: "Terminar ronda",
            .dailyHintRewardToast: "+1 pista por un nuevo dia",
            .tutorialTitle: "Como jugar",
            .tutorialPickTile: "Compara las letras con los numeros de abajo: el mismo numero siempre significa la misma letra. Toca la casilla resaltada.",
            .tutorialEnterLetter: "Ahora elige en el teclado la letra para ese numero.",
            .tutorialHintButton: "Si no encuentras la letra, toca Pista.",
            .tutorialHintTile: "La pista esta activa. Toca la casilla resaltada para abrir una letra.",
            .tutorialCompleted: "Perfecto. Ahora termina la frase por tu cuenta.",
            .languageSystem: "Sistema",
            .themeSystem: "Sistema",
            .themeLight: "Claro",
            .themeDark: "Oscuro",
            .purchaseUnavailableStatus: "La compra no esta disponible por ahora.",
            .purchaseVerificationFailedStatus: "No se pudo verificar la compra.",
            .purchaseAdsRemovedStatus: "Anuncios desactivados.",
            .purchaseCompletedStatus: "Compra completada.",
            .purchasePendingStatus: "La compra esta pendiente de confirmacion.",
            .purchaseCancelledStatus: "Compra cancelada.",
            .purchaseUnknownStatus: "Resultado de compra desconocido.",
            .purchaseFailedStatus: "No se pudo completar la compra.",
            .purchaseRestoredStatus: "Compra restaurada.",
            .purchaseNotFoundStatus: "No se encontraron compras.",
            .purchaseRestoreFailedStatus: "No se pudieron restaurar las compras.",
            .purchaseLoadFailedStatus: "No se pudo cargar la informacion de compra.",
            .purchaseBoughtShort: "Comprado",
            .purchaseLoadingShort: "Cargando...",
            .purchaseUnavailableShort: "No disponible"
        ],
        .de: [
            .settingsTitle: "Einstellungen",
            .languageTitle: "Sprache",
            .themeTitle: "Design",
            .purchasesTitle: "Kauefe",
            .globalStatsTitle: "Globale Statistik",
            .removeAdsTitle: "Werbung fuer immer entfernen",
            .purchaseOwnedDescription: "Dieser Kauf ist fuer diese Apple ID aktiv.",
            .purchaseLoadingDescription: "Kaufinformationen werden geladen.",
            .purchaseUnavailableDescription: "Der Kauf ist derzeit nicht verfuegbar.",
            .purchaseMainDescription: "Nach dem Kauf wird keine Werbung mehr angezeigt.",
            .purchaseActiveButton: "Aktiv",
            .purchaseBuyButton: "Kaufen",
            .purchaseRestoreButton: "Wiederherstellen",
            .roundsCompleted: "Abgeschlossene Runden",
            .wins: "Siege",
            .losses: "Niederlagen",
            .winRate: "Siegquote",
            .avgMistakes: "Durchschnittliche Fehler pro Runde",
            .avgRoundTime: "Durchschnittliche Rundenzeit",
            .bestWin: "Bester Sieg",
            .avgHints: "Durchschnittliche Hinweise pro Runde",
            .resetButton: "Neu beginnen",
            .resetHint: "Setzt Fortschritt, Design und alle Statistiken zurueck. Der Kauf zum Entfernen der Werbung bleibt erhalten.",
            .resetDialogTitle: "Neu beginnen?",
            .resetDialogButton: "Fortschritt, Design und Statistik zuruecksetzen",
            .cancelButton: "Abbrechen",
            .resetDialogMessage: "Das Spiel startet mit dem ersten Satz, das Design wird auf System gesetzt und die Statistik wird geloescht.",
            .completedTitle: "Fertig",
            .openedTitle: "Geoeffnet",
            .mistakesTitle: "Fehler",
            .settingsAccessibilityLabel: "Einstellungen",
            .authorTitle: "Autor",
            .roundSolved: "Satz geloest",
            .roundLost: "Drei Fehler",
            .nextButton: "Weiter",
            .hintButton: "Hinweis",
            .continueOfferTitle: "Letzte Chance",
            .continueOfferMessage: "Du hast den letzten Fehler gemacht. Du kannst eine kurze Werbung ansehen und mit diesem Satz weitermachen.",
            .continueOfferWatchAd: "Werbung ansehen",
            .continueOfferContinue: "Fortsetzen",
            .continueOfferDecline: "Runde beenden",
            .dailyHintRewardToast: "+1 Hinweis fuer einen neuen Tag",
            .tutorialTitle: "So spielst du",
            .tutorialPickTile: "Vergleiche die Buchstaben mit den Zahlen darunter: dieselbe Zahl steht immer fuer denselben Buchstaben. Tippe auf das markierte Feld.",
            .tutorialEnterLetter: "Waehle jetzt auf der Tastatur den Buchstaben fuer diese Zahl.",
            .tutorialHintButton: "Wenn du den Buchstaben nicht findest, tippe auf Hinweis.",
            .tutorialHintTile: "Der Hinweis ist aktiv. Tippe auf das markierte Feld, um einen Buchstaben aufzudecken.",
            .tutorialCompleted: "Super. Jetzt loese den Rest der Phrase selbst.",
            .languageSystem: "System",
            .themeSystem: "System",
            .themeLight: "Hell",
            .themeDark: "Dunkel",
            .purchaseUnavailableStatus: "Der Kauf ist derzeit nicht verfuegbar.",
            .purchaseVerificationFailedStatus: "Der Kauf konnte nicht bestaetigt werden.",
            .purchaseAdsRemovedStatus: "Werbung deaktiviert.",
            .purchaseCompletedStatus: "Kauf abgeschlossen.",
            .purchasePendingStatus: "Der Kauf wartet auf Bestaetigung.",
            .purchaseCancelledStatus: "Kauf abgebrochen.",
            .purchaseUnknownStatus: "Unbekanntes Kaufergebnis.",
            .purchaseFailedStatus: "Der Kauf konnte nicht abgeschlossen werden.",
            .purchaseRestoredStatus: "Kauf wiederhergestellt.",
            .purchaseNotFoundStatus: "Keine Kaeufe gefunden.",
            .purchaseRestoreFailedStatus: "Kaeufe konnten nicht wiederhergestellt werden.",
            .purchaseLoadFailedStatus: "Kaufinformationen konnten nicht geladen werden.",
            .purchaseBoughtShort: "Gekauft",
            .purchaseLoadingShort: "Laedt...",
            .purchaseUnavailableShort: "Nicht verfuegbar"
        ],
        .fr: [
            .settingsTitle: "Reglages",
            .languageTitle: "Langue",
            .themeTitle: "Theme",
            .purchasesTitle: "Achats",
            .globalStatsTitle: "Statistiques globales",
            .removeAdsTitle: "Supprimer la pub pour toujours",
            .purchaseOwnedDescription: "Cet achat est actif pour cet identifiant Apple.",
            .purchaseLoadingDescription: "Chargement des informations d achat.",
            .purchaseUnavailableDescription: "L achat est indisponible pour le moment.",
            .purchaseMainDescription: "La publicite disparaitra apres l achat.",
            .purchaseActiveButton: "Actif",
            .purchaseBuyButton: "Acheter",
            .purchaseRestoreButton: "Restaurer",
            .roundsCompleted: "Manches terminees",
            .wins: "Victoires",
            .losses: "Defaites",
            .winRate: "Taux de victoire",
            .avgMistakes: "Erreurs moyennes par manche",
            .avgRoundTime: "Temps moyen d une manche",
            .bestWin: "Meilleure victoire",
            .avgHints: "Indices moyens par manche",
            .resetButton: "Recommencer",
            .resetHint: "Reinitialise la progression, le theme et toutes les statistiques. L achat sans pub est conserve.",
            .resetDialogTitle: "Recommencer ?",
            .resetDialogButton: "Reinitialiser progression, theme et statistiques",
            .cancelButton: "Annuler",
            .resetDialogMessage: "Le jeu repartira de la premiere phrase, le theme reviendra au systeme et les statistiques seront reinitialisees.",
            .completedTitle: "Termine",
            .openedTitle: "Ouvert",
            .mistakesTitle: "Erreurs",
            .settingsAccessibilityLabel: "Reglages",
            .authorTitle: "Auteur",
            .roundSolved: "Phrase resolue",
            .roundLost: "Trois erreurs",
            .nextButton: "Suivant",
            .hintButton: "Indice",
            .continueOfferTitle: "Derniere chance",
            .continueOfferMessage: "Vous avez fait la derniere erreur. Vous pouvez regarder une courte publicite et continuer cette phrase.",
            .continueOfferWatchAd: "Voir la pub",
            .continueOfferContinue: "Continuer",
            .continueOfferDecline: "Terminer la manche",
            .dailyHintRewardToast: "+1 indice pour un nouveau jour",
            .tutorialTitle: "Comment jouer",
            .tutorialPickTile: "Compare les lettres avec les chiffres en dessous : le meme chiffre correspond toujours a la meme lettre. Touchez la case mise en evidence.",
            .tutorialEnterLetter: "Choisissez maintenant sur le clavier la lettre pour ce chiffre.",
            .tutorialHintButton: "Si vous ne trouvez pas la lettre, touchez Indice.",
            .tutorialHintTile: "L indice est actif. Touchez la case mise en evidence pour reveler une lettre.",
            .tutorialCompleted: "Parfait. Continuez la phrase vous-meme.",
            .languageSystem: "Systeme",
            .themeSystem: "Systeme",
            .themeLight: "Clair",
            .themeDark: "Sombre",
            .purchaseUnavailableStatus: "L achat est indisponible pour le moment.",
            .purchaseVerificationFailedStatus: "Impossible de verifier l achat.",
            .purchaseAdsRemovedStatus: "Publicite desactivee.",
            .purchaseCompletedStatus: "Achat termine.",
            .purchasePendingStatus: "L achat attend une confirmation.",
            .purchaseCancelledStatus: "Achat annule.",
            .purchaseUnknownStatus: "Resultat d achat inconnu.",
            .purchaseFailedStatus: "Impossible de terminer l achat.",
            .purchaseRestoredStatus: "Achat restaure.",
            .purchaseNotFoundStatus: "Aucun achat trouve.",
            .purchaseRestoreFailedStatus: "Impossible de restaurer les achats.",
            .purchaseLoadFailedStatus: "Impossible de charger les informations d achat.",
            .purchaseBoughtShort: "Achete",
            .purchaseLoadingShort: "Chargement...",
            .purchaseUnavailableShort: "Indisponible"
        ],
        .it: [
            .settingsTitle: "Impostazioni",
            .languageTitle: "Lingua",
            .themeTitle: "Tema",
            .purchasesTitle: "Acquisti",
            .globalStatsTitle: "Statistiche globali",
            .removeAdsTitle: "Rimuovi la pubblicita per sempre",
            .purchaseOwnedDescription: "Questo acquisto e attivo per questo Apple ID.",
            .purchaseLoadingDescription: "Caricamento delle informazioni di acquisto.",
            .purchaseUnavailableDescription: "L acquisto non e disponibile al momento.",
            .purchaseMainDescription: "Dopo l acquisto la pubblicita non verra piu mostrata.",
            .purchaseActiveButton: "Attivo",
            .purchaseBuyButton: "Acquista",
            .purchaseRestoreButton: "Ripristina",
            .roundsCompleted: "Round completati",
            .wins: "Vittorie",
            .losses: "Sconfitte",
            .winRate: "Percentuale di vittorie",
            .avgMistakes: "Errori medi per round",
            .avgRoundTime: "Tempo medio del round",
            .bestWin: "Migliore vittoria",
            .avgHints: "Suggerimenti medi per round",
            .resetButton: "Ricomincia",
            .resetHint: "Azzera progresso, tema e tutte le statistiche. L acquisto per rimuovere la pubblicita viene mantenuto.",
            .resetDialogTitle: "Ricominciare?",
            .resetDialogButton: "Azzera progresso, tema e statistiche",
            .cancelButton: "Annulla",
            .resetDialogMessage: "Il gioco ripartira dalla prima frase, il tema tornera a quello di sistema e le statistiche saranno azzerate.",
            .completedTitle: "Completato",
            .openedTitle: "Aperto",
            .mistakesTitle: "Errori",
            .settingsAccessibilityLabel: "Impostazioni",
            .authorTitle: "Autore",
            .roundSolved: "Frase risolta",
            .roundLost: "Tre errori",
            .nextButton: "Avanti",
            .hintButton: "Suggerimento",
            .continueOfferTitle: "Ultima possibilita",
            .continueOfferMessage: "Hai fatto l ultimo errore. Puoi guardare una breve pubblicita e continuare questa frase.",
            .continueOfferWatchAd: "Guarda la pubblicita",
            .continueOfferContinue: "Continua",
            .continueOfferDecline: "Termina round",
            .dailyHintRewardToast: "+1 suggerimento per un nuovo giorno",
            .tutorialTitle: "Come si gioca",
            .tutorialPickTile: "Confronta le lettere con i numeri sotto di loro: lo stesso numero indica sempre la stessa lettera. Tocca la casella evidenziata.",
            .tutorialEnterLetter: "Adesso scegli sulla tastiera la lettera per questo numero.",
            .tutorialHintButton: "Se non trovi la lettera, tocca Suggerimento.",
            .tutorialHintTile: "Il suggerimento e attivo. Tocca la casella evidenziata per aprire una lettera.",
            .tutorialCompleted: "Perfetto. Ora completa la frase da solo.",
            .languageSystem: "Sistema",
            .themeSystem: "Sistema",
            .themeLight: "Chiaro",
            .themeDark: "Scuro",
            .purchaseUnavailableStatus: "L acquisto non e disponibile al momento.",
            .purchaseVerificationFailedStatus: "Impossibile verificare l acquisto.",
            .purchaseAdsRemovedStatus: "Pubblicita disattivata.",
            .purchaseCompletedStatus: "Acquisto completato.",
            .purchasePendingStatus: "L acquisto e in attesa di conferma.",
            .purchaseCancelledStatus: "Acquisto annullato.",
            .purchaseUnknownStatus: "Risultato acquisto sconosciuto.",
            .purchaseFailedStatus: "Impossibile completare l acquisto.",
            .purchaseRestoredStatus: "Acquisto ripristinato.",
            .purchaseNotFoundStatus: "Nessun acquisto trovato.",
            .purchaseRestoreFailedStatus: "Impossibile ripristinare gli acquisti.",
            .purchaseLoadFailedStatus: "Impossibile caricare le informazioni di acquisto.",
            .purchaseBoughtShort: "Acquistato",
            .purchaseLoadingShort: "Caricamento...",
            .purchaseUnavailableShort: "Non disponibile"
        ],
        .pt: [
            .settingsTitle: "Definicoes",
            .languageTitle: "Idioma",
            .themeTitle: "Tema",
            .purchasesTitle: "Compras",
            .globalStatsTitle: "Estatisticas globais",
            .removeAdsTitle: "Remover anuncios para sempre",
            .purchaseOwnedDescription: "Esta compra esta ativa para este Apple ID.",
            .purchaseLoadingDescription: "A carregar informacoes da compra.",
            .purchaseUnavailableDescription: "A compra nao esta disponivel no momento.",
            .purchaseMainDescription: "Depois da compra os anuncios deixam de aparecer.",
            .purchaseActiveButton: "Ativo",
            .purchaseBuyButton: "Comprar",
            .purchaseRestoreButton: "Restaurar",
            .roundsCompleted: "Rondas concluidas",
            .wins: "Vitorias",
            .losses: "Derrotas",
            .winRate: "Percentagem de vitorias",
            .avgMistakes: "Erros medios por ronda",
            .avgRoundTime: "Tempo medio por ronda",
            .bestWin: "Melhor vitoria",
            .avgHints: "Dicas medias por ronda",
            .resetButton: "Recomecar",
            .resetHint: "Reinicia o progresso, o tema e todas as estatisticas. A compra sem anuncios sera mantida.",
            .resetDialogTitle: "Recomecar?",
            .resetDialogButton: "Reiniciar progresso, tema e estatisticas",
            .cancelButton: "Cancelar",
            .resetDialogMessage: "O jogo comecara na primeira frase, o tema voltara ao sistema e as estatisticas serao reiniciadas.",
            .completedTitle: "Concluido",
            .openedTitle: "Abertas",
            .mistakesTitle: "Erros",
            .settingsAccessibilityLabel: "Definicoes",
            .authorTitle: "Autor",
            .roundSolved: "Frase resolvida",
            .roundLost: "Tres erros",
            .nextButton: "Seguinte",
            .hintButton: "Dica",
            .continueOfferTitle: "Ultima chance",
            .continueOfferMessage: "Voce cometeu o ultimo erro. Pode ver um anuncio curto e continuar esta frase.",
            .continueOfferWatchAd: "Ver anuncio",
            .continueOfferContinue: "Continuar",
            .continueOfferDecline: "Terminar ronda",
            .dailyHintRewardToast: "+1 dica por um novo dia",
            .tutorialTitle: "Como jogar",
            .tutorialPickTile: "Compara as letras com os numeros por baixo: o mesmo numero representa sempre a mesma letra. Toca na casa destacada.",
            .tutorialEnterLetter: "Agora escolhe no teclado a letra para esse numero.",
            .tutorialHintButton: "Se nao encontrares a letra, toca em Dica.",
            .tutorialHintTile: "A dica esta ativa. Toca na casa destacada para revelar uma letra.",
            .tutorialCompleted: "Perfeito. Agora termina a frase sozinho.",
            .languageSystem: "Sistema",
            .themeSystem: "Sistema",
            .themeLight: "Claro",
            .themeDark: "Escuro",
            .purchaseUnavailableStatus: "A compra nao esta disponivel no momento.",
            .purchaseVerificationFailedStatus: "Nao foi possivel verificar a compra.",
            .purchaseAdsRemovedStatus: "Anuncios desativados.",
            .purchaseCompletedStatus: "Compra concluida.",
            .purchasePendingStatus: "A compra aguarda confirmacao.",
            .purchaseCancelledStatus: "Compra cancelada.",
            .purchaseUnknownStatus: "Resultado de compra desconhecido.",
            .purchaseFailedStatus: "Nao foi possivel concluir a compra.",
            .purchaseRestoredStatus: "Compra restaurada.",
            .purchaseNotFoundStatus: "Nenhuma compra encontrada.",
            .purchaseRestoreFailedStatus: "Nao foi possivel restaurar as compras.",
            .purchaseLoadFailedStatus: "Nao foi possivel carregar as informacoes da compra.",
            .purchaseBoughtShort: "Comprado",
            .purchaseLoadingShort: "A carregar...",
            .purchaseUnavailableShort: "Indisponivel"
        ]
    ]
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
