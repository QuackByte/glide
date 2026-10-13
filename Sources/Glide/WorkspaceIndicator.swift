import AppKit
import SwiftUI

/// Shows which workspace you're on: numbers in the menu bar, and a brief on-screen display
/// when you switch.
enum WorkspaceIndicator {
    struct Entry: Equatable {
        let number: Int
        let isActive: Bool
    }

    /// The Glide symbol followed by the numbers of the workspaces in use, the active one filled
    /// in. A template image, so it follows the menu bar's color.
    static func menuBarImage(symbol: String, entries: [Entry]) -> NSImage {
        let cell: CGFloat = 15
        let spacing: CGFloat = 3
        let symbolWidth: CGFloat = 20
        let height: CGFloat = 16
        let width = symbolWidth + spacing + CGFloat(entries.count) * (cell + spacing)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            if let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(configuration) {
                let size = glyph.size
                glyph.draw(in: NSRect(x: (symbolWidth - size.width) / 2, y: (height - size.height) / 2, width: size.width, height: size.height))
            }
            guard let context = NSGraphicsContext.current?.cgContext else { return true }
            for (index, entry) in entries.enumerated() {
                let rect = NSRect(x: symbolWidth + spacing + CGFloat(index) * (cell + spacing), y: (height - cell) / 2, width: cell, height: cell)
                let text = NSAttributedString(string: "\(entry.number)", attributes: [.font: font, .foregroundColor: NSColor.black])
                let size = text.size()
                let origin = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
                if entry.isActive {
                    NSColor.black.setFill()
                    NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
                    // Knock the number out of the filled square.
                    context.saveGState()
                    context.setBlendMode(.destinationOut)
                    text.draw(at: origin)
                    context.restoreGState()
                } else {
                    text.draw(at: origin)
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// The brief display shown near the bottom of the screen when you switch workspaces.
final class WorkspaceHUD {
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(entries: [WorkspaceIndicator.Entry], message: String) {
        guard let screen = NSScreen.screens.first else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let hosting = NSHostingView(rootView: HUDView(entries: entries, message: message))
        let size = hosting.fittingSize
        panel.contentView = hosting
        let visible = screen.visibleFrame
        panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.minY + 72, width: size.width, height: size.height), display: true)
        if !panel.isVisible || panel.alphaValue < 1 {
            panel.orderFrontRegardless()
            panel.fadeIn(duration: 0.08)
        }

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak panel] in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: {
                if panel.alphaValue == 0 { panel.orderOut(nil) }
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.configureAsOverlay()
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        return panel
    }
}

private struct HUDView: View {
    let entries: [WorkspaceIndicator.Entry]
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(entries, id: \.number) { entry in
                    Text("\(entry.number)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(entry.isActive ? .white : .secondary)
                        .frame(width: 38, height: 38)
                        .background(entry.isActive ? accent : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            Text(message)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(12)
    }

    private var accent: Color { Color(nsColor: Appearance.focusRingColor ?? .controlAccentColor) }
}
