import SwiftUI

// Смотрелка: что выводится в каком типе оплаты. Читает те же спеки, из которых
// собирается сам экран, — поэтому расходиться с формой ей нечем. Два вида:
//
//   · `ServiceSpecSheet` — один тип: универсальные атрибуты и все поля схемы;
//   · `ServiceMatrixScreen` — все десять типов сразу, матрица «поле × тип».

// MARK: - Спека одного типа

struct ServiceSpecSheet: View {
    let spec: ServiceSpec
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WBSpace.x4) {
                    kindCard
                    attributesCard
                    ForEach(spec.sections) { section in
                        sectionCard(section)
                    }
                }
                .padding(.horizontal, WBSpace.x2)
                .padding(.vertical, WBSpace.x3)
            }
            .background(WBColor.bgMinus1)
            .navigationTitle(spec.demoName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть", action: onClose)
                }
            }
        }
    }

    private var kindCard: some View {
        FormCard {
            VStack(alignment: .leading, spacing: WBSpace.x2) {
                HStack(spacing: WBSpace.x2) {
                    WBBadgeView(
                        badge: BadgeSpec(
                            text: spec.kind.title,
                            style: spec.kind == .upfront ? .greenSoft : .violet
                        )
                    )
                    Text(spec.category)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                    Spacer(minLength: 0)
                }

                Text(spec.kind.explanation)
                    .font(WBFont.body)
                    .foregroundStyle(WBColor.textPrimary)

                Text(countsTitle)
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WBSpace.x4)
        }
    }

    private var countsTitle: String {
        let all = spec.allFields.count
        let required = spec.allFields.filter(\.isRequired).count
        let conditional = spec.allFields.filter { $0.reveal != nil }.count
        return "\(all) полей: \(required) обязательных, \(spec.optionalCount) необязательных, "
            + "\(conditional) появляются по условию"
    }

    private var attributesCard: some View {
        FormCard(title: "Универсальные атрибуты категории") {
            VStack(spacing: 0) {
                ForEach(Array(spec.universalAttributes.enumerated()), id: \.offset) { index, row in
                    if index > 0 { FormSeparator() }
                    HStack(alignment: .top, spacing: WBSpace.x3) {
                        Text(row.0)
                            .font(WBFont.description)
                            .foregroundStyle(WBColor.textSecondary)
                            .frame(width: 132, alignment: .leading)
                        Text(row.1)
                            .font(WBFont.description)
                            .foregroundStyle(WBColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, WBSpace.x4)
                    .padding(.vertical, WBSpace.x3)
                }
            }
        }
    }

    private func sectionCard(_ section: FormSection) -> some View {
        FormCard(
            title: section.title ?? "Основной блок",
            footnote: section.reveal.map { "Показывается, когда заполнено: \($0.field)" }
        ) {
            VStack(spacing: 0) {
                ForEach(Array(section.fields.enumerated()), id: \.element.id) { index, field in
                    if index > 0 { FormSeparator() }
                    fieldRow(field, isExtras: section.isExtras)
                }
            }
        }
    }

    private func fieldRow(_ field: FormField, isExtras: Bool) -> some View {
        VStack(alignment: .leading, spacing: WBSpace.x1) {
            HStack(spacing: WBSpace.x2) {
                Text(field.label)
                    .font(WBFont.bodyAccent)
                    .foregroundStyle(WBColor.textPrimary)
                Spacer(minLength: 0)
                Text(field.isRequired ? "обязательное" : "необязательное")
                    .font(WBFont.description)
                    .foregroundStyle(
                        field.isRequired ? WBColor.textAccent : WBColor.textSecondary
                    )
            }

            Text("\(field.facet.title) · \(field.formatTitle)")
                .font(WBFont.description)
                .foregroundStyle(WBColor.textSecondary)

            if let reveal = field.reveal {
                Text(condition(reveal))
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.violet)
            }

            if field.triggersLookup {
                Text("По этому реквизиту идём к провайдеру за начислением")
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.brandBlue)
            }

            if isExtras {
                Text("В блоке дополнительных параметров")
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WBSpace.x4)
        .padding(.vertical, WBSpace.x3)
    }

    private func condition(_ reveal: Reveal) -> String {
        let field = spec.allFields.first { $0.id == reveal.field }
        let name = field?.label ?? reveal.field
        guard let equals = reveal.equals else { return "Появляется после «\(name)»" }
        var value = equals
        if case .choice(let options)? = field?.kind,
           let option = options.first(where: { $0.id == equals }) {
            value = option.title
        }
        return "Только если «\(name)» = \(value)"
    }
}

