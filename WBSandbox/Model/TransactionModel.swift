import Observation
import SwiftUI

/// Состояние одного транзакционного экрана. Живёт ровно столько, сколько выбран
/// режим: при переключении режима создаётся новая модель с нуля.
@Observable
final class TransactionModel {
    let config: TransactionConfig

    var amount: AmountInput
    var selectedAccountID: String
    /// Счёт-получатель для сценариев со свапом.
    var destinationAccountID: String?
    var selectedRail: PaymentRail
    var toggles: [String: Bool]

    /// Текст комментария. Пустая строка — показываем плейсхолдер.
    var commentText: String
    /// Прикреплённые подарки, в порядке добавления.
    var selectedGiftIDs: [String] = []
    /// Включённые доп. функции.
    var enabledExtras: Set<String> = []

    var isAccountSheetPresented = false
    var isOutcomePresented = false

    init(config: TransactionConfig) {
        self.config = config
        self.amount = AmountInput(config.initialAmount)
        self.selectedAccountID = config.accounts.first?.id ?? ""
        self.destinationAccountID = config.destinationAccountID
        // Рельс не задаётся в конфиге вручную: берём первый доступный для этой
        // операции по матрице из таблицы «Способы оплаты».
        self.selectedRail = config.defaultRail
            ?? RailMatrix.defaultRail(for: config.operation)
        var toggleStates = Dictionary(
            uniqueKeysWithValues: config.toggles.map { ($0.id, $0.isOn) }
        )
        if case .automation(let row) = config.suggestSlot {
            toggleStates[row.id] = row.isOn
        }
        self.toggles = toggleStates
        // Комментарий начинается пустым — текст из конфига это лишь пример,
        // который подставляется по тапу. Статичная подпись показывается сразу.
        self.commentText = config.message?.kind == .comment ? "" : (config.message?.text ?? "")
    }

    /// Способы оплаты, доступные для этой операции.
    var rails: [PaymentRail] {
        RailMatrix.rails(for: config.operation)
    }

    // MARK: Производные значения

    var selectedAccount: Account? {
        config.accounts.first { $0.id == selectedAccountID }
    }

    var amountValue: Decimal { amount.decimal }

    var fee: Decimal { config.fee.fee(for: amountValue) }

    var feeBadge: BadgeSpec { config.fee.badge(for: amountValue) }

    /// Начисление WB-баллов за оплату QR собственным рельсом банка. На чужих
    /// рельсах бейдж остаётся, но скручивается в ноль — так видна упущенная выгода.
    var qrBonusPoints: Int? {
        guard config.operation == .qr else { return nil }
        return selectedRail == .direct ? 35 : 0
    }

    /// Счета, которые показываем в шите: только доступные.
    var availableAccounts: [Account] {
        config.accounts.filter(\.isAvailable)
    }

    /// Секция выбора способа нужна только когда есть из чего выбирать. Если способ
    /// один — выбор в шите не показываем, он и так виден на экране логотипом.
    var showsRailPicker: Bool { rails.count >= 2 }

    /// Доступная доп. функция. Сначала смотрим, уместны ли бонусные деньги в этой
    /// операции вообще, и только потом выбираем какие: денег хватает — предлагаем
    /// потратить ягодки, не хватает — добрать WB Кэшем.
    var availableExtra: ExtraFunction? {
        let suitable: ExtraFunction = shortfall == nil ? .berries : .wbCash
        return config.operation.extras.contains(suitable) ? suitable : nil
    }

    func isExtraOn(_ function: ExtraFunction) -> Bool {
        enabledExtras.contains(function.rawValue)
    }

    func setExtra(_ function: ExtraFunction, _ value: Bool) {
        if value { enabledExtras.insert(function.rawValue) }
        else { enabledExtras.remove(function.rawValue) }
    }

    /// Группа бейджей под суммой (макет `badge group`). Бейджи включённых доп.
    /// функций встают СЛЕВА от бейджа комиссии.
    var amountBadges: [BadgeSpec] {
        var result: [BadgeSpec] = []
        if let extra = availableExtra, isExtraOn(extra) {
            result.append(extra.badge)
        }
        result.append(feeBadge)
        return result
    }

    /// Марка выбранного способа в строке списания. Появляется только у чужих
    /// рельсов — СБП и цифрового рубля. Платёж со счёта WB Банка идёт без марки:
    /// это способ по умолчанию, и показывать тут нечего.
    var sourceRailIcons: [RowIcon] { [selectedRail.mark].compactMap(\.self) }

    /// Строка «откуда списываем» собирается из выбранного счёта: сверху название
    /// счёта мелким, снизу остаток крупным — как в макете.
    var sourceRow: DetailRow? {
        guard let account = selectedAccount else { return nil }
        return DetailRow(
            id: "source-" + account.id,
            icon: account.icon,
            // «С WB Банк ··1321» — приставка из шаблона: строка отвечает на вопрос
            // «откуда», поэтому читается как продолжение фразы.
            top: .secondary("С " + account.subtitle),
            bottom: .primary(account.amountTitle),
            trailingBadge: account.badge,
            trailingIcons: sourceRailIcons
        )
    }

