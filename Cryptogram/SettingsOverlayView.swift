import SwiftUI

struct SettingsOverlayView: View {
    let language: AppLanguage
    let selectedLanguage: AppLanguage
    let theme: AppTheme
    let stats: GlobalStatsSnapshot
    @ObservedObject var purchaseManager: PurchaseManager
    let onSelectLanguage: (AppLanguage) -> Void
    let onSelectTheme: (AppTheme) -> Void
    let onPurchase: () async -> Void
    let onRestore: () async -> Void
    let onReset: () -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)

                VStack(spacing: 14) {
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            languageCard
                            themeCard
                            purchaseCard
                            statsCard
                            resetButton
                            resetHint
                        }
                    }
                }
                .padding(16)
                .frame(width: min(max(geometry.size.width - 24, 280), 460))
                .frame(maxHeight: max(geometry.size.height - 32, 320))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
                .padding(.horizontal, 12)
            }
        }
        .transition(.opacity)
        .zIndex(10)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(language.text(.settingsTitle))
                .font(.headline)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var languageCard: some View {
        settingsCard(title: language.text(.languageTitle)) {
            VStack(spacing: 0) {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, item in
                    languageOptionRow(item)

                    if index < AppLanguage.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
    }

    private var themeCard: some View {
        settingsCard(title: language.text(.themeTitle)) {
            VStack(spacing: 0) {
                ForEach(Array(AppTheme.allCases.enumerated()), id: \.element) { index, item in
                    themeOptionRow(item)

                    if index < AppTheme.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
    }

    private var purchaseCard: some View {
        settingsCard(title: language.text(.purchasesTitle)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.text(.removeAdsTitle))
                            .font(.subheadline.weight(.semibold))

                        Text(purchaseDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Text(purchasePriceText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(purchaseManager.isAdsRemoved ? Color.green : Color.secondary)
                }

                if let statusMessage = purchaseStatusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await onPurchase()
                        }
                    } label: {
                        Text(purchaseManager.isAdsRemoved ? language.text(.purchaseActiveButton) : language.text(.purchaseBuyButton))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(purchaseManager.canPurchase ? Color.accentColor : Color.secondary.opacity(0.18))
                            )
                            .foregroundStyle(purchaseManager.canPurchase ? Color.white : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!purchaseManager.canPurchase)

                    Button {
                        Task {
                            await onRestore()
                        }
                    } label: {
                        Text(language.text(.purchaseRestoreButton))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.primary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!purchaseManager.canRestore)
                }
            }
        }
    }

    private var statsCard: some View {
        settingsCard(title: language.text(.globalStatsTitle)) {
            VStack(spacing: 10) {
                settingsValueRow(title: language.text(.roundsCompleted), value: "\(stats.totalRounds)")
                settingsValueRow(title: language.text(.wins), value: "\(stats.totalPassedRounds)")
                settingsValueRow(title: language.text(.losses), value: "\(stats.lostRoundsCount)")
                settingsValueRow(title: language.text(.winRate), value: stats.winRateText)
                settingsValueRow(title: language.text(.avgMistakes), value: stats.averageMistakesText)
                settingsValueRow(title: language.text(.avgRoundTime), value: stats.averageRoundTimeText)
                settingsValueRow(title: language.text(.bestWin), value: stats.bestPassedTimeText)
                settingsValueRow(title: language.text(.avgHints), value: stats.averageHintsText)
            }
        }
    }

    private var resetButton: some View {
        Button(language.text(.resetButton), role: .destructive, action: onReset)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
    }

    private var resetHint: some View {
        Text(language.text(.resetHint))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purchaseDescription: String {
        if purchaseManager.isAdsRemoved {
            return language.text(.purchaseOwnedDescription)
        }

        if purchaseManager.isLoadingProducts {
            return language.text(.purchaseLoadingDescription)
        }

        if purchaseManager.removeAdsProduct == nil {
            return language.text(.purchaseUnavailableDescription)
        }

        return language.text(.purchaseMainDescription)
    }

    private var purchasePriceText: String {
        if purchaseManager.isAdsRemoved {
            return language.text(.purchaseBoughtShort)
        }

        if let displayPrice = purchaseManager.displayPrice {
            return displayPrice
        }

        return purchaseManager.isLoadingProducts
            ? language.text(.purchaseLoadingShort)
            : language.text(.purchaseUnavailableShort)
    }

    private var purchaseStatusMessage: String? {
        switch purchaseManager.status {
        case .idle:
            return nil
        case .unavailable:
            return language.text(.purchaseUnavailableStatus)
        case .verificationFailed:
            return language.text(.purchaseVerificationFailedStatus)
        case .adsRemoved:
            return language.text(.purchaseAdsRemovedStatus)
        case .purchaseCompleted:
            return language.text(.purchaseCompletedStatus)
        case .pending:
            return language.text(.purchasePendingStatus)
        case .cancelled:
            return language.text(.purchaseCancelledStatus)
        case .unknown:
            return language.text(.purchaseUnknownStatus)
        case .purchaseFailed:
            return language.text(.purchaseFailedStatus)
        case .restored:
            return language.text(.purchaseRestoredStatus)
        case .notFound:
            return language.text(.purchaseNotFoundStatus)
        case .restoreFailed:
            return language.text(.purchaseRestoreFailedStatus)
        case .loadFailed:
            return language.text(.purchaseLoadFailedStatus)
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func languageOptionRow(_ item: AppLanguage) -> some View {
        Button {
            onSelectLanguage(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item == .system ? "iphone.gen3" : "globe")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 20)
                    .foregroundStyle(selectedLanguage == item ? Color.accentColor : Color.secondary)

                Text(item.localizedTitle(in: language))
                    .font(.subheadline)

                Spacer(minLength: 0)

                if selectedLanguage == item {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func themeOptionRow(_ item: AppTheme) -> some View {
        Button {
            onSelectTheme(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 20)
                    .foregroundStyle(theme == item ? Color.accentColor : Color.secondary)

                Text(item.localizedTitle(in: language))
                    .font(.subheadline)

                Spacer(minLength: 0)

                if theme == item {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsValueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
