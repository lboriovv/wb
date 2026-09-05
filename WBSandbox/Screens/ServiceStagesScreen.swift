import SwiftUI

/// Экран 1 концепции с этапами: заполнение данных. Макеты 48052:140411 …
/// 48142:113967.
///
/// Два режима, и это разные сущности, а не два состояния одной кнопки:
///
///   · **шаг** — курсор в поле, клавиатура поднята. Внизу «Сохранить» и стрелки
///     навигации. Набор кнопок не меняется от того, заполнено поле или нет:
///     заполнив реквизит, человек остаётся в шагах и едет дальше по ним;
///   · **список** — клавиатуры нет, видны все этапы: пройденные строками,
///     текущий раскрытым, дальше — ниже сгиба. Внизу одна кнопка «Продолжить»,
///     и стоит она в той же карточке, что допы (автоплатёж, напоминания), а не
///     на сером фоне сама по себе.
///
/// Раскрытый этап занимает весь экран по высоте, поэтому следующих не видно. Всё
/// это лежит в скролле: на форме из четырнадцати полей строки пройденных этапов
/// иначе не поместились бы на экран вообще.
///
/// Оплаты здесь нет: сумма и кнопка перевода живут на `ServiceAmountScreen`.
struct ServiceStagesScreen: View {
    @Bindable var model: ServiceFormModel
    var onBack: () -> Void = {}
    var onOpenSpec: () -> Void = {}

    /// Шаги или список — это разные сущности, а не два состояния одной кнопки.
    /// Раньше режим выводился из того, есть ли курсор в поле, и заполненный
    /// реквизит выбрасывал человека в список посреди прохода по шагам.
    private enum Mode { case stepping, list }

    /// Раскрытый этап.
    @State private var activeStageID = ""
    @State private var mode: Mode = .stepping
    /// Высота области скролла — по ней активная карточка растягивается до низа.
    @State private var viewport: CGFloat = 0
    @State private var isAmountPresented = false
    @FocusState private var focus: String?

    private var spec: ServiceSpec { model.spec }
    private var stages: [PaymentStage] { model.stages }

    private var isStepping: Bool { mode == .stepping }

    private var activeStage: PaymentStage? {
        stages.first { $0.id == activeStageID } ?? stages.first
    }