    /// Строка «куда». Если получатель — свой счёт, собираем её из счёта, иначе
    /// берём готовую из конфига.
    var destinationRow: DetailRow? {
        guard let id = destinationAccountID else { return config.destination }
        guard let account = config.accounts.first(where: { $0.id == id }) else { return nil }
        // Порядок обратный строке списания (макет 898:63405): сверху сумма, снизу
        // название счёта с приставкой «На ». Благодаря этому центр строки пустой и
        // кнопка свапа ни на что не наезжает.
        return DetailRow(
            id: "dest-" + account.id,
            icon: account.icon,
            top: .primary(account.amountTitle),
            bottom: .secondary("На " + account.subtitle)
        )
    }

    /// Поменять счёта местами: было с А на Б — стало с Б на А.
    func swapAccounts() {
        guard let destination = destinationAccountID else { return }
        let source = selectedAccountID
        selectedAccountID = destination
        destinationAccountID = source
    }

    /// Сколько не хватает на счёте. nil — денег достаточно, подсказку не рисуем.
    var shortfall: Decimal? {
        guard let balance = selectedAccount?.balance else { return nil }
        let missing = amountValue - balance
        return missing > 0 ? missing : nil
    }

    var isCTAEnabled: Bool { !amount.isEmpty }

    /// Насколько напряжён сейчас экран — единственное, что модель сообщает
    /// живому фону. Как это выглядит, решает `SpikeLimeField`.
    ///
    /// Порог ровно один и он же, что у кнопки: свет и кнопка обязаны меняться
    /// одновременно, иначе подсказка ведёт вниз, а внизу ещё ничего не
    /// произошло.
    var ambientMood: Double {
        if shortfall != nil { return 2 }
        return amount.isEmpty ? 0 : 1
    }

    /// Что показывает основная кнопка. При нехватке денег она превращается в
    /// оранжевое «Пополнить на N ₽» — сначала пополнить, потом переводить.
    enum CTAKind: Equatable {
        case primary(String)
        case topUp(Decimal)
    }

    var cta: CTAKind {
        if let shortfall { return .topUp(shortfall) }
        return .primary(config.ctaTitle)
    }

    // MARK: Действия

    func tapDigit(_ digit: String) {
        amount.append(digit: digit)
    }

    func tapSeparator() {
        amount.appendSeparator()
    }

    func tapBackspace() {
        amount.backspace()
    }

    func applyQuickAmount(_ value: Decimal) {
        amount = AmountInput(value)
    }

    func selectAccount(_ id: String) {
        selectedAccountID = id
    }

    func selectRail(_ rail: PaymentRail) {
        guard RailMatrix.isAvailable(rail, for: config.operation) else { return }
        selectedRail = rail
    }

    // MARK: Комментарий и подарки

    var isCommentFilled: Bool { !commentText.isEmpty }

    /// Прикреплённые подарки в порядке из конфига — слева направо.
    var attachedGifts: [MessageSticker] {
        (config.message?.gifts ?? []).filter { selectedGiftIDs.contains($0.id) }
    }

    /// Кнопка подарка живёт, пока выбраны не все подарки.
    var showsGiftButton: Bool {
        guard let message = config.message, message.kind == .comment else { return false }
        return selectedGiftIDs.count < message.gifts.count
    }

    /// Тап по чипу переключает комментарий между пустым и примером из конфига.
    func toggleComment() {
        guard config.message?.kind == .comment else { return }
        commentText = isCommentFilled ? "" : (config.message?.text ?? "")
    }

    /// Подарки появляются справа налево: берём последний ещё не выбранный.
    func addGift() {
        guard let gifts = config.message?.gifts,
              let next = gifts.last(where: { !selectedGiftIDs.contains($0.id) })
        else { return }
        selectedGiftIDs.append(next.id)
    }

    func removeGift(_ id: String) {
        selectedGiftIDs.removeAll { $0 == id }
    }

    func isToggleOn(_ id: String) -> Bool { toggles[id] ?? false }

    func setToggle(_ id: String, _ value: Bool) { toggles[id] = value }

    // MARK: Допродажа

    /// Сумму набирают руками только там, где под ней стоит клавиатура. В QR и
    /// подобных сценариях она приходит готовой, поэтому и каретки в ней быть не
    /// должно: мигающая палочка обещает ввод, которого нет.
    var isAmountEditable: Bool {
        if case .keypad = config.bottomSlot { return true }
        return false
    }

    /// Предложение оплатить заодно второй счёт. Живёт вместо клавиатуры там, где
    /// сумму всё равно не набирают руками.
    var upsell: UpsellOffer? {
        if case .upsell(let offer) = config.bottomSlot { return offer }
        return nil
    }

    /// Включение допродажи не «показывает баннер», а честно добавляет второй счёт
    /// к платежу: сумма на экране растёт, комиссия и нехватка пересчитываются.
    /// Поэтому сумма всегда собирается заново от базовой, а не прибавляется.
    func setUpsell(_ offer: UpsellOffer, _ value: Bool) {
        toggles[offer.id] = value
        amount = AmountInput(config.initialAmount + (value ? offer.amount : 0))
    }
}
