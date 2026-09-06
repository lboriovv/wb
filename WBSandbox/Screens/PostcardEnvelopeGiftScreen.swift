import SwiftUI

// MARK: - Хореография конверта

/// Рабочая копия раскрытия подарка: вместо вылета открытки снизу появляется
/// конверт, пользователь проводит по ленте, клапан раскрывается, открытка
/// выезжает из кармана, а сам конверт падает вниз.
struct EnvelopeGiftAnim {
    static let k: Double = 1.0

    var flap: Double { 0.42 * Self.k }
    var cardDelay: Double { 0.30 * Self.k }
    var cardReveal: Double { 1.08 * Self.k }
    var cardBounceDelay: Double { cardDelay + cardReveal }
    var cardBounce: Double { 0.46 * Self.k }
    var envelopeDropDelay: Double { 0.42 * Self.k }
    var envelopeDrop: Double { 0.86 * Self.k }
    var confettiDelay: Double { flap + 0.02 * Self.k }
    var confetti: Double { 2.35 * Self.k }
    var backdropDelay: Double { 0.82 * Self.k }
    var backdrop: Double { 0.48 * Self.k }
    var chromeDelay: Double { 1.42 * Self.k }
    var chrome: Double { 0.36 * Self.k }
    var handoverDelay: Double { 1.36 * Self.k }
    var handover: Double { 0.35 * Self.k }

    var total: Double {
        max(
            confettiDelay + confetti,
            max(cardBounceDelay + cardBounce, chromeDelay + chrome)
        )
            + 0.18 * Self.k
    }
}

// MARK: - Ручки конверта

/// Все числа, которые хочется быстро подкручивать до появления финального
/// дизайна. Когда придёт готовый конверт, этот конфиг останется местом, где
/// меняются пропорции, положение ленты и характер падения.
private struct EnvelopeRevealConfig {
    var maxWidth: CGFloat = 336
    var sideInset: CGFloat = 54
    /// Высота как доля ширины.
    var aspectRatio: CGFloat = 753.0 / 1080.0
    /// Глубина верхнего клапана как доля высоты конверта.
    var flapDepthRatio: CGFloat = 0.50
    /// Точка схождения нижнего кармана.
    var pocketFoldRatio: CGFloat = 0.54
    /// Верхняя кромка переднего кармана. Чем ниже, тем дольше открытка реально
    /// сидит внутри конверта, а не летит поверх него.
    var pocketLipRatio: CGFloat = 0.38
    /// Ленту можно заменить на `.vertical(position: 0.5)` или подвинуть ближе к
    /// любому краю.
    var seam: EnvelopeSeam = .horizontal(position: 504.0 / 753.0)
    var sealThicknessRatio: CGFloat = 18.0 / 753.0
    var sealInsetRatio: CGFloat = 24.0 / 1080.0
    var sealDashRatio: CGFloat = 60.0 / 1080.0
    var sealGapRatio: CGFloat = 48.0 / 1080.0
    var sealBaseOpacity: Double = 0.20
    var sealShineOpacity: Double = 0.40
    var sealShineWidthRatio: CGFloat = 360.0 / 1080.0
    var sealShineRunDuration: TimeInterval = 2.35
    var sealShinePauseDuration: TimeInterval = 1.55
    /// Насколько крышка приподнимается прямо под пальцем во время реза.
    var cutLiftDegrees: CGFloat = 30
    /// 0.625 — середина первой четверти нижней половины экрана.
    var envelopeVerticalPosition: CGFloat = 0.625
    var cardStartScale: CGFloat = 0.34
    var cardFinalScale: CGFloat = 264.0 / 310.0
    var cardStartOffsetY: CGFloat = 54
    var cardLandingBounceY: CGFloat = 14
    var dropRotation: Double = 24
    var dropShrink: CGFloat = 0.70
    var textures = EnvelopeTextureConfig()
}

private struct EnvelopeTextureConfig {
    /// Внешняя задняя сторона конверта.
    var backExterior: String? = "envelopeBodyBack"
    /// Передний карман/лицевая нижняя часть.
    var frontExterior: String? = "envelopeBodyFront"
    /// Тень между открыткой и передней частью кармана.
    var pocketShadow: String? = "envelopeShadow"
    /// Внешняя сторона прямоугольной крышки.
    var flapExterior: String? = "envelopeCapFront"
    /// Внутренняя сторона крышки, которая видна при раскрытии.
    var flapInterior: String? = "envelopeCapBack"
    var hasBodyArtwork: Bool {
        backExterior != nil || frontExterior != nil || pocketShadow != nil
    }

    var hasCapArtwork: Bool {
        flapExterior != nil || flapInterior != nil
    }
}

private enum EnvelopeSeam {
    case horizontal(position: CGFloat)
    case vertical(position: CGFloat)

    var isHorizontal: Bool {
        if case .horizontal = self { return true }
        return false
    }

    var position: CGFloat {
        switch self {
        case .horizontal(let position), .vertical(let position):
            return clamp01(position)
        }
    }

    func dragProgress(location: CGPoint, in size: CGSize) -> CGFloat {
        let main = isHorizontal ? location.x : location.y
        let length = max(1, isHorizontal ? size.width : size.height)
        let inset = length * (isHorizontal ? 24.0 / 1080.0 : 24.0 / 753.0)
        return clamp01((main - inset) / max(1, length - inset * 2))
    }
}

// MARK: - Экран

struct PostcardEnvelopeGiftScreen: View {
    var cards: [Postcard] = PostcardCatalog.all
    var onThanks: () -> Void = {}
    let onClose: () -> Void

    @State private var motion = TiltMotionService()
    @State private var tearProgress: CGFloat = 0
    @State private var tearHapticStep = 0
    @State private var openedAt: Date?
    @State private var isRevealing = false

    private let anim = EnvelopeGiftAnim()
    private let config = EnvelopeRevealConfig()
    private let messageText = "Ещё раз тебя с днём рождения и счастья!"

    private enum Metrics {
        static let navRow: CGFloat = 48
        static let sideInset: CGFloat = 8
        static let buttonHeight: CGFloat = 52
        static let panelTopPadding: CGFloat = 8
        static let panelRadius: CGFloat = 24
        static let figmaScreenHeight: CGFloat = 844
        static let messageCenterYRatio: CGFloat = 137.5 / figmaScreenHeight
        static let cardCenterYRatio: CGFloat = 394.5 / figmaScreenHeight
        static let messageToCardGap: CGFloat = 36
    }

    private var card: Postcard {
        let index = SandboxSettings.startCard ?? 0
        return cards[cards.indices.contains(index) ? index : 0]
    }

    private var isOpen: Bool { openedAt != nil }

