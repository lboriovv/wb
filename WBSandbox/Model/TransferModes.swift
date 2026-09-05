import SwiftUI

// Сценарии транзакционного экрана. Добавить новый = добавить сюда ещё один
// `TransactionConfig` и вписать его в `all`. Вёрстку трогать не надо.
//
// Поле `operation` привязывает сценарий к строке таблицы «Способы оплаты» —
// оттуда автоматически берётся набор платёжных рельсов для шита.
//
// Опечатки макета исправлены в тексте: «БЕЗ КОМИСИИ» → «БЕЗ КОМИССИИ»,
// «Камунальные услуги , счет» → «Коммунальные услуги, счёт»,
// «задолжности» → «задолженности», «мощенничества» → «мошенничества».

enum TransferModes {
    static let all: [TransactionConfig] = [
        byPhone,
        byPhoneAmbient,
        betweenAccounts,
        topUp,
        utilities,
        qr,
        budgetUIN,
        byCard,
        crossBorder,
    ]

    // MARK: Общие данные

    /// Счета списания. Одинаковы для всех сценариев — меняется только то, какие
    /// рельсы к ним применимы.
    ///
    /// Отдельного счёта «WB Банк + WB Кэш» здесь нет: WB Кэш — это доп. функция
    /// операции (`ExtraFunction.wbCash`), а не ещё один счёт. Иначе одно и то же
    /// решение пришлось бы принимать дважды — и в списке счетов, и переключателем.
    static var sharedAccounts: [Account] {
        [
            Account(
                id: "wb-1321",
                icon: .asset("icAccountWB"),
                amountTitle: Money.rub(1235),
                subtitle: "WB Банк ··1321",
                balance: 1235
            ),
            Account(
                id: "save-6489",
                icon: savingsIcon,
                amountTitle: Money.rub(96780),
                subtitle: "Накопительный счёт ··6489",
                balance: 96780
            ),
        ]
    }

    /// Сейф на светло-зелёной подложке — логотип «24/Fill/safeFill» из макета.
    static let savingsIcon = RowIcon.tile(
        "icSafe",
        CGSize(width: 20, height: 19),
        background: WBColor.badgeGreenStrongBg
    )

    private static func processing(
        subtitle: String,
        icon: RowIcon,
        counterparty: String,
        chip: String?
    ) -> SuccessConfig {
        SuccessConfig(
            title: TransactionOutcome.processing.title,
            subtitle: subtitle,
            icon: icon,
            counterparty: counterparty,
            chip: chip
        )
    }

    // MARK: 1. Перевод по номеру телефона

    static let byPhone = TransactionConfig(
        id: "by-phone",
        demoName: "По номеру телефона",
        operation: .byPhone,
        // В шаблоне в строке списания стоит логотип СБП — значит выбран этот рельс.
        defaultRail: .sbp,
        title: "Перевести по номеру",
        navTrailing: nil,
        // Свободная сумма набирается с нуля.
        initialAmount: 0,
        fee: .free,
        message: MessageBubble(
            kind: .comment,
            text: "Ещё раз тебя с днём рождения и счастья!",
            gifts: [
                MessageSticker(
                    id: "balloon",
                    asset: "stickerBalloon",
                    rotation: -4,
                    background: WBColor.bgRedLight,
                    hasWhiteBorder: true
                ),
                MessageSticker(id: "person", asset: "stickerPerson", rotation: 8),
            ]
        ),
        accounts: sharedAccounts,
        destination: DetailRow(
            id: "dest-phone",
            icon: .asset("icTBank"),
            top: .primary("Алина Ивановна Т."),
            bottom: .secondary("+7 913 654-11-56")
        ),
        toggles: [],
        suggestSlot: .amounts([1235, 500, 1000, 5000]),
        bottomSlot: .keypad,
        ctaTitle: "Продолжить",
        deliveryNote: "Деньги придут за несколько секунд",
        // Кадр успеха собран по итоговому макету 925:207394.
        success: SuccessConfig(
            title: TransactionOutcome.processing.title,
            subtitle: "Со счёта ··1321",
            icon: .squircle(
                "icTBankLogo",
                logo: CGSize(width: 38.4, height: 38.4),
                background: WBColor.brandYellow,
                offset: CGSize(width: 0, height: -1.6)
            ),
            counterparty: "Татьяна Л.",
            chip: "Возвращаю должок, спасибо!"
        )
    )

    // MARK: 1а. Тот же перевод по номеру, но с живым фоном

    /// Копия сценария 1 один в один — отличается только включённым световым
    /// слоем. Сделано копией, а не флагом на основном сценарии, чтобы на показе
    /// можно было открыть два экрана подряд и сравнить их вживую.
    ///
    /// На счёте 1 235 ₽, поэтому состояния перебираются с клавиатуры: пусто →
    /// покой, 500 → спокойное дыхание, 2000 → холмы приседают и ведут вниз.
    static var byPhoneAmbient: TransactionConfig {
        var config = byPhone
        config.id = "by-phone-ambient"
        config.demoName = "По номеру телефона · живой фон"
        config.ambient = .mounds
        return config
    }

    // MARK: 2. Между счетами

