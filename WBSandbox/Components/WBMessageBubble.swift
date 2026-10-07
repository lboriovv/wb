import SwiftUI

/// A compact two-line message bubble with an optional leading or trailing artwork.
///
/// The component owns only layout. Colors, typography and images are injected,
/// so this file can be moved to another SwiftUI project without postcard-specific
/// models or asset names.
struct WBMessageBubble: View {
    static let maximumSize = CGSize(width: 311, height: 52)

    enum Position {
        case left
        case right

        fileprivate var tailAlignment: Alignment {
            switch self {
            case .left: .bottomLeading
            case .right: .bottomTrailing
            }
        }
    }

    struct Style {
        let font: Font
        let textColor: Color
        let bubbleBackground: Color
        let bubbleStroke: Color
    }

    struct Badge {
        let image: Image
        let background: Color
        let outline: Color
    }

    struct Artwork {
        let image: Image
        let background: Color
        let badge: Badge?

        init(image: Image, background: Color, badge: Badge? = nil) {
            self.image = image
            self.background = background
            self.badge = badge
        }
    }

    let message: String
    var position: Position = .right
    var artwork: Artwork?
    var tailImage: Image?
    let style: Style

    init(
        message: String,
        position: Position = .right,
        artwork: Artwork? = nil,
        tailImage: Image? = nil,
        style: Style
    ) {
        self.message = message
        self.position = position
        self.artwork = artwork
        self.tailImage = tailImage
        self.style = style
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if position == .right, let artwork {
                artworkView(artwork)
            }

            messageBubble

            if position == .left, let artwork {
                artworkView(artwork)
            }
        }
    }

    private var messageBubble: some View {
        IntrinsicWidthCapLayout(maxWidth: 263) {
            Text(message)
                .font(style.font)
                .foregroundStyle(style.textColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .frame(minHeight: 40, alignment: .leading)
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(style.bubbleBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(style.bubbleStroke, lineWidth: 1)
                }
        }
        .overlay(alignment: position.tailAlignment) {
            if let tailImage {
                tailImage
                    .resizable()
                    .frame(width: 16, height: 20)
                    .scaleEffect(x: position == .right ? -1 : 1, y: 1)
                    .offset(x: position == .right ? 4.5 : -4.5)
            }
        }
    }

    private func artworkView(_ artwork: Artwork) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(artwork.background)

                artwork.image
                    .resizable()
                    .scaledToFill()
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let badge = artwork.badge {
                badge.image
                    .resizable()
                    .frame(width: 12, height: 12)
                    .padding(2)
                    .background(badge.background, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(badge.outline, lineWidth: 2)
                    }
                    .offset(x: 2)
            }
        }
        .frame(width: 40, height: 40)
    }
}

private struct IntrinsicWidthCapLayout: Layout {
    let maxWidth: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else { return .zero }

        let availableWidth = min(maxWidth, proposal.width ?? maxWidth)
        let ideal = subview.sizeThatFits(.unspecified)
        let width = min(ideal.width, availableWidth)
        let fitted = subview.sizeThatFits(
            ProposedViewSize(width: width, height: proposal.height)
        )

        return CGSize(width: width, height: fitted.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }
        subview.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}
