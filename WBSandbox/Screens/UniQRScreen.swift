import SwiftUI

/// UniQR, экран ввода суммы по макету 52478:422242.
struct UniQRScreen: View {
    var onBack: () -> Void = {}
    var bonusAnimationStyle: UniQRBonusAnimationStyle = .rollOnly
    var configuration: UniQRConfiguration = .qrDemo
    var onPay: () -> Void = {}

    @State private var selectedRail: UniQRPaymentRail = .wbPay
    @State private var sourceAccountID: String?
    @State private var destinationAccountID: String?
    @State private var accountPickerSlot: UniQRTransferSlot = .destination
    @State private var isAccountPickerPresented = false
    @State private var sourceAttentionProgress: CGFloat = 0
    @State private var destinationAttentionProgress: CGFloat = 0
    @State private var didInitializeTransferRoute = false

    private var sourceAccount: UniQRTransferAccount? {
        guard let sourceAccountID else { return nil }
        return configuration.transferAccounts.first { $0.id == sourceAccountID }
    }

    private var destinationAccount: UniQRTransferAccount? {
        guard let destinationAccountID else { return nil }
        return configuration.transferAccounts.first { $0.id == destinationAccountID }
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(proxy.size.width, 390)

            ZStack(alignment: .top) {
                WBColor.bgBase
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    UniQRNavBar(title: configuration.title, onBack: onBack)

                    VStack {
                        UniQRAmountBlock(
                            amount: configuration.amount,
                            bonusPoints: selectedRail.bonusPoints,
                            isBonusActive: selectedRail.earnsBonus,
                            showsBonus: configuration.showsBonus,
                            bonusAnimationStyle: bonusAnimationStyle
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    UniQRDownSection(
                        selection: $selectedRail,
                        configuration: configuration,
                        sourceAccount: sourceAccount,
                        destinationAccount: destinationAccount,
                        sourceAttentionProgress: sourceAttentionProgress,
                        destinationAttentionProgress: destinationAttentionProgress,
                        onTapSource: { openAccountPicker(.source) },
                        onTapDestination: { openAccountPicker(.destination) },
                        onPay: onPay
                    )
                }
                .frame(width: contentWidth, height: proxy.size.height)
                .frame(maxWidth: .infinity)

                if isAccountPickerPresented {
                    accountPickerOverlay(width: proxy.size.width)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .zIndex(1)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: initializeTransferRouteIfNeeded)
    }

    private func initializeTransferRouteIfNeeded() {
        guard configuration.routeStyle == .betweenAccountsTransition,
              !didInitializeTransferRoute
        else { return }
        didInitializeTransferRoute = true
        sourceAccountID = configuration.initialTransferSourceID
            ?? configuration.transferAccounts.first?.id
    }

    private func openAccountPicker(_ slot: UniQRTransferSlot) {
        Haptics.tap()
        accountPickerSlot = slot
        withAnimation(.snappy(duration: 0.24)) {
            isAccountPickerPresented = true
        }
    }

    private func selectTransferAccount(_ account: UniQRTransferAccount) {
        let targetSlot = accountPickerSlot
        let slotToShake: UniQRTransferSlot? = switch targetSlot {
        case .source:
            destinationAccountID == account.id ? .destination : nil
        case .destination:
            sourceAccountID == account.id ? .source : nil
        }

        withAnimation(.snappy(duration: 0.2)) {
            switch targetSlot {
            case .source:
                sourceAccountID = account.id
                if slotToShake == .destination {
                    destinationAccountID = nil
                }
            case .destination:
                destinationAccountID = account.id
                if slotToShake == .source {
                    sourceAccountID = nil
                }
            }
            isAccountPickerPresented = false
        }

        guard let slotToShake else {
            Haptics.tap()
            return
        }

        triggerSlotAttention(slotToShake)
    }

    private func triggerSlotAttention(_ slot: UniQRTransferSlot) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            playSlotAttention(slot)
        }
    }

    private func playSlotAttention(_ slot: UniQRTransferSlot) {
        Haptics.impact(.rigid, intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Haptics.impact(.rigid, intensity: 0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            Haptics.impact(.rigid, intensity: 0.8)
        }
        setAttentionProgress(0, for: slot)
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 0.46)) {
                setAttentionProgress(1, for: slot)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            withTransaction(Transaction(animation: nil)) {
                setAttentionProgress(0, for: slot)
            }
        }
    }

    private func setAttentionProgress(_ progress: CGFloat, for slot: UniQRTransferSlot) {
        switch slot {
        case .source:
            sourceAttentionProgress = progress
        case .destination:
            destinationAttentionProgress = progress
        }
    }

    private func closeAccountPicker() {
        withAnimation(.snappy(duration: 0.22)) {
            isAccountPickerPresented = false
        }
    }

    private func accountPickerOverlay(width: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture(perform: closeAccountPicker)

            UniQRAccountPickerSheet(
                title: accountPickerSlot.sheetTitle,
                accounts: configuration.transferAccounts,
                width: width,
                onSelect: selectTransferAccount,
                onClose: closeAccountPicker
            )
        }
        .ignoresSafeArea()
    }
}

