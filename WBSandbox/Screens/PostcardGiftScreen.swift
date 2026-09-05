import SwiftUI

// MARK: - Хореография подарка

/// Такты раскрытия. Считаются как функция от `elapsed`, без `withAnimation` — так
/// же, как анимация экрана исхода: такты свободно накладываются и не дерутся за
/// одни и те же свойства.
///
///   1. вылет    — из-за нижней кромки выходит **одна открытка**: растёт с 0,34
///                 до 1 и делает один оборот вокруг вертикальной оси. Экран под
///                 ней всё ещё прежний — белый, с кнопкой «Открыть подарок»;
///   2. фон      — открытка прилетела и начинает дублировать себя на фоне. Слой
///                 непрозрачный, поэтому он же и перекрывает прежний экран;
///   3. хром     — последней выезжает белая подложка со «Сказать спасибо»;
///   4. передача — бликом перестаёт управлять оборот, управление забирает рука.
///
/// Порядок важнее длительностей: сначала предмет, потом среда, потом управление.
/// Если запускать их вместе, читается одна плашка, которая едет вверх.
struct GiftAnim {
    /// Множитель замедления для отладки.
    static let k: Double = 1.0

    /// Сколько оборотов делает открытка в полёте.
    static let turns: Double = 1

    var card: Double { 0.62 * Self.k }
    var backdrop: Double { 0.45 * Self.k }
    var chrome: Double { 0.36 * Self.k }
    var handover: Double { 0.30 * Self.k }

    var cardEnd: Double { card }
    /// Фон подхватывает открытку ровно в момент приземления.
    var backdropStart: Double { cardEnd }
    /// Кнопка ждёт, пока фон почти набрал плотность: два движения подряд
    /// сливаются, между ними нужен зазор.
    var chromeStart: Double { backdropStart + backdrop * 0.7 }
    var handoverStart: Double { cardEnd }
    var total: Double { chromeStart + chrome }
}

// MARK: - Экран

/// Получение открытки. Второй пункт раздела: там открытку к переводу выбирают,
/// здесь получают.
///
/// До нажатия на экране только кнопка «Открыть подарок» — ни самой открытки, ни
/// её текстуры на фоне: всё это раскрывало бы подарок заранее. По нажатию снизу
/// вылетает открытка, за ней проявляется её же фон, и последним приезжает
/// «Сказать спасибо». Дальше открытка живёт от наклона — теми же компонентами,
/// что и в выборе.
///
/// Отличия от `PostcardPickerScreen`: открытка одна (соседей и свайпа нет — мы
/// открываем присланное, а не выбираем), и кнопка внизу другая. Какая открытка
/// пришла, задаёт `-demoCard`, по умолчанию первая.
struct PostcardGiftScreen: View {
    var cards: [Postcard] = PostcardCatalog.all
    var onThanks: () -> Void = {}
    let onClose: () -> Void

    @State private var motion = TiltMotionService()
    /// Момент нажатия на «Открыть подарок». `nil` — подарок ещё закрыт.
    @State private var openedAt: Date?
    /// Пока идёт раскрытие, кадры считает `TimelineView`. После — статичный
    /// кадр, который живёт только от наклона.
    @State private var isRevealing = false

    private let anim = GiftAnim()

    private enum Metrics {
        static let navRow: CGFloat = 48
        static let sideInset: CGFloat = 16
        static let buttonHeight: CGFloat = 52
        static let panelTopPadding: CGFloat = 16
        static let panelRadius: CGFloat = 24
        /// Масштаб открытки в начале вылета.
        static let launchScale: CGFloat = 0.34
        /// Кнопка «Открыть подарок» стоит по центру и не тянется на всю ширину:
        /// растянутая, она читалась бы той же нижней подложкой, только поднятой.
        static let openButtonWidth: CGFloat = 220
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
            let cardCenterY = (topInset + Metrics.navRow + panelTop) / 2

