import SwiftUI

/// Выбор открытки к переводу. Макет 46432:621671.
///
/// Три механики, которые здесь проверяются:
///
/// 1. **Наклон.** Активная открытка искажается в перспективе и ведёт за собой
///    блик. Технология — из прототипа Brighty (`HolographicCardBlend`), но от
///    голографии остался только сам наклон и один вытянутый белый блик:
///    радуга, решётки лучей и их пересечение выброшены. Подробности —
///    в `TiltMotion.swift` и `GlossyPostcard.swift`.
/// 2. **Свайп по вариантам.** Соседние карточки лежат в масштабе 0,5 и въезжают
///    в центр, вырастая до 1; активная уезжает и уменьшается. Числа взяты из
///    макета: шаг между центрами 248,44, разворот соседей ±2°.
/// 3. **Фон.** Во весь экран лежит активная открытка, поверх — белая заливка
///    88 % и сильное размытие. Текстура выбранной открытки должна угадываться на
///    фоне, но не спорить с контентом. При свайпе фон перетекает между двумя
///    ближайшими вариантами, а не переключается рывком.
///
/// Разметка, как и на экране исхода, считается в координатах полного экрана:
/// макет задаёт отступы от его кромки, а не от безопасной зоны.
struct PostcardPickerScreen: View {
    var cards: [Postcard] = PostcardCatalog.all
    var onSelect: (Postcard) -> Void = { _ in }
    let onClose: () -> Void

    @State private var motion = TiltMotionService()
    /// Индекс активной открытки. Между индексами живёт `drag`.
    @State private var index: Int = 0
    /// Текущий сдвиг пальца. Крутит карусель, и только её: наклон карточки
    /// принадлежит телефону, а не жесту.
    @State private var drag: CGSize = .zero

    private enum Metrics {
        /// Строка навбара под статус-баром (в макете карточка 92 = 44 + 48).
        static let navRow: CGFloat = 48
        static let sideInset: CGFloat = 16
        static let buttonHeight: CGFloat = 52
        /// Панель кнопки: отбивка сверху, кнопка и дальше — home indicator.
        static let panelTopPadding: CGFloat = 16
        static let panelRadius: CGFloat = 24
    }

    /// Непрерывная позиция карусели: целое — карточка в центре.
    private var position: Double {
        Double(index) - Double(drag.width / PostcardMetrics.neighborStep)
    }

    private var tilt: TiltInput {
        var value = TiltInput.from(motion: motion)
        // `-demoTilt "8,-16"` — кадр наклона для показа и скриншотов.
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
            // Открытка стоит по центру полосы между навбаром и панелью. На
            // 390 × 844 это даёт центр 417 — ровно как в макете.
            let cardCenterY = (topInset + Metrics.navRow + panelTop) / 2

            ZStack(alignment: .topLeading) {
                backdrop
                    .frame(width: width, height: height)

                carousel(width: width, centerY: cardCenterY)
                    .frame(width: width, height: height)

                closeButton
                    .position(x: width - 4 - 22, y: topInset + Metrics.navRow / 2)

                panel(width: width, height: panelHeight)
                    .offset(y: panelTop)
            }
            .frame(width: width, height: height, alignment: .topLeading)
            // Работаем в координатах полного экрана.
            .offset(y: -topInset)
        }
        .onAppear {
            motion.start()
            // `-demoCard 1` — открыть сразу на нужном варианте.
            if let start = SandboxSettings.startCard, cards.indices.contains(start) {
                index = start
            }
        }
        .onDisappear { motion.stop() }
    }

    // MARK: Фон

    private var backdrop: some View {
        ZStack {
            WBColor.bgBase

            ZStack {
                ForEach(Array(cards.enumerated()), id: \.element.id) { pair in
                    let weight = max(0, 1 - abs(Double(pair.offset) - position))
                    if weight > 0.001 {
                        PostcardFace(card: pair.element)
                            .opacity(weight)
                    }
                }
            }
            // Размытие гасит свои же края, поэтому слой растянут за кромку
            // экрана: иначе по периметру появляется светлая рамка.
            .blur(radius: 60)
            .scaleEffect(1.25)

            WBColor.bgBase.opacity(0.88)
        }
        .clipped()
    }

    // MARK: Шапка

    private var closeButton: some View {
        Button(action: onClose) {
            DSIconView(icon: .close)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Закрыть")
    }

    // MARK: Карусель

    private func carousel(width: CGFloat, centerY: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Тянуть можно за всю середину экрана, а не только за саму
            // открытку: на показе палец попадает мимо карточки чаще, чем
            // кажется. Кнопка и панель лежат выше по стеку, их нажатия целы.
            Color.clear
                .contentShape(Rectangle())

            ForEach(Array(cards.enumerated()), id: \.element.id) { pair in
                card(pair.element, at: pair.offset, centerX: width / 2, centerY: centerY)
            }
        }
        .gesture(swipe)
    }

    private func card(
        _ card: Postcard,
        at offset: Int,
        centerX: CGFloat,
        centerY: CGFloat
    ) -> some View {
        let r = Double(offset) - position
        let distance = min(1, abs(r))
        // Соседи ровно вдвое меньше активной — как в макете.
        let scale = 1 - (1 - Double(PostcardMetrics.neighborScale)) * distance
        let cardTilt = tilt.scaled(by: max(0, 1 - abs(r)))

        return GlossyPostcardView(
            card: card,
            tilt: cardTilt,
            glare: max(0, 1 - abs(r))
        )
        // Тап навешен до `position`, иначе жест достаётся всей полосе карусели:
        // активная карточка лежит выше всех и перехватывала бы нажатия по
        // соседям, которые как раз и нужно выбирать тапом.
        .onTapGesture {
            guard offset != index else { return }
            Haptics.tap()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                index = offset
                drag = .zero
            }
        }
        .accessibilityLabel(card.title)
        // Поворот берём не весь: `rotationPitch/Yaw` уже сжаты относительно
        // наклона, которым ездит блик.
        .modifier(CardTiltEffect(pitch: cardTilt.rotationPitch, yaw: cardTilt.rotationYaw))
        .rotationEffect(.degrees(PostcardMetrics.neighborTilt * max(-1, min(1, r))))
        .scaleEffect(scale)
        .position(x: centerX + r * Double(PostcardMetrics.neighborStep), y: centerY)
        .zIndex(-abs(r))
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                // Без анимации: карточка должна идти за пальцем один к одному.
                drag = value.translation
            }
            .onEnded { value in
                let step = Double(PostcardMetrics.neighborStep)
                // Учитываем не только пройденный путь, но и бросок: короткий
                // резкий флик тоже должен листать.
                let projected = Double(value.translation.width)
                    + Double(value.predictedEndTranslation.width) * 0.25

                var next = index
                if projected < -step * 0.28 {
                    next = min(index + 1, cards.count - 1)
                } else if projected > step * 0.28 {
                    next = max(index - 1, 0)
                }

                if next != index { Haptics.tap() }

                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    index = next
                    drag = .zero
                }
            }
    }

    // MARK: Панель кнопки

    private func panel(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: Metrics.panelRadius,
                topTrailingRadius: Metrics.panelRadius,
                style: .continuous
            )
            .fill(WBColor.bgBase)

            WBPrimaryButton(title: "Выбрать") {
                onSelect(cards[min(index, cards.count - 1)])
            }
            .frame(width: width - Metrics.sideInset * 2, height: Metrics.buttonHeight)
            .offset(y: Metrics.panelTopPadding)
        }
        .frame(width: width, height: height, alignment: .top)
    }
}

#Preview {
    PostcardPickerScreen(onClose: {})
}