struct UniQRConfiguration {
    var title: String
    var amount: Int
    var showsBonus: Bool
    var showsPaymentSwitch: Bool
    var recipientTitle: String
    var recipientSubtitle: String
    var recipientIcon: UniQRRecipientIcon
    var routeStyle: UniQRRouteStyle = .payment
    var buttonTitle: String = "Оплатить"
    var buttonSubtitle: String = "Без комиссии"
    var transferAccounts: [UniQRTransferAccount] = []
    var initialTransferSourceID: String?

    static let qrDemo = UniQRConfiguration(
        title: "Оплатить по QR-коду",
        amount: 1_000,
        showsBonus: true,
        showsPaymentSwitch: true,
        recipientTitle: "Цветы у дома",
        recipientSubtitle: "Т-Банк",
        recipientIcon: .flower
    )
    static func esim(
        amount: Int,
        destination: String,
        subtitle: String,
        flagAsset: String?
    ) -> UniQRConfiguration {
        UniQRConfiguration(
            title: "Оплатить eSIM",
            amount: amount,
            showsBonus: false,
            showsPaymentSwitch: false,
            recipientTitle: destination,
            recipientSubtitle: subtitle,
            recipientIcon: flagAsset.map(UniQRRecipientIcon.asset) ?? .placeholder
        )
    }

    static let betweenAccountsTransition = UniQRConfiguration(
        title: "Перевести",
        amount: 1_000,
        showsBonus: false,
        showsPaymentSwitch: false,
        recipientTitle: "Куда",
        recipientSubtitle: "Выберите счёт",
        recipientIcon: .emptySlot,
        routeStyle: .betweenAccountsTransition,
        buttonTitle: "Продолжить",
        buttonSubtitle: "",
        transferAccounts: UniQRTransferAccount.demoAccounts,
        initialTransferSourceID: "save-7654"
    )

}

enum UniQRRecipientIcon {
    case flower
    case asset(String)
    case placeholder
    case wbAccount
    case savingsAccount
    case emptySlot
}

enum UniQRBonusAnimationStyle {
    case rollOnly
    case lossParticles
    case gainFromTop
}

enum UniQRRouteStyle {
    case payment
    case betweenAccountsTransition
}

private enum UniQRTransferSlot {
    case source
    case destination

    var sheetTitle: String {
        switch self {
        case .source: "Откуда перевести"
        case .destination: "Куда перевести"
        }
    }
}

struct UniQRTransferAccount: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var icon: UniQRRecipientIcon
    var background: Color

    static let demoAccounts = [
        UniQRTransferAccount(
            id: "wb-2831",
            title: "1 235 ₽",
            subtitle: "WB Кошелёк ··2831",
            icon: .wbAccount,
            background: WBColor.bgAccentSecondaryLight
        ),
        UniQRTransferAccount(
            id: "save-7654",
            title: "121 235 ₽",
            subtitle: "Накопительный счёт ··7654",
            icon: .savingsAccount,
            background: WBColor.bgMinus1
        ),
    ]
}

private enum UniQRPaymentRail: String, CaseIterable, Identifiable {
    case wbPay
    case sbp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wbPay: "WB Pay"
        case .sbp: "СБП"
        }
    }

    var bonusPoints: Int {
        switch self {
        case .wbPay: 35
        case .sbp: 0
        }
    }

    var earnsBonus: Bool { bonusPoints > 0 }
}

// MARK: - Navbar

private struct UniQRNavBar: View {
    let title: String
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(width: 390, height: 44)

            ZStack {
                Text(title)
                    .font(WBFont.hauss(17, .semibold))
                    .foregroundStyle(WBColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 56)

                HStack {
                    Button(action: onBack) {
                        Image("dsChevronLeft24")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(WBColor.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 2)
            }
            .frame(width: 390, height: 48)
        }
        .frame(width: 390, height: 92)
    }
}

// MARK: - Amount

private struct UniQRAmountBlock: View {
    let amount: Int
    let bonusPoints: Int
    let isBonusActive: Bool
    let showsBonus: Bool
    let bonusAnimationStyle: UniQRBonusAnimationStyle

