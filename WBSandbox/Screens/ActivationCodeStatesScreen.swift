import SwiftUI

struct ActivationCodeStatesScreen: View {
    let onClose: () -> Void

    @State private var phase: ActivationCodeView.Phase = .idle
    @State private var runID = 0
    @State private var revealStartedAt = Date()

    private let variants: [ActivationCodeVariantDescriptor] = [
        .init(id: 1, title: "Вариант 1 · лоудер", variant: .spinner, isVisible: true),
        .init(id: 2, title: "Вариант 2 · сканер", variant: .scanner, isVisible: false),
        .init(id: 3, title: "Вариант 3 · группы", variant: .groupPulse, isVisible: false),
        .init(id: 4, title: "Вариант 4 · расшифровка", variant: .decrypt, isVisible: false),
        .init(id: 5, title: "Вариант 5 · импульс от глаза", variant: .eyeImpulse, isVisible: false),
        .init(id: 6, title: "Вариант 6 · blur/sharp", variant: .blurReveal, isVisible: false),
        .init(id: 7, title: "Вариант 7 · волна", variant: .dotWave, isVisible: true),
        .init(id: 8, title: "Вариант 8 · белый слайд", variant: .whiteSlide, isVisible: true),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(variants.filter { $0.isVisible }) { variant in
                        ActivationCodeVariant(
                            title: variant.title,
                            variant: variant.variant,
                            phase: phase,
                            revealStartedAt: revealStartedAt
                        )
                    }
                }
                .padding(.vertical, 24)
            }
            .background(WBColor.bgMinus1, ignoresSafeAreaEdges: .all)
            .navigationTitle("Код активации")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                WBPrimaryButton(title: "Показать") {
                    play()
                }
                .padding(.horizontal, WBSpace.x4)
                .padding(.top, WBSpace.x3)
                .padding(.bottom, WBSpace.x2)
                .background(WBColor.bgMinus1)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть", action: onClose)
                }
            }
        }
    }

    private func play() {
        runID += 1
        let currentRun = runID

        withAnimation(.snappy(duration: 0.16)) {
            phase = .loading
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            guard currentRun == runID else { return }
            revealStartedAt = Date()
            withAnimation(.snappy(duration: 0.24)) {
                phase = .revealing
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.12) {
            guard currentRun == runID else { return }
            withAnimation(.snappy(duration: 0.18)) {
                phase = .visible
            }
        }
    }
}

private struct ActivationCodeVariantDescriptor: Identifiable {
    let id: Int
    let title: String
    let variant: ActivationCodeView.Variant
    let isVisible: Bool
}

private struct ActivationCodeVariant: View {
    let title: String
    let variant: ActivationCodeView.Variant
    let phase: ActivationCodeView.Phase
    let revealStartedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(WBFont.descriptionAccent)
                .foregroundStyle(WBColor.textSecondary)
                .padding(.horizontal, WBSpace.x4)

            ScrollView(.horizontal, showsIndicators: false) {
                ActivationCodeView(variant: variant, phase: phase, revealStartedAt: revealStartedAt)
                    .frame(width: 390, height: 113)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ActivationCodeView: View {
    enum Variant {
        case spinner
        case scanner
        case groupPulse
        case decrypt
        case eyeImpulse
        case blurReveal
        case dotWave
        case whiteSlide
    }

    enum Phase {
        case idle
        case loading
        case revealing
        case visible
    }

    let variant: Variant
    let phase: Phase
    let revealStartedAt: Date

    private let visibleCode = "4829061795432086"
    private var codeCount: Int { visibleCode.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: 44)
                .padding(.top, 8)

            HStack(spacing: WBSpace.x4) {
                codeContent
                    .frame(height: 20, alignment: .leading)

                Spacer(minLength: WBSpace.x4)

                trailingControl
                    .frame(width: 24, height: 24)
            }
            .frame(height: 44)
            .padding(.horizontal, WBSpace.x4)
            .padding(.bottom, WBSpace.x4)

            Rectangle()
                .fill(WBColor.separator)
                .frame(height: 1)
                .padding(.horizontal, WBSpace.x4)
        }
        .frame(width: 390, height: 113, alignment: .topLeading)
        .background(WBColor.bgBase)
        .clipShape(PipTopCornersShape(radius: 24))
    }

    private var header: some View {
        HStack {
            Text("Код активации")
                .font(WBFont.title3Bold)
                .lineLimit(1)
                .foregroundStyle(WBColor.textPrimary)
            Spacer(minLength: WBSpace.x4)
        }
        .padding(.horizontal, WBSpace.x4)
    }

