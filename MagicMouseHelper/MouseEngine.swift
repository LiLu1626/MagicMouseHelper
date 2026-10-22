import AppKit
import Combine
import ApplicationServices

// The tap is installed on the main run loop; it shares isolation with the settings UI.
@MainActor
final class MouseEngine: ObservableObject {
    @Published var preferences: Preferences { didSet { preferences.save(to: defaults) } }
    private let defaults: UserDefaults
    @Published private(set) var status = "尚未启动"
    @Published private(set) var running = false
    @Published private(set) var eventCount = 0
    @Published private(set) var lastEvent = "尚无事件"
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var middleDrag = false
    private var frontAppID = ""
    private var workspaceObserver: NSObjectProtocol?
    private var count = 0
    private var lastUpdate = Date.distantPast

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = Preferences.load(from: defaults)
        frontAppID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier ?? ""
            MainActor.assumeIsolated { self?.frontAppID = id }
        }
    }

    var accessibilityGranted: Bool { AXIsProcessTrusted() }

    func start() {
        guard tap == nil else { return }
        guard accessibilityGranted else {
            status = "等待辅助功能授权"
            return
        }
        let types: [CGEventType] = [.scrollWheel, .leftMouseDown, .leftMouseUp, .leftMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated {
                let engine = Unmanaged<MouseEngine>.fromOpaque(context).takeUnretainedValue()
                return engine.handle(type, event: event)
            }
        }
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            status = "监听启动失败，请检查权限后重试"
            return
        }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            status = "无法创建事件监听"
            return
        }
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        running = true
        status = "事件监听已运行"
    }

    func stop() {
        // Complete a remapped press if the app quits during a drag.
        if middleDrag, let up = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp,
            mouseCursorPosition: CGEvent(source: nil)?.location ?? .zero, mouseButton: .center) {
            up.post(tap: .cghidEventTap)
        }
        middleDrag = false
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        running = false
        status = "事件监听已停止"
    }

    func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func quit() { stop(); NSApplication.shared.terminate(nil) }

    func handle(_ type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Fail open: never silently resume after macOS disables the tap.
            running = false
            status = "系统已停用监听，请停止后重新启动"
            return Unmanaged.passUnretained(event)
        }
        count += 1
        let now = Date()
        if now.timeIntervalSince(lastUpdate) > 0.2 {
            eventCount = count
            lastEvent = type == .scrollWheel ? "滚动" : "鼠标点击或拖动"
            lastUpdate = now
        }
        // Finish an existing middle-button sequence regardless of settings or focus changes.
        if middleDrag && (type == .leftMouseUp || type == .leftMouseDragged) {
            event.type = type == .leftMouseUp ? .otherMouseUp : .otherMouseDragged
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
            event.flags.remove(.maskAlternate)
            if type == .leftMouseUp { middleDrag = false }
            return Unmanaged.passUnretained(event)
        }
        let p = preferences
        guard p.enabled, !p.excludes(frontAppID),
              !(p.bypassWithShift && event.flags.contains(.maskShift)) else {
            return Unmanaged.passUnretained(event)
        }
        if type == .leftMouseDown && p.optionMiddleClick && event.flags.contains(.maskAlternate) {
            middleDrag = true
            event.type = .otherMouseDown
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
            event.flags.remove(.maskAlternate)
        }
        if type == .scrollWheel {
            let axes: [(CGEventField, CGEventField, CGEventField, Bool)] = [
                (.scrollWheelEventDeltaAxis1, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, false),
                (.scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, true)
            ]
            for (line, point, fixed, horizontal) in axes {
                // Read all representations first: changing one can update the others.
                let lineValue = event.getIntegerValueField(line)
                let pointValue = event.getIntegerValueField(point)
                let fixedValue = event.getDoubleValueField(fixed)
                event.setIntegerValueField(line, value: Int64(p.scale(Double(lineValue), horizontal: horizontal).rounded()))
                event.setDoubleValueField(fixed, value: p.scale(fixedValue, horizontal: horizontal))
                event.setIntegerValueField(point, value: Int64(p.scale(Double(pointValue), horizontal: horizontal).rounded()))
            }
        }
        return Unmanaged.passUnretained(event)
    }
}
