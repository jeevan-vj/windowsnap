import AppKit
import Foundation

final class FillInFormController: NSWindowController {
    private static let fieldWidth: CGFloat = 388
    private static let areaFieldHeight: CGFloat = 70
    private static let singleLineFieldHeight: CGFloat = 24

    private var rows: [SnippetFormRow] = []
    private var fieldControls: [String: NSView] = [:]
    private var firstInputView: NSView?
    private var completion: (([String: String]?) -> Void)?

    private var hasMultilineFields: Bool {
        rows.contains {
            if case .multiLine = $0.kind { return true }
            return false
        }
    }

    convenience init(parsed: ParsedSnippet, completion: @escaping ([String: String]?) -> Void) {
        let formRows = SnippetFormBuilder.formRows(for: parsed)
        let panelHeight = Self.panelHeight(for: formRows)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: panelHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Fill In Snippet Fields"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        self.init(window: panel)
        self.rows = formRows
        self.completion = completion
        setupContent()
    }

    private static func panelHeight(for rows: [SnippetFormRow]) -> CGFloat {
        var height: CGFloat = 120
        for row in rows {
            switch row.kind {
            case .singleLine, .popup:
                height += 56
            case .multiLine:
                height += 90
            }
        }
        return max(height, 220)
    }

    private func setupContent() {
        guard let window, let contentView = window.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        for row in rows {
            let label = NSTextField(labelWithString: row.name)
            label.font = NSFont.boldSystemFont(ofSize: 12)
            stack.addArrangedSubview(label)

            let control: NSView
            switch row.kind {
            case .singleLine:
                let field = NSTextField(string: row.defaultValue)
                field.placeholderString = row.name
                field.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    field.widthAnchor.constraint(equalToConstant: Self.fieldWidth),
                    field.heightAnchor.constraint(equalToConstant: Self.singleLineFieldHeight),
                ])
                if firstInputView == nil {
                    firstInputView = field
                }
                control = field
            case .multiLine:
                let scrollView = NSScrollView()
                scrollView.hasVerticalScroller = true
                scrollView.borderType = .bezelBorder
                scrollView.translatesAutoresizingMaskIntoConstraints = false

                let textView = NSTextView()
                textView.isEditable = true
                textView.isSelectable = true
                textView.isRichText = false
                textView.string = row.defaultValue
                textView.minSize = NSSize(width: Self.fieldWidth, height: Self.areaFieldHeight)
                textView.maxSize = NSSize(
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )
                textView.isVerticallyResizable = true
                textView.isHorizontallyResizable = false
                textView.textContainer?.widthTracksTextView = true
                textView.textContainer?.containerSize = NSSize(
                    width: Self.fieldWidth,
                    height: CGFloat.greatestFiniteMagnitude
                )
                scrollView.documentView = textView

                NSLayoutConstraint.activate([
                    scrollView.widthAnchor.constraint(equalToConstant: Self.fieldWidth),
                    scrollView.heightAnchor.constraint(equalToConstant: Self.areaFieldHeight),
                ])
                if firstInputView == nil {
                    firstInputView = textView
                }
                control = scrollView
            case .popup(let options):
                let popup = NSPopUpButton(frame: .zero, pullsDown: false)
                popup.addItems(withTitles: options)
                if let index = options.firstIndex(of: row.defaultValue) {
                    popup.selectItem(at: index)
                }
                popup.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    popup.widthAnchor.constraint(equalToConstant: Self.fieldWidth),
                ])
                control = popup
            }

            control.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(control)
            fieldControls[row.name] = control
        }

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let insertButton = NSButton(title: "Insert", target: self, action: #selector(insertTapped))
        insertButton.bezelStyle = .rounded
        if hasMultilineFields {
            insertButton.keyEquivalent = "\r"
            insertButton.keyEquivalentModifierMask = .command
        } else {
            insertButton.keyEquivalent = "\r"
            insertButton.keyEquivalentModifierMask = []
        }

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        buttonRow.addArrangedSubview(insertButton)
        buttonRow.addArrangedSubview(cancelButton)
        stack.addArrangedSubview(buttonRow)

        if hasMultilineFields {
            let hintLabel = NSTextField(labelWithString: "Return for new line  •  ⌘↩ to insert")
            hintLabel.font = NSFont.systemFont(ofSize: 11)
            hintLabel.textColor = .secondaryLabelColor
            stack.addArrangedSubview(hintLabel)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
        ])

        window.center()
    }

    func showModal() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let firstInputView {
            window?.makeFirstResponder(firstInputView)
        }
    }

    @objc private func insertTapped() {
        var values: [String: String] = [:]
        for row in rows {
            values[row.name] = value(for: row)
        }
        close()
        completion?(values)
        completion = nil
    }

    @objc private func cancelTapped() {
        close()
        completion?(nil)
        completion = nil
    }

    private func value(for row: SnippetFormRow) -> String {
        guard let control = fieldControls[row.name] else { return row.defaultValue }

        switch row.kind {
        case .singleLine:
            return (control as? NSTextField)?.stringValue ?? row.defaultValue
        case .multiLine:
            if let scrollView = control as? NSScrollView,
               let textView = scrollView.documentView as? NSTextView {
                return textView.string
            }
            return row.defaultValue
        case .popup:
            return (control as? NSPopUpButton)?.titleOfSelectedItem ?? row.defaultValue
        }
    }
}
