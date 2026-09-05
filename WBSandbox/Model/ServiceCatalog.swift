import SwiftUI

// Десять сложных типов оплаты. Ни строчки вёрстки: только схема полей, правило
// суммы и то, что ответит провайдер. Экран собирается из этого автоматически —
// в этом и смысл конструктора: новый провайдер = новая спека, а не новый экран.
//
// Список типов — рабочий, из задачи: свободные реквизиты, УИН, Мосэнергосбыт со
// счётчиками, ЕИРЦ Москвы, интернет в один шаг, интернет с балансом, парковки,
// «Тройка» и два тяжёлых региональных ЖКУ.
//
// ОТКУДА ПОЛЯ. Каждое поле должно находиться в PAYMENTS.md — иначе оно выдумано,
// а выдуманное поле в прототипе дороже отсутствующего: его начинают обсуждать как
// требование. Сверка по разделам карты:
//
//   · 4.2 ЖКХ — ЕЛС (ГИС ЖКХ) или л/с, адрес и период, развилка «ЕПД или
//     отдельные услуги», состав услуг, показания счётчиков, пени, добровольное
//     страхование;
//   · 4.3 Госплатежи — УИН, КБК, ОКТМО, получатель, оплата за третье лицо,
//     скидка и дедлайн у ГИБДД;
//   · 4.5 Интернет и ТВ — провайдер, логин или номер договора, онлайн-баланс л/с;
//   · 4.7 Транспорт — номер транспортной карты, парковочный счёт, госномер;
//   · 4.8 Другие — платёж по свободным реквизитам: ИНН, БИК, р/с, назначение;
//   · 4.1 п.8 — сохраняемые реквизиты и саджесты (чипы под полем);
//   · 3.7–3.8 — автоплатёж, напоминания, уведомления о новом начислении.
//
// Что удалено как выдумка после сверки: «квитанция/чек на почту» (в карте
// документы живут на экране результата, 3.7, а не полем формы), СНИЛС и оплата
// парковочной сессии с зоной и длительностью. КПП оставлен только в ветках, где
// он прямо входит в сценарий перевода по реквизитам из утверждённого макета.
//
// Три допущения оставлены осознанно и помечены на месте: ФИО плательщика в
// бюджетном платеже, город в парковках и выбор управляющей компании в
// региональном ЖКУ. Без них соответствующий платёж не собирается вообще.

enum ServiceCatalog {
    static let all: [ServiceSpec] = [
        requisitesIndividual,
        requisitesLegal,
        requisitesBudget,
        uin,
        mosenergo,
        eirc,
        zhkuMoscow,
        internetOneStep,
        internetBalance,
        parking,
        troika,
        utilitiesTatarstan,
        utilitiesBashkiria,
    ]

    static func spec(id: String) -> ServiceSpec? {
        all.first { $0.id == id }
    }

    // MARK: - Иконки провайдеров

    /// Настоящих логотипов в проекте нет — ставим системные знаки на подложке
    /// категории. Подложка не декоративная: цвет закреплён за категорией, поэтому
    /// шапка узнаётся раньше, чем прочитан заголовок.
    private static func icon(_ symbol: String, _ color: UInt32) -> RowIcon {
        .symbol(name: symbol, tint: .white, background: Color(hex: color))
    }

    private static let colorUtility: UInt32 = 0x0F9D58
    private static let colorBudget: UInt32 = 0x2F6FED
    private static let colorTelecom: UInt32 = 0x7B3FE4
    private static let colorTransport: UInt32 = 0xE5352B

    private static let requisitesBankOptions = [
        BankOption("sber", "ПАО Сбербанк", bic: "044525225"),
        BankOption("alfa", "АО «АЛЬФА-БАНК»", bic: "044525593"),
        BankOption("tbank", "АО «Т-БАНК»", bic: "044525974"),
        BankOption("vtb", "Филиал №7701 Банка ВТБ (ПАО)", bic: "044525187"),
    ]

    private static func requisitesSection(
        accountHint: String,
        accountSuggestion: String
    ) -> FormSection {
        FormSection(
            id: "bank",
            title: nil,
            fields: [
                FormField(
                    id: "account",
                    label: "Номер счёта",
                    kind: .input(.account),
                    facet: .bankRequisites,
                    hint: accountHint,
                    suggestions: [accountSuggestion]
                ),
                FormField(
                    id: "bank",
                    label: "БИК или название",
                    kind: .input(.text(1...120)),
                    facet: .bankRequisites,
                    hint: "Найдите по названию или БИК",
                    bankOptions: requisitesBankOptions
                ),
            ]
        )
    }

    private static func requisitesAttributes() -> CategoryAttributes {
        CategoryAttributes(
            onlineCheck: "есть — после проверки счёта и банка",
            cashback: "исключён",
            savedRequisites: "счета и банки из недавних, назначение из истории",
            balance: "нет"
        )
    }

    // MARK: - Платежи по реквизитам

    /// Это три представления ответа проверки реквизитов. В реальном продукте
    /// ветку и данные шапки присылает бэкенд после пары «счёт + банк»; клиент не
    /// делает вывод о владельце счёта по его цифрам.
    static let requisitesIndividual = ServiceSpec(
        id: "requisites-individual",
        demoName: "По реквизитам · физлицу",
        category: "Переводы по реквизитам",
        kind: .stepwise,
        provider: ProviderCard(
            title: "Перевод по реквизитам",
            subtitle: "Введите счёт и выберите банк",
            icon: icon("doc.text.fill", colorBudget), inn: "—",
            timing: "Зачислится в течение нескольких минут"
        ),
        notice: nil,
        sections: [
            requisitesSection(
                accountHint: "20 цифр, обычно начинается с 40817",
                accountSuggestion: "40817810538000073965"
            ),
            FormSection(id: "recipient", title: "Получатель", fields: [
                FormField(id: "recipient-self", label: "Перевести себе", kind: .toggle(), facet: .payerInfo, isRequired: false, hint: "На ваш счёт в этом банке", attachesTo: "recipient-name"),
                FormField(id: "recipient-name", label: "ФИО получателя", kind: .input(.text(3...120)), facet: .payeeName, suggestions: ["Борисов Леонид Сергеевич"]),
                FormField(id: "purpose", label: "Назначение платежа", kind: .input(.text(0...210)), facet: .purpose, isRequired: false, hint: "Не больше 210 символов", prefill: "Оплата услуг"),
            ]),
        ],
        amount: .free(min: 10, max: 1_000_000), fee: .rate(Decimal(string: "0.005")!),
        lookup: nil, attributes: requisitesAttributes(),
        resolvedProvider: ProviderCard(title: "Физическому лицу", subtitle: "", icon: icon("person.fill", 0xF0C400), inn: "—", timing: "Зачислится в течение нескольких минут"),
        resolvesAfter: "bank", resolvesWithAccountAndBank: true, usesGroupedRequisites: true
    )

    static let requisitesLegal = ServiceSpec(
        id: "requisites-legal",
        demoName: "По реквизитам · юрлицу",
        category: "Переводы по реквизитам",
        kind: .stepwise,
        provider: ProviderCard(title: "Перевод по реквизитам", subtitle: "Введите счёт и выберите банк", icon: icon("doc.text.fill", colorBudget), inn: "—", timing: "Зачислится в течение 1–3 рабочих дней"),
        notice: nil,
        sections: [
            requisitesSection(
                accountHint: "20 цифр, обычно начинается с 40702",
                accountSuggestion: "40702810438000123456"
            ),
            FormSection(id: "recipient", title: "Получатель", fields: [
                FormField(id: "recipient-inn", label: "ИНН получателя", kind: .input(.inn), facet: .payeeName, hint: "Укажите 000000, если у получателя нет ИНН", suggestions: ["7727282640"]),
                FormField(id: "recipient-name", label: "Получатель", kind: .input(.text(3...160)), facet: .payeeName),
                FormField(id: "recipient-kpp", label: "КПП", kind: .input(.digits(9...9)), facet: .budgetRequisites, isRequired: false),
                FormField(id: "vat", label: "НДС", kind: .choice([
                    ChoiceOption("no-vat", "Не облагается"),
                    ChoiceOption("included", "Включён"),
                ]), facet: .purpose),
                FormField(id: "purpose", label: "Назначение платежа", kind: .input(.text(0...210)), facet: .purpose, isRequired: false, hint: "Не больше 210 символов", prefill: "Оплата за основное образование, первый семестр 2026"),
            ]),
        ],
        amount: .free(min: 10, max: 1_000_000), fee: .rate(Decimal(string: "0.005")!),
        lookup: nil, attributes: requisitesAttributes(),
        resolvedProvider: ProviderCard(title: "Юридическому лицу", subtitle: "", icon: icon("building.2.fill", 0x213CC9), inn: "—", timing: "Зачислится в течение 1–3 рабочих дней"),
        resolvesAfter: "bank", resolvesWithAccountAndBank: true, usesGroupedRequisites: true
    )

