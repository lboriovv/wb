import SwiftUI

/// Корень песочницы: только разделы, как папки. Тап открывает страницу раздела,
/// внутри — его варианты.
struct SandboxRoot: View {
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            List(SandboxCatalog.rootSections) { section in
                NavigationLink(value: section.id) {
                    sectionRow(section)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("WB Sandbox")
            .navigationDestination(for: String.self) { sectionID in
                SandboxSectionScreen(sectionID: sectionID)
            }
        }
        .onAppear(perform: openDeepLink)
    }

    private func sectionRow(_ section: SandboxSection) -> some View {
        HStack(spacing: WBSpace.x3) {
            Image(systemName: section.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(WBColor.textAccent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(WBFont.title3)
                    .foregroundStyle(WBColor.textPrimary)
                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                }
            }

            Spacer(minLength: WBSpace.x2)

            Text("\(section.items.count)")
                .font(WBFont.description)
                .foregroundStyle(WBColor.textSecondary)
        }
        .padding(.vertical, WBSpace.x1)
    }

    /// `-demoOpen transfer` открывает страницу раздела,
    /// `-demoOpen transfer/by-phone` — сразу конкретный вариант.
    private func openDeepLink() {
        guard path.isEmpty, let raw = SandboxSettings.openPath else { return }
        let parts = raw.split(separator: "/").map(String.init)
        guard let sectionID = parts.first,
              SandboxCatalog.sections.contains(where: { $0.id == sectionID })
        else { return }
        path = [sectionID]
    }
}

// MARK: - Страница раздела

/// Список вариантов внутри раздела. Сами экраны показываются модально, а не
/// пушем: скрытие системного навбара у пуша меняет верхний safe-area inset, и
/// экран с собственной шапкой начинал уезжать под вырез.
struct SandboxSectionScreen: View {
    let sectionID: String

    @State private var presented: SandboxItem?
    @State private var didHandleDeepLink = false
    /// Счётчик открытий. Идёт в `.id()` показанного экрана, поэтому каждый заход
    /// создаёт состояние заново: остатки прошлого прохода в тестах читаются как
    /// баг прототипа, а не как «мы помним, что вы вводили».
    @State private var openCount = 0

    private var section: SandboxSection? {
        SandboxCatalog.sections.first { $0.id == sectionID }
    }

    private var childSections: [SandboxSection] {
        (section?.childSectionIDs ?? []).compactMap { childID in
            SandboxCatalog.sections.first { $0.id == childID }
        }
    }

