import Observation
import SwiftUI

/// Состояние одной заполняемой формы. Всё, что экран умеет решать, решается
/// здесь: какие поля сейчас видны, что уже сломано, о чём спросить провайдера и
/// сколько в итоге спишется. Вьюхи только рисуют.
@MainActor
@Observable
final class ServiceFormModel {
    let spec: ServiceSpec

    /// Значения полей ввода и выбора: у выбора хранится id варианта.
    var values: [String: String] = [:]
    var toggleStates: [String: Bool] = [:]
    /// Ключ — «id поля.id строки»: одна услуга внутри одного поля.
    var serviceStates: [String: Bool] = [:]
    /// Ключ — «id поля.id счётчика».
    var meterValues: [String: String] = [:]

    /// Поля, из которых человек уже уходил: до этого ошибки не показываем — никто
    /// не любит, когда его ругают за незаконченную мысль.
    var touched: Set<String> = []
    /// Тап по кнопке включает валидацию всей формы сразу.
    var didAttemptSubmit = false

    /// Сумма. Для схем «из начисления» и «из услуг» её считает модель, но хранится
    /// она всё равно здесь: человек может перебить начисление частичной оплатой.
    var amount: AmountInput
    var isAmountTouched = false

    /// Текущий шаг визарда. Храним id, а не индекс: у не динамических провайдеров
    /// шаги появляются по ходу заполнения, и индекс перестал бы значить то же.
    /// Переходы между шагами — только по тапу: ни ввод, ни выбор варианта не
    /// перелистывают форму сами. Автопереход экономил одно нажатие и отбирал
    /// понимание: человек не успевал понять, почему экран сменился, особенно когда
    /// следующее поле уже было заполнено и «проскакивало» мимо него.
    var currentStepID: String = ""

    var lookupState: LookupState = .idle
    /// Значение реквизита, для которого уже спрашивали провайдера.
    private var lookupKey: String?
    private var lookupTask: Task<Void, Never>?

    /// Открыт модальный визард — один вопрос поверх списка полей.
    var isStepSheetPresented = false

    var selectedAccountID: String
    var isMethodSheetPresented = false
    var isOutcomePresented = false
    /// Открытый шит выбора — id поля.
    var choiceSheetField: String?

    let accounts: [Account]

    enum LookupState {
        case idle
        case loading
        case done(LookupResult)

        var charge: ChargeInfo? {
            if case .done(.charge(let info)) = self { return info }
            return nil
        }
    }

    init(spec: ServiceSpec, accounts: [Account] = TransferModes.sharedAccounts) {
        self.spec = spec
        if spec.id == "requisites-budget" {
            let wallet = Account(
                id: "wallet-1321",
                icon: .asset("icWallet"),
                amountTitle: Money.rub(1235),
                subtitle: "WB Кошелёк ··1321",
                balance: 1235
            )
            self.accounts = [wallet] + accounts
            self.selectedAccountID = wallet.id
        } else {
            self.accounts = accounts
            self.selectedAccountID = accounts.first?.id ?? ""
        }
        self.amount = AmountInput(0)

        applyInitialValues()

        currentStepID = steps.first?.id ?? Self.amountStepID
    }

    /// Состояние формы «как при входе»: предзаполненное из профиля и шаблона,
    /// услуги ЕПД включены, тумблеры выключены.
    private func applyInitialValues() {
        for field in spec.allFields {
            if let prefill = field.prefill { values[field.id] = prefill }
            switch field.kind {
            case .toggle:
                toggleStates[field.id] = false
            case .services(let lines):
                for line in lines { serviceStates[key(field.id, line.id)] = line.isOn }
            case .meters:
                break
            case .input, .choice, .info:
                break
            }
        }

        // Свободную сумму сразу ставим в минимум только если он осмысленный —
        // иначе человек начинает не с пустого поля, а со стирания чужой цифры.
        if case .free(_, _, let suggestions) = spec.amount, let first = suggestions.first {
            amount = AmountInput(first)
        }
    }

