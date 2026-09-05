import CoreMotion
import SwiftUI

/// Наклон карточки по датчикам. Технология перенесена из прототипа Brighty
/// (`HolographicCardBlend` → `MotionService`) без изменения математики: там она
/// уже настроена так, чтобы карточка следовала за рукой, а не дёргалась.
///
/// Что именно даёт «живой» наклон, по порядку обработки сигнала:
///
/// 1. **Углы считаем из гравитации, а не из `attitude`.** `data.gravity.x/z` —
///    это то, куда наклонён корпус относительно вертикали, независимо от того,
///    как человек развернулся в пространстве. `attitude` бы уползал вместе с
///    поворотом всего тела.
/// 2. **Автокалибровка нуля.** Ноль — не «экран строго горизонтально», а та
///    поза, в которой телефон держат сейчас: первые 18 кадров усредняются в
///    базу, дальше база медленно подтягивается к текущему положению. Скорость
///    подтяжки зависит от того, шевелится ли телефон (`stillness`): в покое
///    ноль догоняет позу быстрее, в движении почти замирает — иначе наклон,
///    который держат долго, «съедался» бы калибровкой.
/// 3. **Мёртвая зона 0,35°** — снимает дрожь руки на нулевом наклоне.
/// 4. **`tanh`-ограничение** вместо `min/max`: у предела угол не обрубается
///    стенкой, а плавно упирается.
/// 5. **Пружина** (жёсткость 360, затухание 32) — карточка догоняет цель с
///    инерцией и лёгким перелётом. Это и читается как «следование».
/// 6. **Публикация раз в кадр главного потока.** Датчик приходит на своей
///    очереди 60 раз в секунду; без склейки SwiftUI получал бы по обновлению
///    состояния на каждый сэмпл.
///
/// В симуляторе `isDeviceMotionAvailable == false`, поэтому там углы всегда
/// нулевые — наклон на показе задаётся пальцем, см. `TiltInput`.
@Observable
final class TiltMotionService {
    /// Предельные углы. Они же — масштаб для расчёта положения блика.
    static let pitchMaxAngle: Double = 17
    static let yawMaxAngle: Double = 21

    private(set) var pitch: Double = 0
    private(set) var yaw: Double = 0
    /// 0…1, как сильно телефон шевелится прямо сейчас. Подмешивается в яркость
    /// блика: в покое он спокойнее, в движении вспыхивает.
    private(set) var motionEnergy: Double = 0

    /// Есть ли на устройстве датчики. По нему экран решает, нужна ли подсказка
    /// про перетаскивание пальцем.
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    private let manager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "WBSandbox.TiltMotionService"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // Значения крутизны и пружины подняты относительно Brighty: там карточка
    // наклонялась на весь размах в 17–21°, и мягкого отклика хватало. Здесь
    // поворот сжат втрое (см. `TiltInput.rotationGain`), и на том же входе
    // движение стало вялым — до предела приходилось доводить телефон так же
    // далеко, а видимого хода получалось втрое меньше. Поэтому предел оставлен
    // низким, а подход к нему сделан круче.
    private let inputSmoothing: Double = 0.6

    private let springStiffness: Double = 520.0
    private let springDamping: Double = 34.0
    private let updateFPS: Double = 60.0
    private var springTimeStep: Double { 1.0 / updateFPS }

    private let pitchGain: Double = 4.2
    private let yawGain: Double = 6.2

    private let inputDeadzoneDeg: Double = 0.35

    private let baselineAdaptSlow: Double = 0.0008
    private let baselineAdaptFast: Double = 0.005
    private let motionThreshold: Double = 0.6
    private let rotSmoothing: Double = 0.4
    private let motionEnergySaturation: Double = 0.55
    private let motionEnergyDecay: Double = 0.985

    private var baseGx: Double?
    private var baseGz: Double?
    private var smoothedGx: Double = 0
    private var smoothedGz: Double = 0
    private var smoothedRotMag: Double = 0
    private var initialized = false

    private var simulatedPitch: Double = 0
    private var simulatedYaw: Double = 0
    private var simulatedMotionEnergy: Double = 0
    private var pitchVelocity: Double = 0
    private var yawVelocity: Double = 0

