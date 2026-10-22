import Foundation

struct Preferences: Codable, Equatable {
    var enabled = true
    var reverseVertical = false
    var reverseHorizontal = false
    var verticalSpeed = 1.0
    var horizontalSpeed = 1.0
    var blockHorizontal = false
    var optionMiddleClick = false
    var bypassWithShift = true
    var excludedApps = ""

    func excludes(_ bundleID: String) -> Bool {
        excludedApps.split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .contains { $0 == bundleID }
    }

    func scale(_ value: Double, horizontal: Bool) -> Double {
        guard value.isFinite else { return 0 }
        if horizontal && blockHorizontal { return 0 }
        let speed = horizontal ? horizontalSpeed : verticalSpeed
        let safeSpeed = speed.isFinite ? min(4, max(0.25, speed)) : 1
        let reverse = horizontal ? reverseHorizontal : reverseVertical
        return min(Double(Int32.max), max(Double(Int32.min), value * safeSpeed * (reverse ? -1 : 1)))
    }

    static func load(from defaults: UserDefaults = .standard) -> Preferences {
        guard let data = defaults.data(forKey: "preferences"),
              let value = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        return value
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "preferences") }
    }
}
