import SwiftUI

@MainActor
final class OverlayState: ObservableObject {
    @Published var zones: [NormalizedRect] = []
    @Published var highlightedZone: NormalizedRect?
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
        }
    }
}
