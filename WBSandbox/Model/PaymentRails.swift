import SwiftUI

// Платёжные рельсы и матрица их доступности по операциям.
//
// Источник — таблица «Способы оплаты». Важно: колонки таблицы это НЕ механики
// перевода, а платёжные инструменты: откуда берутся деньги и по какому рельсу идут.
// Операция (что делает пользователь) — строки, инструмент — колонки.

/// Инструмент оплаты. Отличаются юридической природой денег, а не «способом нажатия».
enum PaymentRail: String, CaseIterable, Identifiable {
    /// «Оплата / перевод» из таблицы — собственные рельсы ВБ Банка: списание со
    /// счёта или карты. Оплата идёт продавцу (эквайринг), перевод — на чужой счёт;
    /// рельс один и тот же, поэтому в таблице это одна колонка.
    case direct
    /// Рельс НСПК поверх банковских счетов.
    case sbp
    /// Баланс кошелька Wildberries. Это не банковский счёт, а ЭДС по 161-ФЗ.
    case wallet
    /// Счёт цифрового рубля, оператор — Банк России.
    case digitalRuble

    var id: String { rawValue }

    /// Полное название — для подписей и разборов.
    var title: String {
        switch self {
        case .direct: "Оплата / перевод"
        case .sbp: "Через СБП"
        case .wallet: "ВБ кошелёк"
        case .digitalRuble: "Цифровой рубль"
        }
    }

    /// Короткое — для карточек способа оплаты в шите (макет 906:206676).
    var shortTitle: String {
        switch self {
        case .direct: "WB банк"
        case .sbp: "СБП"
        case .wallet: "Кошелёк"
        case .digitalRuble: "ЦР"
        }
    }

    /// Логотип 24 pt: в карточке способа оплаты и в строке списания это одна и та
    /// же марка. СБП и ВБ Банк — экспорты из макета, кошелёк и цифровой рубль пока
    /// заглушки на SF Symbols.
    var icon: RowIcon {
        switch self {
        case .direct:
            // Плитка целиком розовая (#FF22CC, радиус 6), внутри белый логотип.
            .logo(
                "icWBBank",
                size: CGSize(width: 17.1985 / 24, height: 11.7436 / 24),
                background: Color(hex: 0xFF22CC),
                radius: WBRadius.x1_5 / 24,
                offset: .zero
            )
        case .sbp: .asset("icSBP")
        case .wallet: .symbol(name: "bag.fill", tint: .white, background: WBColor.violet)
        case .digitalRuble: .symbol(name: "rublesign", tint: .white, background: Color(hex: 0xF5251B))
        }
    }

    /// Марка в строке списания на транзакционном экране. Ставим её, только когда
    /// деньги уходят по чужому рельсу — через НСПК или платформу Банка России.
    /// Собственные рельсы WB марки не получают: в приложении банка логотип этого
    /// же банка ничего не сообщает, а место в строке занимает.
    var mark: RowIcon? {
        switch self {
        case .sbp, .digitalRuble: icon
        case .direct, .wallet: nil
        }
    }
}

/// Операции из строк таблицы «Способы оплаты».
enum PaymentOperation: String {
    case betweenAccounts      // Между счетами
    case byPhone              // Перевод по номеру телефона
    case topUp                // Пополнение счёта
    case serviceBill          // Платёж за услугу (сотовая, интернет, ЖКХ)
    case qr                   // Оплата / покупка по QR
    case budgetWithUIN        // Перевод / платёж в бюджет по УИН
    case budgetWithoutUIN     // Перевод / платёж в бюджет без УИН
    case byCardNumber         // Перевод по номеру карты
    case crossBorder          // Трансграничный перевод
}

extension PaymentOperation {
    /// Доп. функции, уместные в этой операции.
    ///
    /// Ягодки и WB Кэш — деньги программы лояльности, а не остаток на счёте.
    /// Ими платят за товар или услугу, поэтому они появляются только там, где на
    /// той стороне продавец: оплата услуги и оплата по QR. Перекладывание своих
    /// денег (между счетами), приход денег извне (пополнение) и переводы людям
    /// бонусами не оплачиваются — иначе это обналичивание бонусов.
    var extras: [ExtraFunction] {
        switch self {
        case .serviceBill, .qr: [.berries, .wbCash]
        case .betweenAccounts, .byPhone, .topUp, .budgetWithUIN,
             .budgetWithoutUIN, .byCardNumber, .crossBorder: []
        }
    }
}

enum RailMatrix {
    /// ВБ Банк — банк с универсальной лицензией (рег. № 841), в системно значимые
    /// не входит. По закону о поэтапном подключении к платформе цифрового рубля
    /// универсальные банки обязаны поддерживать ЦР с 1 сентября 2027 года.
    /// Отсюда «to be с 09.2027» в таблице — это регуляторный срок, а не оценка.
    static let digitalRubleLaunch = "09.2027"

    /// Матрица из таблицы. `cr` — не доступность, а пометка «здесь цифровой рубль
    /// появится к сентябрю 2027». Сегодня его нет ни в одной операции, поэтому в
    /// выборе способа он не показывается вообще: обещание вместо инструмента —
    /// это шум, из-за которого выбор из одного способа выглядит выбором из двух.
    /// Колонку держим, чтобы к сроку хватило поменять одну строку.
    private static let table: [PaymentOperation: Row] = [
        .betweenAccounts:  Row(direct: true,  sbp: false, wallet: false, cr: true),
        .byPhone:          Row(direct: true,  sbp: true,  wallet: false, cr: true),
        .topUp:            Row(direct: true,  sbp: false, wallet: false, cr: true),
        .serviceBill:      Row(direct: true,  sbp: false, wallet: false, cr: false),
        .qr:               Row(direct: true,  sbp: true,  wallet: true,  cr: true),
        .budgetWithUIN:    Row(direct: false, sbp: true,  wallet: false, cr: true),
        .budgetWithoutUIN: Row(direct: true,  sbp: false, wallet: false, cr: false),
        .byCardNumber:     Row(direct: true,  sbp: false, wallet: false, cr: false),
        .crossBorder:      Row(direct: true,  sbp: true,  wallet: false, cr: false),
    ]

    // ОТКРЫТЫЙ ВОПРОС по таблице: в строке QR стоят проценты — оплата/перевод 5 %,
    // СБП 100 %, ВБ кошелёк 70 %. Что это за величина, из таблицы не следует:
    // доля точек, которые можно оплатить этим рельсом; доля транзакций; конверсия.
    // От ответа зависит, какой рельс должен быть выбран по умолчанию, поэтому в
    // модель проценты не заводятся, пока автор таблицы не подтвердит смысл.

    private struct Row {
        let direct: Bool
        let sbp: Bool
        let wallet: Bool
        let cr: Bool
    }

    static func isAvailable(_ rail: PaymentRail, for operation: PaymentOperation) -> Bool {
        guard let row = table[operation] else { return false }
        switch rail {
        case .direct: return row.direct
        case .sbp: return row.sbp
        case .wallet: return row.wallet
        // Цифровой рубль не запущен ни в одной операции — см. комментарий к таблице.
        case .digitalRuble: return false
        }
    }

    /// Способы, которыми эту операцию можно оплатить прямо сейчас. Ни «пока нет»,
    /// ни «здесь так не платят» в список не попадают — человеку показываем только
    /// то, что он может выбрать.
    static func rails(for operation: PaymentOperation) -> [PaymentRail] {
        PaymentRail.allCases.filter { isAvailable($0, for: operation) }
    }

    static func defaultRail(for operation: PaymentOperation) -> PaymentRail {
        rails(for: operation).first ?? .direct
    }
}
