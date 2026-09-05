import SwiftUI

// Разводящая категории — экран между общей витриной «Платежи и переводы» и самой
// формой. Появляется только там, где внутри категории много разных получателей и
// сценариев: ЖКХ, платежи по реквизитам. Для перевода по номеру телефона такой
// экран не нужен — там сразу форма.
//
// Что на ней есть: где ты, быстрые действия, незавершённый платёж, последние
// платежи, шаблоны, популярные компании региона.
//
// Главный открытый вопрос — что писать в строке последнего платежа. Реквизиты
// (ИНН, р/с) для опознания бесполезны: своего ИНН никто не помнит, а 20 цифр
// счёта в списке не читаются. Поэтому здесь собраны варианты второй строки, и
// каждый — отдельный пункт песочницы: их сравнивают вживую, а не по описанию.

// MARK: - Как выглядит строка последнего платежа

enum RecentStyle: String {
    /// Провайдер сверху, адрес и период снизу, сумма серым.
    case address
    /// То же, но вместо адреса маскированный лицевой счёт.
    case account
    /// Адрес сверху, провайдер снизу: человек ищет квартиру, а не поставщика.
    case placeFirst
    /// Сумма акцентом и кнопка повтора прямо в строке.
    case amountAccent
    /// Для реквизитов: назначение платежа вместо адреса.
    case purpose

    var title: String {
        switch self {
        case .address: "адрес"
        case .account: "лицевой счёт"
        case .placeFirst: "адрес первой строкой"
        case .amountAccent: "сумма акцентом"
        case .purpose: "назначение платежа"
        }
    }

    var rationale: String {
        switch self {
        case .address:
            "Человек думает о платеже как о квартире. Адрес различает свою и дачу быстрее, чем цифры счёта"
        case .account:
            "Реквизит вместо адреса: работает всегда, но узнаётся медленнее — цифры приходится читать"
        case .placeFirst:
            "Иерархия перевёрнута: сначала объект, потом поставщик. Хорошо, когда поставщик у всех один"
        case .amountAccent:
            "Сумма прошлого периода крупно. Быстрее для повтора, но обещает цифру, которая изменится"
        case .purpose:
            "У реквизитов получатель бывает безымянным ООО. Назначение — единственное, что различает такие платежи"
        }
    }
}

// MARK: - Содержимое разводящей

/// Быстрое действие: два самых частых входа в категорию.
struct HubAction: Identifiable {
    var id: String
    var symbol: String
    var title: String
    var subtitle: String
}

/// Незавершённый платёж. Один и не старше суток: иначе блок превращается в
/// кладбище черновиков, которое перестают замечать.
struct HubDraft {
    var provider: String
    var place: String
    var startedAgo: String
}

struct HubRecent: Identifiable {
    var id: String
    var icon: RowIcon
    /// Кому платили — «Мосэнергосбыт».
    var provider: String
    /// Объект платежа — адрес. nil, если поставщик его не отдаёт.
    var place: String?
    /// Маскированный реквизит — «л/с ··4567».
    var identifier: String
    /// Назначение платежа — для переводов по реквизитам.
    var purpose: String?
    /// За какой период платили — «за июль».
    var period: String
    var amount: Decimal
}

/// Шаблон. В карте (3.7–3.8) это именно шаблоны и автоплатежи — слова
/// «избранное» там нет, и вводить второе название для той же сущности не стоит.
struct HubTemplate: Identifiable {
    var id: String
    var icon: RowIcon
    var title: String
    var subtitle: String
    /// Включён автоплатёж — тогда шаблон работает сам.
    var isAutopay: Bool = false
}

/// Популярная компания. Популярная в регионе, а не вообще: федеральный список в
/// Уфе бесполезен (карта, 1.1 — «популярные в регионе»).
struct HubCompany: Identifiable {
    var id: String
    var icon: RowIcon
    var title: String
}

struct HubSpec: Identifiable {
    var id: String
    var demoName: String
    /// Заголовок отвечает на «где я»: название категории, а не «Платежи».
    var title: String
    var subtitle: String
    var recentStyle: RecentStyle
    var actions: [HubAction]
    var draft: HubDraft?
    var recents: [HubRecent]
    var templates: [HubTemplate]
    var companies: [HubCompany]
    /// Регион, из которого взяты популярные компании.
    var region: String
}

// MARK: - Каталог разводящих

enum PaymentHubs {
    static let all: [HubSpec] =
        [.address, .account, .placeFirst, .amountAccent].map(utilities) + [requisites]

    private static func icon(_ symbol: String, _ color: UInt32) -> RowIcon {
        .symbol(name: symbol, tint: .white, background: Color(hex: color))
    }

    private static let utility: UInt32 = 0x0F9D58
    private static let budget: UInt32 = 0x2F6FED
    private static let telecom: UInt32 = 0x7B3FE4

    // MARK: ЖКХ