    /// Сбросить всё введённое и вернуть форму в начальное состояние. Нужно кнопке
    /// «Сбросить» в концепции со смысловыми группами: там она стоит рядом с
    /// главной кнопкой, как в поиске Яндекс.Путешествий, и обнуляет весь платёж, а
    /// не одно поле.
    func reset() {
        values = [:]
        toggleStates = [:]
        serviceStates = [:]
        meterValues = [:]
        touched = []
        didAttemptSubmit = false
        amount = AmountInput(0)
        isAmountTouched = false
        applyInitialValues()
        refreshRecipientResolution()
        // Начисление тоже сбрасываем: показывать сумму прошлого счёта рядом с
        // пустым реквизитом нельзя.
        refreshLookup()
        currentStepID = steps.first?.id ?? Self.amountStepID
    }

    /// Короткий ответ шага для сводки над текущим вопросом. Показываем ровно то,
    /// что человек выбрал или ввёл, — по этой строке он себя и проверяет.
    func answerSummary(for step: FormStep) -> String {
        guard let field = step.field else { return Money.rub(total) }
        switch field.kind {
        case .input:
            let value = values[field.id] ?? ""
            if let bank = field.bankOptions.first(where: { $0.id == value }) {
                return bank.title
            }
            return value.isEmpty ? "не заполнено" : value
        case .choice(let options):
            let id = values[field.id] ?? ""
            return options.first { $0.id == id }?.title ?? "не выбрано"
        case .toggle(let price):
            guard isToggleOn(field.id) else { return "выключено" }
            return price == nil ? "включено" : Money.rub(price!)
        case .meters(let meters):
            let filled = meters.filter { !meterValue(field.id, $0.id).isEmpty }
            if filled.isEmpty { return "не передавали" }
            return filled.map { meterValue(field.id, $0.id) }.joined(separator: " · ")
        case .services(let lines):
            let on = lines.filter { isServiceOn(field.id, $0.id) }
            return "\(on.count) из \(lines.count) · \(Money.rub(servicesTotal))"
        case .info(let value):
            return value
        }
    }

    private func key(_ fieldID: String, _ itemID: String) -> String { fieldID + "." + itemID }

    // MARK: - Видимость

    /// Условие показа выполнено?
    func isRevealed(_ reveal: Reveal?) -> Bool {
        guard let reveal else { return true }
        let value = values[reveal.field] ?? ""
        guard !value.isEmpty else { return false }
        if let equals = reveal.equals { return value == equals }
        return true
    }

    /// Поле считается заполненным, если в нём есть что заполнять и там что-то есть.
    func isFilled(_ field: FormField) -> Bool {
        switch field.kind {
        case .input, .choice:
            return !(values[field.id] ?? "").isEmpty
        case .toggle, .meters, .services, .info:
            return true
        }
    }

    /// Обязательные поля основной части — по ним считается, дошла ли форма до конца.
    private var requiredBackbone: [FormField] {
        spec.sections
            .filter { !$0.isExtras && isRevealed($0.reveal) }
            .flatMap(\.fields)
            .filter { isRevealed($0.reveal) && $0.isRequired }
    }

    var isBackboneFilled: Bool {
        requiredBackbone.allSatisfy(isFilled)
    }

    /// Поля секции, которые сейчас имеет смысл рисовать.
    ///
    /// У динамического провайдера видно всё сразу: набор параметров уже пришёл,
    /// прятать его — врать про длину формы. У не динамического поля открываются по
    /// одному: следующий атрибут провайдер отдаёт только после предыдущего, и
    /// показать пустую заготовку было бы обещанием, которое банк не контролирует.
    func visibleFields(in section: FormSection) -> [FormField] {
        // Пени живут не в списке полей, а в карточке начисления: см. `penaltyField`.
        let revealed = section.fields.filter { isRevealed($0.reveal) && $0.facet != .penalty }
        guard spec.kind == .stepwise, !section.isExtras else { return revealed }

        // Идём по объявленному порядку и останавливаемся на первом месте, до
        // которого человек ещё не дошёл. Различать приходится два случая, и
        // путать их нельзя:
        //   · условие ссылается на незаполненное поле — мы просто ещё не дошли,
        //     дальше показывать нечего, обрываемся;
        //   · условие ссылается на заполненное, но с другим значением — это чужая
        //     ветка развилки, её пропускаем и смотрим следующее поле.
        var result: [FormField] = []
        for field in section.fields where field.facet != .penalty {
            if let reveal = field.reveal {
                let value = values[reveal.field] ?? ""
                if value.isEmpty { break }
                if let equals = reveal.equals, value != equals { continue }
            }
            result.append(field)
            if field.isRequired, !isFilled(field) { break }
        }
        return result
    }

