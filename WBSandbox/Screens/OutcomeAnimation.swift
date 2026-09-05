import SwiftUI

// Тайминги, партиклы и математика анимации экрана исхода.
//
// Хореография перенесена из старой песочницы и перекроена под новую вёрстку.
// Шесть тактов:
//
//   1. вылет     — иконка летит снизу в центр, сплющенная по ширине;
//   2. рогатка   — стоит в центре, бейдж крутит дугу, капли натягиваются;
//   3. выстрел   — капли стреляют в иконку, она усаживается в свою финальную
//                  точку, дуга сматывается в знак статуса;
//   4. волна     — радиальная волна из иконки и разлёт партиклов;
//   5. подъём    — получатель, сумма, комиссия и комментарий проявляются, и тем
//                  же движением белая карточка ужимается снизу, открывая тёмную
//                  панель с кнопками;
//   6. наливание — градиент нарастает сверху вниз, и на его волне проявляются
//                  плитки.
//
// Всё считается как функция от `elapsed`, без `withAnimation`: такты свободно
// накладываются друг на друга и не дерутся за одни и те же свойства.

struct OutcomeAnim {
    /// Множитель замедления для отладки: > 1 замедляет всё и включает автоповтор.
    static let k: Double = 1.0

    /// Сколько крутится лоадер до раскрытия исхода — приходит из сценария.
    let loader: Double

    // 1–3
    var entrance: Double { 0.55 * Self.k }
    var circlesFlight: Double { 0.70 * Self.k }
    var settle: Double { 0.62 * Self.k }
    var badgeHandover: Double { 0.70 * Self.k }

    var loaderStart: Double { entrance }
    var releaseStart: Double { loaderStart + loader }
    var stageEnd: Double { releaseStart + max(circlesFlight, settle) }

    // 4
    var particleDelay: Double { 0.15 * Self.k }
    /// Разлёт — это удар, а не дрейф. На 3,4 с партиклы почти всё время ползли:
    /// кривая `appear` тормозит к концу, и хвост длиной в две секунды читался
    /// как «еле летят». Полторы секунды дают резкий выброс и короткое затухание.
    var particlesDur: Double { 1.5 * Self.k }

    // 5 — фейд контента и подъём панели идут одним движением
    var fadeStart: Double { stageEnd }
    var fadeDur: Double { 0.5 * Self.k }
    var panelStart: Double { stageEnd }
    var panelDur: Double { 0.55 * Self.k }
    var buttonsStart: Double { panelStart + 0.15 * Self.k }
    var buttonsDur: Double { 0.40 * Self.k }

    // 6
    var glowStart: Double { fadeStart + fadeDur + 0.15 * Self.k }
    var glowDur: Double { 1.6 * Self.k }
    /// Момент, когда свет как следует ложится на строку плиток. Их верхняя кромка
    /// стоит в 136 pt от низа полосы 345,84, то есть на 0,607 радиуса. Свет
    /// касается её уже на яркости 0,53, но плитки ждут 0,74 — там цвет под ними
    /// набрал плотность и они проявляются не на белом. По ходу диммера это
    /// примерно половина такта.
    static let tilesFront: Double = 0.5
    var tilesStart: Double { glowStart + glowDur * Self.tilesFront }
    var tilesDur: Double { 0.45 * Self.k }
    /// Сдвиг между соседними плитками, чтобы они не проявлялись синхронно.
    var tilesStagger: Double { 0.07 * Self.k }

    var total: Double {
        max(stageEnd + particleDelay + particlesDur, glowStart + glowDur) + 0.2
    }
}

// MARK: - Партикл

struct OutcomeParticle: Identifiable {
    let id: Int
    let angle: Double
    let distanceFrac: CGFloat
    let size: CGFloat
    let rotation: Double
    let asset: String
    let color: Color
    let delay: Double

    /// Что разлетается — иконки из «📖 DS Icon & Illustration» по теме самой
    /// операции: деньги (монета, карта), кому переводим (человек, двое, банк),
    /// как переводим (по номеру). Старый набор был про госуслуги — орёл, молоток,
    /// квитанция, — и для перевода человеку не годится.
    ///
    /// Взяты ровно 24/Fill, а не 24/Stroke: партикл живёт на экране доли секунды
    /// и пролетает мимо, штриховой контур на такой скорости не читается —
    /// видно только серую загогулину.
    static let assets = ["ptCoins", "ptCard", "ptUser", "ptUsers", "ptPhone", "ptBank"]

    /// Дуга разлёта: 300° вверх и в стороны, вниз партиклы не летят — там сумма
    /// и комментарий.
    private static let arc: Double = 300