    @ViewBuilder
    private var codeContent: some View {
        switch (phase, variant) {
        case (.revealing, _):
            ActivationCodeRevealDigits(code: visibleCode, startedAt: revealStartedAt)
        case (.loading, .scanner):
            ActivationCodeScannerDots(count: codeCount)
        case (.loading, .groupPulse):
            ActivationCodeGroupPulseDots(count: codeCount)
        case (.loading, .decrypt):
            ActivationCodeDecryptDots(code: visibleCode)
        case (.loading, .eyeImpulse):
            ActivationCodeEyeImpulseDots(count: codeCount)
        case (.loading, .blurReveal):
            ActivationCodeBlurRevealDots(count: codeCount)
        case (.loading, .dotWave):
            ActivationCodeWaveDots(count: codeCount)
        case (.loading, .whiteSlide):
            ActivationCodeWhiteSlideDots(count: codeCount)
        case (.visible, _):
            ActivationCodeDigitsRow(code: visibleCode)
        default:
            ActivationCodeHiddenDots(count: codeCount)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch (phase, variant) {
        case (.loading, .spinner):
            ActivationCodeLoader()
        case (.loading, .eyeImpulse):
            ActivationCodePulsingEyeIcon()
        case (.revealing, _):
            ActivationCodeEyeIcon(isSlashed: true)
        case (.visible, _):
            ActivationCodeEyeIcon(isSlashed: true)
        default:
            ActivationCodeEyeIcon()
        }
    }
}

private enum ActivationCodeCodeMetrics {
    static let cellWidth: CGFloat = 12
    static let groupGap: CGFloat = 6
    static let dotSize: CGFloat = 5
    static let rowHeight: CGFloat = 20

    static func rowWidth(count: Int) -> CGFloat {
        let gaps = max(0, (count - 1) / 4)
        return CGFloat(count) * cellWidth + CGFloat(gaps) * groupGap
    }
}

private struct ActivationCodeCells<Content: View>: View {
    let count: Int
    let content: (Int) -> Content

    init(count: Int, @ViewBuilder content: @escaping (Int) -> Content) {
        self.count = count
        self.content = content
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                content(index)
                    .frame(
                        width: ActivationCodeCodeMetrics.cellWidth,
                        height: ActivationCodeCodeMetrics.rowHeight
                    )

                if index % 4 == 3, index != count - 1 {
                    Spacer()
                        .frame(width: ActivationCodeCodeMetrics.groupGap)
                }
            }
        }
        .frame(
            width: ActivationCodeCodeMetrics.rowWidth(count: count),
            height: ActivationCodeCodeMetrics.rowHeight,
            alignment: .leading
        )
    }
}

private struct ActivationCodeHiddenDots: View {
    let count: Int

    var body: some View {
        ActivationCodeCells(count: count) { _ in
            Circle()
                .fill(WBColor.textPrimary)
                .frame(width: ActivationCodeCodeMetrics.dotSize, height: ActivationCodeCodeMetrics.dotSize)
        }
        .accessibilityHidden(true)
    }
}

private struct ActivationCodeDigitsRow: View {
    let code: String

    private var digits: [String] {
        code.map(String.init)
    }

    var body: some View {
        ActivationCodeCells(count: digits.count) { index in
            Text(digits[index])
                .font(.system(size: 17, weight: .regular))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(WBColor.textPrimary)
        }
    }
}

private struct ActivationCodeRevealDigits: View {
    let code: String
    let startedAt: Date

