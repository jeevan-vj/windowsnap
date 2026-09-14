import AppKit
import Foundation

final class SnippetEditorWindow: NSWindowController {
    var onSave: ((TextExpansionSnippet) -> Bool)?

    private let original: TextExpansionSnippet?
    private var triggerField: NSTextField!
    private var groupField: NSTextField!
    private var typeControl: NSSegmentedControl!
    private var hintLabel: NSTextField!
    private var textScrollView: NSScrollView!
    private var textView: NSTextView!
    private var imageView: NSImageView!

    convenience init(snippet: TextExpansionSnippet?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = snippet == nil ? "Add Snippet" : "Edit Snippet"
        self.init(window: window, snippet: snippet)
    }

    private init(window: NSWindow, snippet: TextExpansionSnippet?) {
        original = snippet
        super.init(window: window)
        setupContent()
        populate()
    }

    required init?(coder: NSCoder) {
        original = nil
        super.init(coder: coder)
    }

    private func setupContent() {
        guard let window, let contentView = window.contentView else { return }

        let triggerLabel = NSTextField(labelWithString: "Trigger")
        triggerField = NSTextField()
        triggerField.placeholderString = ":email"

        let groupLabel = NSTextField(labelWithString: "Group")
        groupField = NSTextField()
        groupField.placeholderString = "Work"

        typeControl = NSSegmentedControl(labels: ["Plain", "Rich", "Image"], trackingMode: .selectOne, target: self, action: #selector(contentTypeChanged))
        typeControl.segmentStyle = .rounded
        typeControl.selectedSegment = 0

        hintLabel = NSTextField(wrappingLabelWithString: "Use {date}, {time}, {cursor}, {field:Name}, {popup:Day:Mon|Tue|Wed}")
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor

        textView = NSTextView()
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        textScrollView = NSScrollView()
        textScrollView.hasVerticalScroller = true
        textScrollView.borderType = .bezelBorder
        textScrollView.documentView = textView

        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.isEditable = true
        imageView.isHidden = true

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded

        let buttonRow = NSStackView(views: [saveButton, cancelButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let stack = NSStackView(views: [
            triggerLabel, triggerField,
            groupLabel, groupField,
            typeControl, hintLabel,
            textScrollView, imageView,
            buttonRow,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            triggerField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            groupField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            typeControl.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hintLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            textScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            textScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            imageView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 160),
        ])

        window.center()
    }

    private func populate() {
        triggerField.stringValue = original?.trigger ?? ":"
        groupField.stringValue = original?.groupName ?? ""
        switch original?.contentType ?? .plainText {
        case .plainText:
            typeControl.selectedSegment = 0
            textView.isRichText = false
            textView.string = original?.replacement ?? ""
        case .richText:
            typeControl.selectedSegment = 1
            textView.isRichText = true
            if let data = original?.richData,
               let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attributed)
            } else {
                textView.string = original?.replacement ?? ""
            }
        case .image:
            typeControl.selectedSegment = 2
            if let data = original?.richData {
                imageView.image = NSImage(data: data)
            }
        }
        applyContentTypeVisibility()
    }

    @objc private func contentTypeChanged() {
        applyContentTypeVisibility()
    }

    private func selectedContentType() -> SnippetContentType {
        switch typeControl.selectedSegment {
        case 1: return .richText
        case 2: return .image
        default: return .plainText
        }
    }

    private func applyContentTypeVisibility() {
        let type = selectedContentType()
        let isImage = type == .image
        textScrollView.isHidden = isImage
        imageView.isHidden = !isImage
        hintLabel.isHidden = isImage
        textView.isRichText = type == .richText
    }

    @objc private func saveTapped() {
        let trigger = triggerField.stringValue.trimmingCharacters(in: .whitespaces)
        let groupName = groupField.stringValue.trimmingCharacters(in: .whitespaces)
        let normalizedGroup = groupName.isEmpty ? nil : groupName
        let contentType = selectedContentType()
        let replacement: String
        let richData: Data?

        switch contentType {
        case .plainText:
            replacement = textView.string
            richData = nil
        case .richText:
            replacement = textView.string
            let range = NSRange(location: 0, length: textView.string.utf16.count)
            richData = textView.rtf(from: range)
        case .image:
            replacement = original?.replacement.isEmpty == false ? original?.replacement ?? "Image" : "Image"
            richData = pngData(from: imageView.image)
        }

        guard TextExpanderManager.shared.validateTrigger(trigger) else {
            presentError(title: "Invalid Trigger", message: "Trigger must be at least 2 characters and cannot contain newlines or tabs.")
            return
        }

        guard TextExpanderManager.shared.validateContent(
            contentType: contentType,
            replacement: replacement,
            richData: richData
        ) else {
            presentError(title: "Invalid Replacement", message: contentType == .image
                ? "Paste or drop an image before saving."
                : "Replacement text cannot be empty.")
            return
        }

        let snippet: TextExpansionSnippet
        if let original {
            snippet = original.withUpdate(
                trigger: trigger,
                replacement: replacement,
                groupName: .some(normalizedGroup),
                contentType: contentType,
                richData: .some(richData)
            )
        } else {
            snippet = TextExpansionSnippet(
                trigger: trigger,
                replacement: replacement,
                groupName: normalizedGroup,
                contentType: contentType,
                richData: richData
            )
        }

        guard onSave?(snippet) == true else {
            presentError(title: original == nil ? "Add Failed" : "Update Failed", message: "A snippet with this trigger already exists.")
            return
        }
        close()
    }

    @objc private func cancelTapped() {
        close()
    }

    private func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func pngData(from image: NSImage?) -> Data? {
        guard let image,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
