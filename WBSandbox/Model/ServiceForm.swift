import SwiftUI

// Сложный платёжный экран, описанный данными. Экран не знает ни одного
// провайдера: он умеет рисовать поля, разворачивать зависимости, спрашивать
// начисление и считать итог. Что именно показать — приходит из `ServiceSpec`.
// Добавить тип оплаты = дописать спеку в ServiceCatalog, вёрстку не трогать.
//
// Термины — из карты «Категории платежей и атрибуты» (PAYMENTS.md): динамический
// и не динамический провайдер, набор параметров, блок необязательных параметров.
//
// Чем этот экран отличается от `TransactionScreen`: там сумма — главный и
// единственный ввод, поэтому под ней стоит своя клавиатура на пол-экрана. Здесь
// полей много, экран скроллится, и отдельная клавиатура забирала бы место у
// формы. Поэтому сумма — такое же поле формы, только крупным кеглем, а ввод —
// системной клавиатурой. Отдельного шага «подтвердите сумму» нет намеренно:
// человек уже видел её здесь, рядом с тем, за что платит.

// MARK: - Тип провайдера

enum ProviderKind {
    /// Динамический: весь набор атрибутов известен заранее, форма показывает его
    /// сразу и целиком.
    case upfront
    /// Не динамический: атрибуты приходят по мере ввода — следующий появляется,
    /// когда заполнен предыдущий, а правка раннего поля перезапускает проверку.
    case stepwise

    var title: String {
        switch self {
        case .upfront: "Динамический"
        case .stepwise: "Не динамический"
        }
    }

    var explanation: String {
        switch self {
        case .upfront: "Набор параметров пришёл целиком"
        case .stepwise: "Параметры приходят по мере ввода"
        }
    }
}

// MARK: - Формат значения

/// Формат — это одновременно клавиатура, фильтр символов, маска и валидация.
/// Один источник намеренно: иначе в спеке можно объявить «только цифры» и забыть
/// поставить цифровую клавиатуру.
enum FieldFormat {
    case digits(ClosedRange<Int>)
    /// УИН: 20 или 25 цифр, последняя — контрольный разряд.
    case uin
    /// Расчётный счёт — ровно 20 цифр.
    case account
    case bic
    case inn
    /// ОКТМО бывает только 8- или 11-значным. Двенадцатый знак сохраняем
    /// временно, чтобы показать ошибку «лишняя цифра», а не молча обрезать ввод.
    case oktmo
    case phone
    /// Госномер: латиница и цифры, приводим к верхнему регистру.
    case plate
    case text(ClosedRange<Int>)
    case email
    /// Показание счётчика: до 6 целых знаков.
    case meter
    /// Период оплаты месяцем: «08.2026». Шесть цифр, точка ставится сама.
    case month

    var keyboard: UIKeyboardType {
        switch self {
        case .digits, .uin, .account, .bic, .inn, .oktmo, .meter, .month: .numberPad
        case .phone: .phonePad
        case .email: .emailAddress
        case .plate, .text: .default
        }
    }

    /// Что написано в спеке напротив поля — им же подписан формат в смотрелке.
    var maskTitle: String {
        switch self {
        case .digits(let range):
            range.lowerBound == range.upperBound
                ? "\(range.lowerBound) цифр"
                : "\(range.lowerBound)–\(range.upperBound) цифр"
        case .uin: "20 или 25 цифр, контрольный разряд"
        case .account: "20 цифр"
        case .bic: "9 цифр"
        case .inn: "10 или 12 цифр"
        case .oktmo: "8 или 11 цифр"
        case .phone: "+7 ··· ··· ·· ··"
        case .plate: "А000АА777"
        case .text(let range): "текст до \(range.upperBound)"
        case .email: "адрес почты"
        case .meter: "до 6 цифр"
        case .month: "ММ.ГГГГ"
        }
    }

    var maxLength: Int {
        switch self {
        case .digits(let range): range.upperBound
        case .uin: 25
        case .account: 20
        case .bic: 9
        case .inn: 12
        case .oktmo: 12
        case .phone: 11
        case .plate: 9
        case .text(let range): range.upperBound
        case .email: 64
        case .meter: 6
        case .month: 6
        }
    }

