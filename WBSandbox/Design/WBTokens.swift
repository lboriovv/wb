import SwiftUI
import UIKit

// Токены сняты напрямую с макета «🥶Леонид песочница» → страница «транзакционный экран».
// Имена соответствуют переменным дизайн-системы (--mo-*), чтобы при переезде на
// реальный WBM ui-kit достаточно было переставить значения в этом файле.

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum WBColor {
    // Фоны
    static let bgBase = Color.dynamic(light: 0xFFFFFF, dark: 0x1C1C20)       // --mo-bg-level-1-base
    static let bgMinus1 = Color.dynamic(light: 0xF6F6F9, dark: 0x111114)     // --mo-bg-level--1
    static let bgLevel2 = Color.dynamic(light: 0xF6F6F9, dark: 0x292930)     // --mo-bg-level-2
    static let bgPurpleLight = Color.dynamic(light: 0xFEECFD, dark: 0x3A203D) // --mo-bg-purpleLight
    static let bgBlueLight = Color.dynamic(light: 0xE2F4FC, dark: 0x173244)   // плитка бюджетного получателя
    static let bgAccentSecondaryLight = Color.dynamic(light: 0xFEEBF7, dark: 0x3C2032) // --mo-bg-accentSecondaryLight
    static let bgRedLight = Color.dynamic(light: 0xFEE6EB, dark: 0x3D1F28)   // --mo-bg-redLight, подложка стикера

    // Текст и иконки
    static let textPrimary = Color.dynamic(light: 0x242429, dark: 0xF4F4F7)   // --mo-text-icon-primary
    static let textSecondary = Color.dynamic(light: 0x808093, dark: 0xAEAEBF) // --mo-text-icon-secondary
    static let textAccent = Color.dynamic(light: 0x038F5D, dark: 0x35D690)    // --mo-text-icon-accent (каретка суммы)
    static let controlsSecondary = Color.dynamic(light: 0x8F8FA3, dark: 0xB5B5C6) // --mo-controls-text-icon-secondary-default
    /// wbWallet/actionAccent — подпись способа оплаты в шите.
    static let walletActionAccent = Color.dynamic(light: 0x34214D, dark: 0xD9C4FF)
    /// --mo-radioButton-content-off-default — обводка невыбранного радио.
    static let radioOff = Color.dynamic(light: 0xE0E0EB, dark: 0x4B4B56)
    /// Крестик закрытия шита.
    static let controlsTertiary = Color.dynamic(light: 0xCBCBD9, dark: 0x777786)

    // Акценты
    static let badgeGreenBg = Color.dynamic(light: 0xE9F5EF, dark: 0x18382A)
    /// Бейдж списания ягодок: «−100» (макет 906:206906).
    static let badgeBerryBg = Color.dynamic(light: 0xFEECFC, dark: 0x3A203D)
    static let badgeBerryText = Color.dynamic(light: 0xC539DD, dark: 0xF374FF)
    /// Бейдж списания WB Кэша: «−3 000» (макет 906:206907).
    static let badgeCashBg = Color.dynamic(light: 0xFAEDFC, dark: 0x33213F)
    static let badgeCashText = Color.dynamic(light: 0xA73AFC, dark: 0xC792FF)
    static let badgeGreenStrongBg = Color.dynamic(light: 0xD5EDE2, dark: 0x214B37)
    static let violet = Color.dynamic(light: 0x863CE5, dark: 0xB679FF)
    static let brandBlue = Color.dynamic(light: 0x00A6E3, dark: 0x35C9FF)
    static let brandYellow = Color(hex: 0xFFDD2D)
    static let pink = Color.dynamic(light: 0xFF3DA5, dark: 0xFF74BF)

    // Кнопка
    static let ctaFill = Color(hex: 0x2F2F37)
    /// Кнопка «Пополнить на N ₽», когда на счёте не хватает денег.
    static let ctaTopUp = Color.dynamic(light: 0xFF7E22, dark: 0xFF9A4A)

    // Отказ. В макете этого состояния нет — цвета подобраны по системной семантике
    // WB (красный из логотипа ЦР) и ждут решения дизайнера.
    static let declined = Color.dynamic(light: 0xE5352B, dark: 0xFF645A)
    static let declinedSoft = Color.dynamic(light: 0xFDECEA, dark: 0x3D211F)

    // Экран исхода (макеты 925:207394 — успех, 927:207898 — обработка,
    // 927:207846 — отказ)

    /// Фон под карточкой: он же подложка панели с кнопками. У каждого исхода свой.
    static let deepGreen = Color(hex: 0x002F1E)
    static let deepBlue = Color(hex: 0x1A1D28)
    static let deepBrown = Color(hex: 0x1F2016)

    /// Кружки статуса у иконки получателя.
    static let bgSuccess = Color(hex: 0x1AB266)   // --mo-bg-success
    static let bgBlue = Color(hex: 0x0098FE)      // --mo-bg-blue
    static let bgDanger = Color(hex: 0xFA1F4B)    // --mo-bg-danger

    /// Подложки плиток получателя в макетах исходов.
    static let tileServiceBlue = Color(hex: 0x0098FE)
    static let tileBankGreen = Color(hex: 0x209F38)

    /// --mo-text-icon-quaternary — подписи под кнопками у обработки и отказа.
    static let textQuaternary = Color(hex: 0xE0E0EB)
    /// Бейдж «вб» на плитке с бонусами.
    static let badgeCoinBg = Color(hex: 0xFF00EA)

    /// Высота блока свечения под карточкой — одна на все исходы.
    static let glowHeight: CGFloat = 345.842

    // Формы сложных платежей

    /// Разделитель между полями внутри белой карточки. Светлее обводки радио, но
    /// заметнее фона: он делит список, а не рисует рамку.
    static let separator = Color.dynamic(light: 0xEDEDF2, dark: 0x34343C)
    /// Предупреждение: сервис поставщика недоступен, платим без проверки.
    /// Текст темнее кнопки «Пополнить», иначе на белом он не читается.
    static let warn = Color.dynamic(light: 0xB55206, dark: 0xFFAA5E)
    static let warnLight = Color.dynamic(light: 0xFFF2E6, dark: 0x3C2A1C)
    /// Фон подсказки с найденным начислением.
    static let okLight = Color.dynamic(light: 0xEAF6F0, dark: 0x183528)

    // Шапка поставщика в концепции с этапами (макет 48052:140411): градиент в
    // бренде поставщика, сверху светлее. Цвета сняты с рендера макета ЖКУ Москвы.
    static let brandCrimsonTop = Color(hex: 0xD42A4A)
    static let brandCrimsonBottom = Color(hex: 0x7F0F26)
}

