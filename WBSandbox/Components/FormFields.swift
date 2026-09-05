import SwiftUI

// Поля сложной формы. Каждое поле — одна строка списка внутри белой карточки:
// один вопрос, одна строка, один ответ. Разной высоты и разной вёрстки поля не
// бывает — иначе длинная форма читается как свалка непохожих блоков.
//
// Общие правила, одинаковые для всех типов полей:
//   · подпись не исчезает при заполнении, а уезжает наверх мелким кеглем — иначе
//     на середине формы человек уже не помнит, что именно он вписал;
//   · подсказка «где это взять» показывается только у поля в фокусе;
//   · ошибка появляется не раньше, чем есть что судить: на выходе из поля или
//     когда введено достаточно символов;
//   · ничего не блокируется. Нельзя нажать — это тупик, а не подсказка.

// MARK: - Секция карты формы

/// Секция карты формы по дизайн-системе: белая карточка со скруглением 20 и
/// внутренними отступами 16. Заголовок — если полей много и стоит сказать, о чём
/// секция. Поля внутри стоят через 12; ячейки (услуги, счётчики) — через 0, у них
/// свои разделители.
struct FormFieldSection<Content: View>: View {
    var title: String?
    var footnote: String?
    /// Список инпутов — 12; список ячеек — 0.
    var spacing: CGFloat = WBSpace.x3
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x2) {
            VStack(alignment: .leading, spacing: WBSpace.x3) {
                if let title {
                    Text(title)
                        .font(WBFont.title3Bold)
                        .foregroundStyle(WBColor.textPrimary)
                }

                VStack(spacing: spacing) {
                    content
                }
            }
            .padding(WBSpace.x4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                WBColor.bgBase,
                in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
            )

            if let footnote {
                Text(footnote)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .padding(.horizontal, WBSpace.x4)
            }
        }
    }
}

// MARK: - Карточка секции

/// Белая карточка с заголовком капслоком. Заголовок отвечает не на «как это
/// называется в системе», а на «что от меня хотят в этих трёх строках».
struct FormCard<Content: View>: View {
    var title: String?
    var footnote: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x2) {
            if let title {
                Text(title.uppercased())
                    .font(WBFont.caption)
                    .foregroundStyle(WBColor.textSecondary)
                    .padding(.horizontal, WBSpace.x4)
            }

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity)
            .background(
                WBColor.bgBase,
                in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
            )

            if let footnote {
                Text(footnote)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .padding(.horizontal, WBSpace.x4)
            }
        }
    }
}

/// Разделитель между полями. Слева отбит на ширину контента, чтобы список
/// читался колонкой, а не сеткой.
struct FormSeparator: View {
    var body: some View {
        Rectangle()
            .fill(WBColor.separator)
            .frame(height: 1)
            .padding(.leading, WBSpace.x4)
    }
}

// MARK: - Поля на карте формы

/// Бокс поля. Все заполняемые поля на карте выглядят полями ввода — белый бокс с
/// обводкой, — а не ячейками списка. Ячейка обещает переход куда-то ещё; поле
/// обещает, что здесь вписывают значение, и именно это и происходит.
///
/// Нередактируемое рисуется иначе: серая плашка без обводки и без шеврона. Разница
/// видна раньше, чем прочитан текст, и не приходится тапать, чтобы узнать, влияешь
/// ты на это значение или нет.
struct FormFieldBox<Content: View>: View {
    var isEditable: Bool = true
    var hasError: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WBRadius.x4, style: .continuous)
        content
            .frame(minHeight: 56)
            .padding(.horizontal, WBSpace.x4)
            .frame(maxWidth: .infinity)
            // Заполняемое — серая выемка внутри белой секции: в неё вписывают.
            // Нередактируемое — без фона, просто текст на белом: трогать нечего.
            .background(isEditable ? WBColor.bgMinus1 : .clear, in: shape)
            .overlay {
                if hasError {
                    shape.strokeBorder(WBColor.declined, lineWidth: 1.5)
                }
            }
    }
}