    /// Секции формы списком.
    ///
    /// Необязательный блок больше не прячется в аккордеон. Аккордеон здесь врал
    /// дважды: он делал форму короче на вид, чем она есть, и заодно убирал с
    /// глаз то, что банк вообще-то предлагает, — страхование, автоплатёж,
    /// напоминания. Спрятанное предложение — не предложение. Блок остался
    /// отдельной секцией в конце: видно, но не мешает главному.
    var visibleSections: [FormSection] {
        spec.sections.filter { isRevealed($0.reveal) && !visibleFields(in: $0).isEmpty }
    }

    /// Все поля, которые сейчас на экране, — по ним идёт валидация на отправке.
    var visibleFields: [FormField] {
        visibleSections.flatMap { visibleFields(in: $0) }
    }

    // MARK: - Шаги

    /// Секции для пошагового прохождения. Отличие от `visibleSections` одно:
    /// необязательный блок не ждёт, пока заполнено обязательное. В визарде он не
    /// прячется, а становится шагами, которые можно проскочить.
    var stepSections: [FormSection] {
        spec.sections.filter { isRevealed($0.reveal) && !visibleFields(in: $0).isEmpty }
    }

    /// Один вопрос — один шаг. Счётчики и состав услуг остаются одним шагом:
    /// это один вопрос («что показывают приборы», «за что платим»), просто
    /// ответов в нём несколько.
    var steps: [FormStep] {
        var result: [FormStep] = []
        for section in stepSections {
            for field in visibleFields(in: section) {
                if case .info = field.kind { continue }
                // Автоплатёж, напоминания, страхование — предложения банка, а не
                // вопросы, без которых платёж не уйдёт. Отдельным шагом они
                // читаются как обязательный этап, поэтому живут строкой на карте
                // формы и отвечаются одним движением.
                if case .toggle = field.kind { continue }
                // Поле-компаньон рисуется на шаге своего хозяина.
                if field.attachesTo != nil { continue }
                result.append(
                    FormStep(
                        id: field.id,
                        content: .field(field),
                        group: section.title,
                        isOptional: !field.isRequired
                    )
                )
            }
        }
        // Сумма — всегда последний шаг: она зависит от всего, что введено выше.
        result.append(FormStep(id: Self.amountStepID, content: .amount, group: nil, isOptional: false))
        return result
    }

    static let amountStepID = "amount"

    /// Поля, которые показываются на одном шаге с этим — и только если их условие
    /// показа выполнено.
    func companions(of field: FormField) -> [FormField] {
        spec.allFields.filter { $0.attachesTo == field.id && isRevealed($0.reveal) }
    }

    var currentStep: FormStep? {
        steps.first { $0.id == currentStepID } ?? steps.first
    }

    var currentStepIndex: Int {
        steps.firstIndex { $0.id == currentStepID } ?? 0
    }

    /// Шаги, на которые уже ответили — их сводка висит над текущим вопросом.
    ///
    /// Пропущенные необязательные вопросы в сводку не попадают: строка «Автоплатёж
    /// — выключено» не сообщает ничего, кроме того, что человек ничего не делал, а
    /// место занимает наравне с настоящим ответом.
    var answeredSteps: [FormStep] {
        steps.prefix(currentStepIndex).filter { step in
            guard let field = step.field else { return true }
            switch field.kind {
            case .input, .choice:
                return !(values[field.id] ?? "").isEmpty
            case .toggle:
                return isToggleOn(field.id)
            case .meters(let meters):
                return meters.contains { !meterValue(field.id, $0.id).isEmpty }
            case .services, .info:
                return true
            }
        }
    }

    var isLastStep: Bool { currentStepIndex >= steps.count - 1 }

