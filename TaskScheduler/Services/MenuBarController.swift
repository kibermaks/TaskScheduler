import AppKit
import Combine
import SwiftUI

class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private weak var awarenessService: SessionAwarenessService?

    func setup(awarenessService: SessionAwarenessService) {
        self.awarenessService = awarenessService

        // Observe config changes to show/hide
        awarenessService.$config
            .map(\.showMenuBarItem)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                if show { self?.show() } else { self?.hide() }
            }
            .store(in: &cancellables)

        // Observe session state for updates
        awarenessService.objectWillChange
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusItem()
                }
            }
            .store(in: &cancellables)
    }

    func show() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(statusItemClicked)
        updateStatusItem()
    }

    func hide() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    @objc private func statusItemClicked() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button, let service = awarenessService else { return }

        if service.isActive {
            // Show session type icon + time metric
            let iconName = service.isBusySlotMode ? "calendar" : (service.currentSessionType?.icon ?? "circle")
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Session")
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = image?.withSymbolConfiguration(config)

            // Time text
            let time: TimeInterval
            let suffix: String
            switch service.timeDisplayMode {
            case .remaining:
                time = service.remaining
                suffix = ""
            case .elapsed:
                time = service.elapsed
                suffix = ""
            }
            let totalSeconds = max(0, Int(time))
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            let timeStr = hours > 0
                ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
                : String(format: "%02d:%02d", minutes, seconds)
            let attributed = NSAttributedString(
                string: " \(timeStr)\(suffix)",
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)]
            )
            button.attributedTitle = attributed
        } else {
            // Idle: show generic icon, no title
            let image = NSImage(systemSymbolName: "eye.circle", accessibilityDescription: "Session Awareness")
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            button.image = image?.withSymbolConfiguration(config)
            button.attributedTitle = NSAttributedString(string: "")
        }
    }
}