/// Поле на карте формы: показывает ответ и открывает визард. Само не редактируется
/// — заполняют в модалке, по одному вопросу, чтобы клавиатура не закрывала
/// половину карты.
struct FormValueRow: View {
    let label: String
    /// Ответ. nil — на вопрос ещё не отвечали.
    let value: String?
    var isRequired: Bool = true
    var error: String?
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x1) {
            FormFieldBox(hasError: error != nil) {
                HStack(spacing: WBSpace.x2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(value == nil ? WBFont.body : WBFont.description)
                            .foregroundStyle(WBColor.textSecondary)
                            .lineLimit(1)
                        if let value {
                            Text(value)
                                .font(WBFont.body)
                                .foregroundStyle(WBColor.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    Spacer(minLength: WBSpace.x2)

                    if value == nil, !isRequired {
                        Text("необязательно")
                            .font(WBFont.description)
                            .foregroundStyle(WBColor.controlsTertiary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WBColor.textSecondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap()
                onTap()
            }

            if let error {
                Text(error)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.declined)
                    .padding(.horizontal, WBSpace.x4)
            }
        }
        .animation(.snappy(duration: 0.2), value: value)
    }
}

/// Значение, на которое человек не влияет: пришло от поставщика. Плоская серая
/// плашка с пометкой — чтобы вопрос «а это я могу поменять?» не возникал.
struct FormReadOnlyRow: View {
    let label: String
    let value: String
    var note: String = "из начисления"

    var body: some View {
        FormFieldBox(isEditable: false) {
            HStack(spacing: WBSpace.x2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                    Text(value)
                        .font(WBFont.body)
                        .foregroundStyle(WBColor.textPrimary)
                        .lineLimit(2)
                }
                Spacer(minLength: WBSpace.x2)
                Text(note)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.controlsTertiary)
            }
        }
    }
}

// MARK: - Поле ввода

/// Строка ввода с уезжающей подписью.
struct FormInputRow: View {
    let field: FormField
    let format: FieldFormat
    @Binding var value: String
    var focus: FocusState<String?>.Binding
    var error: String?
    /// Крутилка справа: по этому реквизиту сейчас спрашиваем провайдера.
    var isChecking: Bool = false
    var onCommit: () -> Void = {}

    private var isFocused: Bool { focus.wrappedValue == field.id }
    /// Подпись наверху — когда в поле что-то есть или в него смотрят.
    private var isLabelUp: Bool { isFocused || !value.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: WBSpace.x2) {
                ZStack(alignment: .leading) {
                    Text(field.label)
                        .font(isLabelUp ? WBFont.description : WBFont.body)
                        .foregroundStyle(WBColor.textSecondary)
                        .offset(y: isLabelUp ? -11 : 0)

                    TextField("", text: $value)
                        .font(WBFont.body)
                        .foregroundStyle(WBColor.textPrimary)
                        .keyboardType(format.keyboard)
                        .textInputAutocapitalization(
                            format.keyboard == .default ? .sentences : .never
                        )
                        .autocorrectionDisabled()
                        .focused(focus, equals: field.id)
                        .offset(y: 9)
                        .opacity(isLabelUp ? 1 : 0)
                        .onSubmit(onCommit)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.snappy(duration: 0.18), value: isLabelUp)

                trailing
            }
            .frame(minHeight: 56)
            .padding(.horizontal, WBSpace.x4)
            .contentShape(Rectangle())
            .onTapGesture { focus.wrappedValue = field.id }

            // Подсказка и ошибка занимают одно место: одновременно они не нужны —
            // если реквизит уже неверный, объяснение, где его взять, только мешает.
            if let error {
                FieldNote(text: error, style: .error)
            } else if isFocused, let hint = field.hint {
                FieldNote(text: hint, style: .hint)
            }

