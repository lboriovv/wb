import SwiftUI

/// Демонстрация морфа иконок. Первый блок — не отдельная игрушка, а тот же
/// `StatusBadge`, что работает на экране исхода: видно ровно тот переход, который
/// пользователь увидит после нажатия «Продолжить».
struct IconMorphScreen: View {
    @State private var statusIndex = 0
    @State private var shapeProgress: CGFloat = 0
    @State private var effectTrigger = 0

    /// nil в начале — состояние лоадера.
    private let statuses: [TransactionOutcome?] = [nil, .processing, .success, .declined]

    private var status: TransactionOutcome? { statuses[statusIndex] }

    var body: some View {
        ScrollView {
            VStack(spacing: WBSpace.x4) {
                statusCard
                effectsCard
                shapeCard
            }
            .padding(WBSpace.x4)
        }
        .background(WBColor.bgMinus1)
    }

    // MARK: Статус операции

    private var statusCard: some View {
        card(
            title: "Статус операции",
            hint: "Тот же компонент, что на экране исхода. Тапни, чтобы прокрутить состояния."
        ) {
            VStack(spacing: WBSpace.x4) {
                CounterpartyIcon(icon: .asset("icTBank"), outcome: status, size: 88)

                Text(status?.title ?? "Отправляем перевод")
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(WBColor.textPrimary)
                    .contentTransition(.opacity)
                    .animation(.snappy(duration: 0.3), value: statusIndex)

                Text(statusCaption)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap()
                withAnimation(.snappy(duration: 0.35)) {
                    statusIndex = (statusIndex + 1) % statuses.count
                }
            }
        }
    }

    private var statusCaption: String {
        switch status {
        case nil: "Дуга крутится, пока идёт операция"
        case .processing: "Magic Replace: дуга сменилась часами"
        case .success: "Часы морфнули в галочку"
        case .declined: "Галочка морфнула в крестик"
        }
    }

    // MARK: Эффекты символов

    private let effects: [(symbol: String, title: String)] = [
        ("arrow.trianglehead.2.clockwise.rotate.90", "rotate"),
        ("bell.fill", "bounce"),
        ("wifi", "variable"),
        ("heart.fill", "pulse"),
        ("bubble.left.fill", "wiggle"),
        ("lungs.fill", "breathe"),
    ]

    private var effectsCard: some View {
        card(
            title: "Эффекты символов",
            hint: "Одно нажатие проигрывает все шесть эффектов сразу."
        ) {
            VStack(spacing: WBSpace.x4) {
                HStack(spacing: 0) {
                    ForEach(Array(effects.enumerated()), id: \.offset) { index, effect in
                        VStack(spacing: WBSpace.x1_5) {
                            symbol(effect.symbol, kind: index)
                            Text(effect.title)
                                .font(.system(size: 9))
                                .foregroundStyle(WBColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Button {
                    Haptics.tap()
                    effectTrigger += 1
                } label: {
                    Text("Проиграть")
                        .font(WBFont.bodyAccent)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(WBColor.ctaFill, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func symbol(_ name: String, kind: Int) -> some View {
        let base = Image(systemName: name)
            .font(.system(size: 26))
            .foregroundStyle(WBColor.textAccent)
            .frame(height: 32)

        switch kind {
        case 0: base.symbolEffect(.rotate, value: effectTrigger)
        case 1: base.symbolEffect(.bounce, value: effectTrigger)
        case 2: base.symbolEffect(.variableColor.iterative, value: effectTrigger)
        case 3: base.symbolEffect(.pulse, value: effectTrigger)
        case 4: base.symbolEffect(.wiggle, value: effectTrigger)
        default: base.symbolEffect(.breathe, value: effectTrigger)
        }
    }

    // MARK: Морф формы

    private var shapeCard: some View {
        card(
            title: "Морф формы",
            hint: "Скругление иконки от squircle до круга — тем же способом можно морфить подложку бренда."
        ) {
            VStack(spacing: WBSpace.x4) {
                RoundedRectangle(
                    cornerRadius: 20 + shapeProgress * 24,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [WBColor.violet, WBColor.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .overlay {
                    Image(systemName: "rublesign")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Slider(value: $shapeProgress, in: 0...1)
                    .tint(WBColor.textAccent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Обёртка карточки

    private func card<Content: View>(
        title: String,
        hint: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: WBSpace.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(WBColor.textPrimary)
                Text(hint)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding(WBSpace.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            WBColor.bgBase,
            in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
        )
    }
}
