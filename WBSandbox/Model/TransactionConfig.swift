import SwiftUI

// Описание транзакционного экрана данными. Экран один и тот же для всех режимов —
// меняется только этот конфиг. Каждая зона опциональна: nil / пустой массив
// означает «зону не рисуем», и стек просто схлопывается.

// MARK: - Иконки

enum RowIcon {
    /// Готовая 40×40 иконка, выгруженная из макета (бренд-логотипы).
    ///
    /// Выгружать только вектором и только сам слой иконки. Экспорт узла целиком
    /// тянет за собой окружение фрейма — белые прямоугольники карточки и ячейки
    /// списка, — и тогда у иконки появляется белая подложка, которой в макете
    /// нет. Растр той же ошибки уже не даёт починить: альфы в нём просто нет.
    case asset(String)
    /// Тот же экспортированный ассет, но с известным цветом фоновой плитки. Нужен
    /// брендовому градиенту: он берёт базовый цвет из аватарки поставщика.
    case brandedAsset(String, tint: Color)
    /// Вектор-логотип из макета поверх цветной подложки. Размеры заданы долями
    /// плитки, поэтому одна и та же иконка одинаково собирается и в 40 pt строке
    /// списания, и в 24 pt карточке способа оплаты. `offset` — тоже доля плитки:
    /// логотип не всегда стоит по центру (у щита Т-Банка низ острый, и в макете
    /// он поднят на 2,5 % высоты).
    case logo(String, size: CGSize, background: Color, radius: CGFloat, offset: CGSize)
    /// Плейсхолдер на SF Symbol там, где настоящего экспорта пока нет.
    case symbol(name: String, tint: Color, background: Color)

    /// Логотип 24 pt внутри плитки 40 pt — типовая иконка строки в шите и на
    /// транзакционном экране. Доли считаются от плитки: 24/40 = 0,6, радиус 12/40.
    static func tile(_ asset: String, _ logo: CGSize, background: Color) -> RowIcon {
        .logo(
            asset,
            size: CGSize(width: logo.width / 40, height: logo.height / 40),
            background: background,
            radius: 12.0 / 40,
            offset: .zero
        )
    }

    /// Основной цвет иконки: им подкрашиваются капли и партиклы на анимации
    /// исхода — так эффект попадает в бренд получателя, а не живёт своей жизнью.
    var tint: Color {
        switch self {
        case .logo(_, _, let background, _, _): background
        case .symbol(_, _, let background): background
        case .brandedAsset(_, let tint): tint
        case .asset: WBColor.brandBlue
        }
    }

    /// Плитка получателя 64 pt на экране исхода (макет 925:207402): скругление
    /// 18,286, внутри вектор своего размера. `logo` и `offset` задаются в точках
    /// от плитки 64 — так их проще сверять с макетом.
    static func squircle(
        _ asset: String,
        logo: CGSize,
        background: Color,
        offset: CGSize = .zero
    ) -> RowIcon {
        .logo(
            asset,
            size: CGSize(width: logo.width / 64, height: logo.height / 64),
            background: background,
            radius: 18.286 / 64,
            offset: CGSize(width: offset.width / 64, height: offset.height / 64)
        )
    }
}

// MARK: - Текст в строках

enum TextEmphasis {
    case primary    // 15/20, --mo-text-icon-primary
    case secondary  // 13/17, --mo-text-icon-secondary
}

struct RowText {
    var value: String
    var emphasis: TextEmphasis

    static func primary(_ value: String) -> RowText { .init(value: value, emphasis: .primary) }
    static func secondary(_ value: String) -> RowText { .init(value: value, emphasis: .secondary) }
}

// MARK: - Бейджи

enum BadgeStyle {
    case greenSoft    // «БЕЗ КОМИССИИ», «КОМИССИЯ 3,74 ₽» под суммой
    case greenStrong  // «WB Кэш» в строке счёта
    case berry        // «−100» со списанием ягодок
    case wbCash       // «−3 000» со списанием WB Кэша
    case neutral
    case violet
    /// «вб» — розовый бейдж WB-баллов на плитке с бонусами (макет 927:207945).
    case wbCoin
}

struct BadgeSpec {
    var text: String
    var style: BadgeStyle
    var isUppercase: Bool = false
    /// Иконка 12×12 справа от текста.
    var iconAsset: String?
}

// MARK: - Дополнительные функции

/// Доп. функции операции. Показываем одну: если денег хватает — списание ягодок,
/// если не хватает — WB Кэш.
enum ExtraFunction: String, Identifiable, CaseIterable {
    case berries
    case wbCash

    var id: String { rawValue }

    /// Крупная строка — сколько списываем (макет 906:206723).
    var title: String {
        switch self {
        case .berries: "100 ягодок"
        case .wbCash: "3 000\(Money.nbsp)₽ WB Кэша"
        }
    }

    var subtitle: String {
        switch self {
        case .berries: "Потратить ягодки"
        case .wbCash: "Потратить WB Кэш"
        }
    }

