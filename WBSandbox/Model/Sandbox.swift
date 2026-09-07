import SwiftUI

/// Настройки песочницы. Читаются из launch-аргументов, чтобы на показе попадать
/// сразу в нужный кадр. В Xcode: Product → Scheme → Edit Scheme → Arguments.
///
///     -demoOpen transfer/by-phone   открыть сразу этот пункт
///     -demoAmount 250               стартовая сумма
///     -demoAccount wb-1321-cash     выбранный счёт списания
///     -demoSheet 1                  открыть шит «Счёт списания»
///     -demoOutcome 1                открыть исход операции
///     -demoHideSwitcher 1           спрятать переключатель подпунктов
///     -demoFill 1                   заполнить сложную форму демо-данными
///     -demoBill 2026-03              открыть детали конкретного начисления
///     -demoTilt "8,-16"             зафиксировать наклон открытки: pitch, yaw
///     -demoGiftElapsed 0.6          кадр раскрытия подарка на конкретной секунде
enum SandboxSettings {
    private static var defaults: UserDefaults { .standard }
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var showsItemSwitcher: Bool { !defaults.bool(forKey: "demoHideSwitcher") }

    /// Открыть форму оплаты услуг уже заполненной: так кадры для показа
    /// снимаются одинаковыми при каждом прогоне.
    static var fillsForms: Bool { defaults.bool(forKey: "demoFill") }

    /// На каком шаге открыть пошаговую форму: номер с единицы или `last`.
    /// Нужно, чтобы снимать кадры конкретных шагов, а не листать их руками.
    static var startStep: String? { defaults.string(forKey: "demoStep") }

    /// `-demoCard 1` — какая открытка активна на старте, счёт с нуля.
    static var startCard: Int? {
        guard let raw = defaults.string(forKey: "demoCard") else { return nil }
        return Int(raw)
    }

    /// `-demoGiftOpened 1` — открыть подарок сразу раскрытым, без вылета.
    /// Нужно, чтобы снимать финальный кадр, а не гоняться за анимацией.
    static var giftOpened: Bool { launchBool(forKey: "demoGiftOpened") }

    /// `-demoGiftElapsed 0.6` — показать конкретный кадр раскрытия подарка.
    /// Удобно для эффектов вроде конверта: финал может быть правильным, а
    /// ошибка слойности живёт только в середине движения.
    static var giftElapsed: Double? {
        guard let raw = launchValue(forKey: "demoGiftElapsed") else { return nil }
        return Double(raw)
    }