    private let baselineSampleCount: Int = 18
    private var baselineSamplesCollected: Int = 0
    private var baselineSumGx: Double = 0
    private var baselineSumGz: Double = 0

    private let outputLock = NSLock()
    private var pendingPitch: Double = 0
    private var pendingYaw: Double = 0
    private var pendingMotionEnergy: Double = 0
    private var publishScheduled = false

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / updateFPS
        manager.startDeviceMotionUpdates(to: motionQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.handleDeviceMotion(data)
        }
    }

    private func handleDeviceMotion(_ data: CMDeviceMotion) {
        let gx = max(-1.0, min(1.0, data.gravity.x))
        let gz = max(-1.0, min(1.0, data.gravity.z))

        let rx = data.rotationRate.x
        let ry = data.rotationRate.y
        let rz = data.rotationRate.z
        let rotMag = sqrt(rx * rx + ry * ry + rz * rz)

        if !initialized {
            baselineSumGx += gx
            baselineSumGz += gz
            baselineSamplesCollected += 1

            if baselineSamplesCollected >= baselineSampleCount {
                let avgGx = baselineSumGx / Double(baselineSampleCount)
                let avgGz = baselineSumGz / Double(baselineSampleCount)
                baseGx = avgGx
                baseGz = avgGz
                smoothedGx = avgGx
                smoothedGz = avgGz
                smoothedRotMag = rotMag
                initialized = true
            }
            return
        }

        smoothedGx += (gx - smoothedGx) * inputSmoothing
        smoothedGz += (gz - smoothedGz) * inputSmoothing
        smoothedRotMag += (rotMag - smoothedRotMag) * rotSmoothing

        let baseGx = baseGx ?? 0
        let baseGz = baseGz ?? 0

        let dGx = max(-1.0, min(1.0, smoothedGx - baseGx))
        let dGz = max(-1.0, min(1.0, smoothedGz - baseGz))

        let yawDeg = asin(dGx) * 180.0 / .pi * yawGain
        let pitchDeg = -asin(dGz) * 180.0 / .pi * pitchGain

        let yawDeadzoned = applyDeadzone(yawDeg)
        let pitchDeadzoned = applyDeadzone(pitchDeg)

        let targetPitch = Self.pitchMaxAngle * tanh(pitchDeadzoned / Self.pitchMaxAngle)
        let targetYaw = Self.yawMaxAngle * tanh(yawDeadzoned / Self.yawMaxAngle)

        let pitchAccel = (targetPitch - simulatedPitch) * springStiffness - pitchVelocity * springDamping
        pitchVelocity += pitchAccel * springTimeStep
        simulatedPitch += pitchVelocity * springTimeStep

        let yawAccel = (targetYaw - simulatedYaw) * springStiffness - yawVelocity * springDamping
        yawVelocity += yawAccel * springTimeStep
        simulatedYaw += yawVelocity * springTimeStep

        let rawEnergy = min(1.0, rotMag / motionEnergySaturation)
        simulatedMotionEnergy = max(rawEnergy, simulatedMotionEnergy * motionEnergyDecay)

        let stillness = max(0.0, min(1.0, 1.0 - smoothedRotMag / motionThreshold))
        let adaptRate = baselineAdaptSlow + (baselineAdaptFast - baselineAdaptSlow) * stillness

        self.baseGx = baseGx + (smoothedGx - baseGx) * adaptRate
        self.baseGz = baseGz + (smoothedGz - baseGz) * adaptRate

        schedulePublish(pitch: simulatedPitch, yaw: simulatedYaw, motionEnergy: simulatedMotionEnergy)
    }

    private func schedulePublish(pitch: Double, yaw: Double, motionEnergy: Double) {
        var shouldSchedule = false

        outputLock.lock()
        pendingPitch = pitch
        pendingYaw = yaw
        pendingMotionEnergy = motionEnergy
        if !publishScheduled {
            publishScheduled = true
            shouldSchedule = true
        }
        outputLock.unlock()

        guard shouldSchedule else { return }

        DispatchQueue.main.async { [weak self] in
            self?.publishPendingMotion()
        }
    }

    private func publishPendingMotion() {
        outputLock.lock()
        let nextPitch = pendingPitch
        let nextYaw = pendingYaw
        let nextMotionEnergy = pendingMotionEnergy
        publishScheduled = false
        outputLock.unlock()

        pitch = nextPitch
        yaw = nextYaw
        motionEnergy = nextMotionEnergy
    }

    private func applyDeadzone(_ value: Double) -> Double {
        if abs(value) < inputDeadzoneDeg { return 0 }
        return value > 0 ? value - inputDeadzoneDeg : value + inputDeadzoneDeg
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        motionQueue.cancelAllOperations()
        baseGx = nil
        baseGz = nil
        smoothedGx = 0
        smoothedGz = 0
        smoothedRotMag = 0
        initialized = false
        baselineSamplesCollected = 0
        baselineSumGx = 0
        baselineSumGz = 0
        simulatedPitch = 0
        simulatedYaw = 0
        simulatedMotionEnergy = 0
        pitch = 0
        yaw = 0
        pitchVelocity = 0
        yawVelocity = 0
        motionEnergy = 0

        outputLock.lock()
        pendingPitch = 0
        pendingYaw = 0
        pendingMotionEnergy = 0
        publishScheduled = false
        outputLock.unlock()
    }
}

