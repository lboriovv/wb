import SwiftUI

/// Рабочая версия конструктора оплаты услуг.
/// Новый платёж идёт линейно; обзор с аккордеонами — отдельный вход в черновик.
struct ServiceStagesWorkScreen: View {
    @Bindable var model: ServiceFormModel
    var resumesDraft = false
    /// Launch-аргументы нужны только первому экрану, открытому deep-link'ом.
    /// Повторный ручной вход из каталога всегда начинает новый чистый платёж.
    var appliesDemoLaunchState = false
    var onBack: () -> Void = {}
    var onOpenSpec: () -> Void = {}

    @State private var activeStageID = ""
    @State private var isResumeMode = false
    @State private var isAmountPresented = false
    @State private var selectedBillForDetails: ChargeBill?
    @State private var bankSearchQuery = ""
    @State private var activeRequisitesGroupID = ""
    @State private var activeRequisitesFieldID = ""
    @State private var isReviewingRequisitesGroup = false
    @State private var isReviewingAllBudgetData = false
    @State private var overviewReturnGroupID = ""
    @State private var requisitesViewport: CGFloat = 0
    @FocusState private var focus: String?

    private var stages: [PaymentStage] { model.stages }
    private var activeStage: PaymentStage? {
        stages.first { $0.id == activeStageID } ?? stages.first
    }

    private var scenarioTopType: PipFigmaTop.TopType {
        if model.spec.usesGroupedRequisites
            || (model.hasDeferredProvider && !model.isProviderResolved) {
            return .requisites
        }
        return .provider
    }

    private var scenarioTopTheme: PipFigmaTop.Theme {
        topTheme(for: model.spec)
    }

    private var scenarioTop: some View {
        PipFigmaTop(
            type: scenarioTopType,
            showsScanButton: showsReceiptScanner,
            titleText: model.headerProvider.title,
            theme: scenarioTopTheme,
            onBack: goBack,
            onClose: onBack,
            onScanReceipt: scanReceipt
        )
        .frame(maxWidth: .infinity)
    }

    private var scenarioTopBackgroundHeight: CGFloat {
        (showsReceiptScanner ? 168 : 96) + 24
    }

    private var stickyBarType: PipFigmaStickyBar.BarType {
        focus == nil ? .default : .systemKeyboard
    }

    private var flowProgressFraction: CGFloat {
        stageProgressFraction(stages: stages, activeStageID: activeStageID)
    }

