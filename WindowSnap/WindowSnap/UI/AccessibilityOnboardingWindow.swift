import AppKit

final class AccessibilityOnboardingWindowController: NSWindowController, NSWindowDelegate {
    var onDismiss: (() -> Void)?

    private let model: AccessibilityOnboardingModel
    private let statusLabel = NSTextField(labelWithString: "")
    private let statusDetailLabel = NSTextField(wrappingLabelWithString: "")
    private let requestButton = NSButton(title: "Enable Accessibility", target: nil, action: nil)
    private let settingsButton = NSButton(title: "Open System Settings", target: nil, action: nil)
    private let finishButton = NSButton(title: "Finish Setup", target: nil, action: nil)
    private let readinessLabel = NSTextField(wrappingLabelWithString: "")
    private let testedButton = NSButton(title: "I've tested a snapping shortcut", target: nil, action: nil)
    private var activationObserver: NSObjectProtocol?
    private var didNotifyDismiss = false

    init(model: AccessibilityOnboardingModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        configureWindow()
        buildContent()
        observeApplicationActivation()
        render()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    @discardableResult
    func presentIfNeeded() -> Bool {
        model.refreshPermissionStatus()
        guard model.shouldPresentOnLaunch else { return false }
        present()
        return true
    }

    func present() {
        didNotifyDismiss = false
        model.refreshPermissionStatus()
        render()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refreshPermissionStatus() {
        model.refreshPermissionStatus()
        render()
    }

    func windowWillClose(_ notification: Notification) {
        notifyDismissed()
    }

    private func configureWindow() {
        guard let window else { return }
        window.title = "Welcome to WindowSnap"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.delegate = self
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.edgeInsets = NSEdgeInsets(top: 28, left: 32, bottom: 24, right: 32)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let title = NSTextField(labelWithString: "Set up window snapping")
        title.font = .systemFont(ofSize: 24, weight: .bold)
        root.addArrangedSubview(title)

        let introduction = NSTextField(wrappingLabelWithString: "WindowSnap needs Accessibility access so it can move and resize application windows when you use a menu command or keyboard shortcut.")
        introduction.font = .systemFont(ofSize: 14)
        root.addArrangedSubview(introduction)
        introduction.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -64).isActive = true

        let privacyBox = makeBox()
        let privacyText = NSTextField(wrappingLabelWithString: "Private by design\nWindowSnap works locally on this Mac. No account is required, and this setup does not request Screen Recording or Input Monitoring access.")
        privacyText.font = .systemFont(ofSize: 13)
        privacyBox.addSubview(privacyText)
        privacyText.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            privacyText.leadingAnchor.constraint(equalTo: privacyBox.leadingAnchor, constant: 14),
            privacyText.trailingAnchor.constraint(equalTo: privacyBox.trailingAnchor, constant: -14),
            privacyText.topAnchor.constraint(equalTo: privacyBox.topAnchor, constant: 12),
            privacyText.bottomAnchor.constraint(equalTo: privacyBox.bottomAnchor, constant: -12)
        ])
        root.addArrangedSubview(privacyBox)
        privacyBox.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -64).isActive = true

        let statusTitle = NSTextField(labelWithString: "Accessibility status")
        statusTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        root.addArrangedSubview(statusTitle)

        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        root.addArrangedSubview(statusLabel)
        root.addArrangedSubview(statusDetailLabel)
        statusDetailLabel.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -64).isActive = true

        requestButton.target = self
        requestButton.action = #selector(requestPermission)
        requestButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.bezelStyle = .rounded

        let permissionButtons = NSStackView(views: [requestButton, settingsButton])
        permissionButtons.orientation = .horizontal
        permissionButtons.spacing = 10
        root.addArrangedSubview(permissionButtons)

        readinessLabel.stringValue = "Ready to test: focus another app, then press ⌘⇧← to snap its window to the left half. You can reopen this setup from the WindowSnap menu at any time."
        readinessLabel.font = .systemFont(ofSize: 13)
        readinessLabel.textColor = .secondaryLabelColor
        root.addArrangedSubview(readinessLabel)
        readinessLabel.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -64).isActive = true

        testedButton.target = self
        testedButton.action = #selector(confirmShortcutTest)
        testedButton.setButtonType(.switch)
        root.addArrangedSubview(testedButton)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        root.addArrangedSubview(spacer)

        let laterButton = NSButton(title: "Not Now", target: self, action: #selector(dismissWithoutFinishing))
        laterButton.bezelStyle = .rounded
        finishButton.target = self
        finishButton.action = #selector(finishSetup)
        finishButton.bezelStyle = .rounded
        finishButton.keyEquivalent = "\r"

        let footer = NSStackView(views: [laterButton, finishButton])
        footer.orientation = .horizontal
        footer.spacing = 10
        footer.distribution = .fillEqually
        root.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -64).isActive = true
    }

    private func makeBox() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.layer?.cornerRadius = 8
        return view
    }

    private func observeApplicationActivation() {
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPermissionStatus()
        }
    }

    private func render() {
        switch model.status {
        case .notGranted:
            statusLabel.stringValue = "Not granted"
            statusLabel.textColor = .systemOrange
            statusDetailLabel.stringValue = "Choose Enable Accessibility when you're ready. macOS will then ask for your approval."
        case .granted:
            statusLabel.stringValue = "Granted"
            statusLabel.textColor = .systemGreen
            statusDetailLabel.stringValue = "WindowSnap is ready to move and resize windows."
        case .unavailable(let message):
            statusLabel.stringValue = "Status unavailable"
            statusLabel.textColor = .systemRed
            statusDetailLabel.stringValue = "\(message) Open System Settings to verify WindowSnap is enabled, then return here."
        }

        let granted = model.canFinish
        requestButton.isHidden = granted
        finishButton.isEnabled = granted
        readinessLabel.isHidden = !granted
        testedButton.isHidden = !granted
    }

    @objc private func requestPermission() {
        model.requestPermission()
        render()
    }

    @objc private func openSettings() {
        model.openSystemSettings()
    }

    @objc private func confirmShortcutTest() {
        readinessLabel.stringValue = testedButton.state == .on
            ? "Test confirmed. WindowSnap is ready; choose Finish Setup when you're done."
            : "Ready to test: focus another app, then press ⌘⇧← to snap its window to the left half."
    }

    @objc private func finishSetup() {
        guard model.finish() else {
            refreshPermissionStatus()
            return
        }
        window?.close()
    }

    @objc private func dismissWithoutFinishing() {
        window?.orderOut(nil)
        notifyDismissed()
    }

    private func notifyDismissed() {
        guard !didNotifyDismiss else { return }
        didNotifyDismiss = true
        onDismiss?()
    }
}