// MARK: - Свечение под карточкой

/// Радиальное свечение BG1/BG2: эллипс с центром в верхней кромке блока высотой
/// 345,84. По горизонтали он заметно шире экрана, поэтому у краёв цвет поднимается
/// выше, чем по центру. В макетах исходов таких слоёв два: основной и «призрак»
/// соседнего исхода на 10 % под ним.
struct WBGlow {
    let gradient: Gradient
    /// Полуось эллипса по горизонтали. По вертикали всегда `WBColor.glowHeight`.
    let halfWidth: CGFloat
    var opacity: Double = 1

    var size: CGSize { CGSize(width: halfWidth * 2, height: WBColor.glowHeight * 2) }

    /// Стопы из макета: положение, цвет, прозрачность.
    typealias Stops = [(location: Double, rgb: UInt32, alpha: Double)]

    /// SwiftUI смешивает соседние стопы с premultiplied alpha, Figma — без неё,
    /// и на длинном участке 0,32…0,56 разница доходит до 7 единиц по каналу.
    /// Поэтому сэмплируем исходные стопы часто: на коротком отрезке способ
    /// смешивания уже не важен, а слои можно честно класть друг на друга.
    static func gradient(_ stops: Stops) -> Gradient {
        func sample(_ t: Double) -> Color {
            var lower = stops[0]
            var upper = stops[stops.count - 1]
            for index in 1..<stops.count where stops[index].location >= t {
                lower = stops[index - 1]
                upper = stops[index]
                break
            }
            let span = upper.location - lower.location
            let f = span > 0 ? (t - lower.location) / span : 0

            func channel(_ shift: UInt32) -> Double {
                let from = Double((lower.rgb >> shift) & 0xFF)
                let to = Double((upper.rgb >> shift) & 0xFF)
                return (from + (to - from) * f) / 255
            }

            return Color(
                .sRGB,
                red: channel(16),
                green: channel(8),
                blue: channel(0),
                opacity: lower.alpha + (upper.alpha - lower.alpha) * f
            )
        }

        let start = stops[0].location
        let steps = 48
        var result: [Gradient.Stop] = [.init(color: .white.opacity(0), location: 0)]
        for step in 0...steps {
            let t = start + (1 - start) * Double(step) / Double(steps)
            result.append(.init(color: sample(t), location: t))
        }
        return Gradient(stops: result)
    }