    var canGoBack: Bool { currentStepIndex > 0 }

    /// Вниз пускаем, когда на вопрос ответили или отвечать не обязательно.
    /// Блокировать шаг вовсе нельзя: человек должен иметь право посмотреть, что
    /// дальше, — иначе форма превращается в допрос.
    var canGoForward: Bool {
        guard !isLastStep, let step = currentStep else { return false }
        switch step.content {
        case .amount: return false
        case .field(let field):
            return step.isOptional || isFilled(field)
        }
    }

    func goForward() {
        let all = steps
        guard currentStepIndex + 1 < all.count else { return }
        currentStepID = all[currentStepIndex + 1].id
    }

    func goBack() {
        let all = steps
        guard currentStepIndex > 0 else { return }
        currentStepID = all[currentStepIndex - 1].id
    }

    func goToStep(_ id: String) {
        guard steps.contains(where: { $0.id == id }) else { return }
        currentStepID = id
    }

    /// Тап по строке на экране со всеми полями: открываем визард ровно на этом
    /// вопросе. Дальше он ведёт по цепочке сам, а закрыть его можно в любой момент
    /// — экран со списком под ним и показывает, сколько уже заполнено.
    func openStep(_ id: String) {
        goToStep(id)
        isStepSheetPresented = true
    }

    /// Заполнен последний вопрос — визард закрывается сам: держать модалку с
    /// пустым содержимым, когда отвечать больше не на что, незачем.
    func closeStepSheet() {
        isStepSheetPresented = false
    }

    /// Сколько обязательных вопросов уже закрыто — подпись прогресса на списке.
    var filledRequiredCount: Int {
        requiredBackbone.filter(isFilled).count
    }

    var requiredCount: Int { requiredBackbone.count }

    /// Ушли со шага — считаем его тронутым, чтобы ошибка формата не появлялась
    /// раньше, чем человек закончил отвечать.
    func leaveStep() {
        if let step = currentStep, case .field(let field) = step.content {
            markTouched(field.id)
        }
    }

    // MARK: - Валидация

    /// Ошибка появляется после ухода из поля либо после попытки продолжить сценарий.
    /// До этого не отвлекаем человека сообщением о незаконченной мысли.
    func error(for field: FormField, focused: String?) -> String? {
        let value = values[field.id] ?? ""
        let shouldShowError = didAttemptSubmit || touched.contains(field.id)

        guard shouldShowError else { return nil }

        switch field.kind {
        case .input(let format):
            if value.isEmpty {
                return field.isRequired ? "Обязательное поле" : nil
            }
            if spec.id == "requisites-budget", field.id == "uin", value == "0" {
                return nil
            }
            let readyToJudge = focused != field.id || format.isComplete(value)
            guard readyToJudge else { return nil }
            if let formatError = format.error(value) { return formatError }
            if spec.id == "requisites-budget" {
                switch field.id {
                case "account" where value.allSatisfy({ $0 == "0" }):
                    return "Не удалось определить счёт по этим реквизитам"
                case "recipient-inn" where value.allSatisfy({ $0 == "0" }):
                    return "Получатель с таким ИНН не найден"
                case "recipient-kpp" where value.allSatisfy({ $0 == "0" }):
                    return "КПП с такими данными не найден"
                case "kbk" where value.allSatisfy({ $0 == "0" }):
                    return "КБК не найден — проверьте реквизиты квитанции"
                case "oktmo" where value.allSatisfy({ $0 == "0" }):
                    return "Не удалось определить ОКТМО"
                default:
                    break
                }
            }
            return nil
        case .choice:
            return value.isEmpty && field.isRequired && shouldShowError
                ? "Обязательное поле"
                : nil
        case .toggle, .meters, .services, .info:
            return nil
        }
    }

    /// Первое поле с ошибкой — к нему уводим фокус по тапу на кнопку.
    func firstInvalidField() -> String? {
        didAttemptSubmit = true
        return visibleFields.first { error(for: $0, focused: nil) != nil }?.id
    }

    /// Поле, на которое встаёт фокус при открытии экрана: первое пустое.
    var autofocusField: String? {
        visibleFields.first { field in
            if case .input = field.kind { return !isFilled(field) }
            return false
        }?.id
    }