    var body: some View {
        VStack(spacing: WBSpace.x2) {
            HStack(alignment: .lastTextBaseline, spacing: WBSpace.x1_5) {
                Text(amount.formatted(.number.grouping(.automatic)))
                    .foregroundStyle(WBColor.textPrimary)
                Text("₽")
                    .foregroundStyle(WBColor.textSecondary)
            }
            .font(WBFont.balance)
            .lineLimit(1)
            .frame(height: 44)

            if showsBonus {
                UniQRBonusBadgeView(
                    points: bonusPoints,
                    isActive: isBonusActive,
                    animationStyle: bonusAnimationStyle
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct UniQRBonusBadgeView: View {
    let points: Int
    let animationStyle: UniQRBonusAnimationStyle

    @State private var shownPoints: Double
    @State private var isVisuallyActive: Bool
    @State private var badgeScale: CGFloat = 1
    @State private var particles: [UniQRVBParticle] = []
    @State private var particleRunID = UUID()
    @State private var badgeTransitionID = UUID()

    init(points: Int, isActive: Bool, animationStyle: UniQRBonusAnimationStyle) {
        self.points = points
        self.animationStyle = animationStyle
        _shownPoints = State(initialValue: Double(points))
        _isVisuallyActive = State(initialValue: isActive)
    }

    private var background: Color {
        isVisuallyActive ? WBColor.badgeBerryBg : Color(hex: 0xF2F2F6)
    }

    private var foreground: Color {
        isVisuallyActive ? WBColor.badgeBerryText : WBColor.controlsSecondary
    }

    private var coinBackground: Color {
        isVisuallyActive ? WBColor.badgeCoinBg : WBColor.strokeSecondary
    }

    private var coinForeground: Color {
        isVisuallyActive ? .white : WBColor.controlsSecondary
    }

    var body: some View {
        HStack(spacing: 3) {
            Text("+")

            UniQRRolledIntegerText(value: shownPoints)
                .contentTransition(.numericText(value: shownPoints))
                .frame(minWidth: 15, alignment: .trailing)

            UniQRVBLogoCapsule(
                background: coinBackground,
                foreground: coinForeground
            )
        }
        .font(WBFont.descriptionAccent)
        .monospacedDigit()
        .foregroundStyle(foreground)
        .padding(.leading, 7)
        .padding(.trailing, 3)
        .frame(height: 21)
        .background(background, in: Capsule())
        .saturation(isVisuallyActive ? 1 : 0)
        .opacity(isVisuallyActive ? 1 : 0.72)
        .scaleEffect(badgeScale)
        .overlay(alignment: .topLeading) {
            GeometryReader { proxy in
                let origin = CGPoint(x: proxy.size.width - 12, y: proxy.size.height / 2)

                ForEach(particles) { particle in
                    let p = CGFloat(particle.progress)
                    let arc = particle.arcHeight * CGFloat(sin(.pi * particle.progress))
                    let x = particle.startX + (particle.endX - particle.startX) * p
                    let y = particle.startY + (particle.endY - particle.startY) * p - arc

                    UniQRVBLogoCapsule(
                        background: WBColor.badgeCoinBg,
                        foreground: .white,
                        height: particle.baseSize
                    )
                    .rotationEffect(.degrees(particle.rotation))
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .position(
                        x: origin.x + x,
                        y: origin.y + y
                    )
                    .allowsHitTesting(false)
                }
            }
            .allowsHitTesting(false)
        }
        .animation(.snappy(duration: 0.28), value: isVisuallyActive)
        .onChange(of: points) { _, newValue in
            let transitionID = UUID()
            badgeTransitionID = transitionID

            if newValue > 0 {
                withAnimation(.snappy(duration: 0.2)) {
                    isVisuallyActive = true
                }
            }

            if animationStyle == .lossParticles {
                if newValue == 0, shownPoints > 0 {
                    playLossParticles()
                } else if newValue > 0, shownPoints <= 0 {
                    playGainParticles()
                } else if newValue > 0 {
                    particles = []
                }
            } else if animationStyle == .gainFromTop {
                if newValue == 0, shownPoints > 0 {
                    playLossParticles()
                } else if newValue > 0, shownPoints <= 0 {
                    playTopGainParticles()
                } else {
                    particles = []
                }
            } else if newValue > 0 {
                particles = []
            }

            withAnimation(.easeInOut(duration: 0.65)) {
                shownPoints = Double(newValue)
            }

            if newValue == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    guard badgeTransitionID == transitionID else { return }
                    withAnimation(.easeOut(duration: 0.1)) {
                        isVisuallyActive = false
                    }
                }
            }
        }
        .accessibilityLabel("Начислим \(points) вб")
    }

    private func playLossParticles() {
        let runID = UUID()
        particleRunID = runID
        Haptics.impact(.soft, intensity: 0.45)
        spawnLossParticles(runID: runID)

        withAnimation(.spring(response: 0.26, dampingFraction: 0.62)) {
            badgeScale = 1.06
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard particleRunID == runID else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                badgeScale = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            guard particleRunID == runID else { return }
            particles = []
        }
    }

    private func playGainParticles() {
        let runID = UUID()
        particleRunID = runID
        Haptics.impact(.soft, intensity: 0.36)
        spawnGainParticles(runID: runID)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            guard particleRunID == runID else { return }
            withAnimation(.spring(response: 0.26, dampingFraction: 0.58)) {
                badgeScale = 1.08
            }
            Haptics.impact(.light, intensity: 0.4)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.74) {
            guard particleRunID == runID else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                badgeScale = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            guard particleRunID == runID else { return }
            particles = []
        }
    }

    private func playTopGainParticles() {
        let runID = UUID()
        particleRunID = runID
        Haptics.impact(.soft, intensity: 0.34)
        spawnTopGainParticles(runID: runID)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            guard particleRunID == runID else { return }
            withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
                badgeScale = 1.09
            }
            Haptics.impact(.light, intensity: 0.42)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            guard particleRunID == runID else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                badgeScale = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            guard particleRunID == runID else { return }
            particles = []
        }
    }

