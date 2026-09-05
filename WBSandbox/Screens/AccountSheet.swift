import SwiftUI

/// Боттом-шит выбора способа оплаты и счёта списания. Собран по макету
/// `906:206669`: крестик, три блока с зазором 16 и кнопка «Готово».
///
/// 1. **Способ оплаты** — показываем, только когда выбирать есть из чего, то есть
///    доступно два и более рельса. Если способ один, выбора нет: он и так виден
///    на транзакционном экране логотипом в строке списания.
/// 2. **Доп. функция** — ровно одна: денег хватает → потратить ягодки,
///    не хватает → добавить WB Кэш. Включение добавляет бейдж слева от комиссии.
/// 3. **Счёт списания** — только доступные счета, выбор радиокнопкой.
///
/// Выбор ничего не закрывает: шит живёт до «Готово» или крестика, потому что за
/// один заход можно поменять и способ, и счёт, и доп. функцию.
struct AccountSheet: View {
    @Bindable var model: TransactionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            closeRow

            ScrollView {
                // Между блоками 16, снизу у контейнера ещё 8 (макет 906:206672).
                VStack(alignment: .leading, spacing: WBSpace.x4) {
                    if model.showsRailPicker {
                        block("Способ оплаты") { rails }
                    }

                    if let extra = model.availableExtra {
                        extraRow(extra)
                    }

                    block("Счёт списания") { accounts }
                }
                .padding(.bottom, WBSpace.x2)
            }
            // Контент короткий и в детент помещается целиком — скролл нужен только
            // как страховка на длинных списках, поэтому высоту он не забирает.
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
        .background(WBColor.bgBase)
    }

    // MARK: Шапка и подвал

    private var closeRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(WBColor.controlsTertiary)
                    // Нажимается зона 44, а место в разметке занимает 24 —
                    // ровно как «tap zone» поверх плитки в макете.
                    .frame(width: WBSpace.x11, height: WBSpace.x11)
                    .contentShape(Rectangle())
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, WBSpace.x3)
        .padding(.horizontal, WBSpace.x4)
    }

    private var footer: some View {
        WBPrimaryButton(title: "Готово") { dismiss() }
            .padding(.top, WBSpace.x4)
            .padding(.bottom, WBSpace.x2)
            .padding(.horizontal, WBSpace.x4)
    }

    /// Заголовок секции + её содержимое. Между ними 12 (макет `🔷 sectionHeader`).
    private func block<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(WBFont.title3Bold)
                .foregroundStyle(WBColor.textPrimary)
                .frame(minHeight: 24, alignment: .leading)
                .padding(.horizontal, WBSpace.x4)
                .padding(.bottom, WBSpace.x3)
            content()
        }
    }

    // MARK: 1. Способ оплаты

    private var rails: some View {
        // Карточки фиксированной ширины: втроём они не влезают в 390, поэтому
        // ряд горизонтально скроллится, а на двух ведёт себя как обычный HStack.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WBSpace.x2) {
                ForEach(model.rails) { rail in
                    railCard(rail)
                }
            }
            .padding(.horizontal, WBSpace.x4)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func railCard(_ rail: PaymentRail) -> some View {
        let isSelected = model.selectedRail == rail

        return Button {
            Haptics.tap()
            withAnimation(.snappy(duration: 0.2)) { model.selectRail(rail) }
        } label: {
            HStack(spacing: WBSpace.x2) {
                RowIconView(icon: rail.icon, size: 24)

                Text(rail.shortTitle)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.walletActionAccent)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(WBSpace.x2)
            .frame(width: 128, height: 48)
            .background(
                WBColor.bgLevel2,
                in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
                    .strokeBorder(WBColor.textAccent, lineWidth: isSelected ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 2. Доп. функция

    private func extraRow(_ extra: ExtraFunction) -> some View {
        listRow(icon: extra.icon, title: extra.title, subtitle: extra.subtitle) {
            Toggle(
                "",
                isOn: Binding(
                    get: { model.isExtraOn(extra) },
                    set: { model.setExtra(extra, $0) }
                )
            )
            .labelsHidden()
            .tint(WBColor.textAccent)
        }
    }

    // MARK: 3. Счета

    private var accounts: some View {
        VStack(spacing: 0) {
            ForEach(model.availableAccounts) { account in
                listRow(
                    icon: account.icon,
                    title: account.amountTitle,
                    subtitle: account.subtitle
                ) {
                    RadioMark(isOn: model.selectedAccountID == account.id)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.tap()
                    withAnimation(.snappy(duration: 0.2)) { model.selectAccount(account.id) }
                }
            }
        }
    }

    // MARK: Строка списка

    /// `🔷 listItemLite / medium - small`: иконка 40, контент с py 8, справа
    /// контрол. Высота строки получается 55 — её задаёт содержимое.
    private func listRow<Trailing: View>(
        icon: RowIcon,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: WBSpace.x2) {
            RowIconView(icon: icon, size: 40)

            HStack(spacing: WBSpace.x2) {
                VStack(alignment: .leading, spacing: WBSpace.x0_5) {
                    Text(title)
                        .font(WBFont.body)
                        .foregroundStyle(WBColor.textPrimary)
                        .lineLimit(1)
                        .frame(height: WBLineHeight.body)
                    Text(subtitle)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                        .lineLimit(1)
                        .frame(height: WBLineHeight.description)
                }

                Spacer(minLength: 0)

                trailing()
            }
            .padding(.vertical, WBSpace.x2)
        }
        // Высота зафиксирована: 8 + (20 + 2 + 17) + 8. Иначе SwiftUI отдаёт строке
        // на пару точек меньше, и по трём строкам набегает заметный сдвиг.
        .frame(height: 55)
        .padding(.horizontal, WBSpace.x4)
    }
}

// MARK: - Радиокнопка

/// `◆ Radio · Medium`: 22 pt, обводка 2. Выбранная — зелёное кольцо с точкой.
struct RadioMark: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? WBColor.textAccent : WBColor.radioOff, lineWidth: 2)
            if isOn {
                Circle()
                    .fill(WBColor.textAccent)
                    .frame(width: 11, height: 11)
                    .transition(.scale)
            }
        }
        .frame(width: 22, height: 22)
    }
}
