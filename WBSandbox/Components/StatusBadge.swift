import SwiftUI

/// Бейдж статуса операции в углу иконки получателя.
///
/// У него два режима. Без `handover` он переключается по состоянию: пока
/// `outcome == nil` крутится дуга, при появлении исхода она сменяется символом
/// через Magic Replace — этот морф и показывается в разделе «Морф иконок».
/// С `handover` кадр целиком задаётся снаружи: так его гонит таймлайн экрана
/// исхода, где дуга сматывается ровно в момент выстрела капель.
struct StatusBadge: View {
    let outcome: TransactionOutcome?
    /// В макете 925:207402 кружок 22,858: заливка 18,286 плюс белая обводка 2,286.
    var size: CGFloat = 22.858
    /// Внешний угол дуги лоадера. nil — крутится сама.
    var loaderAngle: Double? = nil
    /// Подмена «дуга → знак статуса», 0…1. nil — режим по состоянию.
    var handover: CGFloat? = nil

    @State private var spin = false

    /// Обводка и символ заданы долями кружка, чтобы бейдж одинаково собирался
    /// и на иконке 64 pt, и в демо морфа.
    private var ring: CGFloat { size * (2.286 / 22.858) }

    var body: some View {
        ZStack {
            Circle().fill(.white)

            if let handover {
                timeline(handover)
            } else if let outcome {
                Circle()
                    .fill(outcome.accent)
                    .padding(ring)
                    .transition(.scale.combined(with: .opacity))
                mark(outcome)
            } else {
                loaderArc.rotationEffect(.degrees(spin ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                            spin = true
                        }
                    }
                    .onDisappear { spin = false }
            }
        }
        .frame(width: size, height: size)
        .animation(handover == nil ? .snappy(duration: 0.35) : nil, value: outcome)
    }

    // MARK: Кадр по таймлайну

    /// Дуга сматывается за первые 40 % подмены, заливка наливается к 50 %,
    /// знак статуса проступает с 35 % — так они успевают передать эстафету,
    /// не столкнувшись в одном кадре. Кривые по ролям, как и на всём экране:
    /// сматывание — разгон, заливка и знак — проявление.
    @ViewBuilder
    private func timeline(_ p: CGFloat) -> some View {
        let arc = 1 - Ease.accelerate(clamp01(p / 0.4))
        let fill = Ease.appear(clamp01(p / 0.5))
        let markP = Ease.appear(clamp01((p - 0.35) / 0.65))

        if let outcome {
            Circle()
                .fill(outcome.accent)
                .padding(ring)
                .opacity(Double(fill))
        }

        if arc > 0.001 {
            Circle()
                .trim(from: 0, to: 0.22 * arc)
                .stroke(
                    WBColor.brandBlue,
                    style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
                )
                .padding(size * 0.2)
                .rotationEffect(.degrees(loaderAngle ?? 0))
        }

        if let outcome, markP > 0.001 {
            mark(outcome)
                .opacity(Double(markP))
                .scaleEffect(0.6 + 0.4 * markP)
        }
    }

    @ViewBuilder
    private func mark(_ outcome: TransactionOutcome) -> some View {
        if let vector = outcome.badgeVector {
            // Знак из макета: морфа у него нет, он появляется наплывом.
            DSIconView(icon: vector, size: size * (15.673 / 22.858))
                .transition(.opacity)
        } else {
            Image(systemName: outcome.symbol)
                .font(.system(size: size * 0.53, weight: .bold))
                .foregroundStyle(.white)
                // Magic Replace морфит символ в символ, если формы родственные,
                // и мягко подменяет в остальных случаях.
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
        }
    }

    private var loaderArc: some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(
                WBColor.brandBlue,
                style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
            )
            .padding(size * 0.2)
    }
}

/// Иконка контрагента со статусным бейджем — центральный элемент экрана исхода.
struct CounterpartyIcon: View {
    let icon: RowIcon
    let outcome: TransactionOutcome?
    var size: CGFloat = 64
    var loaderAngle: Double? = nil
    var handover: CGFloat? = nil

    var body: some View {
        RowIconView(icon: icon, size: size)
            // Макет 925:207402: кружок 22,858 прижат к нижней кромке плитки
            // и выступает за правую на 2,29.
            .overlay(alignment: .bottomTrailing) {
                StatusBadge(
                    outcome: outcome,
                    size: size * (22.858 / 64),
                    loaderAngle: loaderAngle,
                    handover: handover
                )
                .offset(x: size * (2.29 / 64), y: 0)
            }
    }
}