    /// Отбрасываем символы, которых в этом формате не бывает: так поле нельзя
    /// испортить вставкой из буфера, и ошибку не приходится показывать вообще.
    func normalized(_ raw: String) -> String {
        var value: String
        switch self {
        case .digits, .uin, .account, .bic, .inn, .oktmo, .phone, .meter:
            value = raw.filter(\.isNumber)
        case .month:
            // Точку ставим сами: человек набирает «082026», видит «08.2026».
            let digits = String(raw.filter(\.isNumber).prefix(6))
            guard digits.count > 2 else { return digits }
            return digits.prefix(2) + "." + digits.dropFirst(2)
        case .plate:
            value = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        case .text, .email:
            value = raw
        }
        return String(value.prefix(maxLength))
    }

    /// Правдоподобное значение для съёмки кадров: заполнять форму из десяти полей
    /// руками — это разные кадры при каждом прогоне.
    var demoValue: String {
        switch self {
        case .digits(let range): Self.digits(range.lowerBound)
        case .uin: UIN.complete("1881045631080261437")
        case .account: "40702810400000012345"
        case .bic: "044525225"
        case .inn: "7736520080"
        case .oktmo: "45328000"
        case .phone: "79136541156"
        case .plate: "А123ВС777"
        case .text: "Оплата по счёту 1345"
        case .email: "leonid@brighty.app"
        case .meter: "1"
        case .month: "08.2026"
        }
    }

    private static func digits(_ count: Int) -> String {
        String((0..<count).map { Character(String(($0 + 1) % 10)) })
    }

    /// Введено достаточно, чтобы судить о правильности. Нужно, чтобы не ругаться
    /// на середину номера, но поймать неверный контрольный разряд на последней
    /// цифре, не дожидаясь, пока человек уйдёт из поля.
    func isComplete(_ value: String) -> Bool {
        switch self {
        case .digits(let range): value.count >= range.lowerBound
        case .uin: value.count == 20 || value.count == 25
        case .account: value.count == 20
        case .bic: value.count == 9
        case .inn: value.count == 10 || value.count == 12
        case .oktmo: value.count == 8 || value.count == 11
        case .phone: value.count == 11
        case .plate: value.count >= 6
        case .text(let range): value.count >= range.lowerBound
        case .email: value.contains("@")
        case .meter: !value.isEmpty
        case .month: value.filter(\.isNumber).count == 6
        }
    }

    /// Ошибка формата или nil. Пустое значение здесь не проверяется — за
    /// обязательность отвечает само поле.
    func error(_ value: String) -> String? {
        guard !value.isEmpty else { return nil }
        switch self {
        case .digits(let range):
            return value.count < range.lowerBound ? "Нужно \(range.lowerBound) цифр" : nil
        case .uin:
            guard value.count == 20 || value.count == 25 else {
                return "УИН — 20 или 25 цифр"
            }
            return UIN.isValid(value) ? nil : "Не сходится контрольный разряд"
        case .account:
            return value.count < 20 ? "Счёт — 20 цифр" : nil
        case .bic:
            return value.count < 9 ? "БИК — 9 цифр" : nil
        case .inn:
            return (value.count == 10 || value.count == 12) ? nil : "ИНН — 10 или 12 цифр"
        case .oktmo:
            if value.count < 8 { return "ОКТМО должен содержать 8 или 11 цифр" }
            if value.count == 9 || value.count == 10 {
                return "ОКТМО содержит лишние цифры: нужно 8 или 11"
            }
            if value.count > 11 { return "Удалите лишнюю цифру из ОКТМО" }
            return nil
        case .phone:
            return value.count < 11 ? "Номер целиком, с кодом страны" : nil
        case .plate:
            return value.count < 6 ? "Номер целиком, как на табличке" : nil
        case .text(let range):
            return value.count < range.lowerBound ? "Слишком коротко" : nil
        case .email:
            return value.contains("@") && value.contains(".") ? nil : "Проверьте адрес"
        case .meter:
            return nil
        case .month:
            let digits = value.filter(\.isNumber)
            guard digits.count == 6 else { return "Месяц и год: 08.2026" }
            let month = Int(digits.prefix(2)) ?? 0
            return (1...12).contains(month) ? nil : "Такого месяца нет"
        }
    }
}

// MARK: - Контрольный разряд УИН

