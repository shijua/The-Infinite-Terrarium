import Foundation

/// Converts wall-clock timestamps into a bounded simulation delta time.
public struct FrameStepper: Sendable {
    private var previousDate: Date?

    public init(previousDate: Date? = nil) {
        self.previousDate = previousDate
    }

    public mutating func step(at date: Date) -> Float {
        guard let previousDate else {
            self.previousDate = date
            return 1.0 / 60.0
        }

        let dt = date.timeIntervalSince(previousDate)
        self.previousDate = date

        // Clamp dt to keep simulation numerically stable on frame hitches.
        return Float(max(1.0 / 240.0, min(1.0 / 20.0, dt)))
    }
}