    static func make(colors: [Color]) -> [OutcomeParticle] {
        let sizes: [CGFloat] = [22, 24, 26, 28, 30, 32]
        let bag = (assets + assets).shuffled()
        let sector = arc / Double(bag.count)

        return bag.enumerated().map { index, asset in
            // Углы не разыгрываем: дюжина случайных чисел на дуге неизбежно
            // сбивается в комки и оставляет проплешины — то, что видно глазу
            // как «всё улетело вправо». Даём каждому партиклу свой сектор и
            // дрожим внутри него, чтобы не читалась решётка.
            let jitter = Double.random(in: -0.35...0.35) * sector
            let degrees = -arc / 2 + sector * (Double(index) + 0.5) + jitter

            return OutcomeParticle(
                id: index,
                angle: degrees * .pi / 180,
                // Доля пути до кромки экрана в своём направлении, а не доля
                // диагонали: иначе боковые улетают за край втрое быстрее верхних
                // и поле опять редеет по краям.
                distanceFrac: CGFloat.random(in: 1.0...1.35),
                size: sizes.randomElement()!,
                rotation: Double.random(in: -30...30),
                asset: asset,
                color: colors[index % colors.count],
                delay: Double.random(in: 0...0.14)
            )
        }
    }
}

// MARK: - Кривые

/// Кривые по ролям, а не по вкусу. Правило: у каждой величины ровно одна роль,
/// кривая применяется ровно один раз и только здесь. Сырой линейный прогресс,
/// попавший прямо в визуальное свойство, — это баг, как и две кривые подряд:
/// именно от такой мешанины анимация начинает казаться кривой на глаз.
///
/// `prog` возвращает сырые 0…1. Кривую накладывает тот, кто величину использует.
enum Ease {
    /// Перемещение, масштаб, размеры. Объект трогается и останавливается мягко.
    static func move(_ p: CGFloat) -> CGFloat { easeInOut(p) }

    /// Появление и всё, что тормозит само: проявление, разлёт, ударная волна.
    static func appear(_ p: CGFloat) -> CGFloat { easeOut(p) }

    /// Вылет: резкий старт и длинное торможение. Для предмета, который бросили и
    /// который сам гасит скорость — в отличие от `appear`, где торможение
    /// квадратичное и потому ровное, здесь основная часть пути проходится в
    /// первой трети такта, а конец подходит почти вплотную.
    static func launch(_ p: CGFloat) -> CGFloat { easeOutQuart(p) }

    /// Разгон: натяжение рогатки, схлопывание капли, уход в прозрачность.
    static func accelerate(_ p: CGFloat) -> CGFloat { easeIn(p) }

    /// Выезд с пружиной — только для смещения в `reveal`.
    static func spring(_ p: CGFloat) -> CGFloat { easeOutBack(p) }
}

// MARK: - Каскадное проявление

extension View {
    /// Проявление с выездом снизу и лёгкой пружиной. rise — дистанция выезда.
    /// Прозрачность и смещение считаются от одного и того же сырого прогресса,
    /// каждое по своей роли: проявление тормозит, смещение пружинит.
    func reveal(_ p: CGFloat, rise: CGFloat = 12) -> some View {
        let t = clamp01(p)
        return opacity(Double(Ease.appear(t)))
            .offset(y: (1 - Ease.spring(t)) * rise)
    }
}

// MARK: - Верхний цвет градиента капель

extension Color {
    /// Бледный верх капли: берём тон логотипа, слегка сдвигаем к циану, сбрасываем
    /// насыщенность до пастельной и поднимаем яркость на максимум.
    func glowHighlight(hueShift: CGFloat = -0.07, paleSaturation: CGFloat = 0.36) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        var shifted = h + hueShift
        if shifted < 0 { shifted += 1 } else if shifted > 1 { shifted -= 1 }
        return Color(hue: Double(shifted), saturation: Double(paleSaturation), brightness: 1, opacity: Double(a))
    }
}

// MARK: - Математика

func clamp01(_ x: CGFloat) -> CGFloat { min(1, max(0, x)) }

/// Прогресс 0…1 отрезка, начинающегося в `start` и длящегося `dur`.
func prog(_ elapsed: TimeInterval, _ start: Double, _ dur: Double) -> CGFloat {
    clamp01(CGFloat((elapsed - start) / dur))
}

func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
func easeIn(_ x: CGFloat) -> CGFloat { x * x }
func easeOut(_ x: CGFloat) -> CGFloat { 1 - (1 - x) * (1 - x) }
/// Торможение четвёртой степени: половина пути пройдена за первые 16 % такта,
/// три четверти — за 30 %, остальное подходит вплотную.
func easeOutQuart(_ x: CGFloat) -> CGFloat { 1 - pow(1 - x, 4) }
func easeInOut(_ x: CGFloat) -> CGFloat {
    x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
}

/// Один горб без ухода в минус: быстро вырастает по инерции и оседает к нулю.
func overshootPulse(_ q: CGFloat) -> CGFloat {
    let x = clamp01(q)
    return sin(.pi * x) * (1 - x)
}

func easeOutBack(_ x: CGFloat) -> CGFloat {
    let c1: CGFloat = 1.70158
    let c3 = c1 + 1
    let t = x - 1
    return 1 + c3 * t * t * t + c1 * t * t
}

/// Квадратичная кривая Безье — по ней капли летят в иконку.
func bezier(_ a: CGFloat, _ c: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    let mt = 1 - t
    return mt * mt * a + 2 * mt * t * c + t * t * b
}