/// Проверка последней цифры УИН по приказу Минфина: взвешенная сумма первых
/// разрядов по модулю 11. Нужна не ради строгости, а чтобы опечатку в двадцати
/// цифрах поймать на форме, а не через сутки платёжкой, ушедшей не туда.
enum UIN {
    static func isValid(_ value: String) -> Bool {
        let digits = value.compactMap { $0.wholeNumberValue }
        guard digits.count == 20 || digits.count == 25 else { return false }
        let body = digits.dropLast()
        let control = digits[digits.count - 1]

        func remainder(startingAt shift: Int) -> Int {
            var sum = 0
            for (index, digit) in body.enumerated() {
                var weight = (index + shift) % 10
                if weight == 0 { weight = 10 }
                sum += digit * weight
            }
            return sum % 11
        }

        var value = remainder(startingAt: 1)
        if value == 10 { value = remainder(startingAt: 3) }
        return (value == 10 ? 0 : value) == control
    }

    /// Достроить корректный УИН по первым разрядам — нужно для демо-данных.
    static func complete(_ prefix: String) -> String {
        for digit in 0...9 {
            let candidate = prefix + String(digit)
            if isValid(candidate) { return candidate }
        }
        return prefix + "0"
    }
}

// MARK: - Варианты выбора

struct ChoiceOption: Identifiable, Equatable {
    var id: String
    var title: String
    /// Вторая строка в шите выбора — «Зона 1, 40 ₽ в час».
    var subtitle: String?