    private var liveTilt: TiltInput {
        var value = TiltInput.from(motion: motion)
        if let fixed = SandboxSettings.tilt {
            value.pitch += fixed.pitch
            value.yaw += fixed.yaw
        }
        return value
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let width = proxy.size.width
            let height = proxy.size.height + topInset + proxy.safeAreaInsets.bottom

            let panelHeight = Metrics.panelTopPadding + Metrics.buttonHeight
                + proxy.safeAreaInsets.bottom
            let panelTop = height - panelHeight
            let finalCardHalfHeight = PostcardMetrics.cardSize.height * config.cardFinalScale / 2
            let messageCenterY = height * Metrics.messageCenterYRatio
            let desiredCardCenterY = height * Metrics.cardCenterYRatio
            let minCardCenterY = messageCenterY
                + EnvelopeGiftMessageView.size.height / 2
                + Metrics.messageToCardGap
                + finalCardHalfHeight
            let maxCardCenterY = panelTop - finalCardHalfHeight - 24
            let cardCenterY = min(maxCardCenterY, max(minCardCenterY, desiredCardCenterY))

            let stage = Stage(
                width: width,
                height: height,
                panelTop: panelTop,
                panelHeight: panelHeight,
                cardCenterY: cardCenterY,
                topInset: topInset
            )

            Group {
                if let demoElapsed = SandboxSettings.giftElapsed {
                    frame(at: demoElapsed, stage: stage)
                } else if isRevealing, let openedAt {
                    TimelineView(.animation) { context in
                        frame(at: context.date.timeIntervalSince(openedAt), stage: stage)
                    }
                } else {
                    frame(at: isOpen ? anim.total : 0, stage: stage)
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .offset(y: -topInset)
        }
        .onAppear {
            motion.start()
            if SandboxSettings.giftOpened || SandboxSettings.giftElapsed != nil {
                tearProgress = 1
                openedAt = .distantPast
            }
        }
        .onDisappear { motion.stop() }
    }

    private struct Stage {
        let width: CGFloat
        let height: CGFloat
        let panelTop: CGFloat
        let panelHeight: CGFloat
        let cardCenterY: CGFloat
        let topInset: CGFloat
    }

    // MARK: Кадр

    private func frame(at elapsed: TimeInterval, stage: Stage) -> some View {
        let envelopeSize = envelopeSize(for: stage.width)
        let envelopeCenter = envelopeCenter(stage: stage, envelopeSize: envelopeSize)

        let flapP = isOpen ? prog(elapsed, 0, anim.flap) : 0
        let cardP = isOpen ? prog(elapsed, anim.cardDelay, anim.cardReveal) : 0
        let dropP = isOpen ? prog(elapsed, anim.envelopeDropDelay, anim.envelopeDrop) : 0
        let backdropP = isOpen ? prog(elapsed, anim.backdropDelay, anim.backdrop) : 0
        let chromeP = isOpen ? prog(elapsed, anim.chromeDelay, anim.chrome) : 0
        let handover = isOpen ? Double(prog(elapsed, anim.handoverDelay, anim.handover)) : 0
        let landingBounceP = isOpen ? prog(elapsed, anim.cardBounceDelay, anim.cardBounce) : 0

        let cutLift = clamp01(config.cutLiftDegrees / 180)
        let flapOpen = isOpen
            ? cutLift + (1 - cutLift) * Ease.move(flapP)
            : cutLift * Ease.move(tearProgress)
        // Один сырой прогресс ведет открытку из конверта в финальную позицию:
        // без промежуточных ключей, только с разными easing-профилями.
        let cardFlight = cubicBezierProgress(cardP, x1: 0.62, y1: 0.00, x2: 0.12, y2: 1.00)
        let cardTurnFlight = cubicBezierProgress(cardP, x1: 0.56, y1: 0.00, x2: 0.14, y2: 1.00)
        let cardScaleFlight = cubicBezierProgress(cardP, x1: 0.74, y1: 0.00, x2: 0.22, y2: 1.00)
        let cardReleaseP = Ease.appear(
            prog(elapsed, anim.envelopeDropDelay + anim.envelopeDrop * 0.28, anim.envelopeDrop * 0.24)
        )
        let envelopeFall = envelopeFallProgress(dropP)
        let envelopeFade = Ease.appear(
            prog(elapsed, anim.envelopeDropDelay + anim.envelopeDrop * 0.62, anim.envelopeDrop * 0.34)
        )
        let capLayerZ = cardP > 0.001 ? 2.85 : 4.25

        let startCardY = envelopeCenter.y + config.cardStartOffsetY
        let landingBounceY = config.cardLandingBounceY * landingBounce(landingBounceP)
        let cardArcY = -24 * CGFloat(sin(Double(cardFlight) * .pi))
        let cardY = lerp(startCardY, stage.cardCenterY, cardFlight)
            + cardArcY
            + landingBounceY
        let cardScale = lerp(config.cardStartScale, config.cardFinalScale, cardScaleFlight)
        let cardRotation = 90 * Double(1 - cardTurnFlight)

        let dropDistance = stage.height - envelopeCenter.y + envelopeSize.height * 0.7
        let envelopeY = envelopeCenter.y + envelopeFall * dropDistance
        let envelopeX = envelopeCenter.x + 28 * envelopeFall
        let envelopeKick = 0.022 * overshootPulse(prog(elapsed, 0, anim.flap * 0.92))
        let envelopeScale = 1 + envelopeKick - config.dropShrink * envelopeFall
        let envelopeYaw = -18 * Double(envelopeFall)
        let confettiOrigin = CGPoint(
            x: stage.width / 2,
            y: envelopeCenter.y - envelopeSize.height * 0.04
        )
        let closedFade = isOpen ? Ease.appear(prog(elapsed, 0, anim.backdropDelay)) : 0

        return ZStack(alignment: .topLeading) {
            WBColor.bgBase
                .frame(width: stage.width, height: stage.height)

            PostcardFace(card: card)
                .frame(width: stage.width, height: stage.height)
                .blur(radius: 60)
                .scaleEffect(1.25)
                .opacity(Double(Ease.appear(backdropP)))
                .clipped()
                .allowsHitTesting(false)

            WBColor.bgBase.opacity(0.88)
                .frame(width: stage.width, height: stage.height)
                .allowsHitTesting(false)

            backChevron
                .position(x: 4 + 22, y: stage.topInset + Metrics.navRow / 2)
                .opacity(1 - Double(closedFade))
                .allowsHitTesting(!isOpen)

            if isOpen {
                EnvelopeBackLayerView(config: config)
                    .frame(width: envelopeSize.width, height: envelopeSize.height)
                    .scaleEffect(envelopeScale)
                    .rotation3DEffect(
                        .degrees(envelopeYaw),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.62
                    )
                    .rotationEffect(.degrees(config.dropRotation * Double(envelopeFall)))
                    .opacity(1 - Double(envelopeFade))
                    .position(x: envelopeX, y: envelopeY)
                    .allowsHitTesting(false)
                    .zIndex(1)

                EnvelopeConfettiField(
                    elapsed: elapsed,
                    start: anim.confettiDelay,
                    duration: anim.confetti,
                    origin: confettiOrigin,
                    layer: .background
                )
                .frame(width: stage.width, height: stage.height)
                .allowsHitTesting(false)
                .zIndex(2.2)

                giftCardLayer(
                    handover: handover,
                    scale: cardScale,
                    rotation: cardRotation,
                    y: cardY,
                    stage: stage,
                    envelopeBottom: envelopeY + envelopeSize.height * envelopeScale / 2,
                    releaseProgress: cardReleaseP
                )
                    .zIndex(3)

                EnvelopeConfettiField(
                    elapsed: elapsed,
                    start: anim.confettiDelay,
                    duration: anim.confetti,
                    origin: confettiOrigin,
                    layer: .foregroundBurst
                )
                .frame(width: stage.width, height: stage.height)
                .allowsHitTesting(false)
                .zIndex(3.35)

                EnvelopeFrontLayerView(
                    config: config,
                    sealProgress: 1,
                    isInteractive: false,
                    showsSeal: false,
                    showsCutHint: true
                )
                .frame(width: envelopeSize.width, height: envelopeSize.height)
                .scaleEffect(envelopeScale)
                .rotation3DEffect(
                    .degrees(envelopeYaw),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.62
                )
                .rotationEffect(.degrees(config.dropRotation * Double(envelopeFall)))
                .opacity(1 - Double(envelopeFade))
                .position(x: envelopeX, y: envelopeY)
                .allowsHitTesting(false)
                .zIndex(4)

                EnvelopeCapLayerView(config: config, openProgress: flapOpen)
                    .frame(width: envelopeSize.width, height: envelopeSize.height)
                    .scaleEffect(envelopeScale)
                    .rotation3DEffect(
                        .degrees(envelopeYaw),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.62
                    )
                    .rotationEffect(.degrees(config.dropRotation * Double(envelopeFall)))
                    .opacity(1 - Double(envelopeFade))
                    .position(x: envelopeX, y: envelopeY)
                    .allowsHitTesting(false)
                    .zIndex(capLayerZ)

            } else {
                envelope(
                    size: envelopeSize,
                    openProgress: flapOpen,
                    sealProgress: tearProgress,
                    isInteractive: true
                )
                .position(x: envelopeCenter.x, y: envelopeCenter.y)
                .zIndex(4)
            }

            if isOpen {
                EnvelopeGiftMessageView(message: messageText)
                    .position(
                        x: stage.width / 2,
                        y: stage.height * Metrics.messageCenterYRatio
                    )
                    .reveal(chromeP, rise: 8)
                    .allowsHitTesting(false)
                    .zIndex(7)

                Group {
                    openedNavigationBar(width: stage.width)
                        .offset(y: stage.topInset)
                        .reveal(chromeP, rise: 10)

                    panel(title: "Сказать спасибо", stage: stage) { onThanks() }
                        .reveal(chromeP, rise: 28)
                        .offset(y: stage.panelTop)
                }
                .allowsHitTesting(chromeP > 0.9)
                .zIndex(8)
            }
        }
        .frame(width: stage.width, height: stage.height, alignment: .topLeading)
    }

    private func envelope(
        size: CGSize,
        openProgress: CGFloat,
        sealProgress: CGFloat,
        isInteractive: Bool
    ) -> some View {
        EnvelopePackageView(
            config: config,
            openProgress: openProgress,
            sealProgress: sealProgress,
            isInteractive: isInteractive
        )
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(tearGesture(envelopeSize: size))
        .accessibilityLabel("Открыть конверт")
    }

    private func giftCardLayer(
        handover: Double,
        scale: CGFloat,
        rotation: Double,
        y: CGFloat,
        stage: Stage,
        envelopeBottom: CGFloat,
        releaseProgress: CGFloat
    ) -> some View {
        let visibleBottom = lerp(
            envelopeBottom - 2,
            stage.height + PostcardMetrics.cardSize.height,
            releaseProgress
        )

        return ZStack(alignment: .topLeading) {
            giftCard(handover: handover)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .position(x: stage.width / 2, y: y)
        }
        .frame(width: stage.width, height: stage.height, alignment: .topLeading)
        .mask {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.white)
                    .frame(width: stage.width, height: max(0, visibleBottom))

                Spacer(minLength: 0)
            }
            .frame(width: stage.width, height: stage.height, alignment: .top)
        }
    }

    private func giftCard(handover: Double) -> some View {
        let tilt = TiltInput.blend(TiltInput(), liveTilt, handover)

        return GlossyPostcardView(card: card, tilt: tilt)
            .modifier(
                CardTiltEffect(
                    pitch: tilt.rotationPitch * handover,
                    yaw: tilt.rotationYaw * handover
                )
            )
            .contentShape(
                RoundedRectangle(cornerRadius: PostcardMetrics.cornerRadius, style: .continuous)
            )
            .allowsHitTesting(false)
            .shadow(color: .black.opacity(0.18), radius: 26, y: 15)
    }

    private func landingBounce(_ progress: CGFloat) -> CGFloat {
        let p = clamp01(progress)
        let dipEnd: CGFloat = 0.38

        if p < dipEnd {
            return cubicBezierProgress(p / dipEnd, x1: 0.18, y1: 0.00, x2: 0.32, y2: 1.00)
        }

        let riseP = (p - dipEnd) / (1 - dipEnd)
        let easedRise = cubicBezierProgress(riseP, x1: 0.16, y1: 0.00, x2: 0.12, y2: 1.00)
        return 1 - easedRise
    }

    private func envelopeFallProgress(_ progress: CGFloat) -> CGFloat {
        cubicBezierProgress(progress, x1: 0.24, y1: 0.00, x2: 0.12, y2: 1.00)
    }

    private func cubicBezierProgress(
        _ progress: CGFloat,
        x1: CGFloat,
        y1: CGFloat,
        x2: CGFloat,
        y2: CGFloat
    ) -> CGFloat {
        let target = clamp01(progress)
        var t = target

        for _ in 0..<6 {
            let x = cubicBezierValue(t, 0, x1, x2, 1)
            let dx = cubicBezierDerivative(t, 0, x1, x2, 1)
            guard abs(dx) > 0.0001 else { break }
            t = clamp01(t - (x - target) / dx)
        }

        return cubicBezierValue(t, 0, y1, y2, 1)
    }

    private func cubicBezierValue(
        _ t: CGFloat,
        _ p0: CGFloat,
        _ p1: CGFloat,
        _ p2: CGFloat,
        _ p3: CGFloat
    ) -> CGFloat {
        let u = 1 - t
        return u * u * u * p0
            + 3 * u * u * t * p1
            + 3 * u * t * t * p2
            + t * t * t * p3
    }

    private func cubicBezierDerivative(
        _ t: CGFloat,
        _ p0: CGFloat,
        _ p1: CGFloat,
        _ p2: CGFloat,
        _ p3: CGFloat
    ) -> CGFloat {
        let u = 1 - t
        return 3 * u * u * (p1 - p0)
            + 6 * u * t * (p2 - p1)
            + 3 * t * t * (p3 - p2)
    }

    private func envelopeSize(for width: CGFloat) -> CGSize {
        let envelopeWidth = min(config.maxWidth, max(260, width - config.sideInset * 2))
        return CGSize(width: envelopeWidth, height: envelopeWidth * config.aspectRatio)
    }

    private func envelopeCenter(stage: Stage, envelopeSize: CGSize) -> CGPoint {
        let minY = stage.topInset + Metrics.navRow + envelopeSize.height / 2 + 12
        let maxY = stage.panelTop - envelopeSize.height / 2 - 22
        let desiredY = stage.height * config.envelopeVerticalPosition
        return CGPoint(x: stage.width / 2, y: min(maxY, max(minY, desiredY)))
    }

    // MARK: Жест

    private func tearGesture(envelopeSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !isOpen else { return }
                let progress = config.seam.dragProgress(location: value.location, in: envelopeSize)
                let nextProgress = max(tearProgress, progress)
                if nextProgress > tearProgress {
                    tearProgress = nextProgress
                    playTearHapticIfNeeded(progress: nextProgress)
                }
                if tearProgress >= 0.98 {
                    reveal()
                }
            }
            .onEnded { _ in
                guard !isOpen else { return }
                tearHapticStep = 0
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    tearProgress = 0
                }
            }
    }

    private func playTearHapticIfNeeded(progress: CGFloat) {
        let steps = 12
        let step = min(steps, max(0, Int((progress * CGFloat(steps)).rounded(.down))))
        guard step > tearHapticStep else { return }

        tearHapticStep = step
        Haptics.key()
    }

    private func reveal() {
        guard !isOpen else { return }
        tearProgress = 1
        tearHapticStep = 0
        openedAt = Date()
        isRevealing = true
        Haptics.impact(.rigid)

        DispatchQueue.main.asyncAfter(deadline: .now() + anim.flap * 0.58) {
            Haptics.impact(.soft)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + anim.envelopeDropDelay) {
            Haptics.impact(.medium)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + anim.cardBounceDelay) {
            Haptics.impact(.light)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + anim.total) {
            isRevealing = false
        }
    }

    // MARK: Шапка и кнопка

    private func openedNavigationBar(width: CGFloat) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Text("Вам открытка")
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(WBColor.textPrimary)
                    .frame(height: WBLineHeight.body)

                Text("От Леонида Б.")
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .frame(height: WBLineHeight.description)
            }

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                closeButton
            }
            .padding(.horizontal, WBSpace.x1)
        }
        .frame(width: width, height: Metrics.navRow)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            DSIconView(icon: .close)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Закрыть")
    }

    private var backChevron: some View {
        Button(action: onClose) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(WBColor.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Назад")
    }

    private func panel(
        title: String,
        stage: Stage,
        action: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: Metrics.panelRadius,
                topTrailingRadius: Metrics.panelRadius,
                style: .continuous
            )
            .fill(WBColor.bgBase)

            WBPrimaryButton(title: title, action: action)
                .frame(
                    width: stage.width - Metrics.sideInset * 2,
                    height: Metrics.buttonHeight
                )
                .offset(y: Metrics.panelTopPadding)
        }
        .frame(width: stage.width, height: stage.panelHeight, alignment: .top)
    }
}

