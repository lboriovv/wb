import SwiftUI

// Концепция с этапами (макеты 48052:140411 → 48142:114753). Форма разбита на
// последовательные этапы: на экране раскрыт ровно один, он занимает всё место до
// низа, и следующих этапов человек не видит вообще — пока не закончит текущий.
//
// Отличие от карты формы (`ServicePaymentScreen`): там весь платёж виден сразу и
// любое поле открывается модалкой. Здесь экран отвечает на один вопрос за раз, а
// пройденные этапы остаются строками сверху — по ним видно, что уже сказано.
//
// Что важно в устройстве данных: **период не отдельный вопрос**. Поставщик отдаёт
// начисление сущностью «Обычный ЕПД за март 2026 — 10 253,38 ₽», где тип, период и
// сумма неразделимы, поэтому этап «Счет на оплату» показывает их списком
// (`ServiceSpec.bills`). Отдельный ввод периода остаётся только у произвольной
// суммы: там счёта нет, и месяц назвать больше некому.

enum ServiceStages {
    /// Ключ в `values`, под которым живёт выбор начисления. Синтетический: в
    /// схеме поля для него нет, зато условия показа (`Reveal`) на него ссылаются
    /// как на обычное поле — так поле «Период оплаты» появляется ровно у
    /// произвольной суммы, без единого `if` в вёрстке.
    static let billFieldID = "bill"
    /// Оплатить все начисления одной суммой.
    static let allBillsID = "all"
    /// Произвольная сумма — тогда спрашиваем период.
    static let customBillID = "custom"

    static let billsStageID = "bills-stage"
    static let billsTitle = "Счет на оплату"
    static let billsLabel = "Счет на оплату"
}

// MARK: - Этап

struct PaymentStage: Identifiable {
    enum Kind {
        case field(FormField)
        /// Список начислений поставщика.
        case bills
    }

    var id: String
    /// Заголовок раскрытого этапа — он же подпись свёрнутой строки.
    var title: String
    var kind: Kind

    var field: FormField? {
        if case .field(let field) = kind { return field }
        return nil
    }

    var isOptional: Bool {
        guard let field else { return false }
        return !field.isRequired
    }
}

// MARK: - Форма этапами

extension ServiceFormModel {
    /// Нейтральная шапка нужна, пока не завершена проверка пары «счёт + банк».
    /// Результат может прийти и через будущий API-resolver, и как ответ выбранной
    /// ветки прототипа — UI не должен зависеть от способа получения ответа.
    var hasDeferredProvider: Bool {
        spec.recipientResolver != nil || spec.resolvedProvider != nil
    }

    /// Этапы по порядку. Список начислений встаёт сразу за реквизитом, который его
    /// запрашивает: ответ поставщика — следующий вопрос, а не отдельная карточка.
    var stages: [PaymentStage] {
        var result: [PaymentStage] = []
        for field in visibleFields {
            // Тумблеры этапами не бывают: напоминание и автоплатёж — предложения
            // банка, отвечаются одним движением и живут в карточке внизу.
            if case .toggle = field.kind { continue }
            // Найденный получатель уже появился в шапке. Это ответ проверки, а
            // не новый вопрос, поэтому не требуем от человека лишнего тапа.
            if case .info = field.kind { continue }
            result.append(PaymentStage(id: field.id, title: field.label, kind: .field(field)))
            if field.triggersLookup, !spec.bills.isEmpty {
                result.append(
                    PaymentStage(
                        id: ServiceStages.billsStageID,
                        title: ServiceStages.billsTitle,
                        kind: .bills
                    )
                )
            }
        }
        return result
    }

    /// Тумблеры — карточка под этапами.
    var reminderFields: [FormField] {
        visibleFields.filter { field in
            if case .toggle = field.kind { return field.facet != .penalty }
            return false
        }
    }

    // MARK: Начисления

