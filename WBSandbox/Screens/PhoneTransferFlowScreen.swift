import SwiftUI

/// Перевод по номеру использует тот же конструктор, что и остальные платежи:
/// общий Top, общий Input, общий list item и общий экран суммы.
struct PhoneTransferFlowScreen: View {
    let baseConfig: TransactionConfig
    var onBack: () -> Void = {}

    @State private var query = ""
    @State private var selectedContact: PhoneTransferContact?
    @State private var amountModel: TransactionModel?
    @FocusState private var focus: String?

    private let recipientField = FormField(
        id: "phone-recipient",
        label: "Имя или телефон",
        kind: .input(.text(1...80)),
        facet: .payeeName
    )

    private let contacts: [PhoneTransferContact] = [
        PhoneTransferContact(
            id: "tatiana",
            name: "Татьяна Л.",
            phone: "+7 913 654-11-56",
            icon: .symbol(name: "person.fill", tint: .white, background: Color(hex: 0x7E57C2))
        ),
        PhoneTransferContact(
            id: "alina",
            name: "Алина Ивановна Т.",
            phone: "+7 916 204-78-32",
            icon: .symbol(name: "person.fill", tint: .white, background: Color(hex: 0xE85D75))
        ),
        PhoneTransferContact(
            id: "leonid",
            name: "Леонид Б.",
            phone: "+7 985 440-12-08",
            icon: .symbol(name: "person.fill", tint: .white, background: Color(hex: 0x2878C8))
        ),
        PhoneTransferContact(
            id: "maria",
            name: "Мария С.",
            phone: "+7 903 118-63-45",
            icon: .symbol(name: "person.fill", tint: .white, background: Color(hex: 0xD58A22))
        ),
    ]

    private let banks: [BankOption] = [
        BankOption("tbank", "Т-Банк", bic: "044525974"),
        BankOption("sber", "СберБанк", bic: "044525225"),
        BankOption("vtb", "ВТБ", bic: "044525187"),
    ]

    var body: some View {
        Group {
            if let amountModel {
                TransactionScreen(model: amountModel, onBack: returnToBankSelection)
            } else {
                selectionFlow
            }
        }
        .animation(.snappy(duration: 0.24), value: amountModel != nil)
    }