    init(_ id: String, _ title: String, _ subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

/// Результат из банковского справочника. В отличие от обычного choice, это не
/// вопрос «кого выбрать»: человек ищет банк по названию или БИК, а в форме
/// сохраняется его стабильный идентификатор.
struct BankOption: Identifiable, Equatable {
    var id: String
    var title: String
    var bic: String

    init(_ id: String, _ title: String, bic: String) {
        self.id = id
        self.title = title
        self.bic = bic
    }

    var icon: RowIcon {
        switch id {
        case "tbank":
            return .asset("icTBank")
        case "sber":
            return .symbol(name: "checkmark", tint: .white, background: Color(hex: 0x21A038))
        case "alfa":
            return .symbol(name: "a", tint: .white, background: Color(hex: 0xEF3124))
        case "vtb":
            return .symbol(name: "building.columns.fill", tint: .white, background: Color(hex: 0x0A5CC4))
        default:
            return .symbol(name: "building.columns.fill", tint: .white, background: WBColor.brandBlue)
        }
    }
}

/// Счётчик: своя строка с предыдущим показанием. Предыдущее показание — не
/// украшение: без него человек не понимает, правдоподобно ли то, что он ввёл.
struct MeterSpec: Identifiable {
    var id: String
    var title: String
    var previous: String
    var unit: String
    /// Последние оплаченные показания, свежее — первым. Чипы для быстрого ввода.
    ///
    /// Валидации «меньше прошлого» здесь нет намеренно: счётчик действительно
    /// могли заменить, и красная рамка в таком случае обвиняет человека в чужой
    /// ошибке. Прошлые значения рядом решают ту же задачу лучше — по ним видно
    /// порядок цифр, и опечатка заметна без запретов.
    var history: [String] = []
}

/// Строка услуги в едином платёжном документе: сумма своя, тумблер свой.
/// Из неё же складывается итог — поэтому «оплатить только свет» не требует
/// никакого отдельного экрана.
struct ServiceLine: Identifiable {
    var id: String
    var title: String
    var amount: Decimal
    var isOn: Bool = true
    /// Услугу нельзя отключить: капремонт и содержание идут единой строкой ЕПД.
    var isLocked: Bool = false
}

// MARK: - Смысл поля

/// Канонический смысл поля — общий для всех провайдеров. Нужен смотрелке: по
/// нему строится матрица «что выводится в каком типе оплаты», иначе одинаковые
/// по сути поля разъехались бы по разным строкам из-за разных id.
enum FieldFacet: String, CaseIterable {
    case geo
    case provider
    case payeeType
    case payeeName
    case identifier
    case bankRequisites
    case budgetRequisites
    case purpose
    case payerInfo
    case period
    case services
    case meters
    case penalty
    case insurance
    case tariff
    case thirdParty
    case autopay
    case notify
    case receipt

    var title: String {
        switch self {
        case .geo: "Регион и город"
        case .provider: "Поставщик"
        case .payeeType: "Тип получателя"
        case .payeeName: "Имя получателя"
        case .identifier: "Идентификатор"
        case .bankRequisites: "Реквизиты банка"
        case .budgetRequisites: "Бюджетные реквизиты"
        case .purpose: "Назначение платежа"
        case .payerInfo: "Данные плательщика"
        case .period: "Период оплаты"
        case .services: "Состав услуг"
        case .meters: "Показания счётчиков"
        case .penalty: "Пени"
        case .insurance: "Страхование"
        case .tariff: "Тариф и пакет"
        case .thirdParty: "Оплата за третье лицо"
        case .autopay: "Автоплатёж"
        case .notify: "Уведомления"
        case .receipt: "Квитанция на почту"
        }
    }
}

// MARK: - Поле

/// Условие показа: поле появляется, когда другое заполнено (или равно значению).
struct Reveal {
    var field: String
    var equals: String?

    init(_ field: String, equals: String? = nil) {
        self.field = field
        self.equals = equals
    }
}

enum FieldKind {
    case input(FieldFormat)
    case choice([ChoiceOption])
    /// Тумблер со своей ценой: включённый добавляет её в итог.
    case toggle(price: Decimal? = nil)
    case meters([MeterSpec])
    case services([ServiceLine])
    /// Строка «только прочитать» — пришла из начисления, менять нечего.
    case info(String)
}

struct FormField: Identifiable {
    var id: String
    var label: String
    var kind: FieldKind
    var facet: FieldFacet
    var isRequired: Bool = true
    /// Подсказка «где это взять». Показываем только у поля в фокусе — иначе
    /// форма превращается в стену пояснений, которую никто не читает.
    var hint: String?
    /// Значение на старте: из профиля, шаблона, QR.
    var prefill: String?
    /// Сохранённые реквизиты: чипы под полем. Самый быстрый способ заполнить
    /// форму — не заполнять её.
    var suggestions: [String] = []
    /// Справочник банков для этапа поиска. Сам ввод остаётся обычным текстовым
    /// полем, но выбор результата кладёт в значение id банка, а не текст поиска.
    var bankOptions: [BankOption] = []
    var reveal: Reveal?
    /// Заполнили это поле — идём к провайдеру за начислением.
    var triggersLookup: Bool = false
    /// Показывать вместе с этим полем, а не отдельным шагом.
    ///
    /// Нужно там, где выбор и его следствие — один вопрос: выбрал «отдельные
    /// услуги» — вот они, тут же. Спрашивать «что оплачиваем», а список показывать
    /// следующим экраном значит разорвать одно решение на два шага.
    var attachesTo: String?

    /// Как поле подписано в спеке: тип и ограничения.
    var formatTitle: String {
        switch kind {
        case .input(let format): format.maskTitle
        case .choice(let options): "выбор из \(options.count)"
        case .toggle(let price): price == nil ? "тумблер" : "тумблер, \(Money.rub(price!))"
        case .meters(let meters): "счётчики, \(meters.count) шт."
        case .services(let lines): "услуги, \(lines.count) строк"
        case .info: "из начисления"
        }
    }
}

// MARK: - Секция

struct FormSection: Identifiable {
    var id: String
    /// Заголовок капслоком. nil — секция без заголовка (первая, с идентификатором).
    var title: String?
    var fields: [FormField]
    /// Блок дополнительных параметров — идёт последним. По карте это «блок
    /// необязательных параметров» при пороге больше двух. Свёрнутым он не бывает:
    /// страхование, автоплатёж и напоминания — это то, что банк предлагает, а
    /// спрятанное предложение предложением не является.
    var isExtras: Bool = false
    var reveal: Reveal?
    /// Сноска под карточкой — там, где правило нельзя выразить самим полем:
    /// «показания примут до 25 числа».
    var footnote: String?
}

// MARK: - Шаг

/// Что происходит на одном шаге визарда.
enum StepContent {
    case field(FormField)
    /// Последний шаг: сумма, комиссия, итог.
    case amount
}

/// Шаг пошагового прохождения формы. Один вопрос — один экран: на длинной форме
/// это единственный способ не показывать человеку сразу пятнадцать полей, из
/// которых он всё равно заполняет по одному.
struct FormStep: Identifiable {
    var id: String
    var content: StepContent
    /// Заголовок секции, к которой относится шаг, — «Где платим».
    var group: String?
    var isOptional: Bool

    var field: FormField? {
        if case .field(let field) = content { return field }
        return nil
    }
}

// MARK: - Сумма

enum AmountRule {
    /// Пришла из начисления. `partial` — разрешена ли частичная оплата.
    case fromCharge(partial: Bool)
    /// Произвольная, в пределах. Саджесты — быстрые суммы под полем.
    case free(min: Decimal, max: Decimal, suggestions: [Decimal] = [])
    /// Складывается из выбранных услуг и тумблеров с ценой.
    case fromServices

    var title: String {
        switch self {
        case .fromCharge(let partial):
            partial ? "из начисления, частичная разрешена" : "из начисления, только полностью"
        case .free(let min, let max, _):
            "произвольная, \(Money.rub(min)) — \(Money.rub(max))"
        case .fromServices:
            "сумма выбранных услуг"
        }
    }

    var allowsPartial: Bool {
        switch self {
        case .fromCharge(let partial): partial
        case .free: true
        case .fromServices: false
        }
    }
}

// MARK: - Ответ провайдера

/// Что вернула онлайн-проверка начислений. Все четыре исхода — из карты: экран
/// обязан уметь каждый, потому что отказ провайдера не должен быть тупиком.
enum LookupResult {
    case charge(ChargeInfo)
    /// Начислений нет — переходим к произвольной сумме.
    case none
    /// Счёт не найден: проверить реквизит или сменить поставщика.
    case notFound
    /// Сервис недоступен — платим без проверки, банк дотолкает.
    case unavailable
}

struct ChargeInfo {
    var amount: Decimal
    /// «за август 2026», «постановление от 12.07.2026».
    var period: String
    /// Что ещё пришло с начислением: ФИО, адрес, автомобиль.
    var details: [(String, String)]
    /// Баланс лицевого счёта, если провайдер его отдаёт.
    var balance: Decimal?
    /// Пени отдельной строкой.
    var penalty: Decimal?
    /// Как начисление называет сам поставщик: «Обычный ЕПД». Вместе с периодом
    /// это одна сущность — «Обычный ЕПД за август 2026», — и спрашивать период
    /// отдельным вопросом, когда начисление уже пришло, значит разрывать её.
    var title: String?

    /// Начисление одной строкой — то, что читает человек.
    var displayTitle: String {
        guard let title else { return "Начисление " + period }
        return title + " за " + period
    }
}

// MARK: - Счёт на оплату

/// Одно начисление в списке «Счет на оплату». Период здесь не отдельный вопрос, а
/// часть самого счёта: поставщик отдаёт «Обычный ЕПД за март 2026» одной сущностью,
/// и спрашивать период отдельно значит просить человека собрать её обратно руками.
///
/// Отдельный период остаётся только у произвольной суммы: там платят не по
/// выставленному счёту, и месяц назвать больше некому.
struct ChargeBill: Identifiable {
    var id: String
    /// «Обычный ЕПД», «Долговой ЕПД».
    var title: String
    /// «март 2026».
    var period: String
    /// Когда поставщик сформировал начисление. У части провайдеров дата может не
    /// прийти — тогда экран деталей не выдумывает её и показывает только период.
    var issuedAt: String? = nil
    var amount: Decimal
}

// MARK: - Карточка провайдера

struct ProviderCard {
    var title: String
    var subtitle: String
    var icon: RowIcon
    var inn: String
    /// Срок зачисления — единственное, что живёт под кнопкой.
    var timing: String
    /// Цвета шапки в концепции с этапами: градиент сверху вниз. Пусто — шапка
    /// нейтральная. Это не украшение: человек заходит из каталога и по цвету
    /// узнаёт, что попал к своему поставщику, раньше, чем прочитает название.
    var brandColors: [Color] = []
}

/// Описывает ответ будущего метода проверки реквизитов. В прототипе это
/// детерминированный мок, но форма не знает, каким способом результат получен:
/// по реальному API, по QR или из сохранённого шаблона.
struct ResolvedRecipient {
    var id: String
    var provider: ProviderCard
    var bankID: String? = nil
    var accountPrefix: String? = nil
    var accountSuffix: String? = nil

    func matches(account: String, bankID: String) -> Bool {
        if let expectedBankID = self.bankID, expectedBankID != bankID { return false }
        if let prefix = accountPrefix, !account.hasPrefix(prefix) { return false }
        if let suffix = accountSuffix, !account.hasSuffix(suffix) { return false }
        return true
    }
}

struct RecipientResolver {
    var accountFieldID: String
    var bankFieldID: String
    /// Внутреннее значение, на которое ссылаются следующие ветки формы.
    var resultFieldID: String
    var recipients: [ResolvedRecipient]

    func resolve(values: [String: String]) -> ResolvedRecipient? {
        guard let account = values[accountFieldID], account.count == 20,
              let bankID = values[bankFieldID], !bankID.isEmpty
        else { return nil }
        return recipients.first { $0.matches(account: account, bankID: bankID) }
    }
}

// MARK: - Универсальные атрибуты категории

/// Девять универсальных атрибутов из карты. Здесь только то, что нельзя вывести
/// из самой схемы: остальное смотрелка считает сама — иначе спека начнёт
/// расходиться с формой.
struct CategoryAttributes {
    /// Онлайн-проверка начислений: есть / нет / проверить.
    var onlineCheck: String
    var cashback: String
    var savedRequisites: String
    var balance: String
}

// MARK: - Прошлый платёж

/// Что человек платил этому провайдеру в прошлый раз. Идея на проверку, поэтому
/// живёт только у спек из раздела «Идеи» — в основных сценариях `nil`.
struct LastPayment {
    /// «Июль 2026» — за какой период платили.
    var period: String
    /// Реквизит, по которому платили: он же подставится в форму.
    var identifier: String
    var amount: Decimal
}

// MARK: - Спека типа оплаты

struct ServiceSpec: Identifiable {
    var id: String
    var demoName: String
    var category: String
    var kind: ProviderKind
    var provider: ProviderCard
    /// Предупреждение над формой. У не динамических — про онлайн-загрузку
    /// начисления: человек должен понимать, почему поля появляются по одному.
    var notice: String?
    var sections: [FormSection]
    var amount: AmountRule
    var fee: FeeRule
    /// Что ответит провайдер после ключевого реквизита. nil — проверки нет.
    var lookup: LookupResult?
    var attributes: CategoryAttributes
    var ctaTitle: String = "Продолжить"
    /// Прошлый платёж этому провайдеру — включает блок повторной оплаты.
    var lastPayment: LastPayment?
    /// Кем становится шапка, когда реквизиты разобраны. Нужно платежу по
    /// реквизитам: пока БИК и счёт не введены, поставщик неизвестен, и шапка
    /// честно говорит «по реквизитам», а не выдумывает получателя.
    var resolvedProvider: ProviderCard?
    /// Поле, после заполнения которого поставщик считается найденным.
    var resolvesAfter: String?
    /// У перевода по реквизитам проверка начинается только с полной пары: один
    /// БИК ничего не говорит о получателе, как и один расчётный счёт без банка.
    var resolvesWithAccountAndBank: Bool = false
    /// Результат проверки пары «счёт + банк». Он меняет шапку и открывает только
    /// те этапы, которые нужны найденному получателю.
    var recipientResolver: RecipientResolver? = nil
    /// Сложные платежи по реквизитам собираются не из одиночных экранов, а из
    /// смысловых групп: реквизиты, данные получателя и плательщик. Состав полей
    /// остаётся в секциях, поэтому один экран подходит физлицу, юрлицу и бюджету.
    var usesGroupedRequisites: Bool = false
    /// Начисления, которые отдал поставщик. Их показывает этап «Счет на оплату» в
    /// концепции с этапами; карта формы про них не знает и работает по `lookup`.
    var bills: [ChargeBill] = []

    var allFields: [FormField] { sections.flatMap(\.fields) }

    /// Идентификатор операции — первое обязательное поле ввода. Из него смотрелка
    /// берёт «тип идентификатора» первым универсальным атрибутом.
    var identifierTitle: String {
        guard let field = allFields.first(where: { $0.facet == .identifier }) else {
            return "нет"
        }
        return "\(field.label.lowercased()), \(field.formatTitle)"
    }

    var feeTitle: String {
        switch fee {
        case .free: "0 %"
        case .fixed(let value): Money.rub(value)
        case .rate(let rate): Money.percent(rate * 100) + " от суммы"
        }
    }

    /// Девять универсальных атрибутов категории — ровно тем же списком и в том же
    /// порядке, что в карте. Шесть из девяти считаются из самой схемы: если бы их
    /// вписывали руками, спека начала бы расходиться с формой в первую же неделю.
    var universalAttributes: [(String, String)] {
        [
            ("Тип идентификатора", identifierTitle),
            ("Онлайн-проверка начислений", attributes.onlineCheck),
            ("Сумма", amount.title),
            ("Комиссия", feeTitle),
            ("Кэшбек и ягодки", attributes.cashback),
            ("Сроки зачисления", provider.timing),
            ("Частичная оплата", amount.allowsPartial ? "разрешена" : "запрещена"),
            ("Сохраняемые реквизиты", attributes.savedRequisites),
            ("Баланс лицевого счёта", attributes.balance),
        ]
    }

    /// Сколько необязательных параметров в схеме — по карте больше двух схлопываются
    /// в отдельный блок.
    var optionalCount: Int {
        allFields.filter { !$0.isRequired }.count
    }
}