    private var digits: [String] {
        code.map(String.init)
    }

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startedAt)

            ActivationCodeCells(count: digits.count) { index in
                    let progress = revealProgress(elapsed: elapsed, index: index)

                    ZStack {
                        Circle()
                            .fill(WBColor.textPrimary)
                            .frame(width: ActivationCodeCodeMetrics.dotSize, height: ActivationCodeCodeMetrics.dotSize)
                            .scaleEffect(max(0.05, 1 - 0.95 * progress))
                            .opacity(1 - progress)

                        Text(digits[index])
                            .font(.system(size: 17, weight: .regular))
                            .monospacedDigit()
                            .foregroundStyle(WBColor.textPrimary)
                            .scaleEffect(0.68 + 0.32 * progress)
                            .opacity(progress)
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private func revealProgress(elapsed: TimeInterval, index: Int) -> Double {
        let delay = Double(index) * 0.018
        let raw = (elapsed - delay) / 0.42
        let clamped = min(max(raw, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }
}

private struct ActivationCodeEyeIcon: View {
    var isSlashed = false

    var body: some View {
        ZStack {
            Image("dsEyeOn24")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(WBColor.textPrimary)

            if isSlashed {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(WBColor.textPrimary)
                    .frame(width: 23, height: 2)
                    .rotationEffect(.degrees(-42))
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

private struct ActivationCodeLoader: View {
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(
                WBColor.textSecondary,
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
            )
            .padding(4.8)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
            .onDisappear { spin = false }
            .accessibilityHidden(true)
    }
}

private struct ActivationCodePulsingEyeIcon: View {
    var body: some View {
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.1) / 1.1
            let pulse = 1 - abs(progress * 2 - 1)

            ActivationCodeEyeIcon()
                .scaleEffect(1 + 0.1 * pulse)
                .opacity(0.72 + 0.28 * pulse)
        }
    }
}

private struct ActivationCodeScannerDots: View {
    let count: Int

    var body: some View {
        TimelineView(.animation) { context in
            let width = ActivationCodeCodeMetrics.rowWidth(count: count)
            let progress = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.35) / 1.35
            let head = progress * Double(count + 5) - 2.5

            ZStack(alignment: .leading) {
                ActivationCodeCells(count: count) { index in
                    let distance = abs(Double(index) - head)
                    let highlight = max(0, 1 - distance / 3)

                    Circle()
                        .fill(WBColor.textPrimary)
                        .frame(width: ActivationCodeCodeMetrics.dotSize, height: ActivationCodeCodeMetrics.dotSize)
                        .opacity(0.42 + 0.58 * highlight)
                }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                WBColor.textSecondary.opacity(0),
                                WBColor.textSecondary.opacity(0.34),
                                WBColor.textSecondary.opacity(0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 24, height: 16)
                    .offset(x: -12 + progress * (width + 24))
            }
            .frame(width: width, height: ActivationCodeCodeMetrics.rowHeight, alignment: .leading)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

private struct ActivationCodeGroupPulseDots: View {
    let count: Int

    var body: some View {
        TimelineView(.animation) { context in
            let groupSize = 4
            let groupCount = max(1, Int(ceil(Double(count) / Double(groupSize))))
            let progress = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.7) / 1.7
            let head = progress * Double(groupCount + 1)

            ActivationCodeCells(count: count) { index in
                let group = Double(index / groupSize)
                let highlight = max(0, 1 - abs(group - head) / 1.2)

                Circle()
                    .fill(WBColor.textPrimary)
                    .frame(width: ActivationCodeCodeMetrics.dotSize, height: ActivationCodeCodeMetrics.dotSize)
                    .opacity(0.42 + 0.58 * highlight)
                    .scaleEffect(1 + 0.55 * highlight)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ActivationCodeDecryptDots: View {
    let code: String

    private var symbols: [String] {
        code.map(String.init)
    }

    var body: some View {
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.55) / 1.55
            let head = progress * Double(symbols.count + 4) - 2

            ActivationCodeCells(count: symbols.count) { index in
                    let distance = abs(Double(index) - head)
                    let reveal = max(0, 1 - distance / 1.4)
                    let symbol = reveal > 0.42 ? symbols[index] : "•"

                    Text(symbol)
                        .font(.system(size: 17, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(WBColor.textPrimary)
                        .opacity(symbol == "•" ? 1 : 0.78 + 0.22 * reveal)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ActivationCodeEyeImpulseDots: View {
    let count: Int

    var body: some View {
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.25) / 1.25
            let head = Double(count + 2) - progress * Double(count + 5)

            ActivationCodeCells(count: count) { index in
                let distance = abs(Double(index) - head)
                let highlight = max(0, 1 - distance / 2.5)

                Circle()
                    .fill(WBColor.textPrimary)
                    .frame(width: ActivationCodeCodeMetrics.dotSize, height: ActivationCodeCodeMetrics.dotSize)
                    .opacity(0.38 + 0.62 * highlight)
                    .scaleEffect(1 + 0.28 * highlight)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ActivationCodeBlurRevealDots: View {
    let count: Int

    var body: some View {
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.5) / 1.5
            let head = progress * Double(count + 8) - 4

            ActivationCodeCells(count: count) { index in
                let position = Double(index)
                let headSharpness = max(0, 1 - abs(position - head) / 1.35)
                let tailDistance = head - position
                let tailSharpness = tailDistance >= 0 ? max(0, 1 - tailDistance / 4.6) : 0
                let sharpness = max(headSharpness, tailSharpness * 0.72)

                Circle()
                    .fill(WBColor.textPrimary)
                    .frame(width: ActivationCodeCodeMetrics.dotSize, height: ActivationCodeCodeMetrics.dotSize)
                    .blur(radius: 1.6 * (1 - sharpness))
                    .opacity(0.24 + 0.76 * sharpness)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ActivationCodeWaveDots: View {
    let count: Int

    var body: some View {
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.45) / 1.45
            let head = progress * Double(count + 4) - 2

            ActivationCodeCells(count: count) { index in
                let distance = abs(Double(index) - head)
                let influence = max(0, 1 - distance / 4)

                Circle()
                    .fill(WBColor.textPrimary)
                    .frame(width: ActivationCodeCodeMetrics.dotSize, height: ActivationCodeCodeMetrics.dotSize)
                    .scaleEffect(1 + influence)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ActivationCodeWhiteSlideDots: View {
    let count: Int

    var body: some View {
        TimelineView(.animation) { context in
            let width = ActivationCodeCodeMetrics.rowWidth(count: count)
            let cycle = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 2.6) / 2.6
            let slideWidth: CGFloat = 62
            let xOffset = -slideWidth + CGFloat(cycle) * (width + slideWidth)

            ZStack(alignment: .leading) {
                ActivationCodeHiddenDots(count: count)

                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0), location: 0),
                                .init(color: Color.white.opacity(0.48), location: 0.28),
                                .init(color: Color.white.opacity(0.8), location: 0.5),
                                .init(color: Color.white.opacity(0.48), location: 0.72),
                                .init(color: Color.white.opacity(0), location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: slideWidth, height: ActivationCodeCodeMetrics.rowHeight + 4)
                    .offset(x: xOffset)
            }
            .frame(width: width, height: ActivationCodeCodeMetrics.rowHeight, alignment: .leading)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ActivationCodeStatesScreen {}
}
