import Foundation
import AppKit
import Carbon

/// Engine that performs text expansion by replacing triggers with configured text
final class TextExpansionEngine {
    static let shared = TextExpansionEngine()

    private enum ExpansionTiming {
        static let postDeleteDelay: TimeInterval = 0.03
        static let postPasteboardWriteDelay: TimeInterval = 0.02
        static let postPasteDelay: TimeInterval = 0.02
        static let clipboardRestoreDelay: TimeInterval = 0.15
        static let targetAppActivationDelay: TimeInterval = 0.15
    }

    private var isExpanding = false
    private var activeFillInFormController: FillInFormController?
    private let expansionQueue = DispatchQueue(label: "com.windowsnap.textexpansion", qos: .userInteractive)

    private init() {
        setupTriggerCallback()
    }

    private func setupTriggerCallback() {
        GlobalKeyCaptureService.shared.onTriggerMatch = { [weak self] snippet, triggerLength in
            self?.performExpansion(snippet: snippet, triggerLength: triggerLength)
        }
    }

    // MARK: - Expansion

    func performExpansion(
        snippet: TextExpansionSnippet,
        triggerLength: Int = 0,
        values: [String: String] = [:],
        targetApp: NSRunningApplication? = nil
    ) {
        guard !isExpanding, activeFillInFormController == nil else {
            AppLog.textExpansion.warning("Expansion already in progress, skipping")
            return
        }

        if snippet.contentType == .plainText {
            let parsed = SnippetParser.parse(snippet.replacement)
            if parsed.hasFields && values.isEmpty {
                let capturedApp = targetApp ?? NSWorkspace.shared.frontmostApplication
                DispatchQueue.main.async { [weak self] in
                    self?.presentFillInForm(
                        for: snippet,
                        triggerLength: triggerLength,
                        parsed: parsed,
                        targetApp: capturedApp
                    )
                }
                return
            }
        }

        isExpanding = true
        GlobalKeyCaptureService.shared.setExpanding(true)

        AppLog.textExpansion.debug("Expanding snippet")

        let pasteboard = NSPasteboard.general
        let previousContents = PasteboardSnapshot.capture(pasteboard)
        let prepared = prepareReplacement(for: snippet, values: values)
        let replacementText = prepared.text
        let leftArrowCount = prepared.leftArrowCount

        let runKeyboardExpansion = { [weak self] in
            guard let self else { return }
            self.expansionQueue.async {
                if triggerLength > 0 {
                    self.deleteCharacters(count: triggerLength)
                    usleep(useconds_t(ExpansionTiming.postDeleteDelay * 1_000_000))
                }

                DispatchQueue.main.async {
                    pasteboard.clearContents()
                    self.writeToPasteboard(snippet: snippet, replacementText: replacementText, pasteboard: pasteboard)
                    let postWriteChangeCount = pasteboard.changeCount

                    DispatchQueue.main.asyncAfter(deadline: .now() + ExpansionTiming.postPasteboardWriteDelay) {
                        self.simulatePaste()

                        DispatchQueue.main.asyncAfter(deadline: .now() + ExpansionTiming.postPasteDelay) {
                            self.expansionQueue.async {
                                if let leftArrowCount, leftArrowCount > 0 {
                                    self.moveCursorLeft(count: leftArrowCount)
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + ExpansionTiming.clipboardRestoreDelay) {
                                    if previousContents.restore(to: pasteboard, ifChangeCountIs: postWriteChangeCount) {
                                        AppLog.textExpansion.debug("Clipboard restored")
                                    } else {
                                        AppLog.textExpansion.debug("Skipping clipboard restore; pasteboard changed since expansion write")
                                    }

                                    TextExpanderManager.shared.recordExpansion(
                                        trigger: snippet.trigger,
                                        replacement: replacementText
                                    )

                                    self.isExpanding = false
                                    GlobalKeyCaptureService.shared.setExpanding(false)

                                    AppLog.textExpansion.debug("Expansion complete")
                                }
                            }
                        }
                    }
                }
            }
        }

        if let targetApp {
            targetApp.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + ExpansionTiming.targetAppActivationDelay) {
                runKeyboardExpansion()
            }
        } else {
            runKeyboardExpansion()
        }
    }

    private func presentFillInForm(
        for snippet: TextExpansionSnippet,
        triggerLength: Int,
        parsed: ParsedSnippet,
        targetApp: NSRunningApplication?
    ) {
        let controller = FillInFormController(parsed: parsed) { [weak self] values in
            guard let self else { return }
            self.activeFillInFormController = nil
            guard let values else { return }
            self.performExpansion(
                snippet: snippet,
                triggerLength: triggerLength,
                values: values,
                targetApp: targetApp
            )
        }
        activeFillInFormController = controller
        controller.showModal()
    }

    // MARK: - Clipboard / Pasteboard

    private func writeToPasteboard(
        snippet: TextExpansionSnippet,
        replacementText: String,
        pasteboard: NSPasteboard
    ) {
        if snippet.contentType == .plainText {
            pasteboard.setString(replacementText, forType: .string)
            return
        }

        let item = NSPasteboardItem()
        for writeItem in SnippetPasteboardWriter.writeItems(for: snippet) {
            item.setData(writeItem.data, forType: NSPasteboard.PasteboardType(writeItem.typeIdentifier))
        }
        pasteboard.writeObjects([item])
    }

    // MARK: - Text Processing

    private func prepareReplacement(for snippet: TextExpansionSnippet, values: [String: String]) -> (text: String, leftArrowCount: Int?) {
        if snippet.contentType != .plainText {
            return (snippet.replacement, nil)
        }

        let result = SnippetExpansionPipeline.expand(
            snippet.replacement,
            values: values,
            now: Date(),
            clipboard: NSPasteboard.general.string(forType: .string)
        )
        return result
    }

    func expandPlainText(_ text: String, now: Date = Date(), clipboard: String? = nil) -> String {
        let clipboardText = clipboard ?? NSPasteboard.general.string(forType: .string)
        return MacroProcessor.expand(text, now: now, clipboard: clipboardText)
    }

    func expandAndResolveCursor(_ text: String, now: Date = Date(), clipboard: String? = nil) -> (text: String, leftArrowCount: Int?) {
        CursorResolver.resolve(expandPlainText(text, now: now, clipboard: clipboard))
    }

    // MARK: - Keyboard Simulation

    private func deleteCharacters(count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)

        for _ in 0..<count {
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: true) {
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }
            usleep(5000)
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }

        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }

        AppLog.textExpansion.debug("Simulated paste command")
    }

    private func moveCursorLeft(count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)

        for _ in 0..<count {
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_LeftArrow), keyDown: true) {
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_LeftArrow), keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }
            usleep(5000)
        }
    }

    // MARK: - Public Interface

    func start() {
        guard TextExpanderManager.shared.isEnabled else {
            AppLog.textExpansion.info("Text expander is disabled")
            return
        }

        GlobalKeyCaptureService.shared.start()
        AppLog.textExpansion.info("TextExpansionEngine started")
    }

    func stop() {
        GlobalKeyCaptureService.shared.stop()
        isExpanding = false
        if let form = activeFillInFormController {
            activeFillInFormController = nil
            form.close()
        }
        AppLog.textExpansion.info("TextExpansionEngine stopped")
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.start()
        }
    }
}
