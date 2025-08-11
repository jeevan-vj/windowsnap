import AppKit
import Foundation

class PreferencesWindow: NSWindowController {
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWindow()
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "WindowSnap Preferences"
        window.center()
        window.isRestorable = false
        
        setupContentView()
    }
    
    private func setupContentView() {
        guard let window = window else { return }
        
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView
        
        // Create tab view
        let tabView = NSTabView(frame: contentView.bounds)
        tabView.autoresizingMask = [.width, .height]
        contentView.addSubview(tabView)
        
        // General tab
        let generalTab = NSTabViewItem(identifier: "general")
        generalTab.label = "General"
        generalTab.view = createGeneralTab()
        tabView.addTabViewItem(generalTab)
        
        // Shortcuts tab
        let shortcutsTab = NSTabViewItem(identifier: "shortcuts")
        shortcutsTab.label = "Shortcuts"
        shortcutsTab.view = createShortcutsTab()
        tabView.addTabViewItem(shortcutsTab)
    }
    
    private func createGeneralTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 350))
        
        var yPos: CGFloat = 300
        
        // Title
        let titleLabel = NSTextField(labelWithString: "General Settings")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 25)
        view.addSubview(titleLabel)
        yPos -= 40
        
        // Launch at login checkbox
        let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch WindowSnap at login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        launchAtLoginCheckbox.frame = NSRect(x: 20, y: yPos, width: 300, height: 25)
        launchAtLoginCheckbox.state = getLaunchAtLoginState()
        view.addSubview(launchAtLoginCheckbox)
        yPos -= 40
        
        // Show notifications checkbox
        let showNotificationsCheckbox = NSButton(checkboxWithTitle: "Show notifications when windows are snapped", target: self, action: #selector(toggleNotifications(_:)))
        showNotificationsCheckbox.frame = NSRect(x: 20, y: yPos, width: 400, height: 25)
        showNotificationsCheckbox.state = getNotificationsState()
        view.addSubview(showNotificationsCheckbox)
        yPos -= 40
        
        // Accessibility permissions info
        let accessibilityLabel = NSTextField(labelWithString: "Accessibility Permissions:")
        accessibilityLabel.font = NSFont.boldSystemFont(ofSize: 13)
        accessibilityLabel.frame = NSRect(x: 20, y: yPos, width: 200, height: 20)
        view.addSubview(accessibilityLabel)
        yPos -= 25
        
        let permissionStatus = AccessibilityPermissions.hasPermissions() ? "✓ Granted" : "✗ Not Granted"
        let statusLabel = NSTextField(labelWithString: permissionStatus)
        statusLabel.textColor = AccessibilityPermissions.hasPermissions() ? .systemGreen : .systemRed
        statusLabel.frame = NSRect(x: 40, y: yPos, width: 150, height: 20)
        view.addSubview(statusLabel)
        
        if !AccessibilityPermissions.hasPermissions() {
            let openSettingsButton = NSButton(title: "Open System Preferences", target: self, action: #selector(openAccessibilitySettings))
            openSettingsButton.frame = NSRect(x: 200, y: yPos - 5, width: 200, height: 30)
            view.addSubview(openSettingsButton)
        }
        
        return view
    }
    
    private func createShortcutsTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 350))
        
        var yPos: CGFloat = 320
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Keyboard Shortcuts")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 25)
        view.addSubview(titleLabel)
        yPos -= 30
        
        // Description
        let descriptionLabel = NSTextField(wrappingLabelWithString: "Default keyboard shortcuts for window positioning. These shortcuts are automatically registered when WindowSnap starts.")
        descriptionLabel.frame = NSRect(x: 20, y: yPos - 40, width: 440, height: 40)
        view.addSubview(descriptionLabel)
        yPos -= 70
        
        // Shortcuts list
        let shortcuts = ShortcutManager().getDefaultShortcuts()
        
        for (shortcut, position) in shortcuts.sorted(by: { $0.value.rawValue < $1.value.rawValue }) {
            let shortcutLabel = NSTextField(labelWithString: shortcut.uppercased())
            shortcutLabel.frame = NSRect(x: 20, y: yPos, width: 150, height: 20)
            shortcutLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            view.addSubview(shortcutLabel)
            
            let actionLabel = NSTextField(labelWithString: position.displayName)
            actionLabel.frame = NSRect(x: 180, y: yPos, width: 280, height: 20)
            view.addSubview(actionLabel)
            
            yPos -= 25
        }
        
        return view
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enable = sender.state == .on
        setLaunchAtLogin(enable)
    }
    
    @objc private func toggleNotifications(_ sender: NSButton) {
        let enable = sender.state == .on
        UserDefaults.standard.set(enable, forKey: "ShowNotifications")
    }
    
    @objc private func openAccessibilitySettings() {
        AccessibilityPermissions.openSecurityPreferences()
    }
    
    private func getLaunchAtLoginState() -> NSControl.StateValue {
        return UserDefaults.standard.bool(forKey: "LaunchAtLogin") ? .on : .off
    }
    
    private func getNotificationsState() -> NSControl.StateValue {
        return UserDefaults.standard.bool(forKey: "ShowNotifications") ? .on : .off
    }
    
    private func setLaunchAtLogin(_ enable: Bool) {
        UserDefaults.standard.set(enable, forKey: "LaunchAtLogin")
        // Note: Actual launch at login implementation would require additional setup
        // This is a placeholder for the setting
    }
}