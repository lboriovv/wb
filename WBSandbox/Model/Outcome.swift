import SwiftUI

/// Кнопка в нижней панели экрана исхода.
struct OutcomeAction: Identifiable {
    var id: String { title }
    let icon: DSIcon
    let title: String
    /// Закрывает экран. У «Справки» своё поведение, поэтому она не закрывает.
    let closes: Bool
}

/// Исход операции. Экран один и тот же, меняется статус, заголовок и подпись —
/// как и на транзакционном экране, разница живёт в данных.
///
/// Палитра, набор кнопок и отбивки сняты с трёх макетов: 925:207394 (успех),
/// 927:207898 (в обработке), 927:207846 (отказ).
enum TransactionOutcome: String, CaseIterable, Identifiable {
    case success
    case processing
    case declined

    var id: String { rawValue }

    var title: String {
        switch self {
        case .success: "Перевод выполнен"
        case .processing: "Перевод в обработке"
        case .declined: "Перевод отклонён"
        }
    }

    var symbol: String {
        switch self {
        case .success: "checkmark"
        case .processing: "clock"
        case .declined: "xmark"
        }
    }

    /// Вектор из макета вместо SF Symbol в кружке статуса. У «в обработке» знак —
    /// только стрелки часов: циферблат рисует сама белая обводка кружка, и
    /// системная `clock` дала бы второе кольцо внутри первого.
    var badgeVector: DSIcon? {
        self == .processing ? .timeBold : nil
    }

    /// Заливка кружка статуса у иконки получателя.
    var accent: Color {
        switch self {
        case .success: WBColor.bgSuccess
        case .processing: WBColor.bgBlue
        case .declined: WBColor.bgDanger
        }
    }

    // MARK: Палитра экрана

    /// Фон под белой карточкой, он же подложка панели кнопок.
    var deepBackground: Color {
        switch self {
        case .success: WBColor.deepGreen
        case .processing: WBColor.deepBlue
        case .declined: WBColor.deepBrown
        }
    }

    /// Слои свечения снизу вверх. В обработке и отказе под основным лежит
    /// «призрак» соседнего исхода на 10 % — так в макете.
    var glow: [WBGlow] {
        switch self {
        case .success: [.green]
        case .processing: [WBGlow.orange.faded(0.1), .blue]
        case .declined: [.orange, WBGlow.green.faded(0.1)]
        }
    }

    /// Те же три оттенка, что у `glow`, но для шейдера `outcomeEmber`: край,
    /// середина, ядро.
    var ember: EmberPalette {
        switch self {
        case .success: .green
        case .processing: .blue
        case .declined: .orange
        }
    }

    /// Отбивка от навбара до иконки получателя. В макете успеха 122, в двух
    /// других — 152.
    var contentTop: CGFloat {
        self == .success ? 122 : 152
    }

    /// Комиссия и комментарий под суммой. У отказа под суммой пусто: списания
    /// не было, объяснять комиссию нечем.
    var showsAmountDetails: Bool { self != .declined }

    var showsTiles: Bool { true }

    /// Что предлагаем дальше. Набор зависит от исхода: после успешного перевода
    /// человеку интересна доставка, после отказа — как всё-таки заплатить.
    /// Координаты иллюстраций и крупных строк взяты из макетов.
    var tiles: [PromoTile] {
        switch self {
        case .success: [.delivery, .insurance]
        case .processing: [.bonuses, .instalments]
        case .declined: [.instalments, .anotherAccount]
        }
    }

    // MARK: Нижняя панель

    /// У успеха панель белая и непрозрачная, у двух других — приглушённая.
    var actionFill: Color {
        self == .success ? WBColor.bgBase : WBColor.bgLevel2
    }

    var actionLabel: Color {
        self == .success ? .white : WBColor.textQuaternary
    }

    var actionBarOpacity: Double {
        self == .success ? 1 : 0.9
    }

