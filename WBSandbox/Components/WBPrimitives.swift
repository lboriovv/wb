import SwiftUI
import UIKit

// MARK: - Иконка строки

struct RowIconView: View {
    let icon: RowIcon
    var size: CGFloat = 40

    var body: some View {
        switch icon {
        case .asset(let name):
            // Экспорт из макета: подложка и скругление уже внутри картинки.
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        case .brandedAsset(let name, let tint):
            // В Figma герб ЖКУ — не готовая плитка: он лежит поверх отдельного
            // бордового фона 40×40 с радиусом 12.
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(tint)
                .frame(width: size, height: size)
                .overlay {
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
                }
        case .logo(let name, let logo, let background, let radius, let offset):
            // Подложка и логотип живут отдельно: в макете это заливка плитки и
            // вектор поверх неё, и оба масштабируются вместе с размером строки.
            RoundedRectangle(cornerRadius: size * radius, style: .continuous)
                .fill(background)
                .frame(width: size, height: size)
                .overlay {
                    Image(name)
                        .resizable()
                        .frame(width: size * logo.width, height: size * logo.height)
                        .offset(x: size * offset.width, y: size * offset.height)
                }
        case .symbol(let name, let tint, let background):
            // Радиус пропорционален плитке (12 при 40), иначе на 24 pt заглушка
            // превращается в круг.
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(background)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: name)
                        .font(.system(size: size * 0.5, weight: .semibold))
                        .foregroundStyle(tint)
                }
        }
    }
}

// MARK: - Иконка 24 из макета

/// Вектор, выгруженный из Figma, редко занимает весь квадрат 24 pt: у экспорта
/// своя рамка, а внутри квадрата он стоит по отступам компонента. Поэтому кадр
/// вектора задаём явно, в координатах квадрата 24×24.
struct DSIcon {
    let asset: String
    let frame: CGRect

    static let fileText = DSIcon(
        asset: "icFileText24",
        frame: CGRect(x: 3, y: 1, width: 18, height: 22)
    )
    static let reloader = DSIcon(
        asset: "icReloader24",
        frame: CGRect(x: 1.83, y: 0, width: 21.12, height: 22.95)
    )
    static let checkmark = DSIcon(
        asset: "icCheckmark24",
        frame: CGRect(x: 4, y: 5, width: 16.96, height: 12.52)
    )
    static let close = DSIcon(
        asset: "icClose24",
        frame: CGRect(x: 5, y: 5, width: 14, height: 14)
    )
    /// 16/Stroke/timeBold — только стрелки часов: циферблатом служит обводка
    /// кружка статуса. Кадр пересчитан из знака 15,673 в квадрат 24.
    static let timeBold = DSIcon(
        asset: "icTimeBold",
        frame: CGRect(x: 5.25, y: 5.0, width: 10.75, height: 9.0)
    )
}

struct DSIconView: View {
    let icon: DSIcon
    var size: CGFloat = 24

    var body: some View {
        let scale = size / 24
        Image(icon.asset)
            .resizable()
            .frame(width: icon.frame.width * scale, height: icon.frame.height * scale)
            .offset(x: icon.frame.minX * scale, y: icon.frame.minY * scale)
            .frame(width: size, height: size, alignment: .topLeading)
    }
}

// MARK: - Бейдж

struct WBBadgeView: View {
    let badge: BadgeSpec

    private var background: Color {
        switch badge.style {
        case .greenSoft: WBColor.badgeGreenBg
        case .greenStrong: WBColor.badgeGreenStrongBg
        case .berry: WBColor.badgeBerryBg
        case .wbCash: WBColor.badgeCashBg
        case .neutral: WBColor.bgMinus1
        case .violet: WBColor.violet.opacity(0.12)
        case .wbCoin: WBColor.badgeCoinBg
        }
    }

    private var foreground: Color {
        switch badge.style {
        // В макете текст бейджа комиссии тёмный (#242429), а не зелёный —
        // зелёный только фон. Замерено по рендеру узла 818:140760.
        case .greenSoft: WBColor.textPrimary
        case .greenStrong: WBColor.textAccent
        case .berry: WBColor.badgeBerryText
        case .wbCash: WBColor.badgeCashText
        case .neutral: WBColor.textSecondary
        case .violet: WBColor.violet
        case .wbCoin: .white
        }
    }

