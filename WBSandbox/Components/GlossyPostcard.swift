import SwiftUI

// MARK: - Модель открытки

/// Вариант открытки к переводу. Лицо — либо фотография, либо графика на
/// градиенте: карусель должна показывать, что варианты бывают разной природы, а
/// эффект наклона одинаково работает и на фото, и на плашке.
struct Postcard: Identifiable, Hashable {
    let id: String
    let title: String
    let face: Face

    enum Face: Hashable {
        case photo(String)
        /// Поздравление на градиенте. Стикер рисуется в своём родном размере:
        /// готовые ассеты в проекте по 96–180 px, на карточке 310 pt они мылят,
        /// поэтому крупный элемент здесь — надпись, а не картинка.
        case lettering(greeting: String, colors: [Color], sticker: String, stickerSide: CGFloat)
    }
}

enum PostcardCatalog {
    /// Готовые дизайны открыток из папки `Открытки`. Каждый вариант хранится
    /// цельным изображением: текст и иллюстрация уже являются частью макета.
    static let all: [Postcard] = [
        Postcard(id: "warm", title: "С теплом", face: .photo("pcWarm")),
        Postcard(
            id: "everything-works",
            title: "Пусть всё получится",
            face: .photo("pcEverythingWorks")
        ),
        Postcard(id: "own-wave", title: "На своей волне", face: .photo("pcOwnWave")),
        Postcard(
            id: "wish-come-true",
            title: "Желание сбудется",
            face: .photo("pcWishComeTrue")
        ),
        Postcard(id: "full-speed", title: "Полный вперёд", face: .photo("pcFullSpeed")),
        Postcard(id: "for-you", title: "Это тебе", face: .photo("pcForYou")),
    ]
}

// MARK: - Геометрия карусели
//
// Числа сняты с макета 46432:621675. Соседняя карточка там ровно вдвое меньше
// активной (154,875 / 310 = 0,4996), и радиус у неё тоже вдвое меньше (10
// против 20) — то есть в макете это та же самая карточка, уменьшенная целиком.
// Поэтому в коде мы не подбираем радиус для соседей, а масштабируем готовую
// карточку через `scaleEffect`: значения совпадут сами.

enum PostcardMetrics {
    static let cardSize = CGSize(width: 310, height: 413.333)
    static let cornerRadius: CGFloat = 20

    /// Масштаб соседней карточки.
    static let neighborScale: CGFloat = 0.4996
    /// Расстояние между центрами активной и соседней карточки.
    static let neighborStep: CGFloat = 248.44
    /// Разворот соседей: правый +2°, левый −2°.
    static let neighborTilt: Double = 2
}

// MARK: - Лицо открытки

/// Отдельная вью, потому что рисуется дважды: в карточке и во весь экран под
/// размытием фона.
struct PostcardFace: View {
    let card: Postcard

    var body: some View {
        switch card.face {
        case .photo(let asset):
            Image(asset)
                .resizable()
                .aspectRatio(contentMode: .fill)

        case .lettering(let greeting, let colors, let sticker, let side):
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(sticker)
                            .resizable()
                            .frame(width: side, height: side)
                            .shadow(color: .black.opacity(0.22), radius: 10, y: 6)

                        Text(greeting)
                            .font(WBFont.hauss(34, .semibold))
                            .tracking(-0.8)
                            .lineSpacing(-2)
                            .foregroundStyle(.white)
                    }
                    .padding(28)
                }
        }
    }
}

// MARK: - Оборот открытки

/// Обратная сторона. Нужна для двух вещей: в подарке открытка лежит лицом вниз,
/// а в полёте с двумя оборотами оборот видно дважды — без него карточка
/// показывала бы зеркальное лицо, и это читается как ошибка, а не как поворот.
///
/// Нарисована фигурами, а не картинкой: в полёте карточка проходит все размеры
/// от 0,34 до 1, растровый оборот на этом пути мылил бы. Если передать
/// `message`, вместо адресных линий показывается текст поздравления.
struct PostcardBackFace: View {
    var message: String? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .topLeading) {
                WBColor.bgMinus1

                // Делитель, как на почтовой открытке: слева адрес, справа марка.
                Rectangle()
                    .fill(WBColor.separator)
                    .frame(width: 1, height: h * 0.74)
                    .offset(x: w * 0.58, y: h * 0.13)

                // Марка.
                RoundedRectangle(cornerRadius: w * 0.025, style: .continuous)
                    .fill(.white)
                    .frame(width: w * 0.13, height: w * 0.16)
                    .overlay {
                        Image("artClover")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(w * 0.022)
                    }
                    .offset(x: w * 0.74, y: h * 0.09)

                if let message {
                    Text(message)
                        .font(WBFont.title1)
                        .lineSpacing(5)
                        .foregroundStyle(WBColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: w * 0.42, alignment: .leading)
                        .rotationEffect(.degrees(-4))
                        .offset(x: w * 0.09, y: h * 0.22)
                } else {
                    // Строки адреса.
                    VStack(alignment: .leading, spacing: w * 0.05) {
                        ForEach(0..<3, id: \.self) { line in
                            Capsule()
                                .fill(WBColor.textSecondary.opacity(0.16))
                                .frame(width: w * (0.40 - Double(line) * 0.07), height: w * 0.016)
                        }
                    }
                    .offset(x: w * 0.09, y: h * 0.6)
                }
            }
        }
    }
}