    var actions: [OutcomeAction] {
        switch self {
        case .success:
            [
                OutcomeAction(icon: .fileText, title: "Справка", closes: false),
                OutcomeAction(icon: .reloader, title: "Повторить", closes: true),
                OutcomeAction(icon: .checkmark, title: "Готово", closes: true),
            ]
        case .processing:
            [
                OutcomeAction(icon: .fileText, title: "Справка", closes: false),
                OutcomeAction(icon: .reloader, title: "Повторить", closes: true),
                OutcomeAction(icon: .close, title: "Закрыть", closes: true),
            ]
        case .declined:
            [
                OutcomeAction(icon: .reloader, title: "Повторить", closes: true),
                OutcomeAction(icon: .checkmark, title: "Готово", closes: true),
            ]
        }
    }
}

// MARK: - Плитки исходов

/// Координаты иллюстраций и крупных строк взяты из макетов как есть: в Figma
/// они лежат абсолютно, а не по потоку, и свисают за кромку карточки.
extension PromoTile {
    /// Успех, 925:207428 и 925:207433.
    static let delivery = PromoTile(
        id: "delivery",
        text: "Отследить доставку",
        art: TileArt(asset: "artEscalator", size: 87.471, x: -2.629, y: 45.129)
    )

    static let insurance = PromoTile(
        id: "insurance",
        text: "Страхование карты и счёта\nот мошенников",
        isWide: true,
        art: TileArt(asset: "artSpider", size: 78, x: 6.203, y: 45.271)
    )

    /// Обработка, 927:207938 и 927:207946.
    static let bonuses = PromoTile(
        id: "bonuses",
        text: "Забрать бонусы",
        accent: TileAccent(
            text: "500",
            origin: CGPoint(x: 12, y: 85),
            badge: BadgeSpec(text: "вб", style: .wbCoin),
            badgeOrigin: CGPoint(x: 69, y: 86.03)
        )
    )

    static let instalments = PromoTile(
        id: "instalments",
        text: "Разделить платёж на части без переплаты",
        isWide: true,
        accent: TileAccent(
            text: "12 × 500\(Money.nbsp)₽",
            origin: CGPoint(x: 39.712, y: 83.486),
            art: TileArt(asset: "artClover", size: 31.2, x: 8.514, y: 79.343)
        )
    )

    /// Отказ, 927:207893.
    static let anotherAccount = PromoTile(
        id: "another-account",
        text: "Выбрать другой счёт",
        art: TileArt(asset: "artWallet3D", size: 59.057, x: 3.957, y: 56.5)
    )
}

/// Чем светит блок под карточкой на такте наливания.
enum OutcomeGlowStyle {
    /// Радиальный градиент из макета: эллипсы BG1/BG2 и диммер.
    case gradient
    /// Живое свечение: три бегущие волны света на Metal, палитра — из тех же
    /// стопов градиента. См. `EmberGlowField`.
    case ember
}

/// Сценарий раздела «Экран успеха»: лоадер, затем конкретный исход.
struct OutcomeScenario: Identifiable {
    var id: String
    var demoName: String
    var outcome: TransactionOutcome
    /// Чем светит блок под карточкой. По умолчанию — как в макете.
    var glowStyle: OutcomeGlowStyle = .gradient
    /// Откуда берём получателя и плитки — из конфига режима перевода.
    var source: TransactionConfig
    var loaderDuration: Double = 1.8
    /// Сумма кадра. В живом флоу её приносит модель, в песочнице — сценарий.
    var amount: Decimal?
    /// Бейдж комиссии под суммой. Там же: живой флоу считает его от введённой
    /// суммы, демо-кадр берёт из макета.
    var badge: BadgeSpec?
    /// Полное содержимое кадра, если демо отличается от сценария перевода.
    var override: SuccessConfig?
    /// Текст навбара во время отправки. По умолчанию сохраняет прежний сценарий.
    var loaderTitle: String = "Отправляем перевод"
    /// Необязательная замена итогового заголовка для оплат и других не-переводов.
    var resultTitle: String?

    var success: SuccessConfig { override ?? source.success }
}
