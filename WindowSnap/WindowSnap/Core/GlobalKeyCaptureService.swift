import Foundation
import AppKit
import Carbon

/// Service that captures global keyboard events to detect text expansion triggers
final class GlobalKeyCaptureService {
    static let shared = GlobalKeyCaptureService()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false

    private var typeBuffer: String = ""
    private let maxBufferLength = 64

    private var isExpanding = false

    var onTriggerMatch: ((TextExpansionSnippet, Int) -> Void)?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else {
            AppLog.textExpansion.debug("GlobalKeyCaptureService already running")
            return
        }

        guard InputMonitoringPermissions.hasPermissions() else {
            AppLog.textExpansion.warning("Text expander permissions not granted")
            return
        }

        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        )

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }

                let service = Unmanaged<GlobalKeyCaptureService>.fromOpaque(refcon).takeUnretainedValue()
                return service.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            AppLog.textExpansion.error("Failed to create event tap")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        guard let runLoopSource = runLoopSource else {
            AppLog.textExpansion.error("Failed to create run loop source")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        isRunning = true
        AppLog.textExpansion.info("GlobalKeyCaptureService started")
    }

    func stop() {
        guard isRunning else { return }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isRunning = false
        typeBuffer = ""

        AppLog.textExpansion.info("GlobalKeyCaptureService stopped")
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.start()
        }
    }

    // MARK: - Event Handling

    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            AppLog.textExpansion.debug("Re-enabled event tap after disable")
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        guard !isExpanding else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        let hasCommand = flags.contains(.maskCommand)
        let hasControl = flags.contains(.maskControl)

        if hasCommand || hasControl {
            clearBuffer()
            return Unmanaged.passRetained(event)
        }

        if keyCode == Int64(kVK_Tab) {
            if let snippet = TextExpanderManager.shared.findMatchingSnippet(for: typeBuffer) {
                let triggerLength = snippet.trigger.count

                DispatchQueue.main.async { [weak self] in
                    self?.onTriggerMatch?(snippet, triggerLength)
                }

                clearBuffer()
                return nil
            }

            return Unmanaged.passRetained(event)
        }

        if keyCode == Int64(kVK_Escape) {
            clearBuffer()
            return Unmanaged.passRetained(event)
        }

        if keyCode == Int64(kVK_Delete) {
            if !typeBuffer.isEmpty {
                typeBuffer.removeLast()
            }
            return Unmanaged.passRetained(event)
        }

        if keyCode == Int64(kVK_Return) || keyCode == Int64(kVK_ANSI_KeypadEnter) {
            clearBuffer()
            return Unmanaged.passRetained(event)
        }

        appendUnicodeString(from: event)

        return Unmanaged.passRetained(event)
    }

    // MARK: - Buffer Management

    private func appendUnicodeString(from event: CGEvent) {
        var length = 0
        var buffer: [UniChar] = Array(repeating: 0, count: 16)
        event.keyboardGetUnicodeString(maxStringLength: 16, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return }

        let string = String(utf16CodeUnits: buffer, count: length)
        typeBuffer.append(string)

        if typeBuffer.count > maxBufferLength {
            let dropCount = typeBuffer.count - maxBufferLength
            typeBuffer = String(typeBuffer.dropFirst(dropCount))
        }
    }

    func clearBuffer() {
        typeBuffer = ""
    }

    func setExpanding(_ expanding: Bool) {
        isExpanding = expanding
    }
}