    /// Самая насыщенная ветка. Сначала сверяем пару счёт+банк, затем постепенно
    /// уточняем получателя и плательщика; экран не превращается в белое полотно.
    static let requisitesBudget = ServiceSpec(
        id: "requisites-budget",
        demoName: "По реквизитам · в бюджет",
        category: "Госплатежи",
        kind: .stepwise,
        provider: ProviderCard(
            title: "По реквизитам",
            subtitle: "Введите счёт и выберите банк",
            icon: .logo(
                "icFileText24",
                size: CGSize(width: 0.45, height: 0.55),
                background: Color(hex: 0xF0FAFF),
                radius: 0.3,
                offset: .zero
            ),
            inn: "—",
            timing: "Деньги могут зачисляться до 2 часов"
        ),
        notice: nil,
        sections: [
            requisitesSection(
                accountHint: "20 цифр из реквизитов ведомства",
                accountSuggestion: "03224643450000007300"
            ),
            FormSection(id: "recipient", title: "Получатель", fields: [
                FormField(id: "recipient-inn", label: "ИНН получателя", kind: .input(.inn), facet: .budgetRequisites, hint: "ИНН организации содержит 10 цифр, ИП — 12. Он указан в квитанции рядом с реквизитами получателя.", suggestions: ["7730160480", "7730160488"]),
                FormField(id: "recipient-name", label: "Получатель перевода", kind: .input(.text(3...160)), facet: .payeeName, hint: "Полное наименование находится в блоке «Получатель» платёжного документа.", suggestions: ["ГБОУ ОБРАЗОВАТЕЛЬНЫЙ ЦЕНТР «ПРОТОН»"]),
                FormField(id: "recipient-kpp", label: "КПП получателя", kind: .input(.digits(9...9)), facet: .budgetRequisites, isRequired: false, hint: "КПП состоит из 9 цифр и указан рядом с ИНН. У ИП КПП может отсутствовать.", suggestions: ["773001001"]),
                FormField(id: "kbk", label: "КБК", kind: .input(.digits(20...20)), facet: .budgetRequisites, hint: "КБК содержит 20 цифр и находится в блоке бюджетных реквизитов квитанции.", suggestions: ["07500000000013111042"]),
            ]),
            FormSection(id: "payer", title: "Плательщик", fields: [
                FormField(id: "payment-for", label: "Платите", kind: .choice([
                    ChoiceOption("self", "За себя"), ChoiceOption("third-party", "За третье лицо"),
                ]), facet: .thirdParty),
                // При платеже за себя эти данные приходят из профиля. На форме
                // их не спрашиваем повторно — человек сверяет их на «Все данные».
                FormField(id: "payer-name", label: "ФИО плательщика", kind: .info("Иванов Иван Петрович"), facet: .payerInfo),
                FormField(id: "payer-identifier-type", label: "Тип идентификатора", kind: .info("ИНН"), facet: .payerInfo),
                FormField(id: "payer-identifier", label: "Номер идентификатора", kind: .info("381466623088"), facet: .payerInfo),
                FormField(id: "payer-status", label: "Статус плательщика", kind: .info("24 — физическое лицо"), facet: .payerInfo),
            ]),
            FormSection(id: "payment", title: "Платёж", fields: [
                FormField(id: "uin", label: "Код УИН", kind: .input(.uin), facet: .budgetRequisites, hint: "УИН содержит 20 или 25 цифр. Если в квитанции его нет, оставьте 0.", prefill: "0"),
                FormField(id: "oktmo", label: "ОКТМО", kind: .input(.oktmo), facet: .budgetRequisites, hint: "ОКТМО содержит 8 или 11 цифр и указан в бюджетных реквизитах квитанции.", suggestions: ["45328000"]),
                FormField(id: "purpose", label: "Назначение платежа", kind: .input(.text(0...210)), facet: .purpose, isRequired: false, hint: "Опишите основание платежа. Максимум 210 символов.", prefill: "свид.о рожд. рф:ххххх11000. оплата за Ванина Ивана (лс сд000000023242) февраль.2026"),
            ]),
        ],
        amount: .free(min: 10, max: 1_000_000, suggestions: [1000]), fee: .fixed(100),
        lookup: nil, attributes: requisitesAttributes(),
        resolvedProvider: ProviderCard(
            title: "Государству",
            subtitle: "",
            icon: .logo(
                "icEagleRus",
                size: CGSize(width: 0.6, height: 0.6),
                background: Color(hex: 0x00A6E3),
                radius: 0.3,
                offset: .zero
            ),
            inn: "—",
            timing: "Деньги могут зачисляться до 2 часов"
        ),
        resolvesAfter: "bank", resolvesWithAccountAndBank: true, usesGroupedRequisites: true
    )

    // MARK: - 1. Свободные реквизиты