    /// `-demoTilt "8,-16"` — зафиксировать наклон открытки: pitch и yaw в
    /// градусах. В симуляторе датчиков нет, и без этого кадр наклона руками не
    /// снять: палец, который наклоняет карточку, на скриншот не попадает.
    /// Наклон от пальца при этом продолжает работать и складывается с фиксацией.
    static var tilt: (pitch: Double, yaw: Double)? {
        guard let raw = defaults.string(forKey: "demoTilt") else { return nil }
        let parts = raw
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    static var openPath: String? { defaults.string(forKey: "demoOpen") }
    /// Идентификатор этапа для быстрой проверки конкретного кадра рабочего flow.
    static var startStage: String? { defaults.string(forKey: "demoStage") }
    /// Идентификатор начисления для проверки промежуточного экрана деталей.
    static var startBillID: String? { defaults.string(forKey: "demoBill") }
    /// Открыть рабочую копию этапов как возврат к сохранённому черновику.
    static var resumesDraft: Bool { defaults.bool(forKey: "demoResume") }
    static var startsWithSheet: Bool { defaults.bool(forKey: "demoSheet") }
    static var startsWithOutcome: Bool { defaults.bool(forKey: "demoOutcome") }
    static var startAccount: String? { defaults.string(forKey: "demoAccount") }
    static var startAmount: Decimal? {
        guard let raw = defaults.string(forKey: "demoAmount") else { return nil }
        return Decimal(string: raw)
    }

    private static func launchBool(forKey key: String) -> Bool {
        guard let raw = launchValue(forKey: key)?.lowercased() else { return false }
        return raw == "1" || raw == "true" || raw == "yes"
    }

    private static func launchValue(forKey key: String) -> String? {
        guard let keyIndex = arguments.firstIndex(of: "-\(key)") else { return nil }
        let valueIndex = arguments.index(after: keyIndex)
        guard valueIndex < arguments.endIndex else { return "1" }

        let value = arguments[valueIndex]
        return value.hasPrefix("-") ? "1" : value
    }
}

// MARK: - Каталог

enum SandboxDestination {
    case transaction(TransactionConfig)
    case outcome(OutcomeScenario)
    case iconMorph
    /// Выбор открытки к переводу: наклон, блик и свайп по вариантам.
    case postcards([Postcard])
    /// Получение открытки: подарок вылетает снизу с оборотом.
    case postcardGift([Postcard])
    /// Получение открытки v2: конверт, жест по ленте, выезд карточки и конфетти.
    case postcardGiftEnvelope([Postcard])
    /// Сложная форма оплаты услуг — одна вёрстка на все типы.
    case serviceForm(ServiceSpec)
    /// Та же форма во второй концепции: последовательные этапы, раскрыт один.
    case serviceStages(ServiceSpec)
    /// Рабочая копия концепции этапов.
    case serviceStagesWork(ServiceSpec)
    /// Матрица «поле × тип оплаты».
    case serviceMatrix
}

struct SandboxItem: Identifiable {
    var id: String
    var title: String
    var subtitle: String?
    var destination: SandboxDestination
}

struct SandboxSection: Identifiable {
    var id: String
    var title: String
    var subtitle: String?
    var symbol: String
    var items: [SandboxItem]
    /// Вложенные папки. Если они есть, раздел показывает сначала их, а не сценарии.
    var childSectionIDs: [String] = []
}

enum SandboxCatalog {
    /// Разделы на первом уровне песочницы.
    static let rootSections: [SandboxSection] = [
        pip, postcards, ideas, morph,
    ]

    /// Полный каталог: нужен маршрутизации, в том числе для вложенных разделов.
    static let sections: [SandboxSection] = [
        pip, transfer, postcards, services, groups, groupsWork, ideas, outcomes, morph,
    ]

    // MARK: ПиП

    /// Платежи и переводы — рабочий контур, собранный в одну папку. Сами
    /// сценарии остаются самостоятельными, чтобы их можно было открывать
    /// напрямую через `-demoOpen transfer/...` и подобные пути.
    static let pip = SandboxSection(
        id: "pip",
        title: "ПиП",
        subtitle: "Переводы, оплаты и исходы операций",
        symbol: "arrow.left.arrow.right.circle",
        items: [],
        childSectionIDs: ["transfer", "services", "groups-work", "groups", "outcome"]
    )

    // MARK: 1. Перевод

    static let transfer = SandboxSection(
        id: "transfer",
        title: "Перевод",
        subtitle: "Один транзакционный экран под все операции",
        symbol: "arrow.left.arrow.right",
        items: TransferModes.all.map { config in
            SandboxItem(
                id: config.id,
                title: config.demoName,
                subtitle: RailMatrix.rails(for: config.operation)
                    .map(\.shortTitle)
                    .joined(separator: " · "),
                destination: .transaction(config)
            )
        }
    )

    // MARK: 2. Открытка к переводу

    /// Механика наклона перенесена из прототипа Brighty (`HolographicCardBlend`).
    /// Голографии здесь нет: остались перспективный наклон и один вытянутый белый
    /// блик в ближней точке.
    static let postcards = SandboxSection(
        id: "postcard",
        title: "Открытка к переводу",
        subtitle: "Наклон карточки, блик и свайп по вариантам",
        symbol: "rectangle.on.rectangle.angled",
        items: [
            SandboxItem(
                id: "picker",
                title: "Выбор открытки",
                subtitle: "Варианты открытки · макет 46432:621671",
                destination: .postcards(PostcardCatalog.all)
            ),
            SandboxItem(
                id: "gift",
                title: "Получение открытки",
                subtitle: "Вылет снизу, оборот, приземление со сквизом",
                destination: .postcardGift(PostcardCatalog.all)
            ),
            SandboxItem(
                id: "gift-envelope",
                title: "Получение открытки · конверт",
                subtitle: "Свайп по ленте, раскрытие клапана, выезд карточки",
                destination: .postcardGiftEnvelope(PostcardCatalog.all)
            ),
        ]
    )

