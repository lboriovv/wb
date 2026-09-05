import SwiftUI

/// Сложный платёжный экран: карта всей формы. Один на все типы оплаты — порядок
/// блоков фиксирован, состав приходит из спеки. Ни одного `if spec.id == ...`.
///
/// Здесь ничего не вводят. Экран отвечает на два вопроса: из чего состоит платёж
/// и сколько уже заполнено. Тап по любой строке открывает модальный визард
/// (`ServiceStepSheet`) ровно на этом вопросе, дальше он ведёт по цепочке сам.
/// Закрыть визард можно в любой момент — карта под ним показывает, что уже
/// отвечено.
///
/// Почему ввод унесён в модалку: на форме из пятнадцати полей клавиатура
/// закрывает половину экрана, и человек заполняет поле, не видя ни соседних, ни
/// итога. Разделение честнее — карта показывает целое, модалка спрашивает по
/// одному.
///
/// Порядок блоков повторяет то, как человек отвечает на вопросы:
///   1. кому платим (шапка провайдера — подтверждение, что попал куда хотел);
///   2. по каким реквизитам (карта формы);
///   3. что нашлось у поставщика (ответ провайдера);
///   4. сколько (сумма);
///   5. чем платим (счёт списания);
///   6. итог и кнопка на всю ширину — всегда на виду.
struct ServicePaymentScreen: View {
    @Bindable var model: ServiceFormModel
    var onBack: () -> Void = {}
    /// Открыть спеку этого типа — правая кнопка в шапке.
    var onOpenSpec: () -> Void = {}

    @FocusState private var focus: String?

    private var spec: ServiceSpec { model.spec }

