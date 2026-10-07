import SwiftUI

struct PipDesignSystemScreen: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    FigmaCanvas(title: "Top · 48516:73991", height: 692) {
                        VStack(spacing: 28) {
                            PipFigmaTop(type: .provider, showsScanButton: false, titleText: "ЖКУ Москвы", theme: .utilities)
                            PipFigmaTop(type: .provider, showsScanButton: true, titleText: "Ростелеком", theme: .telecom)
                            PipFigmaTop(type: .requisites, showsScanButton: false, titleText: "Перевод по реквизитам", theme: .requisites)
                            PipFigmaTop(type: .requisites, showsScanButton: true, titleText: "Государству", theme: .requisites)
                        }
                    }

                    FigmaCanvas(title: "stiky bar · 48486:49048", height: 598, background: .clear) {
                        VStack(spacing: 40) {
                            PipFigmaStickyBar(type: .default, progressFraction: 0.38)
                            PipFigmaStickyBar(type: .keyboard, progressFraction: 0.74)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .background(WBColor.bgMinus1, ignoresSafeAreaEdges: .all)
            .navigationTitle("Дизайн-система")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть", action: onClose)
                }
            }
        }
    }
}

// MARK: - Figma Canvas

private struct FigmaCanvas<Content: View>: View {
    let title: String
    let height: CGFloat
    var background: Color = Color(hex: 0x272727)
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(WBFont.descriptionAccent)
                .foregroundStyle(WBColor.textSecondary)
                .padding(.horizontal, WBSpace.x4)

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    background
                    content
                }
                .frame(width: 390, height: height)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Top

struct PipFigmaTop: View {
    enum TopType {
        case provider
        case requisites
    }

    enum Theme {
        case utilities
        case telecom
        case transport
        case requisites
        case government
        case phoneTransfer

        var colors: (center: Color, edge: Color) {
            switch self {
            case .utilities:
                return (Color(hex: 0xDFF1E8), Color(hex: 0xA8D8BC))
            case .telecom:
                return (Color(hex: 0xEEE5FF), Color(hex: 0xD4BCF8))
            case .transport:
                return (Color(hex: 0xFFF3D1), Color(hex: 0xFFE4A8))
            case .requisites, .government:
                return (Color(hex: 0xDDF4FF), Color(hex: 0xB7E7F8))
            case .phoneTransfer:
                return (Color(hex: 0xFFE0FE), Color(hex: 0xFFBFF0))
            }
        }

        var xRadiusRatio: CGFloat {
            switch self {
            case .utilities:
                return 314.39 / 390
            case .telecom, .transport:
                return 288.52 / 390
            case .requisites, .government, .phoneTransfer:
                return 334.29 / 390
            }
        }
    }

    let type: TopType
    var showsScanButton: Bool
    var titleText: String?
    var theme: Theme = .requisites
    var showsBackButton = true
    var showsCloseButton = true
    var showsBackground = true
    var showsTitle = true
    var onBack: () -> Void = {}
    var onClose: () -> Void = {}
    var onScanReceipt: () -> Void = {}

    private let backgroundOverhang: CGFloat = 24

    private var layoutHeight: CGFloat {
        showsScanButton ? 168 : 96
    }

    private var backgroundHeight: CGFloat {
        layoutHeight + backgroundOverhang
    }

    private let navIconInset: CGFloat = 28
    private let navIconY: CGFloat = 68

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                if showsBackground {
                    PipFigmaTopBackground(theme: theme, width: width, height: backgroundHeight)
                }