    private func spawnLossParticles(runID: UUID) {
        let configs: [(start: CGPoint, end: CGPoint, scale: CGFloat, delay: Double, size: CGFloat, arc: CGFloat)] = [
            (CGPoint(x: -1, y: -1), CGPoint(x: -24, y: 74), 0.88, 0.00, 15, 10),
            (CGPoint(x:  1, y:  0), CGPoint(x:   6, y: 92), 1.02, 0.08, 16,  6),
            (CGPoint(x:  2, y: -1), CGPoint(x:  25, y: 76), 0.82, 0.17, 15, 12),
            (CGPoint(x: -2, y:  1), CGPoint(x: -13, y: 112), 1.12, 0.29, 16,  5),
            (CGPoint(x:  2, y:  1), CGPoint(x:  18, y: 104), 0.78, 0.41, 15,  8),
            (CGPoint(x:  0, y:  0), CGPoint(x:  -2, y:  68), 0.62, 0.55, 14,  4),
        ]

        particles = configs.map { config in
            UniQRVBParticle(
                startX: config.start.x,
                startY: config.start.y,
                endX: config.end.x,
                endY: config.end.y,
                peakScale: config.scale,
                arcHeight: config.arc,
                flightDuration: 0.52 + Double(config.end.y / 210),
                totalRotation: Double.random(in: 80...190) * (Bool.random() ? 1 : -1),
                startDelay: config.delay,
                baseSize: config.size,
                scale: 0.08
            )
        }

        for index in particles.indices {
            animateLossParticle(at: index, runID: runID)
        }
    }

    private func spawnGainParticles(runID: UUID) {
        let configs: [(start: CGPoint, end: CGPoint, scale: CGFloat, delay: Double, size: CGFloat, arc: CGFloat)] = [
            (CGPoint(x: -30, y: 86), CGPoint(x: -2, y:  0), 0.78, 0.00, 14, 12),
            (CGPoint(x:   7, y: 108), CGPoint(x:  1, y: -1), 0.98, 0.08, 16, 18),
            (CGPoint(x:  30, y: 82), CGPoint(x:  2, y:  0), 0.82, 0.17, 15, 14),
            (CGPoint(x: -14, y: 118), CGPoint(x: -1, y:  1), 1.08, 0.29, 16, 20),
            (CGPoint(x:  20, y: 106), CGPoint(x:  1, y:  1), 0.76, 0.42, 15, 15),
        ]

        particles = configs.map { config in
            UniQRVBParticle(
                startX: config.start.x,
                startY: config.start.y,
                endX: config.end.x,
                endY: config.end.y,
                peakScale: config.scale,
                arcHeight: config.arc,
                flightDuration: 0.54,
                totalRotation: Double.random(in: 180...360) * (Bool.random() ? 1 : -1),
                startDelay: config.delay,
                baseSize: config.size,
                scale: 0.08
            )
        }

        for index in particles.indices {
            animateGainParticle(at: index, runID: runID)
        }
    }

