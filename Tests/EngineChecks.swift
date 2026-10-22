import AppKit
import Foundation

@main
struct EngineChecks {
    @MainActor static func main() {
        var checks = 0
        func check(_ condition: Bool, _ name: String) {
            precondition(condition, name)
            checks += 1
        }
        var p = Preferences()
        check(p.scale(12, horizontal: false) == 12, "default preserves scrolling")
        p.reverseVertical = true; p.verticalSpeed = 2
        check(p.scale(12, horizontal: false) == -24, "vertical reversal and speed")
        check(p.scale(3, horizontal: true) == 3, "axes independent")
        p.blockHorizontal = true
        check(p.scale(3, horizontal: true) == 0, "horizontal block")
        p.verticalSpeed = .infinity
        check(p.scale(12, horizontal: false) == -12, "invalid speed handled")
        check(p.scale(.nan, horizontal: false) == 0, "invalid event handled")
        p.excludedApps = "com.apple.Safari\ncom.apple.finder, test.app"
        check(p.excludes("com.apple.Safari"), "app exclusion")
        check(!p.excludes("com.apple.Safari.Other"), "exact bundle ID matching")
        let defaults = UserDefaults(suiteName: "MagicMouseHelper.AutomatedChecks")!
        defaults.removePersistentDomain(forName: "MagicMouseHelper.AutomatedChecks")
        var saved = Preferences(); saved.verticalSpeed = 1.75; saved.optionMiddleClick = true
        saved.save(to: defaults)
        check(Preferences.load(from: defaults) == saved, "settings round trip")
        defaults.set(Data("broken".utf8), forKey: "preferences")
        check(Preferences.load(from: defaults) == Preferences(), "corrupt settings recover")
        defaults.removePersistentDomain(forName: "MagicMouseHelper.AutomatedChecks")

        let engine = MouseEngine(defaults: defaults)
        // Tests call the transform directly; they never install a tap or post input.
        engine.preferences = Preferences()
        engine.preferences.reverseVertical = true
        engine.preferences.verticalSpeed = 2
        let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 12, wheel2: 5, wheel3: 0)!
        scroll.flags = []
        let y = scroll.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        _ = engine.handle(.scrollWheel, event: scroll)
        check(scroll.getDoubleValueField(.scrollWheelEventPointDeltaAxis1) == y * -2, "CGEvent scroll transformed")
        engine.preferences.blockHorizontal = true
        _ = engine.handle(.scrollWheel, event: scroll)
        check(scroll.getDoubleValueField(.scrollWheelEventPointDeltaAxis2) == 0, "CGEvent horizontal blocked")
        scroll.flags = .maskShift
        let before = scroll.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        _ = engine.handle(.scrollWheel, event: scroll)
        check(scroll.getDoubleValueField(.scrollWheelEventPointDeltaAxis1) == before, "Shift bypass")
        engine.preferences.enabled = false
        scroll.flags = []
        _ = engine.handle(.scrollWheel, event: scroll)
        check(scroll.getDoubleValueField(.scrollWheelEventPointDeltaAxis1) == before, "master bypass")
        engine.preferences.enabled = true
        engine.preferences.optionMiddleClick = true
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left)!
        down.flags = .maskAlternate
        _ = engine.handle(.leftMouseDown, event: down)
        check(down.type == .otherMouseDown, "middle down")
        check(!down.flags.contains(.maskAlternate), "Option removed")
        engine.preferences.enabled = false
        let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: .zero, mouseButton: .left)!
        _ = engine.handle(.leftMouseDragged, event: drag)
        check(drag.type == .otherMouseDragged, "drag survives setting change")
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: .zero, mouseButton: .left)!
        _ = engine.handle(.leftMouseUp, event: up)
        check(up.type == .otherMouseUp, "paired middle release")
        _ = engine.handle(.tapDisabledByTimeout, event: up)
        check(!engine.running, "timeout fails open")
        engine.stop()
        check(!engine.running, "stop idempotent")
        defaults.removePersistentDomain(forName: "MagicMouseHelper.AutomatedChecks")
        print("PASS: \(checks) checks")
    }
}