    // MARK: - Изменения

    func setValue(_ raw: String, for field: FormField) {
        var value = raw
        if case .input(let format) = field.kind { value = format.normalized(raw) }
        values[field.id] = value
        applyRecipientAutofill(after: field.id, value: value)
        refreshRecipientResolution()
        refreshLookup()
    }

    /// После проверки ИНН бэкенд возвращает связанные реквизиты получателя.
    /// Здесь ответы из макета служат демо-данными; в продукте этот метод заменяет
    /// результат API, а не вычисляет компанию по цифрам ИНН на устройстве.
    private func applyRecipientAutofill(after fieldID: String, value: String) {
        switch (spec.id, fieldID, value) {
        case ("requisites-legal", "recipient-inn", "7727282640"):
            values["recipient-name"] = "ОАНО ШКОЛА «НИКА»"
            values["recipient-kpp"] = "772701001"
        case ("requisites-budget", "recipient-inn", "7730160480"),
             ("requisites-budget", "recipient-name", "ГБОУ ОБРАЗОВАТЕЛЬНЫЙ ЦЕНТР «ПРОТОН»"),
             ("requisites-budget", "recipient-kpp", "773001001"):
            values["recipient-inn"] = "7730160480"
            values["recipient-name"] = "ГБОУ ОБРАЗОВАТЕЛЬНЫЙ ЦЕНТР «ПРОТОН»"
            values["recipient-kpp"] = "773001001"
            values["kbk"] = "07500000000013111042"
        case ("requisites-budget", "recipient-inn", "7730160488"):
            values["recipient-name"] = "ГБОУ ШКОЛА № 1465"
            values["recipient-kpp"] = "773001002"
            values.removeValue(forKey: "kbk")
        case ("requisites-legal", "recipient-inn", _),
             ("requisites-budget", "recipient-inn", _):
            values.removeValue(forKey: "recipient-kpp")
            values.removeValue(forKey: "recipient-name")
            if spec.id == "requisites-budget" { values.removeValue(forKey: "kbk") }
        default:
            break
        }
    }

    func pickChoice(_ optionID: String, for field: FormField) {
        values[field.id] = optionID
        touched.insert(field.id)
        // Смена развилки может убрать поля, которые от неё зависели: их значения
        // не чистим намеренно — вернувшись назад, человек находит форму как оставил.
        refreshRecipientResolution()
        refreshLookup()
    }

    /// Выбор банка — не радиокнопка: выбор в поисковой выдаче сразу становится
    /// ответом этапа. Поиск храним только во View, в модели остаётся id банка.
    func pickBank(_ bank: BankOption, for field: FormField) {
        pickChoice(bank.id, for: field)
    }

    func markTouched(_ id: String) { touched.insert(id) }

    func isToggleOn(_ id: String) -> Bool { toggleStates[id] ?? false }
    func setToggle(_ id: String, _ value: Bool) {
        toggleStates[id] = value
        // Reveal хранит условие в `values`. Благодаря этому зависимые поля
        // одинаково работают для input, choice и переключателя.
        values[id] = value ? "true" : ""
        // Для перевода себе имя не угадывается по счёту: это явный выбор
        // пользователя, поэтому подставляем профиль только после включения
        // тумблера и не трогаем вручную введённое ФИО при выключении.
        if id == "recipient-self", value {
            values["recipient-name"] = "Борисов Леонид Сергеевич"
        }
    }

    func isServiceOn(_ fieldID: String, _ lineID: String) -> Bool {
        serviceStates[key(fieldID, lineID)] ?? false
    }

    func setService(_ fieldID: String, _ lineID: String, _ value: Bool) {
        serviceStates[key(fieldID, lineID)] = value
    }

    func meterValue(_ fieldID: String, _ meterID: String) -> String {
        meterValues[key(fieldID, meterID)] ?? ""
    }

    func setMeter(_ fieldID: String, _ meterID: String, _ value: String) {
        meterValues[key(fieldID, meterID)] = FieldFormat.meter.normalized(value)
    }

    // MARK: - Повторный платёж