    var selectedBillID: String? {
        let value = values[ServiceStages.billFieldID] ?? ""
        return value.isEmpty ? nil : value
    }

    var selectedBill: ChargeBill? {
        guard let id = selectedBillID else { return nil }
        return spec.bills.first { $0.id == id }
    }

    var isCustomAmount: Bool { selectedBillID == ServiceStages.customBillID }

    var billsTotal: Decimal {
        spec.bills.reduce(0) { $0 + $1.amount }
    }

    /// Сумма, с которой уходим на экран оплаты. Ноль — произвольная, её вводят там.
    var stagesAmount: Decimal {
        if isCustomAmount { return 0 }
        if let bill = selectedBill { return bill.amount }
        if !spec.bills.isEmpty { return billsTotal }
        return lookupState.charge?.amount ?? 0
    }

    /// Начать произвольную сумму с нуля. Подставленное начисление здесь стирается
    /// намеренно: человек только что сказал «введу сам», и чужая цифра в поле
    /// заставляет сначала её удалить.
    func startCustomAmount() {
        amount = AmountInput(0)
        isAmountTouched = false
    }

    func selectBill(_ id: String) {
        values[ServiceStages.billFieldID] = id
        touched.insert(ServiceStages.billFieldID)
    }

    // MARK: Состояние этапа

    func isComplete(_ stage: PaymentStage) -> Bool {
        switch stage.kind {
        case .bills:
            return selectedBillID != nil
        case .field(let field):
            return !field.isRequired || isFilled(field)
        }
    }

    /// Ответ этапа для свёрнутой строки. nil — ещё не отвечали.
    func answer(for stage: PaymentStage) -> String? {
        switch stage.kind {
        case .bills:
            switch selectedBillID {
            case nil: return nil
            case ServiceStages.customBillID: return "Произвольную сумму"
            case ServiceStages.allBillsID: return "Все счета · \(Money.rub(billsTotal))"
            default:
                guard let bill = selectedBill else { return nil }
                return "\(bill.title), \(bill.period)"
            }
        case .field(let field):
            switch field.kind {
            case .input:
                let value = values[field.id] ?? ""
                if let bank = field.bankOptions.first(where: { $0.id == value }) {
                    return bank.title
                }
                return value.isEmpty ? nil : value
            case .choice(let options):
                return options.first { $0.id == values[field.id] }?.title
            case .meters(let meters):
                let filled = meters
                    .map { meterValue(field.id, $0.id) }
                    .filter { !$0.isEmpty }
                return filled.isEmpty ? nil : filled.joined(separator: " · ")
            case .services(let lines):
                let on = lines.filter { isServiceOn(field.id, $0.id) }
                return on.isEmpty ? nil : "\(on.count) из \(lines.count)"
            case .info(let value):
                return value
            case .toggle:
                return isToggleOn(field.id) ? "включено" : nil
            }
        }
    }

    /// Первый незакрытый этап — с него начинается заполнение.
    var firstIncompleteStage: PaymentStage? {
        stages.first { !isComplete($0) }
    }

    func stage(after id: String) -> PaymentStage? {
        let all = stages
        guard let index = all.firstIndex(where: { $0.id == id }), index + 1 < all.count else {
            return nil
        }
        return all[index + 1]
    }

    func stage(before id: String) -> PaymentStage? {
        let all = stages
        guard let index = all.firstIndex(where: { $0.id == id }), index > 0 else { return nil }
        return all[index - 1]
    }

    /// Все этапы закрыты — дальше только экран суммы.
    var areStagesComplete: Bool {
        stages.allSatisfy(isComplete)
    }

    // MARK: Шапка

    /// Реквизиты разобраны — поставщик найден. До этого момента шапка нейтральная:
    /// подставлять получателя, которого ещё не нашли, нельзя.
    var isProviderResolved: Bool {
        if let resolver = spec.recipientResolver {
            return resolver.resolve(values: values) != nil
        }
        if spec.resolvesWithAccountAndBank {
            return !(values["account"] ?? "").isEmpty && !(values["bank"] ?? "").isEmpty
        }
        guard spec.resolvedProvider != nil, let field = spec.resolvesAfter else { return false }
        return !(values[field] ?? "").isEmpty
    }