            if isFocused, !field.suggestions.isEmpty, value.isEmpty {
                SuggestionChips(values: field.suggestions) { picked in
                    value = picked
                    onCommit()
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: error)
    }

    @ViewBuilder
    private var trailing: some View {
        if isChecking {
            ProgressView()
                .controlSize(.small)
        } else if isFocused, !value.isEmpty {
            Button {
                value = ""
                Haptics.tap()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(WBColor.controlsTertiary)
            }
            .buttonStyle(.plain)
        } else if !field.isRequired, value.isEmpty {
            // Единственная пометка на форме — «необязательно». Обратная разметка
            // звёздочками у обязательных полей засоряет каждую строку.
            Text("необязательно")
                .font(WBFont.description)
                .foregroundStyle(WBColor.controlsTertiary)
        }
    }
}

/// Подпись под полем: подсказка или ошибка.
struct FieldNote: View {
    enum Style { case hint, error }

    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .font(WBFont.description)
            .foregroundStyle(style == .error ? WBColor.declined : WBColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WBSpace.x4)
            .padding(.bottom, WBSpace.x3)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// Сохранённые реквизиты и быстрые суммы. Самый быстрый способ заполнить форму —
/// не заполнять её.
struct SuggestionChips: View {
    let values: [String]
    /// На белой карточке чип серый, на сером фоне шага — белый с обводкой. Один
    /// вид на оба фона не работает: серый чип на сером фоне просто исчезает.
    var onLightBackground: Bool = true
    let onPick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: WBSpace.x2) {
                ForEach(values, id: \.self) { value in
                    Button {
                        Haptics.tap()
                        onPick(value)
                    } label: {
                        Text(value)
                            .font(WBFont.descriptionAccent)
                            .foregroundStyle(WBColor.textPrimary)
                            .padding(.horizontal, WBSpace.x3)
                            .frame(height: 34)
                            .background(
                                onLightBackground ? WBColor.bgMinus1 : WBColor.bgBase,
                                in: Capsule()
                            )
                            .overlay {
                                if !onLightBackground {
                                    Capsule().strokeBorder(WBColor.separator, lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, WBSpace.x4)
            .padding(.bottom, WBSpace.x3)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Выбор

/// Развилка из двух-трёх коротких вариантов — сегментами: выбор виден целиком,
/// без лишнего шита.
struct FormSegmentedRow: View {
    let field: FormField
    let options: [ChoiceOption]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: WBSpace.x2) {
            Text(field.label)
                .font(WBFont.description)
                .foregroundStyle(WBColor.textSecondary)

            HStack(spacing: WBSpace.x1) {
                ForEach(options) { option in
                    let isOn = selection == option.id
                    Button {
                        Haptics.tap()
                        selection = option.id
                    } label: {
                        Text(option.title)
                            .font(WBFont.bodyAccent)
                            .foregroundStyle(isOn ? .white : WBColor.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                isOn ? WBColor.ctaFill : WBColor.bgMinus1,
                                in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, WBSpace.x4)
        .padding(.vertical, WBSpace.x3)
        .animation(.snappy(duration: 0.2), value: selection)
    }
}

/// Выбор из длинного списка — строкой с шевроном: города и управляющие компании
/// в сегменты не влезают.
struct FormPickerRow: View {
    let field: FormField
    let options: [ChoiceOption]
    let selection: String
    var error: String?
    let onTap: () -> Void

    private var selected: ChoiceOption? {
        options.first { $0.id == selection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: WBSpace.x2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.label)
                        .font(selected == nil ? WBFont.body : WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                    if let selected {
                        Text(selected.title)
                            .font(WBFont.body)
                            .foregroundStyle(WBColor.textPrimary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WBColor.textSecondary)
            }
            .frame(minHeight: 56)
            .padding(.horizontal, WBSpace.x4)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap()
                onTap()
            }

            if let error {
                FieldNote(text: error, style: .error)
            }
        }
    }
}

/// Шит выбора. Заголовок повторяет вопрос поля, чтобы не терять контекст.
struct ChoiceSheet: View {
    let title: String
    let options: [ChoiceOption]
    let selection: String
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(WBFont.title1)
                .foregroundStyle(WBColor.textPrimary)
                .padding(.horizontal, WBSpace.x4)
                .padding(.top, WBSpace.x4)
                .padding(.bottom, WBSpace.x3)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(options) { option in
                        Button {
                            Haptics.tap()
                            onPick(option.id)
                        } label: {
                            HStack(spacing: WBSpace.x3) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(WBFont.body)
                                        .foregroundStyle(WBColor.textPrimary)
                                    if let subtitle = option.subtitle {
                                        Text(subtitle)
                                            .font(WBFont.description)
                                            .foregroundStyle(WBColor.textSecondary)
                                    }
                                }
                                Spacer(minLength: WBSpace.x2)
                                if option.id == selection {
                                    DSIconView(icon: .checkmark, size: 22)
                                        .foregroundStyle(WBColor.textAccent)
                                }
                            }
                            .frame(minHeight: 56)
                            .padding(.horizontal, WBSpace.x4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if option.id != options.last?.id { FormSeparator() }
                    }
                }
                .background(
                    WBColor.bgBase,
                    in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
                )
                .padding(.horizontal, WBSpace.x2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WBColor.bgMinus1)
    }
}

// MARK: - Тумблер со своей ценой

/// Пени, страховка, автоплатёж. Цена стоит в той же строке, что и тумблер:
/// решение и его стоимость нельзя разносить по разным местам экрана.
struct FormToggleRow: View {
    let field: FormField
    let price: Decimal?
    @Binding var isOn: Bool
    /// На карте формы тумблер тоже обведён боксом — он такой же ответ, как ввод.
    /// Внутри визарда бокс рисует сам шаг, и второй был бы рамкой в рамке.
    var isBoxed: Bool = false

    var body: some View {
        Group {
            if isBoxed {
                FormFieldBox { row }
            } else {
                row
            }
        }
    }

    private var row: some View {
        HStack(spacing: WBSpace.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(field.label)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textPrimary)
                if let hint = field.hint {
                    Text(hint)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: WBSpace.x2)

            if let price {
                Text(Money.rub(price))
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(isOn ? WBColor.textPrimary : WBColor.textSecondary)
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(WBColor.textAccent)
        }
        .frame(minHeight: isBoxed ? 40 : 56)
        .padding(.horizontal, isBoxed ? 0 : WBSpace.x4)
        .padding(.vertical, WBSpace.x2)
    }
}

// MARK: - Счётчики

/// Показания: подпись, предыдущее значение, поле. Предыдущее показание — не
/// украшение: без него человек не понимает, правдоподобно ли то, что он ввёл.
struct FormMetersView: View {
    let field: FormField
    let meters: [MeterSpec]
    var focus: FocusState<String?>.Binding
    let value: (String) -> String
    let onChange: (String, String) -> Void
    /// Для линейного конструктора используем единый ритм OperationLine: без
    /// разделителей, с вертикальными отступами 12 pt.
    var usesOperationLineStyle = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(meters) { meter in
                let id = field.id + "." + meter.id
                VStack(alignment: .leading, spacing: WBSpace.x2) {
                    HStack(spacing: WBSpace.x3) {
                        Text("\(meter.title), \(meter.unit)")
                            .font(WBFont.body)
                            .foregroundStyle(WBColor.textPrimary)

                        Spacer(minLength: WBSpace.x2)

                        TextField("0", text: Binding(
                            get: { value(meter.id) },
                            set: { onChange(meter.id, $0) }
                        ))
                        .font(WBFont.bodyAccent)
                        .foregroundStyle(WBColor.textPrimary)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused(focus, equals: id)
                        .frame(width: 96)
                        .padding(.horizontal, WBSpace.x3)
                        .frame(height: 44)
                        .background(
                            WBColor.bgMinus1,
                            in: RoundedRectangle(cornerRadius: WBRadius.x3, style: .continuous)
                        )
                    }
                    .frame(minHeight: usesOperationLineStyle ? 0 : 56)
                    .padding(.vertical, usesOperationLineStyle ? WBSpace.x3 : 0)

                    // Последние оплаченные показания. Быстрый ввод и заодно
                    // подсказка про порядок цифр — без запретов и красных рамок.
                    if !meter.history.isEmpty {
                        SuggestionChips(
                            values: meter.history,
                            onLightBackground: false
                        ) { picked in
                            onChange(meter.id, picked.filter(\.isNumber))
                        }
                        .padding(.horizontal, -WBSpace.x4)
                    }
                }
                .padding(.horizontal, usesOperationLineStyle ? 0 : WBSpace.x4)

                if !usesOperationLineStyle, meter.id != meters.last?.id { FormSeparator() }
            }
        }
    }
}

// MARK: - Состав услуг

/// Строки единого платёжного документа. Каждая — со своей суммой и тумблером:
/// «оплатить только свет» решается здесь, а не отдельным экраном выбора услуг.
/// Итог внизу пересчитывается сразу, поэтому связь «выключил — стало меньше»
/// видна без объяснений.
struct FormServicesView: View {
    let field: FormField
    let lines: [ServiceLine]
    let isOn: (String) -> Bool
    let onToggle: (String, Bool) -> Void
    /// См. `FormMetersView.usesOperationLineStyle`.
    var usesOperationLineStyle = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(lines) { line in
                let on = isOn(line.id)
                HStack(spacing: WBSpace.x3) {
                    Button {
                        guard !line.isLocked else { return }
                        Haptics.tap()
                        onToggle(line.id, !on)
                    } label: {
                        checkbox(on: on, locked: line.isLocked)
                    }
                    .buttonStyle(.plain)

                    Text(line.title)
                        .font(WBFont.body)
                        .foregroundStyle(WBColor.textPrimary)

                    Spacer(minLength: WBSpace.x2)

                    Text(Money.rub(line.amount))
                        .font(WBFont.bodyAccent)
                        .foregroundStyle(on ? WBColor.textPrimary : WBColor.textSecondary)
                }
                .frame(minHeight: usesOperationLineStyle ? 0 : 52)
                .padding(.horizontal, usesOperationLineStyle ? 0 : WBSpace.x4)
                .padding(.vertical, usesOperationLineStyle ? WBSpace.x3 : 0)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !line.isLocked else { return }
                    Haptics.tap()
                    onToggle(line.id, !on)
                }
                .opacity(on ? 1 : 0.55)

                if !usesOperationLineStyle, line.id != lines.last?.id { FormSeparator() }
            }
        }
        .animation(.snappy(duration: 0.2), value: lines.map { isOn($0.id) })
    }

    private func checkbox(on: Bool, locked: Bool) -> some View {
        RoundedRectangle(cornerRadius: WBRadius.x1_5, style: .continuous)
            .fill(on ? WBColor.textAccent : .clear)
            .frame(width: 22, height: 22)
            .overlay {
                if !on {
                    RoundedRectangle(cornerRadius: WBRadius.x1_5, style: .continuous)
                        .strokeBorder(WBColor.radioOff, lineWidth: 1.5)
                }
            }
            .overlay {
                if on {
                    Image(systemName: locked ? "lock.fill" : "checkmark")
                        .font(.system(size: locked ? 10 : 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
    }
}

// MARK: - Строка из начисления

struct FormInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: WBSpace.x3) {
            Text(label)
                .font(WBFont.body)
                .foregroundStyle(WBColor.textSecondary)
            Spacer(minLength: WBSpace.x2)
            Text(value)
                .font(WBFont.bodyAccent)
                .foregroundStyle(WBColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 52)
        .padding(.horizontal, WBSpace.x4)
    }
}