// MARK: - Сообщение поздравителя

private struct EnvelopeGiftMessageView: View {
    static let size = CGSize(width: 316, height: 91)

    let message: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            messageBackground
                .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: -4)

            Text(message)
                .font(WBFont.description)
                .foregroundStyle(WBColor.textPrimary)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.86)
                .frame(width: 252, height: WBLineHeight.description)
                .position(x: 158, y: 58.5)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var messageBackground: some View {
        ZStack(alignment: .topLeading) {
            Image("postcardMessageDot")
                .resizable()
                .frame(width: 8, height: 8)
                .position(x: 228, y: 24)

            Image("postcardMessageTail")
                .resizable()
                .frame(width: 16, height: 16)
                .position(x: 236, y: 40)

            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(WBColor.bgBase)
                .frame(width: 284, height: 41)
                .position(x: 158, y: 58.5)
        }
    }
}

// MARK: - Конверт

private struct EnvelopePackageView: View {
    let config: EnvelopeRevealConfig
    let openProgress: CGFloat
    let sealProgress: CGFloat
    let isInteractive: Bool

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack(alignment: .topLeading) {
                EnvelopeBackBoardView(textureAsset: config.textures.backExterior)
                    .mask { EnvelopeArtworkSilhouetteMask(config: config) }
                    .shadow(color: .black.opacity(0.13), radius: 22, y: 12)

                EnvelopePocketShadowView(config: config)
                    .zIndex(1.5)

                EnvelopeFrontPocketView(config: config)
                    .zIndex(2)

                EnvelopeCapLayerView(config: config, openProgress: openProgress)
                    .frame(width: size.width, height: size.height)
                    .zIndex(3)

                EnvelopeSealView(
                    config: config,
                    progress: sealProgress,
                    isInteractive: isInteractive
                )
                .zIndex(4)

                EnvelopeCutHintView(config: config)
                    .zIndex(4.1)
            }
        }
    }
}