// MARK: - Карточка с наклоном и бликом

/// Открытка, которая искажается в наклоне. Два слоя поверх лица:
///
/// 1. `SpecularGlare` — белый блик в ближней точке. Он и создаёт ощущение объёма:
///    перспектива сама по себе читается слабо, а свет, который убегает в
///    поднятый угол, читается сразу.
/// 2. `FarSideShade` — почти незаметное затемнение дальней половины. Парный к
///    блику намёк: если ближний край светлее, дальний обязан быть темнее.
///
/// Белой обводки 2 pt из макета здесь нет намеренно: в наклоне она не даёт
/// объёма, а обводит плоскую фигуру — на карточке это читается как обрубленный
/// край, а не как кромка предмета.
///
/// Сам наклон навешивается снаружи (`CardTiltEffect`), чтобы в карусели он
/// складывался с масштабом и разворотом соседей.
struct GlossyPostcardView: View {
    let card: Postcard
    let tilt: TiltInput
    /// Яркость блика. Гасим у соседних карточек: там блика в макете нет.
    var glare: Double = 1

    var body: some View {
        PostcardFace(card: card)
            .frame(width: PostcardMetrics.cardSize.width, height: PostcardMetrics.cardSize.height)
            .overlay { FarSideShade(tilt: tilt) }
            .overlay { SpecularGlare(tilt: tilt, strength: glare) }
            .clipShape(
                RoundedRectangle(cornerRadius: PostcardMetrics.cornerRadius, style: .continuous)
            )
    }
}

// MARK: - Блик
//
// Перенос `SpecularLayer` и `HolographicMath.edgeSquish` из старой версии
// голокарточки Brighty (`Features/HolographicCard`). Математика взята без
// изменений, пересчитаны только пропорции под размер этой карточки.
//
// Идея, ради которой это перенесено, — **две координаты вместо одной**:
//
//   • «сырое» положение считается в процентах и свободно уходит за 0…100;
//   • рисуется блик по **зажатому** значению, а сырое идёт только в деформацию.
//
// Поэтому блик доезжает до кромки, прилипает к ней и дальше продолжает отвечать
// на наклон — но уже формой, а не смещением. Оторваться от границы он физически
// не может. Прежняя реализация именно этим и была плоха: центр уходил за кромку,
// и на сильном наклоне блик повисал пятном в углу.
//
// Форма меняется двумя правилами, и оба детерминированные — никакого поворота:
//
//   1. **Сжатие у кромки** (`edgeSquish`). В зоне 22 % от края соответствующая
//      ось жмётся до 0,42. Подъехал к правой кромке — пятно стало вертикальной
//      линзой на всю высоту; подъехал к низу — горизонтальной; в углу жмутся обе
//      оси и остаётся плотный сгусток. Набор форм конечный: круг в центре,
//      четыре линзы, четыре сгустка, между ними непрерывная интерполяция.
//   2. **Дыхание радиусов** от величины наклона. Чем сильнее горизонтальный
//      наклон, тем пятно уже по горизонтали, и наоборот. В Brighty это правило
//      висело на `CutoutLayer`; здесь оно перенесено на сам блик, чтобы форма
//      начинала жить раньше, чем включится сжатие у кромки.
//
// Блик не крутится, и это принципиально: лампа не крутится — крутится карточка
// под ней. Поворот блика подменял бы деформацию, и именно от этого он читался
// как наклейка, которая ездит по поверхности.

private struct SpecularGlare: View {
    let tilt: TiltInput
    /// Яркость. Гасим у соседних карточек в карусели.
    let strength: Double