    /// Повторить прошлый платёж: подставляем реквизит и ждём начисление. Сумму не
    /// копируем из прошлого месяца намеренно — за август начислено своё, и
    /// показывать сумму июля рядом со словом «оплатить» значит обещать не ту цифру.
    func repeatLastPayment() {
        guard let last = spec.lastPayment,
              let field = spec.allFields.first(where: { $0.triggersLookup })
        else { return }
        values[field.id] = last.identifier
        touched.insert(field.id)
        refreshLookup()
    }

    // MARK: - Демо-заполнение

    /// Заполнить форму правдоподобными данными — для съёмки кадров и показа.
    ///
    /// Проходим схему несколько раз: у не динамических провайдеров заполненное
    /// поле открывает следующее, и за один проход до конца формы не дойти.
    func fillWithDemoData() {
        for _ in 0..<8 {
            var didChange = false

            for field in visibleFields where !isFilled(field) {
                switch field.kind {
                case .input(let format):
                    // Текст по смыслу поля — только в текстовые поля: «ИНН
                    // получателя: ООО „Ромашка“» на кадре читается как баг.
                    var value = field.suggestions.first
                    if value == nil, case .text = format {
                        value = Self.demoText(for: field.facet)
                    }
                    setValue(field.bankOptions.first?.id ?? value ?? format.demoValue, for: field)
                    didChange = true
                case .choice(let options):
                    guard let first = options.first else { continue }
                    pickChoice(first.id, for: field)
                    didChange = true
                case .toggle, .meters, .services, .info:
                    continue
                }
            }

            // Показания: берём последнее оплаченное и прибавляем расход за месяц.
            for field in visibleFields {
                guard case .meters(let meters) = field.kind else { continue }
                for (index, meter) in meters.enumerated()
                where meterValue(field.id, meter.id).isEmpty {
                    let previous = Int(meter.previous.filter(\.isNumber)) ?? 0
                    setMeter(field.id, meter.id, String(previous + 14 + index * 9))
                    didChange = true
                }
            }

            refreshRecipientResolution()
            refreshLookup()
            if !didChange { break }
        }

        // Свободную сумму без саджестов тоже надо чем-то заполнить: пустая зона
        // суммы на кадре читается как незаконченный экран.
        if case .free(let min, _, _) = amountRule, baseAmount == 0 {
            applyQuickAmount(max(min, 1200))
        }
    }

    // MARK: - Определение получателя

    /// Здесь находится единственная временная заглушка будущего API. Когда
    /// появится бэкенд, он будет обновлять те же `resultFieldID` и данные шапки;
    /// экран и порядок этапов менять не придётся.
    private func refreshRecipientResolution() {
        guard let resolver = spec.recipientResolver else { return }
        if let recipient = resolver.resolve(values: values) {
            values[resolver.resultFieldID] = recipient.id
        } else {
            values.removeValue(forKey: resolver.resultFieldID)
        }
    }

    /// Текст по смыслу поля, а не по формату.
    private static func demoText(for facet: FieldFacet) -> String? {
        switch facet {
        case .payeeName: "ООО «Ромашка»"
        case .purpose: "Оплата по счёту 1345 от 12.08.2026"
        case .payerInfo: "Борисов Леонид Игоревич"
        default: nil
        }
    }

    // MARK: - Проверка у провайдера

    private var triggerField: FormField? {
        spec.allFields.first(where: \.triggersLookup)
    }

    /// Секция, из которой уходит запрос к провайдеру. Ответ рисуем сразу под ней:
    /// он отвечает на реквизит, который только что ввели, и в конце длинной формы
    /// его уже не связать с вопросом.
    var lookupSectionID: String? {
        spec.sections.first { section in
            section.fields.contains(where: \.triggersLookup)
        }?.id
    }

