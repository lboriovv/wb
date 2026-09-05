import SwiftUI

/// Модальный визард: один вопрос поверх карты формы.
///
/// Открывается тапом по строке на `ServicePaymentScreen` — ровно на том вопросе,
/// по которому тапнули, — и дальше ведёт по цепочке сам: ответил на один, приехал
/// следующий. Закрыть можно в любой момент: под модалкой остаётся карта формы, и
/// по ней видно, сколько уже заполнено. Поэтому здесь нет ни сводки ответов, ни
/// прогресса — и то и другое уже есть на экране под ним.
///
/// Почему модалка, а не отдельный экран-режим: заполнение и обзор — две разные
/// задачи. Клавиатура закрывает половину экрана, и пока человек вводит, ему не
/// нужны ни соседние поля, ни итог; а когда он смотрит, из чего состоит платёж,
/// ему не нужна клавиатура.
///
/// Оплаты здесь нет: модалка отвечает за заполнение, платят на карте формы, где
/// видно весь платёж. Единственная кнопка — «Сохранить».
///
/// Навигация — стрелками вверх-вниз, а не кнопкой «Далее». «Далее» обещает, что
/// шаг закончен и назад дороги нет; стрелки честно говорят, что форма — это одна
/// плоскость, по которой ходят в обе стороны. Реквизит фиксированной длины
/// перелистывается сам: просить нажать стрелку после десятой цифры не за что.
struct ServiceStepSheet: View {
    @Bindable var model: ServiceFormModel

    @FocusState private var focus: String?