    /// Разводящая ЖКХ в четырёх вариантах: меняется только строка последнего
    /// платежа, всё остальное одинаково — иначе сравнивать нечего.
    static func utilities(_ style: RecentStyle) -> HubSpec {
        HubSpec(
            id: "hub-utilities-" + style.rawValue,
            demoName: "Разводящая ЖКХ · " + style.title,
            title: "ЖКХ и коммуналка",
            subtitle: "Квартплата, свет, вода, капремонт",
            recentStyle: style,
            actions: [
                HubAction(
                    id: "qr",
                    symbol: "qrcode.viewfinder",
                    title: "Сканировать QR",
                    subtitle: "С квитанции"
                ),
                HubAction(
                    id: "manual",
                    symbol: "keyboard",
                    title: "Ввести реквизиты",
                    subtitle: "Лицевой счёт или ЕЛС"
                ),
            ],
            draft: HubDraft(
                provider: "ЖКУ Республики Татарстан",
                place: "Казань, Баумана, 58, кв. 21",
                startedAgo: "начали 40 минут назад"
            ),
            recents: [
                HubRecent(
                    id: "mosenergo",
                    icon: icon("bolt.fill", utility),
                    provider: "Мосэнергосбыт",
                    place: "Ленинский пр-т, 42, кв. 118",
                    identifier: "л/с ··4567",
                    purpose: nil,
                    period: "за июль",
                    amount: Decimal(string: "3105.40")!
                ),
                HubRecent(
                    id: "eirc",
                    icon: icon("building.2.fill", utility),
                    provider: "ЕИРЦ Москвы",
                    place: "Тверская, 12, кв. 45",
                    identifier: "код ··4567",
                    purpose: nil,
                    period: "за июль",
                    amount: Decimal(string: "5162.30")!
                ),
                // Второй платёж тому же поставщику — на нём и видно, работает ли
                // выбранный различитель: две строки «Мосэнергосбыт» подряд.
                HubRecent(
                    id: "mosenergo-dacha",
                    icon: icon("bolt.fill", utility),
                    provider: "Мосэнергосбыт",
                    place: "Дмитровский р-н, СНТ Заря, 14",
                    identifier: "л/с ··9082",
                    purpose: nil,
                    period: "за июнь",
                    amount: Decimal(string: "612.80")!
                ),
            ],
            templates: [
                HubTemplate(
                    id: "eirc-monthly",
                    icon: icon("building.2.fill", utility),
                    title: "ЕИРЦ Москвы",
                    subtitle: "Тверская, 12, кв. 45",
                    isAutopay: true
                ),
                HubTemplate(
                    id: "mosenergo-monthly",
                    icon: icon("bolt.fill", utility),
                    title: "Мосэнергосбыт",
                    subtitle: "Ленинский пр-т, 42, кв. 118"
                ),
            ],
            companies: [
                HubCompany(id: "mosvodokanal", icon: icon("drop.fill", utility), title: "Мосводоканал"),
                HubCompany(id: "mosgaz", icon: icon("flame.fill", utility), title: "Мосгаз"),
                HubCompany(id: "kapremont", icon: icon("hammer.fill", utility), title: "Фонд капремонта"),
                HubCompany(id: "rostelecom", icon: icon("wifi", telecom), title: "Ростелеком"),
            ],
            region: "Москве"
        )
    }

    // MARK: Переводы по реквизитам

    /// У реквизитов различитель другой: получатель может быть безымянным ООО, и
    /// две строки «ООО „Ромашка“» отличает только назначение платежа.
    static let requisites = HubSpec(
        id: "hub-requisites",
        demoName: "Разводящая по реквизитам · назначение",
        title: "Платежи по реквизитам",
        subtitle: "Организации, ИП, бюджет",
        recentStyle: .purpose,
        actions: [
            HubAction(
                id: "qr",
                symbol: "qrcode.viewfinder",
                title: "Сканировать QR",
                subtitle: "Со счёта или квитанции"
            ),
            HubAction(
                id: "manual",
                symbol: "keyboard",
                title: "Ввести реквизиты",
                subtitle: "ИНН, БИК, счёт"
            ),
        ],
        draft: nil,
        recents: [
            HubRecent(
                id: "romashka-rent",
                icon: icon("doc.text.fill", budget),
                provider: "ООО «Ромашка»",
                place: nil,
                identifier: "счёт ··2345",
                purpose: "Аренда за август",
                period: "12 августа",
                amount: Decimal(string: "45000")!
            ),
            HubRecent(
                id: "romashka-services",
                icon: icon("doc.text.fill", budget),
                provider: "ООО «Ромашка»",
                place: nil,
                identifier: "счёт ··2345",
                purpose: "По счёту 1345",
                period: "2 августа",
                amount: Decimal(string: "12800")!
            ),
            HubRecent(
                id: "fns",
                icon: icon("building.columns.fill", budget),
                provider: "ФНС России",
                place: nil,
                identifier: "УИН ··4371",
                purpose: "Налог на имущество",
                period: "28 июля",
                amount: Decimal(string: "3410")!
            ),
        ],
        templates: [
            HubTemplate(
                id: "romashka",
                icon: icon("doc.text.fill", budget),
                title: "ООО «Ромашка»",
                subtitle: "Аренда, счёт ··2345"
            ),
        ],
        companies: [
            HubCompany(id: "fns", icon: icon("building.columns.fill", budget), title: "ФНС России"),
            HubCompany(id: "fssp", icon: icon("scalemass.fill", budget), title: "ФССП"),
            HubCompany(id: "gibdd", icon: icon("car.fill", budget), title: "ГИБДД"),
        ],
        region: "Москве"
    )
}
