import AppKit

private final class AppearanceAwareControlBackgroundView: NSView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
}

final class AccessibilityOnboardingWindowController: NSWindowController, NSWindowDelegate {
    var onDismiss: (() -> Void)?

    private let model: AccessibilityOnboardingModel
    private let statusLabel = NSTextField(labelWithString: "")
    private let statusDetailLabel = NSTextField(wrappingLabelWithString: "")
    private let requestButton = NSButton(title: "Continue", target: nil, action: nil)
    private let settingsButton = NSButton(title: "Open System Settings", target: nil, action: nil)
    private let finishButton = NSButton(title: "Finish Setup", target: nil, action: nil)
    private let readinessLabel = NSTextField(wrappingLabelWithString: "")
    private var activationObserver: NSObjectProtocol?
    private var didNotifyDismiss = false
    private var hasRequestedPermission = false

    init(model: AccessibilityOnboardingModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 350),
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
        model.markPresented()
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
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 22, right: 28)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let title = NSTextField(labelWithString: "Set up window snapping")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        root.addArrangedSubview(title)

        let introduction = NSTextField(wrappingLabelWithString: "WindowSnap needs Accessibility access so it can move and resize application windows when you use a menu command or keyboard shortcut.")
        introduction.font = .systemFont(ofSize: 14)
        root.addArrangedSubview(introduction)
        introduction.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -56).isActive = true

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
        privacyBox.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -56).isActive = true

        let statusTitle = NSTextField(labelWithString: "Accessibility status")
        statusTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        root.addArrangedSubview(statusTitle)

        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        root.addArrangedSubview(statusLabel)
        root.addArrangedSubview(statusDetailLabel)
        statusDetailLabel.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -56).isActive = true

        requestButton.target = self
        requestButton.action = #selector(requestPermission)
        requestButton.bezelStyle = .rounded
        requestButton.keyEquivalent = "\r"
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.bezelStyle = .rounded

        readinessLabel.stringValue = "WindowSnap is ready. Focus another app and press ⌘⇧← to move its window to the left half."
        readinessLabel.font = .systemFont(ofSize: 13)
        readinessLabel.textColor = .secondaryLabelColor
        root.addArrangedSubview(readinessLabel)
        readinessLabel.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -56).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        root.addArrangedSubview(spacer)

        let laterButton = NSButton(title: "Not Now", target: self, action: #selector(dismissWithoutFinishing))
        laterButton.bezelStyle = .rounded
        finishButton.target = self
        finishButton.action = #selector(finishSetup)
        finishButton.bezelStyle = .rounded
        finishButton.keyEquivalent = "\r"

        let horizontalSpacer = NSView()
        horizontalSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let footer = NSStackView(views: [laterButton, horizontalSpacer, settingsButton, requestButton, finishButton])
        footer.orientation = .horizontal
        footer.spacing = 10
        footer.alignment = .centerY
        root.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -56).isActive = true
    }

    private func makeBox() -> NSView {
        let view = AppearanceAwareControlBackgroundView()
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
            statusLabel.stringValue = "Setup needed"
            statusLabel.textColor = .secondaryLabelColor
            statusDetailLabel.stringValue = "Continue when you're ready. macOS will ask you to allow WindowSnap in Privacy & Security."
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
        requestButton.isHidden = granted || hasRequestedPermission
        settingsButton.isHidden = granted || !hasRequestedPermission
        finishButton.isEnabled = granted
        finishButton.isHidden = !granted
        readinessLabel.isHidden = !granted
    }

    @objc private func requestPermission() {
        hasRequestedPermission = true
        model.requestPermission()
        render()
    }

    @objc private func openSettings() {
        model.openSystemSettings()
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
