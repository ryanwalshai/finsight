import SwiftUI

// The handful of shapes every screen is built from, matching the web app's card, tile and
// section heading. Keeping them here means a screen is a description of what it shows rather
// than a pile of padding values, and that the twenty screens still to come all agree.

/// A titled block with a hairline edge — the web app's `.card`.
struct FSCard<Content: View>: View {
    var title: String?
    var systemImage: String?
    var trailing: AnyView?
    @ViewBuilder var content: () -> Content

    init(title: String? = nil, systemImage: String? = nil,
         trailing: AnyView? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || trailing != nil {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.fsMuted)
                    }
                    if let title {
                        Text(title.uppercased())
                            .font(FSFont.display(11.5, .bold))
                            .tracking(1.6)
                            .foregroundStyle(Color.fsMuted)
                    }
                    Spacer(minLength: 8)
                    if let trailing { trailing }
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.fsBorder, lineWidth: 1)
        )
    }
}

/// One figure with its label and a line of context — the web app's `.btile`.
///
/// A tile with somewhere to go is a button; one that is only reporting a figure is not. A button
/// that does nothing when pressed is worse than plain text for anyone using VoiceOver, because it
/// promises something it cannot do.
struct FSTile: View {
    let icon: String
    let tint: Color
    let key: String
    let value: String
    var valueColor: Color?
    var sub: String?
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { face }
                .buttonStyle(.plain)
        } else {
            face
        }
    }

    private var face: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                Spacer(minLength: 0)
                if action != nil {
                    // The one mark that says a tile is a door. Its absence has to be trustworthy,
                    // so it goes on every tile that navigates and none that don't.
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.fsDim)
                }
            }
            Text(key.uppercased())
                .font(FSFont.display(10.5, .bold))
                .tracking(1.4)
                .foregroundStyle(Color.fsMuted)
                .padding(.top, 2)
            Text(value)
                .font(FSFont.number(23, .bold))
                .foregroundStyle(valueColor ?? Color.fsText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(FSFont.body(12))
                    .foregroundStyle(Color.fsDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.fsBorder, lineWidth: 1)
        )
    }
}

/// A screen's title, its one line of explanation, and the action that belongs to the whole screen.
struct FSSectionHead<Trailing: View>: View {
    let title: String
    let sub: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(FSFont.display(30, .bold))
                .tracking(-0.9)
                .foregroundStyle(Color.fsText)
            Text(sub)
                .font(FSFont.body(14))
                .foregroundStyle(Color.fsMuted)
                .fixedSize(horizontal: false, vertical: true)
            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// What a screen shows when it has nothing to show: what this is for, and the way to start.
struct FSEmpty: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Color.fsDim)
            Text(title)
                .font(FSFont.display(16, .semibold))
                .foregroundStyle(Color.fsText)
            Text(text)
                .font(FSFont.body(13))
                .foregroundStyle(Color.fsMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

/// The pill button the web app uses for the one action a screen is really about.
struct FSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FSFont.body(15, .semibold))
            .foregroundStyle(Color.fsOnPanel)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color.fsPanel, in: Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