    /// Иконка строки: логотип 24 pt на подложке своего цвета.
    var icon: RowIcon {
        switch self {
        case .berries:
            .tile("icCashback", CGSize(width: 22, height: 22), background: WBColor.badgeBerryBg)
        case .wbCash:
            .tile("icWBCash", CGSize(width: 22, height: 22), background: WBColor.badgeCashBg)
        }
    }

    /// Бейдж, который встаёт слева от бейджа комиссии, когда функция включена.
    var badge: BadgeSpec {
        switch self {
        case .berries:
            BadgeSpec(text: "−100", style: .berry, iconAsset: "icBerry")
        case .wbCash:
            BadgeSpec(text: "−3 000", style: .wbCash, iconAsset: "icWBCash")
        }
    }
}

// MARK: - Комиссия

enum FeeRule {
    case free
    /// Фиксированная комиссия, не зависящая от суммы перевода.
    case fixed(Decimal)
    /// Доля от суммы. Для ЖКУ ставка подобрана так, чтобы на 4 000 ₽ получить
    /// ровно 3,74 ₽ из макета, и при этом комиссия честно пересчитывалась на вводе.
    case rate(Decimal)

    func fee(for amount: Decimal) -> Decimal {
        switch self {
        case .free: return 0
        case .fixed(let value): return value
        case .rate(let rate): return (amount * rate).rounded(scale: 2)
        }
    }

    func badge(for amount: Decimal) -> BadgeSpec {
        switch self {
        case .free:
            return BadgeSpec(text: "Без комиссии", style: .greenSoft, isUppercase: true)
        case .fixed(let value):
            return BadgeSpec(
                text: "Комиссия \(Money.plain(value))\(Money.nbsp)₽",
                style: .greenSoft,
                isUppercase: true
            )
        case .rate:
            let value = fee(for: amount)
            return BadgeSpec(
                text: "Комиссия \(Money.kopecks(value))\(Money.nbsp)₽",
                style: .greenSoft,
                isUppercase: true
            )
        }
    }
}

// MARK: - Строки «откуда» и «куда»

struct DetailRow: Identifiable {
    var id: String
    var icon: RowIcon
    var top: RowText
    var bottom: RowText?
    var trailingBadge: BadgeSpec?
    /// Логотипы платёжных рельсов перед шевроном. Показываем доступные сейчас
    /// инструменты кроме собственных рельсов банка: только банк → ничего,
    /// банк + СБП → один логотип, банк + СБП + кошелёк → два, и так далее.
    var trailingIcons: [RowIcon] = []
    var showsChevron: Bool = true
}

/// Строка с переключателем — автоматизация над клавиатурой.
///
/// Иконка и подпись обязательны намеренно: строка всегда двухэтажная и одного
/// размера, иначе один сценарий выглядит крупнее другого без всякой причины.
/// Подпись отвечает на «что именно произойдёт», а не хвалит функцию.
struct ToggleRow: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var isOn: Bool = false
    /// SF Symbol слева от текста (в макете зелёная молния).
    var symbol: String
    var symbolColor: Color = WBColor.textAccent
}

// MARK: - Счёт списания и способ оплаты (боттом-шит)

struct Account: Identifiable {
    var id: String
    var icon: RowIcon
    var amountTitle: String   // «11 235 ₽» — крупная строка
    var subtitle: String      // «WB Банк ··1321»
    var balance: Decimal
    var badge: BadgeSpec?
    /// Недоступные счета в шите не показываем совсем.
    var isAvailable: Bool = true
}

// Способы оплаты больше не перечисляются в конфиге вручную — они выводятся из
// матрицы `RailMatrix` по полю `operation`. См. Model/PaymentRails.swift.

// MARK: - Нижний слот

struct PromoBanner {
    var title: String
    var subtitle: String?
    var background: Color
    var foreground: Color
    /// Крупная подпись слева — «−50 %», «0 %». Только в полосе над клавиатурой.
    var accent: String?
}

/// Допродажа: второй счёт, который человек всё равно оплатит на этих же днях.
/// Не реклама партнёра, а его собственный платёжный календарь — поэтому у неё
/// есть сумма и переключатель, а не кнопка «узнать больше».
struct UpsellOffer: Identifiable {
    var id: String
    var icon: RowIcon
    var title: String
    /// Чем предложение обосновано: «обычно вы платите в эти же дни».
    var reason: String
    var amount: Decimal
}

/// Что занимает низ экрана. Если сумму менять нельзя, клавиатура не нужна и
/// освободившееся место достаётся допродаже.
enum BottomSlot {
    case keypad
    case upsell(UpsellOffer)
    case empty
}

/// Полоса над клавиатурой — единственное место для всего, что не относится к
/// самому переводу. Три наполнения, больше пока не нужно:
///
/// 1. `amounts` — быстрые суммы, когда сумму набирают руками;
/// 2. `automation` — превратить разовое действие в регулярное: автоплатёж,
///    пополнение по расписанию, шаблон;
/// 3. `promo` — маркетинг: скидка, акция, партнёрское предложение.
///
/// Под кнопкой маркетингу места нет — там живёт только `deliveryNote`.
enum SuggestSlot {
    case amounts([Decimal])
    case automation(ToggleRow)
    case promo(PromoBanner)
    case none
}