    private var spec: ServiceSpec { model.spec }
    private var step: FormStep? { model.currentStep }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: WBSpace.x4) {
                        if let step {
                            stepBody(step)
                                .id(step.id)
                                .transition(.opacity)
                        }

                    }
                    .padding(.horizontal, WBSpace.x2)
                    .padding(.top, WBSpace.x3)
                    .padding(.bottom, WBSpace.x4)
                }
                .scrollDismissesKeyboard(.interactively)
                .animation(.snappy(duration: 0.28), value: model.currentStepID)
                .onChange(of: model.currentStepID) { _, id in
                    withAnimation(.snappy(duration: 0.3)) { proxy.scrollTo(id, anchor: .top) }
                    focusCurrentStep()
                }
                .onAppear { focusCurrentStep() }
            }

            footer
        }
        .background(WBColor.bgMinus1)
        .presentationDetents([.large])
        .presentationCornerRadius(WBRadius.x6)
        .sheet(item: choiceBinding) { field in choiceSheet(field) }
        .sheet(isPresented: $model.isMethodSheetPresented) { methodSheet }
    }

    /// Фокус ставим только там, где есть что набирать: приезжающая на шаге выбора
    /// клавиатура закрывает половину вариантов.
    private func focusCurrentStep() {
        guard let step, let field = step.field, case .input = field.kind else {
            focus = nil
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            focus = field.id
        }
    }

    // MARK: - Шапка

    /// Крестик слева, а не «Готово»: модалку закрывают, а не завершают — ответы
    /// уже сохранены, и закрытие ничего не отменяет.
    private var header: some View {
        HStack(spacing: 0) {
            Button {
                Haptics.tap()
                model.leaveStep()
                model.closeStepSheet()
            } label: {
                DSIconView(icon: .close, size: 24)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 1) {
                Text(spec.provider.title)
                    .font(WBFont.navTitle)
                    .foregroundStyle(WBColor.textPrimary)
                    .lineLimit(1)
                Text(model.currentStep?.group ?? spec.category)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            // Симметрия крестику: без пустого места заголовок съезжает влево.
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, WBSpace.x1)
        .padding(.top, WBSpace.x2)
        .padding(.bottom, WBSpace.x2)
        .background(WBColor.bgBase)
    }

    // MARK: - Тело шага

    @ViewBuilder
    private func stepBody(_ step: FormStep) -> some View {
        switch step.content {
        case .amount:
            amountStep
        case .field(let field):
            VStack(alignment: .leading, spacing: WBSpace.x4) {
                StepQuestion(
                    title: field.label,
                    hint: field.hint,
                    isOptional: step.isOptional
                )

                fieldControl(field)

                // Следствие выбора — на том же шаге: выбрал «отдельные услуги» —
                // вот они. Разрывать одно решение на два экрана незачем.
                ForEach(model.companions(of: field)) { companion in
                    fieldControl(companion)
                }

                // Ответ провайдера показываем на том шаге, который его вызвал:
                // связь «ввёл номер — вот что нашлось» иначе теряется.
                if field.triggersLookup {
                    LookupStatusView(
                        state: model.lookupState,
                        penaltyField: model.penaltyField,
                        penaltyOn: penaltyBinding
                    ) {
                        model.retryLookup()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fieldControl(_ field: FormField) -> some View {
        let error = model.error(for: field, focused: focus)

        switch field.kind {
        case .input(let format):
            StepInput(
                field: field,
                format: format,
                value: Binding(
                    get: { model.values[field.id] ?? "" },
                    set: { model.setValue($0, for: field) }
                ),
                focus: $focus,
                error: error,
                isChecking: field.triggersLookup && isCheckingLookup
            )

        case .choice(let options):
            StepChoice(
                options: options,
                selection: model.values[field.id] ?? "",
                onPick: { model.pickChoice($0, for: field) }
            )

        case .toggle(let price):
            FormCard {
                FormToggleRow(
                    field: field,
                    price: price,
                    isOn: Binding(
                        get: { model.isToggleOn(field.id) },
                        set: { model.setToggle(field.id, $0) }
                    )
                )
            }

        case .meters(let meters):
            FormCard {
                FormMetersView(
                    field: field,
                    meters: meters,
                    focus: $focus,
                    value: { model.meterValue(field.id, $0) },
                    onChange: { model.setMeter(field.id, $0, $1) }
                )
            }

        case .services(let lines):
            // Своего итога у шага нет: он уже стоит в нижней панели и меняется на
            // каждом тумблере. Второе число рядом только заставляет их сверять.
            FormCard {
                FormServicesView(
                    field: field,
                    lines: lines,
                    isOn: { model.isServiceOn(field.id, $0) },
                    onToggle: { model.setService(field.id, $0, $1) }
                )
            }

        case .info(let value):
            FormCard {
                FormInfoRow(label: field.label, value: value)
            }
        }
    }

    /// Последний шаг. Здесь же и способ оплаты: «сколько» и «чем» — один вопрос,
    /// разносить их по двум экранам незачем.
    private var amountStep: some View {
        VStack(alignment: .leading, spacing: WBSpace.x4) {
            StepQuestion(title: "Сколько платим", hint: nil, isOptional: false)

            // Карточки начисления здесь нет намеренно: она уже была на том шаге,
            // где вводили реквизит, вместе с решением про пени. Повторять её
            // значит удлинять последний шаг ровно там, где нужно проверить сумму
            // и нажать кнопку.
            AmountBlock(model: model, focus: $focus, showsTitle: false)

            if let source = model.sourceRow {
                FormCard(title: "Чем платим") {
                    DetailRowView(row: source) {
                        model.isMethodSheetPresented = true
                    }
                    .padding(.horizontal, WBSpace.x2)
                }
            }
        }
    }

    private var penaltyBinding: Binding<Bool> {
        Binding(
            get: { model.penaltyField.map { model.isToggleOn($0.id) } ?? false },
            set: { value in
                guard let field = model.penaltyField else { return }
                model.setToggle(field.id, value)
            }
        )
    }

    private var isCheckingLookup: Bool {
        if case .loading = model.lookupState { return true }
        return false
    }

    // MARK: - Низ

    /// В модалке нет и не может быть кнопки оплаты. Модалка — про заполнение;
    /// платят на карте формы, где видно всё сразу. Пока здесь стояло
    /// «Продолжить», оно читалось как «дальше будет ещё шаг», а на последнем
    /// вопросе — как «оплатить», и человек не понимал, что именно он нажимает.
    /// Поэтому одна кнопка: «Сохранить» — она сохраняет ответы и закрывает
    /// модалку. Над ней только переходы по полям, вверх и вниз; «Пропустить» убрано
    /// — необязательный вопрос и так можно оставить пустым, а отдельная кнопка
    /// делала из этого решение, которого никто не просил.
    private var footer: some View {
        VStack(spacing: WBSpace.x3) {
            HStack(spacing: WBSpace.x4) {
                navText("Предыдущий", symbol: "chevron.up", isEnabled: model.canGoBack) {
                    model.leaveStep()
                    model.goBack()
                }

                Spacer(minLength: 0)

                navText("Следующий", symbol: "chevron.down", isEnabled: model.canGoForward) {
                    model.leaveStep()
                    model.goForward()
                }
            }
            .padding(.horizontal, WBSpace.x4)

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

                WBPrimaryButton(title: "Сохранить") {
                    model.leaveStep()
                    model.closeStepSheet()
                }
            }
            .padding(.horizontal, WBSpace.x4)
        }
        .padding(.top, WBSpace.x3)
        .padding(.bottom, WBSpace.x2)
        .frame(maxWidth: .infinity)
        .background {
            WBColor.bgBase
                .overlay(alignment: .top) {
                    Rectangle().fill(WBColor.separator).frame(height: 1)
                }
        }
        .animation(.snappy(duration: 0.25), value: model.currentStepID)
        .animation(.snappy(duration: 0.25), value: model.total)
    }

    /// Навигация текстом со стрелкой. Выключенная не исчезает, а гаснет: пропадающие
    /// элементы заставляют искать, куда делась кнопка.
    private func navText(
        _ title: String,
        symbol: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: WBSpace.x1) {
                if symbol == "chevron.up" {
                    Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                    Text(title).font(WBFont.bodyAccent)
                } else {
                    Text(title).font(WBFont.bodyAccent)
                    Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(isEnabled ? WBColor.textPrimary : WBColor.controlsTertiary)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    // MARK: - Шиты

    private struct ChoiceTarget: Identifiable { var id: String }

    private var choiceBinding: Binding<ChoiceTarget?> {
        Binding(
            get: { model.choiceSheetField.map(ChoiceTarget.init) },
            set: { model.choiceSheetField = $0?.id }
        )
    }

    @ViewBuilder
    private func choiceSheet(_ target: ChoiceTarget) -> some View {
        if let field = spec.allFields.first(where: { $0.id == target.id }),
           case .choice(let options) = field.kind {
            ChoiceSheet(
                title: field.label,
                options: options,
                selection: model.values[field.id] ?? ""
            ) { picked in
                model.pickChoice(picked, for: field)
                model.choiceSheetField = nil
            }
            .presentationDetents([.height(min(88 + CGFloat(options.count) * 57, 620))])
            .presentationCornerRadius(WBRadius.x6)
        }
    }

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

// MARK: - Вопрос шага

/// Заголовок шага — это сам вопрос, а не название поля из таблицы атрибутов.
/// Крупный кегль здесь не украшение: на шаге он единственный ориентир, и по нему
/// человек понимает, что от него хотят, не читая ничего больше.
struct StepQuestion: View {
    let title: String
    var hint: String?
    var isOptional: Bool

    var body: some View {
        // Раздел формы не повторяем: он уже стоит в шапке под названием
        // провайдера, и второй раз читается как заголовок другого блока.
        VStack(alignment: .leading, spacing: WBSpace.x2) {
            HStack(alignment: .firstTextBaseline, spacing: WBSpace.x2) {
                Text(title)
                    .font(WBFont.hauss(28, .bold))
                    .foregroundStyle(WBColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if isOptional {
                    Text("необязательно")
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                }
            }

            if let hint {
                Text(hint)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WBSpace.x4)
    }
}

// MARK: - Ввод на шаге

/// Поле на шаге крупнее, чем в списке: оно здесь одно, и мельчить незачем.
/// Подписи над полем нет — вопрос уже задан заголовком, повторять его дважды
/// значит занимать место, которое лучше отдать подсказке.
struct StepInput: View {
    let field: FormField
    let format: FieldFormat
    @Binding var value: String
    var focus: FocusState<String?>.Binding
    var error: String?
    var isChecking: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x3) {
            HStack(spacing: WBSpace.x2) {
                TextField(placeholder, text: $value)
                    .font(WBFont.hauss(24, .regular))
                    .foregroundStyle(WBColor.textPrimary)
                    .keyboardType(format.keyboard)
                    .textInputAutocapitalization(
                        format.keyboard == .default ? .sentences : .never
                    )
                    .autocorrectionDisabled()
                    .focused(focus, equals: field.id)

                if isChecking {
                    ProgressView().controlSize(.small)
                } else if !value.isEmpty {
                    Button {
                        Haptics.tap()
                        value = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(WBColor.controlsTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, WBSpace.x4)
            .frame(height: 64)
            .background(
                WBColor.bgBase,
                in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
            )
            .overlay {
                if error != nil {
                    RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
                        .strokeBorder(WBColor.declined, lineWidth: 1.5)
                }
            }

            if let error {
                Text(error)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.declined)
                    .transition(.opacity)
            }

            if !field.suggestions.isEmpty, value.isEmpty {
                SuggestionChips(values: field.suggestions, onLightBackground: false) { picked in
                    value = picked
                }
                .padding(.horizontal, -WBSpace.x4)
            }
        }
        .padding(.horizontal, WBSpace.x4)
        .animation(.snappy(duration: 0.2), value: error)
    }

    /// Маска в плейсхолдере вместо подписи «10 цифр»: пример короче объяснения.
    /// Сами маски живут в `FieldFormat.placeholder` — один список на все экраны.
    private var placeholder: String { format.placeholder }
}

// MARK: - Выбор на шаге

/// Варианты на шаге — списком строк, а не сегментами: на своём экране места
/// достаточно, а список читается без сокращений и подходит и для двух вариантов,
/// и для пяти. Тап по варианту сразу листает дальше — подтверждать выбор второй
/// кнопкой незачем.
struct StepChoice: View {
    let options: [ChoiceOption]
    let selection: String
    let onPick: (String) -> Void

    var body: some View {
        FormCard {
            VStack(spacing: 0) {
                ForEach(options) { option in
                    Button {
                        Haptics.tap()
                        onPick(option.id)
                    } label: {
                        HStack(spacing: WBSpace.x3) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(WBFont.body)
                                    .foregroundStyle(WBColor.textPrimary)
                                if let subtitle = option.subtitle {
                                    Text(subtitle)
                                        .font(WBFont.description)
                                        .foregroundStyle(WBColor.textSecondary)
                                }
                            }
                            Spacer(minLength: WBSpace.x2)
                            radio(isOn: option.id == selection)
                        }
                        .frame(minHeight: 60)
                        .padding(.horizontal, WBSpace.x4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if option.id != options.last?.id { FormSeparator() }
                }
            }
        }
    }

    private func radio(isOn: Bool) -> some View {
        Circle()
            .strokeBorder(isOn ? WBColor.textAccent : WBColor.radioOff, lineWidth: isOn ? 7 : 1.5)
            .frame(width: 22, height: 22)
            .animation(.snappy(duration: 0.18), value: isOn)
    }
}

// MARK: - Общий шит счёта списания

/// Один шит на оба режима формы: список и шаги спрашивают про счёт одинаково.
struct AccountPickerSheet: View {
    let accounts: [Account]
    let selectedID: String
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x3) {
            Text("Чем платим")
                .font(WBFont.title1)
                .foregroundStyle(WBColor.textPrimary)
                .padding(.horizontal, WBSpace.x4)
                .padding(.top, WBSpace.x4)

            VStack(spacing: 0) {
                ForEach(accounts) { account in
                    Button {
                        Haptics.tap()
                        onPick(account.id)
                    } label: {
                        HStack(spacing: WBSpace.x2) {
                            RowIconView(icon: account.icon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.amountTitle)
                                    .font(WBFont.body)
                                    .foregroundStyle(WBColor.textPrimary)
                                Text(account.subtitle)
                                    .font(WBFont.description)
                                    .foregroundStyle(WBColor.textSecondary)
                            }
                            Spacer(minLength: WBSpace.x2)
                            if account.id == selectedID {
                                DSIconView(icon: .checkmark, size: 22)
                            }
                        }
                        .frame(minHeight: 56)
                        .padding(.horizontal, WBSpace.x4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if account.id != accounts.last?.id { FormSeparator() }
                }
            }
            .background(
                WBColor.bgBase,
                in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
            )
            .padding(.horizontal, WBSpace.x2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WBColor.bgMinus1)
        .presentationDetents([.height(120 + CGFloat(accounts.count) * 57)])
        .presentationCornerRadius(WBRadius.x6)
    }
}
