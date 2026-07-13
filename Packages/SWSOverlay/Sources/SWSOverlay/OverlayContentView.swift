import SwiftUI
import SWSModel

@MainActor
final class OverlayState: ObservableObject {
    @Published var zones: [NormalizedRect] = []
    @Published var highlightedZone: NormalizedRect?
    /// Names of all configurations, shown as a switcher while dragging so
    /// the user can see what Option-cycling (see `ConfigurationStore
    /// .activateNextConfiguration`) will land on next. Empty/single-element
    /// hides the switcher - there's nothing to swap to with one profile.
    @Published var configurationNames: [String] = []
    @Published var activeConfigurationIndex: Int?
}

struct OverlayContentView: View {
    @ObservedObject var state: OverlayState

    var body: some View {
        GeometryReader { proxy in
            ForEach(state.zones, id: \.self) { zone in
                let isHighlighted = zone == state.highlightedZone
                // A dark backing (rather than a light/translucent one) keeps
                // zones legible over arbitrary desktop wallpaper/content,
                // which a subtle white-on-white treatment washed out against.
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHighlighted ? Color.accentColor.opacity(0.35) : Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isHighlighted ? Color.accentColor : Color.white.opacity(0.9), lineWidth: isHighlighted ? 5 : 3)
                    )
                    .frame(width: zone.width * proxy.size.width, height: zone.height * proxy.size.height)
                    .position(
                        x: (zone.x + zone.width / 2) * proxy.size.width,
                        y: (zone.y + zone.height / 2) * proxy.size.height
                    )
            }

            if state.configurationNames.count > 1 {
                configurationSwitcher
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }

    private var configurationSwitcher: some View {
        VStack(spacing: 6) {
            Text("Press Option to swap")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))

            Text("Press Control to disable snap")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))

            HStack(spacing: 8) {
                ForEach(Array(state.configurationNames.enumerated()), id: \.offset) { index, name in
                    let isActive = index == state.activeConfigurationIndex
                    Text(name)
                        .font(.system(size: 15, weight: isActive ? .bold : .regular))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isActive ? Color.accentColor.opacity(0.9) : Color.black.opacity(0.5))
                        )
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.35)))
    }
}
