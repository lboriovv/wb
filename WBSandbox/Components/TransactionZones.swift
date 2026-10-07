import SwiftUI

// Зоны транзакционного экрана. Каждая знает только про свои данные и ничего —
// про режим. Порядок зон задаёт TransactionScreen.

// MARK: - Сумма + комиссия + назначение

struct AmountZone: View {
    let input: AmountInput
    /// Группа бейджей под суммой (макет: `badge group`, gap 4).
    let badges: [BadgeSpec]
    /// WB-баллы за выбранный способ оплаты. nil — в этом сценарии бейджа нет.
    var bonusPoints: Int?
    let message: MessageBubble?
    /// Каретка есть только там, где сумму набирают: под ней стоит клавиатура.
    /// Без клавиатуры мигающая палочка обещает ввод, которого нет.
    var showsCaret: Bool = true

    // Состояние комментария и подарков живёт в модели, сюда приходит готовым.
    let isCommentFilled: Bool
    let commentText: String
    let gifts: [MessageSticker]
    let showsGiftButton: Bool
    let onTapComment: () -> Void
    let onTapGift: () -> Void
    let onRemoveGift: (String) -> Void

    var body: some View {
        VStack(spacing: WBSpace.x2) {
            VStack(spacing: WBSpace.x2) {
                amountLine
                if bonusPoints != nil || !badges.isEmpty {
                    HStack(spacing: WBSpace.x1) {
                        if let bonusPoints {
                            WBBonusBadgeView(points: bonusPoints)
                        }

                        ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                            WBBadgeView(badge: badge)
                        }
                    }
                }
            }

            if let message {
                MessageZone(
                    message: message,
                    isCommentFilled: isCommentFilled,
                    commentText: commentText,
                    gifts: gifts,
                    showsGiftButton: showsGiftButton,
                    onTapComment: onTapComment,
                    onTapGift: onTapGift,
                    onRemoveGift: onRemoveGift
                )
            }
        }
    }

    /// «1 000|₽» — число, мигающая зелёная каретка, знак рубля через отступ 6.
    /// Там, где сумму не набирают, каретки нет и строка сжимается на её ширину.
    ///
    /// Без `contentTransition(.numericText())`: этот модификатор меняет бокс текста
    /// и уводил каретку выше цифр. Выравнивание по центру строки — каретка 44 pt
    /// перекрывает цифры и чуть выступает сверху и снизу, как в макете.
    private var amountLine: some View {
        HStack(alignment: .center, spacing: 0) {
            AmountDigits(text: input.displayInteger + (input.displayFraction ?? ""))

            if showsCaret {
                AmountCaret()
            }

            Text("₽")
                .font(WBFont.balance)
                .foregroundStyle(WBColor.textPrimary)
                .fixedSize()
                .padding(.leading, WBSpace.x1_5)
        }
    }
}

// MARK: - Цифры суммы

/// Число посимвольно: каждая цифра — своя вьюха, поэтому новая может вылететь снизу,
/// увеличиваясь. Одним `Text` такое не анимируется — SwiftUI подменил бы строку.
///
/// Идентичность цифры — её номер СЛЕВА, и он не меняется никогда: набор всегда идёт
/// справа. Поэтому при переходе через разряд («999» → «1 000») переезжает только
/// разделитель, а уже стоящие цифры сохраняют вьюхи и не переигрывают появление.
/// Разделитель разрядов появляется мгновенно — ему анимация не нужна.
struct AmountDigits: View {
    let text: String

    private struct Glyph: Identifiable {
        let id: String
        let character: Character
        let isDigit: Bool
    }

    private var glyphs: [Glyph] {
        var digitIndex = 0
        return text.map { character in
            if character.isNumber {
                defer { digitIndex += 1 }
                return Glyph(id: "d\(digitIndex)", character: character, isDigit: true)
            }
            return Glyph(id: "s\(digitIndex)", character: character, isDigit: false)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(glyphs) { glyph in
                Text(String(glyph.character))
                    .font(WBFont.balance)
                    .foregroundStyle(WBColor.textPrimary)
                    .monospacedDigit()
                    .fixedSize()
                    .transition(glyph.isDigit ? .digitAppear : .identity)
            }
        }
        // Ровная кривая без отскока: пружина давала перелёт на каждом нажатии, и
        // число заметно качало.
        .animation(.easeOut(duration: 0.18), value: text)
    }
}

/// Цифра выезжает снизу, увеличиваясь от уменьшенного размера, и проявляется.
/// Якорь масштаба снизу — цифра «вырастает» с базовой линии.
private struct DigitAppearModifier: ViewModifier {
    /// 1 — цифры ещё нет, 0 — она на месте.
    let progress: Double

