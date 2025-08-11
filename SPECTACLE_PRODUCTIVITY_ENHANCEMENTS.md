# WindowSnap - Spectacle-Inspired Productivity Enhancements

## Analysis of Spectacle & Rectangle Success Factors

After deep analysis of Spectacle, Rectangle, and Rectangle Pro, I've identified key productivity features that made them industry leaders in window management. Here's our enhancement roadmap:

---

## 🔄 **1. CYCLING WINDOW SIZES** (High Priority)
**What Spectacle Does:** Repeated shortcuts cycle through different sizes
**Example:** Press ⌘⇧← multiple times: 50% → 33% → 66% → 50%

### Implementation Plan:
```swift
class WindowActionHistory {
    private var lastAction: (position: GridPosition, count: Int)?
    
    func getNextCyclePosition(for position: GridPosition, count: Int) -> GridPosition {
        switch position {
        case .leftHalf:
            return [.leftHalf, .leftThird, .leftTwoThirds][count % 3]
        case .rightHalf:
            return [.rightHalf, .rightThird, .rightTwoThirds][count % 3]
        // ... other positions
        }
    }
}
```

**Benefit:** Eliminates need for multiple shortcuts, intuitive workflow

---

## ⏪ **2. UNDO/REDO FUNCTIONALITY** (High Priority)
**What Spectacle Does:** ⌥⌘Z to undo, ⌥⇧⌘Z to redo window actions

### Implementation Plan:
```swift
class WindowActionHistory {
    private var history: [WindowState] = []
    private var currentIndex: Int = -1
    
    struct WindowState {
        let windowInfo: WindowInfo
        let frame: CGRect
        let timestamp: Date
    }
    
    func saveState(before action: GridPosition, window: WindowInfo)
    func undo() -> WindowState?
    func redo() -> WindowState?
}
```

**Benefit:** Fearless experimentation, easy mistake correction

---

## 📏 **3. INCREMENTAL RESIZING** (Medium Priority) 
**What Spectacle Does:** ⌃⌥⇧→ (larger), ⌃⌥⇧← (smaller)

### Implementation Plan:
```swift
enum ResizeDirection {
    case larger, smaller
}

func incrementalResize(_ window: WindowInfo, direction: ResizeDirection) {
    let currentSize = window.frame.size
    let increment: CGFloat = 50 // pixels
    
    let newSize = CGSize(
        width: direction == .larger ? currentSize.width + increment : currentSize.width - increment,
        height: direction == .larger ? currentSize.height + increment : currentSize.height - increment
    )
}
```

**New Shortcuts:**
- `⌃⌥⇧→` - Make window larger
- `⌃⌥⇧←` - Make window smaller

**Benefit:** Fine-grained control, precise adjustments

---

## 🖥️ **4. DISPLAY SWITCHING** (High Priority)
**What Spectacle Does:** ⌃⌥⌘→ (next display), ⌃⌥⌘← (previous display)

### Implementation Plan:
```swift
func moveToNextDisplay(_ window: WindowInfo) {
    let screens = NSScreen.screens
    let currentScreen = getScreenContainingAXRect(window.frame)
    
    if let currentIndex = screens.firstIndex(of: currentScreen) {
        let nextIndex = (currentIndex + 1) % screens.count
        let nextScreen = screens[nextIndex]
        
        // Maintain relative position on new screen
        let relativeFrame = calculateRelativeFrame(window.frame, from: currentScreen, to: nextScreen)
        moveWindowToAXFrame(window, frame: relativeFrame)
    }
}
```

**New Shortcuts:**
- `⌃⌥⌘→` - Move to next display
- `⌃⌥⌘←` - Move to previous display

**Benefit:** Essential for multi-monitor workflows

---

## 🎨 **5. VISUAL FEEDBACK** (Medium Priority)
**What Rectangle Pro Does:** Overlay showing snap targets

### Implementation Plan:
```swift
class VisualFeedbackManager {
    func showSnapPreview(for position: GridPosition, on screen: NSScreen)
    func showActionFeedback(action: String, success: Bool)
    func highlightTargetArea(frame: CGRect, color: NSColor)
}
```

