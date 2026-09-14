import AppKit
import CoreGraphics
import Foundation

/// Owns virtual-screen lifecycle: SPI create, ScreenCaptureKit preview, and sleep/wake recovery.
final class VirtualDisplayController: NSObject {
    static let shared = VirtualDisplayController()
    static let didChangeStateNotification = Notification.Name("WindowSnapVirtualDisplayDidChangeState")

    private let adapter: VirtualDisplayCreating
    private(set) var session = VirtualDisplaySession()
    private var mirrorWindow: VirtualDisplayMirrorWindow?
    private var captureEngine: RegionCaptureEngine?
    private var screenObserver: NSObjectProtocol?
    private var appearanceWaitTask: Task<Void, Never>?
    private var captureGeneration = 0
    private var wantsCapture = false
    private var wantsPreview = false

    var state: VirtualDisplayConnectionState { session.state }

    var isAvailable: Bool { adapter.isAvailable }

    var wantsConnection: Bool { session.wantsConnection }

    init(adapter: VirtualDisplayCreating = VirtualDisplayAdapter()) {
        self.adapter = adapter
        super.init()
        if !adapter.isAvailable {
            session.markUnavailable()
        }
        observeScreenParameters()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        appearanceWaitTask?.cancel()
    }

    func connect() {
        if !adapter.isAvailable {
            session.markUnavailable()
            presentError(VirtualDisplayError.unavailable)
            notifyStateChanged()
            return
        }

        wantsPreview = true

        if let displayID = session.connectedDisplayID {
            ScreenRecordingPermissions.checkPermissionsWithAlert { [weak self] granted in
                guard let self else { return }
                self.wantsCapture = granted
                self.presentMirror(displayID: displayID)
            }
            return
        }

        guard session.state != .connecting else { return }

        ScreenRecordingPermissions.checkPermissionsWithAlert { [weak self] granted in
            self?.completeConnect(hasScreenRecording: granted)
        }
    }

    func disconnect() {
        appearanceWaitTask?.cancel()
        appearanceWaitTask = nil
        wantsCapture = false
        wantsPreview = false
        stopCapture()
        closeMirror()
        adapter.disconnect()
        session.disconnect()
        notifyStateChanged()
    }

    func recoverAfterWake() {
        if !adapter.isAvailable {
            session.markUnavailable()
            notifyStateChanged()
            return
        }

        let present: Bool
        if let displayID = adapter.displayID ?? session.connectedDisplayID {
            present = screen(for: displayID) != nil
        } else {
            present = false
        }

        switch session.recoverAfterWake(isDisplayPresent: present) {
        case .none:
            break
        case .refreshCapture:
            if let displayID = session.connectedDisplayID {
                startCapture(for: displayID)
            }
        case .recreate:
            adapter.disconnect()
            recreateDisplay()
        }
        notifyStateChanged()
    }

    private func completeConnect(hasScreenRecording: Bool) {
        wantsCapture = hasScreenRecording
        guard session.beginConnect() else {
            if let displayID = session.connectedDisplayID {
                presentMirror(displayID: displayID)
            }
            return
        }
        notifyStateChanged()

        do {
            let displayID = try adapter.connect(presets: VirtualDisplayPreset.all)
            waitForScreen(displayID: displayID, isRecovery: false)
        } catch {
            adapter.disconnect()
            session.failConnect()
            presentError(error)
            notifyStateChanged()
        }
    }

    private func recreateDisplay() {
        do {
            let displayID = try adapter.connect(presets: VirtualDisplayPreset.all)
            waitForScreen(displayID: displayID, isRecovery: true)
        } catch {
            adapter.disconnect()
            session.failRecovery()
            AppLog.virtualDisplay.error("Virtual screen recreate failed: \(error.localizedDescription, privacy: .public)")
            notifyStateChanged()
        }
    }