    private func spawnTopGainParticles(runID: UUID) {
        let configs: [(start: CGPoint, end: CGPoint, scale: CGFloat, delay: Double, size: CGFloat, arc: CGFloat)] = [
            (CGPoint(x: -30, y: -92), CGPoint(x: -2, y:  0), 0.78, 0.00, 14, 14),
            (CGPoint(x:   4, y: -118), CGPoint(x:  1, y: -1), 1.02, 0.07, 16, 22),
            (CGPoint(x:  30, y: -86), CGPoint(x:  2, y:  0), 0.82, 0.16, 15, 15),
            (CGPoint(x: -14, y: -132), CGPoint(x: -1, y:  1), 1.1,  0.28, 16, 24),
            (CGPoint(x:  18, y: -106), CGPoint(x:  1, y:  1), 0.76, 0.4,  15, 17),
        ]

        particles = configs.map { config in
            UniQRVBParticle(
                startX: config.start.x,
                startY: config.start.y,
                endX: config.end.x,
                endY: config.end.y,
                peakScale: config.scale,
                arcHeight: config.arc,
                flightDuration: 0.56,
                totalRotation: Double.random(in: 180...360) * (Bool.random() ? 1 : -1),
                startDelay: config.delay,
                baseSize: config.size,
                scale: 0.08
            )
        }

        for index in particles.indices {
            animateGainParticle(at: index, runID: runID)
        }
    }

    private func animateLossParticle(at index: Int, runID: UUID) {
        guard index < particles.count else { return }

        let target = particles[index]
        let delay = target.startDelay
        let flightDuration = target.flightDuration
        let halfFlight = flightDuration / 2
        let fadeDuration = min(0.26, flightDuration * 0.34)
        let fadeOutStart = flightDuration - fadeDuration

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard particleRunID == runID, index < particles.count else { return }

            withAnimation(.easeOut(duration: 0.12)) {
                particles[index].opacity = 1
            }
            withAnimation(.easeIn(duration: flightDuration)) {
                particles[index].progress = 1
            }
            withAnimation(.easeIn(duration: flightDuration)) {
                particles[index].rotation = target.totalRotation
            }
            withAnimation(.easeOut(duration: halfFlight)) {
                particles[index].scale = target.peakScale
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay + halfFlight) {
            guard particleRunID == runID, index < particles.count else { return }

            withAnimation(.easeIn(duration: halfFlight)) {
                particles[index].scale = 0.08
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay + fadeOutStart) {
            guard particleRunID == runID, index < particles.count else { return }

            withAnimation(.easeIn(duration: fadeDuration)) {
                particles[index].opacity = 0
            }
        }
    }

    private func animateGainParticle(at index: Int, runID: UUID) {
        guard index < particles.count else { return }

        let target = particles[index]
        let delay = target.startDelay
        let flightDuration = target.flightDuration
        let fadeDuration = min(0.16, flightDuration * 0.28)
        let fadeOutStart = flightDuration - fadeDuration

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard particleRunID == runID, index < particles.count else { return }

            withAnimation(.easeOut(duration: 0.1)) {
                particles[index].opacity = 1
            }
            withAnimation(.easeInOut(duration: flightDuration)) {
                particles[index].progress = 1
            }
            withAnimation(.easeOut(duration: flightDuration)) {
                particles[index].rotation = target.totalRotation
            }
            withAnimation(.easeOut(duration: flightDuration * 0.62)) {
                particles[index].scale = target.peakScale
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay + fadeOutStart) {
            guard particleRunID == runID, index < particles.count else { return }

            withAnimation(.easeInOut(duration: fadeDuration)) {
                particles[index].scale = 0.16
                particles[index].opacity = 0
            }
        }
    }
}

private struct UniQRVBParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let peakScale: CGFloat
    let arcHeight: CGFloat
    let flightDuration: Double
    let totalRotation: Double
    let startDelay: Double
    let baseSize: CGFloat

    var progress: Double = 0
    var rotation: Double = 0
    var scale: CGFloat = 0.2
    var opacity: Double = 0
}

private struct UniQRRolledIntegerText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))")
    }
}

private struct UniQRVBLogoCapsule: View {
    let background: Color
    let foreground: Color
    var height: CGFloat = 16

    var body: some View {
        Text("вб")
            .font(WBFont.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 4)
            .frame(height: height)
            .background(background, in: Capsule())
    }
}

// MARK: - Payment Switch