    func body(content: Content) -> some View {
        content
            .opacity(1 - progress)
            .scaleEffect(1 - 0.28 * progress, anchor: .bottom)
            .offset(y: 14 * progress)
    }
}

extension AnyTransition {
    static var digitAppear: AnyTransition {
        .modifier(
            active: DigitAppearModifier(progress: 1),
            identity: DigitAppearModifier(progress: 0)
        )
    }
}

/// Каретка ввода суммы. Только мерцает — не дёргается и не смещается на вводе.
struct AmountCaret: View {
    @State private var isOn = true

    var body: some View {
        Rectangle()
            .fill(WBColor.textAccent)
            .frame(width: 2, height: WBLineHeight.balance)
            .opacity(isOn ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isOn = false
                }
            }
    }
}

// MARK: - Сообщение к переводу

/// Тултип с комментарием, кнопка подарка и прикреплённые подарки.
///
/// Хвостик тултипа всегда по центру экрана: зона занимает всю ширину, а чип с
/// кнопкой центрируется внутри. Поэтому при появлении кнопки чип смещается влево,
/// а язычок остаётся на месте.
struct MessageZone: View {
    let message: MessageBubble
    let isCommentFilled: Bool
    let commentText: String
    let gifts: [MessageSticker]
    let showsGiftButton: Bool
    let onTapComment: () -> Void
    let onTapGift: () -> Void
    let onRemoveGift: (String) -> Void

    private var isComment: Bool { message.kind == .comment }
    private var shownText: String { isComment ? commentText : message.text }
    private var isPlaceholder: Bool { isComment ? !isCommentFilled : true }

