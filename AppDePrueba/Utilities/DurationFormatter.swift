import Foundation

enum DurationFormatter {
    static func string(from interval: TimeInterval) -> String {
        guard interval.isFinite, interval >= 0 else { return "0:00" }
        let seconds = Int(interval.rounded(.down))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remaining = seconds % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, remaining) }
        return String(format: "%d:%02d", minutes, remaining)
    }
}