// MARK: - Матрица

/// Все типы оплаты в одной таблице: строки — смысл поля, столбцы — типы.
/// Нужна не для красоты: по ней видно, что в десяти разных провайдерах на самом
/// деле повторяется десяток одинаковых полей, и спорить про «у каждого свой
/// экран» больше не о чем.
///
/// Столбцы подписаны номерами, а не названиями, — и это не экономия: с
/// названиями таблица не влезает в экран, а таблица со скроллом вправо
/// перестаёт быть таблицей. Расшифровка номеров стоит сразу под ней, и с неё
/// можно провалиться в спеку любого типа.
struct ServiceMatrixScreen: View {
    var onClose: () -> Void = {}

    @State private var inspected: ServiceSpec?

    private let specs = ServiceCatalog.all
    private let labelWidth: CGFloat = 132
    private let columnWidth: CGFloat = 26
    private let rowHeight: CGFloat = 40

    /// Только те смыслы, которые встречаются хотя бы в одном типе.
    private var facets: [FieldFacet] {
        FieldFacet.allCases.filter { facet in
            specs.contains { $0.allFields.contains { $0.facet == facet } }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WBSpace.x4) {
                    legend
                    table
                    key
                }
                .padding(.horizontal, WBSpace.x2)
                .padding(.vertical, WBSpace.x3)
            }
            .background(WBColor.bgMinus1)
            .navigationTitle("Матрица полей")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть", action: onClose)
                }
            }
            .sheet(item: $inspected) { spec in
                ServiceSpecSheet(spec: spec) { inspected = nil }
            }
        }
    }

    // MARK: Легенда

    private var legend: some View {
        HStack(spacing: WBSpace.x3) {
            ForEach([CellState.required, .conditional, .optional], id: \.glyph) { state in
                HStack(spacing: WBSpace.x1) {
                    Text(state.glyph)
                        .font(WBFont.descriptionAccent)
                        .foregroundStyle(state.color)
                    Text(state.title)
                        .font(WBFont.description)
                        .foregroundStyle(WBColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, WBSpace.x2)
    }

    // MARK: Таблица

    private var table: some View {
        VStack(spacing: 0) {
            headerRow
            ForEach(Array(facets.enumerated()), id: \.element) { index, facet in
                FormSeparator()
                row(facet)
                    .background(index.isMultiple(of: 2) ? WBColor.bgBase : WBColor.bgMinus1.opacity(0.4))
            }
            FormSeparator()
            totalsRow
        }
        .background(
            WBColor.bgBase,
            in: RoundedRectangle(cornerRadius: WBRadius.x5, style: .continuous)
        )
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Поле")
                .font(WBFont.caption)
                .foregroundStyle(WBColor.textSecondary)
                .frame(width: labelWidth, alignment: .leading)
                .padding(.leading, WBSpace.x3)

            ForEach(Array(specs.enumerated()), id: \.element.id) { index, spec in
                Button {
                    Haptics.tap()
                    inspected = spec
                } label: {
                    VStack(spacing: 1) {
                        Text("\(index + 1)")
                            .font(WBFont.descriptionAccent)
                            .foregroundStyle(WBColor.textPrimary)
                        // Точка под номером — тип провайдера: видно, что поэтапных
                        // среди десяти всего три.
                        Circle()
                            .fill(spec.kind == .upfront ? WBColor.textAccent : WBColor.violet)
                            .frame(width: 4, height: 4)
                    }
                    .frame(width: columnWidth, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ facet: FieldFacet) -> some View {
        HStack(spacing: 0) {
            Text(facet.title)
                .font(WBFont.description)
                .foregroundStyle(WBColor.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: labelWidth, alignment: .leading)
                .padding(.leading, WBSpace.x3)

            ForEach(specs) { spec in
                let state = cell(spec, facet)
                Text(state.glyph)
                    .font(WBFont.descriptionAccent)
                    .foregroundStyle(state.color)
                    .frame(width: columnWidth)
            }
        }
        .frame(height: rowHeight)
    }

    /// Нижняя строка: сколько полей в каждом типе. Здесь и видно, что «сложный
    /// экран» — это от четырёх полей до четырнадцати, и одна вёрстка обязана
    /// тянуть весь диапазон.
    private var totalsRow: some View {
        HStack(spacing: 0) {
            Text("Всего полей")
                .font(WBFont.descriptionAccent)
                .foregroundStyle(WBColor.textSecondary)
                .frame(width: labelWidth, alignment: .leading)
                .padding(.leading, WBSpace.x3)

            ForEach(specs) { spec in
                Text("\(spec.allFields.count)")
                    .font(WBFont.description)
                    .foregroundStyle(WBColor.textSecondary)
                    .frame(width: columnWidth)
            }
        }
        .frame(height: rowHeight)
    }

    // MARK: Расшифровка номеров

    private var key: some View {
        FormCard(title: "Типы оплаты") {
            VStack(spacing: 0) {
                ForEach(Array(specs.enumerated()), id: \.element.id) { index, spec in
                    if index > 0 { FormSeparator() }
                    Button {
                        Haptics.tap()
                        inspected = spec
                    } label: {
                        HStack(spacing: WBSpace.x3) {
                            Text("\(index + 1)")
                                .font(WBFont.descriptionAccent)
                                .foregroundStyle(WBColor.textSecondary)
                                .frame(width: 20, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(spec.demoName)
                                    .font(WBFont.body)
                                    .foregroundStyle(WBColor.textPrimary)
                                Text("\(spec.kind.title.lowercased()) · \(spec.allFields.count) полей · \(spec.category)")
                                    .font(WBFont.description)
                                    .foregroundStyle(WBColor.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: WBSpace.x2)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(WBColor.textSecondary)
                        }
                        .frame(minHeight: 56)
                        .padding(.horizontal, WBSpace.x4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Ячейка

    private enum CellState {
        case required, conditional, optional, absent

        var glyph: String {
            switch self {
            case .required: "●"
            case .conditional: "◐"
            case .optional: "○"
            case .absent: "·"
            }
        }

        var color: Color {
            switch self {
            case .required: WBColor.textAccent
            case .conditional: WBColor.violet
            case .optional: WBColor.textSecondary
            case .absent: WBColor.controlsTertiary
            }
        }

        var title: String {
            switch self {
            case .required: "обязательное"
            case .conditional: "по условию"
            case .optional: "необязательное"
            case .absent: "нет"
            }
        }
    }

    /// Состояние ячейки. Обязательное поле с условием показа считается условным:
    /// «обязательное, но только в этой ветке» — это про ветку, а не про строгость.
    private func cell(_ spec: ServiceSpec, _ facet: FieldFacet) -> CellState {
        let fields = spec.allFields.filter { $0.facet == facet }
        guard !fields.isEmpty else { return .absent }
        if fields.contains(where: { $0.isRequired && $0.reveal == nil }) { return .required }
        if fields.contains(where: { $0.isRequired }) { return .conditional }
        return .optional
    }
}