    // MARK: 3. Оплата услуг

    /// Сложные формы. Первый пункт — матрица: она отвечает на вопрос «какие поля
    /// выводятся в каком типе» сразу по всем десяти, и с неё удобно начинать
    /// разговор. Дальше сами формы, вживую.
    static let services = SandboxSection(
        id: "services",
        title: "Оплата услуг",
        subtitle: "Сложные формы: одна вёрстка на десять типов",
        symbol: "list.bullet.rectangle.portrait",
        items: [
            SandboxItem(
                id: "matrix",
                title: "Матрица полей",
                subtitle: "Что выводится в каком типе оплаты",
                destination: .serviceMatrix
            )
        ] + ServiceCatalog.all.map { spec in
            SandboxItem(
                id: spec.id,
                title: spec.demoName,
                subtitle: "\(spec.allFields.count) полей · \(spec.kind.title.lowercased())",
                destination: .serviceForm(spec)
            )
        }
    )

    // MARK: 4. Оплата услуг — этапы

    /// Вторая концепция того же платежа: последовательные этапы вместо списка
    /// полей. Раскрыт ровно один этап, он занимает экран до низа, следующие не
    /// видны; сумма и оплата — на втором экране (макеты 48052:140411 …
    /// 48142:114753). См. `ServiceStagesScreen` и `ServiceAmountScreen`.
    ///
    /// Первый пункт — ЖКУ Москвы: ради него концепция и собиралась, у него же
    /// есть список начислений. Остальные стоят рядом, чтобы видеть, что этапы не
    /// подогнаны под одну спеку.
    static let groups = SandboxSection(
        id: "groups",
        title: "Оплата услуг · этапы",
        subtitle: "Один этап на экран, сумма и оплата — вторым экраном",
        symbol: "square.stack.3d.up",
        // Рабочий сценарий не привязан к ЖКУ: тот же конструктор обязан
        // собирать все типы оплат из единой `ServiceSpec`.
        items: ServiceCatalog.all.map { spec in
            SandboxItem(
                id: spec.id,
                title: spec.demoName,
                subtitle: "\(spec.allFields.count) полей"
                    + (spec.bills.isEmpty ? "" : " · \(spec.bills.count) начислений")
                    + (spec.resolvedProvider == nil ? "" : " · получателя ищем по БИК"),
                destination: .serviceStages(spec)
            )
        }
    )

    /// Изолированная точка для итераций над концепцией этапов. Базовый раздел
    /// `groups` остаётся рядом для сравнения с утверждённой версией.
    static let groupsWork = SandboxSection(
        id: "groups-work",
        title: "Оплата услуг · этапы · в работе",
        subtitle: "Рабочая копия для изменений",
        symbol: "wrench.and.screwdriver",
        // Рабочий сценарий не привязан к ЖКУ: тот же конструктор собирает
        // каждый тип оплаты из единой `ServiceSpec`.
        items: ServiceCatalog.all.map { spec in
            SandboxItem(
                id: spec.id + "-work",
                title: spec.demoName,
                subtitle: "\(spec.allFields.count) полей"
                    + (spec.bills.isEmpty ? "" : " · \(spec.bills.count) начислений")
                    + (spec.resolvedProvider == nil ? "" : " · получателя ищем по БИК"),
                destination: .serviceStagesWork(spec)
            )
        }
    )

    // MARK: 5. Идеи

    /// Предложения на проверку — отдельно от рабочих сценариев. В основные экраны
    /// попадает только то, что подтверждено картой; идею сначала показывают здесь.
    static let ideas = SandboxSection(
        id: "ideas",
        title: "Идеи",
        subtitle: "Предложения на проверку, вне основных сценариев",
        symbol: "lightbulb",
        items: ServiceIdeas.all.map { spec in
            SandboxItem(
                id: spec.id,
                title: spec.demoName,
                subtitle: "На основе «\(spec.provider.title)»",
                destination: .serviceForm(spec)
            )
        }
    )

    // MARK: 6. Экран успеха