    /// Ход блика: сколько процентов карточки он проходит на градус наклона.
    /// **Связь линейная, и другой она быть не может.**
    ///
    /// Здесь была попытка успокоить блик кривой — медленно у нуля, быстрее к
    /// пределу. Она и сломала ощущение: отражение перестало быть привязанным к
    /// поверхности. Пятно стояло на месте, потом резко улетало, у кромки
    /// упиралось в зажим — и читалось как светлячок, который летает сам по себе,
    /// а не как свет на поверхности.
    ///
    /// Настоящий блик смещается пропорционально повороту поверхности. Значит,
    /// успокаивать его можно только наклоном самой прямой, а не её изгибом.
    /// 2,7 против прежних 3,7 линейных — на четверть спокойнее.
    ///
    /// Множитель один на обе оси, и этого достаточно: вертикаль слабее сама по
    /// себе, потому что диапазон `pitch` уже зажат в `TiltInput` (`pitchScale`
    /// 0,46). На пределе получается ход ±41 % по горизонтали и ±21 % по
    /// вертикали, то есть центр пятна всегда остаётся на карточке — зажим ниже
    /// работает страховкой и в норме не срабатывает. Это тоже важно: упор в
    /// зажим — это остановка посреди движения, и глаз её замечает.
    private static let travelPerDegree: Double = 2.7

    /// Радиус градиента — доля ширины карточки. Свет виден до `fadeStop` от него,
    /// то есть пятно крупнее самой карточки. Так и задумано: широкое мягкое пятно
    /// не берёт на себя внимание, в отличие от компактного и контрастного —
    /// маленькое пятно всегда читается как объект, большое как освещение.
    private static let radiusFactor: CGFloat = 1.15
    private static let coreOpacity: Double = 0.18
    private static let fadeStop: Double = 0.62

    /// Профиль яркости от центра к краю пятна — приподнятый косинус.
    ///
    /// В Brighty спад задавали три жёстких стопа (0,60 → 0,15 на 25 % → 0 на
    /// 55 %). На крупном пятне этот перелом на четверти радиуса становится виден:
    /// свет читается как круг с ободком. Степенной спад перелом убрал, но оставил
    /// другую беду — вся яркость собиралась в центре, и пятно опять читалось
    /// компактным светящимся объектом, «светлячком», хотя формально было широким.
    ///
    /// У косинуса середина держит плато и спад начинается только к краю, поэтому
    /// свет выглядит разлитым по поверхности. Производная нулевая на обоих
    /// концах: ни ободка в центре, ни кромки на краю.
    private static let profilePower: Double = 1.2
    private static let falloffStops: Int = 10

    /// Насколько центр пятна может уйти за кромку карточки, в процентах.
    ///
    /// Не ноль: свет должен уходить с карточки, как уходит настоящий, а не
    /// только плющиться у края. Но и немного — при большом выносе пятно
    /// отрывается от границы и повисает в углу, а это был порок первых двух
    /// версий блика.
    private static let overflow: Double = 12

    /// Положение в процентах от карточки. Уходит за 0…100 — это и есть то самое
    /// «сырое» значение. Знаки те же, что у перспективы: положительный `yaw`
    /// уводит правый край назад, значит ближе левый и блик едет влево.
    private var rawX: Double {
        50 - tilt.yaw * Self.travelPerDegree
    }

    private var rawY: Double {
        50 + tilt.pitch * Self.travelPerDegree
    }

    /// Профиль света стопами: приподнятый косинус, десять отсчётов.
    private static var lightGradient: Gradient {
        var stops: [Gradient.Stop] = []
        for step in 0...falloffStops {
            let t = Double(step) / Double(falloffStops)
            let bell = pow(0.5 + 0.5 * cos(.pi * t), profilePower)
            stops.append(.init(color: .white.opacity(coreOpacity * bell), location: t * fadeStop))
        }
        stops.append(.init(color: .white.opacity(0), location: 1))
        return Gradient(stops: stops)
    }

    var body: some View {
        let visualX = max(-Self.overflow, min(100 + Self.overflow, rawX))
        let visualY = max(-Self.overflow, min(100 + Self.overflow, rawY))
        let squish = GlareMath.edgeSquish(rawCenterX: rawX, rawCenterY: rawY)

        let yawFactor = min(abs(tilt.yaw) / TiltInput.yawLimit, 1)
        let pitchFactor = min(abs(tilt.pitch) / TiltInput.pitchLimit, 1)
        let breathX = 1 - 0.19 * yawFactor + 0.07 * pitchFactor
        let breathY = 1 - 0.17 * pitchFactor + 0.05 * yawFactor

        Canvas { context, size in
            let cx = visualX / 100 * size.width
            let cy = visualY / 100 * size.height
            let r = size.width * Self.radiusFactor

            var ctx = context
            ctx.translateBy(x: cx, y: cy)
            // Сжатие у кромки и дыхание радиусов — это два множителя одной и той
            // же деформации, поэтому просто перемножаются.
            ctx.scaleBy(x: squish.scaleX * breathX, y: squish.scaleY * breathY)

            ctx.fill(
                Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
                with: .radialGradient(
                    Self.lightGradient,
                    center: .zero,
                    startRadius: 0,
                    endRadius: r
                )
            )
        }
        // `.screen`, а не сложение: на светлых участках фотографии сложение
        // выжигало картинку в белое пятно, экран же подсвечивает тёмное и почти
        // не трогает уже светлое.
        .blendMode(.screen)
        .opacity(strength)
        .allowsHitTesting(false)
    }
}