private struct EnvelopeBackLayerView: View {
    let config: EnvelopeRevealConfig

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                EnvelopeBackBoardView(textureAsset: config.textures.backExterior)
                    .mask { EnvelopeArtworkSilhouetteMask(config: config) }
                    .shadow(color: .black.opacity(0.13), radius: 22, y: 12)
            }
        }
    }
}

private struct EnvelopeFrontLayerView: View {
    let config: EnvelopeRevealConfig
    let sealProgress: CGFloat
    let isInteractive: Bool
    var showsSeal: Bool = true
    var showsCutHint: Bool = false

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                EnvelopePocketShadowView(config: config)

                EnvelopeFrontPocketView(config: config)
                    .shadow(color: .black.opacity(config.textures.hasBodyArtwork ? 0.03 : 0.08), radius: 12, y: 5)

                if showsSeal {
                    EnvelopeSealView(
                        config: config,
                        progress: sealProgress,
                        isInteractive: isInteractive
                    )
                }

                if showsCutHint {
                    EnvelopeCutHintView(config: config)
                }
            }
        }
    }
}

private struct EnvelopeBackBoardView: View {
    let textureAsset: String?

    var body: some View {
        if let textureAsset {
            EnvelopeTextureLayer(assetName: textureAsset)
        } else {
            LinearGradient(
                colors: [
                    Color.dynamic(light: 0xFFF8FE, dark: 0x342B35),
                    Color.dynamic(light: 0xEEF5FF, dark: 0x202B38),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            EnvelopePaperTexture()
                .opacity(0.58)

            LinearGradient(
                colors: [
                    .white.opacity(0.32),
                    .clear,
                    WBColor.violet.opacity(0.10),
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct EnvelopeFrontPocketView: View {
    let config: EnvelopeRevealConfig

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let crease = Color.dynamic(light: 0xDDD9EA, dark: 0x4A4357)

            if let frontExterior = config.textures.frontExterior {
                EnvelopeTextureLayer(assetName: frontExterior)
            } else {
                ZStack {
                    EnvelopePocketShape(config: config)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.dynamic(light: 0xFFFAFE, dark: 0x342B36),
                                    Color.dynamic(light: 0xF4F8FF, dark: 0x222D3A),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    EnvelopePaperTexture()
                        .clipShape(EnvelopePocketShape(config: config))
                        .opacity(0.48)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.26),
                                    .clear,
                                    WBColor.brandBlue.opacity(0.05),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(EnvelopePocketShape(config: config))

                    EnvelopeFoldLines(config: config, color: crease)
                        .frame(width: size.width, height: size.height)

                    EnvelopePocketShape(config: config)
                        .stroke(crease.opacity(0.86), lineWidth: 1)

                    EnvelopePocketMouthShadow(config: config, color: crease)
                }
            }
        }
    }
}

private struct EnvelopePocketShadowView: View {
    let config: EnvelopeRevealConfig

    var body: some View {
        GeometryReader { _ in
            if let pocketShadow = config.textures.pocketShadow {
                EnvelopeTextureLayer(assetName: pocketShadow)
                    .mask { EnvelopeArtworkSilhouetteMask(config: config) }
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct EnvelopePocketMouthShadow: View {
    let config: EnvelopeRevealConfig
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let path = mouthPath(in: CGRect(origin: .zero, size: geo.size))

            ZStack {
                path
                    .stroke(
                        .black.opacity(0.10),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 3)
                    .offset(y: 3)

                path
                    .stroke(
                        .white.opacity(0.68),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                    )

                path
                    .stroke(
                        color.opacity(0.68),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                    )
                    .offset(y: 0.5)
            }
        }
        .allowsHitTesting(false)
    }

    private func mouthPath(in rect: CGRect) -> Path {
        let h = rect.height
        let lipY = h * config.pocketLipRatio

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + lipY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + lipY))
        return path
    }
}

private struct EnvelopeTopFlapView: View {
    let config: EnvelopeRevealConfig
    let openProgress: CGFloat

    var body: some View {
        let interior = Ease.appear(clamp01((openProgress - 0.20) / 0.48))

        EnvelopeFlapShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color.dynamic(light: 0xFFF8FE, dark: 0x3A303B),
                        Color.dynamic(light: 0xF3F6FF, dark: 0x253040),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                EnvelopePaperTexture()
                    .clipShape(EnvelopeFlapShape())
                    .opacity(0.58)
            }
            .overlay {
                ZStack {
                    EnvelopeTextureLayer(assetName: config.textures.flapExterior)
                        .opacity(1 - Double(interior))

                    EnvelopeTextureLayer(assetName: config.textures.flapInterior)
                        .opacity(Double(interior))
                }
                .clipShape(EnvelopeFlapShape())
            }
            .overlay {
                EnvelopeFlapShape()
                    .stroke(Color.dynamic(light: 0xDDD9EA, dark: 0x4A4357), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(0.10 * Double(1 - openProgress)),
                radius: 12,
                y: 6
            )
            .rotation3DEffect(
                .degrees(-148 * Double(openProgress)),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: 0.68
            )
            .scaleEffect(y: 1 - openProgress * 0.08, anchor: .top)
            .offset(y: -openProgress * 5)
    }
}

private struct EnvelopeCapLayerView: View {
    let config: EnvelopeRevealConfig
    let openProgress: CGFloat

    var body: some View {
        GeometryReader { geo in
            if config.textures.hasCapArtwork {
                let size = geo.size
                let capHeight = size.height * config.seam.position
                let flip = clamp01(openProgress)
                let rotation = 180 * Double(flip)
                let showsFront = rotation < 90

                ZStack(alignment: .topLeading) {
                    capArtworkFace(
                        assetName: config.textures.flapInterior,
                        side: .back,
                        size: size,
                        capHeight: capHeight
                    )
                    .rotation3DEffect(
                        .degrees(180),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .center,
                        perspective: 0
                    )
                    .opacity(showsFront ? 0 : 1)
                    .zIndex(0)

                    capArtworkFace(
                        assetName: config.textures.flapExterior,
                        side: .front,
                        size: size,
                        capHeight: capHeight
                    )
                    .opacity(showsFront ? 1 : 0)
                    .zIndex(1)
                }
                .frame(width: size.width, height: capHeight, alignment: .topLeading)
                .compositingGroup()
                .shadow(
                    color: .black.opacity(0.16 * Double(1 - flip)),
                    radius: 14,
                    y: 8
                )
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .top,
                    perspective: 0.46
                )
                .frame(width: size.width, height: size.height, alignment: .topLeading)
            } else {
                EnvelopeTopFlapView(config: config, openProgress: openProgress)
                    .frame(
                        width: geo.size.width,
                        height: geo.size.height * config.flapDepthRatio,
                        alignment: .top
                    )
            }
        }
    }

    private enum CapArtworkSide {
        case front
        case back
    }

    @ViewBuilder
    private func capArtworkFace(
        assetName: String?,
        side: CapArtworkSide,
        size: CGSize,
        capHeight: CGFloat
    ) -> some View {
        if let assetName {
            ZStack(alignment: .topLeading) {
                EnvelopeTextureLayer(assetName: assetName)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .offset(y: side == .back ? -(size.height - capHeight) : 0)
            }
            .frame(width: size.width, height: capHeight, alignment: .topLeading)
            .clipped()
        }
    }
}

private struct EnvelopeCutHintView: View {
    let config: EnvelopeRevealConfig

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let position = hintPosition(in: size)

            Text("Проведите по линии")
                .font(WBFont.description)
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(1)
                .frame(width: size.width, height: WBLineHeight.description)
                .position(position)
        }
        .allowsHitTesting(false)
    }

    private func hintPosition(in size: CGSize) -> CGPoint {
        if config.seam.isHorizontal {
            let seamY = size.height * config.seam.position
            let offset = size.height * (20.0 / 753.0)
            let y = seamY + offset + WBLineHeight.description / 2
            return CGPoint(
                x: size.width / 2,
                y: min(size.height - WBLineHeight.description / 2, y)
            )
        }

        let seamX = size.width * config.seam.position
        let offset = size.width * (20.0 / 1080.0)
        let x = seamX + offset + 90
        return CGPoint(
            x: min(size.width - 90, max(90, x)),
            y: size.height / 2
        )
    }
}

private struct EnvelopeSealView: View {
    let config: EnvelopeRevealConfig
    let progress: CGFloat
    let isInteractive: Bool