    private var activeIndex: Int {
        stages.firstIndex { $0.id == activeStage?.id } ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            stageList
            footer
        }
        .background(WBColor.bgMinus1, ignoresSafeAreaEdges: .all)
        .fullScreenCover(isPresented: $isAmountPresented) {
            ServiceAmountScreen(
                model: model,
                onBack: { isAmountPresented = false },
                onFinish: onBack,
                onOpenSpec: onOpenSpec
            )
        }
        // Курсор в поле означает шаги: тап по полю в списке возвращает в них, и
        // низ меняется вместе с этим, а не по отдельной кнопке.
        .onChange(of: focus) { _, new in
            guard new != nil, mode != .stepping else { return }
            withAnimation(.snappy(duration: 0.28)) { mode = .stepping }
        }
        .onAppear {
            guard activeStageID.isEmpty else { return }
            let stage = model.firstIncompleteStage ?? stages.first
            activeStageID = stage?.id ?? ""
            // Экран открывается сразу вводом: это единственное, что от человека
            // нужно, и просить сначала тапнуть по полю — нажатие на пустом месте.
            //
            // Фокус на первом кадре ставить нельзя: экран приезжает модально, и
            // курсор в поле появляется, а клавиатура — нет. Отсюда задержка;
            // при переходах между этапами она не нужна и вредна, там клавиатура
            // уже поднята и её нельзя отпускать.
            if let field = stage?.field, case .input = field.kind {
                Task {
                    try? await Task.sleep(for: .milliseconds(320))
                    focus = field.id
                }
            }
        }
    }

    // MARK: - Шапка

    /// Градиент в бренде поставщика: человек заходит из каталога и по цвету узнаёт,
    /// что попал к своему, раньше, чем прочитает название. У платежа по реквизитам
    /// поставщик неизвестен, пока не разобраны реквизиты, — до этого шапка
    /// нейтральная, а потом на её месте появляется тот, кого нашли по БИК.
    private var header: some View {
        let provider = model.headerProvider
        let isBranded = !provider.brandColors.isEmpty
        let foreground = isBranded ? Color.white : WBColor.textPrimary

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(foreground)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button(action: onBack) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(foreground)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: WBSpace.x2) {
                RowIconView(icon: provider.icon, size: 28)

                Text(provider.title)
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(foreground)
                    .lineLimit(1)

                Button(action: onOpenSpec) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(foreground.opacity(0.8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Карандаш появляется, когда реквизиты уже разобраны: заполненную
                // шапку надо чем-то править, иначе единственный путь назад —
                // выйти из платежа целиком.
                if model.isProviderResolved {
                    Button {
                        Haptics.tap()
                        editRequisites()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(foreground.opacity(0.8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, WBSpace.x4)
            .padding(.bottom, WBSpace.x4)
        }
        .background {
            if isBranded {
                LinearGradient(
                    colors: provider.brandColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            } else {
                WBColor.bgBase.ignoresSafeArea(edges: .top)
            }
        }
    }

    // MARK: - Этапы

    /// Этапы в скролле: пройденные строками сверху, активный на весь экран,
    /// следующие — под сгибом. Ни одна карточка не подменяется другой: меняется
    /// только высота, поэтому переход читается как растягивание контейнера.
    private var stageList: some View {
        GeometryReader { proxy in
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(stages) { stage in
                            stageCard(stage)
                                .id(stage.id)
                        }
                    }
                    .padding(.bottom, WBSpace.x2)
                    .animation(.snappy(duration: 0.32), value: activeStageID)
                    .animation(.snappy(duration: 0.28), value: mode)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: activeStageID) { _, id in
                    // Скроллим не к самому этапу, а к предыдущей строке: сверху
                    // остаётся видно, на что уже ответили, — как в макете, — а
                    // низ активной карточки уходит за кромку, и следующего этапа
                    // всё равно не видно.
                    let target = model.stage(before: id)?.id ?? id
                    withAnimation(.snappy(duration: 0.3)) { scroll.scrollTo(target, anchor: .top) }
                }
            }
            .onAppear { viewport = proxy.size.height }
            .onChange(of: proxy.size.height) { _, new in viewport = new }
        }
    }

    private func stageCard(_ stage: PaymentStage) -> some View {
        let isActive = stage.id == activeStage?.id
        let answer = model.answer(for: stage)

        return VStack(alignment: .leading, spacing: WBSpace.x3) {
            HStack(alignment: .firstTextBaseline, spacing: WBSpace.x3) {
                // Один и тот же текст в обоих состояниях: в раскрытом — заголовок
                // вопроса, в свёрнутом — подпись строки.
                Text(stage.title)
                    .font(isActive ? WBFont.hauss(20, .bold) : WBFont.body)
                    .foregroundStyle(isActive ? WBColor.textPrimary : WBColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: WBSpace.x2)

                Text(answer ?? "не заполнено")
                    .font(WBFont.body)
                    .foregroundStyle(answer == nil ? WBColor.controlsTertiary : WBColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    // В раскрытом этапе ответ виден в самом поле — здесь он
                    // уезжает вместе с высотой, а не гаснет.
                    .frame(height: isActive ? 0 : nil)
                    .clipped()
            }
            .frame(minHeight: 24)

            if isActive {
                stageContent(stage)
                    .transition(.identity)
                Spacer(minLength: 0)
            }
        }
        .padding(WBSpace.x4)
        // Ширина и высота одним модификатором, фон — строго после: два frame
        // подряд отменяли растяжение, а фон, поставленный раньше, рисовался по
        // содержимому, и карточка перехватывала тапы у того, что ниже.
        // До низа экрана карточка растягивается только в шагах: там задача —
        // не показывать, что дальше. В списке человек как раз пришёл посмотреть
        // весь платёж, и растянутая карточка выталкивала бы остальные этапы за
        // экран.
        .frame(
            maxWidth: .infinity,
            minHeight: isActive && isStepping ? max(viewport - WBSpace.x2, 0) : nil,
            alignment: .topLeading
        )
        .background(cardShape.fill(WBColor.bgBase))
        .padding(.bottom, WBSpace.x2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isActive else { return }
            Haptics.tap()
            activate(stage)
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
    }

    @ViewBuilder
    private func stageContent(_ stage: PaymentStage) -> some View {
        switch stage.kind {
        case .field(let field):
            fieldContent(field)
        case .bills:
            billsContent
        }
    }

    // MARK: - Поле этапа

    @ViewBuilder
    private func fieldContent(_ field: FormField) -> some View {
        switch field.kind {
        case .input(let format):
            inputContent(field, format)

        case .choice(let options):
            VStack(spacing: 0) {
                ForEach(options) { option in
                    Button {
                        Haptics.tap()
                        model.pickChoice(option.id, for: field)
                        goForward()
                    } label: {
                        listRow(
                            title: option.title,
                            subtitle: option.subtitle,
                            isSelected: option.id == (model.values[field.id] ?? "")
                        )
                    }
                    .buttonStyle(.plain)

                    if option.id != options.last?.id { FormSeparator().padding(.leading, 0) }
                }
            }

        case .meters(let meters):
            FormMetersView(
                field: field,
                meters: meters,
                focus: $focus,
                value: { model.meterValue(field.id, $0) },
                onChange: { model.setMeter(field.id, $0, $1) }
            )
            .padding(.horizontal, -WBSpace.x4)

        case .services(let lines):
            FormServicesView(
                field: field,
                lines: lines,
                isOn: { model.isServiceOn(field.id, $0) },
                onToggle: { model.setService(field.id, $0, $1) }
            )
            .padding(.horizontal, -WBSpace.x4)

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

        case .info(let value):
            FormReadOnlyRow(label: field.label, value: value)
        }
    }

    /// Поле ввода — всегда настоящий `TextField`, в любом состоянии этапа. Раньше
    /// незанятое поле было кнопкой, которая подменялась полем по тапу: фокус
    /// приходилось ставить программно и с задержкой, поэтому первый тап
    /// «проваливался», а клавиатура то поднималась, то нет.
    private func inputContent(_ field: FormField, _ format: FieldFormat) -> some View {
        let value = model.values[field.id] ?? ""
        let error = model.error(for: field, focused: focus)
        let isFocused = focus == field.id

        return VStack(alignment: .leading, spacing: WBSpace.x2) {
            // Сканирование квитанции — только у реквизита, который на ней
            // напечатан: у периода и суммы сканировать нечего.
            if field.facet == .identifier, !field.suggestions.isEmpty {
                Button {
                    Haptics.tap()
                    // Камеры в прототипе нет: «скан» подставляет сохранённый
                    // реквизит и едет дальше, как после ручного ввода.
                    model.setValue(field.suggestions[0], for: field)
                    advanceAfterInput(from: field.id)
                } label: {
                    Text("Сканировать квитанцию")
                        .font(WBFont.bodyAccent)
                        .foregroundStyle(WBColor.textAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            WBColor.bgMinus1,
                            in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: WBSpace.x2) {
                TextField(format.placeholder, text: Binding(
                    get: { model.values[field.id] ?? "" },
                    set: { type($0, into: field, format) }
                ))
                .font(WBFont.hauss(17, .regular))
                .foregroundStyle(WBColor.textPrimary)
                .keyboardType(format.keyboard)
                .textInputAutocapitalization(format.keyboard == .default ? .sentences : .never)
                .autocorrectionDisabled()
                .focused($focus, equals: field.id)
                // Своя идентичность на каждое поле: без неё SwiftUI переиспользует
                // то же поле для следующего этапа и дописывает в него набранное для
                // прошлого — БИК уезжал в счёт получателя.
                .id(field.id)
                .submitLabel(.done)
                .onSubmit { advanceAfterInput(from: field.id) }

                if field.triggersLookup, isCheckingLookup {
                    ProgressView().controlSize(.small)
                } else if isFocused, !value.isEmpty {
                    Button {
                        Haptics.tap()
                        model.setValue("", for: field)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(WBColor.controlsTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, WBSpace.x4)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
                    .fill(WBColor.bgMinus1)
                    .overlay {
                        RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
                            .strokeBorder(
                                error != nil ? WBColor.declined
                                    : (isFocused ? WBColor.textPrimary : .clear),
                                lineWidth: 1
                            )
                    }
            }

            if let error {
                Text(error)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.declined)
            } else if let hint = field.hint {
                Text(hint)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !field.suggestions.isEmpty {
                HStack(spacing: WBSpace.x2) {
                    ForEach(field.suggestions, id: \.self) { suggestion in
                        Button {
                            Haptics.tap()
                            model.setValue(suggestion, for: field)
                            advanceAfterInput(from: field.id)
                        } label: {
                            HStack(spacing: WBSpace.x1) {
                                Text(suggestion)
                                    .font(WBFont.description)
                                    .foregroundStyle(WBColor.textPrimary)
                                if field.facet == .identifier {
                                    Text("· ваш код")
                                        .font(WBFont.description)
                                        .foregroundStyle(WBColor.textAccent)
                                }
                            }
                            .padding(.horizontal, WBSpace.x3)
                            .frame(height: 34)
                            .background(
                                WBColor.bgMinus1,
                                in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Этап «Счет на оплату»

    @ViewBuilder
    private var billsContent: some View {
        if isCheckingLookup {
            HStack(spacing: WBSpace.x3) {
                ProgressView().controlSize(.small)
                Text("Спрашиваем начисления у поставщика")
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textSecondary)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 56)
        } else {
            VStack(spacing: 0) {
                ForEach(spec.bills) { bill in
                    Button {
                        Haptics.tap()
                        model.selectBill(bill.id)
                        focus = nil
                        isAmountPresented = true
                    } label: {
                        HStack(alignment: .top, spacing: WBSpace.x3) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bill.title)
                                    .font(WBFont.body)
                                    .foregroundStyle(WBColor.textPrimary)
                                Text(bill.period)
                                    .font(WBFont.description)
                                    .foregroundStyle(WBColor.textSecondary)
                            }

                            Spacer(minLength: WBSpace.x2)

                            Text(Money.rub(bill.amount))
                                .font(WBFont.body)
                                .foregroundStyle(WBColor.textPrimary)
                        }
                        .frame(minHeight: 56)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    FormSeparator().padding(.leading, 0)
                }

                Button {
                    Haptics.tap()
                    model.selectBill(ServiceStages.customBillID)
                    if let next = model.stage(after: ServiceStages.billsStageID) {
                        activate(next)
                    } else {
                        focus = nil
                        isAmountPresented = true
                    }
                } label: {
                    HStack {
                        Text("Ввести произвольную сумму")
                            .font(WBFont.body)
                            .foregroundStyle(WBColor.textAccent)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func listRow(title: String, subtitle: String?, isSelected: Bool) -> some View {
        HStack(spacing: WBSpace.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                }
            }
            Spacer(minLength: WBSpace.x2)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WBColor.textAccent)
            }
        }
        .frame(minHeight: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Низ

    /// Шаги — «Сохранить» и стрелки; список — допы и «Продолжить» одной карточкой.
    /// Набор кнопок зависит только от режима: заполнение поля его не меняет.
    @ViewBuilder
    private var footer: some View {
        if isStepping {
            steppingFooter
        } else {
            listFooter
        }
    }

    private var steppingFooter: some View {
        HStack(spacing: WBSpace.x3) {
            roundArrow("chevron.up", isEnabled: model.stage(before: activeStageID) != nil) {
                goBackward()
            }

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                // «Сохранить» — выход из шагов в список, а не переход дальше:
                // человек хочет увидеть, что записалось и что осталось.
                if let field = activeStage?.field { model.markTouched(field.id) }
                focus = nil
                withAnimation(.snappy(duration: 0.28)) { mode = .list }
            } label: {
                Text("Сохранить")
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(WBColor.textPrimary)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            roundArrow("chevron.down", isEnabled: model.stage(after: activeStageID) != nil) {
                goForward()
            }
        }
        .padding(.horizontal, WBSpace.x4)
        .padding(.bottom, WBSpace.x2)
    }

    /// Кнопка живёт в той же карточке, что автоплатёж и напоминания: это один
    /// блок «что ещё сделать с платежом и поехали», а не кнопка на сером фоне.
    private var listFooter: some View {
        VStack(spacing: 0) {
            ForEach(model.reminderFields) { field in
                FormToggleRow(
                    field: field,
                    price: togglePrice(field),
                    isOn: Binding(
                        get: { model.isToggleOn(field.id) },
                        set: { model.setToggle(field.id, $0) }
                    )
                )
                FormSeparator()
            }

            WBPrimaryButton(title: "Продолжить") { goForward() }
                .padding(WBSpace.x4)
        }
        .background(cardShape.fill(WBColor.bgBase))
        .padding(.bottom, WBSpace.x2)
    }

    private func togglePrice(_ field: FormField) -> Decimal? {
        if case .toggle(let price) = field.kind { return price }
        return nil
    }

    private func roundArrow(
        _ symbol: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(WBColor.ctaFill, in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .disabled(!isEnabled)
    }

    // MARK: - Переходы

    /// Раскрыть этап. Если в нём вводят — сразу ставим курсор: остаёмся в шагах,
    /// клавиатура не уезжает. Фокус ставится синхронно, без задержки, иначе
    /// клавиатура успевает уйти и вернуться.
    /// Раскрыть этап и остаться в шагах: если в нём вводят — сразу ставим курсор,
    /// клавиатура не уезжает (фокус синхронный, без задержки — иначе она успевает
    /// уйти и вернуться). Если это список начислений, курсору некуда встать, но
    /// режим шагов сохраняется: внизу по-прежнему «Сохранить» и стрелки.
    private func activate(_ stage: PaymentStage) {
        withAnimation(.snappy(duration: 0.3)) {
            activeStageID = stage.id
            mode = .stepping
        }
        guard let field = stage.field, case .input = field.kind else {
            focus = nil
            return
        }
        // Фокус — со задержкой в один такт разметки. Программный фокус на поле,
        // которое только что появилось на экране, курсор ставит, а клавиатуру не
        // поднимает: она уезжает вместе со прошлым полем и не возвращается.
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            focus = field.id
        }
    }

    /// Автопереход после заполненного поля: только раскрыть следующий этап. Ни
    /// оплатить все счета, ни уйти на экран суммы он не может — это решения, и
    /// принимает их человек кнопкой, а не десятая цифра реквизита.
    /// `from` — поле, которое просит переход. Проверка «это поле активного этапа»
    /// обязательна: сеттер `TextField` успевает пройти ещё раз после того, как
    /// этап уже сменился, и без неё заполненный реквизит перепрыгивал сразу через
    /// два-три этапа.
    private func advanceAfterInput(from fieldID: String) {
        guard let stage = activeStage, stage.field?.id == fieldID else { return }
        guard let next = model.stage(after: stage.id) else { return }
        model.markTouched(fieldID)
        activate(next)
    }

    private func goForward() {
        guard let stage = activeStage else { return }
        if let field = stage.field { model.markTouched(field.id) }

        // На этапе начислений «дальше» без выбора значит «все счета сразу»: это то,
        // что предлагает сам список.
        if case .bills = stage.kind, model.selectedBillID == nil {
            model.selectBill(ServiceStages.allBillsID)
            focus = nil
            isAmountPresented = true
            return
        }

        if let next = model.stage(after: stage.id) {
            activate(next)
            return
        }

        focus = nil
        isAmountPresented = true
    }

    private func goBackward() {
        guard let stage = activeStage, let previous = model.stage(before: stage.id) else { return }
        if let field = stage.field { model.markTouched(field.id) }
        activate(previous)
    }

    private func goBack() {
        guard let stage = activeStage, let previous = model.stage(before: stage.id) else {
            onBack()
            return
        }
        activate(previous)
    }

    /// Карандаш в шапке: вернуться к реквизитам, по которым нашли поставщика.
    private func editRequisites() {
        guard let first = stages.first else { return }
        activate(first)
    }

    /// Ввод по одному символу. Реквизит фиксированной длины уводит к следующему
    /// шагу сам — но именно к следующему шагу, а не в список: набор кнопок под
    /// рукой от заполнения поля не меняется.
    private func type(_ raw: String, into field: FormField, _ format: FieldFormat) {
        model.setValue(raw, for: field)
        guard focus == field.id, format.hasFixedLength else { return }
        let value = model.values[field.id] ?? ""
        guard format.isComplete(value), format.error(value) == nil else { return }
        advanceAfterInput(from: field.id)
    }

    private var isCheckingLookup: Bool {
        if case .loading = model.lookupState { return true }
        return false
    }
}