    var body: some View {
        VStack(spacing: gifts.isEmpty ? 0 : WBSpace.x3) {
            VStack(spacing: 0) {
                if message.hasTooltipArrow {
                    TooltipArrow()
                        .padding(.top, WBSpace.x1)
                }
                // items-end в макете: кнопка подарка выравнивается по низу чипа.
                // fixedSize обязателен: без него текст пузыря забирает всю доступную
                // ширину и выталкивает кнопку подарка к правому краю экрана.
                HStack(alignment: .bottom, spacing: WBSpace.x2) {
                    bubble
                    if showsGiftButton {
                        giftButton
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity)

            // Строка подарков присутствует всегда, просто схлопнута: если её
            // монтировать заново, первый подарок появляется без анимации, потому
            // что вставляется весь контейнер, а не плитка.
            giftRow
                .frame(height: gifts.isEmpty ? 0 : 56)
                .opacity(gifts.isEmpty ? 0 : 1)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.68), value: gifts.count)
        .animation(.snappy(duration: 0.25), value: isCommentFilled)
    }

    private var bubble: some View {
        Text(isPlaceholder && isComment ? message.placeholder : shownText)
            .font(WBFont.description)
            .foregroundStyle(isPlaceholder ? WBColor.textSecondary : WBColor.textPrimary)
            .multilineTextAlignment(.center)
            // Ограничение переноса из макета: контент максимум 304. Внутри
            // обжимающего HStack эта рамка не растягивает пузырь, а только
            // задаёт, где текст начнёт переноситься.
            .frame(maxWidth: 304)
            .padding(.horizontal, WBSpace.x3)
            .padding(.vertical, WBSpace.x2)
            .background(
                WBColor.bgMinus1,
                in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
            )
            // Ширину НЕ ограничиваем рамкой: frame(maxWidth:) растягивает layout-
            // ширину пузыря и выталкивает кнопку подарка к правому краю. Текст и так
            // переносится по доступной ширине зоны — она близка к 304 из макета.
            .contentShape(Rectangle())
            .onTapGesture {
                guard isComment else { return }
                Haptics.tap()
                onTapComment()
            }
    }

    /// Кнопка «прикрепить подарок». Макет 818:140765: 32×32, радиус 10, подложка
    /// --mo-bg-level-2, картинка сверху по `cover`. Пропадает, когда выбраны все
    /// подарки.
    private var giftButton: some View {
        Button {
            Haptics.tap()
            onTapGift()
        } label: {
            Image("icSticker")
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .background(WBColor.bgLevel2)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Плитки 44×44 с наклоном, наезжающие друг на друга: первая сверху.
    private var giftRow: some View {
        HStack(spacing: -WBSpace.x1) {
            ForEach(Array(gifts.enumerated()), id: \.element.id) { index, gift in
                giftTile(gift)
                    .zIndex(Double(gifts.count - index))
                    .transition(.giftAppear)
            }
        }
    }

    private func giftTile(_ gift: MessageSticker) -> some View {
        let shape = RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
        return Image(gift.asset)
            .resizable()
            .scaledToFill()
            .frame(width: 44, height: 44)
            .background(gift.background ?? .clear)
            .clipShape(shape)
            .overlay {
                if gift.hasWhiteBorder {
                    shape.strokeBorder(.white, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                removeButton(gift.id).offset(x: 8, y: -8)
            }
            .rotationEffect(.degrees(gift.rotation))
    }

    private func removeButton(_ id: String) -> some View {
        Button {
            Haptics.tap()
            onRemoveGift(id)
        } label: {
            Circle()
                .fill(WBColor.bgMinus1)
                .frame(width: 24, height: 24)
                .overlay { Circle().strokeBorder(WBColor.bgBase, lineWidth: 2) }
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(WBColor.textPrimary)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Подсказка «не хватает»

struct HintZone: View {
    let shortfall: Decimal
    let onTopUp: () -> Void

    var body: some View {
        HStack(spacing: WBSpace.x2) {
            Text("Не хватает \(Money.rub(shortfall))")
                .font(WBFont.description)
                .foregroundStyle(WBColor.textPrimary)
            Spacer(minLength: WBSpace.x2)
            Button(action: onTopUp) {
                Text("Пополнить")
                    .font(WBFont.descriptionAccent)
                    .foregroundStyle(WBColor.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WBSpace.x3)
        .frame(height: 40)
        .background(
            WBColor.bgMinus1,
            in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
        )
    }
}

// MARK: - Строка «откуда» / «куда»

struct DetailRowView: View {
    let row: DetailRow
    var onTap: (() -> Void)?

    @ViewBuilder
    var body: some View {
        if let onTap {
            rowContent
                .onTapGesture {
                    Haptics.tap()
                    onTap()
                }
                .accessibilityAddTraits(.isButton)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        // Макет `🔷 listItemLite / medium - small`: Body gap 8, Content gap 8 и py 8.
        // Высота не фиксирована — её задаёт содержимое (получается те же ~56 pt).
        HStack(spacing: WBSpace.x2) {
            RowIconView(icon: row.icon)

            HStack(spacing: WBSpace.x2) {
                VStack(alignment: .leading, spacing: WBSpace.x0_5) {
                    text(row.top)
                    if let bottom = row.bottom {
                        text(bottom)
                    }
                }

                Spacer(minLength: 0)

                if let badge = row.trailingBadge {
                    WBBadgeView(badge: badge)
                }

                if !row.trailingIcons.isEmpty {
                    HStack(spacing: WBSpace.x1) {
                        ForEach(Array(row.trailingIcons.enumerated()), id: \.offset) { _, icon in
                            RowIconView(icon: icon, size: 24)
                        }
                    }
                }

                if row.showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WBColor.textSecondary)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, WBSpace.x2)
        }
        .contentShape(Rectangle())
    }

    private func text(_ spec: RowText) -> some View {
        Text(spec.value)
            .font(spec.emphasis == .primary ? WBFont.body : WBFont.description)
            .foregroundStyle(
                spec.emphasis == .primary ? WBColor.textPrimary : WBColor.textSecondary
            )
            .lineLimit(1)
            // Межстрочка задана явно: у SwiftUI своя (15,5 / 17,9), а макет требует
            // 17 / 20 — иначе строка выходит 51 pt вместо 55.
            .frame(
                height: spec.emphasis == .primary
                    ? WBLineHeight.body
                    : WBLineHeight.description
            )
    }
}

// MARK: - Строка с переключателем

struct ToggleRowView: View {
    let row: ToggleRow
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: WBSpace.x3) {
            Image(systemName: row.symbol)
                .font(.system(size: 20, weight: .semibold))
                // Без этого часть символов (календарь, закладка) приезжает
                // в своей многоцветной палитре и выглядит наклейкой.
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(row.symbolColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: WBSpace.x0_5) {
                Text(row.title)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textPrimary)
                // Строка ровно двухэтажная: подпись, которая не влезла, лучше
                // переписать короче, чем ронять её на клавиатуру.
                Text(row.subtitle)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: WBSpace.x2)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(WBColor.textAccent)
        }
        .frame(height: 56)
    }
}

// MARK: - Быстрые суммы

struct QuickAmountsZone: View {
    let values: [Decimal]
    let onPick: (Decimal) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Button {
                    Haptics.tap()
                    onPick(value)
                } label: {
                    Text(Money.rub(value))
                        .font(WBFont.bodyAccent)
                        .foregroundStyle(WBColor.controlsSecondary)
                        // Пятизначные суммы не должны ломаться на две строки —
                        // лучше слегка сжать кегль.
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, WBSpace.x3)
                        .frame(minHeight: 38)
                }
                .buttonStyle(.plain)
                if index < values.count - 1 { Spacer(minLength: 0) }
            }
        }
        .padding(.horizontal, WBSpace.x10)
        .padding(.vertical, WBSpace.x1)
    }
}

// MARK: - Клавиатура

struct KeypadZone: View {
    let onDigit: (String) -> Void
    let onSeparator: () -> Void
    let onBackspace: () -> Void

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        VStack(spacing: WBSpace.x1) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { index, digit in
                        key(digit) { onDigit(digit) }
                        if index < row.count - 1 { Spacer(minLength: 0) }
                    }
                }
            }
            HStack(spacing: 0) {
                key(",", action: onSeparator)
                Spacer(minLength: 0)
                key("0") { onDigit("0") }
                Spacer(minLength: 0)
                keyContainer {
                    Image(systemName: "delete.left")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(WBColor.textPrimary)
                } action: {
                    onBackspace()
                }
            }
        }
        .padding(.horizontal, WBSpace.x10)
    }

    private func key(_ label: String, action: @escaping () -> Void) -> some View {
        keyContainer {
            Text(label)
                .font(WBFont.title1)
                .foregroundStyle(WBColor.textPrimary)
        } action: {
            action()
        }
    }

    private func keyContainer<Content: View>(
        @ViewBuilder content: () -> Content,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.key()
            action()
        } label: {
            content()
                .frame(width: 56, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(KeyButtonStyle())
    }
}