    /// Кого показывать в шапке.
    var headerProvider: ProviderCard {
        if let resolver = spec.recipientResolver,
           let recipient = resolver.resolve(values: values) {
            return recipient.provider
        }
        guard isProviderResolved, var provider = spec.resolvedProvider else {
            return spec.provider
        }
        // После ручного ввода ФИО или после ответа проверки ИНН в шапке уже
        // показываем конкретного получателя. До этого она остаётся нейтральной
        // («физическому / юридическому / государственному лицу»).
        if let recipient = values["recipient-name"], !recipient.isEmpty {
            provider.title = recipient
        }
        return provider
    }

    /// Заголовок экрана оплаты: «Оплата ЖКХ» — по категории поставщика, а не по его
    /// названию: «Оплата ЖКУ Москвы» в навбар не влезает.
    var payTitle: String {
        if spec.usesGroupedRequisites {
            return "Перевести по реквизитам"
        }
        let category = spec.category.components(separatedBy: " · ").first ?? spec.category
        return "Оплата " + category
    }

    /// Короткая строка под получателем на экране суммы. Для перевода по
    /// реквизитам человеку важнее ещё раз сверить конечные цифры счёта и банк,
    /// чем увидеть техническую категорию операции.
    var paymentDestinationSubtitle: String {
        let account = values["account"] ?? ""
        if spec.id == "requisites-budget", !account.isEmpty { return account }
        let maskedAccount = account.count >= 4 ? "Счёт ··" + String(account.suffix(4)) : ""
        let bankTitle: String = {
            guard let field = spec.allFields.first(where: { $0.id == "bank" }),
                  let bankID = values["bank"],
                  let bank = field.bankOptions.first(where: { $0.id == bankID })
            else { return "" }
            return bank.title
        }()
        let requisites = [maskedAccount, bankTitle].filter { !$0.isEmpty }
        if !requisites.isEmpty { return requisites.joined(separator: " · ") }
        if headerProvider.inn != "—" { return "ИНН " + headerProvider.inn }
        return spec.category
    }

    /// В форме есть хоть один ответ — «Сбросить» имеет смысл.
    var hasAnyAnswer: Bool {
        if selectedBillID != nil { return true }
        return spec.allFields.contains { field in
            switch field.kind {
            case .input, .choice:
                return !(values[field.id] ?? "").isEmpty
            case .toggle:
                return isToggleOn(field.id)
            case .meters(let meters):
                return meters.contains { !meterValue(field.id, $0.id).isEmpty }
            case .services, .info:
                return false
            }
        }
    }
}

// MARK: - Формат

extension FieldFormat {
    /// У реквизита фиксированной длины последняя цифра — сигнал, что ввод
    /// закончен: после неё этап можно закрыть, не прося нажать «Сохранить».
    var hasFixedLength: Bool {
        switch self {
        case .digits(let range): range.lowerBound == range.upperBound
        case .account, .bic, .phone, .month: true
        case .uin, .inn, .oktmo, .plate, .text, .email, .meter: false
        }
    }

    /// Маска в плейсхолдере вместо объяснения «10 цифр»: пример короче описания.
    var placeholder: String {
        switch self {
        case .digits(let range): String(repeating: "0", count: range.lowerBound)
        case .uin: "0000000000000000000"
        case .account: "40702810400000000000"
        case .bic: "044525225"
        case .inn: "7700000000"
        case .oktmo: "45328000"
        case .phone: "+7 000 000-00-00"
        case .plate: "А000АА777"
        case .text: "Впишите"
        case .email: "name@mail.ru"
        case .meter: "0"
        case .month: "08.2026"
        }
    }
}