// MARK: - Математика формы блика

enum GlareMath {
    /// Сжатие пятна у кромки. Механика `HolographicMath.edgeSquish` из Brighty.
    ///
    /// Считает по каждой оси, насколько близко центр к ближайшему краю, и жмёт
    /// именно эту ось. Работает от **сырой** координаты, поэтому продолжает
    /// жать и после того, как нарисованный центр уже уперся в кромку.
    ///
    /// Против оригинала (22 / 0,42) сжатие здесь заметно мягче и начинается
    /// раньше. В Brighty блик был компактным, и сплющивание вдвое читалось как
    /// свет, скользнувший по ребру. У широкого мягкого пятна такое сжатие
    /// превращается в самостоятельный жест: пятно на глазах меняет пропорции и
    /// начинает отвлекать. Здесь его роль — намёк, а не событие.
    static func edgeSquish(
        rawCenterX: Double,
        rawCenterY: Double,
        approachZone: Double = 26,
        minScale: Double = 0.78
    ) -> (scaleX: Double, scaleY: Double) {
        let nearestX = min(rawCenterX, 100 - rawCenterX)
        let nearestY = min(rawCenterY, 100 - rawCenterY)

        let compressionX = max(0, min(1, (approachZone - nearestX) / approachZone))
        let compressionY = max(0, min(1, (approachZone - nearestY) / approachZone))

        return (
            scaleX: 1 - compressionX * (1 - minScale),
            scaleY: 1 - compressionY * (1 - minScale)
        )
    }
}

// MARK: - Затемнение дальней половины

/// Дальняя от зрителя половина карточки чуть темнее. Слой слабый (до 12 %) и
/// нужен только как противовес блику: со светом без тени наклон читается как
/// засветка, а не как поворот. Если мешает — можно убрать одной строкой в
/// `GlossyPostcardView`.
private struct FarSideShade: View {
    let tilt: TiltInput

    var body: some View {
        let nx = max(-1, min(1, -tilt.yaw / TiltMotionService.yawMaxAngle))
        let ny = max(-1, min(1, tilt.pitch / TiltMotionService.pitchMaxAngle))
        let depth = min(1, hypot(nx, ny))

        // Градиент идёт от дальнего края (там, где блика нет) к ближнему.
        let far = UnitPoint(x: 0.5 - nx * 0.5, y: 0.5 - ny * 0.5)
        let near = UnitPoint(x: 0.5 + nx * 0.5, y: 0.5 + ny * 0.5)

        LinearGradient(
            colors: [.black.opacity(0.12 * depth), .clear],
            startPoint: far,
            endPoint: near
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Наклон

/// Перспективный наклон карточки. Перенесён из Brighty как есть: сдвиг в центр,
/// `m34 = −1/800` для перспективы, поворот вокруг X (pitch) и Y (yaw), сдвиг
/// обратно.
///
/// Это `GeometryEffect`, а не `rotation3DEffect`, по двум причинам: он
/// анимируется через `animatableData` (пружина отрабатывает по кадрам) и
/// нормально складывается с `scaleEffect` соседних карточек в карусели.
struct CardTiltEffect: GeometryEffect {
    var pitch: Double
    var yaw: Double
    var perspectiveDistance: CGFloat = 800

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(pitch, yaw) }
        set {
            pitch = newValue.first
            yaw = newValue.second
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, size.width / 2, size.height / 2, 0)
        t.m34 = -1.0 / perspectiveDistance
        t = CATransform3DRotate(t, pitch * .pi / 180, 1, 0, 0)
        t = CATransform3DRotate(t, yaw * .pi / 180, 0, 1, 0)
        t = CATransform3DTranslate(t, -size.width / 2, -size.height / 2, 0)
        return ProjectionTransform(t)
    }
}

#Preview("Открытка, наклон") {
    VStack(spacing: 32) {
        ForEach([-14.0, 0.0, 14.0], id: \.self) { yaw in
            GlossyPostcardView(
                card: PostcardCatalog.all[0],
                tilt: TiltInput(pitch: 6, yaw: yaw)
            )
            .modifier(CardTiltEffect(pitch: 6, yaw: yaw))
            .scaleEffect(0.5)
            .frame(height: PostcardMetrics.cardSize.height * 0.55)
        }
    }
    .padding()
}
