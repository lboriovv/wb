import SwiftUI
import UIKit
import WebKit

struct ESIMScreen: View {
    var onBack: () -> Void = {}

    @State private var catalogMode: ESIMCatalogMode = .countries
    @State private var selectedOffer: ESIMOffer?
    @State private var searchText = ""
    @State private var isSearchMode = false
    @State private var isGlobePaused = false
    @State private var searchListSpread: CGFloat = 0
    @State private var searchMotionGeneration = 0
    @State private var flowStep: ESIMFlowStep = .selection
    @State private var duration: ESIMDuration = .oneDay
    @State private var planIndex = 1
    @FocusState private var isSearchFocused: Bool

    private let focusedGlobeOffset: CGFloat = 92
    private let idleGlobeOuterOffset: CGFloat = -42
    private let focusedGlobeOuterOffset: CGFloat = -80
    private let sheetTop: CGFloat = 390
    private let contentPanelHeight: CGFloat = 620
    private let topBarHeight: CGFloat = 96
    private let uiTransition = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.58)
    private let microTransition = Animation.easeInOut(duration: 0.2)
    private let searchListSettleDelay = 0.48
    private let searchGlobePauseDelay = 0.56
    private let globeFocusTransition = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.82)

    private let countries = ESIMCatalog.countries
    private let regions = ESIMCatalog.regions

    private var visibleOffers: [ESIMOffer] {
        let offers: [ESIMOffer] = switch catalogMode {
        case .countries:
            countries.map(ESIMOffer.country)
        case .regions:
            regions.map(ESIMOffer.region)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return offers }
        return offers.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var popularOffers: [ESIMOffer] {
        switch catalogMode {
        case .countries:
            ["TUR", "THA", "ARE", "EGY", "CHN"].compactMap { id in
                countries.first(where: { $0.id == id }).map(ESIMOffer.country)
            }
        case .regions:
            Array(regions.prefix(2)).map(ESIMOffer.region)
        }
    }

    private var isTariffStep: Bool { flowStep == .tariff }

    private var globeOuterOffset: CGFloat {
        return selectedOffer == nil
            ? idleGlobeOuterOffset
            : focusedGlobeOuterOffset
    }

    private var selectedPlan: ESIMTariffPlan {
        let plans = duration.plans
        return plans[min(planIndex, plans.count - 1)]
    }

    var body: some View {
        Group {
            switch flowStep {
            case .selection, .tariff:
                globeFlow
                    .transition(.opacity)
            case .payment:
                paymentScreen
                    .transition(.move(edge: .trailing))
            case .success:
                successScreen
                    .transition(.opacity)
            }
        }
    }

    private var globeFlow: some View {
        GeometryReader { proxy in
            let cornerRadius = WBRadius.x6
            let restingTop = min(sheetTop, proxy.size.height - 320)
            let stageHeight = restingTop + cornerRadius
            let panelHeight = min(contentPanelHeight, proxy.size.height)
            let currentTop = isSearchMode ? 0 : proxy.size.height - panelHeight
            let listHeight = isSearchMode ? proxy.size.height : panelHeight
            let contentTopInset = isSearchMode
                ? topBarHeight + WBSpace.x4
                : WBSpace.x4

            ZStack(alignment: .top) {
                Color(hex: 0xEEE5FF)
                    .ignoresSafeArea()

                globeStage(height: stageHeight)
                    .frame(height: stageHeight)
                    .offset(y: globeOuterOffset)
                    .animation(globeFocusTransition, value: selectedOffer?.id)
                    .zIndex(0)

                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        countryList(contentTopInset: contentTopInset)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .offset(x: isTariffStep ? -proxy.size.width : 0)
                            .allowsHitTesting(!isTariffStep)

                        tariffPanel
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .offset(x: isTariffStep ? 0 : proxy.size.width)
                            .allowsHitTesting(isTariffStep)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if selectedOffer != nil && !isSearchMode {
                        PipFigmaStickyBar(
                            type: .default,
                            title: "Продолжить",
                            showsProgress: false,
                            onContinue: isTariffStep ? showPayment : continueFlow
                        )
                        .frame(maxWidth: .infinity)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                    .frame(
                        width: proxy.size.width,
                        height: listHeight,
                        alignment: .top
                    )
                    .background {
                        PipTopCornersShape(radius: isSearchMode ? 0 : WBRadius.x6)
                            .fill(WBColor.bgBase)
                    }
                    .clipShape(PipTopCornersShape(radius: isSearchMode ? 0 : WBRadius.x6))
                    .offset(y: currentTop)
                    .zIndex(1)

                stageChrome
                    .frame(height: topBarHeight, alignment: .top)
                    .background(isSearchMode ? WBColor.bgBase : .clear)
                    .zIndex(2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(uiTransition, value: isSearchMode)
            .animation(uiTransition, value: flowStep)
        }
        .ignoresSafeArea()
    }

    private func globeStage(height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Color(hex: 0xEEE5FF)
                .ignoresSafeArea(edges: .top)

            ESIMGlobeWebView(
                countries: countries,
                selectedOffer: selectedOffer,
                showsTooltip: true,
                showsTooltipSubtitle: !isTariffStep,
                tooltipScale: 1,
                stageOffsetY: selectedOffer == nil ? 0 : focusedGlobeOffset,
                isPaused: isGlobePaused,
                onSelectCountry: selectCountry
            )
            .frame(height: height)
            .padding(.horizontal, -10)
            .animation(uiTransition, value: flowStep)
        }
        .frame(height: height, alignment: .top)
        .clipped()
    }

    private var stageChrome: some View {
        PipFigmaTop(
            type: .provider,
            showsScanButton: false,
            titleText: nil,
            theme: .telecom,
            showsBackButton: isTariffStep || isSearchMode,
            showsCloseButton: true,
            showsBackground: false,
            showsTitle: false,
            onBack: handleStageBack,
            onClose: onBack
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func countryList(contentTopInset: CGFloat) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: WBSpace.x3) {
                    searchField

                    catalogTabs
                        .offset(y: searchCatchUpOffset(depth: 1))

                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        sectionTitle("Популярные")
                            .padding(.top, WBSpace.x3)
                            .offset(y: searchCatchUpOffset(depth: 2))

                        ScrollView(.horizontal) {
                            HStack(spacing: WBSpace.x1) {
                                ForEach(Array(popularOffers.enumerated()), id: \.element.id) { index, offer in
                                    popularOffer(offer)
                                        .offset(y: searchCatchUpOffset(depth: 3 + index))
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .scrollClipDisabled()
                        .contentMargins(.horizontal, WBSpace.x4, for: .scrollContent)
                        .padding(.horizontal, -WBSpace.x4)
                    }

                    sectionTitle(catalogMode.title)
                        .padding(.top, WBSpace.x3)
                        .offset(y: searchCatchUpOffset(depth: 5))

                    if visibleOffers.isEmpty {
                        Text("Ничего не найдено")
                            .font(WBFont.body)
                            .foregroundStyle(WBColor.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .offset(y: searchCatchUpOffset(depth: 6))
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(visibleOffers.enumerated()), id: \.element.id) { index, offer in
                                offerRow(offer)
                                    .offset(y: searchCatchUpOffset(depth: 6 + index))
                            }
                        }
                        .transition(.opacity)
                    }
            }
            .padding(.horizontal, WBSpace.x4)
            .padding(.bottom, WBSpace.x4)
            .padding(.top, contentTopInset)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.never)
        .animation(microTransition, value: selectedOffer?.id)
    }

    private var searchField: some View {
        HStack(spacing: WBSpace.x2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(WBColor.controlsTertiary)
                .frame(width: 20, height: 20)

            TextField("Поиск", text: $searchText)
                .textFieldStyle(.plain)
                .font(WBFont.body)
                .foregroundStyle(WBColor.textPrimary)
                .tint(WBColor.textAccent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onChange(of: isSearchFocused) { _, isFocused in
                    guard isFocused else { return }
                    activateSearch()
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(WBColor.controlsTertiary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, WBSpace.x3)
        .frame(height: 44)
        .background(
            WBColor.bgMinus1,
            in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
        )
    }

    private var catalogTabs: some View {
        HStack(spacing: 0) {
            ForEach(ESIMCatalogMode.allCases) { mode in
                let isSelected = catalogMode == mode

                Button {
                    guard catalogMode != mode else { return }
                    Haptics.tap()
                    catalogMode = mode
                    clearSelection()
                } label: {
                    Text(mode.tabTitle)
                        .font(WBFont.body)
                        .foregroundStyle(WBColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? WBColor.bgBase : .clear)
                                .shadow(
                                    color: isSelected ? .black.opacity(0.07) : .clear,
                                    radius: 6,
                                    x: 0,
                                    y: 4
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(WBSpace.x0_5)
        .frame(height: 40)
        .background(
            WBColor.bgMinus1,
            in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
        )
        .animation(microTransition, value: catalogMode)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(WBFont.hauss(19, .semibold))
            .foregroundStyle(WBColor.textPrimary)
            .frame(height: 23)
    }

    private func popularOffer(_ offer: ESIMOffer) -> some View {
        Button {
            selectOffer(offer)
        } label: {
            HStack(spacing: WBSpace.x2) {
                Text(offer.title)
                    .font(WBFont.descriptionAccent)
                    .foregroundStyle(WBColor.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                offerIcon(offer, size: 32)
            }
            .padding(.horizontal, WBSpace.x3)
            .frame(width: 172)
            .frame(height: 58)
            .background(
                WBColor.bgMinus1,
                in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func offerRow(_ offer: ESIMOffer) -> some View {
        Button {
            selectOffer(offer)
        } label: {
            HStack(spacing: WBSpace.x4) {
                offerIcon(offer, size: 40)

                Text(offer.title)
                    .font(WBFont.hauss(17, .regular))
                    .foregroundStyle(WBColor.textPrimary)

                Spacer(minLength: 0)

                if selectedOffer?.id == offer.id {
                    Image("icCheckmark24")
                        .resizable()
                        .frame(width: 16.962, height: 12.523)
                        .frame(width: 24, height: 24)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(microTransition, value: selectedOffer?.id)
    }

    @ViewBuilder
    private func offerIcon(_ offer: ESIMOffer, size: CGFloat) -> some View {
        switch offer {
        case .country(let country):
            Image(country.flagAsset)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
                .accessibilityHidden(true)
        case .region:
            RowIconView(icon: .placeholder, size: size)
        }
    }

    private func selectCountry(_ country: ESIMCountry) {
        catalogMode = .countries
        selectedOffer = .country(country)
    }

    private func selectOffer(_ offer: ESIMOffer) {
        guard isSearchMode else {
            selectedOffer = offer
            return
        }

        searchMotionGeneration += 1
        searchListSpread = 0
        selectedOffer = offer
        isSearchFocused = false
        isGlobePaused = false
        isSearchMode = false
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            flowStep = .tariff
        }
    }

    private func continueFlow() {
        guard selectedOffer != nil else { return }
        Haptics.tap()
        isSearchFocused = false
        withAnimation(uiTransition) {
            flowStep = .tariff
        }
    }

    private func clearSelection() {
        selectedOffer = nil
    }

    private func activateSearch() {
        guard !isSearchMode, flowStep == .selection else { return }

        searchMotionGeneration += 1
        let generation = searchMotionGeneration
        withAnimation(uiTransition) {
            isSearchMode = true
            searchListSpread = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + searchListSettleDelay) {
            guard generation == searchMotionGeneration, isSearchMode else { return }
            withAnimation(uiTransition) {
                searchListSpread = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + searchGlobePauseDelay) {
            guard generation == searchMotionGeneration, isSearchMode else { return }
            isGlobePaused = true
        }
    }

    private func searchCatchUpOffset(depth: Int) -> CGFloat {
        guard isSearchMode else { return 0 }

        let clampedDepth = CGFloat(min(max(depth, 1), 10))
        let graduatedLag = 4.5 * clampedDepth + 0.4 * clampedDepth * clampedDepth
        return graduatedLag * searchListSpread
    }

    private func returnToSelection() {
        Haptics.tap()
        withAnimation(uiTransition) {
            flowStep = .selection
        }
    }

    private func handleStageBack() {
        guard isSearchMode else {
            returnToSelection()
            return
        }

        Haptics.tap()
        isSearchFocused = false
        searchText = ""
        searchMotionGeneration += 1
        isGlobePaused = false
        withAnimation(uiTransition) {
            isSearchMode = false
            searchListSpread = 0
        }
    }

    private var tariffPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            durationChips

            ESIMPlanSelector(
                plans: duration.plans,
                selection: $planIndex
            )
            .padding(.top, 44)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, WBSpace.x4)
        .padding(.top, WBSpace.x4)
        .padding(.bottom, WBSpace.x4)
    }

    private var durationChips: some View {
        HStack(spacing: WBSpace.x2) {
            ForEach(ESIMDuration.allCases) { item in
                Button {
                    guard duration != item else { return }
                    Haptics.tap()
                    duration = item
                    planIndex = item.plans.count / 2
                } label: {
                    let isSelected = duration == item

                    Text(item.title)
                        .font(WBFont.body)
                        .foregroundStyle(isSelected ? Color(hex: 0xF6F6F9) : WBColor.textPrimary)
                        .padding(.horizontal, WBSpace.x3)
                        .frame(height: 38)
                        .background(
                            isSelected ? WBColor.ctaFill : WBColor.bgMinus1,
                            in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
                        )
                        .animation(microTransition, value: isSelected)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func showPayment() {
        Haptics.tap()
        withAnimation(uiTransition) {
            flowStep = .payment
        }
    }

    @ViewBuilder
    private var paymentScreen: some View {
        if let offer = selectedOffer {
            UniQRScreen(
                onBack: {
                    withAnimation(uiTransition) {
                        flowStep = .tariff
                    }
                },
                bonusAnimationStyle: .gainFromTop,
                configuration: .esim(
                    amount: selectedPlan.price,
                    destination: offer.title,
                    subtitle: selectedPlan.purchaseDescription(for: duration),
                    flagAsset: offer.flagAsset
                ),
                onPay: {
                    withAnimation(uiTransition) {
                        flowStep = .success
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var successScreen: some View {
        if let offer = selectedOffer {
            OutcomeScreen(
                scenario: OutcomeScenario(
                    id: "esim-success",
                    demoName: "eSIM",
                    outcome: .success,
                    source: TransferModes.qr,
                    loaderDuration: 1.25,
                    amount: Decimal(selectedPlan.price),
                    badge: nil,
                    override: SuccessConfig(
                        title: "Оплата выполнена",
                        subtitle: "С WB Кошелька",
                        icon: offer.outcomeIcon,
                        counterparty: offer.title,
                        chip: selectedPlan.purchaseDescription(for: duration)
                    ),
                    loaderTitle: "Оплачиваем eSIM",
                    resultTitle: "Оплата выполнена"
                ),
                amount: Decimal(selectedPlan.price),
                badge: nil,
                onClose: onBack
            )
        }
    }
}

private enum ESIMFlowStep {
    case selection
    case tariff
    case payment
    case success
}

private enum ESIMCatalogMode: String, CaseIterable, Identifiable {
    case countries
    case regions

    var id: String { rawValue }

    var tabTitle: String {
        switch self {
        case .countries: "Страна"
        case .regions: "Регион"
        }
    }

    var title: String {
        switch self {
        case .countries: "Все страны"
        case .regions: "Все регионы"
        }
    }
}

private struct ESIMCountry: Identifiable {
    let id: String
    let title: String
    let region: String
    let continent: String
    let pricePerGB: Int
    let lat: Double
    let lng: Double
    let flagCode: String
    let sticker: String

    var priceLabel: String {
        "1 Гб от \(pricePerGB) ₽"
    }

    var subtitle: String {
        "\(region) · \(priceLabel)"
    }

    var flagAsset: String {
        "esimFlag\(flagCode.uppercased())"
    }
}

private struct ESIMRegion: Identifiable {
    let id: String
    let title: String
    let continent: String
    let pricePerGB: Int
    let lat: Double
    let lng: Double
    let altitude: Double

    var priceLabel: String {
        "1 Гб от \(pricePerGB) ₽"
    }
}

private enum ESIMOffer: Identifiable {
    case country(ESIMCountry)
    case region(ESIMRegion)

    var id: String {
        switch self {
        case .country(let country): "country:\(country.id)"
        case .region(let region): "region:\(region.id)"
        }
    }

    var title: String {
        switch self {
        case .country(let country): country.title
        case .region(let region): region.title
        }
    }

    var priceLabel: String {
        switch self {
        case .country(let country): country.priceLabel
        case .region(let region): region.priceLabel
        }
    }

    var flagAsset: String? {
        guard case .country(let country) = self else { return nil }
        return country.flagAsset
    }

    var outcomeIcon: RowIcon {
        flagAsset.map(RowIcon.asset) ?? .placeholder
    }
}

private enum ESIMDuration: Int, CaseIterable, Identifiable {
    case oneDay = 1
    case sevenDays = 7
    case thirtyDays = 30

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .oneDay: "1 день"
        case .sevenDays: "7 дней"
        case .thirtyDays: "30 дней"
        }
    }

    var plans: [ESIMTariffPlan] {
        switch self {
        case .oneDay:
            [
                ESIMTariffPlan(gigabytes: 1, price: 290),
                ESIMTariffPlan(gigabytes: 5, price: 990),
                ESIMTariffPlan(gigabytes: 10, price: 1_590),
            ]
        case .sevenDays:
            [
                ESIMTariffPlan(gigabytes: 1, price: 390),
                ESIMTariffPlan(gigabytes: 3, price: 590),
                ESIMTariffPlan(gigabytes: 5, price: 890),
                ESIMTariffPlan(gigabytes: 10, price: 1_490),
                ESIMTariffPlan(gigabytes: 20, price: 2_390),
            ]
        case .thirtyDays:
            [
                ESIMTariffPlan(gigabytes: 10, price: 1_290),
                ESIMTariffPlan(gigabytes: 30, price: 2_990),
                ESIMTariffPlan(gigabytes: 50, price: 4_490),
            ]
        }
    }
}

private struct ESIMTariffPlan: Identifiable, Equatable {
    var id: Int { gigabytes }
    let gigabytes: Int
    let price: Int

    var priceLabel: String {
        "\(price.formatted(.number.grouping(.automatic))) ₽"
    }

    var label: String { "\(gigabytes) Гб" }

    func purchaseDescription(for duration: ESIMDuration) -> String {
        "\(gigabytes) Гб на \(duration.title)"
    }
}

private enum ESIMSliderMetrics {
    // Together with the panel's 16 pt padding these keep the tapered
    // track's visible edges 40 pt from either side of the screen.
    static let leadingInset: CGFloat = 32
    static let trailingInset: CGFloat = 36
}

private struct ESIMBubbleMotionState: Equatable {
    var progress: CGFloat = 0
    var tilt: CGFloat = 0
    var stretch: CGFloat = 0
}

@MainActor
private final class ESIMBubbleMotionModel: NSObject, ObservableObject {
    @Published private(set) var state = ESIMBubbleMotionState()

    private let glide: CGFloat = 0.09
    private let stiffness: CGFloat = 0.16
    private let damping: CGFloat = 0.45
    private let maximumTilt: CGFloat = 8
    private let softTrail: CGFloat = 42
    private let stretchFactor: CGFloat = 0.0005
    private let maximumStretch: CGFloat = 0.04

    private var targetProgress: CGFloat = 0
    private var playProgress: CGFloat = 0
    private var bobX: CGFloat = 0
    private var lagX: CGFloat = 0
    private var velocity: CGFloat = 0
    private var trackWidth: CGFloat = 0
    private var displayLink: CADisplayLink?

    private(set) var isConfigured = false
    private(set) var isScrubbing = false

    deinit {
        displayLink?.invalidate()
    }

    func setTarget(_ progress: CGFloat, trackWidth: CGFloat, animated: Bool) {
        let clampedProgress = min(max(progress, 0), 1)
        let widthChanged = abs(self.trackWidth - trackWidth) > 0.5
        self.trackWidth = trackWidth
        targetProgress = clampedProgress

        if !isConfigured || !animated {
            isConfigured = true
            playProgress = clampedProgress
            bobX = position(for: playProgress)
            lagX = bobX
            velocity = 0
            state = ESIMBubbleMotionState(progress: playProgress)
            stop()
            return
        }

        if widthChanged {
            bobX = position(for: playProgress)
            lagX = bobX
            velocity = 0
        }

        start()
    }

    func scrub(to progress: CGFloat, trackWidth: CGFloat, animated: Bool) {
        let clampedProgress = min(max(progress, 0), 1)
        let widthChanged = abs(self.trackWidth - trackWidth) > 0.5
        self.trackWidth = trackWidth

        guard animated else {
            isScrubbing = true
            setTarget(clampedProgress, trackWidth: trackWidth, animated: false)
            return
        }

        if !isConfigured || widthChanged {
            isConfigured = true
            playProgress = clampedProgress
            bobX = position(for: playProgress)
            lagX = bobX
            velocity = 0
        }

        isScrubbing = true
        targetProgress = clampedProgress
        playProgress = clampedProgress
        bobX = position(for: playProgress)
        state = ESIMBubbleMotionState(
            progress: playProgress,
            tilt: state.tilt,
            stretch: state.stretch
        )
        start()
    }

    func endScrubbing(at progress: CGFloat, trackWidth: CGFloat, animated: Bool) {
        isScrubbing = false
        setTarget(progress, trackWidth: trackWidth, animated: animated)
    }

    @objc private func tick() {
        playProgress += (targetProgress - playProgress) * glide
        if abs(targetProgress - playProgress) < 0.0005 {
            playProgress = targetProgress
        }

        bobX = position(for: playProgress)
        velocity = (velocity + (bobX - lagX) * stiffness) * damping
        lagX += velocity

        let tilt = maximumTilt * tanh((lagX - bobX) / softTrail)
        let stretch = min(abs(velocity) * stretchFactor, maximumStretch)
        state = ESIMBubbleMotionState(
            progress: playProgress,
            tilt: tilt,
            stretch: stretch
        )

        let bobSettled = abs(velocity) < 0.02 && abs(bobX - lagX) < 0.05
        guard playProgress == targetProgress, bobSettled else { return }

        lagX = bobX
        velocity = 0
        state = ESIMBubbleMotionState(progress: targetProgress)
        stop()
    }

    private func position(for progress: CGFloat) -> CGFloat {
        let startX = ESIMSliderMetrics.leadingInset
        let endX = max(startX, trackWidth - ESIMSliderMetrics.trailingInset)
        return startX + (endX - startX) * progress
    }

    private func start() {
        guard displayLink == nil else { return }
        let displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: 60,
            preferred: 60
        )
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    private func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
}

private struct ESIMPlanSelector: View {
    let plans: [ESIMTariffPlan]
    @Binding var selection: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var bubbleMotion = ESIMBubbleMotionModel()

    private var progress: CGFloat {
        guard plans.count > 1 else { return 0 }
        return CGFloat(selection) / CGFloat(plans.count - 1)
    }

    private var planSignature: String {
        plans
            .map { "\($0.gigabytes):\($0.price)" }
            .joined(separator: "|")
    }

    var body: some View {
        GeometryReader { proxy in
            let startX = ESIMSliderMetrics.leadingInset
            let endX = proxy.size.width - ESIMSliderMetrics.trailingInset
            let renderedProgress = bubbleMotion.isConfigured
                ? bubbleMotion.state.progress
                : progress
            let displayedIndex = min(
                max(Int((renderedProgress * CGFloat(max(plans.count - 1, 0))).rounded()), 0),
                plans.count - 1
            )
            let displayedPlan = plans[displayedIndex]
            let anchorX = startX + (endX - startX) * renderedProgress
            let pivot = UnitPoint.bottom
            let horizontalScale = 1 - bubbleMotion.state.stretch * 0.7
            let verticalScale = 1 + bubbleMotion.state.stretch

            ZStack(alignment: .topLeading) {
                ESIMTariffTooltip(plan: displayedPlan)
                    .scaleEffect(
                        x: horizontalScale,
                        y: verticalScale,
                        anchor: pivot
                    )
                    .rotationEffect(
                        .degrees(bubbleMotion.state.tilt),
                        anchor: pivot
                    )
                    .position(x: anchorX, y: 25)

                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    let markerProgress = plans.count > 1
                        ? CGFloat(index) / CGFloat(plans.count - 1)
                        : 0
                    let markerX = startX + (endX - startX) * markerProgress

                    Text(plan.label)
                        .font(WBFont.description)
                        .foregroundStyle(
                            index == displayedIndex
                                ? WBColor.textPrimary
                                : WBColor.textSecondary
                        )
                        .fixedSize()
                        .position(x: markerX, y: 67.5)
                        .animation(.easeInOut(duration: 0.2), value: displayedIndex)
                }

                ESIMTaperedSlider(
                    count: plans.count,
                    selection: $selection,
                    visualProgress: renderedProgress,
                    onScrub: { scrubProgress in
                        bubbleMotion.scrub(
                            to: scrubProgress,
                            trackWidth: proxy.size.width,
                            animated: !reduceMotion
                        )
                    },
                    onScrubEnded: { snappedProgress in
                        bubbleMotion.endScrubbing(
                            at: snappedProgress,
                            trackWidth: proxy.size.width,
                            animated: !reduceMotion
                        )
                    }
                )
                .frame(height: 30)
                .offset(y: 83)
            }
            .onAppear {
                bubbleMotion.setTarget(
                    progress,
                    trackWidth: proxy.size.width,
                    animated: false
                )
            }
            .onChange(of: selection) { _, _ in
                guard !bubbleMotion.isScrubbing else { return }
                bubbleMotion.setTarget(
                    progress,
                    trackWidth: proxy.size.width,
                    animated: !reduceMotion
                )
            }
            .onChange(of: planSignature) { _, _ in
                bubbleMotion.setTarget(
                    progress,
                    trackWidth: proxy.size.width,
                    animated: false
                )
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                bubbleMotion.setTarget(
                    progress,
                    trackWidth: newWidth,
                    animated: false
                )
            }
            .onChange(of: reduceMotion) { _, isReduced in
                bubbleMotion.setTarget(
                    progress,
                    trackWidth: proxy.size.width,
                    animated: !isReduced
                )
            }
        }
        .frame(height: 128)
    }
}

private struct ESIMTariffTooltip: View {
    let plan: ESIMTariffPlan

    private let morphAnimation = Animation.timingCurve(
        0.19,
        1,
        0.22,
        1,
        duration: 0.4
    )

    var body: some View {
        VStack(spacing: 0) {
            ESIMTorphPrice(plan: plan)
                .font(WBFont.hauss(19, .bold))
                .foregroundStyle(WBColor.textPrimary)
                .frame(height: 23, alignment: .center)
                .clipped()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, WBSpace.x2)
                .background(
                    WBColor.bgMinus1,
                    in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
                )

            Image("esimTariffTooltipArrow")
                .resizable()
                .renderingMode(.original)
                .frame(width: 52, height: 11)
        }
        .fixedSize(horizontal: true, vertical: true)
        .animation(morphAnimation, value: plan)
    }
}

private struct ESIMTorphPrice: View {
    let plan: ESIMTariffPlan

    var body: some View {
        Text(plan.priceLabel)
            .contentTransition(
                .numericText(value: Double(plan.price))
            )
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(plan.priceLabel)
    }
}

private struct ESIMTaperedSlider: View {
    let count: Int
    @Binding var selection: Int
    let visualProgress: CGFloat
    let onScrub: (CGFloat) -> Void
    let onScrubEnded: (CGFloat) -> Void

    @State private var isScrubbing = false

    private let scrubThreshold: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let startX = ESIMSliderMetrics.leadingInset
            let endX = proxy.size.width - ESIMSliderMetrics.trailingInset
            let clampedProgress = min(max(visualProgress, 0), 1)
            let activeEndX = startX + (endX - startX) * clampedProgress
            let activeGradient = LinearGradient(
                colors: [Color(hex: 0x985EEA), Color(hex: 0xB48FF2)],
                startPoint: .leading,
                endPoint: UnitPoint(
                    x: activeEndX / max(proxy.size.width, 1),
                    y: 0.5
                )
            )
            ZStack(alignment: .leading) {
                ESIMTaperedTrackShape(progress: 1)
                    .fill(WBColor.bgMinus1)

                ESIMTaperedTrackShape(progress: clampedProgress)
                    .fill(activeGradient)

                ForEach(0..<count, id: \.self) { index in
                    let diameter = markerDiameter(at: index)
                    let markerProgress = count > 1
                        ? CGFloat(index) / CGFloat(count - 1)
                        : 0
                    let markerX = startX + (endX - startX) * markerProgress

                    Circle()
                        .fill(WBColor.bgBase)
                        .frame(width: diameter, height: diameter)
                        .position(x: markerX, y: 15)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let normalized = min(max((value.location.x - startX) / (endX - startX), 0), 1)
                        let shouldScrub = isScrubbing || abs(value.translation.width) >= scrubThreshold
                        guard shouldScrub else { return }

                        isScrubbing = true
                        onScrub(normalized)

                        let next = Int((normalized * CGFloat(count - 1)).rounded())
                        guard next != selection else { return }
                        Haptics.impact(.light, intensity: 0.35)
                        selection = next
                    }
                    .onEnded { value in
                        let normalized = min(max((value.location.x - startX) / (endX - startX), 0), 1)
                        let wasScrubbing = isScrubbing || abs(value.translation.width) >= scrubThreshold
                        isScrubbing = false

                        let next = Int((normalized * CGFloat(count - 1)).rounded())
                        if next != selection {
                            Haptics.impact(.light, intensity: 0.35)
                            selection = next
                        }

                        guard wasScrubbing else { return }
                        let snappedProgress = count > 1
                            ? CGFloat(next) / CGFloat(count - 1)
                            : 0
                        onScrub(normalized)
                        onScrubEnded(snappedProgress)
                    }
            )
        }
    }

    private func markerDiameter(at index: Int) -> CGFloat {
        guard count > 1 else { return 16 }
        let markerProgress = CGFloat(index) / CGFloat(count - 1)
        return 12 + 8 * markerProgress
    }
}

private struct ESIMTaperedTrackShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let centerY = rect.midY
        let startRadius: CGFloat = 8
        let startX = rect.minX + ESIMSliderMetrics.leadingInset
        let finalEndX = rect.maxX - ESIMSliderMetrics.trailingInset
        let clampedProgress = min(max(progress, 0), 1)
        let endX = startX + (finalEndX - startX) * clampedProgress
        let endRadius = startRadius + 4 * clampedProgress

        var path = Path()
        path.move(to: CGPoint(x: startX, y: centerY - startRadius))
        path.addLine(to: CGPoint(x: endX, y: centerY - endRadius))
        path.addArc(
            center: CGPoint(x: endX, y: centerY),
            radius: endRadius,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: startX, y: centerY + startRadius))
        path.addArc(
            center: CGPoint(x: startX, y: centerY),
            radius: startRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private enum ESIMCatalog {
    static let countries: [ESIMCountry] = [
        country("TUR", "Турция", "Европа и Азия", "Asia", 45, 38.9637, 35.2433, "tr", "🕌"),
        country("THA", "Таиланд", "Юго-Восточная Азия", "Asia", 60, 15.8700, 100.9925, "th", "🏝️"),
        country("ARE", "ОАЭ", "Ближний Восток", "Asia", 70, 23.4241, 53.8478, "ae", "🏙️"),
        country("EGY", "Египет", "Северная Африка", "Africa", 55, 26.8206, 30.8025, "eg", "🐪"),
        country("CHN", "Китай", "Восточная Азия", "Asia", 50, 35.8617, 104.1954, "cn", "🥟"),
        country("VNM", "Вьетнам", "Юго-Восточная Азия", "Asia", 58, 14.0583, 108.2772, "vn", "🍜"),
        country("GEO", "Грузия", "Кавказ", "Asia", 40, 42.3154, 43.3569, "ge", "🍷"),
        country("ARM", "Армения", "Кавказ", "Asia", 42, 40.0691, 45.0382, "am", "⛰️"),
        country("AZE", "Азербайджан", "Кавказ", "Asia", 45, 40.1431, 47.5769, "az", "🔥"),
        country("KAZ", "Казахстан", "Центральная Азия", "Asia", 55, 48.0196, 66.9237, "kz", "🐎"),
        country("UZB", "Узбекистан", "Центральная Азия", "Asia", 48, 41.3775, 64.5853, "uz", "🕌"),
        country("KGZ", "Киргизия", "Центральная Азия", "Asia", 52, 41.2044, 74.7661, "kg", "🏔️"),
        country("IND", "Индия", "Южная Азия", "Asia", 65, 20.5937, 78.9629, "in", "🪷"),
        country("LKA", "Шри-Ланка", "Южная Азия", "Asia", 68, 7.8731, 80.7718, "lk", "🐘"),
        country("MDV", "Мальдивы", "Южная Азия", "Asia", 95, 3.2028, 73.2207, "mv", "🏖️"),
        country("IDN", "Индонезия", "Юго-Восточная Азия", "Asia", 65, -0.7893, 113.9213, "id", "🌋"),
        country("MYS", "Малайзия", "Юго-Восточная Азия", "Asia", 72, 4.2105, 101.9758, "my", "🌺"),
        country("PHL", "Филиппины", "Юго-Восточная Азия", "Asia", 75, 12.8797, 121.7740, "ph", "🤿"),
        country("KHM", "Камбоджа", "Юго-Восточная Азия", "Asia", 62, 12.5657, 104.9910, "kh", "🛕"),
        country("JPN", "Япония", "Восточная Азия", "Asia", 95, 36.2048, 138.2529, "jp", "🗼"),
        country("KOR", "Южная Корея", "Восточная Азия", "Asia", 85, 35.9078, 127.7669, "kr", "🎎"),
        country("ISR", "Израиль", "Ближний Восток", "Asia", 90, 31.0461, 34.8516, "il", "🫒"),
        country("JOR", "Иордания", "Ближний Восток", "Asia", 88, 30.5852, 36.2384, "jo", "🏜️"),
        country("QAT", "Катар", "Ближний Восток", "Asia", 82, 25.3548, 51.1839, "qa", "🏟️"),
        country("OMN", "Оман", "Ближний Восток", "Asia", 78, 21.4735, 55.9754, "om", "⛵️"),
        country("CYP", "Кипр", "Средиземноморье", "Asia", 80, 35.1264, 33.4299, "cy", "🌊"),
        country("GRC", "Греция", "Южная Европа", "Europe", 84, 39.0742, 21.8243, "gr", "🏛️"),
        country("SRB", "Сербия", "Балканы", "Europe", 70, 44.0165, 21.0059, "rs", "🎺"),
        country("MNE", "Черногория", "Балканы", "Europe", 74, 42.7087, 19.3744, "me", "⛰️"),
        country("HRV", "Хорватия", "Балканы", "Europe", 86, 45.1000, 15.2000, "hr", "⛵️"),
        country("BGR", "Болгария", "Балканы", "Europe", 72, 42.7339, 25.4858, "bg", "🌹"),
        country("HUN", "Венгрия", "Центральная Европа", "Europe", 78, 47.1625, 19.5033, "hu", "♨️"),
        country("ITA", "Италия", "Южная Европа", "Europe", 90, 41.8719, 12.5674, "it", "🍕"),
        country("ESP", "Испания", "Южная Европа", "Europe", 92, 40.4637, -3.7492, "es", "💃"),
        country("PRT", "Португалия", "Южная Европа", "Europe", 88, 39.3999, -8.2245, "pt", "🚋"),
        country("FRA", "Франция", "Западная Европа", "Europe", 96, 46.2276, 2.2137, "fr", "🥐"),
        country("DEU", "Германия", "Центральная Европа", "Europe", 94, 51.1657, 10.4515, "de", "🥨"),
        country("AUT", "Австрия", "Центральная Европа", "Europe", 92, 47.5162, 14.5501, "at", "🎻"),
        country("CHE", "Швейцария", "Центральная Европа", "Europe", 110, 46.8182, 8.2275, "ch", "🏔️"),
        country("NLD", "Нидерланды", "Западная Европа", "Europe", 98, 52.1326, 5.2913, "nl", "🌷"),
        country("GBR", "Великобритания", "Северная Европа", "Europe", 105, 55.3781, -3.4360, "gb", "💂"),
        country("CUB", "Куба", "Карибы", "North America", 98, 21.5218, -77.7812, "cu", "🚗"),
        country("DOM", "Доминикана", "Карибы", "North America", 96, 18.7357, -70.1627, "do", "🌴"),
        country("MEX", "Мексика", "Северная Америка", "North America", 90, 23.6345, -102.5528, "mx", "🌮"),
        country("BRA", "Бразилия", "Южная Америка", "South America", 92, -14.2350, -51.9253, "br", "⚽️"),
        country("MAR", "Марокко", "Северная Африка", "Africa", 70, 31.7917, -7.0926, "ma", "🫖"),
        country("ZAF", "ЮАР", "Южная Африка", "Africa", 105, -30.5595, 22.9375, "za", "🦁"),
        country("KEN", "Кения", "Восточная Африка", "Africa", 98, -0.0236, 37.9062, "ke", "🦒"),
        country("MUS", "Маврикий", "Индийский океан", "Africa", 110, -20.3484, 57.5522, "mu", "🐚"),
        country("SYC", "Сейшелы", "Индийский океан", "Africa", 120, -4.6796, 55.4920, "sc", "🐢"),
    ]

    private static func country(
        _ id: String,
        _ title: String,
        _ region: String,
        _ continent: String,
        _ pricePerGB: Int,
        _ lat: Double,
        _ lng: Double,
        _ flagCode: String,
        _ sticker: String
    ) -> ESIMCountry {
        ESIMCountry(
            id: id,
            title: title,
            region: region,
            continent: continent,
            pricePerGB: pricePerGB,
            lat: lat,
            lng: lng,
            flagCode: flagCode,
            sticker: sticker
        )
    }

    static let regions: [ESIMRegion] = [
        ESIMRegion(
            id: "europe",
            title: "Европа",
            continent: "Europe",
            pricePerGB: 90,
            lat: 54,
            lng: 15,
            altitude: 1.9
        ),
        ESIMRegion(
            id: "asia",
            title: "Азия",
            continent: "Asia",
            pricePerGB: 80,
            lat: 36,
            lng: 92,
            altitude: 2.05
        ),
        ESIMRegion(
            id: "africa",
            title: "Африка",
            continent: "Africa",
            pricePerGB: 85,
            lat: 3,
            lng: 21,
            altitude: 1.95
        ),
        ESIMRegion(
            id: "north-america",
            title: "Северная Америка",
            continent: "North America",
            pricePerGB: 120,
            lat: 45,
            lng: -100,
            altitude: 2.0
        ),
        ESIMRegion(
            id: "south-america",
            title: "Южная Америка",
            continent: "South America",
            pricePerGB: 110,
            lat: -15,
            lng: -60,
            altitude: 1.95
        ),
        ESIMRegion(
            id: "oceania",
            title: "Океания",
            continent: "Oceania",
            pricePerGB: 105,
            lat: -25,
            lng: 135,
            altitude: 2.05
        ),
    ]
}

private struct ESIMGlobeWebView: UIViewRepresentable {
    let countries: [ESIMCountry]
    let selectedOffer: ESIMOffer?
    let showsTooltip: Bool
    let showsTooltipSubtitle: Bool
    let tooltipScale: CGFloat
    let stageOffsetY: CGFloat
    let isPaused: Bool
    let onSelectCountry: (ESIMCountry) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(countries: countries, onSelectCountry: onSelectCountry)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "esimGlobe")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        if let url = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "Web/ESIMGlobe"
        ) ?? Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        context.coordinator.sync(
            webView: webView,
            countries: countries,
            selectedOffer: selectedOffer,
            showsTooltip: showsTooltip,
            showsTooltipSubtitle: showsTooltipSubtitle,
            tooltipScale: tooltipScale,
            stageOffsetY: stageOffsetY,
            isPaused: isPaused,
            onSelectCountry: onSelectCountry
        )

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.sync(
            webView: webView,
            countries: countries,
            selectedOffer: selectedOffer,
            showsTooltip: showsTooltip,
            showsTooltipSubtitle: showsTooltipSubtitle,
            tooltipScale: tooltipScale,
            stageOffsetY: stageOffsetY,
            isPaused: isPaused,
            onSelectCountry: onSelectCountry
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private var countries: [ESIMCountry]
        private var onSelectCountry: (ESIMCountry) -> Void
        private var selectedOffer: ESIMOffer?
        private var showsTooltip = true
        private var showsTooltipSubtitle = true
        private var tooltipScale: CGFloat = 1
        private var stageOffsetY: CGFloat = 0
        private var isPaused = false
        private var isLoaded = false
        private var didSendCountries = false
        private var lastSelectedID: String?
        private var lastShowsTooltip: Bool?
        private var lastShowsTooltipSubtitle: Bool?
        private var lastTooltipScale: CGFloat?
        private var lastStageOffsetY: CGFloat?
        private var lastIsPaused: Bool?

        init(countries: [ESIMCountry], onSelectCountry: @escaping (ESIMCountry) -> Void) {
            self.countries = countries
            self.onSelectCountry = onSelectCountry
        }

        func sync(
            webView: WKWebView,
            countries: [ESIMCountry],
            selectedOffer: ESIMOffer?,
            showsTooltip: Bool,
            showsTooltipSubtitle: Bool,
            tooltipScale: CGFloat,
            stageOffsetY: CGFloat,
            isPaused: Bool,
            onSelectCountry: @escaping (ESIMCountry) -> Void
        ) {
            self.countries = countries
            self.selectedOffer = selectedOffer
            self.showsTooltip = showsTooltip
            self.showsTooltipSubtitle = showsTooltipSubtitle
            self.tooltipScale = tooltipScale
            self.stageOffsetY = stageOffsetY
            self.isPaused = isPaused
            self.onSelectCountry = onSelectCountry

            guard isLoaded else { return }

            if !didSendCountries {
                sendCountries(to: webView)
                didSendCountries = true
            }

            sendPauseStateIfNeeded(isPaused, to: webView)
            sendStageOffsetIfNeeded(stageOffsetY, to: webView)
            sendSelectionIfNeeded(to: webView)
            sendTooltipVisibilityIfNeeded(showsTooltip, to: webView)
            sendTooltipSubtitleVisibilityIfNeeded(showsTooltipSubtitle, to: webView)
            sendTooltipScaleIfNeeded(tooltipScale, to: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            didSendCountries = false
            lastSelectedID = nil
            lastShowsTooltip = nil
            lastShowsTooltipSubtitle = nil
            lastTooltipScale = nil
            lastStageOffsetY = nil
            lastIsPaused = nil
            sync(
                webView: webView,
                countries: countries,
                selectedOffer: selectedOffer,
                showsTooltip: showsTooltip,
                showsTooltipSubtitle: showsTooltipSubtitle,
                tooltipScale: tooltipScale,
                stageOffsetY: stageOffsetY,
                isPaused: isPaused,
                onSelectCountry: onSelectCountry
            )
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.name == "esimGlobe",
                let body = message.body as? [String: Any],
                body["type"] as? String == "selectCountry",
                let id = body["id"] as? String,
                let country = countries.first(where: { $0.id == id })
            else { return }

            DispatchQueue.main.async {
                self.onSelectCountry(country)
            }
        }

        private func sendCountries(to webView: WKWebView) {
            let payload = countries.map(ESIMGlobeCountryPayload.init(country:))
            guard let json = jsonLiteral(payload) else { return }
            webView.evaluateJavaScript("window.esimGlobe?.setCountries(\(json));")
        }

        private func sendSelectionIfNeeded(to webView: WKWebView) {
            let selectedID = selectedOffer?.id
            guard selectedID != lastSelectedID else { return }

            lastSelectedID = selectedID

            if let selectedOffer {
                let payload = ESIMGlobeSelectionPayload(offer: selectedOffer)
                guard let json = jsonLiteral(payload) else { return }
                webView.evaluateJavaScript("window.esimGlobe?.selectCountry(\(json));")
            } else {
                webView.evaluateJavaScript("window.esimGlobe?.clearSelection();")
            }
        }

        private func sendTooltipVisibilityIfNeeded(_ isVisible: Bool, to webView: WKWebView) {
            guard lastShowsTooltip != isVisible else { return }
            lastShowsTooltip = isVisible
            webView.evaluateJavaScript("window.esimGlobe?.setTooltipVisible(\(isVisible));")
        }

        private func sendTooltipSubtitleVisibilityIfNeeded(
            _ isVisible: Bool,
            to webView: WKWebView
        ) {
            guard lastShowsTooltipSubtitle != isVisible else { return }
            lastShowsTooltipSubtitle = isVisible
            webView.evaluateJavaScript(
                "window.esimGlobe?.setTooltipSubtitleVisible(\(isVisible));"
            )
        }

        private func sendTooltipScaleIfNeeded(_ scale: CGFloat, to webView: WKWebView) {
            guard lastTooltipScale != scale else { return }
            lastTooltipScale = scale
            webView.evaluateJavaScript("window.esimGlobe?.setTooltipScale(\(scale));")
        }

        private func sendStageOffsetIfNeeded(_ offsetY: CGFloat, to webView: WKWebView) {
            guard lastStageOffsetY != offsetY else { return }
            lastStageOffsetY = offsetY
            webView.evaluateJavaScript("window.esimGlobe?.setStageOffset(\(offsetY));")
        }

        private func sendPauseStateIfNeeded(_ isPaused: Bool, to webView: WKWebView) {
            guard lastIsPaused != isPaused else { return }
            lastIsPaused = isPaused
            webView.evaluateJavaScript("window.esimGlobe?.setPaused(\(isPaused));")
        }

        private func jsonLiteral<T: Encodable>(_ value: T) -> String? {
            guard
                let data = try? JSONEncoder().encode(value),
                let string = String(data: data, encoding: .utf8)
            else { return nil }
            return string
        }
    }
}

private struct ESIMGlobeCountryPayload: Encodable {
    let id: String
    let title: String
    let priceLabel: String
    let lat: Double
    let lng: Double
    let continent: String
    let sticker: String

    init(country: ESIMCountry) {
        id = country.id
        title = country.title
        priceLabel = country.priceLabel
        lat = country.lat
        lng = country.lng
        continent = country.continent
        sticker = country.sticker
    }
}

private struct ESIMGlobeSelectionPayload: Encodable {
    let id: String
    let title: String
    let priceLabel: String
    let lat: Double
    let lng: Double
    let altitude: Double
    let countryIDs: [String]?
    let continents: [String]?
    let sticker: String

    init(offer: ESIMOffer) {
        id = offer.id
        title = offer.title
        priceLabel = offer.priceLabel

        switch offer {
        case .country(let country):
            lat = country.lat
            lng = country.lng
            altitude = 1.55
            countryIDs = [country.id]
            continents = nil
            sticker = country.sticker
        case .region(let region):
            lat = region.lat
            lng = region.lng
            altitude = region.altitude
            countryIDs = nil
            continents = [region.continent]
            sticker = "🌍"
        }
    }
}
