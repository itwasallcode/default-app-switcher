import Foundation

package struct ShortcutFeedback {
    package static let duration: TimeInterval = 0.12

    package private(set) var key: Key?
    private var deadline: TimeInterval?

    package init() {}

    package mutating func press(
        _ key: Key, at now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        self.key = key
        deadline = now + Self.duration
    }

    package mutating func remainingMilliseconds(
        at now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Int32? {
        guard let deadline else { return nil }
        let remaining = deadline - now
        guard remaining > 0 else {
            key = nil
            self.deadline = nil
            return nil
        }
        return Int32(ceil(remaining * 1000))
    }
}
