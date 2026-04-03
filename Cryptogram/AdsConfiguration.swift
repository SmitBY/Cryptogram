import Foundation

enum RewardedAdPlacement {
    case hint
    case continueAfterMistake
}

enum InterstitialAdPlacement {
    case levelCompletion
}

enum AdsConfiguration {
    enum AdMob {
        // Fill these values when the SDK is connected.
        static let applicationID = ""
        static let usesTestAds = true
    }

    enum Rewarded {
        static let hintUnitID = ""
        static let continueAfterMistakeUnitID = ""

        static func unitID(for placement: RewardedAdPlacement) -> String {
            switch placement {
            case .hint:
                return hintUnitID
            case .continueAfterMistake:
                return continueAfterMistakeUnitID
            }
        }

        static func simulatedPresentationDelayNanoseconds(for placement: RewardedAdPlacement) -> UInt64 {
            switch placement {
            case .hint, .continueAfterMistake:
                return 1_000_000_000
            }
        }
    }

    enum Interstitial {
        static let firstCompletedLevelNumberForAutomaticAd = 10
        static let levelCompletionUnitID = ""

        static func unitID(for placement: InterstitialAdPlacement) -> String {
            switch placement {
            case .levelCompletion:
                return levelCompletionUnitID
            }
        }

        static func shouldShowAfterCompletingLevel(_ levelNumber: Int) -> Bool {
            levelNumber >= firstCompletedLevelNumberForAutomaticAd
        }

        static func simulatedPresentationDelayNanoseconds(for placement: InterstitialAdPlacement) -> UInt64 {
            switch placement {
            case .levelCompletion:
                return 1_500_000_000
            }
        }
    }
}
