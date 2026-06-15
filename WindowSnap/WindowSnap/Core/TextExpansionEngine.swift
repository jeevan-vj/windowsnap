import Foundation
import AppKit

/// Engine that performs text expansion by replacing triggers with configured text
class TextExpansionEngine {
    static let shared = TextExpansionEngine()

    private var isExpanding = false
    private var activeFillInFormController: FillInFormController?
    private var expansionTargetApp: NSRunningApplication?
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

    func performExpansion(snippet: TextExpansionSnippet, triggerLength: Int = 0, values: [String: String] = [:]) {
        guard !isExpanding else {
            print("⚠️ Expansion already in progress, skipping")
            return
        }

        if snippet.contentType == .plainText {
            let parsed = SnippetParser.parse(snippet.replacement)
            if parsed.hasFields && values.isEmpty {
                expansionTargetApp = NSWorkspace.shared.frontmostApplication
                DispatchQueue.main.async { [weak self] in
                    self?.presentFillInForm(for: snippet, triggerLength: triggerLength, parsed: parsed)
                }
                return
            }
        }

        isExpanding = true
        GlobalKeyCaptureService.shared.setExpanding(true)

        print("📝 Expanding: '\(snippet.trigger)' → '\(snippet.replacement.prefix(30))...'")

        let pasteboard = NSPasteboard.general
        let previousContents = backupClipboard(pasteboard)
        let previousChangeCount = pasteboard.changeCount
        let prepared = prepareReplacement(for: snippet, values: values)
        let replacementText = prepared.text
        let leftArrowCount = prepared.leftArrowCount
        let targetApp = expansionTargetApp
        expansionTargetApp = nil

        let runKeyboardExpansion = { [weak self] in
            guard let self else { return }
            self.expansionQueue.async {
                if triggerLength > 0 {
                    self.deleteCharacters(count: triggerLength)
                    usleep(30000)
                }

                DispatchQueue.main.async {
                    pasteboard.clearContents()
                    self.writeToPasteboard(snippet: snippet, replacementText: replacementText, pasteboard: pasteboard)

                    usleep(20000)

                    self.simulatePaste()

                    if let leftArrowCount, leftArrowCount > 0 {
                        usleep(20000)
                        self.moveCursorLeft(count: leftArrowCount)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.restoreClipboard(pasteboard, contents: previousContents, previousChangeCount: previousChangeCount)

                        TextExpanderManager.shared.recordExpansion(
                            trigger: snippet.trigger,
                            replacement: replacementText
                        )

                        self.isExpanding = false
                        GlobalKeyCaptureService.shared.setExpanding(false)

                        print("✅ Expansion complete")
                    }
                }
            }
        }

        if let targetApp {
            targetApp.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                runKeyboardExpansion()
            }
        } else {
            runKeyboardExpansion()
        }
    }

    private func presentFillInForm(for snippet: TextExpansionSnippet, triggerLength: Int, parsed: ParsedSnippet) {
        let controller = FillInFormController(parsed: parsed) { [weak self] values in
            guard let self else { return }
            self.activeFillInFormController = nil
            guard let values else {
                self.isExpanding = false
                GlobalKeyCaptureService.shared.setExpanding(false)
                return
            }
            self.performExpansion(snippet: snippet, triggerLength: triggerLength, values: values)
        }
        activeFillInFormController = controller
        controller.showModal()
    }

    // MARK: - Clipboard Management

    private struct ClipboardContents {
        var items: [(NSPasteboard.PasteboardType, Data)] = []
        var string: String?
    }

    private func backupClipboard(_ pasteboard: NSPasteboard) -> ClipboardContents {
        var contents = ClipboardContents()

        if let string = pasteboard.string(forType: .string) {
            contents.string = string
        }

        if let items = pasteboard.pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        contents.items.append((type, data))
                    }
                }
            }
        }

        return contents
    }

    private func restoreClipboard(_ pasteboard: NSPasteboard, contents: ClipboardContents, previousChangeCount: Int) {
        guard pasteboard.changeCount != previousChangeCount else {
            return
        }

        pasteboard.clearContents()

        if !contents.items.isEmpty {
            let item = NSPasteboardItem()
            for (type, data) in contents.items {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        } else if let string = contents.string {
            pasteboard.setString(string, forType: .string)
        }

        print("📋 Clipboard restored")
    }

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
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true) {
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }
            usleep(5000)
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }

        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }

        print("📋 Simulated paste command")
    }

    private func moveCursorLeft(count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        let leftArrowKeyCode: CGKeyCode = 0x7B

        for _ in 0..<count {
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: leftArrowKeyCode, keyDown: true) {
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: leftArrowKeyCode, keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }
            usleep(5000)
        }
    }

    // MARK: - Public Interface

    func start() {
        guard TextExpanderManager.shared.isEnabled else {
            print("📝 Text expander is disabled")
            return
        }

        GlobalKeyCaptureService.shared.start()
        print("📝 TextExpansionEngine started")
    }

    func stop() {
        GlobalKeyCaptureService.shared.stop()
        isExpanding = false
        print("📝 TextExpansionEngine stopped")
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.start()
        }
    }
}
