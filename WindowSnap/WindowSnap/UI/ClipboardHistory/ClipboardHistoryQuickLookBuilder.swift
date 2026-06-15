import AppKit

enum ClipboardHistoryQuickLookBuilder {
    static let popoverSize = NSSize(width: 340, height: 240)

    static func makeViewController(for item: ClipboardHistoryItem) -> NSViewController {
        let viewController = NSViewController()
        let containerView = NSView(frame: NSRect(origin: .zero, size: popoverSize))

        if item.type == .image,
           let thumbnailString = item.thumbnail,
           let thumbnailData = Data(base64Encoded: thumbnailString),
           let image = NSImage(data: thumbnailData) {
            let imageView = NSImageView(frame: containerView.bounds)
            imageView.image = image
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.autoresizingMask = [.width, .height]
            containerView.addSubview(imageView)
        } else {
            let scrollView = NSScrollView(frame: containerView.bounds)
            scrollView.autoresizingMask = [.width, .height]
            scrollView.hasVerticalScroller = true
            scrollView.borderType = .noBorder
            scrollView.scrollerStyle = .overlay

            let textView = NSTextView(frame: containerView.bounds)
            textView.isEditable = false
            textView.isSelectable = true
            textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textView.textColor = .labelColor
            textView.backgroundColor = .clear
            textView.textContainerInset = NSSize(width: 12, height: 12)
            textView.string = item.content.count > 2000
                ? String(item.content.prefix(2000)) + "\n..."
                : item.content

            scrollView.documentView = textView
            containerView.addSubview(scrollView)
        }

        viewController.view = containerView
        return viewController
    }
}