    var body: some View {
        VStack(spacing: 0) {
            WBNavBar(
                title: spec.provider.title,
                subtitle: spec.category,
                onLeading: onBack
            )
            .overlay(alignment: .trailing) {
                Button(action: onOpenSpec) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(WBColor.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(WBColor.bgBase)

            form

            footer
        }
        .background(WBColor.bgMinus1, ignoresSafeAreaEdges: .all)
        .sheet(isPresented: $model.isStepSheetPresented) {
            ServiceStepSheet(model: model)
        }
        .sheet(isPresented: $model.isMethodSheetPresented) { methodSheet }
        .fullScreenCover(isPresented: $model.isOutcomePresented) {
            OutcomeScreen(
                scenario: model.outcomeScenario,
                amount: model.total,
                badge: spec.fee.badge(for: model.subtotal),
                onClose: { model.isOutcomePresented = false }
            )
        }
    }

    // MARK: - Форма

    private var form: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: WBSpace.x3) {
                    ProviderHeader(provider: spec.provider, kind: spec.kind, notice: spec.notice)

                    // Идея, живёт только у спек из раздела «Идеи».
                    if let last = spec.lastPayment, model.lookupState.charge == nil {
                        RepeatPaymentCard(last: last) { model.repeatLastPayment() }
                    }

                    ForEach(model.visibleSections) { section in
                        sectionView(section)
                            .id(section.id)

                        // Ответ провайдера — сразу под секцией, из которой ушёл
                        // запрос, а не в конце формы.
                        if section.id == model.lookupSectionID {
                            LookupStatusView(
                                state: model.lookupState,
                                penaltyField: model.penaltyField,
                                penaltyOn: Binding(
                                    get: { model.penaltyField.map { model.isToggleOn($0.id) } ?? false },
                                    set: { value in
                                        guard let field = model.penaltyField else { return }
                                        model.setToggle(field.id, value)
                                    }
                                )
                            ) {
                                model.retryLookup()
                            }
                        }
                    }

                    AmountBlock(model: model, focus: $focus) {
                        model.openStep(ServiceFormModel.amountStepID)
                    }
                    .id(ServiceFormModel.amountStepID)

                    if let source = model.sourceRow {
                        FormFieldSection(title: "Чем платим") {
                            FormFieldBox {
                                DetailRowView(row: source) {
                                    model.isMethodSheetPresented = true
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, WBSpace.x4)
                .padding(.top, WBSpace.x4)
                .padding(.bottom, WBSpace.x4)
                .animation(.snappy(duration: 0.28), value: model.visibleSections.map(\.id))
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.lookupState.charge?.amount) { _, new in
                // Начисление нашлось — подводим к сумме, чтобы человек увидел, что
                // именно подставилось, и не искал это сам.
                // В режиме съёмки кадров не уводим экран с начала формы.
                guard new != nil, !SandboxSettings.fillsForms else { return }
                withAnimation(.snappy(duration: 0.35)) {
                    proxy.scrollTo("amount", anchor: .center)
                }
            }
            .onChange(of: model.didAttemptSubmit) { _, attempted in
                guard attempted, let invalid = model.firstInvalidField() else { return }
                withAnimation(.snappy(duration: 0.3)) { proxy.scrollTo(invalid, anchor: .center) }
            }
        }
    }

    /// Все секции рисуются одинаково — включая блок дополнительных параметров.
    /// Раньше он был аккордеоном, и это была ошибка: форма выглядела короче, чем
    /// есть, а страхование, автоплатёж и напоминания оказывались спрятанными, хотя
    /// это то, что банк как раз предлагает.
    private func sectionView(_ section: FormSection) -> some View {
        FormFieldSection(title: section.title, footnote: section.footnote) {
            ForEach(model.visibleFields(in: section)) { field in
                fieldView(field)
                    .id(field.id)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func fieldView(_ field: FormField) -> some View {
        let error = model.error(for: field, focused: nil)

        switch field.kind {
        case .input:
            FormValueRow(
                label: field.label,
                value: model.values[field.id].flatMap { $0.isEmpty ? nil : $0 },
                isRequired: field.isRequired,
                error: error
            ) {
                model.openStep(field.id)
            }

        case .choice(let options):
            FormValueRow(
                label: field.label,
                value: options.first { $0.id == model.values[field.id] }?.title,
                isRequired: field.isRequired,
                error: error
            ) {
                model.openStep(field.id)
            }

        // Тумблер — не ввод: ответ на него даётся одним движением, и уводить это
        // движение в модалку значило бы просить два действия вместо одного.
        case .toggle(let price):
            FormToggleRow(
                field: field,
                price: price,
                isOn: Binding(
                    get: { model.isToggleOn(field.id) },
                    set: { model.setToggle(field.id, $0) }
                ),
                isBoxed: true
            )

        case .meters(let meters):
            FormValueRow(
                label: field.label,
                value: metersSummary(field, meters),
                isRequired: field.isRequired
            ) {
                model.openStep(field.id)
            }

        case .services(let lines):
            FormValueRow(
                label: field.label,
                value: servicesSummary(field, lines),
                isRequired: field.isRequired
            ) {
                model.openStep(field.id)
            }

        case .info(let value):
            FormReadOnlyRow(label: field.label, value: value)
        }
    }

    /// «426 · 321» — что уже передали по счётчикам.
    private func metersSummary(_ field: FormField, _ meters: [MeterSpec]) -> String? {
        let values = meters.map { model.meterValue(field.id, $0.id) }.filter { !$0.isEmpty }
        return values.isEmpty ? nil : values.joined(separator: " · ")
    }

    /// «5 из 6 · 5 309 ₽» — сколько услуг выбрано и на сколько.
    private func servicesSummary(_ field: FormField, _ lines: [ServiceLine]) -> String? {
        let on = lines.filter { model.isServiceOn(field.id, $0.id) }
        guard !on.isEmpty else { return nil }
        return "\(on.count) из \(lines.count) · \(Money.rub(model.servicesTotal))"
    }

    private var isCheckingLookup: Bool {
        if case .loading = model.lookupState { return true }
        return false
    }

    // MARK: - Липкий низ

    /// Итог и кнопка не уезжают со скроллом. На форме из пятнадцати полей человек
    /// иначе теряет главное число и не понимает, к чему он всё это заполняет.
    private var footer: some View {
        VStack(spacing: WBSpace.x2) {
            HStack(spacing: WBSpace.x2) {
                Text(model.totalLine.title)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                Spacer(minLength: 0)
                if let value = model.totalLine.value {
                    Text(value)
                        .font(WBFont.bodyAccent)
                        .foregroundStyle(WBColor.textPrimary)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, WBSpace.x4)

            switch model.cta {
            case .primary(let title):
                WBPrimaryButton(title: title) { submit() }
            case .topUp(let missing):
                WBPrimaryButton(
                    title: "Пополнить на",
                    subtitle: Money.rub(missing),
                    fill: WBColor.ctaTopUp
                ) {
                    model.isMethodSheetPresented = true
                }
            }

            // Единственная подпись под кнопкой — срок зачисления. Ни комиссий, ни
            // акций: всё остальное человек читает выше, до того как решится нажать.
            Text(spec.provider.timing)
                .font(WBFont.description)
                .foregroundStyle(WBColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, WBSpace.x3)
        .padding(.bottom, WBSpace.x2)
        .padding(.horizontal, WBSpace.x4)
        .frame(maxWidth: .infinity)
        .background {
            WBColor.bgBase
                .overlay(alignment: .top) {
                    Rectangle().fill(WBColor.separator).frame(height: 1)
                }
        }
        .animation(.snappy(duration: 0.25), value: model.total)
    }

    private func submit() {
        // Незаполненное подсвечиваем на карте и говорим, что оно обязательное.
        // Открывать модалку за человека нельзя: он нажал кнопку оплаты, а не
        // «продолжить заполнение», и подмена действия сбивает.
        if model.firstInvalidField() != nil {
            Haptics.notification(.error)
            return
        }
        model.isOutcomePresented = true
    }

    // MARK: - Шиты

    /// `sheet(item:)` требует Identifiable — оборачиваем id поля.
    /// Выбор счёта списания — тот же шит, что в пошаговом режиме.
    private var methodSheet: some View {
        AccountPickerSheet(
            accounts: model.accounts,
            selectedID: model.selectedAccountID
        ) { id in
            model.selectedAccountID = id
            model.isMethodSheetPresented = false
        }
    }
}

// MARK: - Повторный платёж

/// Прошлый платёж строкой над формой: тап — и реквизит подставлен, начисление
/// запрошено. Пропадает, как только начисление нашлось: дальше человек работает с
/// новым платежом, и напоминание о прошлом только мешает.
struct RepeatPaymentCard: View {
    let last: LastPayment
    let onRepeat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Прошлый платёж — \(last.period)")
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(WBColor.textPrimary)
                Text("Счёт ··\(last.identifier.suffix(4)) · \(Money.rub(last.amount))")
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
            }

            Button {
                Haptics.tap()
                onRepeat()
            } label: {
                Text("Оплатить так же")
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        WBColor.ctaFill,
                        in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(WBSpace.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            WBColor.bgPurpleLight,
            in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
        )
    }
}

// MARK: - Шапка провайдера

/// Блок «куда». Отвечает на единственный вопрос, который человек задаёт себе,
/// открыв форму: «я туда попал?». Поэтому здесь название, ИНН и срок — то, по
/// чему сверяются с квитанцией, а не рекламная плашка.
struct ProviderHeader: View {
    let provider: ProviderCard
    let kind: ProviderKind
    let notice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x3) {
            HStack(spacing: WBSpace.x3) {
                RowIconView(icon: provider.icon, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.title)
                        .font(WBFont.title3Bold)
                        .foregroundStyle(WBColor.textPrimary)
                    Text(provider.subtitle)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                    if provider.inn != "—" {
                        Text("ИНН \(provider.inn)")
                            .font(WBFont.description)
                            .foregroundStyle(WBColor.textSecondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, WBSpace.x4)
            .padding(.top, WBSpace.x4)
            .padding(.bottom, notice == nil ? WBSpace.x4 : 0)

            // Предупреждение не «алерт ради алерта»: оно объясняет, почему поля
            // появляются по одному, — иначе форма кажется сломанной.
            if let notice {
                HStack(alignment: .top, spacing: WBSpace.x2) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WBColor.textSecondary)
                    Text(notice)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WBSpace.x3)
                .background(
                    WBColor.bgMinus1,
                    in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
                )
                .padding(.horizontal, WBSpace.x2)
                .padding(.bottom, WBSpace.x2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            WBColor.bgBase,
            in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
        )
    }
}

// MARK: - Ответ провайдера

/// Четыре исхода онлайн-проверки из карты. Ни один из них не тупик: у каждого
/// есть, что делать дальше, — и это главное требование к блоку. «Ничего не
/// найдено» без выхода означает брошенный платёж.
struct LookupStatusView: View {
    let state: ServiceFormModel.LookupState
    /// Подробности начисления свёрнуты: главное — сумма и период, остальное
    /// (плательщик, адрес, тариф, долг) человек смотрит, только если сверяет с
    /// квитанцией. Шесть строк подряд в самой заметной карточке экрана делали её
    /// тяжелее всего остального.
    @State private var showsDetails = false
    /// Пени приходят вместе с начислением, поэтому и решаются здесь же — рядом с
    /// суммой долга, а не в блоке необязательных параметров через два экрана.
    var penaltyField: FormField?
    var penaltyOn: Binding<Bool> = .constant(false)
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle:
            EmptyView()

        case .loading:
            card(WBColor.bgMinus1) {
                HStack(spacing: WBSpace.x3) {
                    ProgressView().controlSize(.small)
                    Text("Спрашиваем начисление у поставщика")
                        .font(WBFont.body)
                        .foregroundStyle(WBColor.textSecondary)
                    Spacer(minLength: 0)
                }
            }

        case .done(.charge(let info)):
            card(WBColor.okLight) {
                VStack(alignment: .leading, spacing: WBSpace.x2) {
                    HStack(spacing: WBSpace.x2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(WBColor.textAccent)
                        Text(info.displayTitle)
                            .font(WBFont.bodyAccent)
                            .foregroundStyle(WBColor.textPrimary)
                        Spacer(minLength: 0)
                        Button {
                            Haptics.tap()
                            withAnimation(.snappy(duration: 0.25)) { showsDetails.toggle() }
                        } label: {
                            Image(systemName: showsDetails ? "info.circle.fill" : "info.circle")
                                .font(.system(size: 17))
                                .foregroundStyle(WBColor.textAccent)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Сумма — крупным кеглем и сразу здесь. Раньше она стояла
                    // только в конце формы, и человек узнавал, сколько с него
                    // хотят, пройдя все поля: к этому моменту решение платить он
                    // уже принял, не зная цены.
                    Text(Money.rub(info.amount))
                        .font(WBFont.hauss(28, .bold))
                        .foregroundStyle(WBColor.textPrimary)
                        .padding(.bottom, WBSpace.x1)

                    ForEach(Array(info.details.enumerated()), id: \.offset) { _, detail in
                        if showsDetails {
                        HStack(alignment: .top, spacing: WBSpace.x2) {
                            Text(detail.0)
                                .font(WBFont.description)
                                .foregroundStyle(WBColor.textSecondary)
                                .frame(width: 116, alignment: .leading)
                            Text(detail.1)
                                .font(WBFont.description)
                                .foregroundStyle(WBColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        }
                    }

                    if let balance = info.balance, showsDetails {
                        HStack(spacing: WBSpace.x2) {
                            Text(balance < 0 ? "Долг по счёту" : "Баланс счёта")
                                .font(WBFont.description)
                                .foregroundStyle(WBColor.textSecondary)
                                .frame(width: 116, alignment: .leading)
                            Text(Money.rub(abs(balance)))
                                .font(WBFont.descriptionAccent)
                                .foregroundStyle(
                                    balance < 0 ? WBColor.declined : WBColor.textAccent
                                )
                            Spacer(minLength: 0)
                        }
                    }

                    // Пени — часть долга: они уже в сумме, и это состояние, а не
                    // вопрос. Тумблер рядом читался как «платить пени по желанию»;
                    // отказ остался, но стал отдельным решением текстом.
                    if penaltyField != nil, let penalty = info.penalty {
                        Rectangle()
                            .fill(WBColor.textAccent.opacity(0.15))
                            .frame(height: 1)
                            .padding(.vertical, WBSpace.x1)

                        HStack(spacing: WBSpace.x3) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Пени \(Money.rub(penalty))")
                                    .font(WBFont.bodyAccent)
                                    .foregroundStyle(WBColor.textPrimary)
                                Text(
                                    penaltyOn.wrappedValue
                                        ? "Включены в платёж"
                                        : "Не входят в этот платёж"
                                )
                                .font(WBFont.description)
                                .foregroundStyle(WBColor.textSecondary)
                            }
                            Spacer(minLength: WBSpace.x2)
                            Button {
                                Haptics.tap()
                                penaltyOn.wrappedValue.toggle()
                            } label: {
                                Text(penaltyOn.wrappedValue ? "Оплатить без пеней" : "Вернуть пени")
                                    .font(WBFont.descriptionAccent)
                                    .foregroundStyle(WBColor.textAccent)
                                    .multilineTextAlignment(.trailing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

        case .done(.none):
            card(WBColor.bgMinus1) {
                statusRow(
                    symbol: "tray",
                    tint: WBColor.textSecondary,
                    title: "Начислений нет",
                    subtitle: "Можно заплатить любую сумму — она уйдёт на счёт вперёд"
                )
            }

        case .done(.notFound):
            card(WBColor.declinedSoft) {
                VStack(alignment: .leading, spacing: WBSpace.x3) {
                    statusRow(
                        symbol: "exclamationmark.circle.fill",
                        tint: WBColor.declined,
                        title: "Счёт не найден",
                        subtitle: "Проверьте номер или выберите другого поставщика"
                    )
                    Button(action: onRetry) {
                        Text("Проверить снова")
                            .font(WBFont.bodyAccent)
                            .foregroundStyle(WBColor.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }

        case .done(.unavailable):
            card(WBColor.warnLight) {
                VStack(alignment: .leading, spacing: WBSpace.x3) {
                    statusRow(
                        symbol: "clock.arrow.circlepath",
                        tint: WBColor.warn,
                        title: "Поставщик не отвечает",
                        subtitle: "Можно заплатить без проверки — зачислим, когда он ответит"
                    )
                    Button(action: onRetry) {
                        Text("Попробовать ещё раз")
                            .font(WBFont.bodyAccent)
                            .foregroundStyle(WBColor.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func statusRow(
        symbol: String,
        tint: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .top, spacing: WBSpace.x2) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(WBColor.textPrimary)
                Text(subtitle)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func card<Content: View>(
        _ background: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WBSpace.x4)
            .background(
                background,
                in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Сумма

/// Сумма — поле формы, а не отдельный экран. Но поле особое: кегль крупнее всего
/// остального на экране, потому что это единственное число, которое человек
/// перепроверяет перед нажатием.
struct AmountBlock: View {
    @Bindable var model: ServiceFormModel
    var focus: FocusState<String?>.Binding
    /// В визарде заголовок не нужен: вопрос «сколько платим» уже задан крупным
    /// кеглем над блоком, и второй раз он читается как чужая секция.
    var showsTitle: Bool = true
    /// На карте формы сумму не правят на месте — тап открывает визард. В самом
    /// визарде обработчика нет, и поле становится редактируемым.
    var onTap: (() -> Void)?

    private var isEditable: Bool { model.isAmountEditable && onTap == nil }
    private var isEmpty: Bool { model.baseAmount == 0 }

    /// Сумму можно менять только там, где это разрешено правилом: из начисления
    /// без частичной оплаты её не правят вовсе, и блок тогда рисуется серым —
    /// так же, как остальные значения, пришедшие от поставщика.
    private var canChange: Bool { model.isAmountEditable }

    var body: some View {
        FormFieldSection(title: showsTitle ? "Сколько платим" : nil) {
            VStack(alignment: .leading, spacing: WBSpace.x1) {
                FormFieldBox(isEditable: canChange, hasError: model.amountError != nil) {
                    VStack(alignment: .leading, spacing: WBSpace.x1) {
                        HStack(alignment: .firstTextBaseline, spacing: WBSpace.x1_5) {
                            if isEditable {
                                TextField("0", text: Binding(
                                    get: {
                                        model.amount.displayInteger
                                            + (model.amount.displayFraction ?? "")
                                    },
                                    set: { model.setAmount($0) }
                                ))
                                .font(WBFont.title1)
                                .foregroundStyle(WBColor.textPrimary)
                                .keyboardType(.decimalPad)
                                .focused(focus, equals: "amount-field")
                                .fixedSize()
                            } else {
                                Text(Money.grouped(model.baseAmount))
                                    .font(WBFont.title1)
                                    // Ноль — ещё не сумма, а место под неё: чёрным
                                    // он читается как «к оплате ноль рублей».
                                    .foregroundStyle(
                                        isEmpty ? WBColor.controlsTertiary : WBColor.textPrimary
                                    )
                                    .contentTransition(.numericText())
                            }

                            Text("₽")
                                .font(WBFont.title1)
                                .foregroundStyle(
                                    isEmpty ? WBColor.controlsTertiary : WBColor.textPrimary
                                )

                            Spacer(minLength: 0)

                            // Бейдж комиссии от нулевой суммы ничего не сообщает —
                            // ждём, пока появится, от чего считать.
                            if !isEmpty {
                                WBBadgeView(badge: model.spec.fee.badge(for: model.subtotal))
                                    .transition(.opacity)
                            }

                            if canChange, onTap != nil {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(WBColor.textSecondary)
                            }
                        }

                        Text(amountNote)
                            .font(WBFont.description)
                            .foregroundStyle(WBColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, WBSpace.x3)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard canChange else { return }
                    if let onTap {
                        Haptics.tap()
                        onTap()
                    } else {
                        focus.wrappedValue = "amount-field"
                    }
                }

                if let error = model.amountError {
                    Text(error)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.declined)
                        .padding(.horizontal, WBSpace.x4)
                }

                // На карте формы чипов нет: сумму правят в модалке, и там же им
                // место. Два одинаковых набора на двух экранах — лишний выбор.
                if !model.quickAmounts.isEmpty, canChange, onTap == nil {
                    SuggestionChips(
                        values: model.quickAmounts.map { Money.rub($0) },
                        onLightBackground: false
                    ) { picked in
                        guard let index = model.quickAmounts
                            .firstIndex(where: { Money.rub($0) == picked }) else { return }
                        model.applyQuickAmount(model.quickAmounts[index])
                    }
                    .padding(.horizontal, -WBSpace.x4)
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: model.baseAmount)
    }

    /// Одна строка, которая объясняет статус суммы. Правило показываем словами
    /// «можно заплатить часть» вместо «частичная оплата разрешена»: второе — из
    /// таблицы атрибутов, а не из речи человека.
    private var amountNote: String {
        switch model.amountRule {
        case .fromCharge(let partial):
            if let charge = model.lookupState.charge {
                return partial
                    ? "Из начисления \(charge.period). Можно заплатить часть"
                    : "Из начисления \(charge.period). Только полностью"
            }
            return "Появится, когда найдём начисление"
        case .free(let min, let max, _):
            return "От \(Money.rub(min)) до \(Money.rub(max))"
        case .fromServices:
            if model.hasServiceLines { return "Складывается из выбранных услуг" }
            guard let charge = model.lookupState.charge else {
                return "Появится, когда найдём начисление"
            }
            return "Весь документ \(charge.period). Можно платить по услугам"
        }
    }
}