    /// Реквизит изменился — решаем, идти ли к провайдеру. Правка раннего поля
    /// сбрасывает уже полученное начисление: показывать сумму от прошлого счёта
    /// рядом с новым номером нельзя.
    func refreshLookup() {
        guard let field = triggerField, let result = spec.lookup else { return }
        let value = values[field.id] ?? ""

        guard case .input(let format) = field.kind,
              format.isComplete(value),
              format.error(value) == nil
        else {
            lookupTask?.cancel()
            lookupKey = nil
            if case .idle = lookupState {} else { lookupState = .idle }
            return
        }

        guard lookupKey != value else { return }
        lookupKey = value
        lookupTask?.cancel()
        lookupState = .loading
        lookupTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1100))
            guard let self, !Task.isCancelled else { return }
            self.apply(result)
        }
    }

    private func apply(_ result: LookupResult) {
        lookupState = .done(result)
        if case .charge(let info) = result {
            // Начисление подставляем в сумму, даже если человек уже что-то набрал:
            // он просил найти счёт — вот счёт. Частичную оплату он введёт поверх.
            amount = AmountInput(info.amount)
            isAmountTouched = false

            // Пени включены по умолчанию — это долг, а не услуга банка. Тумблер
            // рядом с ними делал вид, что платить пени необязательно; отказаться
            // можно, но это отдельное решение, а не невыбранная галочка.
            if info.penalty != nil, let field = spec.allFields.first(where: { $0.facet == .penalty }) {
                toggleStates[field.id] = true
            }
        }
    }

    /// Пени показываем внутри карточки начисления и только если они реально
    /// пришли: вопрос «оплатить пени» при отсутствии пеней — лишняя строка.
    var penaltyField: FormField? {
        guard lookupState.charge?.penalty != nil else { return nil }
        return spec.allFields.first { $0.facet == .penalty }
    }

    func retryLookup() {
        lookupKey = nil
        refreshLookup()
    }

    // MARK: - Сумма и итог

    /// Правило суммы с учётом ответа провайдера: начислений нет или сервис лежит —
    /// значит сумма становится произвольной, и это не ошибка, а ветка сценария.
    var amountRule: AmountRule {
        switch lookupState {
        case .done(.none), .done(.unavailable):
            return .free(min: 10, max: 300_000, suggestions: [])
        default:
            return spec.amount
        }
    }

    var isAmountEditable: Bool {
        switch amountRule {
        case .fromServices: false
        case .fromCharge(let partial): partial
        case .free: true
        }
    }

    /// На форме есть разложенный состав услуг — значит сумму считаем по нему.
    var hasServiceLines: Bool {
        visibleFields.contains { field in
            if case .services = field.kind { return true }
            return false
        }
    }

    /// Сумма без комиссии и без надбавок.
    ///
    /// «Весь документ» и «отдельные услуги» — одна и та же схема с одним правилом
    /// суммы: пока состав не разложен, сумма равна начислению целиком. Иначе
    /// переключение развилки обнуляло бы платёж.
    var baseAmount: Decimal {
        if case .fromServices = amountRule {
            return hasServiceLines ? servicesTotal : (lookupState.charge?.amount ?? 0)
        }
        return amount.decimal
    }

    /// Услуги, отмеченные в едином платёжном документе.
    var servicesTotal: Decimal {
        var sum: Decimal = 0
        for field in visibleFields {
            guard case .services(let lines) = field.kind else { continue }
            for line in lines where isServiceOn(field.id, line.id) {
                sum += line.amount
            }
        }
        return sum
    }

    /// Тумблеры со своей ценой — страховка в квитанции и пени из начисления.
    var extrasTotal: Decimal {
        var sum: Decimal = 0
        for field in visibleFields + [penaltyField].compactMap(\.self) {
            guard case .toggle(let price) = field.kind, let price, isToggleOn(field.id) else {
                continue
            }
            sum += price
        }
        return sum
    }

    var subtotal: Decimal { baseAmount + extrasTotal }

    var feeValue: Decimal { spec.fee.fee(for: subtotal) }

    var total: Decimal { subtotal + feeValue }

    var selectedAccount: Account? {
        accounts.first { $0.id == selectedAccountID }
    }

    /// Сколько не хватает на выбранном счёте — кнопка меняется на «Пополнить».
    var shortfall: Decimal? {
        guard let balance = selectedAccount?.balance else { return nil }
        let missing = total - balance
        return missing > 0 ? missing : nil
    }

    /// Сумма вне допустимых границ: сообщаем прямо у поля, а не после нажатия.
    var amountError: String? {
        guard case .free(let min, let max, _) = amountRule else { return nil }
        guard isAmountTouched || didAttemptSubmit else { return nil }
        if baseAmount == 0 { return didAttemptSubmit ? "Введите сумму" : nil }
        if baseAmount < min { return "Минимум \(Money.rub(min))" }
        if baseAmount > max { return "Максимум \(Money.rub(max))" }
        return nil
    }

    var quickAmounts: [Decimal] {
        if case .free(_, _, let suggestions) = amountRule { return suggestions }
        return []
    }

    func applyQuickAmount(_ value: Decimal) {
        amount = AmountInput(value)
        isAmountTouched = true
    }

    func setAmount(_ raw: String) {
        let digits = raw.filter { $0.isNumber || $0 == "," || $0 == "." }
        let parts = digits.replacingOccurrences(of: ".", with: ",").split(separator: ",")
        var input = AmountInput(0)
        if let whole = parts.first, let value = Decimal(string: String(whole.prefix(9))) {
            input = AmountInput(value)
        }
        if parts.count > 1 {
            let fraction = String(parts[1].prefix(2))
            input.appendSeparator()
            for character in fraction { input.append(digit: String(character)) }
        }
        amount = input
        isAmountTouched = true
    }

    /// Что показывает кнопка. Она всегда активна: выключенная кнопка не объясняет,
    /// чего не хватает, — а нажатие объясняет.
    enum CTAKind: Equatable {
        case primary(String)
        case topUp(Decimal)
    }

    var cta: CTAKind {
        // Пока сумма неизвестна, кнопка не говорит про нехватку денег: человек ещё
        // не видел, сколько с него хотят, и «не хватает 4 078 ₽» в этот момент —
        // приговор за неназванную цену.
        if baseAmount > 0, let shortfall, isBackboneFilled { return .topUp(shortfall) }
        return .primary(spec.ctaTitle)
    }

    /// Строка над кнопкой: она есть всегда, потому что «сколько это стоит» — тот
    /// вопрос, на который экран обязан отвечать в любой момент, а не в конце.
    var totalLine: (title: String, value: String?) {
        guard baseAmount > 0 else {
            if spec.lookup != nil, lookupState.charge == nil {
                return ("Сумму узнаем, когда найдём начисление", nil)
            }
            return ("Сумму вводите сами", nil)
        }
        return ("Итого к списанию", Money.rub(total))
    }

    /// Строка списания.
    var sourceRow: DetailRow? {
        guard let account = selectedAccount else { return nil }
        return DetailRow(
            id: "source-" + account.id,
            icon: account.icon,
            top: .secondary("С " + account.subtitle),
            bottom: .primary(account.amountTitle),
            trailingBadge: account.badge
        )
    }

    /// Кадр исхода для этой формы: получатель и сумма берутся из заполненного,
    /// поэтому экран успеха не приходится настраивать отдельно.
    var outcomeScenario: OutcomeScenario {
        OutcomeScenario(
            id: spec.id + "-processing",
            demoName: spec.demoName,
            outcome: .processing,
            source: outcomeSource,
            amount: total,
            badge: spec.fee.badge(for: subtotal)
        )
    }

    private var outcomeSource: TransactionConfig {
        let recipient = headerProvider
        return TransactionConfig(
            id: spec.id,
            demoName: spec.demoName,
            operation: .serviceBill,
            defaultRail: nil,
            title: payTitle,
            navTrailing: nil,
            initialAmount: total,
            fee: spec.fee,
            message: nil,
            accounts: accounts,
            destination: nil,
            destinationAccountID: nil,
            toggles: [],
            suggestSlot: .none,
            bottomSlot: .empty,
            ctaTitle: spec.ctaTitle,
            deliveryNote: recipient.timing,
            success: SuccessConfig(
                title: TransactionOutcome.processing.title,
                subtitle: "Со счёта " + (selectedAccount?.subtitle ?? ""),
                icon: recipient.icon,
                counterparty: recipient.title,
                chip: spec.usesGroupedRequisites
                    ? paymentDestinationSubtitle
                    : lookupState.charge?.period
            )
        )
    }
}
