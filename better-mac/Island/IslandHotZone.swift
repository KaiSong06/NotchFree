import AppKit

/// Tracks mouse position and drives expand/collapse of the island.
///
/// - Installs an `NSTrackingArea` on the panel's content view for precise
///   enter/exit while the cursor is inside the expanded panel bounds.
/// - Falls back on a global mouse monitor while expanded so we can detect the
///   cursor crossing the outer edge of the expanded region (tracking areas
///   don't report events outside the panel frame).
@MainActor
final class IslandHotZone: NSObject {
    enum State: Equatable { case collapsed, expanded }

    private(set) var state: State = .collapsed {
        didSet {
            if oldValue != state { onChange(state) }
        }
    }

    private weak var contentView: NSView?
    private var trackingArea: NSTrackingArea?
    private var globalMonitor: Any?
    private let onChange: (State) -> Void

    /// Short hysteresis on collapse. Long enough to absorb enter/exit jitter
    /// at the tracking-area boundary (the source of the flicker you'd see
    /// with a zero-grace collapse), short enough to feel instant to a human.
    /// A fresh `enter()` cancels the pending collapse.
    private let collapseDebounce: TimeInterval = 0.06
    private var collapseWork: DispatchWorkItem?

    init(onChange: @escaping (State) -> Void) {
        self.onChange = onChange
        super.init()
    }

    // MARK: - Attachment

    func attach(to view: NSView) {
        self.contentView = view
        installTrackingArea()
    }

    /// Re-install the tracking area after the panel frame changes. Needed
    /// because tracking areas are pinned to the view's bounds at creation.
    func refreshTrackingArea() {
        installTrackingArea()
    }

    private func installTrackingArea() {
        guard let view = contentView else { return }
        if let existing = trackingArea {
            view.removeTrackingArea(existing)
            trackingArea = nil
        }
        let area = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(area)
        trackingArea = area
    }

    // MARK: - Callbacks from the tracking area
    // NSTrackingArea sends mouseEntered:/mouseExited: to its owner using the
    // standard NSResponder selectors even when the owner is a plain NSObject.

    @objc func mouseEntered(_ event: NSEvent) {
        enter()
    }

    @objc func mouseExited(_ event: NSEvent) {
        exit()
    }

    // MARK: - Public API (also used by hosting NSView's events)

    func enter() {
        // A pending collapse is cancelled by any fresh enter — this is how
        // the anti-flicker hysteresis collapses back to stable on jitter.
        collapseWork?.cancel()
        collapseWork = nil
        if state != .expanded {
            state = .expanded
            startGlobalMonitor()
        }
    }

    func exit() {
        // If the cursor is still inside the logical hot zone (the expanded
        // panel OR the physical notch), this isn't a real exit — it's just
        // the cursor sitting at the top of the notch while the expanded
        // panel has a small gap below the screen edge. Ignore it.
        if cursorInsideHotZone() { return }

        collapseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Re-check at fire time too, in case the cursor moved back into
            // the notch during the debounce window.
            if self.cursorInsideHotZone() { return }
            if self.state != .collapsed {
                self.state = .collapsed
                self.stopGlobalMonitor()
            }
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDebounce, execute: work)
    }

    /// True iff the cursor is inside the union of the current panel frame
    /// and the physical notch rect. The notch rect is always included so
    /// that cursor positions at the very top edge of the screen (above the
    /// expanded panel's top) don't count as exits.
    private func cursorInsideHotZone() -> Bool {
        guard let window = contentView?.window else { return false }
        let p = NSEvent.mouseLocation
        let notchFrame = (window.screen ?? NSScreen.main)?.islandCollapsedRect ?? .zero
        let combined = window.frame.union(notchFrame)
        return combined.contains(p)
    }

    // MARK: - Global monitor for leaving the expanded bounds

    private func startGlobalMonitor() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            guard let self else { return }
            if !self.cursorInsideHotZone() {
                self.exit()
            }
        }
    }

    private func stopGlobalMonitor() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
}