            let stage = Stage(
                width: width,
                height: height,
                panelTop: panelTop,
                panelHeight: panelHeight,
                cardCenterY: cardCenterY,
                topInset: topInset
            )

            Group {
                if isRevealing, let openedAt {
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
            // `-demoGiftOpened 1` — сразу раскрытый кадр, без анимации.
            if SandboxSettings.giftOpened { openedAt = .distantPast }
        }
        .onDisappear { motion.stop() }
    }

    /// Всё, что кадру нужно знать о геометрии экрана.
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
        // Сырые прогрессы: кривую накладывает тот, кто величину использует.
        let cardP = isOpen ? prog(elapsed, 0, anim.card) : 0
        let backdropP = isOpen ? prog(elapsed, anim.backdropStart, anim.backdrop) : 0
        let chromeP = isOpen ? prog(elapsed, anim.chromeStart, anim.chrome) : 0
        let handover = isOpen ? Double(prog(elapsed, anim.handoverStart, anim.handover)) : 0

        // Вылет: резкий старт, длинное торможение. Одна кривая на путь, размер и
        // оборот — это одно движение, и разными кривыми оно бы расслоилось.
        let rise = Ease.launch(cardP)
        let spin = GiftAnim.turns * 360 * Double(rise)

        // Стартовая точка — за нижней кромкой экрана.
        let launchOffset = stage.height - stage.cardCenterY
            + PostcardMetrics.cardSize.height * Metrics.launchScale / 2 + 24
        let flightY = (1 - rise) * launchOffset
        let scale = lerp(Metrics.launchScale, 1, rise)

        // Экран до подарка гаснет быстрее фона: к приезду хрома подарка его уже
        // не должно быть на экране, иначе на кромке сойдутся сразу три движения.
        let closedFade = isOpen
            ? Double(Ease.appear(prog(elapsed, anim.backdropStart, anim.backdrop * 0.6)))
            : 0

        return ZStack(alignment: .topLeading) {
            // Фон — слоёный пирог, и порядок слоёв здесь важнее их появления.
            // Двигается ровно один слой: картинка. Белое полотно и белая вуаль
            // 88 % стоят на месте с самого начала — они белые поверх белого
            // экрана, поэтому их «появление» ничего не стоит.
            //
            // Раньше проявлялся весь фон целиком, и на середине такта он давал
            // вспышку: SwiftUI без `compositingGroup` раздаёт прозрачность
            // каждому подслою по отдельности, так что вуаль была ещё
            // полупрозрачной, а картинка под ней уже яркой. Теперь картинка
            // всегда смотрится сквозь готовую вуаль и растёт от нуля до своих
            // 12 % ровно.

            // 1. Нижнее белое полотно.
            WBColor.bgBase
                .frame(width: stage.width, height: stage.height)

            // 2. Картинка открытки — единственный слой, который проявляется.
            PostcardFace(card: card)
                .frame(width: stage.width, height: stage.height)
                .blur(radius: 60)
                .scaleEffect(1.25)
                .opacity(Double(Ease.appear(backdropP)))
                .clipped()
                .allowsHitTesting(false)

            // 3. Белая вуаль: заливка 88 % и есть тот самый эффект «текстура
            //    угадывается, но не спорит с контентом».
            WBColor.bgBase.opacity(0.88)
                .frame(width: stage.width, height: stage.height)
                .allowsHitTesting(false)

            // 4. Элементы экрана до подарка. Стоят намеренно не там, где
            //    элементы подарка: кнопка по центру против нижней подложки,
            //    шеврон слева против крестика справа. Когда они совпадали по
            //    месту, раскрытие читалось как мигание.
            Group {
                backChevron
                    .position(x: 4 + 22, y: stage.topInset + Metrics.navRow / 2)

                WBPrimaryButton(title: "Открыть подарок") { open() }
                    .frame(width: Metrics.openButtonWidth, height: Metrics.buttonHeight)
                    .position(x: stage.width / 2, y: stage.cardCenterY)
            }
            .opacity(1 - closedFade)
            .allowsHitTesting(!isOpen)

            // 5. Открытка — выше фона и выше прежнего экрана.
            if isOpen {
                cardStack(spin: spin, handover: handover)
                    .scaleEffect(scale)
                    .offset(y: flightY)
                    .position(x: stage.width / 2, y: stage.cardCenterY)
            }

            // 6. Хром подарка приезжает последним: крестик справа и подложка со
            //    «Сказать спасибо» внизу. До своего такта его в иерархии нет
            //    вовсе — слой с нулевой прозрачностью в SwiftUI продолжает ловить
            //    нажатия и съедал бы тап по «Открыть подарок».
            if isOpen {
                Group {
                    openedNavigationBar(width: stage.width)
                        .offset(y: stage.topInset)
                        .reveal(chromeP, rise: 10)

                    panel(title: "Сказать спасибо", stage: stage) { onThanks() }
                        .reveal(chromeP, rise: 28)
                        .offset(y: stage.panelTop)
                }
                .allowsHitTesting(chromeP > 0.9)
            }
        }
        .frame(width: stage.width, height: stage.height, alignment: .topLeading)
    }