    private func waitForScreen(displayID: CGDirectDisplayID, isRecovery: Bool) {
        if finishConnectIfScreenExists(displayID: displayID) {
            return
        }

        appearanceWaitTask?.cancel()
        appearanceWaitTask = Task { [weak self] in
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
                guard let controller = self else { return }
                let finished = await MainActor.run {
                    guard !Task.isCancelled else { return true }
                    return controller.finishConnectIfScreenExists(displayID: displayID)
                }
                if finished { return }
            }
            guard !Task.isCancelled else { return }
            guard let controller = self else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                guard controller.session.wantsConnection else { return }
                if controller.finishConnectIfScreenExists(displayID: displayID) { return }
                guard controller.adapter.displayID == displayID else { return }
                controller.adapter.disconnect()
                if isRecovery {
                    controller.session.failRecovery()
                    AppLog.virtualDisplay.error("Virtual screen did not reappear after recovery")
                } else {
                    controller.session.failConnect()
                    controller.presentError(VirtualDisplayError.displayNeverAppeared)
                }
                controller.notifyStateChanged()
            }
        }
    }

    @discardableResult
    private func finishConnectIfScreenExists(displayID: CGDirectDisplayID) -> Bool {
        guard session.wantsConnection else { return true }
        guard screen(for: displayID) != nil else { return false }
        session.didConnect(displayID: displayID)
        if wantsPreview {
            presentMirror(displayID: displayID)
        }
        notifyStateChanged()
        return true
    }

    private func presentMirror(displayID: CGDirectDisplayID) {
        let bounds = RegionShareManager.shared.getDisplayBounds(for: displayID)
            ?? CGDisplayBounds(displayID)
        if let mirrorWindow {
            mirrorWindow.updateDisplay(displayID: displayID, bounds: bounds)
        } else {
            let window = VirtualDisplayMirrorWindow(displayID: displayID, displayBounds: bounds)
            window.onClosed = { [weak self] in
                self?.handleMirrorClosed()
            }
            mirrorWindow = window
        }
        pinAndShowMirror(excluding: displayID)

        if wantsCapture {
            startCapture(for: displayID)
        } else {
            mirrorWindow?.showPlaceholder("Grant Screen Recording to preview this display.")
        }
    }

    private func handleMirrorClosed() {
        mirrorWindow = nil
        wantsCapture = false
        wantsPreview = false
        stopCapture()
    }

    private func pinAndShowMirror(excluding displayID: CGDirectDisplayID) {
        guard let window = mirrorWindow else { return }
        window.pinToRealScreen(excluding: displayID)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func startCapture(for displayID: CGDirectDisplayID) {
        guard wantsCapture, mirrorWindow != nil else { return }
        guard let bounds = RegionShareManager.shared.getDisplayBounds(for: displayID) else {
            mirrorWindow?.showPlaceholder("Waiting for virtual screen bounds…")
            return
        }

        captureGeneration += 1
        let generation = captureGeneration
        let previous = captureEngine
        previous?.delegate = nil
        previous?.requestStop()

        let engine = RegionCaptureEngine(displayID: displayID, cropRect: bounds, frameRate: 30)
        engine.delegate = mirrorWindow
        captureEngine = engine

        Task { [weak self] in
            await previous?.stopCapture()
            guard let self else {
                await engine.stopCapture()
                return
            }
            do {
                try await engine.startCapture()
                await MainActor.run {
                    guard self.captureGeneration == generation,
                          self.wantsCapture,
                          self.mirrorWindow != nil else {
                        Task { await engine.stopCapture() }
                        return
                    }
                    AppLog.virtualDisplay.info("Preview capture started for display \(displayID, privacy: .public)")
                }
            } catch {
                await MainActor.run {
                    if self.captureEngine === engine {
                        self.captureEngine = nil
                    }
                    guard self.captureGeneration == generation else { return }
                    self.mirrorWindow?.showPlaceholder(error.localizedDescription)
                    AppLog.virtualDisplay.error("Preview capture failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func stopCapture() {
        captureGeneration += 1
        captureEngine?.delegate = nil
        captureEngine?.requestStop()
        let engine = captureEngine
        captureEngine = nil
        Task {
            await engine?.stopCapture()
        }
    }

    private func closeMirror() {
        mirrorWindow?.onClosed = nil
        mirrorWindow?.close()
        mirrorWindow = nil
    }

    private func observeScreenParameters() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenParametersChanged()
        }
    }

    private func handleScreenParametersChanged() {
        if session.state == .connecting, let pendingID = adapter.displayID {
            _ = finishConnectIfScreenExists(displayID: pendingID)
            return
        }

        guard let displayID = session.connectedDisplayID else { return }

        if screen(for: displayID) == nil {
            guard session.wantsConnection else { return }
            adapter.disconnect()
            _ = session.recoverAfterWake(isDisplayPresent: false)
            recreateDisplay()
            notifyStateChanged()
            return
        }

        let bounds = RegionShareManager.shared.getDisplayBounds(for: displayID) ?? CGDisplayBounds(displayID)
        mirrorWindow?.updateDisplay(displayID: displayID, bounds: bounds)
        if wantsCapture {
            startCapture(for: displayID)
        }
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == displayID }
    }

    private func notifyStateChanged() {
        NotificationCenter.default.post(name: Self.didChangeStateNotification, object: self)
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Virtual Screen"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
