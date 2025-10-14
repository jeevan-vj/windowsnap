import AppKit
import Foundation

/// Window for managing custom window positions
class CustomPositionsWindow: NSWindowController {
    
    private var customPositionManager = CustomPositionManager.shared
    private var tableView: NSTableView!
    private var positions: [CustomPosition] = []
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
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
        
        window.title = "Custom Positions"
        window.center()
        window.isRestorable = false
        window.minSize = NSSize(width: 500, height: 400)
        
        setupContentView()
        refreshPositions()
    }
    
    private func setupContentView() {
        guard let window = window else { return }
        
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView
        
        // Title label
        let titleLabel = NSTextField(labelWithString: "Custom Window Positions")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: contentView.frame.height - 40, width: 300, height: 25)
        titleLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Create and manage your custom window sizes and positions")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 20, y: contentView.frame.height - 60, width: 400, height: 20)
        subtitleLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(subtitleLabel)
        
        // Create table view with scroll view
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 80, width: contentView.frame.width - 40, height: contentView.frame.height - 160))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .lineBorder
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Create columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 150
        tableView.addTableColumn(nameColumn)
        
        let descriptionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))
        descriptionColumn.title = "Position"
        descriptionColumn.width = 200
        tableView.addTableColumn(descriptionColumn)
        
        let shortcutColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("shortcut"))
        shortcutColumn.title = "Shortcut"
        shortcutColumn.width = 150
        tableView.addTableColumn(shortcutColumn)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        // Create buttons
        setupButtons(in: contentView)
    }
    
    private func setupButtons(in contentView: NSView) {
        let buttonHeight: CGFloat = 32
        let buttonSpacing: CGFloat = 10
        var xPos: CGFloat = 20
        
        // Add Current Window button
        let addCurrentButton = NSButton(title: "Add Current Window", target: self, action: #selector(addCurrentWindow))
        addCurrentButton.frame = NSRect(x: xPos, y: 20, width: 150, height: buttonHeight)
        addCurrentButton.autoresizingMask = [.minYMargin]
        contentView.addSubview(addCurrentButton)
        xPos += 150 + buttonSpacing
        
        // Add Custom button
        let addCustomButton = NSButton(title: "Add Custom", target: self, action: #selector(addCustomPosition))
        addCustomButton.frame = NSRect(x: xPos, y: 20, width: 100, height: buttonHeight)
        addCustomButton.autoresizingMask = [.minYMargin]
        contentView.addSubview(addCustomButton)
        xPos += 100 + buttonSpacing
        
        // Edit button
        let editButton = NSButton(title: "Edit", target: self, action: #selector(editPosition))
        editButton.frame = NSRect(x: xPos, y: 20, width: 70, height: buttonHeight)
        editButton.autoresizingMask = [.minYMargin]
        contentView.addSubview(editButton)
        xPos += 70 + buttonSpacing
        
        // Delete button
        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deletePosition))
        deleteButton.frame = NSRect(x: xPos, y: 20, width: 70, height: buttonHeight)
        deleteButton.autoresizingMask = [.minYMargin]
        contentView.addSubview(deleteButton)
        xPos += 70 + buttonSpacing
        
        // Test button
        let testButton = NSButton(title: "Test", target: self, action: #selector(testPosition))
        testButton.frame = NSRect(x: xPos, y: 20, width: 70, height: buttonHeight)
        testButton.autoresizingMask = [.minYMargin]
        contentView.addSubview(testButton)
    }
    
    private func refreshPositions() {
        positions = customPositionManager.getAllPositions()
        tableView?.reloadData()
    }
    
    // MARK: - Button Actions
    
    @objc private func addCurrentWindow() {
        guard WindowManager.shared.getFocusedWindow() != nil else {
            showAlert(title: "No Window", message: "Please focus on a window first, then try again.")
            return
        }
        
        showAddPositionDialog(fromCurrentWindow: true)
    }
    
    @objc private func addCustomPosition() {
        showAddPositionDialog(fromCurrentWindow: false)
    }
    
    @objc private func editPosition() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < positions.count else {
            showAlert(title: "No Selection", message: "Please select a position to edit.")
            return
        }
        
        let position = positions[selectedRow]
        showEditPositionDialog(for: position)
    }
    
    @objc private func deletePosition() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < positions.count else {
            showAlert(title: "No Selection", message: "Please select a position to delete.")
            return
        }
        
        let position = positions[selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "Delete Custom Position"
        alert.informativeText = "Are you sure you want to delete '\(position.name)'?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            customPositionManager.removePosition(id: position.id)
            refreshPositions()
        }
    }
    
    @objc private func testPosition() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < positions.count else {
            showAlert(title: "No Selection", message: "Please select a position to test.")
            return
        }
        
        let position = positions[selectedRow]
        customPositionManager.executePosition(position)
    }
    
    // MARK: - Dialog Methods
    
    private func showAddPositionDialog(fromCurrentWindow: Bool) {
        let dialog = CustomPositionDialog(fromCurrentWindow: fromCurrentWindow)
        
        if let window = window {
            window.beginSheet(dialog.window!) { [weak self] response in
                if response == .OK, let position = dialog.customPosition {
                    self?.customPositionManager.addPosition(position)
                    self?.refreshPositions()
                }
            }
        }
    }
    
    private func showEditPositionDialog(for position: CustomPosition) {
        let dialog = CustomPositionDialog(editing: position)
        
        if let window = window {
            window.beginSheet(dialog.window!) { [weak self] response in
                if response == .OK, let updatedPosition = dialog.customPosition {
                    self?.customPositionManager.updatePosition(updatedPosition)
                    self?.refreshPositions()
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Table View Data Source and Delegate

extension CustomPositionsWindow: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return positions.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < positions.count else { return nil }
        
        let position = positions[row]
        let identifier = tableColumn?.identifier
        
        let cell = NSTextField()
        cell.isBordered = false
        cell.backgroundColor = .clear
        cell.isEditable = false
        
        switch identifier?.rawValue {
        case "name":
            cell.stringValue = position.name
            cell.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            
        case "description":
            cell.stringValue = position.displayDescription
            cell.font = NSFont.systemFont(ofSize: 12)
            cell.textColor = .secondaryLabelColor
            
        case "shortcut":
            cell.stringValue = position.shortcut ?? "None"
            cell.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            cell.textColor = position.hasShortcut ? .labelColor : .tertiaryLabelColor
            
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
}

// MARK: - Custom Position Creation Dialog

class CustomPositionDialog: NSWindowController {
    
    private var nameField: NSTextField!
    private var shortcutField: NSTextField!
    private var widthSlider: NSSlider!
    private var heightSlider: NSSlider!
    private var xSlider: NSSlider!
    private var ySlider: NSSlider!
    private var widthLabel: NSTextField!
    private var heightLabel: NSTextField!
    private var xLabel: NSTextField!
    private var yLabel: NSTextField!
    
    private let fromCurrentWindow: Bool
    private let editingPosition: CustomPosition?
    
    var customPosition: CustomPosition?
    
    init(fromCurrentWindow: Bool = false, editing: CustomPosition? = nil) {
        self.fromCurrentWindow = fromCurrentWindow
        self.editingPosition = editing
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        setupDialog()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupDialog() {
        guard let window = window else { return }
        
        let title = editingPosition != nil ? "Edit Custom Position" :
                   fromCurrentWindow ? "Add Position from Current Window" : "Add Custom Position"
        window.title = title
        window.center()
        
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView
        
        var yPos: CGFloat = contentView.frame.height - 40
        
        // Name field
        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.frame = NSRect(x: 20, y: yPos, width: 60, height: 20)
        contentView.addSubview(nameLabel)
        
        nameField = NSTextField(frame: NSRect(x: 90, y: yPos, width: 340, height: 22))
        nameField.placeholderString = "Enter position name"
        contentView.addSubview(nameField)
        yPos -= 40
        
        // Shortcut field
        let shortcutLabel = NSTextField(labelWithString: "Shortcut:")
        shortcutLabel.frame = NSRect(x: 20, y: yPos, width: 60, height: 20)
        contentView.addSubview(shortcutLabel)
        
        shortcutField = NSTextField(frame: NSRect(x: 90, y: yPos, width: 200, height: 22))
        shortcutField.placeholderString = "e.g., cmd+shift+1"
        contentView.addSubview(shortcutField)
        yPos -= 40
        
        if !fromCurrentWindow {
            // Only show position controls if not from current window
            setupPositionControls(in: contentView, startingY: yPos)
        }
        
        // Buttons
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.frame = NSRect(x: contentView.frame.width - 180, y: 20, width: 70, height: 32)
        contentView.addSubview(cancelButton)
        
        let okButton = NSButton(title: "OK", target: self, action: #selector(ok))
        okButton.frame = NSRect(x: contentView.frame.width - 100, y: 20, width: 70, height: 32)
        okButton.keyEquivalent = "\r"
        contentView.addSubview(okButton)
        
        // Load existing values if editing
        if let position = editingPosition {
            nameField.stringValue = position.name
            shortcutField.stringValue = position.shortcut ?? ""
            
            if !fromCurrentWindow {
                widthSlider.doubleValue = position.widthPercent * 100
                heightSlider.doubleValue = position.heightPercent * 100
                xSlider.doubleValue = position.xPercent * 100
                ySlider.doubleValue = position.yPercent * 100
                updateLabels()
            }
        }
    }
    
    private func setupPositionControls(in contentView: NSView, startingY: CGFloat) {
        var yPos = startingY
        
        // Width
        let widthTitleLabel = NSTextField(labelWithString: "Width:")
        widthTitleLabel.frame = NSRect(x: 20, y: yPos, width: 60, height: 20)
        contentView.addSubview(widthTitleLabel)
        
        widthSlider = NSSlider(frame: NSRect(x: 90, y: yPos, width: 250, height: 20))
        widthSlider.minValue = 10
        widthSlider.maxValue = 100
        widthSlider.doubleValue = 50
        widthSlider.target = self
        widthSlider.action = #selector(sliderChanged)
        contentView.addSubview(widthSlider)
        
        widthLabel = NSTextField(labelWithString: "50%")
        widthLabel.frame = NSRect(x: 350, y: yPos, width: 60, height: 20)
        contentView.addSubview(widthLabel)
        yPos -= 30
        
        // Height
        let heightTitleLabel = NSTextField(labelWithString: "Height:")
        heightTitleLabel.frame = NSRect(x: 20, y: yPos, width: 60, height: 20)
        contentView.addSubview(heightTitleLabel)
        
        heightSlider = NSSlider(frame: NSRect(x: 90, y: yPos, width: 250, height: 20))
        heightSlider.minValue = 10
        heightSlider.maxValue = 100
        heightSlider.doubleValue = 50
        heightSlider.target = self
        heightSlider.action = #selector(sliderChanged)
        contentView.addSubview(heightSlider)
        
        heightLabel = NSTextField(labelWithString: "50%")
        heightLabel.frame = NSRect(x: 350, y: yPos, width: 60, height: 20)
        contentView.addSubview(heightLabel)
        yPos -= 30
        
        // X Position
        let xTitleLabel = NSTextField(labelWithString: "X Position:")
        xTitleLabel.frame = NSRect(x: 20, y: yPos, width: 70, height: 20)
        contentView.addSubview(xTitleLabel)
        
        xSlider = NSSlider(frame: NSRect(x: 90, y: yPos, width: 250, height: 20))
        xSlider.minValue = 0
        xSlider.maxValue = 100
        xSlider.doubleValue = 25
        xSlider.target = self
        xSlider.action = #selector(sliderChanged)
        contentView.addSubview(xSlider)
        
        xLabel = NSTextField(labelWithString: "25%")
        xLabel.frame = NSRect(x: 350, y: yPos, width: 60, height: 20)
        contentView.addSubview(xLabel)
        yPos -= 30
        
        // Y Position
        let yTitleLabel = NSTextField(labelWithString: "Y Position:")
        yTitleLabel.frame = NSRect(x: 20, y: yPos, width: 70, height: 20)
        contentView.addSubview(yTitleLabel)
        
        ySlider = NSSlider(frame: NSRect(x: 90, y: yPos, width: 250, height: 20))
        ySlider.minValue = 0
        ySlider.maxValue = 100
        ySlider.doubleValue = 25
        ySlider.target = self
        ySlider.action = #selector(sliderChanged)
        contentView.addSubview(ySlider)
        
        yLabel = NSTextField(labelWithString: "25%")
        yLabel.frame = NSRect(x: 350, y: yPos, width: 60, height: 20)
        contentView.addSubview(yLabel)
    }
    
    @objc private func sliderChanged() {
        updateLabels()
    }
    
    private func updateLabels() {
        widthLabel?.stringValue = "\(Int(widthSlider.doubleValue))%"
        heightLabel?.stringValue = "\(Int(heightSlider.doubleValue))%"
        xLabel?.stringValue = "\(Int(xSlider.doubleValue))%"
        yLabel?.stringValue = "\(Int(ySlider.doubleValue))%"
    }
    
    @objc private func ok() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Invalid Name"
            alert.informativeText = "Please enter a name for the custom position."
            alert.runModal()
            return
        }
        
        let shortcut = shortcutField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalShortcut = shortcut.isEmpty ? nil : shortcut
        
        if fromCurrentWindow {
            customPosition = CustomPositionManager.shared.createFromCurrentWindow(name: name, shortcut: finalShortcut)
        } else {
            customPosition = CustomPosition(
                name: name,
                widthPercent: widthSlider.doubleValue / 100.0,
                heightPercent: heightSlider.doubleValue / 100.0,
                xPercent: xSlider.doubleValue / 100.0,
                yPercent: ySlider.doubleValue / 100.0,
                shortcut: finalShortcut
            )
        }
        
        window?.sheetParent?.endSheet(window!, returnCode: .OK)
    }
    
    @objc private func cancel() {
        window?.sheetParent?.endSheet(window!, returnCode: .cancel)
    }
}