    /// BG1 экрана успеха (925:207399).
    static let green = WBGlow(
        gradient: gradient([
            (0.32,   0xFFFFFF, 0.0),
            (0.56,   0x81C7C5, 0.5),
            (0.67,   0x42B799, 0.75),
            (0.725,  0x22AF82, 0.875),
            (0.7525, 0x12AB77, 0.9375),
            (0.78,   0x02A76C, 1.0),
            (0.89,   0x02764B, 1.0),
            (0.945,  0x025E3B, 1.0),
            (1.0,    0x01462B, 1.0),
        ]),
        halfWidth: 605.72
    )

    /// BG1 экрана обработки (927:207903).
    static let blue = WBGlow(
        gradient: gradient([
            (0.32,   0xFFFFFF, 0.0),
            (0.56,   0x90D6EA, 0.5),
            (0.67,   0x4AB9E5, 0.75),
            (0.725,  0x27AAE3, 0.875),
            (0.7525, 0x16A2E2, 0.9375),
            (0.78,   0x059BE1, 1.0),
            (0.835,  0x107DD3, 1.0),
            (0.89,   0x1A5FC5, 1.0),
            (0.945,  0x2541B7, 1.0),
            (1.0,    0x3023A9, 1.0),
        ]),
        halfWidth: 603.84
    )

    /// BG2 экрана отказа (927:207850).
    static let orange = WBGlow(
        gradient: gradient([
            (0.32,  0xFFFFFF, 0.0),
            (0.56,  0xF0CE89, 0.5),
            (0.67,  0xE59B4D, 0.75),
            (0.725, 0xE0812F, 0.875),
            (0.78,  0xDA6811, 1.0),
            (0.89,  0xAD4108, 1.0),
            (0.945, 0x962D04, 1.0),
            (1.0,   0x801A00, 1.0),
        ]),
        halfWidth: 601.84
    )

    func faded(_ value: Double) -> WBGlow {
        WBGlow(gradient: gradient, halfWidth: halfWidth, opacity: value)
    }
}

// MARK: - Палитра живого свечения

/// Три оттенка одного свечения для шейдера `outcomeEmber`: разреженный край,
/// середина и плотное ядро у нижней кромки.
///
/// Стопы не подобраны на глаз, а сняты с того самого радиального градиента,
/// который ember заменяет, — по одному на каждую зону: 0,56 (там, где цвет только
/// проступает), 0,78 (первый полностью непрозрачный стоп — им исход и опознаётся)
/// и 1,0 (внешний радиус, он же нижняя кромка блока). Поэтому v1 и v2 светят
/// одним цветом, а различаются только формой и жизнью света.
struct EmberPalette {
    let edge: SIMD3<Float>
    let mid: SIMD3<Float>
    let core: SIMD3<Float>