                if showsBackButton {
                    Button(action: onBack) {
                        PipFigmaTemplateIcon("dsChevronLeft24", size: 24, color: WBColor.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                    .position(x: navIconInset, y: navIconY)
                }

                if showsCloseButton {
                    Button(action: onClose) {
                        PipFigmaTemplateIcon("dsCross24", size: 24, color: WBColor.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                    .position(x: width - navIconInset, y: navIconY)
                }

                if showsTitle {
                    title
                        .frame(width: min(258, width - 132), height: 48)
                        .position(x: width / 2, y: navIconY)
                }

                if showsScanButton {
                    PipFigmaScanReceiptButton(width: width - 32, onTap: onScanReceipt)
                        .position(x: width / 2, y: 126)
                }
            }
            .frame(width: width, height: backgroundHeight, alignment: .topLeading)
        }
        .frame(height: backgroundHeight, alignment: .top)
        .padding(.bottom, -backgroundOverhang)
        .accessibilityElement(children: .contain)
    }

    private var title: some View {
        Text(titleText ?? defaultTitle)
            .font(WBFont.hauss(17, .bold))
            .foregroundStyle(WBColor.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .frame(height: 20)
    }

    private var defaultTitle: String {
        switch type {
        case .provider:
            "ЖКУ Москвы"
        case .requisites:
            "Перевод по реквизитам"
        }
    }
}

struct PipFigmaTopBackground: View {
    let theme: PipFigmaTop.Theme
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        PipFigmaRadialTopGradient(theme: theme, width: width, height: height)
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
    }
}

private struct PipFigmaRadialTopGradient: View {
    let theme: PipFigmaTop.Theme
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let safeWidth = max(width, 1)
        let safeHeight = max(height, 1)
        let xRadius = max(safeWidth * theme.xRadiusRatio, 1)
        let xScale = xRadius / safeHeight
        let colors = theme.colors

        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: colors.center, location: 0),
                .init(color: colors.edge, location: 1),
            ]),
            center: .top,
            startRadius: 0,
            endRadius: safeHeight
        )
        .frame(width: safeWidth / xScale, height: safeHeight)
        .scaleEffect(x: xScale, y: 1, anchor: .top)
        .frame(width: safeWidth, height: safeHeight)
    }
}

private struct PipFigmaScanReceiptButton: View {
    var width: CGFloat = 358
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                PipFigmaTemplateIcon("dsQrScan24", size: 20, color: WBColor.textPrimary)

                Text("Сканировать квитанцию")
                    .font(WBFont.hauss(17, .medium))
                    .frame(height: 20)
            }
            .foregroundStyle(WBColor.textPrimary)
            .frame(width: width, height: 52)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sticky Bar

struct PipFigmaStickyBar: View {
    enum BarType {
        case `default`
        case systemKeyboard
        case keyboard
    }

    let type: BarType
    var title: String = "Продолжить"
    var progressFraction: CGFloat = 0
    var showsProgress = true
    var onContinue: () -> Void = {}
    var onStepsTap: () -> Void = {}

    private var height: CGFloat {
        surfaceHeight + (showsProgress ? 46 : 0)
    }

    private var surfaceHeight: CGFloat {
        switch type {
        case .default: 106
        case .systemKeyboard: 72
        case .keyboard: 360
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            VStack(spacing: 0) {
                if showsProgress {
                    PipFigmaStepsContainer(width: width, progressFraction: progressFraction, onTap: onStepsTap)
                        .frame(width: width, height: 46)
                }

                VStack(spacing: 0) {
                    PipFigmaStickyButtonArea(title: title, onTap: onContinue)
                        .frame(width: width, height: 72)

                    switch type {
                    case .default:
                        Image("dsHomeIndicator")
                            .resizable()
                            .frame(width: width, height: 34)

                    case .systemKeyboard:
                        EmptyView()

                    case .keyboard:
                        PipFigmaKeyboard()
                            .frame(width: width, height: 288)
                    }
                }
                .frame(width: width, height: surfaceHeight, alignment: .top)
                .background(
                    PipTopCornersShape(radius: 28)
                        .fill(.white)
                )
            }
            .frame(width: width, height: height, alignment: .top)
        }
        .frame(height: height, alignment: .top)
        .accessibilityElement(children: .contain)
    }
}

