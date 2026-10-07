import SwiftUI

/// Экран исхода операции: лоадер, затем «выполнен», «в обработке» или «отклонён».
///
/// Вёрстка собрана по макетам 925:207394 (успех), 927:207898 (в обработке) и
/// 927:207846 (отказ). Разметка у всех трёх одна, различаются палитра, отбивка
/// до иконки, набор кнопок и наполнение плиток — всё это живёт в
/// `TransactionOutcome` и в данных сценария.
///
/// Хореография — шесть тактов из `OutcomeAnim`, всё считается от `elapsed`
/// внутри одного `TimelineView`. Пока анимация не идёт, рисуем последний кадр:
/// экран стоит и ничего не тикает.
///
/// Геометрия взята из макета как есть, поэтому в коде встречаются нецелые
/// значения вроде 55,875 и 120,857: макет отрисован в масштабе 0,9977,
/// и округлять их значило бы разъезжаться с ним на глаз.
struct OutcomeScreen: View {
    let scenario: OutcomeScenario
    let amount: Decimal
    /// Бейдж комиссии под суммой. nil — бейджа нет.
    var badge: BadgeSpec?
    let onClose: () -> Void

    @State private var particles: [OutcomeParticle] = []
    @State private var startedAt: Date = .distantPast
    @State private var isAnimating = false

    private var config: SuccessConfig { scenario.success }
    private var outcome: TransactionOutcome { scenario.outcome }
    private var anim: OutcomeAnim { OutcomeAnim(loader: scenario.loaderDuration) }

    private enum Metrics {
        /// Панель с кнопками: 19,955 + 55,875 + 7,982 + 17 + 19,955.
        static let actionBar: CGFloat = 120.767
        /// Скругление нижних углов белой карточки.
        static let cardRadius: CGFloat = 32.002
        /// Ширина колонки контента (390 − 2 × 24).
        static let content: CGFloat = 342
        static let icon: CGFloat = 64
        static let navRow: CGFloat = 48
        static let tile: CGFloat = 120
        /// Насколько выше геометрического центра стоит иконка на лоадере.
        static let centerLift: CGFloat = 38
        /// Размер иконки в центре, до усадки.
        static let centerScale: CGFloat = 1.5
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let fullHeight = proxy.size.height + topInset + proxy.safeAreaInsets.bottom
            let stage = Stage(
                width: proxy.size.width,
                height: fullHeight,
                topInset: topInset,
                iconCenterY: topInset + Metrics.navRow + outcome.contentTop + Metrics.icon / 2
            )

