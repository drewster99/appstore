import Foundation

// Global rate limiter for API calls
// Apple's App Store API allows approximately 20 requests per minute
// This translates to one request every 3 seconds
class RateLimiter {
    static let shared = RateLimiter()

    // Time to wait between API calls (in seconds)
    private let delaySeconds: TimeInterval = 3.0

    // Last time an API call was made
    private var lastRequestTime: Date?

    // Queue to ensure thread safety
    private let queue = DispatchQueue(label: "com.appstore.ratelimiter")

    private init() {}

    // Call this before making any API request
    func waitIfNeeded() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                let now = Date()

                if let lastTime = lastRequestTime {
                    let timeSinceLastRequest = now.timeIntervalSince(lastTime)

                    if timeSinceLastRequest < delaySeconds {
                        let waitTime = delaySeconds - timeSinceLastRequest

                        // Wait for the remaining time
                        DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
                            self.queue.async {
                                self.lastRequestTime = Date()
                                continuation.resume()
                            }
                        }
                        return
                    }
                }

                // No need to wait
                lastRequestTime = now
                continuation.resume()
            }
        }
    }
}

// Global convenience function
func waitForRateLimit() async {
    await RateLimiter.shared.waitIfNeeded()
}