private struct KeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(WBColor.bgMinus1)
                    .opacity(configuration.isPressed ? 1 : 0)
                    .frame(width: 48, height: 48)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Рекламный баннер вместо клавиатуры

/// Промо-полоса над клавиатурой. Место у неё чужое, поэтому она низкая и без
/// воздуха: акцент слева, две строки текста, никаких кнопок.
struct PromoZone: View {
    let banner: PromoBanner

    var body: some View {
        HStack(spacing: WBSpace.x3) {
            if let accent = banner.accent {
                Text(accent)
                    .font(WBFont.title3Bold)
                    .foregroundStyle(banner.foreground)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(banner.foreground)
                if let subtitle = banner.subtitle {
                    Text(subtitle)
                        .font(WBFont.description)
                        .foregroundStyle(banner.foreground.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, WBSpace.x3)
        .padding(.vertical, WBSpace.x2)
        .background(
            banner.background,
            in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
        )
        .padding(.horizontal, WBSpace.x4)
        .padding(.vertical, WBSpace.x1)
    }
}

// MARK: - Допродажа вместо клавиатуры

/// Второй счёт, который предлагаем оплатить заодно.
///
/// Строка устроена как «Автоплатёж» и «Пополнять регулярно» — на белом, без
/// своей подложки: на экране и так много всего, и лишняя серая рамка заставляет
/// разбираться, что это за отдельный блок.
///
/// Всё предложение читается одной фразой: что оплатить, сколько и почему сейчас.
/// Сумму берём из самого предложения, а не пишем руками, — на экране она уже
/// прибавилась к платежу, и разойтись эти два числа не могут.
struct UpsellZone: View {
    let offer: UpsellOffer
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: WBSpace.x3) {
            RowIconView(icon: offer.icon, size: 24)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: WBSpace.x0_5) {
                Text(offer.title)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textPrimary)
                    .lineLimit(1)
                // Сумма стоит в той же фразе, что и обоснование: «650 ₽ — обычно
                // платите в эти дни». Так предложение читается целиком, а число
                // не приходится искать глазами отдельно от причины.
                Text("\(Money.rub(offer.amount)) — \(offer.reason)")
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: WBSpace.x2)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(WBColor.textAccent)
        }
        .frame(height: 56)
        .padding(.horizontal, WBSpace.x4)
    }
}


// MARK: - Появление подарка

/// Подарок вылетает снизу вверх, докручиваясь до своего наклона, и одновременно
/// проявляется из нуля.
private struct GiftAppearModifier: ViewModifier {
    /// 1 — подарка ещё нет, 0 — он на месте.
    let progress: Double

    func body(content: Content) -> some View {
        content
            .opacity(1 - progress)
            .scaleEffect(1 - 0.14 * progress)
            .rotationEffect(.degrees(-22 * progress))
            .offset(y: 30 * progress)
    }
}

extension AnyTransition {
    static var giftAppear: AnyTransition {
        .modifier(
            active: GiftAppearModifier(progress: 1),
            identity: GiftAppearModifier(progress: 0)
        )
    }
}


// MARK: - Свап счетов

/// Кнопка «поменять счёта местами». Макет 898:71882: 32×32, радиус 10, белая
/// заливка и обводка 4 pt цветом `--mo-bg-level--1` — она садится на зазор между
/// карточками, и обводка сливается с ним. По центру экрана (x 179…211 из 390).
struct AccountSwapButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "repeat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WBColor.textPrimary)
                .frame(width: 32, height: 32)
                .background(
                    WBColor.bgBase,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(WBColor.bgMinus1, lineWidth: 4)
                }
        }
        .buttonStyle(.plain)
    }
}
