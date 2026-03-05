import AppKit
import SwiftUI
import Combine

class DockProgressController {
    private var cancellables = Set<AnyCancellable>()
    private var customView: DockTileProgressView?

    func setup(awarenessService: SessionAwarenessService) {
        awarenessService.$isActive
            .combineLatest(
                awarenessService.$progress,
                awarenessService.$currentSessionType,
                awarenessService.$isBusySlotMode
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive, progress, sessionType, isBusySlot in
                let enabled = awarenessService.config.showDockProgress
                let busyColor: NSColor? = awarenessService.busySlotCalendarColor.map { NSColor($0) }
                let mode = awarenessService.timeDisplayMode
                self?.update(
                    isActive: isActive && enabled,
                    progress: progress,
                    sessionType: sessionType,
                    isBusySlot: isBusySlot,
                    busyColor: busyColor,
                    timeDisplayMode: mode
                )
            }
            .store(in: &cancellables)
    }

    private func update(isActive: Bool, progress: Double, sessionType: SessionType?, isBusySlot: Bool, busyColor: NSColor?, timeDisplayMode: TimeDisplayMode) {
        guard isActive else {
            // Remove custom dock tile, restore default
            if customView != nil {
                NSApp.dockTile.contentView = nil
                NSApp.dockTile.display()
                customView = nil
            }
            return
        }

        let color: NSColor
        if isBusySlot {
            color = busyColor ?? .gray
        } else if let type = sessionType {
            color = NSColor(type.color)
        } else {
            color = .gray
        }

        if customView == nil {
            let view = DockTileProgressView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
            customView = view
            NSApp.dockTile.contentView = view
        }

        customView?.progress = progress
        customView?.progressColor = color
        customView?.isRemainingMode = (timeDisplayMode == .remaining)
        NSApp.dockTile.display()
    }
}

// MARK: - Custom Dock Tile View

private class DockTileProgressView: NSView {
    var progress: Double = 0
    var progressColor: NSColor = .white
    var isRemainingMode: Bool = true

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw app icon as base
        if let appIcon = NSApp.applicationIconImage {
            appIcon.draw(in: bounds)
        }

        // Thick donut in top-right corner
        let donutSize: CGFloat = bounds.width * 0.38
        let lineWidth: CGFloat = donutSize * 0.28
        let radius: CGFloat = (donutSize - lineWidth) / 2
        let center = NSPoint(
            x: bounds.maxX - donutSize / 2 - 4,
            y: bounds.maxY - donutSize / 2 - 4
        )

        // Semi-transparent backdrop circle
        let backdropPath = NSBezierPath(
            ovalIn: NSRect(
                x: center.x - donutSize / 2,
                y: center.y - donutSize / 2,
                width: donutSize,
                height: donutSize
            )
        )
        NSColor.black.withAlphaComponent(0.5).setFill()
        backdropPath.fill()

        // Background track
        let trackPath = NSBezierPath()
        trackPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        trackPath.lineWidth = lineWidth
        NSColor.white.withAlphaComponent(0.2).setStroke()
        trackPath.stroke()

        // Progress arc
        let startAngle: CGFloat = 90  // top in AppKit coordinates

        if isRemainingMode {
            // Remaining: full donut eaten counterclockwise from 12 o'clock
            // Colored arc = remaining portion, clockwise from the eaten edge back to 12
            let remainingFraction = 1.0 - progress
            guard remainingFraction > 0 else { return }
            let endAngle: CGFloat = startAngle - CGFloat(remainingFraction) * 360

            let progressPath = NSBezierPath()
            progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            progressPath.lineWidth = lineWidth
            progressPath.lineCapStyle = .round
            progressColor.withAlphaComponent(0.95).setStroke()
            progressPath.stroke()
        } else {
            // Elapsed: empty donut fills clockwise as time passes
            guard progress > 0 else { return }
            let endAngle: CGFloat = startAngle - CGFloat(progress) * 360

            let progressPath = NSBezierPath()
            progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            progressPath.lineWidth = lineWidth
            progressPath.lineCapStyle = .round
            progressColor.withAlphaComponent(0.95).setStroke()
            progressPath.stroke()
        }
    }
}