private struct UniQRDownSection: View {
    @Binding var selection: UniQRPaymentRail
    let configuration: UniQRConfiguration
    let sourceAccount: UniQRTransferAccount?
    let destinationAccount: UniQRTransferAccount?
    let sourceAttentionProgress: CGFloat
    let destinationAttentionProgress: CGFloat
    let onTapSource: () -> Void
    let onTapDestination: () -> Void
    let onPay: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if configuration.showsPaymentSwitch {
                UniQRPaymentSwitch(selection: $selection)
                    .padding(.top, WBSpace.x2)
                    .padding(.bottom, WBSpace.x4)
                    .padding(.horizontal, WBSpace.x4)
            }

            UniQRRouteCards(
                configuration: configuration,
                sourceAccount: sourceAccount,
                destinationAccount: destinationAccount,
                sourceAttentionProgress: sourceAttentionProgress,
                destinationAttentionProgress: destinationAttentionProgress,
                onTapSource: onTapSource,
                onTapDestination: onTapDestination
            )
                .padding(.horizontal, WBSpace.x4)
                .padding(.bottom, WBSpace.x2)

            UniQRBottomBar(
                title: configuration.buttonTitle,
                subtitle: configuration.buttonSubtitle,
                onPay: onPay
            )
        }
        .frame(width: 390)
    }
}

private struct UniQRPaymentSwitch: View {
    @Binding var selection: UniQRPaymentRail

    var body: some View {
        HStack(spacing: WBSpace.x1_5) {
            ForEach(UniQRPaymentRail.allCases) { rail in
                UniQRChip(title: rail.title, isSelected: selection == rail) {
                    guard selection != rail else { return }
                    Haptics.tap()
                    withAnimation(.snappy(duration: 0.28)) {
                        selection = rail
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UniQRChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WBFont.body)
                .foregroundStyle(isSelected ? Color(hex: 0xF6F6F9) : WBColor.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, WBSpace.x3)
                .frame(height: 38)
                .background(
                    isSelected ? WBColor.ctaFill : WBColor.bgMinus1,
                    in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.28), value: isSelected)
    }
}

// MARK: - Route Cards

private struct UniQRRouteCards: View {
    let configuration: UniQRConfiguration
    let sourceAccount: UniQRTransferAccount?
    let destinationAccount: UniQRTransferAccount?
    let sourceAttentionProgress: CGFloat
    let destinationAttentionProgress: CGFloat
    let onTapSource: () -> Void
    let onTapDestination: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: WBSpace.x3) {
                switch configuration.routeStyle {
                case .payment:
                    UniQRWalletCard()
                        .frame(maxWidth: .infinity)

                    UniQRRecipientCard(configuration: configuration)
                        .frame(maxWidth: .infinity)
                case .betweenAccountsTransition:
                    Button(action: onTapSource) {
                        UniQRTransferAccountCard(
                            account: sourceAccount,
                            placeholderTitle: "Откуда",
                            attentionProgress: sourceAttentionProgress
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .modifier(UniQRPremiumAttentionEffect(progress: sourceAttentionProgress))
                    .accessibilityLabel("Откуда")
                    .accessibilityAddTraits(.isButton)

                    Button(action: onTapDestination) {
                        UniQRTransferAccountCard(
                            account: destinationAccount,
                            placeholderTitle: "Куда",
                            attentionProgress: destinationAttentionProgress
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .modifier(UniQRPremiumAttentionEffect(progress: destinationAttentionProgress))
                    .accessibilityLabel("Куда")
                    .accessibilityAddTraits(.isButton)
                }
            }

            Circle()
                .fill(WBColor.bgBase)
                .frame(width: 24, height: 24)
                .overlay {
                    Image("dsArrowRight16")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(WBColor.textPrimary)
                }
        }
        .frame(height: 96)
    }
}

private struct UniQRTransferAccountCard: View {
    let account: UniQRTransferAccount?
    let placeholderTitle: String
    var attentionProgress: CGFloat = 0

    private var background: Color {
        account?.background ?? WBColor.bgLevel2
    }

    private var iconPop: CGFloat {
        guard account == nil else { return 0 }
        let progress = attentionProgress.uniQRClampedUnit
        return max(0, sin(progress * .pi * 1.65)) * max(0, 1 - progress * 0.36)
    }

    var body: some View {
        UniQRInfoCard(background: background) {
            UniQRRecipientIconView(icon: account?.icon ?? .emptySlot)
                .scaleEffect(1 + iconPop * 0.055)
        } title: {
            Text(account?.title ?? placeholderTitle)
                .font(WBFont.descriptionAccent)
                .foregroundStyle(WBColor.textPrimary)
                .lineLimit(1)
        } subtitle: {
            Text(account?.subtitle ?? "Счёт или банк")
                .font(WBFont.description)
                .foregroundStyle(WBColor.textPrimary)
                .lineLimit(1)
        }
    }
}

private struct UniQRWalletCard: View {
    var body: some View {
        UniQRInfoCard(background: WBColor.bgAccentSecondaryLight) {
            UniQRWBPayIcon()
        } title: {
            Text("1 235 ₽")
                .font(WBFont.descriptionAccent)
                .foregroundStyle(WBColor.textPrimary)
        } subtitle: {
            Text("WB Кошелёк")
                .font(WBFont.description)
                .foregroundStyle(WBColor.textPrimary)
        }
    }
}

private struct UniQRRecipientCard: View {
    let configuration: UniQRConfiguration

    var body: some View {
        UniQRInfoCard(background: WBColor.bgMinus1) {
            UniQRRecipientIconView(icon: configuration.recipientIcon)
        } title: {
            Text(configuration.recipientTitle)
                .font(WBFont.descriptionAccent)
                .foregroundStyle(WBColor.textPrimary)
                .lineLimit(1)
        } subtitle: {
            Text(configuration.recipientSubtitle)
                .font(WBFont.description)
                .foregroundStyle(WBColor.textPrimary)
        }
    }
}

private struct UniQRRecipientIconView: View {
    let icon: UniQRRecipientIcon

    var body: some View {
        switch icon {
        case .flower:
            RoundedRectangle(cornerRadius: WBSpace.x2, style: .continuous)
                .fill(WBColor.ctaTopUp)
                .frame(width: 24, height: 24)
                .overlay {
                    Image("dsFlowerTulip16")
                        .resizable()
                        .frame(width: 16, height: 16)
                }
        case .asset(let name):
            Image(name)
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 7.2, style: .continuous))
        case .placeholder:
            RoundedRectangle(cornerRadius: 7.2, style: .continuous)
                .fill(WBColor.textSecondary.opacity(0.18))
                .frame(width: 24, height: 24)
        case .wbAccount:
            Image("icAccountWB")
                .resizable()
                .frame(width: 24, height: 24)
        case .savingsAccount:
            RoundedRectangle(cornerRadius: 7.2, style: .continuous)
                .fill(WBColor.textAccent)
                .frame(width: 24, height: 24)
                .overlay {
                    Image("icSafe")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14.4, height: 14.4)
                        .foregroundStyle(.white)
                }
        case .emptySlot:
            RoundedRectangle(cornerRadius: 7.2, style: .continuous)
                .fill(WBColor.controlsSecondary)
                .frame(width: 24, height: 24)
                .overlay {
                    Image("dsPlusBold15")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 15, height: 15)
                        .foregroundStyle(Color(hex: 0xF6F6F9))
                }
        }
    }
}

