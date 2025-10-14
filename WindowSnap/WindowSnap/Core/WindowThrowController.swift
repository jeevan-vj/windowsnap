import Foundation
import AppKit
import Carbon

/// Controls the window throw interface - Rectangle Pro's signature feature
class WindowThrowController {
    
    static let shared = WindowThrowController()
    
    private var overlayWindow: ThrowOverlayWindow?
    private var currentWindow: WindowInfo?
    private var currentPositions: [ThrowPosition] = []
    private var keyEventMonitor: Any?
    private var isActive = false
    
    private let calculator = ThrowPositionCalculator()
    
    private init() {
        setupNotifications()
    }
    
    deinit {
        hideThrowOverlay()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(positionSelected(_:)),
            name: .throwPositionSelected,
            object: nil
        )
    }
    
    /// Show the throw overlay for the focused window
    func showThrowOverlay() {
        // Get the focused window
        guard let focusedWindow = WindowManager.shared.getFocusedWindow() else {
            print("❌ No focused window for throw interface")
            return
        }
        
        // Get the screen containing the window
        guard let screen = getScreenContainingWindow(focusedWindow) else {
            print("❌ Could not determine screen for window")
            return
        }
        
        print("🎯 Showing throw interface for window: '\(focusedWindow.windowTitle)'")
        
        // Calculate positions for this screen
        currentPositions = calculator.calculateThrowPositions(for: screen)
        currentWindow = focusedWindow
        
        // Create and show overlay
        overlayWindow = ThrowOverlayWindow()
        overlayWindow?.displayPositions(currentPositions, for: focusedWindow)
        overlayWindow?.makeKeyAndOrderFront(nil)
        
        // Setup keyboard monitoring
        setupKeyboardMonitoring()
        isActive = true
        
        print("✅ Throw interface active with \(currentPositions.count) positions")
    }
    
    /// Hide the throw overlay
    func hideThrowOverlay() {
        guard isActive else { return }
        
        print("🎯 Hiding throw interface")
        
        overlayWindow?.close()
        overlayWindow = nil
        currentWindow = nil
        currentPositions.removeAll()
        
        removeKeyboardMonitoring()
        isActive = false
    }
    
    /// Select a position by index (1-based)
    func selectPosition(_ index: Int) {
        guard isActive,
              let window = currentWindow,
              let position = overlayWindow?.getPosition(for: index) else {
            print("❌ Cannot select position \(index) - not active or invalid")
            return
        }
        
        print("🎯 Selected position \(index): \(position.displayName)")
        
        // Hide overlay first
        hideThrowOverlay()
        
        // Execute the window snap
        WindowManager.shared.snapWindow(window, to: position.gridPosition)
    }
    
    /// Handle position selection from overlay
    @objc private func positionSelected(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let index = userInfo["index"] as? Int else {
            return
        }
        
        selectPosition(index)
    }
    
    /// Setup keyboard event monitoring
    private func setupKeyboardMonitoring() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isActive else { return event }
            
            let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
            
            // Handle escape to cancel
            if event.keyCode == 53 { // Escape key
                self.hideThrowOverlay()
                return nil
            }
            
            // Handle number/letter keys for position selection
            if let index = self.calculator.getIndexForKey(key) {
                self.overlayWindow?.highlightPosition(index)
                
                // Small delay to show highlight before executing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.selectPosition(index)
                }
                return nil
            }
            
            return event
        }
    }
    
    /// Remove keyboard event monitoring
    private func removeKeyboardMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    /// Get the screen containing the given window
    private func getScreenContainingWindow(_ window: WindowInfo) -> NSScreen? {
        let windowCenter = CGPoint(
            x: window.frame.midX,
            y: window.frame.midY
        )
        
        for screen in NSScreen.screens {
            if screen.frame.contains(windowCenter) {
                return screen
            }
        }
        
        // Fallback to main screen
        return NSScreen.main
    }
    
    /// Check if throw overlay is currently active
    var isThrowOverlayActive: Bool {
        return isActive
    }
    
    /// Toggle the throw overlay (show if hidden, hide if shown)
    func toggleThrowOverlay() {
        if isActive {
            hideThrowOverlay()
        } else {
            showThrowOverlay()
        }
    }
}

// MARK: - Public Interface
extension WindowThrowController {
    
    /// Register the default throw shortcut
    func registerThrowShortcut(with shortcutManager: ShortcutManager) {
        let defaultShortcut = "ctrl+option+cmd+space"
        
        let success = shortcutManager.registerGlobalShortcut(defaultShortcut) { [weak self] in
            self?.toggleThrowOverlay()
        }
        
        if success {
            print("✅ Registered throw shortcut: \(defaultShortcut)")
        } else {
            print("❌ Failed to register throw shortcut: \(defaultShortcut)")
        }
    }
    
    /// Get available throw positions for current screen
    func getAvailablePositions() -> [ThrowPosition] {
        guard let screen = NSScreen.main else { return [] }
        return calculator.calculateThrowPositions(for: screen)
    }
}
