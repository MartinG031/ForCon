import Foundation

actor ConversionThrottle {
    private let limits: [FormatCategory: Int]
    private var running: [FormatCategory: Int] = [:]
    private var waiters: [FormatCategory: [CheckedContinuation<Void, Never>]] = [:]

    init(processorCount: Int = ProcessInfo.processInfo.activeProcessorCount) {
        let imageLimit = max(2, min(4, processorCount - 1))
        let heavyLimit = max(1, min(2, processorCount / 2))
        limits = [
            .image: imageLimit,
            .video: heavyLimit,
            .document: heavyLimit
        ]
    }

    func acquire(for category: FormatCategory) async {
        let current = running[category, default: 0]
        let limit = limits[category, default: 1]

        if current < limit {
            running[category] = current + 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters[category, default: []].append(continuation)
        }
    }

    func release(for category: FormatCategory) {
        if var queue = waiters[category], !queue.isEmpty {
            let next = queue.removeFirst()
            waiters[category] = queue
            next.resume()
            return
        }

        let current = running[category, default: 0]
        running[category] = max(0, current - 1)
    }
}

