import Foundation

enum PlaybackQueueLogic {
    static func nextIndex(currentIndex: Int?, queueCount: Int) -> Int? {
        guard let currentIndex, currentIndex >= 0 else { return nil }
        let candidate = currentIndex + 1
        return candidate < queueCount ? candidate : nil
    }

    static func previousIndex(currentIndex: Int?, queueCount: Int) -> Int? {
        guard let currentIndex, currentIndex > 0, currentIndex < queueCount else { return nil }
        return currentIndex - 1
    }
}