    var body: some View {
        GeometryReader { geo in
            if isInteractive && progress < 0.002 {
                TimelineView(.animation) { context in
                    sealContent(size: geo.size, time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                sealContent(size: geo.size, time: 0)
            }
        }
    }

    @ViewBuilder
    private func sealContent(size: CGSize, time: TimeInterval) -> some View {
        if config.seam.isHorizontal {
            horizontalSeal(size: size, time: time)
        } else {
            verticalSeal(size: size, time: time)
        }
    }

    private func horizontalSeal(size: CGSize, time: TimeInterval) -> some View {
        let strokeWidth = size.height * config.sealThicknessRatio
        let inset = size.width * config.sealInsetRatio
        let dash = size.width * config.sealDashRatio
        let dashGap = size.width * config.sealGapRatio
        let y = size.height * config.seam.position
        let lineStart = inset
        let lineEnd = size.width - inset
        let lineLength = max(1, lineEnd - lineStart)
        let cut = lineStart + lineLength * progress
        let cutGap = max(strokeWidth * 2.4, dashGap * 0.40)
        let phase = shinePhase(at: time)

        return ZStack(alignment: .topLeading) {
            dashLine(
                from: CGPoint(x: lineStart, y: y),
                to: CGPoint(x: lineEnd, y: y),
                strokeWidth: strokeWidth,
                dash: dash,
                gap: dashGap,
                opacity: config.sealBaseOpacity
            )
                .mask {
                    horizontalSealMask(
                        size: size,
                        lineStart: lineStart,
                        lineEnd: lineEnd,
                        cut: cut,
                        gap: cutGap,
                        capPadding: strokeWidth / 2 + 1
                    )
                }

            if isInteractive && progress < 0.002, let phase {
                dashLine(
                    from: CGPoint(x: lineStart, y: y),
                    to: CGPoint(x: lineEnd, y: y),
                    strokeWidth: strokeWidth,
                    dash: dash,
                    gap: dashGap,
                    opacity: config.sealShineOpacity
                )
                .mask {
                    horizontalShineMask(
                        size: size,
                        y: y,
                        strokeWidth: strokeWidth,
                        lineStart: lineStart,
                        lineEnd: lineEnd,
                        phase: phase
                    )
                }
            }

        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
    }

    private func verticalSeal(size: CGSize, time: TimeInterval) -> some View {
        let strokeWidth = size.height * config.sealThicknessRatio
        let inset = size.height * (24.0 / 753.0)
        let dash = size.height * (60.0 / 753.0)
        let dashGap = size.height * (48.0 / 753.0)
        let x = size.width * config.seam.position
        let lineStart = inset
        let lineEnd = size.height - inset
        let lineLength = max(1, lineEnd - lineStart)
        let cut = lineStart + lineLength * progress
        let cutGap = max(strokeWidth * 2.4, dashGap * 0.40)
        let phase = shinePhase(at: time)

        return ZStack(alignment: .topLeading) {
            dashLine(
                from: CGPoint(x: x, y: lineStart),
                to: CGPoint(x: x, y: lineEnd),
                strokeWidth: strokeWidth,
                dash: dash,
                gap: dashGap,
                opacity: config.sealBaseOpacity
            )
                .mask {
                    verticalSealMask(
                        size: size,
                        lineStart: lineStart,
                        lineEnd: lineEnd,
                        cut: cut,
                        gap: cutGap,
                        capPadding: strokeWidth / 2 + 1
                    )
                }

            if isInteractive && progress < 0.002, let phase {
                dashLine(
                    from: CGPoint(x: x, y: lineStart),
                    to: CGPoint(x: x, y: lineEnd),
                    strokeWidth: strokeWidth,
                    dash: dash,
                    gap: dashGap,
                    opacity: config.sealShineOpacity
                )
                .mask {
                    verticalShineMask(
                        size: size,
                        x: x,
                        strokeWidth: strokeWidth,
                        lineStart: lineStart,
                        lineEnd: lineEnd,
                        phase: phase
                    )
                }
            }

        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
    }

    private func horizontalSealMask(
        size: CGSize,
        lineStart: CGFloat,
        lineEnd: CGFloat,
        cut: CGFloat,
        gap: CGFloat,
        capPadding: CGFloat
    ) -> some View {
        let rightX = min(lineEnd + capPadding, cut + gap / 2)
        let rightWidth = max(0, lineEnd + capPadding - rightX)

        return ZStack(alignment: .leading) {
            if progress < 0.002 {
                Rectangle()
                    .fill(.white)
                    .frame(width: lineEnd - lineStart + capPadding * 2, height: size.height)
                    .offset(x: lineStart - capPadding)
            } else if rightWidth > 1 {
                Rectangle()
                    .fill(.white)
                    .frame(width: rightWidth, height: size.height)
                    .offset(x: rightX)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .leading)
    }

    private func verticalSealMask(
        size: CGSize,
        lineStart: CGFloat,
        lineEnd: CGFloat,
        cut: CGFloat,
        gap: CGFloat,
        capPadding: CGFloat
    ) -> some View {
        let bottomY = min(lineEnd + capPadding, cut + gap / 2)
        let bottomHeight = max(0, lineEnd + capPadding - bottomY)

        return ZStack(alignment: .top) {
            if progress < 0.002 {
                Rectangle()
                    .fill(.white)
                    .frame(width: size.width, height: lineEnd - lineStart + capPadding * 2)
                    .offset(y: lineStart - capPadding)
            } else if bottomHeight > 1 {
                Rectangle()
                    .fill(.white)
                    .frame(width: size.width, height: bottomHeight)
                    .offset(y: bottomY)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private func dashLine(
        from start: CGPoint,
        to end: CGPoint,
        strokeWidth: CGFloat,
        dash: CGFloat,
        gap: CGFloat,
        opacity: Double
    ) -> some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            .white.opacity(opacity),
            style: StrokeStyle(
                lineWidth: strokeWidth,
                lineCap: .round,
                lineJoin: .round,
                dash: [dash, gap]
            )
        )
    }

    private func horizontalShineMask(
        size: CGSize,
        y: CGFloat,
        strokeWidth: CGFloat,
        lineStart: CGFloat,
        lineEnd: CGFloat,
        phase: CGFloat
    ) -> some View {
        let shineWidth = max(strokeWidth * 10, size.width * config.sealShineWidthRatio)
        let shineHeight = max(strokeWidth * 5, 24)
        let x = lineStart - shineWidth + (lineEnd - lineStart + shineWidth * 2) * phase

        return ZStack(alignment: .topLeading) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.48),
                    .init(color: .white, location: 0.56),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: shineWidth, height: shineHeight)
            .blur(radius: strokeWidth * 0.25)
            .offset(x: x, y: y - shineHeight / 2)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func verticalShineMask(
        size: CGSize,
        x: CGFloat,
        strokeWidth: CGFloat,
        lineStart: CGFloat,
        lineEnd: CGFloat,
        phase: CGFloat
    ) -> some View {
        let shineWidth = max(strokeWidth * 5, 24)
        let shineHeight = max(strokeWidth * 10, size.height * config.sealShineWidthRatio)
        let y = lineStart - shineHeight + (lineEnd - lineStart + shineHeight * 2) * phase

        return ZStack(alignment: .topLeading) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.48),
                    .init(color: .white, location: 0.56),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: shineWidth, height: shineHeight)
            .blur(radius: strokeWidth * 0.25)
            .offset(x: x - shineWidth / 2, y: y)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func shinePhase(at time: TimeInterval) -> CGFloat? {
        let runDuration = max(0.1, config.sealShineRunDuration)
        let pauseDuration = max(0, config.sealShinePauseDuration)
        let cycle = runDuration + pauseDuration
        let cycleTime = time.truncatingRemainder(dividingBy: cycle)

        guard cycleTime <= runDuration else { return nil }
        return Ease.move(CGFloat(cycleTime / runDuration))
    }
}

private struct EnvelopeFoldLines: View {
    let config: EnvelopeRevealConfig
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lipY = h * config.pocketLipRatio

            Path { path in
                path.move(to: CGPoint(x: 0, y: lipY))
                path.addLine(to: CGPoint(x: w, y: lipY))
            }
            .stroke(color.opacity(0.78), lineWidth: 1)
        }
    }
}

private struct EnvelopePaperTexture: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<34 {
                let y = size.height * CGFloat(index) / 33
                let wobble = sin(CGFloat(index) * 1.7) * 4
                var path = Path()
                path.move(to: CGPoint(x: -12, y: y + wobble))
                path.addLine(to: CGPoint(x: size.width + 12, y: y - wobble * 0.55))
                context.stroke(
                    path,
                    with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.10 : 0.055)),
                    lineWidth: 0.6
                )
            }