private struct UniQRInfoCard<Icon: View, Title: View, Subtitle: View>: View {
    let background: Color
    @ViewBuilder var icon: Icon
    @ViewBuilder var title: Title
    @ViewBuilder var subtitle: Subtitle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            icon

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                title
                    .frame(height: 17)
                subtitle
                    .lineLimit(1)
                    .frame(height: 17)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(WBSpace.x3)
        .frame(height: 96)
        .background(background, in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous))
    }
}

private struct UniQRWBPayIcon: View {
    var body: some View {
        Image("uniQRWBLogo24")
            .resizable()
            .frame(width: 24, height: 24)
    }
}

// MARK: - Bottom Bar

private struct UniQRBottomBar: View {
    let title: String
    let subtitle: String
    let onPay: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.tap()
                onPay()
            } label: {
                VStack(spacing: 0) {
                    Text(title)
                        .font(WBFont.hauss(17, .medium))
                        .frame(height: 20)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(WBFont.description)
                            .foregroundStyle(Color(hex: 0xF6F6F9).opacity(0.64))
                            .frame(height: 17)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(WBColor.ctaFill, in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, WBSpace.x2)
            .padding(.horizontal, WBSpace.x2)
            .padding(.bottom, WBSpace.x3)

            Image("dsHomeIndicator")
                .resizable()
                .frame(width: 390, height: 34)
        }
        .frame(width: 390, height: 106, alignment: .top)
        .background(WBColor.bgBase)
    }
}

// MARK: - Account Picker