    // MARK: Карточка

    /// Лицо и оборот в одном стеке: `rotation3DEffect` крутит их вместе, а видна
    /// та сторона, которая сейчас повёрнута к зрителю.
    private func cardStack(spin: Double, handover: Double) -> some View {
        let showsFront = cos(spin * .pi / 180) >= 0
        let tilt = cardTilt(spin: spin, handover: handover)
        let shape = RoundedRectangle(
            cornerRadius: PostcardMetrics.cornerRadius,
            style: .continuous
        )

        return ZStack {
            GlossyPostcardView(card: card, tilt: tilt)
                .opacity(showsFront ? 1 : 0)

            PostcardBackFace()
                .frame(
                    width: PostcardMetrics.cardSize.width,
                    height: PostcardMetrics.cardSize.height
                )
                .clipShape(shape)
                // Разворот на 180°, иначе оборот показывался бы зеркальным.
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsFront ? 0 : 1)
        }
        // Наклон от руки включается только после приземления: в полёте он спорил
        // бы с оборотом.
        .modifier(
            CardTiltEffect(
                pitch: tilt.rotationPitch * handover,
                yaw: tilt.rotationYaw * handover
            )
        )
        .rotation3DEffect(
            .degrees(spin),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.55
        )
        .shadow(color: .black.opacity(0.16), radius: 24, y: 14)
    }

    /// В полёте бликом управляет сам оборот: свет проходит по карточке, как по
    /// настоящему глянцу под лампой. На приземлении управление плавно забирает
    /// рука.
    private func cardTilt(spin: Double, handover: Double) -> TiltInput {
        let spinTilt = TiltInput(pitch: 0, yaw: sin(spin * .pi / 180) * 16, energy: 1)
        return TiltInput.blend(spinTilt, liveTilt, handover)
    }

    // MARK: Шапка и кнопка

    /// Навбар раскрытого подарка из макета 46575:117118: двухстрочный текст
    /// стоит по центру, а крестик сохраняет прежнюю позицию справа.
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

    /// Шеврон на экране до подарка. Тот же знак, что у `WBNavBar` в состоянии
    /// `.back`: экран открыт из списка, и до раскрытия из него уходят назад, а не
    /// закрывают.
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

    // MARK: Раскрытие

    private func open() {
        guard !isOpen else { return }
        openedAt = Date()
        isRevealing = true

        // Отдача на приход открытки — отдельным событием от нажатия.
        DispatchQueue.main.asyncAfter(deadline: .now() + anim.cardEnd) {
            Haptics.impact(.soft)
        }
        // После раскрытия кадры больше не нужны: дальше карточка живёт только от
        // наклона, а он приходит сам.
        DispatchQueue.main.asyncAfter(deadline: .now() + anim.total) {
            isRevealing = false
        }
    }
}

#Preview {
    PostcardGiftScreen(onClose: {})
}