    private var showsFlowProgress: Bool {
        let fieldSteps = model.spec.allFields.filter { field in
            guard field.attachesTo == nil else { return false }
            switch field.kind {
            case .input, .choice, .meters, .services:
                return true
            case .toggle, .info:
                return false
            }
        }.count
        let billsStep = model.spec.bills.isEmpty ? 0 : 1
        return fieldSteps + billsStep > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            scenarioTop
            if isReviewingAllBudgetData {
                budgetAllDataBody
            } else if model.spec.usesGroupedRequisites {
                groupedRequisitesBody
            } else if isResumeMode {
                resumeBody
            } else {
                flowBody
            }
        }
        .ignoresSafeArea(edges: focus == nil ? [.top, .bottom] : .top)
        .background(alignment: .top) {
            GeometryReader { proxy in
                PipFigmaTopBackground(
                    theme: scenarioTopTheme,
                    width: proxy.size.width,
                    height: scenarioTopBackgroundHeight
                )
                .frame(height: scenarioTopBackgroundHeight, alignment: .top)
            }
        }
        .background(WBColor.bgBase, ignoresSafeAreaEdges: .all)
        .animation(.snappy(duration: 0.24), value: focus == nil)
        .animation(.snappy(duration: 0.24), value: showsReceiptScanner)
        .fullScreenCover(isPresented: $isAmountPresented) {
            ServiceAmountScreen(
                model: model,
                appliesDemoLaunchState: appliesDemoLaunchState,
                onBack: { isAmountPresented = false },
                onFinish: onBack,
                onOpenSpec: onOpenSpec
            )
        }
        .fullScreenCover(item: $selectedBillForDetails) { bill in
            ChargeDetailsScreen(
                model: model,
                bill: bill,
                onBack: { selectedBillForDetails = nil },
                onClose: {
                    selectedBillForDetails = nil
                    onBack()
                },
                onContinue: {
                    selectedBillForDetails = nil
                    openAmount()
                }
            )
        }
        .onAppear(perform: configureEntry)
    }

    // MARK: Новый платёж

    private var flowBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                if let activeStage {
                    VStack(alignment: .leading, spacing: WBSpace.x3) {
                        Text(activeStage.title)
                            .font(WBFont.hauss(24, .bold))
                            .foregroundStyle(WBColor.textPrimary)
                            .padding(.vertical, WBSpace.x1)
                        stageContent(activeStage)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, WBSpace.x4)
                    .padding(.top, WBSpace.x4)
                }
            }
            .scrollDismissesKeyboard(.interactively)

            PipFigmaStickyBar(
                type: stickyBarType,
                title: model.spec.ctaTitle,
                progressFraction: flowProgressFraction,
                showsProgress: showsFlowProgress,
                onContinue: continueFlow
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            PipTopCornersShape(radius: WBRadius.x6)
                .fill(WBColor.bgBase)
                .ignoresSafeArea(edges: .bottom)
        }
        .clipShape(PipTopCornersShape(radius: WBRadius.x6))
    }

    // MARK: Группы реквизитов

    /// Для обычной услуги один вопрос на экран — самый ясный путь. У платежа по
    /// реквизитам это превращается в десяток одинаковых экранов, поэтому здесь
    /// единицей прогресса становится смысловая группа, а не отдельное поле.
    private var requisitesGroups: [FormSection] {
        model.spec.sections.filter { !$0.isExtras && model.isRevealed($0.reveal) }
    }

    private var activeRequisitesGroup: FormSection? {
        requisitesGroups.first { $0.id == activeRequisitesGroupID }
            ?? requisitesGroups.first { !isGroupComplete($0) }
            ?? requisitesGroups.last
    }

    private func groupFields(_ section: FormSection) -> [FormField] {
        section.fields.filter { model.isRevealed($0.reveal) }
    }

    private func isGroupComplete(_ section: FormSection) -> Bool {
        groupFields(section)
            .filter(\.isRequired)
            .allSatisfy(model.isFilled)
    }

    /// Группа «Реквизиты» завершается только парой «счёт + банк», но сами
    /// значения спрашиваем последовательно: сначала счёт, затем поиск банка.
    /// Так человек не пытается решить два независимых вопроса одновременно.
    private func activeField(in section: FormSection) -> FormField? {
        let fields = interactiveFields(in: section)
        if let selected = fields.first(where: { $0.id == activeRequisitesFieldID }) {
            return selected
        }
        return fields.first { field in
            !model.isFilled(field)
        }
    }

    private func interactiveFields(in section: FormSection) -> [FormField] {
        groupFields(section).filter { field in
            switch field.kind {
            case .input, .choice, .meters, .services:
                // Необязательное поле не исчезает из сценария: в макете КПП,
                // назначение и УИН всё равно нужно показать, просто их можно
                // пропустить кнопкой «Продолжить».
                return true
            case .toggle, .info:
                return false
            }
        }
    }

    private func groupTitle(_ section: FormSection) -> String {
        section.title ?? (section.id == "bank" ? "Реквизиты" : "Данные")
    }

    /// В итоговом бюджетном макете данные получателя и параметры платежа
    /// заполняются смысловыми блоками: поля видны вместе, а не сменяют друг друга
    /// по одному. Счёт и поиск банка остаются последовательными.
    private func showsWholeBudgetGroup(_ section: FormSection) -> Bool {
        model.spec.id == "requisites-budget"
            && section.id == "payment"
    }

    private func isBudgetRecipientGroup(_ section: FormSection) -> Bool {
        model.spec.id == "requisites-budget" && section.id == "recipient"
    }

    /// Сканирование — часть верхнего компонента, а не содержимого белой секции.
    /// Показываем кнопку только когда текущий вопрос реально можно заполнить
    /// данными из квитанции.
    private var showsReceiptScanner: Bool {
        receiptScanField != nil
    }

    private var receiptScanField: FormField? {
        if isReviewingAllBudgetData { return nil }

        if model.spec.usesGroupedRequisites {
            guard let group = activeRequisitesGroup,
                  !(isBudgetRecipientGroup(group) && activeRequisitesFieldID.isEmpty),
                  let field = activeField(in: group),
                  canScanReceipt(for: field)
            else { return nil }
            return field
        }

        guard !isResumeMode,
              let field = activeStage?.field,
              canScanReceipt(for: field)
        else { return nil }
        return field
    }

    private func canScanReceipt(for field: FormField) -> Bool {
        guard case .input = field.kind, !field.suggestions.isEmpty else { return false }
        if field.facet == .identifier { return true }
        return model.spec.id == "requisites-budget" && field.id == "account"
    }

    private func scanReceipt() {
        Haptics.tap()
        if let field = receiptScanField,
           let saved = field.suggestions.first {
            model.setValue(saved, for: field)
        }
    }

    private var requisitesProgress: RequisitesProgress {
        guard model.spec.usesGroupedRequisites else {
            return RequisitesProgress(fraction: 0)
        }

        let bankFields = requisitesGroups
            .first { $0.id == "bank" }
            .map(interactiveFields(in:))
            ?? []
        let completedBank: Int
        if let activeGroup = activeRequisitesGroup, activeGroup.id == "bank" {
            let currentID = activeField(in: activeGroup)?.id
            completedBank = bankFields.firstIndex { $0.id == currentID } ?? 0
        } else {
            completedBank = bankFields.count
        }
        let bankProgress = CGFloat(min(completedBank, 2)) * 0.125

        guard completedBank >= bankFields.count, model.isProviderResolved else {
            return RequisitesProgress(fraction: bankProgress)
        }

        let restGroups = requisitesGroups
            .filter { $0.id != "bank" }
        let restUnitCount = restGroups.reduce(0) { $0 + progressUnitCount(in: $1) }
        guard restUnitCount > 0 else {
            return RequisitesProgress(fraction: 0.25)
        }

        let completedRest: Int
        if isReviewingAllBudgetData {
            completedRest = restUnitCount
        } else if let activeGroup = activeRequisitesGroup,
                  let activeIndex = restGroups.firstIndex(where: { $0.id == activeGroup.id }) {
            let completedBefore = restGroups.prefix(activeIndex)
                .reduce(0) { $0 + progressUnitCount(in: $1) }
            let activeFields = interactiveFields(in: activeGroup)
            let completedInside: Int
            if isReviewingRequisitesGroup {
                completedInside = progressUnitCount(in: activeGroup)
            } else if isBudgetRecipientGroup(activeGroup), activeRequisitesFieldID.isEmpty {
                completedInside = 0
            } else if showsWholeBudgetGroup(activeGroup) {
                completedInside = 0
            } else if let currentID = activeField(in: activeGroup)?.id {
                completedInside = activeFields.firstIndex { $0.id == currentID } ?? 0
            } else {
                completedInside = activeFields.count
            }
            completedRest = completedBefore + completedInside
        } else {
            completedRest = 0
        }

        let restFraction = CGFloat(completedRest) / CGFloat(restUnitCount)
        return RequisitesProgress(fraction: 0.25 + 0.75 * restFraction)
    }

    private func progressUnitCount(in section: FormSection) -> Int {
        if isBudgetRecipientGroup(section) || showsWholeBudgetGroup(section) {
            return 1
        }
        return interactiveFields(in: section).count
    }

    private var groupedRequisitesBody: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(requisitesGroups) { section in
                                // Счёт и банк остаются в шапке после проверки
                                // реквизитов, поэтому вторым аккордеоном их не
                                // дублируем.
                                if section.id != "bank" || section.id == activeRequisitesGroup?.id {
                                    requisitesAccordionCard(section)
                                        .id(section.id)
                                }
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: activeRequisitesGroupID) { _, id in
                        guard !id.isEmpty else { return }
                        withAnimation(.snappy(duration: 0.3)) {
                            scroll.scrollTo(id, anchor: .top)
                        }
                    }
                }
                .onAppear { requisitesViewport = proxy.size.height }
                .onChange(of: proxy.size.height) { _, size in requisitesViewport = size }
            }

            PipFigmaStickyBar(
                type: stickyBarType,
                title: model.spec.ctaTitle,
                progressFraction: requisitesProgress.fraction,
                onContinue: continueGroupedRequisites,
                onStepsTap: openBudgetDataOverview
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            PipTopCornersShape(radius: WBRadius.x6)
                .fill(WBColor.bgBase)
                .ignoresSafeArea(edges: .bottom)
        }
        .clipShape(PipTopCornersShape(radius: WBRadius.x6))
    }

    /// Ровно тот же паттерн, что в базовых «Оплата услуг · этапы»: завершённый
    /// блок сжимается до строки с ответом, а текущий растягивается до низа.
    private func requisitesAccordionCard(_ section: FormSection) -> some View {
        let isActive = section.id == activeRequisitesGroup?.id
        let field = activeField(in: section)
        let showsRecipientOverview = isBudgetRecipientGroup(section) && activeRequisitesFieldID.isEmpty
        let title = isActive && !isReviewingRequisitesGroup && !showsWholeBudgetGroup(section) && !showsRecipientOverview
            ? (field?.label ?? groupTitle(section))
            : groupTitle(section)
        let summary = groupSummary(section)

        return VStack(alignment: .leading, spacing: WBSpace.x3) {
            HStack(alignment: .firstTextBaseline, spacing: WBSpace.x3) {
                Text(title)
                    .font(isActive ? WBFont.hauss(20, .bold) : WBFont.body)
                    .foregroundStyle(isActive ? WBColor.textPrimary : WBColor.textSecondary)
                    .lineLimit(1)
                    .layoutPriority(1)

                if !isActive {
                    Spacer(minLength: WBSpace.x2)

                    Text(summary.isEmpty ? "не заполнено" : summary)
                        .font(WBFont.body)
                        .foregroundStyle(summary.isEmpty ? WBColor.controlsTertiary : WBColor.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(minHeight: 24)

            if isActive {
                activeGroupContent(section)
                    .transition(.identity)
                Spacer(minLength: 0)
            }
        }
        .padding(WBSpace.x4)
        .frame(
            maxWidth: .infinity,
            minHeight: isActive ? max(requisitesViewport - WBSpace.x2, 0) : nil,
            alignment: .topLeading
        )
        .background {
            if isActive {
                WBColor.bgBase
            } else {
                RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
                    .fill(WBColor.bgBase)
            }
        }
        .padding(.bottom, isActive ? 0 : WBSpace.x2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isActive else { return }
            Haptics.tap()
            withAnimation(.snappy(duration: 0.32)) {
                activeRequisitesGroupID = section.id
                activeRequisitesFieldID = isBudgetRecipientGroup(section)
                    ? ""
                    : interactiveFields(in: section).first?.id ?? ""
                isReviewingRequisitesGroup = false
            }
            focusGroupedInput(after: 180)
        }
    }

    private func activeGroupContent(_ section: FormSection) -> some View {
        let field = activeField(in: section)
        return VStack(alignment: .leading, spacing: WBSpace.x4) {
            if isBudgetRecipientGroup(section), activeRequisitesFieldID.isEmpty {
                budgetRecipientOverview(section)
            } else if showsWholeBudgetGroup(section) {
                VStack(alignment: .leading, spacing: WBSpace.x3) {
                    ForEach(interactiveFields(in: section)) { field in
                        fieldContent(field)
                    }
                }
            } else if isReviewingRequisitesGroup {
                filledGroupReview(section)
            } else if let field {
                ForEach(groupFields(section).filter { $0.attachesTo == field.id }) { attached in
                    fieldContent(attached)
                }
                fieldContent(field)
            } else {
                groupReview(section)
            }

            // Переключатель показываем после обязательных данных плательщика.
            // При включении он раскрывает ещё одну обязательную ветку той же
            // группы, а не создаёт четвёртый экран.
            if case nil = field {
                ForEach(groupFields(section)) { field in
                    if case .toggle = field.kind {
                        fieldContent(field)
                    }
                }
            }
        }
    }

    /// Сводка получателя — это навигация по реквизитам, а не четыре пустых
    /// TextField подряд. Первые три поля могут независимо найти одного и того же
    /// получателя; КБК остаётся отдельным только когда справочник его не вернул.
    private func budgetRecipientOverview(_ section: FormSection) -> some View {
        VStack(spacing: WBSpace.x2) {
            ForEach(interactiveFields(in: section)) { field in
                budgetRecipientOverviewRow(field, in: section)
            }
        }
    }

    private func budgetRecipientOverviewRow(_ field: FormField, in section: FormSection) -> some View {
        let value = model.values[field.id] ?? ""
        return Button {
            Haptics.tap()
            activeRequisitesGroupID = section.id
            activeRequisitesFieldID = field.id
            focusGroupedInput(after: 180)
        } label: {
            Group {
                if value.isEmpty {
                    Text(field.label)
                        .font(WBFont.body)
                        .foregroundStyle(WBColor.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(field.label)
                            .font(WBFont.description)
                            .foregroundStyle(WBColor.textSecondary)
                        Text(value)
                            .font(WBFont.body)
                            .foregroundStyle(WBColor.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WBSpace.x4)
            .frame(height: 64)
        }
        .buttonStyle(.plain)
        .background(
            WBColor.bgMinus1,
            in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .circular)
        )
    }

    private func groupReview(_ section: FormSection) -> some View {
        VStack(spacing: 0) {
            ForEach(groupFields(section)) { field in
                if case .toggle = field.kind { EmptyView() }
                else { reviewRow(field) }
            }
        }
        .padding(.horizontal, WBSpace.x4)
        .background(WBColor.bgMinus1, in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous))
    }

    /// Финальная сверка перед следующей смысловой группой. Поля остаются теми же
    /// инпутами, поэтому человек видит реальные подставленные значения и может
    /// поправить их, а не доверяет безликой текстовой сводке.
    private func filledGroupReview(_ section: FormSection) -> some View {
        VStack(alignment: .leading, spacing: WBSpace.x4) {
            ForEach(groupFields(section)) { field in
                reviewInputField(field, in: section)
            }
        }
    }

    /// Раскрытая группа — это сверка, а не второй ввод. Поэтому поле выглядит
    /// как заполненный input, но не показывает подсказки и не вызывает клавиатуру
    /// до тапа. Тап возвращает в нормальный экран редактирования этого поля.
    private func reviewInputField(_ field: FormField, in section: FormSection) -> some View {
        Button {
            Haptics.tap()
            isReviewingRequisitesGroup = false
            activeRequisitesGroupID = section.id
            activeRequisitesFieldID = field.id
            focusGroupedInput(after: 180)
        } label: {
            VStack(alignment: .leading, spacing: WBSpace.x2) {
                Text(field.label)
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(WBColor.textPrimary)
                Text(answer(for: field))
                    .font(WBFont.hauss(17, .regular))
                    .foregroundStyle(WBColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(.horizontal, WBSpace.x4)
                    .background(
                        WBColor.bgMinus1,
                        in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .circular)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func reviewRow(_ field: FormField) -> some View {
        HStack(alignment: .top, spacing: WBSpace.x3) {
            Text(field.label)
                .font(WBFont.description)
                .foregroundStyle(WBColor.textSecondary)
            Spacer(minLength: 0)
            Text(answer(for: field))
                .font(WBFont.descriptionAccent)
                .foregroundStyle(WBColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, WBSpace.x3)
    }

    private func groupSummary(_ section: FormSection) -> String {
        groupFields(section)
            .filter { if case .toggle = $0.kind { return false }; return true }
            .map(answer(for:))
            .filter { !$0.isEmpty && $0 != "—" }
            .joined(separator: " · ")
    }

    // MARK: Финальная сверка бюджетного платежа

    private var budgetAllDataBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: WBSpace.x4) {
                    Text("Все данные")
                        .font(WBFont.hauss(24, .bold))
                        .foregroundStyle(WBColor.textPrimary)

                    ForEach(requisitesGroups) { section in
                        budgetReviewSection(section)
                    }
                }
                .padding(WBSpace.x4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PipFigmaStickyBar(
                type: stickyBarType,
                title: model.spec.ctaTitle,
                progressFraction: requisitesProgress.fraction,
                onContinue: continueBudgetOverview,
                onStepsTap: {
                    Haptics.tap()
                }
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            PipTopCornersShape(radius: WBRadius.x6)
                .fill(WBColor.bgBase)
                .ignoresSafeArea(edges: .bottom)
        }
        .clipShape(PipTopCornersShape(radius: WBRadius.x6))
    }

    private func continueBudgetOverview() {
        guard let incomplete = requisitesGroups.first(where: { !isGroupComplete($0) }) else {
            openAmount()
            return
        }

        isReviewingAllBudgetData = false
        activeRequisitesGroupID = incomplete.id
        activeRequisitesFieldID = isBudgetRecipientGroup(incomplete)
            ? ""
            : interactiveFields(in: incomplete).first(where: { !model.isFilled($0) })?.id
                ?? interactiveFields(in: incomplete).first?.id
                ?? ""
        focusGroupedInput(after: 180)
    }

    private func openBudgetDataOverview() {
        Haptics.tap()
        focus = nil
        overviewReturnGroupID = activeRequisitesGroup?.id ?? ""
        isReviewingAllBudgetData = true
    }

    private func budgetReviewSection(_ section: FormSection) -> some View {
        VStack(alignment: .leading, spacing: WBSpace.x4) {
            Button {
                Haptics.tap()
                isReviewingAllBudgetData = false
                activeRequisitesGroupID = section.id
                selectFirstUnfilledField()
                if activeRequisitesFieldID.isEmpty {
                    activeRequisitesFieldID = interactiveFields(in: section).first?.id ?? ""
                }
                focusGroupedInput(after: 180)
            } label: {
                HStack {
                    Text(groupTitle(section))
                        .font(WBFont.bodyAccent)
                        .foregroundStyle(WBColor.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WBColor.controlsTertiary)
                }
            }
            .buttonStyle(.plain)

            ForEach(groupFields(section)) { field in
                VStack(alignment: .leading, spacing: WBSpace.x1) {
                    Text(field.id == "payment-for" ? "Платёж" : field.label)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                    Text(answer(for: field))
                        .font(WBFont.body)
                        .foregroundStyle(WBColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func answer(for field: FormField) -> String {
        model.answer(for: PaymentStage(id: field.id, title: field.label, kind: .field(field))) ?? "—"
    }

    // MARK: Возврат к черновику

    private var resumeBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: WBSpace.x3) {
                    Text("Продолжим оплату")
                        .font(WBFont.hauss(24, .bold))
                        .foregroundStyle(WBColor.textPrimary)
                        .padding(.horizontal, WBSpace.x4)

                    ForEach(stages) { stage in resumeStage(stage) }
                }
                .padding(.vertical, WBSpace.x4)
            }

            PipFigmaStickyBar(
                type: stickyBarType,
                title: model.spec.ctaTitle,
                progressFraction: flowProgressFraction,
                showsProgress: showsFlowProgress,
                onContinue: continueFlow,
                onStepsTap: {
                    Haptics.tap()
                }
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            PipTopCornersShape(radius: WBRadius.x6)
                .fill(WBColor.bgBase)
                .ignoresSafeArea(edges: .bottom)
        }
        .clipShape(PipTopCornersShape(radius: WBRadius.x6))
    }

    private func resumeStage(_ stage: PaymentStage) -> some View {
        let isActive = stage.id == activeStage?.id
        let answer = model.answer(for: stage)
        return VStack(alignment: .leading, spacing: WBSpace.x3) {
            Button {
                guard !isActive else { return }
                Haptics.tap()
                activate(stage)
            } label: {
                HStack(spacing: WBSpace.x3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage.title).font(WBFont.bodyAccent).foregroundStyle(WBColor.textPrimary)
                        Text(answer ?? "Не заполнено")
                            .font(WBFont.description)
                            .foregroundStyle(answer == nil ? WBColor.controlsTertiary : WBColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isActive ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WBColor.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isActive {
                stageContent(stage)
            }
        }
        .padding(WBSpace.x4)
        .background(WBColor.bgBase, in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous))
        .padding(.horizontal, WBSpace.x2)
    }

    // MARK: Содержимое этапа

    @ViewBuilder
    private func stageContent(_ stage: PaymentStage) -> some View {
        switch stage.kind {
        case .field(let field): fieldContent(field)
        case .bills: billsContent
        }
    }

    @ViewBuilder
    private func fieldContent(_ field: FormField) -> some View {
        switch field.kind {
        case .input(let format):
            if field.bankOptions.isEmpty { input(field, format) }
            else { bankSearch(field) }
        case .choice(let options):
            VStack(spacing: 0) {
                ForEach(options) { option in
                    Button {
                        Haptics.tap()
                        model.pickChoice(option.id, for: field)
                        // Выбор — это ответ на этап, а не состояние radio-list:
                        // после тапа сразу идём к следующему вопросу.
                        if model.spec.usesGroupedRequisites {
                            advanceGroupedSelection()
                        } else if let next = model.stage(after: field.id) {
                            activate(next)
                        } else {
                            openAmount()
                        }
                    } label: {
                        StageOperationLine(title: option.title, subtitle: option.subtitle)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .meters(let meters):
            FormMetersView(field: field, meters: meters, focus: $focus,
                           value: { model.meterValue(field.id, $0) },
                           onChange: { model.setMeter(field.id, $0, $1) },
                           usesOperationLineStyle: true)
        case .services(let lines):
            FormServicesView(field: field, lines: lines,
                             isOn: { model.isServiceOn(field.id, $0) },
                             onToggle: { model.setService(field.id, $0, $1) },
                             usesOperationLineStyle: true)
        case .toggle(let price):
            FormToggleRow(field: field, price: price,
                          isOn: Binding(get: { model.isToggleOn(field.id) }, set: { model.setToggle(field.id, $0) }),
                          isBoxed: true)
        case .info(let value): FormReadOnlyRow(label: field.label, value: value)
        }
    }

    private func input(_ field: FormField, _ format: FieldFormat) -> some View {
        let error = model.error(for: field, focused: focus)
        return VStack(alignment: .leading, spacing: WBSpace.x3) {
            VStack(alignment: .leading, spacing: WBSpace.x2) {
                if isLargeInput(field) {
                    PipLargeInput(
                        field: field,
                        format: format,
                        value: inputBinding(for: field),
                        focus: $focus,
                        placeholder: inputPlaceholder(for: field),
                        error: error
                    )
                } else {
                    PipInput(
                        field: field,
                        format: format,
                        value: inputBinding(for: field),
                        focus: $focus,
                        placeholder: inputPlaceholder(for: field),
                        error: error
                    )
                }

            // Быстрый ввод всегда подписываем названием самого реквизита: это
            // «ваш код» для ЕПД и «из недавних» для перевода. Не переносим текст
            // «ваш код» на поля, где он не имеет смысла.
            if model.spec.id == "requisites-budget", field.id == "account" {
                budgetSavedAccounts(field)
            } else if model.spec.id == "requisites-budget", field.id == "recipient-inn" {
                budgetRecipientMatches(field)
            } else if let suggestion = field.suggestions.first,
                      let quickLabel = quickSuggestionLabel(for: field) {
                HStack(spacing: WBSpace.x1) {
                    Text(suggestion).foregroundStyle(WBColor.textPrimary)
                    Text("·").foregroundStyle(WBColor.textPrimary)
                    Text(quickLabel).foregroundStyle(WBColor.textAccent)
                }
                .font(WBFont.description)
                .padding(.horizontal, WBSpace.x3)
                .frame(height: 38)
                .background(WBColor.bgMinus1, in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous))
                .onTapGesture { applyQuickSuggestion(suggestion, for: field) }
            }

            // Период выбирают из тех же месяцев, что только что были показаны в
            // начислениях. Отображаем название месяца, а в поле кладём MM.YYYY.
                if field.facet == .period, !billPeriodSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: WBSpace.x2) {
                            ForEach(billPeriodSuggestions) { suggestion in
                                Button(suggestion.title) {
                                    Haptics.tap()
                                    model.setValue(suggestion.value, for: field)
                                }
                                .font(WBFont.description)
                                .foregroundStyle(WBColor.textPrimary)
                                .padding(.horizontal, WBSpace.x3)
                                .frame(height: 38)
                                .background(WBColor.bgMinus1, in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous))
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func inputBinding(for field: FormField) -> Binding<String> {
        Binding(
            get: { model.values[field.id] ?? "" },
            set: { model.setValue($0, for: field) }
        )
    }

    private func inputPlaceholder(for field: FormField) -> String {
        visibleInputCount(for: field) > 1 ? field.label : ""
    }

    private func visibleInputCount(for field: FormField) -> Int {
        guard model.spec.usesGroupedRequisites,
              let section = activeRequisitesGroup,
              groupFields(section).contains(where: { $0.id == field.id })
        else { return 1 }

        let visibleFields: [FormField]
        if showsWholeBudgetGroup(section) {
            visibleFields = interactiveFields(in: section)
        } else if let active = activeField(in: section) {
            visibleFields = groupFields(section).filter { $0.id == active.id || $0.attachesTo == active.id }
        } else {
            visibleFields = []
        }

        return visibleFields.filter(isPlainInput).count
    }

    private func isPlainInput(_ field: FormField) -> Bool {
        guard case .input = field.kind else { return false }
        return field.bankOptions.isEmpty
    }

    private func isLargeInput(_ field: FormField) -> Bool {
        if field.facet == .purpose { return true }
        if field.id == "recipient-name" { return true }
        return field.label.localizedCaseInsensitiveContains("наименование получателя")
    }

    private func budgetRecipientMatches(_ field: FormField) -> some View {
        VStack(spacing: 0) {
            ForEach(field.suggestions, id: \.self) { inn in
                DetailRowView(
                    row: DetailRow(
                        id: "recipient-\(inn)",
                        icon: .symbol(
                            name: "building.2.fill",
                            tint: .white,
                            background: Color(hex: inn == "7730160480" ? 0x7557D3 : 0x2176C7)
                        ),
                        top: .primary(
                            inn == "7730160480"
                                ? "ГБОУ ОБРАЗОВАТЕЛЬНЫЙ ЦЕНТР «ПРОТОН»"
                                : "ГБОУ ШКОЛА № 1465"
                        ),
                        bottom: .secondary("ИНН \(inn)"),
                        showsChevron: false
                    ),
                    onTap: { applyQuickSuggestion(inn, for: field) }
                )
            }
        }
    }

    private func applyQuickSuggestion(_ suggestion: String, for field: FormField) {
        model.setValue(suggestion, for: field)

        guard model.spec.id == "requisites-budget",
              ["recipient-inn", "recipient-name", "recipient-kpp", "kbk"].contains(field.id) else {
            return
        }

        advanceGroupedSelection()
    }

    private func budgetSavedAccounts(_ field: FormField) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WBSpace.x2) {
                budgetSavedAccount(
                    title: "Леонид Б. · Ваш счёт",
                    account: field.suggestions.first ?? "03224643450000007300",
                    icon: "icBudgetSavedSelf",
                    iconSize: 14,
                    field: field
                )
                budgetSavedAccount(
                    title: "ОАНО ШКОЛА «НИКА»",
                    account: "40702810438000123456",
                    icon: "icBudgetSavedNika",
                    iconSize: 24,
                    field: field
                )
            }
        }
    }

    private func budgetSavedAccount(
        title: String,
        account: String,
        icon: String,
        iconSize: CGFloat,
        field: FormField
    ) -> some View {
        Button {
            Haptics.tap()
            model.setValue(account, for: field)
        } label: {
            HStack(spacing: WBSpace.x1) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: 0xFFDD2D))
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                }
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, WBSpace.x2)
            .frame(height: 38)
            .background(
                WBColor.bgMinus1,
                in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func quickSuggestionLabel(for field: FormField) -> String? {
        switch field.id {
        case "payer-code": "ваш код"
        case "account": "из недавних"
        case "recipient-inn": "ваш ИНН"
        case "recipient-kpp": "сохранённый КПП"
        case "recipient-name": "сохранённый получатель"
        case "kbk": "сохранённый КБК"
        case "oktmo": "сохранённый ОКТМО"
        default: nil
        }
    }

    /// Поиск банка — часть этапа, а не следующий экран и не radio-list. Человек
    /// может ввести либо название, либо БИК, затем один тап сразу фиксирует банк
    /// и запускает определение получателя по паре «счёт + банк».
    private func bankSearch(_ field: FormField) -> some View {
        let error = model.error(for: field, focused: focus)
        let results = field.bankOptions.filter { bank in
            let query = bankSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            return query.isEmpty
                || bank.title.localizedCaseInsensitiveContains(query)
                || bank.bic.contains(query)
        }

        return VStack(alignment: .leading, spacing: WBSpace.x2) {
            PipInput(
                field: field,
                format: .text(1...120),
                value: bankSearchBinding(for: field),
                focus: $focus,
                placeholder: inputPlaceholder(for: field),
                error: error
            )

            VStack(spacing: 0) {
                ForEach(results) { bank in
                    DetailRowView(
                        row: DetailRow(
                            id: bank.id,
                            icon: bank.icon,
                            top: .primary(bank.title),
                            bottom: .secondary("БИК \(bank.bic)"),
                            showsChevron: false
                        ),
                        onTap: {
                            bankSearchQuery = bank.title
                            model.pickBank(bank, for: field)
                            if model.spec.usesGroupedRequisites {
                                advanceGroupedSelection()
                            } else if let next = model.stage(after: field.id) {
                                activate(next)
                            } else {
                                openAmount()
                            }
                        }
                    )
                }
            }
        }
    }

    private func bankSearchBinding(for field: FormField) -> Binding<String> {
        Binding(
            get: { bankSearchQuery },
            set: { query in
                bankSearchQuery = query
                let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if let bank = field.bankOptions.first(where: {
                    $0.bic == normalized || $0.title.compare(normalized, options: .caseInsensitive) == .orderedSame
                }) {
                    model.pickBank(bank, for: field)
                } else {
                    model.setValue("", for: field)
                }
            }
        )
    }

    private var billPeriodSuggestions: [PeriodSuggestion] {
        var seen = Set<String>()
        return model.spec.bills.compactMap { bill in
            guard let value = monthValue(from: bill.period), seen.insert(value).inserted else { return nil }
            return PeriodSuggestion(id: value, title: bill.period, value: value)
        }
    }

    private func monthValue(from period: String) -> String? {
        let months = [
            "январь": "01", "февраль": "02", "март": "03", "апрель": "04",
            "май": "05", "июнь": "06", "июль": "07", "август": "08",
            "сентябрь": "09", "октябрь": "10", "ноябрь": "11", "декабрь": "12",
        ]
        let parts = period.lowercased().split(separator: " ")
        guard let month = parts.first.flatMap({ months[String($0)] }),
              let year = parts.last, year.count == 4, year.allSatisfy(\.isNumber) else { return nil }
        return "\(month).\(year)"
    }

    private var billsContent: some View {
        VStack(spacing: WBSpace.x3) {
            // Месячные группы разделены SPx2 = 8 pt. Внутри одной группы
            // начисления остаются единым, неразорванным списком.
            VStack(spacing: WBSpace.x2) {
                ForEach(billMonthGroups) { month in
                    VStack(spacing: 0) {
                        ForEach(month.bills) { bill in
                        Button {
                            Haptics.tap()
                            // Тап по начислению — короткий путь к оплате именно
                            // этого счёта; сначала даём человеку проверить, что
                            // именно выставил поставщик, и только потом платим.
                            model.selectBill(bill.id)
                            selectedBillForDetails = bill
                        } label: {
                                StageOperationLine(
                                    title: bill.title,
                                    subtitle: bill.period,
                                    trailing: AnyView(
                                        Text(Money.rub(bill.amount))
                                            .font(WBFont.title3)
                                            .foregroundStyle(WBColor.textPrimary)
                                            .multilineTextAlignment(.trailing)
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            // Это отдельная neutral-кнопка после списка начислений, а не часть
            // контейнера месячных групп: в Figma между ними SPx3 = 12 pt.
            Button("Ввести произвольную сумму") {
                model.selectBill(ServiceStages.customBillID)
                // После выбора custom `visibleFields` раскрывает этап периода.
                // Он обязателен до ручного ввода суммы, как в исходной версии.
                if let next = model.stage(after: ServiceStages.billsStageID) {
                    activate(next)
                } else {
                    openAmount()
                }
            }
                .font(WBFont.bodyAccent).foregroundStyle(WBColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(WBColor.bgMinus1, in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous))
                .buttonStyle(.plain)
        }
    }

    private var billMonthGroups: [BillMonthGroup] {
        model.spec.bills.reduce(into: []) { groups, bill in
            if let last = groups.indices.last, groups[last].period == bill.period {
                groups[last].bills.append(bill)
            } else {
                groups.append(BillMonthGroup(id: "\(bill.period)-\(groups.count)", period: bill.period, bills: [bill]))
            }
        }
    }

    // MARK: Переходы

    private func configureEntry() {
        guard activeStageID.isEmpty else { return }
        isResumeMode = resumesDraft
        if model.spec.usesGroupedRequisites {
            activeRequisitesGroupID = requisitesGroups.first { !isGroupComplete($0) }?.id
                ?? requisitesGroups.first?.id
                ?? ""
            selectFirstField()
        }
        let requestedStage = appliesDemoLaunchState ? SandboxSettings.startStage : nil
        activeStageID = stages.first(where: { $0.id == requestedStage })?.id
            ?? (resumesDraft ? model.firstIncompleteStage : stages.first)?.id
            ?? ""
        // Deep-link для контрольного кадра второй страницы. Демо-заполнение
        // приходит из host-вью на том же цикле layout, поэтому открываем cover
        // после него, а не показываем на мгновение пустой платёж.
        if model.spec.usesGroupedRequisites,
           requestedStage == ServiceFormModel.amountStepID {
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard model.isBackboneFilled else { return }
                openAmount()
            }
        }
        if model.spec.id == "requisites-budget", requestedStage == "review" {
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard model.isBackboneFilled else { return }
                overviewReturnGroupID = "payment"
                isReviewingAllBudgetData = true
                activeRequisitesFieldID = ""
                focus = nil
            }
        }
        if model.spec.id == "requisites-budget", requestedStage == "bank" {
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                if let account = model.spec.allFields.first(where: { $0.id == "account" }) {
                    model.setValue(account.suggestions.first ?? "03224643450000007300", for: account)
                }
                activeRequisitesGroupID = "bank"
                activeRequisitesFieldID = "bank"
                focusGroupedInput(after: 180)
            }
        }
        if model.spec.id == "requisites-budget",
           requestedStage == "recipient" || requestedStage == "recipient-missing-kbk" {
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                prepareBudgetRequisitesBackbone()
                if requestedStage == "recipient-missing-kbk",
                   let inn = model.spec.allFields.first(where: { $0.id == "recipient-inn" }) {
                    model.setValue("7730160488", for: inn)
                }
                activeRequisitesGroupID = "recipient"
                activeRequisitesFieldID = ""
                focus = nil
            }
        }
        if model.spec.id == "requisites-budget", requestedStage == "payment-error" {
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                prepareBudgetRequisitesBackbone()
                if let inn = model.spec.allFields.first(where: { $0.id == "recipient-inn" }) {
                    model.setValue("7730160480", for: inn)
                }
                if let oktmo = model.spec.allFields.first(where: { $0.id == "oktmo" }) {
                    model.setValue("12", for: oktmo)
                    model.markTouched(oktmo.id)
                }
                activeRequisitesGroupID = "payment"
                activeRequisitesFieldID = "oktmo"
                focus = nil
            }
        }
        if appliesDemoLaunchState,
           let billID = SandboxSettings.startBillID,
           let bill = model.spec.bills.first(where: { $0.id == billID }) {
            if let payerCode = model.spec.allFields.first(where: { $0.id == "payer-code" }),
               let demoCode = payerCode.suggestions.first {
                model.setValue(demoCode, for: payerCode)
            }
            model.selectBill(bill.id)
            // Только для deep-link-съёмки: даём базовому экрану закончить первый
            // layout, иначе iOS захватывает кадр посередине transition cover'а.
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                selectedBillForDetails = bill
            }
        }
        if model.spec.usesGroupedRequisites {
            focusGroupedInput(after: 320)
        } else {
            focusActiveInput(after: 320)
        }
    }

    private func prepareBudgetRequisitesBackbone() {
        if let account = model.spec.allFields.first(where: { $0.id == "account" }) {
            model.setValue(account.suggestions.first ?? "03224643450000007300", for: account)
        }
        if let bank = model.spec.allFields.first(where: { $0.id == "bank" }),
           let option = bank.bankOptions.first {
            model.pickBank(option, for: bank)
        }
    }

    private func activate(_ stage: PaymentStage) {
        withAnimation(.snappy(duration: 0.28)) { activeStageID = stage.id }
        focusActiveInput(after: 180)
    }

    private func continueFlow() {
        guard let stage = activeStage else { return }
        if let field = stage.field {
            model.markTouched(field.id)
            guard model.error(for: field, focused: nil) == nil else { return }
        }
        if case .bills = stage.kind {
            // Явная CTA на списке всегда означает «оплатить все начисления».
            // Конкретный счёт выбирается только прямым тапом по его строке.
            model.selectBill(ServiceStages.allBillsID)
            openAmount()
            return
        }
        if let next = model.stage(after: stage.id) { activate(next) }
        else { openAmount() }
    }

    private func goBack() {
        if model.spec.usesGroupedRequisites {
            if isReviewingAllBudgetData {
                isReviewingAllBudgetData = false
                let returnID = overviewReturnGroupID.isEmpty ? "payment" : overviewReturnGroupID
                overviewReturnGroupID = ""
                if let returnGroup = requisitesGroups.first(where: { $0.id == returnID }) {
                    activeRequisitesGroupID = returnGroup.id
                    selectFirstUnfilledField()
                }
                focusGroupedInput(after: 180)
                return
            }
            if isReviewingRequisitesGroup {
                isReviewingRequisitesGroup = false
                if let group = activeRequisitesGroup {
                    activeRequisitesFieldID = interactiveFields(in: group).last?.id ?? ""
                }
                focusGroupedInput(after: 180)
                return
            }
            guard let current = activeRequisitesGroup,
                  let field = activeField(in: current),
                  let fieldIndex = interactiveFields(in: current).firstIndex(where: { $0.id == field.id })
            else {
                onBack()
                return
            }
            if fieldIndex > 0 {
                activeRequisitesFieldID = interactiveFields(in: current)[fieldIndex - 1].id
                focusGroupedInput(after: 180)
                return
            }
            guard let groupIndex = requisitesGroups.firstIndex(where: { $0.id == current.id }), groupIndex > 0 else {
                onBack()
                return
            }
            let previousGroup = requisitesGroups[groupIndex - 1]
            activeRequisitesGroupID = previousGroup.id
            activeRequisitesFieldID = interactiveFields(in: previousGroup).last?.id ?? ""
            focusGroupedInput(after: 180)
            return
        }
        guard let stage = activeStage, let previous = model.stage(before: stage.id) else {
            onBack()
            return
        }
        activate(previous)
    }

    private func openAmount() {
        focus = nil
        isAmountPresented = true
    }

    private func focusActiveInput(after milliseconds: Int) {
        guard let field = activeStage?.field, case .input = field.kind else {
            focus = nil
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(milliseconds))
            focus = field.id
        }
    }

    private func continueGroupedRequisites() {
        guard let group = activeRequisitesGroup else { return }
        if isBudgetRecipientGroup(group), activeRequisitesFieldID.isEmpty {
            if isGroupComplete(group) {
                moveToNextGroup(after: group)
            } else {
                selectFirstUnfilledField()
                focusGroupedInput(after: 180)
            }
            return
        }
        if isReviewingRequisitesGroup {
            let fields = groupFields(group).filter(\.isRequired)
            for field in fields { model.markTouched(field.id) }
            guard fields.allSatisfy({ model.error(for: $0, focused: nil) == nil }) else { return }
            isReviewingRequisitesGroup = false
            moveToNextGroup(after: group)
            return
        }
        // У группы может быть десять обязательных полей, но проверяем только
        // текущий шаг. Иначе после номера счёта мы бы требовали выбрать банк,
        // который ещё даже не показали.
        let fields: [FormField]
        if showsWholeBudgetGroup(group) {
            fields = groupFields(group).filter(\.isRequired)
        } else if let field = activeField(in: group) {
            fields = [field]
        } else {
            fields = groupFields(group).filter(\.isRequired)
        }
        for field in fields { model.markTouched(field.id) }
        guard fields.allSatisfy({ model.error(for: $0, focused: nil) == nil }) else {
            if let invalid = fields.first(where: { model.error(for: $0, focused: nil) != nil })?.id {
                focus = invalid
            }
            return
        }
        advanceGroupedSelection(forceNextGroup: true)
    }

    private func advanceGroupedSelection(forceNextGroup: Bool = false) {
        guard let group = activeRequisitesGroup else { return }
        let fields = interactiveFields(in: group)
        if isBudgetRecipientGroup(group) {
            if isGroupComplete(group) {
                // Справочник вернул КБК — дополнительная сверка не нужна.
                moveToNextGroup(after: group)
            } else {
                // ИНН/название/КПП могли заполнить друг друга. Возвращаемся в
                // сводку, где остаётся ровно тот реквизит, которого не знаем.
                activeRequisitesFieldID = ""
                focus = nil
            }
            return
        }
        if !showsWholeBudgetGroup(group),
           let current = activeField(in: group),
           let index = fields.firstIndex(where: { $0.id == current.id }),
           index + 1 < fields.count {
            // Даже уже заполненное полем значение остаётся самостоятельным
            // шагом: бэкенд мог подставить КПП и название, но человек должен
            // увидеть и при необходимости исправить каждое из них.
            activeRequisitesFieldID = fields[index + 1].id
            focusGroupedInput(after: 180)
            return
        }
        guard isGroupComplete(group) else {
            selectFirstUnfilledField()
            focusGroupedInput(after: 80)
            return
        }
        // В бюджетной ветке отдельная сверка каждой группы не нужна: макет
        // собирает плательщика и платёж на едином финальном экране «Все данные».
        if model.spec.id == "requisites-budget" {
            guard let index = requisitesGroups.firstIndex(where: { $0.id == group.id }) else { return }
            if index == requisitesGroups.count - 1 {
                overviewReturnGroupID = group.id
                isReviewingAllBudgetData = true
                activeRequisitesFieldID = ""
                focus = nil
            } else {
                moveToNextGroup(after: group)
            }
            return
        }
        // Каждая завершённая смысловая группа сначала показывается заполненной:
        // получатель, плательщик и параметры платежа проверяются до перехода к
        // следующей. Это те же заполненные inputs, а не текстовая сводка.
        if group.id != "bank" {
            isReviewingRequisitesGroup = true
            activeRequisitesFieldID = ""
            focus = nil
        } else {
            moveToNextGroup(after: group)
        }
    }

    private func moveToNextGroup(after group: FormSection) {
        guard let index = requisitesGroups.firstIndex(where: { $0.id == group.id }),
              index + 1 < requisitesGroups.count
        else {
            openAmount()
            return
        }
        activeRequisitesGroupID = requisitesGroups[index + 1].id
        selectFirstField()
        focusGroupedInput(after: 180)
    }

    private func selectFirstField() {
        guard let group = activeRequisitesGroup else {
            activeRequisitesFieldID = ""
            return
        }
        activeRequisitesFieldID = isBudgetRecipientGroup(group)
            ? ""
            : interactiveFields(in: group).first?.id ?? ""
    }

    private func selectFirstUnfilledField() {
        guard let group = activeRequisitesGroup else {
            activeRequisitesFieldID = ""
            return
        }
        activeRequisitesFieldID = interactiveFields(in: group)
            .first(where: { !model.isFilled($0) })?.id
            ?? ""
    }

    private func focusGroupedInput(after milliseconds: Int) {
        guard let group = activeRequisitesGroup,
              !(isBudgetRecipientGroup(group) && activeRequisitesFieldID.isEmpty),
              let field = activeField(in: group),
              case .input = field.kind
        else {
            focus = nil
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(milliseconds))
            focus = field.id
        }
    }
}

@MainActor
private func stageProgressFraction(stages: [PaymentStage], activeStageID: String) -> CGFloat {
    guard !stages.isEmpty,
          let currentIndex = stages.firstIndex(where: { $0.id == activeStageID })
    else { return 0 }
    return min(max(CGFloat(currentIndex) / CGFloat(stages.count), 0), 1)
}

private func topTheme(for spec: ServiceSpec) -> PipFigmaTop.Theme {
    if spec.usesGroupedRequisites {
        return .requisites
    }

    let category = spec.category.components(separatedBy: " · ").first ?? spec.category
    switch category {
    case "ЖКХ":
        return .utilities
    case "Интернет и ТВ":
        return .telecom
    case "Транспорт":
        return .transport
    case "Госплатежи":
        return .government
    case "Переводы по реквизитам":
        return .requisites
    default:
        return .requisites
    }
}

private struct RequisitesProgress {
    let fraction: CGFloat

    init(fraction: CGFloat) {
        self.fraction = min(max(fraction, 0), 1)
    }
}

/// Базовая строка списков в пошаговой оплате. Вариативны только контент справа
/// и наличие подзаголовка; типографика, межстрочный интервал и вертикальные
/// отступы во всех сценариях совпадают с OperationLine.
private struct StageOperationLine: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .top, spacing: WBSpace.x3) {
            VStack(alignment: .leading, spacing: WBSpace.x0_5) {
                Text(title)
                    .font(WBFont.title3)
                    .foregroundStyle(WBColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if let trailing { trailing }
        }
        // Единый для list item и OperationLine вертикальный padding — 12 pt.
        .padding(.vertical, WBSpace.x3)
        .contentShape(Rectangle())
    }
}

/// Промежуточная страница одного начисления. Список отвечает на вопрос «что
/// оплатить», а здесь человек сначала видит, что именно прислал поставщик, и
/// подтверждает переход к оплате уже осознанно.
private struct ChargeDetailsScreen: View {
    let model: ServiceFormModel
    let bill: ChargeBill
    var onBack: () -> Void
    var onClose: () -> Void
    var onContinue: () -> Void
    @State private var isAboutSheetPresented = false

    private var provider: ProviderCard { model.headerProvider }
    private var isDebt: Bool {
        bill.title.localizedCaseInsensitiveContains("долгов")
    }
    private var payerCode: String {
        model.values["payer-code"] ?? "—"
    }
    private var explanationTitle: String {
        isDebt ? "Долговой счёт" : "Текущий счёт"
    }
    private var explanation: String {
        if isDebt {
            return "Это непогашенная сумма за \(bill.period). Данные получены напрямую от поставщика. Если долг уже оплачен или не относится к вам, уточните информацию в управляющей компании."
        }
        return "Начисление за \(bill.period). Мы получили его напрямую от поставщика услуг — сумма может меняться после корректировки квитанции."
    }

    var body: some View {
        VStack(spacing: 0) {
            PipFigmaTop(
                type: .provider,
                showsScanButton: false,
                titleText: provider.title,
                theme: topTheme(for: model.spec),
                onBack: onBack,
                onClose: onClose
            )
            .frame(maxWidth: .infinity)

            content
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .background(WBColor.bgMinus1, ignoresSafeAreaEdges: .all)
        .sheet(isPresented: $isAboutSheetPresented) {
            ChargeAboutSheet(
                title: explanationTitle,
                explanation: explanation,
                providerName: provider.title,
                onClose: { isAboutSheetPresented = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: WBSpace.x1) {
                        Text(bill.title)
                            .font(WBFont.hauss(28, .bold))
                            .foregroundStyle(WBColor.textPrimary)
                        Text("За \(bill.period)")
                            .font(WBFont.body)
                            .foregroundStyle(WBColor.textSecondary)
                        if let issuedAt = bill.issuedAt {
                            Text("Начислено \(issuedAt)")
                                .font(WBFont.description)
                                .foregroundStyle(WBColor.controlsTertiary)
                        }
                        Text(Money.rub(bill.amount))
                            .font(WBFont.hauss(32, .bold))
                            .foregroundStyle(WBColor.textPrimary)
                            .padding(.top, WBSpace.x3)
                    }

                    VStack(alignment: .leading, spacing: WBSpace.x3) {
                        Text("О начислении")
                            .font(WBFont.bodyAccent)
                            .foregroundStyle(WBColor.textPrimary)

                        VStack(spacing: 0) {
                            detail("Код плательщика", payerCode)
                            detail("Поставщик", provider.title)
                            Button {
                                Haptics.tap()
                                isAboutSheetPresented = true
                            } label: {
                                HStack(spacing: WBSpace.x3) {
                                    VStack(alignment: .leading, spacing: WBSpace.x0_5) {
                                        Text(explanationTitle)
                                            .font(WBFont.bodyAccent)
                                            .foregroundStyle(WBColor.textPrimary)
                                        Text("Подробнее")
                                            .font(WBFont.descriptionAccent)
                                            .foregroundStyle(WBColor.textAccent)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(WBColor.textSecondary)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, WBSpace.x3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, WBSpace.x4)
                        .padding(.vertical, WBSpace.x1)
                        .background(WBColor.bgMinus1, in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WBSpace.x4)
                .padding(.top, 24)
                .padding(.bottom, WBSpace.x4)
            }

            PipFigmaStickyBar(
                type: .default,
                title: "Продолжить",
                progressFraction: 1,
                onContinue: {
                    Haptics.tap()
                    onContinue()
                },
                onStepsTap: {
                    Haptics.tap()
                    onBack()
                }
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            PipTopCornersShape(radius: WBRadius.x6)
                .fill(WBColor.bgBase)
                .ignoresSafeArea(edges: .bottom)
        }
        .clipShape(PipTopCornersShape(radius: WBRadius.x6))
    }

    @ViewBuilder
    private func detail(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: WBSpace.x3) {
            Text(title)
                .font(WBFont.description)
                .foregroundStyle(WBColor.textSecondary)
            Spacer(minLength: WBSpace.x3)
            Text(value)
                .font(WBFont.bodyAccent)
                .foregroundStyle(WBColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, WBSpace.x3)
    }
}

/// Подробности не занимают место в первичном решении «оплачивать или нет», но
/// всегда доступны по явному тапу по краткому типу начисления.
private struct ChargeAboutSheet: View {
    let title: String
    let explanation: String
    let providerName: String
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x4) {
            HStack(spacing: WBSpace.x3) {
                Text(title)
                    .font(WBFont.title1)
                    .foregroundStyle(WBColor.textPrimary)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WBColor.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(WBColor.bgMinus1, in: Circle())
                }
                .buttonStyle(.plain)
            }
            Text(explanation)
                .font(WBFont.body)
                .foregroundStyle(WBColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Данные передал \(providerName)")
                .font(WBFont.description)
                .foregroundStyle(WBColor.controlsTertiary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WBSpace.x4)
        .padding(.top, WBSpace.x2)
    }
}

private struct BillMonthGroup: Identifiable {
    let id: String
    let period: String
    var bills: [ChargeBill]
}

private struct PeriodSuggestion: Identifiable {
    let id: String
    let title: String
    let value: String
}

private struct BudgetFieldHintSheet: View {
    let field: FormField
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x3) {
            HStack {
                Text(field.label)
                    .font(WBFont.hauss(20, .bold))
                    .foregroundStyle(WBColor.textPrimary)
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WBColor.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(WBColor.bgMinus1, in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text(field.hint ?? field.formatTitle)
                .font(WBFont.body)
                .foregroundStyle(WBColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(WBSpace.x4)
        .background(WBColor.bgBase)
    }
}

/// Точный фон первых двух кадров бюджетных реквизитов из Figma 49681:597126:
/// сине-чёрный эллиптический radial-gradient и затемнение накладываются отдельно.
private struct BudgetRequisitesEntryGradient: View {
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            let horizontalRadius = size.width * (386.75 / 390)
            let scaleX = horizontalRadius / height
            let localWidth = size.width / scaleX
            let path = Path(CGRect(x: 0, y: 0, width: localWidth, height: height))

            context.scaleBy(x: scaleX, y: 1)
            context.fill(
                path,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(hex: 0x008ED6), location: 0),
                        .init(color: Color(hex: 0x006CA3), location: 0.22837),
                        .init(color: Color(hex: 0x004A70), location: 0.45673),
                        .init(color: Color(hex: 0x003957), location: 0.59255),
                        .init(color: Color(hex: 0x00283D), location: 0.72837),
                        .init(color: Color(hex: 0x001824), location: 0.86418),
                        .init(color: Color(hex: 0x000F17), location: 0.93209),
                        .init(color: Color(hex: 0x00070A), location: 1),
                    ]),
                    center: CGPoint(x: localWidth / 2, y: 0),
                    startRadius: 0,
                    endRadius: height
                )
            )
        }
    }
}

/// Белый контент в макете только верхними углами заходит на брендированную шапку.
/// Фигура один в один повторяет `gradientTransform` узла 48346:48544:
/// центр в середине верхней грани, RX = 386,75 и RY = 176 для фрейма 390×176.
/// `coreRadius` — радиус центрального блика до начала растяжения, в точках по Y.
private struct ProviderBrandGradient: View {
    let base: Color
    let height: CGFloat
    var coreRadius: CGFloat

    var body: some View {
        Canvas { context, size in
            // Горизонтальная полуось в Figma равна 386,75 / 390 ширины кадра.
            // Вертикальная всегда совпадает с высотой градиентного слоя.
            let horizontalRadius = size.width * (386.75 / 390)
            let scaleX = horizontalRadius / height
            let localWidth = size.width / scaleX
            let path = Path(CGRect(x: 0, y: 0, width: localWidth, height: height))

            context.scaleBy(x: scaleX, y: 1)
            context.fill(
                path,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: base.adjustingHSLightness(by: 0.20), location: 0),
                        .init(color: base.adjustingHSLightness(by: 0.10), location: 0.28871),
                        .init(color: base, location: 0.57743),
                        .init(color: base.adjustingHSLightness(by: -0.10), location: 0.78871),
                        .init(color: base.adjustingHSLightness(by: -0.20), location: 1),
                    ]),
                    center: CGPoint(x: localWidth / 2, y: 0),
                    startRadius: coreRadius,
                    endRadius: height
                )
            )
        }
    }
}

private extension Color {
    /// Сдвиг HSL lightness сохраняет оттенок и насыщенность бренда — в отличие от
    /// смешивания с белым/чёрным, которое грязнит насыщенные фирменные цвета.
    func adjustingHSLightness(by delta: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }

        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let lightness = (maximum + minimum) / 2
        let difference = maximum - minimum
        guard difference > 0 else {
            let value = min(max(lightness + delta, 0), 1)
            return Color(.sRGB, white: value, opacity: alpha)
        }

        let saturation = difference / (1 - abs(2 * lightness - 1))
        var hue: CGFloat
        if maximum == red {
            hue = ((green - blue) / difference).truncatingRemainder(dividingBy: 6)
        } else if maximum == green {
            hue = (blue - red) / difference + 2
        } else {
            hue = (red - green) / difference + 4
        }
        hue = (hue / 6 + 1).truncatingRemainder(dividingBy: 1)

        let resultLightness = min(max(lightness + delta, 0), 1)
        let chroma = (1 - abs(2 * resultLightness - 1)) * saturation
        let x = chroma * (1 - abs((hue * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = resultLightness - chroma / 2
        let sector = hue * 6
        let rgb: (CGFloat, CGFloat, CGFloat)
        switch sector {
        case 0..<1: rgb = (chroma, x, 0)
        case 1..<2: rgb = (x, chroma, 0)
        case 2..<3: rgb = (0, chroma, x)
        case 3..<4: rgb = (0, x, chroma)
        case 4..<5: rgb = (x, 0, chroma)
        default: rgb = (chroma, 0, x)
        }
        return Color(.sRGB, red: rgb.0 + m, green: rgb.1 + m, blue: rgb.2 + m, opacity: alpha)
    }
}