private struct PipFigmaStepsContainer: View {
    var width: CGFloat = 390
    var progressFraction: CGFloat = 0
    var onTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            PipFigmaStepsPill(progressFraction: progressFraction, onTap: onTap)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: 46, alignment: .top)
    }
}

private struct PipFigmaStepsPill: View {
    private let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
    var progressFraction: CGFloat = 0
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                PipFigmaProgressRing(progress: progressFraction)
                    .frame(width: 26, height: 26)

                HStack(spacing: 0) {
                    Text("Всё, что нужно заполнить")
                        .font(WBFont.body)
                        .foregroundStyle(WBColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                        .allowsTightening(true)
                        .truncationMode(.tail)
                        .frame(width: 182, height: 20, alignment: .leading)

                    PipFigmaTemplateIcon("dsChevronRight24", size: 14, color: WBColor.textPrimary)
                        .frame(width: 14, height: 14)
                }
                .frame(width: 196, height: 20)
            }
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .frame(width: 248, height: 38)
            .background(
                shape.fill(WBColor.bgBase)
            )
            .overlay(
                shape.stroke(Color(red: 209 / 255, green: 209 / 255, blue: 224 / 255).opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PipFigmaProgressRing: View {
    var progress: CGFloat

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .inset(by: 2)
                .stroke(WBColor.strokeSecondary, style: StrokeStyle(lineWidth: 4))

            if clampedProgress > 0.001 {
                Circle()
                    .inset(by: 2)
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        WBColor.textAccent,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy(duration: 0.32), value: clampedProgress)
            }
        }
        .accessibilityLabel("Прогресс заполнения")
        .accessibilityValue("\(Int((clampedProgress * 100).rounded())) процентов")
    }
}

private struct PipFigmaStickyButtonArea: View {
    let title: String
    var onTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            PipFigmaPrimaryButton(title: title, onTap: onTap)
                .padding(.top, 8)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
    }
}

private struct PipFigmaPrimaryButton: View {
    let title: String
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(WBFont.hauss(17, .medium))
                .foregroundStyle(.white)
                .frame(height: 20)
                .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                .background(WBColor.ctaFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PipFigmaKeyboard: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 7) {
                keyboardRow([
                    .key("1", ""),
                    .key("2", "А Б В Г"),
                    .key("3", "Д Е Ж З"),
                ])
                keyboardRow([
                    .key("4", "И Й К Л"),
                    .key("5", "М Н О П"),
                    .key("6", "Р С Т У"),
                ])
                keyboardRow([
                    .key("7", "Ф Х Ц Ч"),
                    .key("8", "Ш Щ Ъ Ы"),
                    .key("9", "Ь Э Ю Я"),
                ])
                keyboardRow([
                    .blank,
                    .key("0", ""),
                    .backspace,
                ])
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .frame(width: 390, height: 217, alignment: .top)
            .background(Color(hex: 0xD8DADE))

            VStack(spacing: 0) {
                Color.clear.frame(height: 37)
                Image("dsKeyboardHomeIndicator")
                    .resizable()
                    .frame(width: 390, height: 34)
            }
            .frame(width: 390, height: 71)
            .background(Color(hex: 0xD8DADE))
        }
        .frame(width: 390, height: 288)
        .background(Color(hex: 0xD8DADE))
    }

    private func keyboardRow(_ keys: [KeySpec]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                switch key {
                case .key(let number, let letters):
                    KeyboardKey(number: number, letters: letters)
                case .blank:
                    Color.clear
                        .frame(height: 46)
                        .frame(maxWidth: .infinity)
                case .backspace:
                    Image(systemName: "delete.left")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Color(hex: 0x3C3C43).opacity(0.85))
                        .frame(height: 46)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(width: 378, height: 46)
    }

    private enum KeySpec {
        case key(String, String)
        case blank
        case backspace
    }
}

private struct KeyboardKey: View {
    let number: String
    let letters: String