            for index in 0..<52 {
                let x = size.width * CGFloat((index * 37) % 101) / 100
                let y = size.height * CGFloat((index * 61) % 101) / 100
                let side = CGFloat(0.8 + Double(index % 4) * 0.35)
                let rect = CGRect(x: x, y: y, width: side, height: side)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(WBColor.textSecondary.opacity(0.045))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct EnvelopeTextureLayer: View {
    let assetName: String?

    var body: some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .allowsHitTesting(false)
        }
    }
}

private struct EnvelopeArtworkSilhouetteMask: View {
    let config: EnvelopeRevealConfig

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let flapMask = config.textures.flapExterior ?? config.textures.flapInterior

            ZStack(alignment: .topLeading) {
                if let flapMask {
                    EnvelopeTextureLayer(assetName: flapMask)
                        .frame(width: size.width, height: size.height, alignment: .topLeading)
                        .mask {
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(.white)
                                    .frame(height: size.height * config.seam.position)

                                Spacer(minLength: 0)
                            }
                            .frame(width: size.width, height: size.height, alignment: .top)
                        }
                }

                if let frontExterior = config.textures.frontExterior {
                    EnvelopeTextureLayer(assetName: frontExterior)
                        .frame(width: size.width, height: size.height, alignment: .topLeading)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }
}

private struct EnvelopePocketShape: Shape {
    let config: EnvelopeRevealConfig