    var body: some View {
        HStack(spacing: WBSpace.x1) {
            Text(badge.isUppercase ? badge.text.uppercased() : badge.text)
                .font(badge.isUppercase ? WBFont.caption : WBFont.descriptionAccent)
                // Font/Letter spacing/chameleon в макете равен 0 — трекинга нет
                // даже у капслока.
                .tracking(0)
                .foregroundStyle(foreground)
            if let icon = badge.iconAsset {
                Image(icon)
                    .resizable()
                    .frame(width: 12, height: 12)
            }
        }
        // Small-размер бейджа в макете 20,93 против 22 у капслока и 24 у обычного.
        .padding(.horizontal, badge.style == .wbCoin ? 7 : WBSpace.x2)
        .frame(height: badge.style == .wbCoin ? 20.93 : (badge.isUppercase ? 22 : 24))
        .background(background, in: Capsule())
    }
}

// MARK: - Навбар

struct WBNavBar: View {
    let title: String
    var subtitle: String?
    var leading: LeadingStyle = .back
    var trailing: RowIcon?
    var onLeading: () -> Void = {}

    enum LeadingStyle { case back, close, none }

    var body: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(title)
                    .font(WBFont.navTitle)
                    .foregroundStyle(WBColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 48)

            HStack(spacing: 0) {
                if leading != .none {
                    Button(action: onLeading) {
                        Group {
                            if leading == .close {
                                DSIconView(icon: .close)
                            } else {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(WBColor.textPrimary)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        // Зона нажатия 44×44: в макете кнопка навбара всегда такая,
                        // а иконка стоит по её центру — то есть в 26 pt от кромки.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                }
                Spacer(minLength: 0)
                if let trailing {
                    RowIconView(icon: trailing, size: 22)
                        .frame(width: 44, height: 44)
                }
            }
        }
        // В макете строка навбара 48 pt (карточка 92 = статус-бар 44 + 48).
        .frame(height: 48)
        .padding(.horizontal, WBSpace.x1)
    }
}

// MARK: - Основная кнопка

struct WBPrimaryButton: View {
    let title: String
    /// Вторая строка внутри кнопки — сумма в варианте «Пополнить на N ₽».
    var subtitle: String?
    /// Размер заголовка. По умолчанию сохраняем прежний вариант компонента;
    /// этап выбора счёта использует action-токен 17 pt из Figma.
    var titleSize: CGFloat = 16
    var fill: Color = WBColor.ctaFill
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: titleSize, weight: subtitle == nil ? .medium : .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .opacity(0.9)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            // Не капсула: замер по рендеру макета 818:140807 даёт радиус ≈ 21 при
            // высоте 52 — то есть токен --mo-CRx5 (20), а не полное скругление.
            .background(fill, in: RoundedRectangle(cornerRadius: WBRadius.x5))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
        .animation(.snappy(duration: 0.25), value: fill)
    }
}

// MARK: - Хвостик тултипа

/// Треугольник-указатель над чипом комментария (макет: 20×7).
struct TooltipArrow: View {
    var fill: Color = WBColor.bgMinus1

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 7))
            path.addQuadCurve(to: CGPoint(x: 10, y: 0), control: CGPoint(x: 7, y: 7))
            path.addQuadCurve(to: CGPoint(x: 20, y: 7), control: CGPoint(x: 13, y: 7))
            path.closeSubpath()
        }
        .fill(fill)
        .frame(width: 20, height: 7)
    }
}

// MARK: - Тактильная отдача

enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)

    static func key() {
        soft.impactOccurred(intensity: 0.6)
    }

    static func tap() {
        light.impactOccurred()
    }

    /// Отдельные удары под такты анимации исхода: вылет, прилёт, выстрел,
    /// наливание — у каждого своя жёсткость.
    static func impact(
        _ style: UIImpactFeedbackGenerator.FeedbackStyle,
        intensity: CGFloat? = nil
    ) {
        let generator = style == .rigid ? rigid : UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        if let intensity {
            generator.impactOccurred(intensity: intensity)
        } else {
            generator.impactOccurred()
        }
        generator.prepare()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