    static let betweenAccounts = TransactionConfig(
        id: "between-accounts",
        demoName: "Между счетами",
        operation: .betweenAccounts,
        title: "Перевести",
        navTrailing: nil,
        // Сумма свободная — набирается с нуля.
        initialAmount: 0,
        fee: .free,
        // Своему же счёту не пишут комментарий и не указывают назначение.
        message: nil,
        accounts: sharedAccounts,
        destination: nil,
        // Обе точки — свои счета, поэтому строка «куда» строится из счёта и между
        // строками появляется кнопка свапа.
        destinationAccountID: "save-6489",
        toggles: [],
        suggestSlot: .amounts([96780, 500, 1000, 5000]),
        bottomSlot: .keypad,
        ctaTitle: "Продолжить",
        deliveryNote: "Между своими счетами — мгновенно",
        success: processing(
            subtitle: "Со счёта ··1321",
            icon: savingsIcon,
            counterparty: "Накопительный счёт ··6489",
            chip: nil
        )
    )

    // MARK: 3. Пополнение счёта

    static let topUp = TransactionConfig(
        id: "top-up",
        demoName: "Пополнение счёта",
        operation: .topUp,
        title: "Пополнить",
        navTrailing: nil,
        // Сумма свободная — набирается с нуля.
        initialAmount: 0,
        fee: .free,
        message: nil,
        // При пополнении точка А — карта другого банка, а не свой счёт.
        accounts: [
            Account(
                id: "alfa-4417",
                icon: .symbol(name: "creditcard.fill", tint: .white, background: Color(hex: 0xEF3124)),
                amountTitle: "Карта другого банка",
                subtitle: "Альфа-Банк ··4417",
                balance: 250000
            ),
            Account(
                id: "tbank-8890",
                icon: .asset("icTBank"),
                amountTitle: "Карта другого банка",
                subtitle: "Т-Банк ··8890",
                balance: 250000
            ),
        ],
        destination: DetailRow(
            id: "dest-wb",
            icon: .asset("icAccountWB"),
            top: .primary("WB Банк ··1321"),
            bottom: .secondary(Money.rub(1235))
        ),
        toggles: [],
        // Автоматизация: разовое пополнение превращается в регулярное.
        suggestSlot: .automation(
            ToggleRow(
                id: "regular-topup",
                title: "Пополнять регулярно",
                subtitle: "Та же сумма в тот же день месяца",
                symbol: "arrow.clockwise"
            )
        ),
        bottomSlot: .keypad,
        ctaTitle: "Пополнить",
        deliveryNote: "Деньги придут в течение минуты",
        success: processing(
            subtitle: "Пополнение с Альфа-Банк ··4417",
            icon: .asset("icAccountWB"),
            counterparty: "WB Банк ··1321",
            chip: nil
        )
    )

    // MARK: 4. Оплата ЖКУ

    static let utilities = TransactionConfig(
        id: "utilities",
        demoName: "Оплата ЖКУ",
        operation: .serviceBill,
        title: "Оплатить ЖКУ",
        navTrailing: nil,
        initialAmount: 4000,
        // 4 000 × 0,000935 = 3,74 ₽ — ровно как в макете, но пересчитывается на вводе.
        fee: .rate(Decimal(string: "0.000935")!),
        message: MessageBubble(kind: .label, text: "Погашение задолженности"),
        accounts: sharedAccounts,
        destination: DetailRow(
            id: "dest-rvk",
            icon: .asset("icRVK"),
            top: .primary("РВК–Воронеж"),
            bottom: .secondary("Коммунальные услуги, счёт 1345")
        ),
        toggles: [],
        // Подпись говорит, что именно произойдёт после включения: у ЖКУ сумма
        // каждый месяц своя, поэтому важно, что списывать будем ровно по счёту.
        suggestSlot: .automation(
            ToggleRow(
                id: "autopay",
                title: "Автоплатёж",
                subtitle: "Оплатим счёт сами, когда он придёт",
                symbol: "calendar"
            )
        ),
        bottomSlot: .keypad,
        ctaTitle: "Продолжить",
        deliveryNote: "Перевод может занять до 2 часов",
        success: processing(
            subtitle: "Со счёта ··1321",
            icon: .asset("icRVK"),
            counterparty: "РВК–Воронеж",
            chip: "Погашение задолженности"
        )
    )

    // MARK: 5. Оплата по QR

