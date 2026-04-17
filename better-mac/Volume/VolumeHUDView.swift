import SwiftUI

/// iPhone-style two-tone volume capsule with a device icon at the bottom.
///
/// The pill (track + fill) is drawn in a single `Canvas` so there's no
/// per-layer compositing — that's what was producing the soft halo around
/// the bottom curve. The icon is overlaid as a normal SwiftUI `Image`, which
/// is fine because the Canvas underneath is now a solid opaque shape.
struct VolumeHUDView: View {
    let volume: Float          // 0.0 ... 1.0
    let muted: Bool
    let kind: OutputKind
    let deviceName: String
    let showPercentage: Bool

    private var clampedVolume: CGFloat {
        CGFloat(max(0, min(1, volume)))
    }

    private var fillFraction: CGFloat {
        muted ? 0 : clampedVolume
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Inner pill dimensions after the 8pt shadow padding.
            let innerWidth = size.width - 16
            let innerHeight = size.height - 16
            let capRadius = innerWidth / 2
            // Stop the fill at the top of the straight section so the clip
            // never curls the top edge inward. The top cap stays track-coloured.
            let fillH = max(0, (innerHeight - capRadius) * fillFraction)
            ZStack(alignment: .bottom) {
                // Track — a dedicated Capsule shape so the shadow traces the
                // pill outline instead of the ZStack's bounding rectangle.
                Capsule(style: .continuous)
                    .fill(Color(white: 0.55).opacity(0.9))
                    .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 3)

                // Fill + icon stack, clipped to the same capsule so the fill's
                // bottom tapers with the pill's curve and nothing bleeds past
                // the shadow'd track. This sub-stack has no shadow of its
                // own — the track beneath carries it.
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: fillH)

                    Image(systemName: iconName)
                        .resizable()
                        .symbolRenderingMode(.monochrome)
                        .scaledToFit()
                        .foregroundStyle(.black)
                        .frame(width: size.width * 0.42, height: size.width * 0.42)
                        .padding(.bottom, size.width * 0.32)
                }
                .clipShape(Capsule(style: .continuous))
            }
            .padding(8)
            .accessibilityLabel(Text(accessibilityLabel))
        }
    }

    // MARK: - Symbol resolution

    /// SF Symbol name for the active output. For speaker-type outputs the
    /// glyph is chosen from the `speaker.wave.N.fill` family so the number
    /// of wave bars tracks the current level — matching iOS's volume HUD.
    private var iconName: String {
        if muted { return "speaker.slash.fill" }
        switch kind {
        case .airPods:           return "airpods"
        case .builtInHeadphones: return "headphones"
        case .airPlay:           return "airplayaudio"
        case .builtInSpeakers,
             .usb,
             .bluetooth,
             .other:             return speakerSymbolForLevel
        }
    }

    private var speakerSymbolForLevel: String {
        if clampedVolume <= 0.001 { return "speaker.fill" }
        if clampedVolume <= 0.33  { return "speaker.wave.1.fill" }
        if clampedVolume <= 0.66  { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var accessibilityLabel: String {
        let pct = Int((clampedVolume * 100).rounded())
        if muted { return "\(deviceName) muted" }
        return "\(deviceName) volume \(pct) percent"
    }
}

#if DEBUG
#Preview("70%") {
    VolumeHUDView(volume: 0.7, muted: false, kind: .airPods, deviceName: "AirPods", showPercentage: false)
        .frame(width: 56, height: 220)
        .padding()
        .background(Color.black)
}

#Preview("Muted") {
    VolumeHUDView(volume: 0.7, muted: true, kind: .builtInSpeakers, deviceName: "Speakers", showPercentage: false)
        .frame(width: 56, height: 220)
        .padding()
        .background(Color.black)
}
#endif
