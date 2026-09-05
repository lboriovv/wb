import SwiftUI

/// Один экран на все режимы. Порядок зон фиксирован, состав — из конфига.
/// Ни одного `if mode == ...`: экран не знает, что он «перевод» или «ЖКУ».
struct TransactionScreen: View {
    @Bindable var model: TransactionModel
    /// Возврат в список песочницы по шеврону в шапке.
    var onBack: () -> Void = {}

    private var config: TransactionConfig { model.config }

    /// Настроение живого фона. nil — на этом экране эффекта нет, и карточки
    /// заливаются обычным белым.
    private var ambientMood: Double? {
        config.ambient == nil ? nil : model.ambientMood
    }

    var body: some View {
        // Ни одного `ignoresSafeArea` внутри разметки: он расширяет не только свой
        // элемент, но и соседей, из-за чего шапка то уезжала под вырез, то нет.
        // Кромки закрашиваются фонами — они в разметке не участвуют вообще.
        VStack(spacing: WBSpace.x1) {
            navCard
            amountCard
            destinationCard
            controlsCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Порядок важен: каждый следующий .background уходит ГЛУБЖЕ. Поэтому белые
        // полосы кромок объявлены раньше серого фона, иначе серый их перекрывает.
        //
        // Белое за системным статус-баром и под home indicator: полосы выше и ниже
        // контента. 80 pt с запасом перекрывают вырез на любом устройстве, лишнее
        // уходит за кромку экрана.
        .background(alignment: .top) {
            WBColor.bgBase
                .frame(height: 80)
                .offset(y: -80)
        }
        .background(alignment: .bottom) {
            WBColor.bgBase
                .frame(height: 80)
                .offset(y: 80)
        }
        .background(WBColor.bgMinus1, ignoresSafeAreaEdges: .all)
        .sheet(isPresented: $model.isAccountSheetPresented) {
            AccountSheet(model: model)
                .presentationDetents([.height(sheetHeight)])
                .presentationCornerRadius(WBRadius.x6)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $model.isOutcomePresented) {
            OutcomeScreen(
                scenario: outcomeScenario,
                amount: model.amountValue,
                badge: model.feeBadge,
                onClose: { model.isOutcomePresented = false }
            )
        }
    }

    /// Высота шита считается по макету, а не подгоняется на глаз: строка списка 55,
    /// заголовок секции 24 + отбивка 12, зазор между блоками 16.
    private var sheetHeight: CGFloat {
        var blocks: [CGFloat] = []
        if model.showsRailPicker { blocks.append(24 + 12 + 48) }
        if model.availableExtra != nil { blocks.append(55) }
        blocks.append(24 + 12 + CGFloat(model.availableAccounts.count) * 55)

        let content = blocks.reduce(0, +) + CGFloat(blocks.count - 1) * WBSpace.x4 + WBSpace.x2
        // 36 — крестик с отступом сверху, 76 — кнопка «Готово» с отбивками.
        // Нижнюю безопасную зону детент добавляет сам, в высоту её не закладываем.
        return min(36 + content + 76, 700)
    }

    /// Из транзакционного экрана «Продолжить» ведёт на лоадер и «в обработке» —
    /// как в макете. Остальные исходы живут отдельными пунктами песочницы.
    private var outcomeScenario: OutcomeScenario {
        OutcomeScenario(
            id: config.id + "-processing",
            demoName: config.demoName,
            outcome: .processing,
            source: config
        )
    }

    // MARK: Шапка

    private var navCard: some View {
        WBNavBar(
            title: config.title,
            trailing: config.navTrailing,
            onLeading: onBack
        )
        .background(
            WBColor.bgBase,
            in: UnevenRoundedRectangle(
                bottomLeadingRadius: WBRadius.x5,
                bottomTrailingRadius: WBRadius.x5,
                style: .continuous
            )
        )
    }

    // MARK: Карточки контента

    // В шаблоне это не один белый блок, а три отдельные карточки на фоне
    // --mo-bg-level--1 с зазорами 4 pt (замерено по рендеру: серые полосы на
    // y 92…95, 421…424, 480…483). Группировка смысловая:
    //   «сколько и откуда» → «куда» → «управление».

    /// Сумма, сообщение, подсказка о нехватке и строка списания.
    private var amountCard: some View {
        VStack(spacing: 0) {
            // Зона ввода: pt 44, pb 16, px 16. Максимальной высоты нет — блок растёт
            // вместе с содержимым (длинный комментарий, подарки), снизу его держит
            // только минимум 232.
            AmountZone(
                input: model.amount,
                badges: model.amountBadges,
                message: config.message,
                showsCaret: model.isAmountEditable,
                isCommentFilled: model.isCommentFilled,
                commentText: model.commentText,
                gifts: model.attachedGifts,
                showsGiftButton: model.showsGiftButton,
                onTapComment: { model.toggleComment() },
                onTapGift: { model.addGift() },
                onRemoveGift: { model.removeGift($0) }
            )
            .frame(maxWidth: .infinity)
            .padding(.top, WBSpace.x11)
            .padding(.bottom, WBSpace.x4)
            .padding(.horizontal, WBSpace.x4)
            // Выравнивание по верху обязательно: иначе содержимое центрируется в
            // минимальной высоте и сумма прыгает вверх-вниз, когда появляются или
            // исчезают подарки.
            .frame(minHeight: 232, alignment: .top)

            Spacer(minLength: 0)

            // Серой плашки «Не хватает N ₽» больше нет: о пополнении говорит
            // сама кнопка, которая превращается в оранжевое «Пополнить на N ₽».

            if let source = model.sourceRow {
                DetailRowView(row: source) {
                    model.isAccountSheetPresented = true
                }
                .padding(.horizontal, WBSpace.x2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Единственная площадка живого фона: самое большое белое поле экрана,
            // и его нижняя кромка — это ровно строка с остатком счёта.
            ambientSurface(RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous))
        }
    }

    /// Точка Б и дополнительные строки вроде автоплатежа.
    @ViewBuilder
    private var destinationCard: some View {
        if model.destinationRow != nil || !config.toggles.isEmpty {
            VStack(spacing: 0) {
                if let destination = model.destinationRow {
                    DetailRowView(row: destination) {
                        model.isAccountSheetPresented = true
                    }
                    .padding(.horizontal, WBSpace.x2)
                }

                ForEach(config.toggles) { row in
                    ToggleRowView(
                        row: row,
                        isOn: Binding(
                            get: { model.isToggleOn(row.id) },
                            set: { model.setToggle(row.id, $0) }
                        )
                    )
                    .padding(.horizontal, WBSpace.x4)
                }
            }
            .frame(maxWidth: .infinity)
            .background(
                WBColor.bgBase,
                in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
            )
            // Кнопка свапа садится ровно на зазор между карточками «откуда» и «куда»:
            // её серая обводка сливается с зазором.
            .overlay(alignment: .top) {
                if config.allowsAccountSwap {
                    AccountSwapButton { model.swapAccounts() }
                        .offset(y: -18)
                }
            }
        }
    }

    /// Быстрые суммы, клавиатура (или баннер) и кнопка.
    private var controlsCard: some View {
        VStack(spacing: 0) {
            suggestSlot

            bottomSlot

            ctaZone
        }
        .frame(maxWidth: .infinity)
        // Живого фона здесь нет намеренно: свет под клавиатурой выглядывал из-под
        // кнопки и читался не как продолжение подсказки сверху, а как второе,
        // независимое пятно. Два пятна одновременно никуда не ведут.
        .background(
            WBColor.bgBase,
            in: UnevenRoundedRectangle(
                topLeadingRadius: WBRadius.x5,
                topTrailingRadius: WBRadius.x5,
                style: .continuous
            )
        )
    }

    /// Белая подложка карточки, а поверх неё — световой слой. Порядок именно
    /// такой: свет ложится на белое, но остаётся под контентом, иначе он
    /// затуманивал бы сумму и строку списания.
    @ViewBuilder
    private func ambientSurface<S: Shape>(_ shape: S) -> some View {
        ZStack {
            shape.fill(WBColor.bgBase)

            if let ambientMood {
                AmbientMoundsField(mood: ambientMood)
                    .clipShape(shape)
                    // Кнопка перекрашивается за 0,25 — свет намеренно медленнее:
                    // сначала переключается то, что человек нажимает, и только
                    // потом оседает фон, иначе оба движения читаются как одно
                    // мелькание.
                    .animation(.smooth(duration: 0.55), value: ambientMood)
            }
        }
    }

    /// Полоса над клавиатурой: быстрые суммы, автоматизация или промо.
    @ViewBuilder
    private var suggestSlot: some View {
        switch config.suggestSlot {
        case .amounts(let values):
            QuickAmountsZone(values: values) { value in
                model.applyQuickAmount(value)
            }
        case .automation(let row):
            ToggleRowView(
                row: row,
                isOn: Binding(
                    get: { model.isToggleOn(row.id) },
                    set: { model.setToggle(row.id, $0) }
                )
            )
            .padding(.horizontal, WBSpace.x4)
        case .promo(let banner):
            PromoZone(banner: banner)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var bottomSlot: some View {
        switch config.bottomSlot {
        case .keypad:
            KeypadZone(
                onDigit: { model.tapDigit($0) },
                onSeparator: { model.tapSeparator() },
                onBackspace: { model.tapBackspace() }
            )
        case .upsell(let offer):
            UpsellZone(
                offer: offer,
                isOn: Binding(
                    get: { model.isToggleOn(offer.id) },
                    set: { model.setUpsell(offer, $0) }
                )
            )
        case .empty:
            EmptyView()
        }
    }

    private var ctaZone: some View {
        // Зазор между кнопкой и пояснением — 8.
        VStack(spacing: WBSpace.x2) {
            switch model.cta {
            case .primary(let title):
                // Выключенного состояния нет: пустую сумму обыграем иначе.
                WBPrimaryButton(title: title) {
                    model.isOutcomePresented = true
                }
            case .topUp(let missing):
                // Денег не хватает — вместо перевода предлагаем пополнить.
                WBPrimaryButton(
                    title: "Пополнить на",
                    subtitle: Money.rub(missing),
                    fill: WBColor.ctaTopUp
                ) {
                    model.isAccountSheetPresented = true
                }
            }
            if let note = config.deliveryNote {
                Text(note)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
            }
        }
        .padding(.top, WBSpace.x4)
        .padding(.bottom, WBSpace.x2)
        .padding(.horizontal, WBSpace.x4)
    }
}
