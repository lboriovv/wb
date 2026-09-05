import SwiftUI

/// Экран 2 концепции с этапами: сумма и оплата. Макеты 48133:30406 (все счета),
/// 48142:113773 (один счёт) и 48142:114753 (произвольная сумма).
///
/// Здесь ничего не заполняют. Экран отвечает на два вопроса: сколько списывают и
/// куда это уйдёт, — поэтому сумма стоит одна на весь экран, а под ней две плитки
/// «откуда → куда». Данные пришли с экрана этапов; менять их возвращаются туда.
///
/// Клавиатура появляется только у произвольной суммы: у выставленного счёта сумма
/// не редактируется, и мигающая каретка над ней обещала бы обратное.
struct ServiceAmountScreen: View {
    @Bindable var model: ServiceFormModel
    var appliesDemoLaunchState = false
    var onBack: () -> Void = {}
    /// Завершить весь платёжный сценарий и вернуться в каталог типов переводов.
    var onFinish: () -> Void = {}
    var onOpenSpec: () -> Void = {}

    @FocusState private var isAmountFocused: Bool
    @State private var isUrgent = false
    @State private var isFinishing = false

    private var spec: ServiceSpec { model.spec }
    private var recipient: ProviderCard { model.headerProvider }
    /// Произвольная сумма бывает не только после кнопки «Ввести произвольную
    /// сумму» у начисления. Перевод по реквизитам изначально не имеет счёта от
    /// поставщика, поэтому его свободную сумму тоже вводят прямо здесь.
    private var isEditableAmount: Bool {
        model.isCustomAmount || (spec.bills.isEmpty && model.isAmountEditable)
    }