// MARK: - Итоговый наклон

/// Углы, которыми рисуется карточка.
///
/// Источник один — датчики. Пальцем карточку не наклоняют: наклон должен
/// принадлежать телефону, а не жесту, иначе на одном экране получаются две
/// физики и свайп по карусели начинает подкручивать перспективу.
///
/// Следствие для показа: **в симуляторе наклона нет вовсе** —
/// `isDeviceMotionAvailable` там `false`. Кадры наклона снимаются флагом
/// `-demoTilt`, живьём эффект смотрится только на устройстве.
struct TiltInput {
    var pitch: Double = 0
    var yaw: Double = 0
    var energy: Double = 0

    /// Сжатие входа. **Вертикаль слабее горизонтали**: телефон в руке почти
    /// всегда наклонён «на себя», и полноразмерный отклик по этой оси читается
    /// как случайный дрейф, а не как ответ на движение. Но совсем зажимать её
    /// нельзя — вертикального хода блика тогда не видно.
    private static let pitchScale: Double = 0.46
    private static let yawScale: Double = 0.72

    /// Предельные углы уже после сжатия входа. По ним нормируются правила формы
    /// блика: ему важна не абсолютная величина угла, а доля от возможного.
    static var pitchLimit: Double { TiltMotionService.pitchMaxAngle * pitchScale }
    static var yawLimit: Double { TiltMotionService.yawMaxAngle * yawScale }

    /// Во сколько раз геометрический поворот меньше «полного» наклона. Свет
    /// читается лучше перспективы, поэтому блик ездит на весь размах, а сама
    /// карточка ведёт себя деликатно: сильное искажение выглядит поломкой, а не
    /// объёмом.
    private static let rotationGain: Double = 0.45

    /// Углы для `CardTiltEffect`.
    var rotationPitch: Double { pitch * Self.rotationGain }
    var rotationYaw: Double { yaw * Self.rotationGain }

    static func from(motion: TiltMotionService) -> TiltInput {
        TiltInput(
            pitch: motion.pitch * pitchScale,
            yaw: motion.yaw * yawScale,
            energy: motion.motionEnergy
        )
    }

    /// Наклон целиком (1) или частично (0) — соседние карточки в карусели не
    /// наклоняются, у них своя роль.
    func scaled(by factor: Double) -> TiltInput {
        TiltInput(pitch: pitch * factor, yaw: yaw * factor, energy: energy * factor)
    }

    /// Переход между двумя источниками наклона. Нужен на приземлении подарка:
    /// в полёте бликом управляет сам оборот, дальше — рука.
    static func blend(_ from: TiltInput, _ to: TiltInput, _ t: Double) -> TiltInput {
        let k = max(0, min(1, t))
        return TiltInput(
            pitch: from.pitch + (to.pitch - from.pitch) * k,
            yaw: from.yaw + (to.yaw - from.yaw) * k,
            energy: from.energy + (to.energy - from.energy) * k
        )
    }
}