    static let qr = TransactionConfig(
        id: "qr",
        demoName: "Оплата по QR",
        operation: .qr,
        title: "Оплата по QR-коду",
        navTrailing: nil,
        initialAmount: 4000,
        fee: .rate(Decimal(string: "0.000935")!),
        message: MessageBubble(kind: .label, text: "Погашение задолженности"),
        accounts: sharedAccounts,
        destination: DetailRow(
            id: "dest-qr",
            icon: .asset("icRVK"),
            top: .primary("РВК–Воронеж"),
            bottom: .secondary("Коммунальные услуги, счёт 1345")
        ),
        toggles: [],
        // Верхний слот пуст намеренно: на экране уже есть допродажа внизу, и две
        // истории в одном сценарии начинают конкурировать друг с другом.
        // Автоматизацию показываем в пополнении и ЖКУ, здесь — допродажу.
        suggestSlot: .none,
        // Сумма пришла из QR-кода, менять её нельзя — клавиатуры нет, вместо неё
        // место под рекламный баннер из макета.
        // Не продажа партнёра, а допродажа в контексте: человек платит за ЖКУ,
        // и интернет он оплачивает примерно в эти же дни. Предложение работает
        // от его календаря платежей, а не от рекламного бюджета — и включается
        // прямо здесь, добавляя второй счёт к этому же платежу.
        bottomSlot: .upsell(
            UpsellOffer(
                id: "upsell-internet",
                icon: .symbol(name: "wifi", tint: .white, background: WBColor.brandBlue),
                title: "Заодно оплатите интернет",
                reason: "обычно платите в эти же дни",
                amount: 650
            )
        ),
        ctaTitle: "Продолжить",
        deliveryNote: "Перевод может занять до 2 часов",
        success: processing(
            subtitle: "Со счёта ··1321",
            icon: .asset("icRVK"),
            counterparty: "РВК–Воронеж",
            chip: "Погашение задолженности"
        )
    )

    // MARK: 6. В бюджет по УИН

    static let budgetUIN = TransactionConfig(
        id: "budget-uin",
        demoName: "В бюджет по УИН",
        operation: .budgetWithUIN,
        title: "Платёж в бюджет",
        navTrailing: nil,
        initialAmount: 2300,
        fee: .free,
        message: MessageBubble(kind: .label, text: "Штраф ГИБДД"),
        accounts: sharedAccounts,
        destination: DetailRow(
            id: "dest-uin",
            icon: .symbol(name: "building.columns.fill", tint: .white, background: WBColor.brandBlue),
            top: .primary("УФК по г. Москве"),
            bottom: .secondary("УИН 18810277240000123456")
        ),
        toggles: [],
        // Скидка за раннюю оплату — это маркетинг, а не свойство перевода,
        // поэтому она живёт над клавиатурой, а не подписью под кнопкой.
        suggestSlot: .promo(
            PromoBanner(
                title: "Скидка на штраф",
                subtitle: "Действует до 12 августа",
                background: WBColor.bgPurpleLight,
                foreground: WBColor.violet,
                accent: "−50 %"
            )
        ),
        bottomSlot: .keypad,
        ctaTitle: "Оплатить",
        deliveryNote: "Платёж дойдёт до ведомства за 1–3 дня",
        success: processing(
            subtitle: "Со счёта ··1321",
            icon: .symbol(name: "building.columns.fill", tint: .white, background: WBColor.brandBlue),
            counterparty: "УФК по г. Москве",
            chip: "Штраф ГИБДД"
        )
    )

    // MARK: 7. По номеру карты

    static let byCard = TransactionConfig(
        id: "by-card",
        demoName: "По номеру карты",
        operation: .byCardNumber,
        title: "Перевести на карту",
        navTrailing: nil,
        // Сумма свободная — набирается с нуля.
        initialAmount: 0,
        fee: .rate(Decimal(string: "0.01")!),
        message: nil,
        accounts: sharedAccounts,
        destination: DetailRow(
            id: "dest-card",
            icon: .symbol(name: "creditcard.fill", tint: .white, background: WBColor.controlsSecondary),
            top: .primary("2200 ··· ··· 7834"),
            bottom: .secondary("Мир · Другой банк")
        ),
        toggles: [],
        suggestSlot: .amounts([500, 1000, 3000, 5000]),
        bottomSlot: .keypad,
        ctaTitle: "Продолжить",
        deliveryNote: "Деньги придут за несколько минут",
        success: processing(
            subtitle: "Со счёта ··1321",
            icon: .symbol(name: "creditcard.fill", tint: .white, background: WBColor.controlsSecondary),
            counterparty: "2200 ··· ··· 7834",
            chip: nil
        )
    )

    // MARK: 8. Трансграничный перевод

    static let crossBorder = TransactionConfig(
        id: "cross-border",
        demoName: "Трансграничный",
        operation: .crossBorder,
        title: "Перевод за рубеж",
        navTrailing: nil,
        // Сумма свободная — набирается с нуля.
        initialAmount: 0,
        fee: .rate(Decimal(string: "0.015")!),
        message: MessageBubble(kind: .label, text: "Помощь семье"),
        accounts: sharedAccounts,
        destination: DetailRow(
            id: "dest-cross",
            icon: .symbol(name: "globe", tint: .white, background: WBColor.violet),
            top: .primary("Азизбек Р."),
            bottom: .secondary("Узбекистан · UZS по курсу 148,2")
        ),
        toggles: [],
        suggestSlot: .amounts([5000, 10000, 20000, 50000]),
        bottomSlot: .keypad,
        ctaTitle: "Продолжить",
        deliveryNote: "Перевод идёт 1–2 рабочих дня",
        success: processing(
            subtitle: "Со счёта ··1321",
            icon: .symbol(name: "globe", tint: .white, background: WBColor.violet),
            counterparty: "Азизбек Р.",
            chip: "Помощь семье"
        )
    )
}