**Features:**
- Translucent overlay showing target position
- Success/failure notifications  
- Smooth animations during transitions

**Benefit:** Clear visual confirmation, better user understanding

---

## 🎯 **6. CUSTOM POSITIONS** (Advanced)
**What Rectangle Pro Does:** User-defined window sizes and positions

### Implementation Plan:
```swift
struct CustomPosition {
    let name: String
    let widthPercent: Double
    let heightPercent: Double
    let xPercent: Double
    let yPercent: Double
    let shortcut: String?
}

class CustomPositionManager {
    func saveCustomPosition(_ position: CustomPosition)
    func getCustomPositions() -> [CustomPosition]
    func executeCustomPosition(_ position: CustomPosition, window: WindowInfo)
}
```

**UI Enhancement:**
- Preferences panel for defining custom positions
- Drag-to-define interface
- Export/import position sets

**Benefit:** Personalized workflows, specialized layouts

---

## 📊 **7. WINDOW MEMORY** (Advanced)
**Innovation Beyond Spectacle:** Remember window preferences per app

### Implementation Plan:
```swift
class WindowMemoryManager {
    func rememberWindowPreference(app: String, position: GridPosition)
    func getPreferredPosition(for app: String) -> GridPosition?
    func applyAppDefaults(when app: String, launches: Bool)
}
```

**Smart Features:**
- Learn user patterns for specific apps
- Auto-position frequently used apps
- Context-aware suggestions

**Benefit:** Intelligent automation, reduced manual positioning

---

## 🚀 **8. PRODUCTIVITY COMBOS** (Innovation)
**New Concept:** Compound shortcuts for complex layouts

### Implementation Plan:
```swift
enum ProductivityCombo {
    case codingLayout    // Editor 66%, Terminal 33%
    case designLayout    // Canvas 75%, Tools 25%
    case meetingLayout   // Zoom center, Notes left third
}

func executeProductivityCombo(_ combo: ProductivityCombo) {
    // Position multiple windows in coordinated layout
}
```

**New Shortcuts:**
- `⌘⌥⇧C` - Coding layout
- `⌘⌥⇧D` - Design layout
- `⌘⌥⇧M` - Meeting layout

**Benefit:** One-click workspace setup, context switching

---

## 🎛️ **9. ENHANCED PREFERENCES** 
**What Rectangle Pro Does:** Extensive customization options

### UI Improvements:
- **Shortcut Customization:** Visual shortcut editor
- **Animation Settings:** Speed, easing preferences  
- **Display Preferences:** Per-monitor settings
- **App-Specific Rules:** Custom behavior per application
- **Import/Export:** Share configurations

---

## 📈 **Implementation Priority**

### **Phase 1: Core Productivity (Week 1)**
1. ✅ **Cycling Window Sizes** - Most impactful feature
2. ✅ **Undo/Redo** - Essential safety net
3. ✅ **Display Switching** - Multi-monitor essential

### **Phase 2: User Experience (Week 2)**  
4. **Visual Feedback** - Polish and usability
5. **Enhanced Preferences** - Better customization
6. **Incremental Resizing** - Fine control

### **Phase 3: Advanced Features (Week 3)**
7. **Custom Positions** - Power user features
8. **Window Memory** - Smart automation
9. **Productivity Combos** - Innovation beyond Spectacle

---

## 🎯 **Success Metrics**

**User Engagement:**
- Reduced time spent on window management
- Increased shortcut usage vs menu clicks
- User retention and word-of-mouth growth

**Feature Adoption:**
- Most used: Cycling (80%), Undo (60%), Display switching (40%)
- Power features: Custom positions (20%), Memory (15%)
- Innovation: Productivity combos (10%)

**Technical Goals:**
- Sub-100ms response time for all actions
- Zero crashes, robust error handling
- Memory usage under 50MB

This roadmap transforms WindowSnap from a basic window manager into a **productivity powerhouse** that rivals Rectangle Pro while adding innovative features that don't exist elsewhere.

The key is implementing features that **reduce cognitive load** and **accelerate workflows** rather than just adding more positioning options. Each feature should make window management more intuitive and powerful.