// MARK: - Сообщение к переводу

/// Стикер под сообщением. В шаблоне их два, с разным наклоном и подложкой.
struct MessageSticker: Identifiable {
    var id: String
    var asset: String
    /// Наклон в градусах: в макете −4° у первого и +8° у второго.
    var rotation: Double
    /// Подложка под прозрачной картинкой (у шарика — --mo-bg-redLight).
    var background: Color?
    /// Белая обводка 2 pt вокруг плитки.
    var hasWhiteBorder: Bool = false
}

enum MessageKind {
    /// Редактируемый комментарий к переводу: пустой показывает плейсхолдер,
    /// рядом живёт кнопка подарка.
    case comment
    /// Статичная подпись назначения платежа — «Погашение задолженности».
    case label
}

/// Блок под суммой: тултип с текстом, кнопка подарка и выбранные подарки.
struct MessageBubble {
    var kind: MessageKind = .label
    /// Для `.label` — сам текст. Для `.comment` — пример заполненного комментария,
    /// который подставляется по тапу (на старте комментарий пустой).
    var text: String
    var placeholder: String = "Комментарий"
    /// Хвостик-указатель на сумму. Всегда по центру экрана, даже если чип смещён
    /// кнопкой подарка.
    var hasTooltipArrow: Bool = true
    /// Подарки, которые можно прикрепить. Появляются справа налево: первый тап
    /// показывает последний в этом списке.
    var gifts: [MessageSticker] = []
}

// MARK: - Экран успеха

/// Иллюстрация внутри плитки. Координаты и размер — от левого верхнего угла
/// карточки, как в макете: картинка свисает за её край и обрезается скруглением.
struct TileArt {
    var asset: String
    var size: CGFloat
    var x: CGFloat
    var y: CGFloat
}

/// Нижняя строка плитки: крупное число и то, что стоит рядом с ним. В макете она
/// лежит абсолютно, а не по потоку, поэтому координаты заданы явно.
struct TileAccent {
    /// «500», «12 × 500 ₽» — 27,913/23 Bold.
    var text: String
    var origin: CGPoint
    /// Значок слева от строки — клевер 31,2 у рассрочки.
    var art: TileArt?
    /// Бейдж справа от строки — «вб» у бонусов.
    var badge: BadgeSpec?
    var badgeOrigin: CGPoint = .zero
}

struct PromoTile: Identifiable {
    var id: String
    var text: String
    /// Квадратная карточка 120×120 против широкой, которая забирает остаток строки.
    var isWide: Bool = false
    var art: TileArt?
    var accent: TileAccent?
    var background: Color = .white
    var foreground: Color = WBColor.textPrimary
}

/// Что показываем на экране исхода. Плиток здесь нет намеренно: что предложить
/// дальше, зависит от исхода, а не от режима перевода — «выбрать другой счёт»
/// имеет смысл только при отказе. Они живут в `TransactionOutcome.tiles`.
struct SuccessConfig {
    var title: String
    var subtitle: String
    var icon: RowIcon
    var counterparty: String
    var chip: String?
}

// MARK: - Живой фон

/// Световой слой под контентом карточек. Экран не описывает, как он выглядит и
/// когда меняется — только то, какой эффект здесь уместен; настроение он берёт
/// из состояния ввода сам.
enum AmbientEffect {
    /// Дышащие холмы у нижней кромки блока: холодный серый в покое, оранжевый
    /// при нехватке денег. Геометрия — из пресета «spike-lime» в MetalForge.
    case mounds
}

// MARK: - Конфиг экрана

struct TransactionConfig: Identifiable {
    var id: String
    /// Подпись в демо-переключателе режимов.
    var demoName: String

    /// Строка из таблицы «Способы оплаты». Определяет, какие платёжные рельсы
    /// доступны в этом сценарии — набор способов в шите считается отсюда.
    var operation: PaymentOperation

    /// Рельс, выбранный изначально. nil — первый доступный по матрице.
    var defaultRail: PaymentRail?

    // Шапка
    var title: String
    var navTrailing: RowIcon?

    // Сумма
    var initialAmount: Decimal
    var fee: FeeRule
    var message: MessageBubble?

    // Точка А / точка Б
    var accounts: [Account]
    var destination: DetailRow?
    /// Если получатель — тоже свой счёт, указываем его id: тогда строка «куда»
    /// строится из счёта и появляется кнопка свапа.
    var destinationAccountID: String?
    var toggles: [ToggleRow]

    // Низ экрана
    var suggestSlot: SuggestSlot
    var bottomSlot: BottomSlot
    var ctaTitle: String
    /// Единственная подпись под кнопкой — срок зачисления. Ни комиссий, ни акций,
    /// ни курсов: всё остальное человек читает выше, до того как решится нажать.
    var deliveryNote: String?

    var success: SuccessConfig

    /// Живой фон карточек. nil — экран как в макете, без свечения.
    var ambient: AmbientEffect?

    /// Свап доступен, когда обе точки — свои счета.
    var allowsAccountSwap: Bool { destinationAccountID != nil }
}
