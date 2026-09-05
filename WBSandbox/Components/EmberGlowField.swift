import SwiftUI

/// Ползунки эффекта — те же, что в редакторе MetalForge, теми же именами и в той
/// же шкале. Значения — из пресета Леонида от 10.08.2026 (`anim=swell`), перенесены
/// один в один, без «поправок на глаз».
///
/// Крутить имеет смысл здесь, а не в шейдере: в шейдере лежит форма света, а тут —
/// его характер, и это разные решения.
struct EmberTuning {
    /// Скорость всех волн сразу.
    var animSpeed: Double = 1.86
    /// Размах дыхания — главная ручка динамики. На 1 фронт ходит на ±10 % высоты
    /// блока, то есть почти незаметно.
    var animAmount: Double = 2
    /// Насколько разъезжаются периоды и фазы трёх волн. На 1 они дышат почти в такт
    /// и читаются как одна масса, выше — свет переливается из волны в волну.
    var animSpread: Double = 1.31
    /// Частота ряби по поверхности. При `anim=swell` она уже не главное движение.
    var waveFreq: Double = 2.2
    /// Насколько источник ходит вдоль нижней кромки.
    var lightSway: Double = 0.27
    /// Дыхание общей яркости.
    var glowPulse: Double = 0.21
    /// Общая заметность слоя.
    var intensity: Double = 1
}

/// Живое свечение под карточкой экрана исхода: три волны света от нижней кромки.
/// Сам эффект живёт в `Design/OutcomeEmber.metal`, здесь — его характер и связь с
/// хореографией экрана.
///
/// Слой заменяет радиальный градиент такта наливания, а не дополняется им: два
/// источника света в одном блоке спорят друг с другом — у них не совпадает ни
/// форма фронта, ни скорость набора плотности, и вместо одного свечения читаются
/// два наложенных пятна.
struct EmberGlowField: View {
    /// Край, середина и ядро — палитра исхода.
    let palette: EmberPalette
    /// Сырой прогресс такта наливания, 0…1. Кривую слой накладывает сам.
    let rise: CGFloat
    /// Общий отсчёт экрана исхода. Волны не должны сбиваться, когда экран
    /// перестаёт тикать и переключается на статический кадр, поэтому время
    /// считаем от точки запуска, а не от появления самого слоя.
    let clock: Date
    var tuning = EmberTuning()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                Rectangle()
                    .colorEffect(
                        ShaderLibrary.outcomeEmber(
                            .float2(geometry.size),
                            .float(Float(seconds(at: context.date))),
                            .float(Float(swell)),
                            .float(Float(tuning.intensity)),
                            .float(Float(tuning.animSpeed)),
                            .float(Float(tuning.animAmount)),
                            .float(Float(tuning.animSpread)),
                            .float(Float(tuning.waveFreq)),
                            .float(Float(tuning.lightSway)),
                            .float(Float(tuning.glowPulse)),
                            palette.edge.argument,
                            palette.mid.argument,
                            palette.core.argument
                        )
                    )
            }
        }
        .allowsHitTesting(false)
        // Слой декоративный: озвучивать его нечем, а фокус он бы перехватывал.
        .accessibilityHidden(true)
    }

    // MARK: Наплыв

    /// Свет не едет из точки в точку — он вспухает и оседает. Поэтому здесь не
    /// диммер градиента (`pow(_, 0.85)`, постоянная скорость), а разгон с
    /// торможением плюс один перелёт: свет заходит выше своей отметки и садится
    /// на неё. Оседание и читается как «свет лёг».
    ///
    /// Такт свету отдан не весь, а первые 55 %: на полной длине наплыв дочитывался
    /// как ползание — движения к концу почти нет, а ждать ещё три четверти секунды.
    /// Плитки при этом по-прежнему приезжают на середине такта, то есть уже на
    /// осевший свет, а не на белое.
    private var swell: CGFloat {
        let p = clamp01(rise / Self.share)
        return Ease.move(p) + Self.overshoot * overshootPulse(p)
    }

    /// Какую долю такта наливания занимает наплыв света.
    private static let share: CGFloat = 0.55
    /// Насколько свет переливает через свою отметку на подходе.
    private static let overshoot: CGFloat = 0.18

    /// Время для шейдера. Окно в десять минут — из-за `float`: большое число
    /// съедает мантиссу, и синусы встают намертво. Заодно страхует от кадра, в
    /// котором `clock` ещё не выставлен: без окна разница дала бы 10⁸ секунд.
    private func seconds(at date: Date) -> TimeInterval {
        date.timeIntervalSince(clock).truncatingRemainder(dividingBy: 600)
    }
}

/// `Shader.Argument.float3` принимает только три скаляра, вектором его не
/// накормить, — а палитра хранится вектором, чтобы не разъезжаться по каналам.
private extension SIMD3<Float> {
    var argument: Shader.Argument { .float3(x, y, z) }
}

#Preview("Три исхода") {
    VStack(spacing: WBSpace.x1) {
        ForEach(
            Array([EmberPalette.green, .blue, .orange].enumerated()),
            id: \.offset
        ) { _, palette in
            ZStack {
                WBColor.bgBase
                EmberGlowField(palette: palette, rise: 1, clock: .now)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous))
        }
    }
    .padding(WBSpace.x1)
    .background(WBColor.bgMinus1)
}