private struct UniQRAccountPickerSheet: View {
    let title: String
    let accounts: [UniQRTransferAccount]
    let width: CGFloat
    let onSelect: (UniQRTransferAccount) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: WBSpace.x2) {
            dragHandle

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                    accountRows
                }
                .padding(.bottom, WBSpace.x2)

                otherBanksSection

                Image("dsHomeIndicator")
                    .resizable()
                    .frame(width: width, height: 34)
            }
            .frame(width: width)
            .background(
                WBColor.bgBase,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: WBRadius.x6,
                    topTrailingRadius: WBRadius.x6,
                    style: .continuous
                )
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: WBRadius.x6,
                    topTrailingRadius: WBRadius.x6,
                    style: .continuous
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.4))
            .frame(width: 36, height: 5)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: WBSpace.x3) {
            Text(title)
                .font(WBFont.title1)
                .foregroundStyle(WBColor.textPrimary)
                .lineLimit(1)
                .frame(height: 29, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image("dsCross24")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(WBColor.controlsTertiary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WBSpace.x4)
        .padding(.top, 18)
        .padding(.bottom, 1)
    }

    private var accountRows: some View {
        VStack(spacing: 0) {
            ForEach(accounts) { account in
                Button {
                    onSelect(account)
                } label: {
                    accountRow(account)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func accountRow(_ account: UniQRTransferAccount) -> some View {
        HStack(spacing: WBSpace.x3) {
            UniQRSheetAccountIcon(icon: account.icon)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: WBSpace.x0_5) {
                Text(account.title)
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(WBColor.textPrimary)
                    .lineLimit(1)
                    .frame(height: WBLineHeight.body)
                Text(account.subtitle)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textSecondary)
                    .lineLimit(1)
                    .frame(height: WBLineHeight.body)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 63)
        .padding(.horizontal, WBSpace.x4)
        .contentShape(Rectangle())
    }

    private var otherBanksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("На счёт в другой банк")
                .font(WBFont.title3Bold)
                .foregroundStyle(WBColor.textPrimary)
                .frame(height: 24, alignment: .leading)
                .padding(.horizontal, WBSpace.x4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WBSpace.x2) {
                    UniQRBankCard(
                        icon: .asset("dsVTB24"),
                        title: "ВТБ",
                        subtitle: "Янина Н.",
                        background: Color(hex: 0xDFF3FF)
                    )

                    UniQRBankCard(
                        icon: .tBank,
                        title: "Т-Банк",
                        subtitle: "Янина Н.",
                        background: WBColor.bgLevel2
                    )

                    UniQRBankCard(
                        icon: .asset("icSBP"),
                        title: "Выбрать\nбанк",
                        subtitle: nil,
                        background: WBColor.bgLevel2
                    )
                }
                .padding(.horizontal, WBSpace.x4)
                .padding(.top, WBSpace.x2)
                .padding(.bottom, WBSpace.x2)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .background(WBColor.bgBase)
    }
}

private struct UniQRSheetAccountIcon: View {
    let icon: UniQRRecipientIcon

    var body: some View {
        switch icon {
        case .wbAccount:
            Image("icAccountWB")
                .resizable()
                .frame(width: 40, height: 40)
        case .savingsAccount:
            RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
                .fill(WBColor.textAccent)
                .frame(width: 40, height: 40)
                .overlay {
                    Image("icSafe")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)
                }
        default:
            UniQRRecipientIconView(icon: icon)
                .frame(width: 40, height: 40)
        }
    }
}

private enum UniQRBankCardIcon {
    case asset(String)
    case tBank
}

private struct UniQRBankCard: View {
    let icon: UniQRBankCardIcon
    let title: String
    let subtitle: String?
    let background: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            iconView

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(WBFont.descriptionAccent)
                    .foregroundStyle(WBColor.walletActionAccent)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.walletActionAccent)
                        .lineLimit(1)
                        .frame(height: WBLineHeight.description)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(WBSpace.x3)
        .frame(width: 112, height: 96)
        .background(background, in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous))
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .asset(let name):
            Image(name)
                .resizable()
                .frame(width: 24, height: 24)
        case .tBank:
            RoundedRectangle(cornerRadius: WBRadius.x1_5, style: .continuous)
                .fill(WBColor.brandYellow)
                .frame(width: 24, height: 24)
                .overlay {
                    Image("dsTBankMark13")
                        .resizable()
                        .frame(width: 13, height: 13)
                }
        }
    }
}

private struct UniQRPremiumAttentionEffect: GeometryEffect {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = progress.uniQRClampedUnit
        // One damped spring impulse: left, smaller right, smaller left, then rest.
        let spring = -13 * exp(-1.45 * t) * sin(3 * .pi * t)
        let settle = t < 0.82 ? 1 : max(0, 1 - pow((t - 0.82) / 0.18, 2))
        return ProjectionTransform(CGAffineTransform(translationX: spring * settle, y: 0))
    }
}

private extension CGFloat {
    var uniQRClampedUnit: CGFloat {
        Swift.min(Swift.max(self, 0), 1)
    }
}

#Preview {
    UniQRScreen()
}