    var body: some View {
        List {
            ForEach(childSections) { child in
                NavigationLink(value: child.id) {
                    sectionRow(child)
                }
            }

            ForEach(section?.items ?? []) { item in
                Button {
                    openCount += 1
                    presented = item
                } label: {
                    row(item)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(section?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $presented) { item in
            screen(for: item)
                .id(openCount)
        }
        // Deep link читаем здесь, а не прокидываем состоянием из корня: при
        // одновременной установке пути и состояния модалка не успевала открыться.
        .onAppear {
            guard !didHandleDeepLink else { return }
            didHandleDeepLink = true
            guard let raw = SandboxSettings.openPath else { return }
            let parts = raw.split(separator: "/").map(String.init)
            guard parts.count > 1, parts[0] == sectionID else { return }
            presented = section?.items.first { $0.id == parts[1] }
        }
    }

    private func row(_ item: SandboxItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textPrimary)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                }
            }
            Spacer(minLength: WBSpace.x2)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WBColor.textSecondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func sectionRow(_ section: SandboxSection) -> some View {
        HStack(spacing: WBSpace.x3) {
            Image(systemName: section.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(WBColor.textAccent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textPrimary)
                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func screen(for item: SandboxItem) -> some View {
        switch item.destination {
        case .transaction(let config):
            TransactionHost(config: config, onBack: { presented = nil })

        case .outcome(let scenario):
            OutcomeScreen(
                scenario: scenario,
                amount: scenario.amount ?? scenario.source.initialAmount,
                badge: scenario.badge,
                onClose: { presented = nil }
            )

        case .postcards(let cards):
            PostcardPickerScreen(
                cards: cards,
                onSelect: { _ in presented = nil },
                onClose: { presented = nil }
            )

        case .postcardGift(let cards):
            PostcardGiftScreen(
                cards: cards,
                onThanks: { presented = nil },
                onClose: { presented = nil }
            )

        case .postcardGiftEnvelope(let cards):
            PostcardEnvelopeGiftScreen(
                cards: cards,
                onThanks: { presented = nil },
                onClose: { presented = nil }
            )

        case .serviceForm(let spec):
            ServiceFormHost(spec: spec, onBack: { presented = nil })

        case .serviceStages(let spec):
            ServiceStagesHost(spec: spec, onBack: { presented = nil })

        case .serviceStagesWork(let spec):
            ServiceStagesWorkHost(
                spec: spec,
                appliesDemoLaunchState: openCount == 0,
                onBack: { presented = nil }
            )

        case .serviceMatrix:
            ServiceMatrixScreen { presented = nil }

        case .uniQRBetweenAccountsTransition:
            UniQRScreen(
                onBack: { presented = nil },
                configuration: .betweenAccountsTransition
            )

        case .iconMorph:
            NavigationStack {
                IconMorphScreen()
                    .navigationTitle("Морф иконок")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Закрыть") { presented = nil }
                        }
                    }
            }
        }
    }
}

// MARK: - Владелец модели сложной формы

/// Держит состояние формы и спеку рядом: спека открывается шитом поверх формы,
/// чтобы сверять таблицу с экраном не по памяти.
private struct ServiceFormHost: View {
    @State private var model: ServiceFormModel
    @State private var isSpecPresented = false
    private let onBack: () -> Void

    init(spec: ServiceSpec, onBack: @escaping () -> Void) {
        _model = State(initialValue: ServiceFormModel(spec: spec))
        self.onBack = onBack
    }

    var body: some View {
        ServicePaymentScreen(
            model: model,
            onBack: onBack,
            onOpenSpec: { isSpecPresented = true }
        )
        .sheet(isPresented: $isSpecPresented) {
            ServiceSpecSheet(spec: model.spec) { isSpecPresented = false }
        }
        .onAppear {
            if SandboxSettings.fillsForms { model.fillWithDemoData() }
            applyStartStep()
        }
    }

    /// `-demoStep 3` открывает третий шаг, `-demoStep last` — последний.
    private func applyStartStep() {
        guard let raw = SandboxSettings.startStep else { return }
        let steps = model.steps
        if raw == "last" {
            model.currentStepID = steps.last?.id ?? model.currentStepID
            return
        }
        guard let number = Int(raw), number >= 1, number <= steps.count else { return }
        model.currentStepID = steps[number - 1].id
    }
}

// MARK: - Владелец модели формы с этапами

/// Та же `ServiceFormModel`, что у карты формы: концепции отличаются экраном, а не
/// данными. Поэтому спеку переписывать не пришлось — ЖКУ Москвы один и тот же в
/// обоих разделах, и сравнивать их можно на одинаковом платеже.
private struct ServiceStagesHost: View {
    @State private var model: ServiceFormModel
    @State private var isSpecPresented = false
    private let onBack: () -> Void

    init(spec: ServiceSpec, onBack: @escaping () -> Void) {
        _model = State(initialValue: ServiceFormModel(spec: spec))
        self.onBack = onBack
    }

    var body: some View {
        ServiceStagesScreen(
            model: model,
            onBack: onBack,
            onOpenSpec: { isSpecPresented = true }
        )
        .sheet(isPresented: $isSpecPresented) {
            ServiceSpecSheet(spec: model.spec) { isSpecPresented = false }
        }
        .onAppear {
            if SandboxSettings.fillsForms { model.fillWithDemoData() }
        }
    }
}

/// Владелец отдельной рабочей ветки UI этапов. Состояние платежа создаётся
/// независимо от основной версии, поэтому сценарии можно открывать рядом.
private struct ServiceStagesWorkHost: View {
    @State private var model: ServiceFormModel
    @State private var isSpecPresented = false
    private let appliesDemoLaunchState: Bool
    private let onBack: () -> Void

    init(
        spec: ServiceSpec,
        appliesDemoLaunchState: Bool,
        onBack: @escaping () -> Void
    ) {
        _model = State(initialValue: ServiceFormModel(spec: spec))
        self.appliesDemoLaunchState = appliesDemoLaunchState
        self.onBack = onBack
    }

    var body: some View {
        ServiceStagesWorkScreen(
            model: model,
            resumesDraft: appliesDemoLaunchState && SandboxSettings.resumesDraft,
            appliesDemoLaunchState: appliesDemoLaunchState,
            onBack: onBack,
            onOpenSpec: { isSpecPresented = true }
        )
        .sheet(isPresented: $isSpecPresented) {
            ServiceSpecSheet(spec: model.spec) { isSpecPresented = false }
        }
        .onAppear {
            if appliesDemoLaunchState && SandboxSettings.fillsForms {
                model.fillWithDemoData()
            }
        }
    }
}

// MARK: - Владелец модели транзакционного экрана

/// Держит `TransactionModel` в `@State`, чтобы состояние жило между перерисовками.
private struct TransactionHost: View {
    @State private var model: TransactionModel
    private let onBack: () -> Void

    init(config: TransactionConfig, onBack: @escaping () -> Void) {
        _model = State(initialValue: TransactionModel(config: config))
        self.onBack = onBack
    }

    var body: some View {
        TransactionScreen(model: model, onBack: onBack)
            .onAppear(perform: applyLaunchState)
    }

    private func applyLaunchState() {
        if let amount = SandboxSettings.startAmount {
            model.applyQuickAmount(amount)
        }
        if let account = SandboxSettings.startAccount {
            model.selectAccount(account)
        }
        if SandboxSettings.startsWithSheet {
            model.isAccountSheetPresented = true
        }
        if SandboxSettings.startsWithOutcome {
            model.isOutcomePresented = true
        }
    }
}