    private var selectionFlow: some View {
        VStack(spacing: 0) {
            PipFigmaTop(
                type: .provider,
                showsScanButton: false,
                titleText: selectedContact?.name ?? "Перевести по номеру",
                theme: .phoneTransfer,
                onBack: goBack,
                onClose: onBack
            )
            .frame(maxWidth: .infinity)

            ScrollView {
                Group {
                    if selectedContact == nil {
                        recipientStep
                    } else {
                        bankStep
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WBSpace.x4)
                .padding(.top, WBSpace.x4)
                .padding(.bottom, WBSpace.x6)
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                PipTopCornersShape(radius: WBRadius.x6)
                    .fill(WBColor.bgBase)
                    .ignoresSafeArea(edges: .bottom)
            }
            .clipShape(PipTopCornersShape(radius: WBRadius.x6))
        }
        .ignoresSafeArea(edges: focus == nil ? [.top, .bottom] : .top)
        .background(alignment: .top) {
            GeometryReader { proxy in
                PipFigmaTopBackground(
                    theme: .phoneTransfer,
                    width: proxy.size.width,
                    height: 120
                )
                .frame(height: 120, alignment: .top)
            }
        }
        .background(WBColor.bgBase, ignoresSafeAreaEdges: .all)
        .animation(.snappy(duration: 0.24), value: selectedContact?.id)
        .onAppear(perform: focusRecipientInput)
    }

    private var recipientStep: some View {
        VStack(alignment: .leading, spacing: WBSpace.x4) {
            Text("Имя или телефон")
                .font(WBFont.hauss(24, .bold))
                .foregroundStyle(WBColor.textPrimary)

            PipInput(
                field: recipientField,
                format: .text(1...80),
                value: recipientQuery,
                focus: $focus,
                placeholder: "+7",
                error: nil
            )

            VStack(spacing: 0) {
                ForEach(filteredContacts) { contact in
                    DetailRowView(
                        row: DetailRow(
                            id: contact.id,
                            icon: contact.icon,
                            top: .primary(contact.name),
                            bottom: .secondary(contact.phone),
                            showsChevron: false
                        ),
                        onTap: { select(contact) }
                    )
                }
            }
        }
    }

    private var bankStep: some View {
        VStack(alignment: .leading, spacing: WBSpace.x4) {
            Text("Выберите банк")
                .font(WBFont.hauss(24, .bold))
                .foregroundStyle(WBColor.textPrimary)

            VStack(spacing: 0) {
                ForEach(banks) { bank in
                    DetailRowView(
                        row: DetailRow(
                            id: bank.id,
                            icon: bank.icon,
                            top: .primary(bank.title),
                            bottom: .secondary("Доступен перевод по СБП"),
                            showsChevron: false
                        ),
                        onTap: { openAmount(for: bank) }
                    )
                }
            }
        }
    }

    private var recipientQuery: Binding<String> {
        Binding(
            get: { query },
            set: { query = formattedRecipientQuery($0) }
        )
    }

    private var filteredContacts: [PhoneTransferContact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return contacts }

        let queryDigits = trimmed.filter(\.isNumber)
        let matches = contacts.filter { contact in
            if trimmed.contains(where: \.isLetter) {
                return contact.name.localizedCaseInsensitiveContains(trimmed)
            }
            return contact.phone.filter(\.isNumber).contains(queryDigits)
        }
        if !matches.isEmpty || queryDigits.count < 11 { return matches }

        return [
            PhoneTransferContact(
                id: "entered-phone",
                name: trimmed,
                phone: trimmed,
                icon: .symbol(name: "person.fill", tint: .white, background: WBColor.brandBlue)
            ),
        ]
    }

    private func formattedRecipientQuery(_ raw: String) -> String {
        if raw.contains(where: \.isLetter) {
            return String(raw.prefix(80))
        }

        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return raw.isEmpty ? "" : "+7" }

        var national = digits
        if national.first == "7" || national.first == "8" {
            national.removeFirst()
        }
        national = String(national.prefix(10))

        var result = "+7"
        let groups = [3, 3, 2, 2]
        var index = national.startIndex
        for length in groups where index < national.endIndex {
            let end = national.index(index, offsetBy: length, limitedBy: national.endIndex)
                ?? national.endIndex
            result += " " + String(national[index..<end])
            index = end
        }
        return result
    }

    private func select(_ contact: PhoneTransferContact) {
        focus = nil
        selectedContact = contact
    }

    private func openAmount(for bank: BankOption) {
        guard let contact = selectedContact else { return }

        var config = baseConfig
        config.title = "Перевести"
        config.destination = DetailRow(
            id: "dest-phone-\(contact.id)-\(bank.id)",
            icon: bank.icon,
            top: .primary(contact.name),
            bottom: .secondary("\(bank.title) · \(contact.phone)")
        )
        config.success = SuccessConfig(
            title: baseConfig.success.title,
            subtitle: baseConfig.success.subtitle,
            icon: bank.icon,
            counterparty: contact.name,
            chip: baseConfig.success.chip
        )
        amountModel = TransactionModel(config: config)
    }

    private func goBack() {
        if selectedContact != nil {
            selectedContact = nil
            focusRecipientInput()
        } else {
            onBack()
        }
    }

    private func returnToBankSelection() {
        amountModel = nil
    }

    private func focusRecipientInput() {
        guard selectedContact == nil, amountModel == nil else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            focus = recipientField.id
        }
    }
}

private struct PhoneTransferContact: Identifiable {
    let id: String
    let name: String
    let phone: String
    let icon: RowIcon
}