    /// sRGB-компоненты 0…1: шейдер смешивает цвета сам, поэтому ему нужны числа,
    /// а не `Color`.
    static func rgb(_ hex: UInt32) -> SIMD3<Float> {
        SIMD3(
            Float((hex >> 16) & 0xFF) / 255,
            Float((hex >> 8) & 0xFF) / 255,
            Float(hex & 0xFF) / 255
        )
    }

    /// Успех — из `WBGlow.green`.
    static let green = EmberPalette(
        edge: rgb(0x81C7C5),
        mid: rgb(0x02A76C),
        core: rgb(0x01462B)
    )

    /// Обработка — из `WBGlow.blue`. Ядро уходит в индиго: в макете внешний радиус
    /// градиента именно там, голубым он остаётся только в середине.
    static let blue = EmberPalette(
        edge: rgb(0x90D6EA),
        mid: rgb(0x059BE1),
        core: rgb(0x3023A9)
    )

    /// Отказ — из `WBGlow.orange`: песочный край, оранжевая середина, жжёное ядро.
    static let orange = EmberPalette(
        edge: rgb(0xF0CE89),
        mid: rgb(0xDA6811),
        core: rgb(0x801A00)
    )
}

enum WBSpace {
    static let x0_5: CGFloat = 2
    static let x1: CGFloat = 4
    static let x1_5: CGFloat = 6
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x10: CGFloat = 40
    static let x11: CGFloat = 44
}

enum WBRadius {
    static let x1_5: CGFloat = 6
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24
    static let full: CGFloat = 100
}

// Макет набран в ALS Hauss VF. Шрифта нет в системе, поэтому прототип рисуется
// системным SF Pro с теми же кеглями и интерлиньяжем. Чтобы подставить настоящий
// шрифт: положить .ttf в проект, прописать UIAppFonts в Info.plist и заменить
// `Font.system` на `Font.custom("ALS Hauss VF", size:)` — только в этом enum.
enum WBFont {
    static func hauss(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }

    /// wbWallet/lgBalance — 44/44 Regular. Крупная сумма на транзакционном экране.
    static let balance = hauss(44, .regular)
    /// Сумма на экране успеха — тот же кегль 44/44, что и на транзакционном.
    static let successAmount = hauss(44, .regular)
    /// Подпись под кнопкой действия на экране успеха — 12,971/16,962 Medium.
    static let successAction = hauss(12.971, .medium)
    /// Title/title1 и display2 — 24/29 Bold (клавиатура, заголовок шита).
    static let title1 = hauss(24, .bold)
    /// Заголовок навбара.
    static let navTitle = hauss(17, .medium)
    /// Title/title3 — 17/22 Regular. Строка «Пополнять при покупке».
    static let title3 = hauss(17, .regular)
    /// Title/title3 — 17/20 Bold. Заголовки секций в шите.
    static let title3Bold = hauss(17, .bold)
    /// Body/body — 15/20 Regular.
    static let body = hauss(15, .regular)
    /// Body/bodyAccent — 15/20 Medium.
    static let bodyAccent = hauss(15, .medium)
    /// Description/description — 13/17 Regular.
    static let description = hauss(13, .regular)
    static let descriptionAccent = hauss(13, .medium)
    /// Caption/captionUppercase — бейджи, капслок с трекингом.
    static let caption = hauss(11, .medium)
}

enum WBLineHeight {
    /// SwiftUI задаёт межстрочку через lineSpacing, поэтому для одиночных строк
    /// достаточно фиксировать высоту блока там, где макет её задаёт явно.
    static let balance: CGFloat = 44
    static let body: CGFloat = 20
    static let description: CGFloat = 17
}