    var body: some View {
        VStack(spacing: 0) {
            Text(number)
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(.black)
                .frame(height: 30)
                .frame(maxWidth: .infinity)

            Text(letters)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .frame(height: 12)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .shadow(color: Color(hex: 0x898A8D), radius: 0, x: 0, y: 1)
    }
}

// MARK: - Shared

struct PipInput: View {
    let field: FormField
    let format: FieldFormat
    @Binding var value: String
    var focus: FocusState<String?>.Binding
    var placeholder: String
    var error: String?

    private var isFocused: Bool { focus.wrappedValue == field.id }
    private var errorColor: Color { Color(hex: 0xFF0F4F) }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: WBRadius.x5, style: .circular)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x2) {
            ZStack(alignment: .leading) {
                if value.isEmpty, !placeholder.isEmpty {
                    Text(placeholder)
                        .font(WBFont.hauss(17, .regular))
                        .foregroundStyle(WBColor.textSecondary)
                        .lineLimit(1)
                }

                TextField("", text: $value)
                    .textFieldStyle(.plain)
                    .font(WBFont.hauss(17, .regular))
                    .foregroundStyle(WBColor.textPrimary)
                    .keyboardType(format.keyboard)
                    .textInputAutocapitalization(format.keyboard == .default ? .sentences : .never)
                    .autocorrectionDisabled(format.keyboard != .default)
                    .tint(WBColor.textAccent)
                    .focused(focus, equals: field.id)
                    .frame(height: 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WBSpace.x4)
            .frame(height: 52)
            .background(WBColor.bgMinus1, in: shape)
            .overlay {
                shape.strokeBorder(
                    error != nil ? errorColor : (isFocused ? WBColor.textPrimary : .clear),
                    lineWidth: 1
                )
            }
            .contentShape(Rectangle())
            .onTapGesture { focus.wrappedValue = field.id }

            if let error {
                Text(error)
                    .font(WBFont.description)
                    .foregroundStyle(errorColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: WBLineHeight.description, alignment: .topLeading)
            }
        }
    }
}

struct PipLargeInput: View {
    let field: FormField
    let format: FieldFormat
    @Binding var value: String
    var focus: FocusState<String?>.Binding
    var placeholder: String
    var error: String?

    private var isFocused: Bool { focus.wrappedValue == field.id }
    private var errorColor: Color { Color(hex: 0xFF0F4F) }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: WBRadius.x5, style: .circular)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x2) {
            ZStack(alignment: .topLeading) {
                if value.isEmpty, !placeholder.isEmpty {
                    Text(placeholder)
                        .font(WBFont.hauss(17, .regular))
                        .foregroundStyle(WBColor.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TextField("", text: $value, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(WBFont.hauss(17, .regular))
                    .foregroundStyle(WBColor.textPrimary)
                    .keyboardType(format.keyboard)
                    .textInputAutocapitalization(format.keyboard == .default ? .sentences : .never)
                    .autocorrectionDisabled(format.keyboard != .default)
                    .tint(WBColor.textAccent)
                    .focused(focus, equals: field.id)
                    .lineLimit(1...4)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            .padding(.horizontal, WBSpace.x4)
            .padding(.vertical, WBSpace.x4)
            .frame(minHeight: 92, alignment: .topLeading)
            .background(WBColor.bgMinus1, in: shape)
            .overlay {
                shape.strokeBorder(
                    error != nil ? errorColor : (isFocused ? WBColor.textPrimary : .clear),
                    lineWidth: 1
                )
            }
            .contentShape(Rectangle())
            .onTapGesture { focus.wrappedValue = field.id }

            if let error {
                Text(error)
                    .font(WBFont.description)
                    .foregroundStyle(errorColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: WBLineHeight.description, alignment: .topLeading)
            }
        }
    }
}

private struct PipFigmaTemplateIcon: View {
    let asset: String
    let size: CGFloat
    let color: Color

    init(_ asset: String, size: CGFloat, color: Color) {
        self.asset = asset
        self.size = size
        self.color = color
    }

    var body: some View {
        Image(asset)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}

struct PipTopCornersShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    PipDesignSystemScreen {}
}
