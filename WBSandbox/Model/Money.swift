import Foundation

/// Форматирование денег так, как в макете: разряды разделены неразрывным пробелом,
/// копейки — запятой. «1 235 ₽», «3,74 ₽».
enum Money {
    static let nbsp = "\u{00A0}"

    private static let grouping: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = nbsp
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    private static let twoDigits: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = nbsp
        f.usesGroupingSeparator = true
        f.decimalSeparator = ","
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// «1 235» — целое число с разделителями разрядов.
    static func grouped(_ value: Decimal) -> String {
        grouping.string(from: value as NSDecimalNumber) ?? "0"
    }

    /// «1 235 ₽» — целое, если копеек нет, иначе с копейками.
    static func rub(_ value: Decimal) -> String {
        let rounded = value.rounded(scale: 2)
        let body: String
        if rounded == rounded.rounded(scale: 0) {
            body = grouped(rounded)
        } else {
            body = twoDigits.string(from: rounded as NSDecimalNumber) ?? "0"
        }
        return body + nbsp + "₽"
    }

    /// «142 750,13» — число без знака рубля: целое, если копеек нет, иначе с
    /// копейками. Нужно там, где «₽» рисуется отдельным элементом своим цветом.
    static func plain(_ value: Decimal) -> String {
        let rounded = value.rounded(scale: 2)
        if rounded == rounded.rounded(scale: 0) { return grouped(rounded) }
        return twoDigits.string(from: rounded as NSDecimalNumber) ?? "0"
    }

    /// «3,74» — всегда с копейками, для строки комиссии.
    static func kopecks(_ value: Decimal) -> String {
        twoDigits.string(from: value.rounded(scale: 2) as NSDecimalNumber) ?? "0,00"
    }

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.decimalSeparator = ","
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 4
        return f
    }()

    /// «0,0935 %» — ставка комиссии в спеке. До четырёх знаков намеренно: у ЖКУ
    /// ставка в сотых долях процента, и округление до двух превращает её в ноль.
    static func percent(_ value: Decimal) -> String {
        (percentFormatter.string(from: value as NSDecimalNumber) ?? "0") + nbsp + "%"
    }
}

extension Decimal {
    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }
}

/// Ввод суммы с цифровой клавиатуры. Хранит то, что пользователь набрал,
/// а не готовое число — иначе нельзя показать «1 000,» с висящей запятой.
struct AmountInput: Equatable {
    private(set) var integerDigits: String
    private(set) var fractionDigits: String?

    init(_ value: Decimal) {
        // Целую часть отрезаем, а не округляем: у 6 214,80 округление вверх давало
        // 6 215 рублей и −20 копеек, и сумма рисовалась как «6 215,-20 ₽».
        let whole = value.rounded(scale: 0, mode: .down)
        integerDigits = NSDecimalNumber(decimal: whole).stringValue
        let fraction = (value - whole).rounded(scale: 2)
        fractionDigits = fraction == 0 ? nil : String(
            format: "%02d",
            Int(truncating: NSDecimalNumber(decimal: fraction * 100))
        )
    }

    var decimal: Decimal {
        let text = integerDigits.isEmpty ? "0" : integerDigits
        var value = Decimal(string: text) ?? 0
        if let fractionDigits, !fractionDigits.isEmpty {
            let scale = Decimal(sign: .plus, exponent: -fractionDigits.count, significand: 1)
            value += (Decimal(string: fractionDigits) ?? 0) * scale
        }
        return value
    }

    var isEmpty: Bool { integerDigits.isEmpty || integerDigits == "0" }

    /// Целая часть с разделителями разрядов — то, что рисуется крупным кеглем.
    var displayInteger: String {
        integerDigits.isEmpty ? "0" : Money.grouped(Decimal(string: integerDigits) ?? 0)
    }

    /// Дробная часть вместе с запятой, включая случай «1 000,» — запятая нажата,
    /// копейки ещё не введены.
    var displayFraction: String? {
        guard let fractionDigits else { return nil }
        return "," + fractionDigits
    }

    mutating func append(digit: String) {
        if fractionDigits != nil {
            guard fractionDigits!.count < 2 else { return }
            fractionDigits! += digit
        } else {
            guard integerDigits.count < 9 else { return }
            integerDigits = integerDigits == "0" ? digit : integerDigits + digit
        }
    }

    mutating func appendSeparator() {
        guard fractionDigits == nil else { return }
        if integerDigits.isEmpty { integerDigits = "0" }
        fractionDigits = ""
    }

    mutating func backspace() {
        if var fraction = fractionDigits {
            if fraction.isEmpty {
                fractionDigits = nil
            } else {
                fraction.removeLast()
                fractionDigits = fraction
            }
        } else if !integerDigits.isEmpty {
            integerDigits.removeLast()
        }
    }
}