    /// Карта, 4.8 п.6: «Другое» — платёж по свободным реквизитам. Тип получателя
    /// больше не спрашиваем первым вопросом: сначала человек вводит счёт и
    /// выбирает банк, затем ответ проверки открывает ровно нужную ветку.
    static let freeRequisites = ServiceSpec(
        id: "free-requisites",
        demoName: "Свободные реквизиты",
        category: "Переводы по реквизитам",
        kind: .stepwise,
        provider: ProviderCard(
            title: "Перевод по реквизитам",
            subtitle: "Найдём получателя по реквизитам",
            icon: icon("doc.text.fill", colorBudget),
            inn: "—",
            timing: "Зачислится в течение 1–3 рабочих дней"
        ),
        notice: nil,
        sections: [
            FormSection(
                id: "bank",
                title: nil,
                fields: [
                    FormField(
                        id: "account",
                        label: "Счёт получателя",
                        kind: .input(.account),
                        facet: .bankRequisites,
                        hint: "20 цифр из счёта или договора",
                        suggestions: ["40702810400000012345"]
                    ),
                    FormField(
                        id: "bank",
                        label: "Банк получателя",
                        kind: .input(.text(1...120)),
                        facet: .bankRequisites,
                        hint: "Найдите по названию или БИК",
                        bankOptions: [
                            BankOption("sber", "СберБанк", bic: "044525225"),
                            BankOption("vtb", "ВТБ", bic: "044525187"),
                            BankOption("tbank", "Т-Банк", bic: "044525974"),
                        ]
                    ),
                ]
            ),
            FormSection(
                id: "recipient",
                title: nil,
                fields: [
                    FormField(
                        id: "legal-recipient",
                        label: "Получатель",
                        kind: .info("ООО «Вектор»"),
                        facet: .payeeName,
                        reveal: Reveal("recipient-kind", equals: "legal")
                    ),
                    FormField(
                        id: "individual-recipient",
                        label: "Получатель",
                        kind: .info("Анна Петрова"),
                        facet: .payeeName,
                        reveal: Reveal("recipient-kind", equals: "individual")
                    ),
                    FormField(
                        id: "zhku-recipient",
                        label: "Получатель",
                        kind: .info("ЖКУ Москвы · ПАО Сбербанк"),
                        facet: .payeeName,
                        reveal: Reveal("recipient-kind", equals: "zhku")
                    ),
                    FormField(
                        id: "payee-inn",
                        label: "ИНН получателя",
                        kind: .input(.inn),
                        facet: .payeeName,
                        isRequired: false,
                        hint: "Если проверка не вернула ИНН",
                        reveal: Reveal("recipient-kind", equals: "legal")
                    ),
                    FormField(
                        id: "payer-code",
                        label: "Код плательщика",
                        kind: .input(.digits(10...10)),
                        facet: .identifier,
                        hint: "10 цифр в правом верхнем углу ЕПД",
                        suggestions: ["8412034567"],
                        reveal: Reveal("recipient-kind", equals: "zhku"),
                        triggersLookup: true
                    ),
                    FormField(
                        id: "period",
                        label: "Период оплаты",
                        kind: .input(.month),
                        facet: .period,
                        reveal: Reveal(ServiceStages.billFieldID, equals: ServiceStages.customBillID)
                    ),
                ]
            ),
            FormSection(
                id: "purpose",
                title: "За что",
                fields: [
                    FormField(
                        id: "purpose",
                        label: "Назначение платежа",
                        kind: .input(.text(5...210)),
                        facet: .purpose,
                        hint: "Номер договора или счёта — так платёж быстрее найдут",
                        reveal: Reveal("recipient-kind")
                    ),
                ]
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "third-party",
                        label: "Плачу за другого человека",
                        kind: .toggle(),
                        facet: .thirdParty,
                        isRequired: false,
                        hint: "Понадобятся его ФИО и ИНН"
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .free(min: 10, max: 1_000_000, suggestions: []),
        fee: .rate(Decimal(string: "0.005")!),
        lookup: nil,
        attributes: CategoryAttributes(
            onlineCheck: "есть — после проверки счёта и банка",
            cashback: "исключён",
            savedRequisites: "счета и банки из недавних, назначение из истории",
            balance: "нет"
        ),
        recipientResolver: RecipientResolver(
            accountFieldID: "account",
            bankFieldID: "bank",
            resultFieldID: "recipient-kind",
            recipients: [
                // Сначала частный случай: тот же счёт, что в демонстрации ЖКУ,
                // должен открыть оплату услуги, а не общий перевод юрлицу.
                ResolvedRecipient(
                    id: "zhku",
                    provider: ProviderCard(
                        title: "ЖКУ Москвы",
                        subtitle: "Единый платёжный документ",
                        icon: .brandedAsset("icZhkuMoscow", tint: Color(hex: 0xA8002C)),
                        inn: "7702813545",
                        timing: "Зачислим за 1–2 рабочих дня"
                    ),
                    bankID: "sber",
                    accountSuffix: "12345"
                ),
                ResolvedRecipient(
                    id: "individual",
                    provider: ProviderCard(
                        title: "Анна Петрова",
                        subtitle: "Перевод физическому лицу",
                        icon: icon("person.fill", 0xA65AF2),
                        inn: "—",
                        timing: "Зачислится в течение нескольких минут"
                    ),
                    accountPrefix: "408"
                ),
                ResolvedRecipient(
                    id: "legal",
                    provider: ProviderCard(
                        title: "ООО «Вектор»",
                        subtitle: "Перевод юридическому лицу",
                        icon: icon("building.2.fill", colorUtility),
                        inn: "7702813545",
                        timing: "Зачислится в течение 1–3 рабочих дней"
                    ),
                    accountPrefix: "407"
                ),
            ]
        ),
        bills: zhkuMoscow.bills
    )

    // MARK: - 2. Оплата по УИН

    /// Карта, 4.3: оплата по УИН, оплата за третье лицо, у ГИБДД — скидка и
    /// дедлайн. Один реквизит на входе, всё остальное приходит от провайдера.
    /// Частичная оплата запрещена (4.1 п.7): бюджет принимает начисление целиком.
    ///
    /// ФИО плательщика в карте не названо — допущение: бюджетный платёж без
    /// плательщика не уходит.
    static let uin = ServiceSpec(
        id: "uin",
        demoName: "Оплата по УИН",
        category: "Госплатежи",
        kind: .upfront,
        provider: ProviderCard(
            title: "Платёж по УИН",
            subtitle: "Штрафы, налоги, пошлины",
            icon: icon("building.columns.fill", colorBudget),
            inn: "7727406020",
            timing: "Ведомство увидит платёж в течение 1 рабочего дня"
        ),
        notice: nil,
        sections: [
            FormSection(
                id: "main",
                title: nil,
                fields: [
                    FormField(
                        id: "uin",
                        label: "УИН",
                        kind: .input(.uin),
                        facet: .identifier,
                        hint: "20 или 25 цифр из квитанции, строка «Индекс документа»",
                        suggestions: [demoUIN],
                        triggersLookup: true
                    ),
                ]
            ),
            FormSection(
                id: "payer",
                title: "Плательщик",
                fields: [
                    FormField(
                        id: "payer-name",
                        label: "ФИО плательщика",
                        kind: .input(.text(3...80)),
                        facet: .payerInfo,
                        prefill: "Борисов Леонид Игоревич"
                    ),
                ]
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "third-party",
                        label: "Плачу за другого человека",
                        kind: .toggle(),
                        facet: .thirdParty,
                        isRequired: false
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .fromCharge(partial: false),
        fee: .free,
        lookup: .charge(
            ChargeInfo(
                amount: 3000,
                period: "Постановление от 12.07.2026",
                details: [
                    ("Получатель", "УФК по г. Москве (ГИБДД)"),
                    ("Нарушение", "Превышение скорости на 21–40 км/ч"),
                    ("Автомобиль", "А 123 ВС 777"),
                    ("Скидка 50 % до", "26.07.2026"),
                ],
                balance: nil,
                penalty: nil
            )
        ),
        attributes: CategoryAttributes(
            onlineCheck: "есть — начисление приходит по УИН",
            cashback: "исключён (госплатежи)",
            savedRequisites: "ФИО из профиля",
            balance: "нет"
        )
    )

    /// Демо-УИН с честным контрольным разрядом — иначе собственная валидация
    /// экрана ругалась бы на подсказку, которую сама и предлагает.
    static let demoUIN = UIN.complete("1881045631080261437")

    // MARK: - 3. Мосэнергосбыт + счётчики

    /// Карта, 4.2: л/с, период оплаты, показания счётчиков «передавать /
    /// пропустить». Автоплатёж и уведомление о новом начислении — из 3.7–3.8.
    static let mosenergo = ServiceSpec(
        id: "mosenergo",
        demoName: "Мосэнергосбыт + счётчики",
        category: "ЖКХ · электроэнергия",
        kind: .upfront,
        provider: ProviderCard(
            title: "Мосэнергосбыт",
            subtitle: "Электроэнергия, Москва",
            icon: icon("bolt.fill", colorUtility),
            inn: "7736520080",
            timing: "Зачислим за 1 рабочий день"
        ),
        notice: nil,
        sections: [
            FormSection(
                id: "main",
                title: nil,
                fields: [
                    FormField(
                        id: "account",
                        label: "Лицевой счёт",
                        kind: .input(.digits(10...10)),
                        facet: .identifier,
                        hint: "10 цифр, в квитанции слева сверху",
                        suggestions: ["8412034567"],
                        triggersLookup: true
                    ),
                    FormField(
                        id: "period",
                        label: "Период оплаты",
                        kind: .choice([
                            ChoiceOption("2026-08", "Август 2026"),
                            ChoiceOption("2026-07", "Июль 2026"),
                            ChoiceOption("2026-06", "Июнь 2026"),
                        ]),
                        facet: .period,
                        prefill: "2026-08"
                    ),
                ]
            ),
            FormSection(
                id: "meters",
                title: "Показания счётчиков",
                fields: [
                    FormField(
                        id: "meters",
                        label: "Показания",
                        kind: .meters([
                            MeterSpec(id: "t1", title: "День (Т1)", previous: "14 205", unit: "кВт·ч",
                                     history: ["14 205", "13 980", "13 720"]),
                            MeterSpec(id: "t2", title: "Ночь (Т2)", previous: "8 940", unit: "кВт·ч",
                                     history: ["8 940", "8 810", "8 655"]),
                        ]),
                        facet: .meters,
                        isRequired: false
                    ),
                ],
                reveal: Reveal("account"),
                footnote: "Можно оплатить и без показаний — их примут до 25 числа"
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "autopay",
                        label: "Автоплатёж по счёту",
                        kind: .toggle(),
                        facet: .autopay,
                        isRequired: false,
                        hint: "Оплатим сами, когда придёт начисление"
                    ),
                    FormField(
                        id: "notify",
                        label: "Сообщать о новых начислениях",
                        kind: .toggle(),
                        facet: .notify,
                        isRequired: false
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .fromCharge(partial: true),
        fee: .rate(Decimal(string: "0.000935")!),
        lookup: .charge(
            ChargeInfo(
                amount: Decimal(string: "3418.60")!,
                period: "за август 2026",
                details: [
                    ("Плательщик", "Борисов Л. И."),
                    ("Адрес", "Москва, Ленинский пр-т, 42, кв. 118"),
                ],
                balance: Decimal(string: "-3418.60")!,
                penalty: nil
            )
        ),
        attributes: CategoryAttributes(
            onlineCheck: "есть — начисление и баланс по л/с",
            cashback: "начисляется",
            savedRequisites: "л/с из недавних, адрес из начисления",
            balance: "есть"
        )
    )

    // MARK: - 4. ЕИРЦ Москвы

    /// Карта, 4.2 целиком: развилка «единая квитанция (ЕПД) или отдельные услуги»,
    /// состав услуг, показания счётчиков, пени, добровольное страхование.
    ///
    /// Самый тяжёлый случай: единый платёжный документ — это список услуг, у
    /// каждой своя сумма. Отдельного экрана «выбор услуг» не нужно: строки живут в
    /// форме, а итог пересчитывается на каждом тумблере.
    static let eirc = ServiceSpec(
        id: "eirc",
        demoName: "ЕИРЦ Москвы",
        category: "ЖКХ · единый документ",
        kind: .upfront,
        provider: ProviderCard(
            title: "ЕИРЦ Москвы",
            subtitle: "Единый платёжный документ",
            icon: icon("building.2.fill", colorUtility),
            inn: "7702813545",
            timing: "Зачислим за 1–2 рабочих дня"
        ),
        notice: nil,
        sections: [
            FormSection(
                id: "main",
                title: nil,
                fields: [
                    FormField(
                        id: "payer-code",
                        label: "Код плательщика",
                        kind: .input(.digits(10...10)),
                        facet: .identifier,
                        hint: "10 цифр, в правом верхнем углу ЕПД",
                        suggestions: ["7701234567"],
                        triggersLookup: true
                    ),
                    FormField(
                        id: "period",
                        label: "Период оплаты",
                        kind: .choice([
                            ChoiceOption("2026-08", "Август 2026"),
                            ChoiceOption("2026-07", "Июль 2026"),
                        ]),
                        facet: .period,
                        prefill: "2026-08"
                    ),
                    FormField(
                        id: "mode",
                        label: "Что оплачиваем",
                        kind: .choice([
                            ChoiceOption("epd", "Весь ЕПД"),
                            ChoiceOption("services", "Отдельные услуги"),
                        ]),
                        facet: .services,
                        prefill: "epd"
                    ),
                ]
            ),
            FormSection(
                id: "services",
                title: "Состав документа",
                fields: [
                    FormField(
                        id: "lines",
                        label: "Что входит в платёж",
                        kind: .services([
                            ServiceLine(id: "maintenance", title: "Содержание и ремонт", amount: Decimal(string: "2140.18")!, isLocked: true),
                            ServiceLine(id: "heating", title: "Отопление", amount: Decimal(string: "1876.40")!),
                            ServiceLine(id: "hot", title: "Горячая вода", amount: Decimal(string: "612.35")!),
                            ServiceLine(id: "cold", title: "Холодная вода и стоки", amount: Decimal(string: "398.72")!),
                            ServiceLine(id: "trash", title: "Вывоз мусора", amount: Decimal(string: "184.90")!),
                            ServiceLine(id: "intercom", title: "Домофон", amount: Decimal(string: "96.00")!),
                        ]),
                        facet: .services,
                        // Условие нужно и на поле, а не только на секции: как
                        // компаньон оно рисуется на шаге развилки и обязано
                        // подчиняться тому же условию, что и секция.
                        reveal: Reveal("mode", equals: "services"),
                        attachesTo: "mode"
                    ),
                ],
                reveal: Reveal("mode", equals: "services")
            ),
            FormSection(
                id: "meters",
                title: "Показания счётчиков",
                fields: [
                    FormField(
                        id: "meters",
                        label: "Показания",
                        kind: .meters([
                            MeterSpec(id: "cold", title: "Холодная вода", previous: "412", unit: "м³",
                                     history: ["412", "405", "397"]),
                            MeterSpec(id: "hot", title: "Горячая вода", previous: "298", unit: "м³",
                                     history: ["298", "291", "284"]),
                        ]),
                        facet: .meters,
                        isRequired: false
                    ),
                ],
                reveal: Reveal("payer-code")
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "penalty",
                        label: "Оплатить пени",
                        kind: .toggle(price: Decimal(string: "145.20")!),
                        facet: .penalty,
                        isRequired: false,
                        hint: "Начислены за просрочку в июне"
                    ),
                    FormField(
                        id: "insurance",
                        label: "Добровольное страхование",
                        kind: .toggle(price: Decimal(string: "96.00")!),
                        facet: .insurance,
                        isRequired: false,
                        hint: "Строка в ЕПД, от неё можно отказаться"
                    ),
                    FormField(
                        id: "autopay",
                        label: "Автоплатёж по ЕПД",
                        kind: .toggle(),
                        facet: .autopay,
                        isRequired: false
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .fromServices,
        fee: .rate(Decimal(string: "0.000935")!),
        lookup: .charge(
            ChargeInfo(
                amount: Decimal(string: "5308.55")!,
                period: "ЕПД за август 2026",
                details: [
                    ("Плательщик", "Борисов Л. И."),
                    ("Адрес", "Москва, ул. Тверская, 12, кв. 45"),
                ],
                balance: nil,
                penalty: Decimal(string: "145.20")!
            )
        ),
        attributes: CategoryAttributes(
            onlineCheck: "есть — приходит весь состав ЕПД",
            cashback: "начисляется",
            savedRequisites: "код плательщика, адрес, состав услуг прошлого месяца",
            balance: "есть"
        )
    )

    // MARK: - 5. ЖКУ Москвы

    /// Оплата ЖКУ в Москве. Поля — из 4.2: код плательщика (он же л/с), пени,
    /// добровольное страхование. Документ оплачивается целиком.
    ///
    /// Ни периода, ни показаний счётчиков здесь нет. Период не спрашиваем: он
    /// приходит вместе с начислением — «Обычный ЕПД за август 2026», — и это одна
    /// сущность, а не два вопроса. Показания в этом сценарии банк не принимает:
    /// их сдают в mos.ru и ГИС ЖКХ, а не платёжкой. Счётчики остались там, где они
    /// настоящие, — у Мосэнергосбыта.
    ///
    /// Здесь было поле «Номер квартиры» — убрано. Оно из флоу mos.ru, где начисление
    /// ищут по паре «код плательщика + квартира». Банк ходит через расчётный центр и
    /// находит начисление по одному коду, поэтому квартиры нет ни в одном другом
    /// банке. В карте её тоже нет — то есть это было допущение, выданное за
    /// требование.
    ///
    /// Настоящая пара реквизитов в карте есть, но в другом месте: 4.3, поиск штрафов
    /// ГИБДД по «СТС + номер». Если нужно проверить, что конструктор держит пару, —
    /// правильное место там, а не здесь.
    ///
    /// Чем отличается от «ЕИРЦ Москвы»: там разбор состава ЕПД по услугам, здесь
    /// оплата документа целиком. Если это один и тот же поставщик, спеки стоит слить.
    ///
    /// Длина кода и дедлайн показаний — из общего знания о mos.ru, не из карты. ИНН
    /// не ставлю: выдумывать реквизит, который человек сверяет с квитанцией, нельзя.
    static let zhkuMoscow = ServiceSpec(
        id: "zhku-moscow",
        demoName: "ЖКУ Москвы",
        category: "ЖКХ · Москва",
        kind: .upfront,
        provider: ProviderCard(
            title: "ЖКУ Москвы",
            subtitle: "Единый платёжный документ",
            icon: .brandedAsset("icZhkuMoscow", tint: Color(hex: 0xA8002C)),
            inn: "—",
            timing: "Зачислим за 1–2 рабочих дня",
            brandColors: [WBColor.brandCrimsonTop, WBColor.brandCrimsonBottom]
        ),
        notice: nil,
        sections: [
            FormSection(
                id: "main",
                title: nil,
                fields: [
                    FormField(
                        id: "payer-code",
                        label: "Код плательщика",
                        kind: .input(.digits(10...10)),
                        facet: .identifier,
                        hint: "10 цифр в правом верхнем углу ЕПД",
                        suggestions: ["8412034567"],
                        triggersLookup: true
                    ),
                    // Период спрашиваем только у произвольной суммы: у выставленного
                    // счёта период уже в нём самом («Обычный ЕПД за март 2026»).
                    FormField(
                        id: "period",
                        label: "Период оплаты",
                        kind: .input(.month),
                        facet: .period,
                        hint: "За какой месяц платим",
                        suggestions: ["06.2026", "07.2026", "08.2026"],
                        reveal: Reveal(ServiceStages.billFieldID, equals: ServiceStages.customBillID)
                    ),
                ]
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "penalty",
                        label: "Оплатить пени",
                        kind: .toggle(price: Decimal(string: "84.10")!),
                        facet: .penalty,
                        isRequired: false
                    ),
                    FormField(
                        id: "autopay",
                        label: "Напомнить о переводе",
                        kind: .toggle(),
                        facet: .notify,
                        isRequired: false,
                        hint: "Напомним, когда придёт новый ЕПД"
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .fromCharge(partial: true),
        fee: .rate(Decimal(string: "0.000935")!),
        lookup: .charge(
            ChargeInfo(
                amount: Decimal(string: "10253.38")!,
                period: "ЕПД за март 2026",
                details: [
                    ("Плательщик", "Борисов Л. И."),
                    ("Адрес", "Москва, Профсоюзная, 84, кв. 216"),
                ],
                balance: Decimal(string: "-142750.13")!,
                penalty: nil
            )
        ),
        attributes: CategoryAttributes(
            onlineCheck: "есть — список начислений по коду плательщика",
            cashback: "начисляется",
            savedRequisites: "код плательщика из прошлого платежа",
            balance: "есть"
        ),
        // Шесть начислений из макета: обычные и долговые ЕПД за разные месяцы.
        // Их сумма — то, что предлагается оплатить целиком.
        bills: [
            ChargeBill(id: "2026-03", title: "Обычный ЕПД", period: "март 2026",
                       issuedAt: "5 марта 2026", amount: Decimal(string: "10253.38")!),
            ChargeBill(id: "2026-04", title: "Обычный ЕПД", period: "апрель 2026",
                       issuedAt: "5 апреля 2026", amount: Decimal(string: "21357.84")!),
            ChargeBill(id: "2026-05-debt", title: "Долговой ЕПД", period: "май 2026",
                       issuedAt: "5 мая 2026", amount: Decimal(string: "35782.66")!),
            ChargeBill(id: "2026-05", title: "Обычный ЕПД", period: "май 2026",
                       issuedAt: "5 мая 2026", amount: Decimal(string: "35782.66")!),
            ChargeBill(id: "2026-06-debt", title: "Долговой ЕПД", period: "июнь 2026",
                       issuedAt: "5 июня 2026", amount: Decimal(string: "30712.52")!),
            ChargeBill(id: "2026-06", title: "Обычный ЕПД", period: "июнь 2026",
                       issuedAt: "5 июня 2026", amount: Decimal(string: "8861.07")!),
        ]
    )

    // MARK: - 5.1 ЖКУ Москвы по реквизитам

    /// Тот же платёж, но поставщик заранее неизвестен: человек пришёл с квитанцией,
    /// в которой есть только БИК и счёт. Сначала реквизиты банка, потом — кто по
    /// ним нашёлся, и лишь после этого лицевой счёт и начисления.
    ///
    /// Для концепции с этапами это главный сценарий на проверку: шапка экрана
    /// сначала нейтральная («по реквизитам»), а когда счёт введён — на её месте
    /// появляется найденный поставщик, с «i» и карандашом для правки.
    static let zhkuRequisites = ServiceSpec(
        id: "zhku-requisites",
        demoName: "ЖКУ Москвы по реквизитам",
        category: "ЖКХ · Москва",
        kind: .stepwise,
        provider: ProviderCard(
            title: "Оплата по реквизитам",
            subtitle: "Найдём получателя по БИК и счёту",
            icon: icon("doc.text.fill", 0x6E7079),
            inn: "—",
            timing: "Зачислим за 1–2 рабочих дня"
        ),
        notice: nil,
        sections: [
            FormSection(
                id: "bank",
                title: nil,
                fields: [
                    FormField(
                        id: "bic",
                        label: "БИК банка получателя",
                        kind: .input(.bic),
                        facet: .bankRequisites,
                        hint: "9 цифр, в квитанции рядом со счётом",
                        suggestions: ["044525225"]
                    ),
                    FormField(
                        id: "account",
                        label: "Счёт получателя",
                        kind: .input(.account),
                        facet: .bankRequisites,
                        hint: "20 цифр расчётного счёта",
                        suggestions: ["40702810400000012345"],
                        reveal: Reveal("bic")
                    ),
                    // Кого нашли по реквизитам. Строка, а не вопрос: выбирать здесь
                    // нечего, а поправить БИК можно карандашом в шапке.
                    FormField(
                        id: "bank-found",
                        label: "Получатель",
                        kind: .info("ЖКУ Москвы · ПАО Сбербанк"),
                        facet: .payeeName,
                        reveal: Reveal("account")
                    ),
                    FormField(
                        id: "payer-code",
                        label: "Код плательщика",
                        kind: .input(.digits(10...10)),
                        facet: .identifier,
                        hint: "10 цифр в правом верхнем углу ЕПД",
                        suggestions: ["8412034567"],
                        reveal: Reveal("account"),
                        triggersLookup: true
                    ),
                    FormField(
                        id: "period",
                        label: "Период оплаты",
                        kind: .input(.month),
                        facet: .period,
                        hint: "За какой месяц платим",
                        suggestions: ["06.2026", "07.2026", "08.2026"],
                        reveal: Reveal(ServiceStages.billFieldID, equals: ServiceStages.customBillID)
                    ),
                ]
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "autopay",
                        label: "Напомнить о переводе",
                        kind: .toggle(),
                        facet: .notify,
                        isRequired: false,
                        hint: "Напомним, когда придёт новый ЕПД"
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .fromCharge(partial: true),
        fee: .rate(Decimal(string: "0.000935")!),
        lookup: .charge(
            ChargeInfo(
                amount: Decimal(string: "10253.38")!,
                period: "ЕПД за март 2026",
                details: [("Плательщик", "Борисов Л. И.")],
                balance: nil,
                penalty: nil
            )
        ),
        attributes: CategoryAttributes(
            onlineCheck: "есть — после разбора реквизитов",
            cashback: "начисляется",
            savedRequisites: "БИК, счёт и код плательщика",
            balance: "нет"
        ),
        resolvedProvider: ProviderCard(
            title: "ЖКУ Москвы",
            subtitle: "Единый платёжный документ",
            icon: icon("building.2.fill", colorUtility),
            inn: "7702813545",
            timing: "Зачислим за 1–2 рабочих дня",
            brandColors: [WBColor.brandCrimsonTop, WBColor.brandCrimsonBottom]
        ),
        resolvesAfter: "account",
        bills: zhkuMoscow.bills
    )

    // MARK: - 5.2 ЖКУ · длинная форма

    /// Нарочно перегруженная спека: двенадцать этапов плюс тумблеры. Нужна не как
    /// сценарий, а как проверка концепции с этапами на масштаб — по ней видно, что
    /// происходит, когда пройденных этапов больше, чем строк влезает на экран.
    static let zhkuLong = ServiceSpec(
        id: "zhku-long",
        demoName: "ЖКУ · длинная форма",
        category: "ЖКХ · регионы",
        kind: .stepwise,
        provider: ProviderCard(
            title: "Расчётный центр",
            subtitle: "Двенадцать этапов подряд",
            icon: icon("building.2.fill", 0x2F6FED),
            inn: "7712345678",
            timing: "Зачислим за 1–2 рабочих дня",
            brandColors: [Color(hex: 0x2F6FED), Color(hex: 0x142C63)]
        ),
        notice: nil,
        sections: [
            FormSection(
                id: "where",
                title: nil,
                fields: [
                    FormField(
                        id: "region",
                        label: "Регион",
                        kind: .choice([
                            ChoiceOption("msk", "Москва"),
                            ChoiceOption("mo", "Московская область"),
                            ChoiceOption("spb", "Санкт-Петербург"),
                        ]),
                        facet: .geo
                    ),
                    FormField(
                        id: "city",
                        label: "Город",
                        kind: .choice([
                            ChoiceOption("msk", "Москва"),
                            ChoiceOption("zelenograd", "Зеленоград"),
                            ChoiceOption("troitsk", "Троицк"),
                            ChoiceOption("shcherbinka", "Щербинка"),
                        ]),
                        facet: .geo,
                        reveal: Reveal("region")
                    ),
                    FormField(
                        id: "company",
                        label: "Управляющая компания",
                        kind: .choice([
                            ChoiceOption("gbu", "ГБУ «Жилищник»", "Профсоюзная, 84"),
                            ChoiceOption("uk1", "УК «Юг-Сервис»", "Обручева, 12"),
                            ChoiceOption("tsj", "ТСЖ «Наш дом»", "Ленинский, 105"),
                        ]),
                        facet: .provider,
                        reveal: Reveal("city")
                    ),
                    FormField(
                        id: "account",
                        label: "Лицевой счёт",
                        kind: .input(.digits(10...10)),
                        facet: .identifier,
                        hint: "10 цифр в квитанции",
                        suggestions: ["7712345678"],
                        reveal: Reveal("company"),
                        triggersLookup: true
                    ),
                    FormField(
                        id: "period",
                        label: "Период оплаты",
                        kind: .input(.month),
                        facet: .period,
                        hint: "За какой месяц платим",
                        suggestions: ["07.2026", "08.2026"],
                        reveal: Reveal(ServiceStages.billFieldID, equals: ServiceStages.customBillID)
                    ),
                ]
            ),
            FormSection(
                id: "meters",
                title: "Показания счётчиков",
                fields: [
                    FormField(
                        id: "meters",
                        label: "Показания",
                        kind: .meters([
                            MeterSpec(id: "cold", title: "Холодная вода", previous: "204", unit: "м³",
                                      history: ["204", "197", "191"]),
                            MeterSpec(id: "hot", title: "Горячая вода", previous: "158", unit: "м³",
                                      history: ["158", "152", "147"]),
                            MeterSpec(id: "power", title: "Электричество", previous: "18420", unit: "кВт·ч",
                                      history: ["18420", "18180", "17960"]),
                        ]),
                        facet: .meters,
                        isRequired: false
                    ),
                ],
                reveal: Reveal("account"),
                footnote: "Показания примут до 25 числа"
            ),
            FormSection(
                id: "services",
                title: "Состав платёжного документа",
                fields: [
                    FormField(
                        id: "services",
                        label: "Что оплачиваем",
                        kind: .services([
                            ServiceLine(id: "maintenance", title: "Содержание и ремонт",
                                        amount: Decimal(string: "2840.15")!, isLocked: true),
                            ServiceLine(id: "heating", title: "Отопление",
                                        amount: Decimal(string: "1980.40")!),
                            ServiceLine(id: "water", title: "Водоснабжение",
                                        amount: Decimal(string: "760.22")!),
                            ServiceLine(id: "power", title: "Электроэнергия",
                                        amount: Decimal(string: "1120.90")!),
                            ServiceLine(id: "waste", title: "Вывоз мусора",
                                        amount: Decimal(string: "310.55")!),
                        ]),
                        facet: .services
                    ),
                ],
                reveal: Reveal("account")
            ),
            FormSection(
                id: "payer",
                title: "Плательщик",
                fields: [
                    FormField(
                        id: "payer-name",
                        label: "ФИО плательщика",
                        kind: .input(.text(4...80)),
                        facet: .payerInfo,
                        hint: "Как в квитанции",
                        reveal: Reveal("account")
                    ),
                    FormField(
                        id: "payer-address",
                        label: "Адрес",
                        kind: .input(.text(6...120)),
                        facet: .payerInfo,
                        hint: "Улица, дом, квартира",
                        suggestions: ["Москва, Профсоюзная, 84, кв. 216"],
                        reveal: Reveal("payer-name")
                    ),
                    FormField(
                        id: "payer-phone",
                        label: "Телефон для связи",
                        kind: .input(.phone),
                        facet: .payerInfo,
                        isRequired: false,
                        reveal: Reveal("payer-address")
                    ),
                    FormField(
                        id: "receipt-email",
                        label: "Квитанция на почту",
                        kind: .input(.email),
                        facet: .receipt,
                        isRequired: false,
                        hint: "Пришлём чек и квитанцию",
                        reveal: Reveal("payer-address")
                    ),
                    FormField(
                        id: "purpose",
                        label: "Назначение платежа",
                        kind: .input(.text(4...140)),
                        facet: .purpose,
                        isRequired: false,
                        hint: "Что писать в платёжке",
                        reveal: Reveal("payer-address")
                    ),
                ]
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "penalty",
                        label: "Оплатить пени",
                        kind: .toggle(price: Decimal(string: "84.10")!),
                        facet: .penalty,
                        isRequired: false
                    ),
                    FormField(
                        id: "insurance",
                        label: "Добровольное страхование",
                        kind: .toggle(price: Decimal(string: "119.00")!),
                        facet: .insurance,
                        isRequired: false,
                        hint: "Строка в ЕПД, от неё можно отказаться"
                    ),
                    FormField(
                        id: "autopay",
                        label: "Автоплатёж по ЕПД",
                        kind: .toggle(),
                        facet: .autopay,
                        isRequired: false
                    ),
                    FormField(
                        id: "notify",
                        label: "Напомнить о переводе",
                        kind: .toggle(),
                        facet: .notify,
                        isRequired: false,
                        hint: "Напомним, когда придёт новый ЕПД"
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .fromServices,
        fee: .rate(Decimal(string: "0.000935")!),
        lookup: .charge(
            ChargeInfo(
                amount: Decimal(string: "7012.22")!,
                period: "ЕПД за август 2026",
                details: [
                    ("Плательщик", "Борисов Л. И."),
                    ("Адрес", "Москва, Профсоюзная, 84, кв. 216"),
                ],
                balance: Decimal(string: "-7012.22")!,
                penalty: Decimal(string: "84.10")!
            )
        ),
        attributes: CategoryAttributes(
            onlineCheck: "есть — по лицевому счёту",
            cashback: "начисляется",
            savedRequisites: "регион, город, УК и лицевой счёт",
            balance: "есть"
        ),
        bills: [
            ChargeBill(id: "2026-07", title: "Обычный ЕПД", period: "июль 2026",
                       amount: Decimal(string: "6841.03")!),
            ChargeBill(id: "2026-08", title: "Обычный ЕПД", period: "август 2026",
                       amount: Decimal(string: "7012.22")!),
            ChargeBill(id: "2026-08-debt", title: "Долговой ЕПД", period: "август 2026",
                       amount: Decimal(string: "12480.71")!),
        ]
    )

    // MARK: - 6. Интернет в один шаг

    /// Карта, 4.5: провайдер, логин или номер договора. Онлайн-проверки у этого
    /// провайдера нет — значит сумма произвольная, и её нужно подсказать
    /// саджестами (4.1 п.8), иначе человек вводит наугад.
    static let internetOneStep = ServiceSpec(
        id: "internet-1step",
        demoName: "Интернет 1 шаг",
        category: "Интернет и ТВ",
        kind: .upfront,
        provider: ProviderCard(
            title: "Дом.ру",
            subtitle: "Интернет и ТВ",
            icon: icon("wifi", colorTelecom),
            inn: "5902202276",
            timing: "Зачислим за несколько минут"
        ),
        notice: nil,
        sections: [
            FormSection(
                id: "main",
                title: nil,
                fields: [
                    FormField(
                        id: "login",
                        label: "Логин или номер договора",
                        kind: .input(.digits(6...12)),
                        facet: .identifier,
                        hint: "Из договора или из личного кабинета",
                        suggestions: ["4409211", "4409865"]
                    ),
                ]
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "autopay",
                        label: "Платить каждый месяц",
                        kind: .toggle(),
                        facet: .autopay,
                        isRequired: false,
                        hint: "Та же сумма в тот же день"
                    ),
                    FormField(
                        id: "notify",
                        label: "Напоминать об оплате",
                        kind: .toggle(),
                        facet: .notify,
                        isRequired: false
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .free(min: 50, max: 15000, suggestions: [650, 1300, 1950]),
        fee: .free,
        lookup: nil,
        attributes: CategoryAttributes(
            onlineCheck: "нет — сумму вводит человек",
            cashback: "начисляется",
            savedRequisites: "логин из недавних, сумма прошлого платежа",
            balance: "нет"
        )
    )

    // MARK: - 7. Интернет с балансом

    /// Тот же интернет, но провайдер отдаёт онлайн-баланс лицевого счёта (4.5
    /// п.2). Из-за этого меняется вся логика суммы: не «сколько хотите», а
    /// «сколько нужно, чтобы не отключили».
    static let internetBalance = ServiceSpec(
        id: "internet-balance",
        demoName: "Интернет с балансом",
        category: "Интернет и ТВ",
        kind: .upfront,
        provider: ProviderCard(
            title: "Ростелеком",
            subtitle: "Интернет, ТВ, домашний телефон",
            icon: icon("antenna.radiowaves.left.and.right", colorTelecom),
            inn: "7707049388",
            timing: "Зачислим за несколько минут"
        ),
        notice: nil,
        sections: [
            FormSection(
                id: "main",
                title: nil,
                fields: [
                    FormField(
                        id: "account",
                        label: "Номер лицевого счёта",
                        kind: .input(.digits(12...12)),
                        facet: .identifier,
                        hint: "12 цифр из квитанции или личного кабинета",
                        suggestions: ["770123456789"],
                        triggersLookup: true
                    ),
                ]
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "autopay-threshold",
                        label: "Пополнять при балансе ниже 100 ₽",
                        kind: .toggle(),
                        facet: .autopay,
                        isRequired: false,
                        hint: "Спишем ту же сумму, что сейчас"
                    ),
                    FormField(
                        id: "notify",
                        label: "Сообщать о низком балансе",
                        kind: .toggle(),
                        facet: .notify,
                        isRequired: false
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .free(min: 50, max: 15000, suggestions: [540, 1080, 1620]),
        fee: .free,
        lookup: .charge(
            ChargeInfo(
                amount: 540,
                period: "к оплате до 05.09.2026",
                // Тариф в карте (4.5) не назван — в начислении оставляем только
                // то, что она перечисляет: сумму, период, ФИО и баланс.
                details: [
                    ("Абонент", "Борисов Л. И."),
                ],
                balance: -540,
                penalty: nil
            )
        ),
        attributes: CategoryAttributes(
            onlineCheck: "есть — отдаёт баланс лицевого счёта",
            cashback: "начисляется",
            savedRequisites: "л/с из недавних, сумма из тарифа",
            balance: "есть, показываем со знаком"
        )
    )

    // MARK: - 8. Парковки России

    /// Карта, 4.7 п.2: парковки — парковочный счёт и госномер. Оба идентификатора
    /// есть в карте, поэтому развилка между ними честная.
    ///
    /// Город в карте не назван — допущение: без города неизвестен оператор
    /// парковок, а «Парковки России» это про разные города. Оплаты сессии с зоной
    /// и длительностью в карте нет — убрано как выдумка.
    static let parking = ServiceSpec(
        id: "parking",
        demoName: "Парковки России",
        category: "Транспорт",
        kind: .stepwise,
        provider: ProviderCard(
            title: "Городские парковки",
            subtitle: "Парковочный счёт",
            icon: icon("car.fill", colorTransport),
            inn: "7714887870",
            timing: "Зачислим за 1–2 минуты"
        ),
        notice: "Оператор парковок приходит от города — поля появятся по мере ввода",
        sections: [
            FormSection(
                id: "main",
                title: nil,
                fields: [
                    FormField(
                        id: "city",
                        label: "Город",
                        kind: .choice([
                            ChoiceOption("msk", "Москва", "АМПП"),
                            ChoiceOption("spb", "Санкт-Петербург", "Городской центр парковок"),
                            ChoiceOption("kzn", "Казань", "Городские парковки"),
                            ChoiceOption("sochi", "Сочи", "Парковочное пространство"),
                            ChoiceOption("ekb", "Екатеринбург", "Городские парковки"),
                        ]),
                        facet: .geo
                    ),
                    FormField(
                        id: "mode",
                        label: "По какому реквизиту",
                        kind: .choice([
                            ChoiceOption("account", "Парковочный счёт"),
                            ChoiceOption("plate", "Госномер"),
                        ]),
                        facet: .payeeType,
                        reveal: Reveal("city")
                    ),
                    FormField(
                        id: "parking-account",
                        label: "Номер парковочного счёта",
                        kind: .input(.digits(10...10)),
                        facet: .identifier,
                        hint: "Из приложения «Парковки»",
                        suggestions: ["7712345678"],
                        reveal: Reveal("mode", equals: "account")
                    ),
                    FormField(
                        id: "plate",
                        label: "Госномер",
                        kind: .input(.plate),
                        facet: .identifier,
                        hint: "Латиницей или кириллицей — приведём сами",
                        suggestions: ["А123ВС777"],
                        reveal: Reveal("mode", equals: "plate")
                    ),
                ]
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "save-plate",
                        label: "Запомнить реквизит",
                        kind: .toggle(),
                        facet: .payerInfo,
                        isRequired: false,
                        hint: "В следующий раз подставим сами"
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .free(min: 40, max: 15000, suggestions: [100, 300, 600]),
        fee: .free,
        lookup: nil,
        attributes: CategoryAttributes(
            onlineCheck: "проверить — город отвечает не всегда",
            cashback: "начисляется",
            savedRequisites: "госномер и счёт из профиля",
            balance: "есть у парковочного счёта"
        )
    )

    // MARK: - 9. Тройка

    /// Карта, 4.7 п.1: транспортные карты («Тройка» и аналоги) — номер карты.
    /// Автопополнение по порогу баланса — из 3.7.
    static let troika = ServiceSpec(
        id: "troika",
        demoName: "Тройка",
        category: "Транспорт",
        kind: .upfront,
        provider: ProviderCard(
            title: "Тройка",
            subtitle: "Транспортная карта Москвы",
            icon: icon("tram.fill", colorTransport),
            inn: "7702619233",
            timing: "Запишется на карту в метро или в приложении"
        ),
        notice: nil,
        sections: [
            FormSection(
                id: "main",
                title: nil,
                fields: [
                    FormField(
                        id: "card",
                        label: "Номер карты «Тройка»",
                        kind: .input(.digits(10...10)),
                        facet: .identifier,
                        hint: "10 цифр под штрих-кодом на обороте",
                        suggestions: ["1234567890"],
                        triggersLookup: true
                    ),
                ]
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "autopay-threshold",
                        label: "Пополнять при балансе ниже 100 ₽",
                        kind: .toggle(),
                        facet: .autopay,
                        isRequired: false
                    ),
                    FormField(
                        id: "save-card",
                        label: "Запомнить карту",
                        kind: .toggle(),
                        facet: .payerInfo,
                        isRequired: false
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .free(min: 30, max: 5000, suggestions: [250, 500, 1000]),
        fee: .free,
        lookup: .charge(
            ChargeInfo(
                amount: 500,
                period: "пополнение кошелька",
                // Из карты (3.2) начисление отдаёт сумму, период и баланс —
                // остальное про «Тройку» было бы придумано.
                details: [],
                balance: 120,
                penalty: nil
            )
        ),
        attributes: CategoryAttributes(
            onlineCheck: "есть — отдаёт баланс кошелька",
            cashback: "начисляется",
            savedRequisites: "номер карты из профиля",
            balance: "есть"
        )
    )

    // MARK: - 10. ЖКУ Татарстан

    /// Тяжёлое региональное ЖКУ. Поля — из 4.2: л/с, период, показания, пени,
    /// добровольное страхование. Тип провайдера — не динамический (карта 2.2):
    /// следующий атрибут приходит только после предыдущего.
    ///
    /// Район и управляющая компания в карте не названы — допущение: в регионах без
    /// них не найти лицевой счёт. ФИО плательщика — тоже допущение.
    static let utilitiesTatarstan = ServiceSpec(
        id: "zhku-tatarstan",
        demoName: "ЖКУ Татарстан",
        category: "ЖКХ · регионы",
        kind: .stepwise,
        provider: ProviderCard(
            title: "ЖКУ Республики Татарстан",
            subtitle: "Единый расчётный центр",
            icon: icon("house.fill", colorUtility),
            inn: "1655065057",
            timing: "Зачислим за 1–3 рабочих дня"
        ),
        notice: "Управляющая компания и состав услуг приходят от расчётного центра",
        sections: [
            FormSection(
                id: "geo",
                title: "Где платим",
                fields: [
                    FormField(
                        id: "district",
                        label: "Город или район",
                        kind: .choice([
                            ChoiceOption("kazan", "Казань"),
                            ChoiceOption("chelny", "Набережные Челны"),
                            ChoiceOption("almet", "Альметьевск"),
                            ChoiceOption("nk", "Нижнекамск"),
                        ]),
                        facet: .geo
                    ),
                    FormField(
                        id: "company",
                        label: "Управляющая компания",
                        kind: .choice([
                            ChoiceOption("uk-1", "УК «Вахитовская», Казань"),
                            ChoiceOption("uk-2", "УК «Уютный дом»"),
                            ChoiceOption("uk-3", "ТСЖ «Сосновка»"),
                            ChoiceOption("uk-4", "УК «Ремжилстрой»"),
                        ]),
                        facet: .provider,
                        reveal: Reveal("district")
                    ),
                ]
            ),
            FormSection(
                id: "main",
                title: "Лицевой счёт",
                fields: [
                    FormField(
                        id: "account",
                        label: "Лицевой счёт",
                        kind: .input(.digits(12...12)),
                        facet: .identifier,
                        hint: "12 цифр из квитанции управляющей компании",
                        suggestions: ["160512340987"],
                        reveal: Reveal("company"),
                        triggersLookup: true
                    ),
                    FormField(
                        id: "period",
                        label: "Период оплаты",
                        kind: .choice([
                            ChoiceOption("2026-08", "Август 2026"),
                            ChoiceOption("2026-07", "Июль 2026"),
                        ]),
                        facet: .period,
                        prefill: "2026-08"
                    ),
                ]
            ),
            FormSection(
                id: "meters",
                title: "Показания счётчиков",
                fields: [
                    FormField(
                        id: "meters",
                        label: "Показания",
                        kind: .meters([
                            MeterSpec(id: "cold", title: "Холодная вода", previous: "318", unit: "м³",
                                     history: ["318", "309", "301"]),
                            MeterSpec(id: "hot", title: "Горячая вода", previous: "204", unit: "м³",
                                     history: ["204", "198", "193"]),
                            MeterSpec(id: "gas", title: "Газ", previous: "2 940", unit: "м³",
                                     history: ["2 940", "2 905", "2 868"]),
                            MeterSpec(id: "power", title: "Электричество", previous: "18 302", unit: "кВт·ч",
                                     history: ["18 302", "18 050", "17 790"]),
                        ]),
                        facet: .meters,
                        isRequired: false
                    ),
                ],
                reveal: Reveal("account")
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "penalty",
                        label: "Оплатить пени",
                        kind: .toggle(price: Decimal(string: "212.40")!),
                        facet: .penalty,
                        isRequired: false
                    ),
                    FormField(
                        id: "insurance",
                        label: "Добровольное страхование жилья",
                        kind: .toggle(price: Decimal(string: "112.00")!),
                        facet: .insurance,
                        isRequired: false
                    ),
                    FormField(
                        id: "payer-name",
                        label: "ФИО плательщика",
                        kind: .input(.text(3...80)),
                        facet: .payerInfo,
                        isRequired: false,
                        prefill: "Борисов Леонид Игоревич"
                    ),
                    FormField(
                        id: "autopay",
                        label: "Автоплатёж по квитанции",
                        kind: .toggle(),
                        facet: .autopay,
                        isRequired: false
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .fromCharge(partial: true),
        fee: .rate(Decimal(string: "0.008")!),
        lookup: .charge(
            ChargeInfo(
                amount: Decimal(string: "4762.18")!,
                period: "за август 2026",
                details: [
                    ("Плательщик", "Борисов Л. И."),
                    ("Адрес", "Казань, ул. Баумана, 58, кв. 21"),
                    ("Начислено", "4 549,78 ₽ + пени 212,40 ₽"),
                ],
                balance: Decimal(string: "-4762.18")!,
                penalty: Decimal(string: "212.40")!
            )
        ),
        attributes: CategoryAttributes(
            onlineCheck: "проверить — расчётный центр отвечает не всегда",
            cashback: "начисляется",
            savedRequisites: "район, УК и л/с из прошлого платежа",
            balance: "есть"
        )
    )

    // MARK: - 11. ЖКУ Башкортостан

    /// Карта, 4.2 п.1 дословно: «ЕЛС (ГИС ЖКХ) или л/с». Развилка взята оттуда, и
    /// от неё зависит и идентификатор, и то, придёт ли состав услуг.
    static let utilitiesBashkiria = ServiceSpec(
        id: "zhku-bashkiria",
        demoName: "ЖКУ Башкортостан",
        category: "ЖКХ · регионы",
        kind: .stepwise,
        provider: ProviderCard(
            title: "ЖКУ Башкортостана",
            subtitle: "ЕЛС ГИС ЖКХ или счёт УК",
            icon: icon("house.lodge.fill", colorUtility),
            inn: "0275038496",
            timing: "Зачислим за 1–3 рабочих дня"
        ),
        notice: "По ЕЛС состав услуг придёт из ГИС ЖКХ, по счёту УК — только сумма",
        sections: [
            FormSection(
                id: "mode",
                title: "Как платим",
                fields: [
                    FormField(
                        id: "mode",
                        label: "Идентификатор",
                        kind: .choice([
                            ChoiceOption("els", "ЕЛС ГИС ЖКХ"),
                            ChoiceOption("uk", "Счёт УК"),
                        ]),
                        facet: .payeeType,
                        prefill: "els"
                    ),
                    FormField(
                        id: "els",
                        label: "ЕЛС (единый лицевой счёт)",
                        kind: .input(.digits(16...16)),
                        facet: .identifier,
                        hint: "16 цифр, в квитанции или в личном кабинете ГИС ЖКХ",
                        suggestions: ["0212345678901234"],
                        reveal: Reveal("mode", equals: "els"),
                        triggersLookup: true
                    ),
                    FormField(
                        id: "company",
                        label: "Управляющая компания",
                        kind: .choice([
                            ChoiceOption("uk-1", "УЖХ Октябрьского района, Уфа"),
                            ChoiceOption("uk-2", "УК «Сипайлово»"),
                            ChoiceOption("uk-3", "ТСЖ «Зелёная роща»"),
                        ]),
                        facet: .provider,
                        reveal: Reveal("mode", equals: "uk")
                    ),
                    FormField(
                        id: "uk-account",
                        label: "Лицевой счёт УК",
                        kind: .input(.digits(10...10)),
                        facet: .identifier,
                        hint: "10 цифр из квитанции",
                        reveal: Reveal("company")
                    ),
                ]
            ),
            FormSection(
                id: "services",
                title: "Состав из ГИС ЖКХ",
                fields: [
                    FormField(
                        id: "lines",
                        label: "Что входит в платёж",
                        kind: .services([
                            ServiceLine(id: "maintenance", title: "Содержание жилья", amount: Decimal(string: "1642.90")!, isLocked: true),
                            ServiceLine(id: "heating", title: "Отопление", amount: Decimal(string: "2103.55")!),
                            ServiceLine(id: "water", title: "Вода и стоки", amount: Decimal(string: "742.10")!),
                            ServiceLine(id: "gas", title: "Газоснабжение", amount: Decimal(string: "268.40")!),
                            ServiceLine(id: "capital", title: "Взнос на капремонт", amount: Decimal(string: "512.30")!),
                        ]),
                        facet: .services
                    ),
                ],
                reveal: Reveal("els")
            ),
            FormSection(
                id: "meters",
                title: "Показания счётчиков",
                fields: [
                    FormField(
                        id: "meters",
                        label: "Показания",
                        kind: .meters([
                            MeterSpec(id: "cold", title: "Холодная вода", previous: "276", unit: "м³",
                                     history: ["276", "268", "259"]),
                            MeterSpec(id: "hot", title: "Горячая вода", previous: "189", unit: "м³",
                                     history: ["189", "183", "178"]),
                        ]),
                        facet: .meters,
                        isRequired: false
                    ),
                ],
                reveal: Reveal("mode", equals: "els")
            ),
            FormSection(
                id: "extra",
                title: "Дополнительно",
                fields: [
                    FormField(
                        id: "penalty",
                        label: "Оплатить пени",
                        kind: .toggle(price: Decimal(string: "88.60")!),
                        facet: .penalty,
                        isRequired: false
                    ),
                    FormField(
                        id: "autopay",
                        label: "Автоплатёж по квитанции",
                        kind: .toggle(),
                        facet: .autopay,
                        isRequired: false
                    ),
                ],
                isExtras: true
            ),
        ],
        amount: .fromServices,
        fee: .rate(Decimal(string: "0.008")!),
        lookup: .charge(
            ChargeInfo(
                amount: Decimal(string: "5269.25")!,
                period: "за август 2026",
                details: [
                    ("Плательщик", "Борисов Л. И."),
                    ("Адрес", "Уфа, ул. Достоевского, 100, кв. 74"),
                    ("Источник", "ГИС ЖКХ"),
                ],
                balance: nil,
                penalty: Decimal(string: "88.60")!
            )
        ),
        attributes: CategoryAttributes(
            onlineCheck: "есть по ЕЛС, нет по счёту УК",
            cashback: "начисляется",
            savedRequisites: "ЕЛС и УК из прошлого платежа",
            balance: "есть по ЕЛС"
        )
    )
}