            Group {
                if isAnimating {
                    TimelineView(.animation) { context in
                        frame(at: context.date.timeIntervalSince(startedAt), stage: stage)
                    }
                } else {
                    frame(at: anim.total, stage: stage)
                }
            }
            .frame(width: proxy.size.width, height: fullHeight)
            // Работаем в координатах полного экрана: макет считает высоты от его
            // кромки, а не от безопасной зоны.
            .offset(y: -topInset)
        }
        .background(outcome.deepBackground.ignoresSafeArea())
        .onAppear(perform: play)
    }

    /// Всё, что нужно знать кадру о геометрии экрана.
    private struct Stage {
        let width: CGFloat
        let height: CGFloat
        let topInset: CGFloat
        /// Куда иконка приезжает в финале.
        let iconCenterY: CGFloat

        var iconCenter: CGPoint { CGPoint(x: width / 2, y: iconCenterY) }
        /// Насколько ниже финальной точки иконка стоит на лоадере.
        var lift: CGFloat { max(0, height / 2 - iconCenterY - Metrics.centerLift) }

        /// Сколько от иконки до кромки экрана в заданном направлении. Экран
        /// вытянутый, и до боковой кромки вдвое ближе, чем до верхней: если
        /// мерить разлёт одной длиной на всех, боковые партиклы улетают за край
        /// втрое быстрее верхних, и поле редеет по краям.
        func edgeDistance(angle: Double) -> CGFloat {
            let dx = CGFloat(sin(angle))
            let dy = CGFloat(-cos(angle))
            let horizontal = abs(dx) < 0.001
                ? CGFloat.infinity
                : (dx > 0 ? width - iconCenter.x : iconCenter.x) / abs(dx)
            let vertical = abs(dy) < 0.001
                ? CGFloat.infinity
                : (dy > 0 ? height - iconCenter.y : iconCenter.y) / abs(dy)
            return min(horizontal, vertical)
        }
    }

    // MARK: Кадр

    private func frame(at elapsed: TimeInterval, stage: Stage) -> some View {
        // Все прогрессы сырые, 0…1. Кривую накладывает тот, кто величину
        // использует, — по роли из `Ease` и ровно один раз.
        let entranceP = prog(elapsed, 0, anim.entrance)
        let appearP = prog(elapsed, 0, 0.2)
        let pullP = prog(elapsed, anim.loaderStart, anim.loader)
        let shotP = prog(elapsed, anim.releaseStart, anim.circlesFlight)
        let settleP = prog(elapsed, anim.releaseStart, anim.settle)
        let handoverP = prog(elapsed, anim.releaseStart, anim.badgeHandover)
        let fadeP = prog(elapsed, anim.fadeStart, anim.fadeDur)
        let panelP = prog(elapsed, anim.panelStart, anim.panelDur)
        let glowP = prog(elapsed, anim.glowStart, anim.glowDur)
        let buttonsP = prog(elapsed, anim.buttonsStart, anim.buttonsDur)

        // Один перелёт по ширине после прилёта и один по масштабу после усадки.
        let bounce = 0.34 * OutcomeAnim.k
        let squish: CGFloat = {
            if elapsed <= anim.entrance {
                return lerp(0.4, 1.0, Ease.move(clamp01((entranceP - 0.2) / 0.8)))
            }
            return 1 + 0.12 * overshootPulse(clamp01(CGFloat((elapsed - anim.entrance) / bounce)))
        }()
        let settleEnd = anim.releaseStart + anim.settle
        let overall: CGFloat = {
            if elapsed <= anim.releaseStart { return Metrics.centerScale }
            if elapsed <= settleEnd { return lerp(Metrics.centerScale, 1.0, Ease.move(settleP)) }
            return 1 + 0.06 * overshootPulse(clamp01(CGFloat((elapsed - settleEnd) / bounce)))
        }()

        // Иконка и капли поднимаются по одной кривой — иначе они летят рядом,
        // но не вместе, и это читается как рассинхрон.
        let entranceOffset = (stage.height * 0.5 + 120) * (1 - Ease.move(entranceP))
        let iconOffset = stage.lift * (1 - Ease.move(settleP)) + entranceOffset

        return ZStack(alignment: .top) {
            actionBar(buttons: buttonsP)
                .frame(height: Metrics.actionBar)
                .frame(maxHeight: .infinity, alignment: .bottom)

            card(
                stage: stage,
                elapsed: elapsed,
                height: stage.height - Metrics.actionBar * Ease.move(panelP),
                iconOffset: iconOffset,
                scaleX: squish * overall,
                scaleY: overall,
                appear: appearP,
                pull: pullP,
                shot: shotP,
                entranceP: entranceP,
                loaderAngle: elapsed * 300,
                handover: handoverP,
                fade: fadeP,
                glow: glowP,
                isLoading: elapsed < anim.releaseStart
            )
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: play)
    }

    // MARK: Белая карточка

    /// Навбар и контент живут на одной белой плоскости: в макете это два блока
    /// подряд одного цвета, а скругление есть только снизу. По ходу пятого такта
    /// карточка ужимается снизу — этим движением и открывается тёмная панель.
    private func card(
        stage: Stage,
        elapsed: TimeInterval,
        height: CGFloat,
        iconOffset: CGFloat,
        scaleX: CGFloat,
        scaleY: CGFloat,
        appear: CGFloat,
        pull: CGFloat,
        shot: CGFloat,
        entranceP: CGFloat,
        loaderAngle: Double,
        handover: CGFloat,
        fade: CGFloat,
        glow: CGFloat,
        isLoading: Bool
    ) -> some View {
        ZStack {
            WBColor.bgBase

            glowLayer(progress: glow)

            drops(stage: stage, pull: pull, shot: shot, entranceP: entranceP)
            wave(stage: stage, elapsed: elapsed)
            particleLayer(stage: stage, raw: prog(elapsed, anim.stageEnd + anim.particleDelay, anim.particlesDur))

            VStack(spacing: 0) {
                Color.clear.frame(height: stage.topInset)
                WBNavBar(
                    title: isLoading ? scenario.loaderTitle : (scenario.resultTitle ?? outcome.title),
                    subtitle: config.subtitle,
                    leading: isLoading ? .none : .close,
                    onLeading: onClose
                )
                .animation(.snappy(duration: 0.3), value: isLoading)

                centerBlock(
                    iconOffset: iconOffset,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    appear: appear,
                    loaderAngle: loaderAngle,
                    handover: handover,
                    fade: fade,
                    isLoading: isLoading
                )
                .frame(width: Metrics.content)
                .padding(.top, outcome.contentTop)

                Spacer(minLength: 0)
            }

            tiles(elapsed: elapsed)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: height, alignment: .top)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: Metrics.cardRadius,
                bottomTrailingRadius: Metrics.cardRadius,
                style: .continuous
            )
        )
    }

    // MARK: Такт 6 — свечение

    /// Свет под карточкой. Форма и жизнь света — единственное, чем отличаются
    /// копии v2: разметка, тайминги и палитра у них те же.
    @ViewBuilder
    private func glowLayer(progress: CGFloat) -> some View {
        switch scenario.glowStyle {
        case .gradient: glowBand(progress: progress)
        case .ember: emberBand(progress: progress)
        }
    }

    /// Живое свечение вместо градиента. Блок тот же самый: высота 345,84, прижат
    /// к нижней кромке карточки и свисает за неё примерно на 1, как в макете.
    ///
    /// Зажигание короче, чем у градиента: там оно вытягивало весь старт такта,
    /// потому что лужица света на минимуме диммера уже заметная. Здесь свет
    /// начинает с куда меньшей отметки и растёт сам, так что прозрачности хватает
    /// ровно на то, чтобы первый кадр не хлопнул.
    private func emberBand(progress: CGFloat) -> some View {
        let ignition = Ease.appear(clamp01(progress / 0.08))

        return Color.clear
            .overlay(alignment: .bottom) {
                EmberGlowField(
                    palette: outcome.ember,
                    rise: progress,
                    clock: startedAt
                )
                .frame(height: WBColor.glowHeight)
                .opacity(Double(ignition))
                .offset(y: 1.1)
            }
    }

    /// Слои свечения: эллипс шире экрана с центром в верхней кромке блока 345,84.
    /// Виден ровно низ эллипса — из-за этого у краёв цвет поднимается заметно
    /// выше, чем по центру, где до самых плиток остаётся белое.
    ///
    /// Свет не открывается шторкой, а включается диммером. Источник — за нижней
    /// кромкой карточки, поэтому «прибавить мощность» и «расширить зону охвата» —
    /// это одно и то же движение: чем сильнее свет, тем дальше от кромки он
    /// достаёт и тем плотнее цвет в уже освещённом месте.
    ///
    /// Технически это `endRadiusFraction`. У градиента центр прозрачный, а цвет
    /// живёт на внешнем радиусе. Растягиваем этот радиус в `1 / spread` раз —
    /// и параметр градиента в каждой точке становится ровно `spread` от финального.
    /// При `spread` около 0,3 он нигде не дотягивает даже до первого стопа, то
    /// есть света ещё нет; дальше он проступает в нижних углах — там до кромки
    /// ближе всего — и оттуда растёт вверх, попутно набирая плотность.
    private func glowBand(progress: CGFloat) -> some View {
        // Своя кривая, и это единственное место, где она допустима: диммер — не
        // перемещение и не проявление, а ручка, которую крутят с постоянной
        // скоростью. Площадь освещённого растёт примерно как квадрат яркости,
        // так что глазу и без разгона кажется, что свет прибавляет всё быстрее;
        // 0,85 — только мягкая посадка в конце, чтобы свет осел, а не обрубился.
        let spread = lerp(Self.glowSpreadFrom, 1, pow(progress, 0.85))
        // На минимуме лужица света уже есть — её и зажигаем коротким наплывом,
        // иначе она возникает из ниоткуда целым пятном.
        let ignition = Ease.appear(clamp01(progress / 0.15))

        return Color.clear
            .overlay(alignment: .bottom) {
                ZStack {
                    ForEach(Array(outcome.glow.enumerated()), id: \.offset) { _, layer in
                        EllipticalGradient(
                            gradient: layer.gradient,
                            center: .center,
                            startRadiusFraction: 0,
                            endRadiusFraction: 0.5 / spread
                        )
                        .frame(width: layer.size.width, height: layer.size.height)
                        .opacity(layer.opacity)
                    }
                }
                // Поднимаем эллипсы так, чтобы их центр встал на верхнюю кромку
                // блока, и обрезаем всё, что выше.
                .offset(y: -WBColor.glowHeight / 2)
                .frame(height: WBColor.glowHeight)
                .clipped()
                .opacity(Double(ignition))
                // В макете блок свисает за нижнюю кромку карточки примерно на 1.
                .offset(y: 1.1)
            }
    }

    /// Минимальная яркость диммера. Первый стоп градиента — 0,32, значит на 0,42
    /// свет уже читается, но добивает всего на 83 pt вверх от кромки: маленькая
    /// лужица у самого низа, с которой и начинается нарастание.
    private static let glowSpreadFrom: CGFloat = 0.42

    // MARK: Такты 1–5 — центральный блок

    private func centerBlock(
        iconOffset: CGFloat,
        scaleX: CGFloat,
        scaleY: CGFloat,
        appear: CGFloat,
        loaderAngle: Double,
        handover: CGFloat,
        fade: CGFloat,
        isLoading: Bool
    ) -> some View {
        VStack(spacing: WBSpace.x3) {
            VStack(spacing: WBSpace.x3) {
                CounterpartyIcon(
                    icon: config.icon,
                    outcome: outcome,
                    size: Metrics.icon,
                    loaderAngle: loaderAngle,
                    handover: handover
                )
                .scaleEffect(x: scaleX, y: scaleY, anchor: .top)
                .offset(y: iconOffset)
                .opacity(Double(Ease.appear(appear)))

                Text(config.counterparty)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textPrimary)
                    .frame(height: WBLineHeight.body)
                    .reveal(fade)
            }

            VStack(spacing: 0) {
                Text("−" + Money.rub(amount))
                    .font(WBFont.successAmount)
                    .foregroundStyle(WBColor.textPrimary)
                    .monospacedDigit()
                    .frame(height: WBLineHeight.balance)
                    .reveal(fade)

                if outcome.showsAmountDetails {
                    if let badge {
                        WBBadgeView(badge: badge)
                            .padding(.top, WBSpace.x2)
                            .reveal(fade)
                    }
                    if let chip = config.chip {
                        tooltip(chip)
                            .padding(.top, WBSpace.x2)
                            .reveal(fade)
                    }
                }
            }
        }
    }

    /// Тултип с хвостиком (макет 925:207412): хвостик 20×7 с отбивкой 4, под ним
    /// плашка 13/17 с полями 12 × 8.
    private func tooltip(_ text: String) -> some View {
        VStack(spacing: 0) {
            TooltipArrow(fill: WBColor.bgMinus1)
            Text(text)
                .font(WBFont.description)
                .foregroundStyle(WBColor.textPrimary)
                .frame(height: WBLineHeight.description)
                .padding(.horizontal, WBSpace.x3)
                .padding(.vertical, WBSpace.x2)
                .background(
                    WBColor.bgMinus1,
                    in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
                )
        }
        .padding(.top, WBSpace.x1)
    }

    // MARK: Такт 6 — плитки на волне цвета

    /// Макет 925:207427 / 927:207931 / 927:207879: плитки прижаты к нижней кромке
    /// белой плоскости с отбивкой 16 и лежат поверх свечения. Проявляются, когда
    /// фронт наливающегося градиента доходит до их строки.
    private func tiles(elapsed: TimeInterval) -> some View {
        HStack(spacing: WBSpace.x1_5) {
            ForEach(Array(outcome.tiles.enumerated()), id: \.element.id) { index, tile in
                tileView(tile)
                    .reveal(
                        prog(
                            elapsed,
                            anim.tilesStart + Double(index) * anim.tilesStagger,
                            anim.tilesDur
                        ),
                        rise: 14
                    )
            }
        }
        .frame(height: Metrics.tile)
        .padding(.horizontal, WBSpace.x4)
        .padding(.bottom, WBSpace.x4)
    }

    private func tileView(_ tile: PromoTile) -> some View {
        tile.background
            .frame(maxWidth: tile.isWide ? .infinity : Metrics.tile, maxHeight: .infinity)
            // Иллюстрация свисает за нижнюю кромку — её обрезает скругление.
            .overlay(alignment: .topLeading) { art(tile.art) }
            .overlay(alignment: .topLeading) {
                Text(tile.text)
                    .font(WBFont.descriptionAccent)
                    .foregroundStyle(tile.foreground)
                    // 13/17 в две строки: SF Pro на 13 даёт ≈15,5, добираем.
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(WBSpace.x3)
            }
            .overlay(alignment: .topLeading) { accent(tile.accent, foreground: tile.foreground) }
            .clipShape(RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous))
    }

    @ViewBuilder
    private func art(_ art: TileArt?) -> some View {
        if let art {
            Image(art.asset)
                .resizable()
                .scaledToFill()
                .frame(width: art.size, height: art.size)
                .offset(x: art.x, y: art.y)
        }
    }

    @ViewBuilder
    private func accent(_ accent: TileAccent?, foreground: Color) -> some View {
        if let accent {
            ZStack(alignment: .topLeading) {
                art(accent.art)

                Text(accent.text)
                    // 27,913/23 Bold — крупная строка под текстом плитки.
                    .font(WBFont.hauss(27.913, .bold))
                    .foregroundStyle(foreground)
                    .frame(height: 23)
                    .offset(x: accent.origin.x, y: accent.origin.y)

                if let badge = accent.badge {
                    WBBadgeView(badge: badge)
                        .offset(x: accent.badgeOrigin.x, y: accent.badgeOrigin.y)
                }
            }
        }
    }

    // MARK: Такт 5 — панель с кнопками

    /// Панель стоит на своём месте всегда, её закрывает белая карточка. Когда
    /// карточка ужимается, панель открывается — кнопки выезжают вместе с ней.
    private func actionBar(buttons: CGFloat) -> some View {
        HStack(spacing: 11.143) {
            ForEach(outcome.actions) { action in
                actionButton(action)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(outcome.actionBarOpacity)
        .reveal(buttons, rise: 14)
    }

    private func actionButton(_ action: OutcomeAction) -> some View {
        Button {
            Haptics.tap()
            if action.closes { onClose() }
        } label: {
            VStack(spacing: 7.982) {
                RoundedRectangle(cornerRadius: 15.964, style: .continuous)
                    .fill(outcome.actionFill)
                    .frame(width: 55.875, height: 55.875)
                    .overlay {
                        DSIconView(icon: action.icon, size: 23.946)
                    }
                Text(action.title)
                    .font(WBFont.successAction)
                    .foregroundStyle(outcome.actionLabel)
                    .frame(height: 17)
            }
            .frame(width: 79.821)
        }
        .buttonStyle(.plain)
    }

    // MARK: Такты 1–4 — эффекты под контентом

    /// Капли: поднимаются снизу вместе с иконкой, натягиваются на лоадере
    /// и выстреливают в неё по кривой Безье.
    @ViewBuilder
    private func drops(stage: Stage, pull: CGFloat, shot: CGFloat, entranceP: CGFloat) -> some View {
        let fadeIn = Ease.appear(clamp01(entranceP / 0.6))
        // Та же кривая, что у иконки: они поднимаются одним движением.
        let rise = (1 - Ease.move(entranceP)) * 220
        let flight = Ease.move(shot)          // полёт по дуге — перемещение
        let collapse = Ease.accelerate(shot)  // схлопывание в точку — разгон
        let tint = config.icon.tint
        let colors = [tint.glowHighlight(), tint]

        ForEach(0..<2, id: \.self) { index in
            let start = CGPoint(x: stage.width * (index == 0 ? 0.15 : 0.85), y: stage.height)
            let bow: CGFloat = index == 0 ? -40 : 40
            let control = CGPoint(
                x: (start.x + stage.iconCenter.x) / 2 + bow,
                y: (start.y + stage.iconCenter.y) / 2 - 60
            )
            let x = bezier(start.x, control.x, stage.iconCenter.x, flight)
            let y = bezier(start.y, control.y, stage.iconCenter.y, flight)

            // До выстрела капля тянется вверх (рогатка), после — сжимается в точку.
            let stretch: CGFloat = shot <= 0
                ? lerp(1.0, 1.55, Ease.accelerate(pull))
                : lerp(1.55, 0.4, collapse)
            let scale: CGFloat = shot <= 0 ? 1.0 : lerp(1.0, 0.2, collapse)
            // Гаснет на последней десятой пути, с ускорением.
            let vanish = Ease.accelerate(clamp01((shot - 0.9) / 0.1))
            let opacity = 0.42 * (1 - vanish) * fadeIn

            if opacity > 0.001 {
                Image("GlowBlob")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    .frame(width: 300 * scale, height: 360 * scale * stretch)
                    .scaleEffect(x: index == 0 ? 1 : -1, y: 1)
                    .rotationEffect(.degrees(index == 0 ? -12 : 12))
                    .blur(radius: 48)
                    .opacity(Double(opacity))
                    .position(x: x, y: y + rise)
            }
        }
    }

    /// Волна: расходится из иконки в момент попадания капель.
    @ViewBuilder
    private func wave(stage: Stage, elapsed: TimeInterval) -> some View {
        let t = CGFloat(elapsed - anim.stageEnd)
        if t >= 0 {
            let reach: CGFloat = 0.30 * CGFloat(OutcomeAnim.k)
            let fadeDur: CGFloat = 0.25 * CGFloat(OutcomeAnim.k)
            // Волна расходится с торможением, а гаснет с ускорением: удар резкий,
            // затухание мягкое на входе и быстрое на выходе.
            let diameter = lerp(80, 400, Ease.appear(clamp01(t / reach)))
            let opacity = 0.20 * (1 - Ease.accelerate(clamp01((t - reach) / fadeDur)))
            if opacity > 0.001 {
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [WBColor.bgBase, config.icon.tint]),
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    ))
                    .frame(width: diameter, height: diameter)
                    .blur(radius: 4)
                    .opacity(Double(opacity))
                    .position(stage.iconCenter)
            }
        }
    }

    @ViewBuilder
    private func particleLayer(stage: Stage, raw: CGFloat) -> some View {
        ForEach(particles) { particle in
            // Разлёт тормозит по мере удаления, появление тормозит, уход ускоряется.
            let e = Ease.appear(clamp01((raw - particle.delay) / (1 - particle.delay)))
            let distance = particle.distanceFrac * stage.edgeDistance(angle: particle.angle)
            let pop = Ease.appear(clamp01(e / 0.12))
            let fade = e <= 0 ? 0 : 1 - Ease.accelerate(clamp01((e - 0.85) / 0.15))
            if fade > 0 {
                Image(particle.asset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: particle.size, height: particle.size)
                    .foregroundStyle(particle.color)
                    .rotationEffect(.degrees(particle.rotation * e))
                    .scaleEffect(pop)
                    .opacity(Double(fade))
                    .position(
                        x: stage.iconCenter.x + sin(particle.angle) * distance * e,
                        y: stage.iconCenter.y - cos(particle.angle) * distance * e
                    )
            }
        }
    }

    // MARK: Запуск

    private func play() {
        // Партиклы летят по белой карточке, свечения там ещё нет, поэтому цвета
        // берём контрастные: акцент исхода, его тёмная подложка и бренд
        // получателя — так разлёт принадлежит и статусу, и адресату.
        particles = OutcomeParticle.make(colors: [
            outcome.accent,
            outcome.deepBackground,
            config.icon.tint,
        ])
        startedAt = .now
        isAnimating = true

        Haptics.impact(.soft)                                        // старт вылета
        beat(anim.entrance) { Haptics.impact(.rigid) }               // прилёт в центр
        beat(anim.releaseStart) { Haptics.impact(.medium) }          // выстрел
        beat(anim.fadeStart) { Haptics.notification(.success) }      // контент и панель
        beat(anim.glowStart) { Haptics.impact(.soft) }               // наливание

        beat(anim.total + 0.05) {
            isAnimating = false
            // При замедлении гоняем по кругу — так удобно разбирать такты.
            if OutcomeAnim.k > 1 {
                beat(1.0) { play() }
            }
        }
    }

    private func beat(_ delay: Double, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}