    var body: some View {
        VStack(spacing: 0) {
            WBNavBar(title: model.payTitle, leading: .back, onLeading: onBack)
                .background(WBColor.bgBase)

            Spacer(minLength: 0)

            amount

            Spacer(minLength: 0)

            VStack(spacing: WBSpace.x3) {
                tiles
                if spec.id == "requisites-budget" { urgentTransfer }
                WBPrimaryButton(title: "Перевести", subtitle: feeNote) {
                    Haptics.tap()
                    model.isOutcomePresented = true
                }
                if spec.id == "requisites-budget" {
                    Text(recipient.timing)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                }
            }
            .padding(.horizontal, WBSpace.x4)
            .padding(.bottom, WBSpace.x2)
        }
        .background(WBColor.bgBase, ignoresSafeAreaEdges: .all)
        .sheet(isPresented: $model.isMethodSheetPresented) {
            AccountPickerSheet(
                accounts: model.accounts,
                selectedID: model.selectedAccountID
            ) { id in
                model.selectedAccountID = id
                model.isMethodSheetPresented = false
            }
        }
        .fullScreenCover(isPresented: $model.isOutcomePresented) {
            OutcomeScreen(
                scenario: model.outcomeScenario,
                amount: model.total + urgentFee,
                badge: amountFeeBadge,
                onClose: finishFlow
            )
        }
        .onAppear {
            // Сумма выставленного счёта приходит с прошлого экрана и правке не
            // подлежит; произвольную набирают здесь, поэтому поле сразу в фокусе.
            if model.isCustomAmount {
                model.startCustomAmount()
            } else if !isEditableAmount {
                model.applyQuickAmount(model.stagesAmount)
            }
            if isEditableAmount {
                isAmountFocused = true
            }
            if appliesDemoLaunchState && SandboxSettings.startsWithOutcome {
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    model.isOutcomePresented = true
                }
            }
        }
    }

    private func finishFlow() {
        guard !isFinishing else { return }
        isFinishing = true
        model.isOutcomePresented = false
        // Сначала закрываем экран результата, затем внешний payment-cover.
        // Одновременное снятие двух fullScreenCover даёт короткий белый кадр.
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            onFinish()
            isFinishing = false
        }
    }

    // MARK: - Сумма

    private var amount: some View {
        HStack(alignment: .firstTextBaseline, spacing: WBSpace.x1) {
            if isEditableAmount {
                TextField("0", text: Binding(
                    get: { model.amount.displayInteger + (model.amount.displayFraction ?? "") },
                    set: { model.setAmount($0) }
                ))
                .font(WBFont.balance)
                .foregroundStyle(WBColor.textPrimary)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .tint(WBColor.textAccent)
                .focused($isAmountFocused)
                .fixedSize()
            } else {
                Text(Money.plain(model.baseAmount))
                    .font(WBFont.balance)
                    .foregroundStyle(WBColor.textPrimary)
                    .contentTransition(.numericText())
            }

            Text("₽")
                .font(WBFont.balance)
                .foregroundStyle(WBColor.controlsTertiary)
        }
        .frame(height: WBLineHeight.balance)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditableAmount else { return }
            isAmountFocused = true
        }
        .animation(.snappy(duration: 0.2), value: model.baseAmount)
    }

    /// Вторая строка кнопки: комиссия считается от набранной суммы, поэтому
    /// «Без комиссии» и «Комиссия 5,89 ₽» — одно и то же место, а не два разных.
    private var feeNote: String {
        amountFeeBadge.text
    }

    private var urgentFee: Decimal { isUrgent ? 199 : 0 }

    private var amountFeeBadge: BadgeSpec {
        let value = model.feeValue + urgentFee
        guard value > 0 else { return spec.fee.badge(for: model.subtotal) }
        return BadgeSpec(text: "Комиссия \(Money.plain(value))\(Money.nbsp)₽", style: .greenSoft)
    }

    // MARK: - Откуда и куда

    /// Две плитки со стрелкой между ними: слева счёт списания, справа поставщик.
    /// Стрелка нужна не для красоты — она отвечает на «в какую сторону уйдут
    /// деньги» до нажатия кнопки.
    private var tiles: some View {
        HStack(spacing: 0) {
            Button {
                Haptics.tap()
                model.isMethodSheetPresented = true
            } label: {
                tile(background: WBColor.bgPurpleLight) {
                    if let account = model.selectedAccount {
                        RowIconView(icon: account.icon, size: 24)
                        Text(account.amountTitle)
                            .font(WBFont.descriptionAccent)
                            .foregroundStyle(WBColor.textPrimary)
                        Text(spec.id == "requisites-budget" ? "WB Кошелёк" : account.subtitle)
                            .font(WBFont.description)
                            .foregroundStyle(WBColor.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WBColor.textSecondary)
                .frame(width: 28, height: 28)
                .background(WBColor.bgBase, in: Circle())
                .zIndex(1)
                .padding(.horizontal, -WBSpace.x1)

            tile(background: spec.id == "requisites-budget" ? WBColor.bgBlueLight : WBColor.bgMinus1) {
                HStack(alignment: .top, spacing: WBSpace.x2) {
                    RowIconView(icon: recipient.icon, size: 24)
                    Spacer(minLength: 0)
                    Button(action: onOpenSpec) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(WBColor.textSecondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Text(recipient.title)
                    .font(WBFont.descriptionAccent)
                    .foregroundStyle(WBColor.textPrimary)
                    .lineLimit(1)
                Text(model.paymentDestinationSubtitle)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var urgentTransfer: some View {
        HStack(spacing: WBSpace.x3) {
            VStack(alignment: .leading, spacing: WBSpace.x1) {
                Text("Перевести срочно")
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textPrimary)
                Text("Зачисление за пару минут")
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
            }
            Spacer(minLength: 0)
            Text("+199 ₽")
                .font(WBFont.description)
                .foregroundStyle(WBColor.textSecondary)
            Toggle("", isOn: $isUrgent)
                .labelsHidden()
                .tint(WBColor.textAccent)
        }
        .padding(.horizontal, WBSpace.x3)
    }

    private func tile<Content: View>(
        background: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: WBSpace.x1) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WBSpace.x3)
        .background(
            background,
            in: RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
        )
    }
}