    /// Три кадра собраны по макетам 925:207394, 927:207898 и 927:207846: сумма,
    /// комиссия, получатель и комментарий взяты оттуда, поэтому у каждого пункта
    /// свой `override`, а не общий конфиг перевода.
    ///
    /// Каждый исход даёт две строки: кадр из макета и его копия v2 с живым
    /// свечением. Копия, а не переключатель внутри одного экрана, — чтобы на
    /// показе открыть два экрана подряд и сравнить их вживую; так же сделан
    /// «живой фон» в разделе «Перевод».
    static let outcomes = SandboxSection(
        id: "outcome",
        title: "Экран успеха",
        subtitle: "Три исхода операции, у каждого копия с живым свечением",
        symbol: "checkmark.circle",
        items: [success, processing, declined].flatMap(rows(for:))
    )

    /// Строки одного исхода: макетная и её копия v2 на шейдере.
    private static func rows(for scenario: OutcomeScenario) -> [SandboxItem] {
        var ember = scenario
        ember.id += "-v2"
        ember.demoName += " · v2"
        ember.glowStyle = .ember

        return [
            SandboxItem(
                id: scenario.id,
                title: scenario.demoName,
                subtitle: scenario.outcome.title,
                destination: .outcome(scenario)
            ),
            SandboxItem(
                id: ember.id,
                title: ember.demoName,
                subtitle: "\(ember.outcome.title) · живое свечение",
                destination: .outcome(ember)
            ),
        ]
    }

    private static let success = OutcomeScenario(
        id: "success",
        demoName: "Лоадер → успех",
        outcome: .success,
        source: TransferModes.byPhone,
        amount: demoAmount,
        badge: demoFee
    )

    private static let processing = OutcomeScenario(
        id: "processing",
        demoName: "Лоадер → в обработке",
        outcome: .processing,
        source: TransferModes.byPhone,
        amount: demoAmount,
        badge: demoFee,
        override: SuccessConfig(
            title: TransactionOutcome.processing.title,
            subtitle: "Со счёта ··1321",
            // 24/Stroke/drillService на подложке --mo-bg-blue.
            icon: .squircle(
                "icDrillService",
                logo: CGSize(width: 26.099, height: 22.857),
                background: WBColor.tileServiceBlue,
                offset: CGSize(width: 0.67, height: 0)
            ),
            counterparty: "Татьяна Л.",
            chip: "За кофе и хорошее настроение"
        )
    )

    /// Комиссии нет: списания не было.
    private static let declined = OutcomeScenario(
        id: "declined",
        demoName: "Лоадер → отказано",
        outcome: .declined,
        source: TransferModes.byPhone,
        amount: demoAmount,
        override: SuccessConfig(
            title: TransactionOutcome.declined.title,
            subtitle: "Со счёта ··1321",
            icon: .squircle(
                "icGreenLogo",
                logo: CGSize(width: 35.2, height: 36),
                background: WBColor.tileBankGreen
            ),
            counterparty: "Татьяна Л.",
            chip: nil
        )
    )

    private static let demoAmount = Decimal(string: "3457.20")!
    private static let demoFee = BadgeSpec(
        text: "Комиссия 3,74\(Money.nbsp)₽",
        style: .greenSoft,
        isUppercase: true
    )

    // MARK: 7. Морф иконок

    static let morph = SandboxSection(
        id: "morph",
        title: "Морф иконок",
        subtitle: "Переходы статусов и эффекты символов",
        symbol: "wand.and.sparkles",
        items: [
            SandboxItem(
                id: "icons",
                title: "Демонстрация морфа",
                subtitle: "Статус операции, эффекты, морф формы",
                destination: .iconMorph
            )
        ]
    )

    /// Разбор пути вида `transfer/by-phone` для launch-аргумента `-demoOpen`.
    static func item(at path: String) -> (section: SandboxSection, item: SandboxItem)? {
        let parts = path.split(separator: "/").map(String.init)
        guard let sectionID = parts.first,
              let section = sections.first(where: { $0.id == sectionID })
        else { return nil }
        if parts.count == 1, let first = section.items.first {
            return (section, first)
        }
        guard let item = section.items.first(where: { $0.id == parts[1] }) else { return nil }
        return (section, item)
    }
}