    func path(in rect: CGRect) -> Path {
        let lipY = rect.height * config.pocketLipRatio

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + lipY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + lipY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.09

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Конфетти

private struct EnvelopeConfettiField: View {
    let elapsed: TimeInterval
    let start: Double
    let duration: Double
    let origin: CGPoint
    let layer: EnvelopeConfettiLayer

    var body: some View {
        GeometryReader { proxy in
            let motionScale = CGSize(
                width: min(0.58, max(0.44, proxy.size.width / 390 * 0.50)),
                height: min(0.84, max(0.66, proxy.size.height / 844 * 0.74))
            )
            let sourceFrame = prog(elapsed, start, duration) * EnvelopeFlexConfettiParticle.sourceFrameCount

            ZStack(alignment: .topLeading) {
                ForEach(EnvelopeFlexConfettiParticle.all) { particle in
                    let state = particle.state(atFrame: sourceFrame)
                    let flutter = particle.flutter(atFrame: sourceFrame)
                    let x = origin.x
                        + (state.point.x - EnvelopeFlexConfettiParticle.sourceCenter.x) * motionScale.width
                    let y = origin.y
                        + (state.point.y - EnvelopeFlexConfettiParticle.sourceCenter.y) * motionScale.height

                    EnvelopeFlexConfettiPiece(particle: particle)
                        .opacity(Double(state.opacity * layer.opacity(atFrame: sourceFrame)))
                        .rotationEffect(.degrees(state.rotation))
                        .scaleEffect(x: flutter.x, y: flutter.y)
                        .shadow(color: particle.color.opacity(0.18), radius: 4, y: 1)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

private enum EnvelopeConfettiLayer {
    case background
    case foregroundBurst

    func opacity(atFrame frame: CGFloat) -> CGFloat {
        switch self {
        case .background:
            return 1
        case .foregroundBurst:
            return 0.76 * (1 - Ease.appear(clamp01((frame - 46) / 42)))
        }
    }
}

private struct EnvelopeFlexConfettiSample {
    let frame: CGFloat
    let point: CGPoint

    init(frame: CGFloat, x: CGFloat, y: CGFloat) {
        self.frame = frame
        point = CGPoint(x: x, y: y)
    }
}

private struct EnvelopeFlexConfettiParticle: Identifiable {
    enum Kind { case star, circle, rectangle, square }

    let id: Int
    let kind: Kind
    let color: Color
    let size: CGSize
    let spin: Double
    let samples: [EnvelopeFlexConfettiSample]

    func state(atFrame frame: CGFloat) -> (point: CGPoint, opacity: CGFloat, rotation: Double) {
        let f = min(Self.sourceFrameCount, max(0, frame))
        let point = point(atFrame: f)
        let fade = 1 - Ease.appear(clamp01((f - 134) / 7))
        let appear = Ease.appear(clamp01(f / 8))
        let wobble = sin(Double(f) * 0.21 + Double(id) * 0.83) * 16
        let rotation = spin * Double(f / Self.sourceFrameCount) + wobble

        return (point, appear * fade * 0.96, rotation)
    }

    func flutter(atFrame frame: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let f = min(Self.sourceFrameCount, max(0, frame))
        let phase = Double(f) * 0.18 + Double(id) * 0.71
        let widthFold = 0.72 + 0.28 * abs(cos(phase))
        let heightFold = 0.84 + 0.16 * abs(sin(phase * 0.82))
        let burstGrow = 0.18 + 0.82 * Ease.appear(clamp01((f - 1) / 26))
        let base: CGFloat = 0.70 * burstGrow

        return (base * CGFloat(widthFold), base * CGFloat(heightFold))
    }

    private func point(atFrame frame: CGFloat) -> CGPoint {
        guard let first = samples.first else { return .zero }
        guard frame > first.frame else { return first.point }
        guard samples.count > 1 else { return first.point }

        for index in 0..<(samples.count - 1) {
            let current = samples[index]
            let next = samples[index + 1]
            guard frame <= next.frame else { continue }

            let span = max(0.001, next.frame - current.frame)
            let p = (frame - current.frame) / span
            return CGPoint(
                x: lerp(current.point.x, next.point.x, p),
                y: lerp(current.point.y, next.point.y, p)
            )
        }

        return samples.last?.point ?? first.point
    }

    static let sourceFrameCount: CGFloat = 141
    static let sourceCenter = CGPoint(x: 465.6, y: 402.6)

    private static let lottieYellow = Color(red: 0.976, green: 0.776, blue: 0.024)
    private static let lottiePink = Color(red: 0.918, green: 0.000, blue: 0.263)
    private static let lottieMint = Color(red: 0.000, green: 0.827, blue: 0.573)

    static let all: [EnvelopeFlexConfettiParticle] = [
        .init(
            id: 0,
            kind: .star,
            color: lottieYellow,
            size: CGSize(width: 35.29, height: 36.41),
            spin: -118,
            samples: [
                .init(frame: 0.0, x: 472.1, y: 384.6),
                .init(frame: 8.0, x: 632.7, y: 288.7),
                .init(frame: 14.0, x: 658.6, y: 292.1),
                .init(frame: 18.0, x: 690.3, y: 298.3),
                .init(frame: 25.0, x: 738.1, y: 318.3),
                .init(frame: 28.0, x: 739.4, y: 330.1),
                .init(frame: 32.0, x: 725.1, y: 348.3),
                .init(frame: 36.0, x: 714.8, y: 368.2),
                .init(frame: 42.0, x: 705.9, y: 398.5),
                .init(frame: 55.0, x: 702.5, y: 448.2),
                .init(frame: 70.0, x: 743.5, y: 467.6),
                .init(frame: 85.0, x: 821.9, y: 519.7),
                .init(frame: 100.0, x: 811.9, y: 567.7),
                .init(frame: 115.0, x: 710.2, y: 609.2),
                .init(frame: 130.0, x: 662.5, y: 711.9),
                .init(frame: 141.0, x: 663.0, y: 740.5),
            ]
        ),
        .init(
            id: 1,
            kind: .star,
            color: lottieYellow,
            size: CGSize(width: 35.29, height: 36.41),
            spin: 126,
            samples: [
                .init(frame: 0.0, x: 464.2, y: 376.7),
                .init(frame: 14.0, x: 179.0, y: 234.2),
                .init(frame: 18.0, x: 169.6, y: 254.3),
                .init(frame: 25.0, x: 161.2, y: 289.1),
                .init(frame: 28.0, x: 159.9, y: 302.3),
                .init(frame: 32.0, x: 159.3, y: 317.5),
                .init(frame: 36.0, x: 159.3, y: 329.2),
                .init(frame: 42.0, x: 160.8, y: 339.5),
                .init(frame: 55.0, x: 232.2, y: 360.6),
                .init(frame: 70.0, x: 279.3, y: 415.5),
                .init(frame: 85.0, x: 250.4, y: 451.5),
                .init(frame: 100.0, x: 141.8, y: 517.1),
                .init(frame: 115.0, x: 119.3, y: 610.8),
                .init(frame: 130.0, x: 125.8, y: 637.7),
                .init(frame: 141.0, x: 154.4, y: 681.3),
            ]
        ),
        .init(
            id: 2,
            kind: .star,
            color: lottieYellow,
            size: CGSize(width: 35.29, height: 36.41),
            spin: -94,
            samples: [
                .init(frame: 0.0, x: 466.1, y: 368.2),
                .init(frame: 36.0, x: 542.1, y: 229.9),
                .init(frame: 42.0, x: 561.9, y: 238.2),
                .init(frame: 55.0, x: 597.8, y: 259.6),
                .init(frame: 70.0, x: 612.8, y: 277.2),
                .init(frame: 85.0, x: 612.4, y: 302.5),
                .init(frame: 100.0, x: 587.6, y: 376.2),
                .init(frame: 115.0, x: 542.8, y: 430.7),
                .init(frame: 130.0, x: 528.1, y: 444.8),
                .init(frame: 141.0, x: 513.5, y: 460.1),
            ]
        ),
        .init(
            id: 3,
            kind: .star,
            color: lottieYellow,
            size: CGSize(width: 35.29, height: 36.41),
            spin: 104,
            samples: [
                .init(frame: 0.0, x: 464.9, y: 369.9),
                .init(frame: 32.0, x: 262.8, y: 129.3),
                .init(frame: 36.0, x: 252.8, y: 155.1),
                .init(frame: 42.0, x: 235.2, y: 192.8),
                .init(frame: 55.0, x: 195.6, y: 301.9),
                .init(frame: 70.0, x: 168.8, y: 419.7),
                .init(frame: 85.0, x: 164.5, y: 451.2),
                .init(frame: 100.0, x: 167.8, y: 618.9),
                .init(frame: 115.0, x: 216.0, y: 682.0),
                .init(frame: 130.0, x: 318.4, y: 750.9),
                .init(frame: 141.0, x: 368.6, y: 770.2),
            ]
        ),
        .init(
            id: 4,
            kind: .circle,
            color: lottiePink,
            size: CGSize(width: 16.81, height: 20.82),
            spin: -72,
            samples: [
                .init(frame: 0.0, x: 463.7, y: 379.6),
                .init(frame: 28.0, x: 672.5, y: 230.3),
                .init(frame: 32.0, x: 664.8, y: 259.7),
                .init(frame: 36.0, x: 658.0, y: 291.7),
                .init(frame: 42.0, x: 648.9, y: 337.8),
                .init(frame: 55.0, x: 630.9, y: 405.4),
                .init(frame: 70.0, x: 630.3, y: 442.5),
                .init(frame: 85.0, x: 679.7, y: 538.7),
                .init(frame: 100.0, x: 641.0, y: 586.3),
                .init(frame: 115.0, x: 642.2, y: 612.5),
                .init(frame: 130.0, x: 732.7, y: 674.1),
                .init(frame: 141.0, x: 791.2, y: 724.4),
            ]
        ),
        .init(
            id: 5,
            kind: .circle,
            color: lottiePink,
            size: CGSize(width: 16.81, height: 20.82),
            spin: 86,
            samples: [
                .init(frame: 0.0, x: 464.5, y: 385.8),
                .init(frame: 32.0, x: 215.6, y: 236.9),
                .init(frame: 36.0, x: 234.9, y: 238.7),
                .init(frame: 42.0, x: 269.7, y: 259.7),
                .init(frame: 55.0, x: 349.6, y: 324.0),
                .init(frame: 70.0, x: 405.5, y: 373.6),
                .init(frame: 85.0, x: 415.1, y: 394.8),
                .init(frame: 100.0, x: 413.9, y: 462.6),
                .init(frame: 115.0, x: 392.6, y: 540.0),
                .init(frame: 130.0, x: 333.1, y: 566.9),
                .init(frame: 141.0, x: 279.6, y: 594.9),
            ]
        ),
        .init(
            id: 6,
            kind: .circle,
            color: lottiePink,
            size: CGSize(width: 16.81, height: 20.82),
            spin: -64,
            samples: [
                .init(frame: 0.0, x: 465.2, y: 395.2),
                .init(frame: 25.0, x: 398.4, y: 154.4),
                .init(frame: 28.0, x: 404.9, y: 158.3),
                .init(frame: 32.0, x: 413.1, y: 160.8),
                .init(frame: 36.0, x: 420.3, y: 170.3),
                .init(frame: 42.0, x: 429.0, y: 194.2),
                .init(frame: 55.0, x: 438.9, y: 249.3),
                .init(frame: 70.0, x: 440.6, y: 282.8),
                .init(frame: 85.0, x: 440.0, y: 362.8),
                .init(frame: 100.0, x: 429.1, y: 402.5),
                .init(frame: 115.0, x: 401.6, y: 473.8),
                .init(frame: 130.0, x: 377.6, y: 587.1),
                .init(frame: 141.0, x: 362.7, y: 637.9),
            ]
        ),
        .init(
            id: 7,
            kind: .rectangle,
            color: lottiePink,
            size: CGSize(width: 23.74, height: 22.82),
            spin: 148,
            samples: [
                .init(frame: 0.0, x: 458.7, y: 373.7),
                .init(frame: 42.0, x: 610.4, y: 170.5),
                .init(frame: 55.0, x: 630.3, y: 205.5),
                .init(frame: 70.0, x: 673.5, y: 302.7),
                .init(frame: 85.0, x: 609.9, y: 346.1),
                .init(frame: 100.0, x: 580.6, y: 368.8),
                .init(frame: 115.0, x: 580.6, y: 437.4),
                .init(frame: 130.0, x: 580.6, y: 496.1),
                .init(frame: 141.0, x: 580.6, y: 507.0),
            ]
        ),
        .init(
            id: 8,
            kind: .rectangle,
            color: lottiePink,
            size: CGSize(width: 23.74, height: 22.82),
            spin: -136,
            samples: [
                .init(frame: 0.0, x: 460.4, y: 381.9),
                .init(frame: 36.0, x: 197.0, y: 204.4),
                .init(frame: 42.0, x: 198.5, y: 234.2),
                .init(frame: 55.0, x: 210.9, y: 332.2),
                .init(frame: 70.0, x: 225.0, y: 418.6),
                .init(frame: 85.0, x: 234.8, y: 455.1),
                .init(frame: 100.0, x: 287.8, y: 549.3),
                .init(frame: 115.0, x: 253.2, y: 599.5),
                .init(frame: 130.0, x: 196.6, y: 629.1),
                .init(frame: 141.0, x: 196.6, y: 665.6),
            ]
        ),
        .init(
            id: 9,
            kind: .rectangle,
            color: lottiePink,
            size: CGSize(width: 23.74, height: 22.82),
            spin: 102,
            samples: [
                .init(frame: 0.0, x: 463.3, y: 378.0),
                .init(frame: 28.0, x: 492.1, y: 128.8),
                .init(frame: 32.0, x: 492.1, y: 148.3),
                .init(frame: 36.0, x: 492.1, y: 156.6),
                .init(frame: 42.0, x: 492.2, y: 163.0),
                .init(frame: 55.0, x: 495.1, y: 220.1),
                .init(frame: 70.0, x: 511.4, y: 334.5),
                .init(frame: 85.0, x: 521.8, y: 404.3),
                .init(frame: 100.0, x: 546.2, y: 447.6),
                .init(frame: 115.0, x: 585.0, y: 543.7),
                .init(frame: 130.0, x: 513.9, y: 585.7),
                .init(frame: 141.0, x: 492.1, y: 602.1),
            ]
        ),
        .init(
            id: 10,
            kind: .rectangle,
            color: lottiePink,
            size: CGSize(width: 23.74, height: 22.82),
            spin: -112,
            samples: [
                .init(frame: 0.0, x: 464.3, y: 393.9),
                .init(frame: 28.0, x: 709.1, y: 178.2),
                .init(frame: 32.0, x: 709.1, y: 194.3),
                .init(frame: 36.0, x: 709.1, y: 204.2),
                .init(frame: 42.0, x: 709.1, y: 210.3),
                .init(frame: 55.0, x: 709.1, y: 263.2),
                .init(frame: 70.0, x: 709.1, y: 342.6),
                .init(frame: 85.0, x: 709.6, y: 371.9),
                .init(frame: 100.0, x: 719.6, y: 471.9),
                .init(frame: 115.0, x: 735.9, y: 570.0),
                .init(frame: 130.0, x: 740.8, y: 609.2),
                .init(frame: 141.0, x: 781.3, y: 663.9),
            ]
        ),
        .init(
            id: 11,
            kind: .square,
            color: lottieMint,
            size: CGSize(width: 22.12, height: 27.01),
            spin: -92,
            samples: [
                .init(frame: 0.0, x: 463.9, y: 386.0),
                .init(frame: 28.0, x: 337.6, y: 250.3),
                .init(frame: 32.0, x: 351.3, y: 278.8),
                .init(frame: 36.0, x: 357.5, y: 305.4),
                .init(frame: 42.0, x: 357.9, y: 328.7),
                .init(frame: 55.0, x: 281.1, y: 365.4),
                .init(frame: 70.0, x: 265.4, y: 388.6),
                .init(frame: 85.0, x: 265.4, y: 460.6),
                .init(frame: 100.0, x: 265.4, y: 513.5),
                .init(frame: 115.0, x: 265.4, y: 533.2),
                .init(frame: 130.0, x: 265.4, y: 598.6),
                .init(frame: 141.0, x: 265.4, y: 658.3),
            ]
        ),
        .init(
            id: 12,
            kind: .square,
            color: lottieMint,
            size: CGSize(width: 22.12, height: 27.01),
            spin: 96,
            samples: [
                .init(frame: 0.0, x: 467.8, y: 381.5),
                .init(frame: 18.0, x: 629.5, y: 241.4),
                .init(frame: 25.0, x: 636.8, y: 284.0),
                .init(frame: 28.0, x: 638.8, y: 297.7),
                .init(frame: 32.0, x: 640.6, y: 312.3),
                .init(frame: 36.0, x: 641.4, y: 323.3),
                .init(frame: 42.0, x: 643.1, y: 332.6),
                .init(frame: 55.0, x: 691.3, y: 401.5),
                .init(frame: 70.0, x: 701.2, y: 470.6),
                .init(frame: 85.0, x: 612.7, y: 512.4),
                .init(frame: 100.0, x: 611.4, y: 547.6),
                .init(frame: 115.0, x: 611.4, y: 620.1),
                .init(frame: 130.0, x: 611.4, y: 654.3),
                .init(frame: 141.0, x: 611.4, y: 673.2),
            ]
        ),
        .init(
            id: 13,
            kind: .square,
            color: lottieMint,
            size: CGSize(width: 22.12, height: 27.01),
            spin: -124,
            samples: [
                .init(frame: 0.0, x: 465.0, y: 381.3),
                .init(frame: 32.0, x: 326.4, y: 151.0),
                .init(frame: 36.0, x: 326.4, y: 169.1),
                .init(frame: 42.0, x: 326.4, y: 201.2),
                .init(frame: 55.0, x: 326.4, y: 266.9),
                .init(frame: 70.0, x: 327.1, y: 297.7),
                .init(frame: 85.0, x: 338.1, y: 401.4),
                .init(frame: 100.0, x: 353.8, y: 495.7),
                .init(frame: 115.0, x: 359.7, y: 533.2),
                .init(frame: 130.0, x: 414.5, y: 620.9),
                .init(frame: 141.0, x: 418.2, y: 666.3),
            ]
        ),
        .init(
            id: 14,
            kind: .square,
            color: lottieMint,
            size: CGSize(width: 22.12, height: 27.01),
            spin: 116,
            samples: [
                .init(frame: 0.0, x: 466.4, y: 381.2),
                .init(frame: 28.0, x: 701.2, y: 248.5),
                .init(frame: 32.0, x: 705.9, y: 266.1),
                .init(frame: 36.0, x: 708.1, y: 274.6),
                .init(frame: 42.0, x: 708.1, y: 281.0),
                .init(frame: 55.0, x: 708.1, y: 334.2),
                .init(frame: 70.0, x: 708.1, y: 373.6),
                .init(frame: 85.0, x: 708.1, y: 433.9),
                .init(frame: 100.0, x: 708.1, y: 510.7),
                .init(frame: 115.0, x: 708.8, y: 541.5),
                .init(frame: 130.0, x: 719.8, y: 645.2),
                .init(frame: 141.0, x: 732.6, y: 720.7),
            ]
        ),
    ]
}

private struct EnvelopeFlexConfettiPiece: View {
    let particle: EnvelopeFlexConfettiParticle

    var body: some View {
        switch particle.kind {
        case .circle:
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.72), particle.color.opacity(0.96)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: max(particle.size.width, particle.size.height)
                    )
                )
                .frame(width: particle.size.width, height: particle.size.height)

        case .rectangle:
            FlexRectangleConfettiShape()
                .fill(
                    LinearGradient(
                        colors: [
                            particle.color.opacity(0.96),
                            .white.opacity(0.58),
                            particle.color.opacity(0.82),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: particle.size.width, height: particle.size.height)

        case .square:
            FlexSquareConfettiShape()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.52), particle.color.opacity(0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: particle.size.width, height: particle.size.height)

        case .star:
            FlexStarConfettiShape()
                .fill(particle.color)
                .overlay(
                    FlexStarConfettiShape()
                        .fill(.white.opacity(0.34))
                        .scaleEffect(0.55)
                        .offset(x: -3, y: -3)
                )
                .frame(width: particle.size.width, height: particle.size.height)
        }
    }
}

private struct FlexStarConfettiShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let points: [CGPoint] = [
            CGPoint(x: 0.812, y: 0.459),
            CGPoint(x: 0.807, y: 0.420),
            CGPoint(x: 0.927, y: 0.110),
            CGPoint(x: 0.609, y: 0.209),
            CGPoint(x: 0.568, y: 0.202),
            CGPoint(x: 0.311, y: 0.000),
            CGPoint(x: 0.301, y: 0.331),
            CGPoint(x: 0.282, y: 0.366),
            CGPoint(x: 0.000, y: 0.552),
            CGPoint(x: 0.313, y: 0.656),
            CGPoint(x: 0.342, y: 0.686),
            CGPoint(x: 0.425, y: 1.000),
            CGPoint(x: 0.629, y: 0.735),
            CGPoint(x: 0.666, y: 0.718),
            CGPoint(x: 1.000, y: 0.729),
        ]

        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}

private struct FlexRectangleConfettiShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = [
            CGPoint(x: 0.187, y: 1.000),
            CGPoint(x: 1.000, y: 0.546),
            CGPoint(x: 0.814, y: 0.000),
            CGPoint(x: 0.000, y: 0.473),
        ]

        path.move(to: CGPoint(x: rect.minX + points[0].x * rect.width, y: rect.minY + points[0].y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}

private struct FlexSquareConfettiShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = [
            CGPoint(x: 0.334, y: 1.000),
            CGPoint(x: 1.000, y: 0.632),
            CGPoint(x: 0.717, y: 0.000),
            CGPoint(x: 0.000, y: 0.323),
        ]

        path.move(to: CGPoint(x: rect.minX + points[0].x * rect.width, y: rect.minY + points[0].y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    PostcardEnvelopeGiftScreen(onClose: {})
}
